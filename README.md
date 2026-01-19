# Gaming on AI Servers
![Screenshot](https://i.ibb.co/KpKpghRk/Screenshot-20260118-110930-Artemis.jpg)

[![Open Repo](https://img.shields.io/badge/Open%20Repo-GitHub-181717?logo=github&logoColor=white)](https://github.com/FahriCT/container-sunshine-headless)


Sunshine Headless Gaming & Streaming Stack for Ubuntu
An automated installation script that turns Ubuntu headless AI servers and cloud GPU instances into a fully functional gaming and streaming environment using Sunshine, Xorg, and NVIDIA GPUs, even in restricted or compute-focused setups.

## Description

AI servers and cloud GPU platforms are typically optimized for compute workloads such as machine learning, rendering, or batch processing. While many providers expose NVIDIA GPUs and ship a working kernel driver, the graphics stack required for interactive use is often incomplete or restricted. In practice, this results in systems where nvidia-smi works correctly but graphical applications fail to start.
Common limitations include missing physical displays, lack of input devices, partial NVIDIA userspace installations, and in some environments restricted access to /dev/dri. These constraints make it difficult to run software such as Sunshine, desktop environments, or game launchers on headless infrastructure.
This project provides a complete and automated solution for these environments. The script installs a lightweight desktop environment, configures a headless Xorg session with a virtual display, completes missing NVIDIA userspace libraries without touching kernel drivers, and installs a Sunshine build compatible with environments that lack physical input devices. The result is a stable, low-latency gaming and streaming setup suitable for AI servers, cloud GPUs, and restricted virtual machines.

## Features

- Automated setup for Ubuntu headless systems
- Lightweight LXQt desktop environment
- Headless Xorg configuration with virtual EDID monitor
- Works without a physical display or monitor
- Supports environments without /dev/input ( use custom build sunshine )
- Compatible with systems where /dev/dri is restricted or unavailable
- Completes missing NVIDIA userspace libraries only
- Does not replace or rebuild provider kernel drivers
- Uses official NVIDIA proprietary components
- Installs Sunshine custom build with legacy input support
- Ready for Sunshine + Moonlight streaming

## Installation

Run the script as a normal user with sudo privileges
Do not run the script as root. The script will exit if executed directly as root.

## Requirements

- Ubuntu (headless, 22.04 or newer recommended)
- NVIDIA GPU
- Provider-installed NVIDIA kernel driver
- Working nvidia-smi
- Internet access

# Notes:
- using sunshine custom build from [![lunarlattice0](https://img.shields.io/badge/lunarlattice0-GitHub-181717?logo=github&logoColor=white)](https://github.com/lunarlattice0/Sunshine-RestoreLegacyInput) for those who don't have access to /dev/input
- Tested on ubuntu 22.04 & 24.04
- Tested on koyeb,saturn cloud,google colab

## TODO

### Priority: Must-have (reliability)
- [ ] Finish Sunshine installation (currently WIP): install the correct build (including the legacy/no-`/dev/input` build when needed) and make it runnable immediately after install.
- [ ] Add proper autostart:
  - systemd service when systemd exists
  - a clean fallback method for non-systemd environments
- [ ] Make Vulkan ICD configuration smarter (no hardcoded paths). Detect the correct NVIDIA Vulkan ICD/library from the extracted driver files and generate the JSON automatically.
- [ ] Improve NVIDIA BusID detection so it works with both `00:04.0` and `0000:00:04.0` formats (with a safe fallback).
- [ ] Make Xorg configuration more compatible by not forcing `DFP-0` by default (keep it optional), and add a fallback if that output doesn’t exist.
- [ ] Add a post-install “smoke test” that clearly reports what works:
  - Can Xorg start?
  - Does `glxinfo` show the NVIDIA renderer (when available)?
  - Does `vulkaninfo` see the driver (when available)?
  - Is Sunshine running and reachable?

### Priority: Stability & portability
- [ ] Add non-interactive mode for automation/CI (`--yes`, `--driver 570`, `--skip-steam`, `--skip-chrome`, `--skip-wine`, `--headless-only`).
- [ ] Improve download reliability (retries + timeouts), and add basic integrity checks (at least SHA256 for `drivers.json` and key driver packages).
- [ ] Avoid copying NVIDIA userspace directly into `/usr/lib` when possible. Prefer an isolated install path (e.g. `/opt/nvidia-<ver>/`) plus `ld.so.conf.d` so it’s less likely to break apt/system libraries.
- [ ] Add better OS/repo checks (Ubuntu 22.04/24.04 detection, ensure `universe` is enabled, use `DEBIAN_FRONTEND=noninteractive` where needed).

### Priority: Quality of life
- [ ] Write logs to a file (e.g. `~/.gameless/install.log`) to make debugging and issue reports easier.
- [ ] Clean up temporary files and partial downloads automatically.
- [ ] Print a clear final summary: installed / skipped / failed + exact “how to start” commands.
- [ ] Add a Troubleshooting section for common issues (Xorg lock files, missing `/dev/dri`, restricted permissions, no input devices, black screen, audio).

### Nice-to-have (future)
- [ ] Add a proper AMD path (Mesa + headless Xorg config + testing).
- [ ] Offer multiple EDID presets (720p/1080p/1440p/4K and refresh rate options).
- [ ] Optional desktop choices via flags (LXQt default, XFCE/KDE-minimal optional).
- [ ] Provide recommended Sunshine presets for Moonlight (bitrate, codec, encoder settings, FEC/QP).
```0
