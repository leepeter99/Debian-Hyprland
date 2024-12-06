#!/usr/bin/env bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}==> ${1}${NC}"
}

echo_success() {
    echo -e "${GREEN}==> ${1}${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Create local bin directory for scripts
echo_step "Creating Hyprland starter script..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/start-hyprland << 'EOF'
#!/bin/bash

export LIBVA_DRIVER_NAME=nvidia
export XDG_SESSION_TYPE=wayland
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER=vulkan

exec Hyprland
EOF
chmod +x ~/.local/bin/start-hyprland

# Create Wayland session file with sudo
echo_step "Creating Wayland session file (requires sudo)..."
cat > /tmp/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=$HOME/.local/bin/start-hyprland
Type=Application
EOF

sudo mv /tmp/hyprland.desktop /usr/share/wayland-sessions/hyprland.desktop
sudo chmod 644 /usr/share/wayland-sessions/hyprland.desktop

# Setup Android development environment if not already done
echo_step "Setting up Android development environment..."
if ! grep -q "ANDROID_HOME" ~/.zshrc; then
    cat >> ~/.zshrc << 'EOF'
# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
EOF
fi

# Initialize Nix flake if not already done
echo_step "Initializing Nix flake..."
cd ~/.config/nixpkgs
nix flake update
home-manager switch --flake .#$USER

echo_success "Installation complete! Please reboot your system."
echo "After reboot, select Hyprland session in SDDM and log in."
echo "Default keybindings:"
echo "  Super + Return: Open terminal"
echo "  Super + Q: Close window"
echo "  Super + R: Open application launcher"
echo "  Super + M: Exit Hyprland"
