#!/usr/bin/env bash


# Exit on any error
set -e

# Getting the public key to enable installation
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

# Installing the chaotic-keyring and chaotic-mirrorlist packages
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

# Appending the chaotic-aur repository to pacman.conf 
sudo mv /etc/pacman.conf /etc/pacman.conf.bak
cat << EOF >> /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

sudo pacman -Syu
