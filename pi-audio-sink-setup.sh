#!/usr/bin/env bash
# pi-audio-sink-setup.sh
# Configures a headless Raspberry Pi (or any Debian-based Linux host) as a
# PulseAudio network audio sink, auto-discoverable via mDNS on the local LAN.
#
# Requirements: Debian/Raspbian (Bullseye or later), sudo access
# Run as the target user (e.g. pi): bash pi-audio-sink-setup.sh
# Re-run safe: idempotent
#
# Optional env overrides:
#   SUBNET   — IP range allowed to connect (default: auto-detected from default route)

set -euo pipefail

# Detect subnet from the default route interface if not overridden
if [[ -z "${SUBNET:-}" ]]; then
    IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
    SUBNET=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | head -1)
    SUBNET=$(python3 -c "import ipaddress; n=ipaddress.IPv4Interface('$SUBNET'); print(n.network)" 2>/dev/null \
             || echo "192.168.0.0/24")
fi

PULSE_CONFIG="$HOME/.config/pulse/default.pa"

echo "==> Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y pulseaudio pulseaudio-module-zeroconf avahi-daemon avahi-utils

echo "==> Enabling Avahi daemon..."
sudo systemctl enable --now avahi-daemon

echo "==> Enabling loginctl linger for $(whoami) (auto-start user session at boot)..."
sudo loginctl enable-linger "$(whoami)"

echo "==> Writing PulseAudio config: $PULSE_CONFIG"
echo "    Allowing connections from subnet: $SUBNET"
mkdir -p "$(dirname "$PULSE_CONFIG")"
cat > "$PULSE_CONFIG" <<EOF
# Extend default PulseAudio config with network sink modules
.include /etc/pulse/default.pa

# Accept TCP connections from the local subnet (no password)
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;${SUBNET} auth-anonymous=1

# Advertise this sink over mDNS so LAN clients auto-discover it
load-module module-zeroconf-publish
EOF

echo "==> Restarting PulseAudio user service..."
systemctl --user daemon-reload
systemctl --user enable pulseaudio
systemctl --user restart pulseaudio

sleep 2

echo "==> PulseAudio status:"
systemctl --user status pulseaudio --no-pager

echo "==> Available sinks:"
pactl list sinks short

echo ""
echo "==> Verifying mDNS advertisement..."
avahi-browse _pulse-sink._tcp -t 2>/dev/null || echo "(avahi-browse check skipped)"

echo ""
echo "==> Done. This host is now a network audio sink."
echo ""
echo "    Run laptop-audio-discover-setup.sh on any Linux laptop to auto-discover it."
