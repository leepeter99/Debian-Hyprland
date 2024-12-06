#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[+] $1${NC}"
}

error() {
    echo -e "${RED}[!] $1${NC}"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install required packages
install_prerequisites() {
    log "Installing prerequisites..."
    apt-get update
    apt-get install -y curl xz-utils sudo systemd

    # Install nvidia drivers
    apt-get install -y nvidia-driver firmware-misc-nonfree
}

# Install Nix
install_nix() {
    log "Installing Nix (multi-user)..."
    if ! command_exists nix; then
        curl -L https://nixos.org/nix/install | sh -s -- --daemon
        
        # Source nix
        . /etc/profile.d/nix.sh
    else
        log "Nix is already installed"
    fi
}

# Configure Nix
configure_nix() {
    log "Configuring Nix..."
    mkdir -p /etc/nix
    cat > /etc/nix/nix.conf << EOF
experimental-features = nix-command flakes
trusted-users = root $USER
max-jobs = auto
cores = 0
sandbox = true
EOF
}

# Setup Home Manager
setup_home_manager() {
    log "Setting up Home Manager..."
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    
    # Create initial home manager configuration
    mkdir -p ~/.config/nixpkgs
    cat > ~/.config/nixpkgs/home.nix << EOF
{ config, pkgs, ... }:

{
  home.username = "$USER";
  home.homeDirectory = "/home/$USER";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    brave
    vscode
    android-studio
    android-tools
    flutter
    git
    kitty
    waybar
    wofi
    dunst
  ];

  programs.kitty = {
    enable = true;
    theme = "Tokyo Night";
    settings = {
      font_family = "JetBrains Mono";
      font_size = 11;
      background_opacity = "0.95";
    };
  };
}
EOF
}

# Setup Hyprland
setup_hyprland() {
    log "Setting up Hyprland..."
    
    # Create Hyprland configuration directory
    mkdir -p ~/.config/hypr
    
    cat > ~/.config/hypr/hyprland.conf << EOF
# Monitor configuration
monitor=eDP-1,1920x1080@60,0x0,1

# Execute at launch
exec-once = waybar
exec-once = dunst
exec-once = hyprpaper

# NVIDIA specific
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# Basic configuration
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0 # -1.0 - 1.0, 0 means no modification
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur = yes
    blur_size = 3
    blur_passes = 1
    blur_new_optimizations = on
}

animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = yes
    preserve_split = yes
}

master {
    new_is_master = true
}

gestures {
    workspace_swipe = off
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$

# Key bindings
$mainMod = SUPER

bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, Q, killactive, 
bind = $mainMod, M, exit, 
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating, 
bind = $mainMod, D, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Move focus
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

# Move active window to workspace
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
}

# Setup display manager
setup_display_manager() {
    log "Setting up SDDM..."
    apt-get install -y sddm
    
    # Create Wayland session file
    cat > /usr/share/wayland-sessions/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    
    chmod 644 /usr/share/wayland-sessions/hyprland.desktop
    
    # Enable SDDM
    systemctl enable sddm
}

# Create flake configuration
create_flake() {
    log "Creating flake configuration..."
    mkdir -p ~/nixos-config
    cd ~/nixos-config
    
    cat > flake.nix << EOF
{
  description = "NixOS configuration with home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
    in
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          hyprland.nixosModules.default
          {
            programs.hyprland = {
              enable = true;
              xwayland.enable = true;
              systemd.enable = true;
            };
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.$USER = import ./home.nix;
          }
        ];
      };
    };
}
EOF

    cat > flake.lock << EOF
{
  "nodes": {
    "nixpkgs": {
      "locked": {
        "lastModified": 1709428628,
        "narHash": "sha256-//zp2ZnJ6UKwqvAzKH8GvvEv3yQQc80Yzz2E0PQoXq4=",
        "owner": "nixos",
        "repo": "nixpkgs",
        "rev": "5e871d8aa6f57cc8e0dc087d3bb3608fb3bd8a14",
        "type": "github"
      },
      "original": {
        "owner": "nixos",
        "ref": "nixos-unstable",
        "repo": "nixpkgs",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "nixpkgs": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
EOF
}

main() {
    check_root
    install_prerequisites
    install_nix
    configure_nix
    setup_home_manager
    setup_hyprland
    setup_display_manager
    create_flake
    
    log "Setup complete! Please reboot your system."
    log "After reboot, run 'home-manager switch' to activate your configuration."
}

main "$@"
