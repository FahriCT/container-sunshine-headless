
---

Sunshine Headless Auto Installer (Ubuntu)

Automated installation script for Sunshine + lightweight GUI on Ubuntu headless systems, designed for cloud GPUs, VMs, and containers.
Supports NVIDIA official drivers, including environments without /dev/input and without /dev/dri.

This project is intended for remote gaming and GPU streaming using Sunshine + Moonlight on headless servers.


---

Features

Automated installation of Sunshine and GUI

Fully compatible with Ubuntu headless environments

Automatic detection and selection of Sunshine build

Supports systems without /dev/input

Works without /dev/dri when using official NVIDIA drivers

Optimized for cloud GPU instances and VMs


---

Sunshine Build Modes

Mode 1: Official Sunshine (Default)

Used when the system provides:

/dev/input

Installs the official Sunshine release

Recommended for bare metal or full VM environments



---

Mode 2: Custom Legacy Input Build

Automatically selected when:

/dev/input is NOT present

Uses a custom Sunshine build with restored legacy input support

Designed for cloud, VM, and container environments

Enables Sunshine input handling without physical input devices


---

GPU and Graphics Support

NVIDIA GPU Required

This script does not require /dev/dri as long as:

Official NVIDIA driver is installed

nvidia-smi works correctly

NVIDIA OpenGL is active and functional


Supported and tested GPUs include:

Tesla T4
NVIDIA L4, L40, L40S
RTX A6000

---

Desktop Environment

The script installs a lightweight desktop environment suitable for headless usage:

XFCE or LXQt (script dependent)

No heavy display manager required

Optimized for Xorg headless operation with Sunshine



---

What the Script Does

Installs Xorg and required GUI components

Configures NVIDIA OpenGL for headless rendering

Sets up a virtual display using EDID

Installs Sunshine (official or custom build automatically)

Applies required permission fixes for input and rendering

Prepares the system for immediate use with Moonlight



---

Installation



After installation:

Open the Sunshine web interface

Pair with Moonlight

Start streaming



---

Requirements and Notes

Official NVIDIA driver is mandatory

Wayland is not supported

Xorg is required

Designed for headless servers, cloud GPUs, and VMs



---

Use Cases

Cloud gaming servers

Remote GPU desktops

Game streaming at 1080p or 4K

GPU server testing

Sunshine and Moonlight deployment in 
