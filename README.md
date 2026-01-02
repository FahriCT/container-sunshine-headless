Container Sunshine Headless is a fully automated setup to run Sunshine on headless Linux environments such as containers,without requiring /dev/ acces
This project uses:
Sunshine AppImage (no build required)
Xorg dummy display
XTEST legacy input for keyboard and mouse injection
It is designed for environments where standard input devices are unavailable or restricted

Limitations
Uses XTEST legacy input, not raw input
Not suitable for competitive FPS games
Requires Xorg (Wayland not supported)
NVIDIA GPU required for NVENC (software encoding fallback available)
