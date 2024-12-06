#!/bin/bash

# Install required dependencies
setup_dependencies() {
    echo "Installing required dependencies..."
    sudo nala update
    sudo nala install -y curl git wget xz-utils build-essential
}

# Install Nix package manager in multi-user mode
install_nix() {
    echo "Installing Nix in multi-user mode..."
    sh <(curl -L https://nixos.org/nix/install) --daemon

    # Source Nix
    . /etc/profile.d/nix.sh

    # Enable flakes and other experimental features system-wide
    sudo mkdir -p /etc/nix
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
    
    # Restart nix-daemon to apply changes
    sudo systemctl restart nix-daemon
}

# Install Home Manager
install_home_manager() {
    echo "Installing Home Manager..."
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    
    # Install home-manager
    nix-shell '<home-manager>' -A install
}

# Configure NVIDIA drivers
setup_nvidia() {
    echo "Setting up NVIDIA drivers..."
    sudo nala install -y nvidia-driver firmware-misc-nonfree
}

# Create basic flake configuration
create_flake_config() {
    mkdir -p ~/.config/nixpkgs
    cat > ~/.config/nixpkgs/flake.nix << 'EOF'
{
  description = "Home Manager configuration";

  inputs = {
    # Using stable channel for better compatibility
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    
    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Hyprland
    hyprland.url = "github:hyprwm/Hyprland";
    
    # Common flake inputs that you might need
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, hyprland, flake-utils, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            # Add any needed insecure packages here
          ];
        };
        overlays = [
          rust-overlay.overlays.default
        ];
      };
    in {
      homeConfigurations."$USER" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          hyprland.homeManagerModules.default
          {
            home = {
              username = "$USER";
              homeDirectory = "/home/$USER";
              stateVersion = "23.11";
              
              # Enable fonts configuration
              packages = with pkgs; [
                # Development
                flutter
                android-studio
                vscode
                git
                gcc
                nodejs
                
                # Hyprland essentials
                kitty
                waybar
                wofi
                grim
                slurp
                wl-clipboard
                
                # System
                firefox
                pavucontrol
                networkmanagerapplet
                
                # Fonts
                (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
              ];
            };

            programs = {
              home-manager.enable = true;
              
              git = {
                enable = true;
                userName = "Your Name";
                userEmail = "your.email@example.com";
              };

              kitty = {
                enable = true;
                settings = {
                  font_family = "JetBrainsMono Nerd Font";
                  font_size = 12;
                  background_opacity = "0.95";
                };
              };
            };

            wayland.windowManager.hyprland = {
              enable = true;
              settings = {
                monitor = "eDP-1,1920x1080@60,0x0,1";
                
                exec-once = [
                  "waybar"
                  "nm-applet --indicator"
                ];
                
                bind = [
                  "SUPER,Return,exec,kitty"
                  "SUPER,Q,killactive,"
                  "SUPER,M,exit,"
                  "SUPER,Space,togglefloating,"
                  "SUPER,D,exec,wofi --show drun"
                  "SUPER,P,pseudo,"
                  
                  # Screenshots
                  "SUPER_SHIFT,S,exec,grim -g \"$(slurp)\" - | wl-copy"
                ];
                
                windowrule = [
                  "float,^(pavucontrol)$"
                  "float,^(nm-connection-editor)$"
                  "float,^(android-studio)$"
                ];

                general = {
                  gaps_in = 5;
                  gaps_out = 10;
                  border_size = 2;
                  "col.active_border" = "rgba(33ccffee)";
                };

                decoration = {
                  rounding = 10;
                  blur = true;
                  blur_size = 3;
                  blur_passes = 1;
                };
              };
            };
          }
        ];
      };
    };
}
EOF

    # Create a shell.nix for development environment
    cat > ~/.config/nixpkgs/shell.nix << 'EOF'
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    flutter
    android-studio
    jdk17
    cmake
    ninja
    pkg-config
    gtk3
    pcre
    dbus
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
  ];

  shellHook = ''
    export CHROME_EXECUTABLE=${pkgs.google-chrome}/bin/google-chrome
  '';
}
EOF
}


# Main setup function
main() {
    setup_dependencies
    install_nix
    install_home_manager
    setup_nvidia
    create_flake_config
    setup_bash
    
    echo "Multi-user Nix installation completed! Please log out and log back in."
    echo ""
    echo "After logging back in:"
    echo "1. Run 'home-manager switch' to apply the configuration"
    echo "2. Edit ~/.config/nixpkgs/flake.nix to customize your setup"
    echo "3. Update git config in the flake with your details"
    echo ""
    echo "Useful commands:"
    echo "- nix-cleanup : Clean up unused packages"
    echo "- flake-update : Update flake inputs"
    echo "- nix-dev : Enter development shell"
    echo ""
    echo "To run other developers' flakes:"
    echo "nix develop github:username/repo"
    echo "nix run github:username/repo"
}

# Run main setup
main
