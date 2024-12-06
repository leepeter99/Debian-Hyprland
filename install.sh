#!/usr/bin/env bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}==> ${1}${NC}"
}

echo_success() {
    echo -e "${GREEN}==> ${1}${NC}"
}

echo_error() {
    echo -e "${RED}==> ${1}${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo_error "Please do not run as root"
    exit 1
fi

# Install required packages
echo_step "Installing required packages..."
sudo apt update
sudo apt install -y curl wget git xorg build-essential

# Install Nix (Multi-user installation)
echo_step "Installing Nix (Multi-user)..."
sh <(curl -L https://nixos.org/nix/install) --daemon

# Source Nix
. /etc/profile.d/nix.sh

# Configure Nix
echo_step "Configuring Nix..."
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
max-jobs = auto
trusted-users = root $USER
EOF

# Install Home Manager
echo_step "Installing Home Manager..."
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install

# Create initial flake configuration
echo_step "Creating Nix flake configuration..."
mkdir -p ~/.config/nixpkgs
cd ~/.config/nixpkgs

# Initialize flake
cat > flake.nix << 'EOF'
{
  description = "Home Manager Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { nixpkgs, home-manager, hyprland, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."$USER" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          hyprland.homeManagerModules.default
          {
            home.username = "$USER";
            home.homeDirectory = "/home/$USER";
            home.stateVersion = "23.11";

            # Enable home-manager
            programs.home-manager.enable = true;

            # Enable Hyprland
            wayland.windowManager.hyprland.enable = true;

            # Install packages
            home.packages = with pkgs; [
              # Development tools
              vscode
              android-studio
              flutter
              android-tools
              git

              # Browser
              brave

              # System tools
              brightnessctl
              pamixer
              networkmanagerapplet
              waybar
              wofi
              dunst

              # Terminal
              kitty
              zsh
              oh-my-zsh
            ];
          }
        ];
      };
    };
}
EOF

# Create initial Hyprland configuration
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = dunst
exec-once = nm-applet

# Some default env vars
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# General window layout
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move windows to workspaces
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
EOF

# Install SDDM
echo_step "Installing SDDM..."
sudo apt install -y sddm
sudo systemctl enable sddm

# Configure NVIDIA
echo_step "Setting up NVIDIA drivers..."
sudo apt install -y nvidia-driver

# Create a wrapper script for Hyprland with NVIDIA settings
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

# Setup Android development environment
echo_step "Setting up Android development environment..."
cat >> ~/.zshrc << 'EOF'
# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
EOF

# Initialize Nix flake
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
