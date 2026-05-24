# LAN Network Audio Sink

Turn any headless Raspberry Pi (or Debian host) into a network speaker that Linux laptops on the same LAN detect and use automatically — no manual IP configuration or pairing required.

## How it works

- The Pi runs **PulseAudio** with two extra modules: one that accepts audio over TCP, and one that advertises the sink via **mDNS/Avahi** so clients can find it automatically.
- The laptop runs **PipeWire** with its native `libpipewire-module-zeroconf-discover` module, which browses mDNS and creates a tunnel sink for each discovered host.
- Both sides use Avahi for zero-config discovery — no static IPs or hostnames to configure.

## Setup

### Pi (audio sink)

Copy `pi-audio-sink-setup.sh` to the Pi and run it as the target user:

```bash
scp pi-audio-sink-setup.sh pi@<your-pi>:~
ssh pi@<your-pi> bash pi-audio-sink-setup.sh
```

The script will:
- Install PulseAudio + zeroconf modules + Avahi
- Auto-detect the local subnet for the TCP access control list
- Configure PulseAudio to accept connections and advertise via mDNS
- Enable `loginctl linger` so the user session (and PulseAudio) starts at boot without a login

**Override the subnet** if auto-detection fails:
```bash
SUBNET=10.0.0.0/24 bash pi-audio-sink-setup.sh
```

### Laptop (PipeWire, Ubuntu 22.04/24.04+)

Run `laptop-audio-discover-setup.sh` once on the laptop:

```bash
bash laptop-audio-discover-setup.sh
```

The script will:
- Install and enable `avahi-daemon`
- Drop a PipeWire config that loads `libpipewire-module-zeroconf-discover` on startup
- Restart PipeWire to pick it up immediately

> **Note:** Do not use `pulseaudio-module-zeroconf` on Ubuntu with PipeWire — it conflicts with `pipewire-pulse`. The native PipeWire module used here requires no extra packages.

## Verifying

After both scripts have run, the Pi should appear as a sink on the laptop:

```bash
pactl list sinks short
# tunnel.<hostname>.local.alsa_output.*  PipeWire  ...  SUSPENDED
```

Set it as the default output:
```bash
pactl set-default-sink tunnel.<hostname>.local.alsa_output.<device>
```

Or select it from your desktop sound settings (GNOME, KDE, etc.).

## Debugging

**On the Pi** — check PulseAudio is running and advertising:
```bash
systemctl --user status pulseaudio
avahi-browse _pulse-sink._tcp -t
```

**On the laptop** — check the module is loaded:
```bash
pw-cli info all | grep -i zeroconf
```

**Sink not appearing?** Verify both machines are on the same LAN subnet and that `avahi-daemon` is active on both.

## Re-deploying

Both scripts are idempotent — safe to re-run after an OS reinstall or if something breaks.
