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

# Source Nix
echo_step "Sourcing Nix environment..."
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
elif [ -e '$HOME/.nix-profile/etc/profile.d/nix.sh' ]; then
    . '$HOME/.nix-profile/etc/profile.d/nix.sh'
else
    echo_error "Nix environment files not found. Reinstalling Nix..."
    sh <(curl -L https://nixos.org/nix/install) --daemon
    
    # Source the newly installed Nix
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Verify Nix is available
if ! command -v nix &> /dev/null; then
    echo_error "Nix command still not available. Please run these commands manually:"
    echo "1. . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    echo "2. Run this script again"
    exit 1
fi

echo_step "Verifying Nix installation..."
nix --version

# Install home-manager if not already installed
echo_step "Ensuring home-manager is installed..."
if ! command -v home-manager &> /dev/null; then
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    nix-shell '<home-manager>' -A install
fi

# Backup existing configuration
echo_step "Backing up existing configuration..."
if [ -d ~/.config/nixpkgs ]; then
    mv ~/.config/nixpkgs ~/.config/nixpkgs.bak-$(date +%Y%m%d-%H%M%S)
fi

# Create new configuration directory
echo_step "Creating new Nix configuration..."
mkdir -p ~/.config/nixpkgs

# Create flake.nix
cat > ~/.config/nixpkgs/flake.nix << EOF
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
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      homeConfigurations.${USER} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home.nix
          hyprland.homeManagerModules.default
        ];
      };
    };
}
EOF

# Create home.nix
cat > ~/.config/nixpkgs/home.nix << EOF
{ config, pkgs, ... }:

{
  home.username = "$USER";
  home.homeDirectory = "/home/$USER";
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable Hyprland
  wayland.windowManager.hyprland.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Packages to install
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

    # Additional utilities
    xdg-utils
    xdg-desktop-portal-hyprland
    polkit-kde-agent
  ];

  # Basic Git configuration
  programs.git = {
    enable = true;
    userName = "$USER";
    userEmail = "$USER@localhost";
  };

  # Terminal configuration
  programs.kitty = {
    enable = true;
    theme = "Tokyo Night";
  };
}
EOF

# Create Hyprland configuration directory and file
echo_step "Creating Hyprland configuration..."
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = dunst
exec-once = nm-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1

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

# Create the Hyprland starter script
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

# Create Wayland session file
echo_step "Creating Wayland session file..."
cat > /tmp/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=$HOME/.local/bin/start-hyprland
Type=Application
EOF

sudo mv /tmp/hyprland.desktop /usr/share/wayland-sessions/hyprland.desktop
sudo chmod 644 /usr/share/wayland-sessions/hyprland.desktop

# Enable experimental features for Nix
echo_step "Enabling Nix experimental features..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Initialize and update flake
echo_step "Initializing and updating Nix flake..."
cd ~/.config/nixpkgs
nix flake update

# Apply configuration
echo_step "Applying home-manager configuration..."
home-manager switch --flake .#$USER

echo_success "Configuration updated successfully!"
echo "Please reboot your system and select Hyprland from the SDDM login screen."
echo ""
echo "Key bindings:"
echo "  Super + Return: Open terminal"
echo "  Super + Q: Close window"
echo "  Super + R: Open application launcher"
echo "  Super + M: Exit Hyprland"
