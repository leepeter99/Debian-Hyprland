#!/bin/bash

# Install required dependencies
setup_dependencies() {
    echo "Installing required dependencies..."
    sudo apt update
    sudo apt install -y curl git wget xz-utils build-essential
}

# Install Nix package manager
install_nix() {
    echo "Installing Nix..."
    sh <(curl -L https://nixos.org/nix/install) --daemon

    # Source Nix
    . /etc/profile.d/nix.sh

    # Enable flakes
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
}

# Install Nix Manager
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
    sudo apt install -y nvidia-driver firmware-misc-nonfree
}

# Create basic flake configuration
create_flake_config() {
    mkdir -p ~/.config/nixpkgs
    cat > ~/.config/nixpkgs/flake.nix << 'EOF'
{
  description = "Home Manager configuration";

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

            programs.home-manager.enable = true;

            home.packages = with pkgs; [
              flutter
              android-studio
              vscode
              git
              wget
              firefox
            ];

            wayland.windowManager.hyprland = {
              enable = true;
              settings = {
                # Basic Hyprland configuration
                monitor = "eDP-1,1920x1080@60,0x0,1";
                exec-once = ["firefox"];
              };
            };
          }
        ];
      };
    };
}
EOF
}

# Setup custom bash configuration
setup_bash() {
    echo "Setting up custom bash configuration..."
    wget -O ~/.bashrc https://raw.githubusercontent.com/ChrisTitusTech/mybash/main/.bashrc
    source ~/.bashrc
}

# Main setup function
main() {
    setup_dependencies
    install_nix
    install_home_manager
    setup_nvidia
    create_flake_config
    setup_bash
    
    echo "Installation completed! Please reboot your system."
    echo "After reboot, run: 'home-manager switch' to apply the configuration."
}

# Run main setup
main
