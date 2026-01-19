#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' 

DRIVER_JSON_URL="https://raw.githubusercontent.com/FahriCT/container-sunshine-headless/refs/heads/main/drivers.json"
DRIVER_JSON_LOCAL="$HOME/.gameless/drivers.json"
DRIVER_JSON_FALLBACK="./drivers.json"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[DETECT]${NC} $1"
}

success() {
    echo -e "${CYAN}[OK]${NC} $1"
}

banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║        Gameless Installer v1.0            ║"
    echo "║   GPU Passthrough & Desktop Environment   ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}


if [ "$EUID" -eq 0 ]; then
    error "Do NOT run this script as root. Run as normal user with sudo privileges."
fi

if ! sudo -n true 2>/dev/null; then
    error "This script requires sudo privileges. Please run as a user with sudo access."
fi

banner

# ============================================
# Download/Load drivers.json
# ============================================

log "Loading driver configuration..."
mkdir -p "$HOME/.gameless"


if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    info "Attempting to download latest drivers.json..."
    
    if command -v wget >/dev/null 2>&1; then
        if wget -q -O "$DRIVER_JSON_LOCAL.tmp" "$DRIVER_JSON_URL" 2>/dev/null; then
            mv "$DRIVER_JSON_LOCAL.tmp" "$DRIVER_JSON_LOCAL"
            success "Downloaded latest drivers.json from repository"
            DRIVER_JSON="$DRIVER_JSON_LOCAL"
        else
            warn "Failed to download drivers.json from URL"
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -fsSL -o "$DRIVER_JSON_LOCAL.tmp" "$DRIVER_JSON_URL" 2>/dev/null; then
            mv "$DRIVER_JSON_LOCAL.tmp" "$DRIVER_JSON_LOCAL"
            success "Downloaded latest drivers.json from repository"
            DRIVER_JSON="$DRIVER_JSON_LOCAL"
        else
            warn "Failed to download drivers.json from URL"
        fi
    fi
fi


if [ ! -f "$DRIVER_JSON" ] || [ ! -s "$DRIVER_JSON" ]; then
    if [ -f "$DRIVER_JSON_FALLBACK" ]; then
        log "Using local drivers.json file"
        cp "$DRIVER_JSON_FALLBACK" "$DRIVER_JSON_LOCAL"
        DRIVER_JSON="$DRIVER_JSON_LOCAL"
        success "Loaded drivers.json from current directory"
    else
        error "drivers.json not found! Please ensure drivers.json is in the same directory or accessible online at: $DRIVER_JSON_URL"
    fi
fi


if command -v jq >/dev/null 2>&1 || sudo apt install -y jq 2>/dev/null; then
    if ! jq empty "$DRIVER_JSON" 2>/dev/null; then
        error "Invalid JSON format in drivers.json"
    fi
    success "drivers.json validated successfully"
    
    # Show metadata
    DRIVER_VERSION=$(jq -r '.metadata.version // "unknown"' "$DRIVER_JSON" 2>/dev/null)
    DRIVER_UPDATED=$(jq -r '.metadata.last_updated // "unknown"' "$DRIVER_JSON" 2>/dev/null)
    info "Driver database version: $DRIVER_VERSION (updated: $DRIVER_UPDATED)"
else
    warn "jq not available, skipping JSON validation"
fi

echo ""

# ============================================
# Install pciutils first for GPU detection
# ============================================

log "Installing pciutils for hardware detection..."
sudo apt update -qq
sudo apt install -y pciutils || warn "Failed to install pciutils"
echo ""

# ============================================
# System Detection
# ============================================

log "Performing system detection..."
echo ""

info "Checking for systemd..."
HAS_SYSTEMD=false
if [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
    success "systemd detected"
else
    warn "systemd NOT detected - will use alternative init methods"
fi
echo ""

info "Checking /dev/dri access..."
HAS_DRI=false
if [ -d /dev/dri ]; then
    if ls /dev/dri/card* >/dev/null 2>&1 || ls /dev/dri/renderD* >/dev/null 2>&1; then
        HAS_DRI=true
        success "/dev/dri is accessible"
        ls -la /dev/dri/ 2>/dev/null | grep -E "card|render" || true
    else
        warn "/dev/dri exists but no devices found"
    fi
else
    warn "/dev/dri does NOT exist"
fi
echo ""

info "Checking /dev/input access..."
HAS_INPUT=false
if [ -d /dev/input ]; then
    if ls /dev/input/event* >/dev/null 2>&1; then
        HAS_INPUT=true
        success "/dev/input is accessible"
        INPUT_COUNT=$(ls /dev/input/event* 2>/dev/null | wc -l)
        echo "  Found $INPUT_COUNT input devices"
    else
        warn "/dev/input exists but no event devices found"
    fi
else
    warn "/dev/input does NOT exist"
fi
echo ""

info "Detecting GPU..."
GPU_VENDOR="unknown"
NVIDIA_BUSID=""

if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -i nvidia >/dev/null; then
        GPU_VENDOR="nvidia"
        success "NVIDIA GPU detected"
        
        # Display GPU info
        GPU_INFO=$(lspci | grep -i vga | grep -i nvidia || lspci | grep -i 3d | grep -i nvidia || echo "")
        if [ -n "$GPU_INFO" ]; then
            echo "  $GPU_INFO"
        fi
        
        # Extract BusID (format: domain:bus:device.function -> PCI:bus:device:function)
        BUSID_RAW=$(lspci | grep -i nvidia | grep -iE "vga|3d" | head -n1 | awk '{print $1}')
        if [ -n "$BUSID_RAW" ]; then
            # Convert from 00:04.0 to PCI:0:4:0 format
            DOMAIN=$(echo $BUSID_RAW | cut -d: -f1 | sed 's/^0*//')
            BUS=$(echo $BUSID_RAW | cut -d: -f2 | cut -d. -f1 | sed 's/^0*//')
            DEVICE=$(echo $BUSID_RAW | cut -d. -f2 | sed 's/^0*//')
            
            # Handle empty values (0 becomes empty after sed)
            [ -z "$DOMAIN" ] && DOMAIN="0"
            [ -z "$BUS" ] && BUS="0"
            [ -z "$DEVICE" ] && DEVICE="0"
            
            NVIDIA_BUSID="PCI:${DOMAIN}:${BUS}:${DEVICE}"
            success "Detected BusID: $NVIDIA_BUSID (raw: $BUSID_RAW)"
        else
            warn "Could not detect NVIDIA BusID, will use default PCI:0:4:0"
            NVIDIA_BUSID="PCI:0:4:0"
        fi
        
    elif lspci | grep -i amd >/dev/null; then
        GPU_VENDOR="amd"
        success "AMD GPU detected"
        GPU_INFO=$(lspci | grep -i vga | grep -i amd || lspci | grep -i 3d | grep -i amd || echo "")
        if [ -n "$GPU_INFO" ]; then
            echo "  $GPU_INFO"
        fi
    else
        warn "GPU vendor could not be determined"
    fi
else
    error "lspci not available even after attempting to install pciutils"
fi
echo ""

log "System Detection Summary:"
echo "  - systemd: $([ "$HAS_SYSTEMD" = true ] && echo "✓" || echo "✗")"
echo "  - /dev/dri: $([ "$HAS_DRI" = true ] && echo "✓" || echo "✗")"
echo "  - /dev/input: $([ "$HAS_INPUT" = true ] && echo "✓" || echo "✗")"
echo "  - GPU Vendor: $GPU_VENDOR"
if [ "$GPU_VENDOR" = "nvidia" ]; then
    echo "  - NVIDIA BusID: $NVIDIA_BUSID"
fi
echo ""

if [ "$GPU_VENDOR" != "nvidia" ] && [ "$GPU_VENDOR" != "amd" ]; then
    warn "No supported GPU detected (NVIDIA or AMD required)"
    read -p "Continue anyway without GPU driver installation? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    SKIP_GPU=true
else
    SKIP_GPU=false
fi

# ============================================
# Driver Selection Menu
# ============================================

if [ "$SKIP_GPU" = false ] && [ "$GPU_VENDOR" = "nvidia" ]; then
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NVIDIA Driver Selection           ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    
    if command -v jq >/dev/null 2>&1; then
        # Parse available NVIDIA drivers from JSON
        declare -A DRIVER_MAP
        declare -A DRIVER_NAME
        declare -A DRIVER_DESC
        declare -A DRIVER_UBUNTU
        
        # Get all NVIDIA driver versions sorted
        VERSIONS=$(jq -r '.nvidia | keys[]' "$DRIVER_JSON" 2>/dev/null | sort -n)
        
        if [ -z "$VERSIONS" ]; then
            error "No NVIDIA drivers found in drivers.json"
        fi
        
        DRIVER_COUNT=1
        for version in $VERSIONS; do
            DRIVER_MAP[$DRIVER_COUNT]=$version
            DRIVER_NAME[$DRIVER_COUNT]=$(jq -r ".nvidia.\"$version\".name" "$DRIVER_JSON")
            DRIVER_DESC[$DRIVER_COUNT]=$(jq -r ".nvidia.\"$version\".description" "$DRIVER_JSON")
            DRIVER_UBUNTU[$DRIVER_COUNT]=$(jq -r ".nvidia.\"$version\".ubuntu_version" "$DRIVER_JSON")
            ((DRIVER_COUNT++))
        done
        
        DEFAULT_DRIVER=$(jq -r '.metadata.default_nvidia // "570"' "$DRIVER_JSON")
        DEFAULT_INDEX=0
        for idx in "${!DRIVER_MAP[@]}"; do
            if [ "${DRIVER_MAP[$idx]}" = "$DEFAULT_DRIVER" ]; then
                DEFAULT_INDEX=$idx
                break
            fi
        done
        
        echo -e "${CYAN}Select your driver:${NC}"
        echo ""
        
        for idx in $(seq 1 $((DRIVER_COUNT-1))); do
            version="${DRIVER_MAP[$idx]}"
            name="${DRIVER_NAME[$idx]}"
            desc="${DRIVER_DESC[$idx]}"
            ubuntu="${DRIVER_UBUNTU[$idx]}"
            
            if [ "$idx" -eq "$DEFAULT_INDEX" ]; then
                echo -e "  ${GREEN}$idx)${NC} ${YELLOW}★${NC} Driver ${CYAN}$version${NC} - $name"
                echo -e "      $desc"
                echo -e "      Target: Ubuntu $ubuntu ${YELLOW}(Recommended)${NC}"
            else
                echo -e "  ${GREEN}$idx)${NC} Driver ${CYAN}$version${NC} - $name"
                echo -e "      $desc"
                echo -e "      Target: Ubuntu $ubuntu"
            fi
            echo ""
        done
        
        if [ "$DEFAULT_INDEX" -gt 0 ]; then
            echo -e "${YELLOW}★${NC} = Recommended driver"
            echo ""
            read -p "Enter your choice [1-$((DRIVER_COUNT-1))] (default: $DEFAULT_INDEX): " DRIVER_CHOICE
            
            if [ -z "$DRIVER_CHOICE" ]; then
                DRIVER_CHOICE=$DEFAULT_INDEX
                log "Using default driver: ${DRIVER_NAME[$DEFAULT_INDEX]}"
            fi
        else
            read -p "Enter your choice [1-$((DRIVER_COUNT-1))]: " DRIVER_CHOICE
        fi
        
        if ! [[ "$DRIVER_CHOICE" =~ ^[0-9]+$ ]] || [ "$DRIVER_CHOICE" -lt 1 ] || [ "$DRIVER_CHOICE" -ge "$DRIVER_COUNT" ]; then
            error "Invalid selection: $DRIVER_CHOICE"
        fi
        
        if [ -z "${DRIVER_MAP[$DRIVER_CHOICE]}" ]; then
            error "Driver not found for selection: $DRIVER_CHOICE"
        fi
        
        NVIDIA_VERSION="${DRIVER_MAP[$DRIVER_CHOICE]}"
        SELECTED_NAME="${DRIVER_NAME[$DRIVER_CHOICE]}"
        SELECTED_DESC="${DRIVER_DESC[$DRIVER_CHOICE]}"
        
        echo ""
        echo -e "${MAGENTA}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║         Driver Configuration              ║${NC}"
        echo -e "${MAGENTA}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        
        NVIDIA_BUILD_ID=$(jq -r ".nvidia.\"$NVIDIA_VERSION\".build_id" "$DRIVER_JSON")
        NVIDIA_UBUNTU_VER=$(jq -r ".nvidia.\"$NVIDIA_VERSION\".ubuntu_version" "$DRIVER_JSON")
        BASE_URL=$(jq -r ".nvidia.\"$NVIDIA_VERSION\".base_url" "$DRIVER_JSON")
        
        mapfile -t NVIDIA_PACKAGES < <(jq -r ".nvidia.\"$NVIDIA_VERSION\".packages[]" "$DRIVER_JSON")
        
        log "Selected Driver: ${CYAN}$SELECTED_NAME${NC}"
        echo "  Version: $NVIDIA_VERSION"
        echo "  Description: $SELECTED_DESC"
        echo "  Build ID: $NVIDIA_BUILD_ID"
        echo "  Target Ubuntu: $NVIDIA_UBUNTU_VER"
        echo "  Total packages: ${#NVIDIA_PACKAGES[@]}"
        echo "  Download URL: $BASE_URL"
        echo "  BusID: $NVIDIA_BUSID"
        echo ""
        
        read -p "Proceed with this driver? [Y/n]: " CONFIRM_DRIVER
        if [[ "$CONFIRM_DRIVER" =~ ^[Nn]$ ]]; then
            error "Installation cancelled by user"
        fi
        
    else
        error "jq is required to parse drivers.json but is not available"
    fi
    
elif [ "$SKIP_GPU" = false ] && [ "$GPU_VENDOR" = "amd" ]; then
    log "AMD GPU detected - using Mesa open source drivers"
    info "AMD drivers will be installed via apt packages"
    AMD_DRIVER=true
fi

echo ""
read -p "Press Enter to continue with package installation..."
echo ""

# ============================================
# Package Installation
# ============================================

log "Updating system packages..."
sudo apt update || error "Failed to update package list"

log "Configuring keyboard layout..."
sudo tee /etc/default/keyboard > /dev/null << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
EOF

log "Adding i386 architecture..."
sudo dpkg --add-architecture i386
sudo apt update || error "Failed to update after adding i386 architecture"

log "Installing X11 and graphics libraries..."
sudo apt install -y \
  xserver-xorg-core \
  x11-xserver-utils \
  x11-utils \
  xinit \
  dbus-x11 \
  mesa-utils \
  mesa-vulkan-drivers \
  libglvnd0 \
  libdrm2 \
  libegl1 \
  libgl1 \
  libglx-mesa0 \
  libgl1-mesa-dri \
  libx11-6 \
  libxext6 \
  libxrandr2 \
  libxcb1 \
  libxinerama1 \
  libxi6 \
  libxtst6 \
  libxdamage1 \
  libxfixes3 \
  libx11-xcb1 \
  libxcb-dri3-0 \
  libxcb-present0 \
  libxcb-sync1 \
  libxshmfence1 \
  libvulkan1 \
  vulkan-tools \
  jq || error "Failed to install X11/graphics packages"

log "Installing LXQt desktop environment..."
sudo apt install -y \
  lxqt \
  lxqt-core \
  lxqt-panel \
  lxqt-session \
  lxqt-config \
  lxqt-policykit \
  lxqt-qtplugin \
  openbox || error "Failed to install LXQt"

log "Installing system utilities..."
sudo apt install -y \
  nano \
  tmux \
  fuse3 \
  git \
  curl \
  wget \
  unzip \
  pulseaudio \
  pavucontrol \
  network-manager \
  fuse \
  network-manager-gnome || error "Failed to install utilities"

log "Installing Wine and 32-bit libraries..."
sudo apt install -y \
  wine32 \
  libwine:i386 \
  libvulkan1:i386 \
  mesa-vulkan-drivers:i386 \
  libgnutls30:i386 \
  libldap-2.5-0:i386 \
  libgpg-error0:i386 \
  libxml2:i386 \
  libasound2-plugins:i386 \
  libsdl2-2.0-0:i386 \
  libfreetype6:i386 \
  libdbus-1-3:i386 \
  libsqlite3-0:i386 \
  lib32gcc-s1 \
  lib32stdc++6 \
  libc6-i386 \
  libgl1-mesa-dri:i386 \
  libgl1:i386 \
  libglx-mesa0:i386 || warn "Some Wine dependencies failed to install"

log "Installing Steam..."
sudo apt install -y steam steam-libs-i386:i386 || warn "Failed to install Steam"

log "Installing Google Chrome..."
wget -qO /tmp/google-chrome.gpg https://dl.google.com/linux/linux_signing_key.pub
sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg < /tmp/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
sudo apt update
sudo apt install -y google-chrome-stable || warn "Failed to install Google Chrome"
sudo chown root:root /opt/google/chrome/chrome-sandbox 2>/dev/null || true
sudo chmod 4755 /opt/google/chrome/chrome-sandbox 2>/dev/null || true
rm -f /tmp/google-chrome.gpg

# ============================================
# GPU Driver Installation
# ============================================

if [ "$SKIP_GPU" = false ]; then
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        echo ""
        echo -e "${MAGENTA}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║      Installing NVIDIA $NVIDIA_VERSION Driver           ║${NC}"
        echo -e "${MAGENTA}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        
        log "Creating driver directory..."
        sudo mkdir -p /opt/nvidia-${NVIDIA_VERSION}/deb
        cd /opt/nvidia-${NVIDIA_VERSION}/deb

        log "Downloading ${#NVIDIA_PACKAGES[@]} driver packages..."
        DOWNLOAD_COUNT=0
        DOWNLOAD_SUCCESS=0
        DOWNLOAD_FAILED=0
        
        for package in "${NVIDIA_PACKAGES[@]}"; do
            ((DOWNLOAD_COUNT++))
            if [ ! -f "$package" ]; then
                echo -ne "  [$DOWNLOAD_COUNT/${#NVIDIA_PACKAGES[@]}] Downloading: ${CYAN}$package${NC}..."
                if sudo wget -q -c "${BASE_URL}/${package}"; then
                    echo -e " ${GREEN}✓${NC}"
                    ((DOWNLOAD_SUCCESS++))
                else
                    echo -e " ${RED}✗${NC}"
                    ((DOWNLOAD_FAILED++))
                    warn "Failed to download ${package}"
                fi
            else
                echo -e "  [$DOWNLOAD_COUNT/${#NVIDIA_PACKAGES[@]}] ${YELLOW}Already downloaded:${NC} $package"
                ((DOWNLOAD_SUCCESS++))
            fi
        done
        
        echo ""
        log "Download summary: ${GREEN}$DOWNLOAD_SUCCESS success${NC}, ${RED}$DOWNLOAD_FAILED failed${NC}"
        
        if [ "$DOWNLOAD_SUCCESS" -eq 0 ]; then
            error "No packages were downloaded successfully"
        fi
        
        echo ""
        log "Extracting NVIDIA drivers..."
        sudo mkdir -p /opt/nvidia-${NVIDIA_VERSION}/extract
        EXTRACT_COUNT=0
        for f in *.deb; do
            ((EXTRACT_COUNT++))
            echo -ne "  Extracting $f..."
            if sudo dpkg-deb -x "$f" /opt/nvidia-${NVIDIA_VERSION}/extract 2>/dev/null; then
                echo -e " ${GREEN}✓${NC}"
            else
                echo -e " ${RED}✗${NC}"
                warn "Failed to extract $f"
            fi
        done

        echo ""
        log "Installing NVIDIA libraries..."
        sudo cp -a /opt/nvidia-${NVIDIA_VERSION}/extract/usr/lib/x86_64-linux-gnu/libnvidia* /usr/lib/x86_64-linux-gnu/ 2>/dev/null && success "NVIDIA libraries installed" || warn "Failed to copy NVIDIA libraries"
        sudo cp -a /opt/nvidia-${NVIDIA_VERSION}/extract/usr/lib/x86_64-linux-gnu/nvidia /usr/lib/x86_64-linux-gnu/ 2>/dev/null && success "NVIDIA directory installed" || warn "Failed to copy NVIDIA directory"

        log "Installing NVIDIA Xorg drivers..."
        sudo mkdir -p /usr/lib/xorg/modules/drivers
        sudo cp /opt/nvidia-${NVIDIA_VERSION}/extract/usr/lib/x86_64-linux-gnu/nvidia/xorg/nvidia_drv.so /usr/lib/xorg/modules/drivers/ 2>/dev/null && success "NVIDIA Xorg driver installed" || warn "Failed to copy nvidia_drv.so"

        sudo mkdir -p /usr/lib/xorg/modules/extensions
        sudo cp /opt/nvidia-${NVIDIA_VERSION}/extract/usr/lib/x86_64-linux-gnu/nvidia/xorg/libglxserver_nvidia.so /usr/lib/xorg/modules/extensions/ 2>/dev/null && success "GLX server extension installed" || warn "Failed to copy libglxserver_nvidia.so"

#1080p 60fps
        log "Creating virtual monitor EDID..."
        sudo mkdir -p /usr/lib/nvidia
        sudo bash -c '
EDID_HEX="00ffffffffffff000469888888888888010101010101010101010101010101011d3680a070381e40302035005550210000001a000000fd00384b1e5311000a20202020202020000000fc005669727475616c204d6f6e69746f72000000ff00303030303030303030303030303000000000"
echo "$EDID_HEX" | xxd -r -p > /usr/lib/nvidia/edid.bin
'
        success "Virtual monitor EDID created"

        log "Configuring Xorg..."
        sudo tee /etc/X11/xorg.conf > /dev/null << EOF
Section "ServerLayout"
    Identifier "Layout0"
    Screen 0 "Screen0"
EndSection

Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    BusID "$NVIDIA_BUSID"
    Option "AllowEmptyInitialConfiguration" "true"
    Option "UseDisplayDevice" "DFP-0"
    Option "ConnectedMonitor" "DFP-0"
    Option "CustomEDID" "DFP-0:/usr/lib/nvidia/edid.bin"
    Option "IgnoreDisplayDevices" "CRT,TV"
    Option "NoLogo" "true"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "NVIDIA"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Virtual 1920 1080
    EndSubSection
EndSection
EOF
        success "Xorg configuration created"

        log "Configuring Vulkan ICD..."
        sudo mkdir -p /etc/vulkan/icd.d
        sudo tee /etc/vulkan/icd.d/nvidia_icd.json > /dev/null << 'EOF'
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0",
    "api_version": "1.3.269"
  }
}
EOF
        success "Vulkan ICD configured"

        log "Updating library cache..."
        sudo ldconfig
        success "Library cache updated"
        
        echo ""
        success "NVIDIA $NVIDIA_VERSION driver installation complete!"
        
    elif [ "$GPU_VENDOR" = "amd" ]; then
        log "Installing AMD Mesa drivers..."
        
        if command -v jq >/dev/null 2>&1; then
            mapfile -t AMD_PACKAGES < <(jq -r '.amd.mesa.packages[]' "$DRIVER_JSON" 2>/dev/null)
            
            if [ ${#AMD_PACKAGES[@]} -gt 0 ]; then
                sudo apt install -y "${AMD_PACKAGES[@]}" && success "AMD drivers installed" || warn "Some AMD packages failed to install"
            else
                warn "No AMD packages found in drivers.json"
            fi
        fi
    fi
fi


#wip
