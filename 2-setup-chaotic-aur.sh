#!/usr/bin/env bash


# Exit on any error
set -e

# Getting the public key to enable installation
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

# Installing the chaotic-keyring and chaotic-mirrorlist packages
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# Appending the chaotic-aur repository to pacman.conf if it's not already there
if ! grep -q "chaotic-aur" /etc/pacman.conf; then
    echo "Adding [chaotic-aur] repository to /etc/pacman.conf"
    cat << EOF | sudo tee -a /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
else
    echo "[chaotic-aur] repository already exists in /etc/pacman.conf"
fi

sudo pacman -Syu
