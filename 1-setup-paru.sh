#!/usr/bin/env bash

# Exit on any error
set -e

if ! command -v paru &> /dev/null; then
    echo "Paru not found. Installing..."
    # Store current directory
    START_DIR=$(pwd)

    # Installing paru
    sudo pacman -S --needed --noconfirm base-devel
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm

    # Return to original directory
    cd "$START_DIR"

    # Clean up the cloned directory
    rm -rf "$START_DIR/paru"
else
    echo "Paru is already installed!"
fi
