#!/usr/bin/env bash
# laptop-audio-discover-setup.sh
# Configures a PipeWire laptop (Ubuntu 22.04/24.04+) to auto-discover PulseAudio
# network sinks on the LAN via mDNS. Does NOT require pulseaudio-module-zeroconf.
#
# Requirements: Ubuntu/Debian with PipeWire 1.0+ as the audio system
# Run as your normal user: bash laptop-audio-discover-setup.sh
# Re-run safe: idempotent

set -euo pipefail

CONF_DIR="$HOME/.config/pipewire/pipewire.conf.d"
CONF_FILE="$CONF_DIR/zeroconf-discover.conf"

echo "==> Ensuring avahi-daemon is installed and running..."
sudo apt-get install -y -qq avahi-daemon
sudo systemctl enable --now avahi-daemon

echo "==> Writing PipeWire zeroconf discover config: $CONF_FILE"
mkdir -p "$CONF_DIR"
cat > "$CONF_FILE" << 'EOF'
context.modules = [
{   name = libpipewire-module-zeroconf-discover
    flags = [ ifexists nofail ]
}
]
EOF

echo "==> Restarting PipeWire..."
systemctl --user restart pipewire wireplumber
sleep 3

echo "==> Available sinks (LAN sinks appear as tunnel.<hostname>.local.*):"
pactl list sinks short

echo ""
echo "==> Done. Network audio sinks will appear automatically when hosts are online."
echo "    Switch output with:"
echo "      pactl set-default-sink <sink-name>"
echo "    Or select from your desktop sound settings."
