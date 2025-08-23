#!/usr/bin/env bash

# Exit on any error
set -e

if ! command -v paru &> /dev/null; then
    sudo pacman -S --needed base-devel
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si
else
    echo "Paru is already installed!"
fi
