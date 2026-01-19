#Gaming on AI Servers

Sunshine Headless Gaming & Streaming Stack for Ubuntu
An automated installation script that turns Ubuntu headless AI servers and cloud GPU instances into a fully functional gaming and streaming environment using Sunshine, Xorg, and NVIDIA GPUs, even in restricted or compute-focused setups.

##Description

AI servers and cloud GPU platforms are typically optimized for compute workloads such as machine learning, rendering, or batch processing. While many providers expose NVIDIA GPUs and ship a working kernel driver, the graphics stack required for interactive use is often incomplete or restricted. In practice, this results in systems where nvidia-smi works correctly but graphical applications fail to start.
Common limitations include missing physical displays, lack of input devices, partial NVIDIA userspace installations, and in some environments restricted access to /dev/dri. These constraints make it difficult to run software such as Sunshine, desktop environments, or game launchers on headless infrastructure.
This project provides a complete and automated solution for these environments. The script installs a lightweight desktop environment, configures a headless Xorg session with a virtual display, completes missing NVIDIA userspace libraries without touching kernel drivers, and installs a Sunshine build compatible with environments that lack physical input devices. The result is a stable, low-latency gaming and streaming setup suitable for AI servers, cloud GPUs, and restricted virtual machines.

##Features

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

##Installation

Run the script as a normal user with sudo privileges
Do not run the script as root. The script will exit if executed directly as root.

##Requirements

- Ubuntu (headless, 22.04 or newer recommended)
- NVIDIA GPU
- Provider-installed NVIDIA kernel driver
- Working nvidia-smi
- Internet access

Notes:


