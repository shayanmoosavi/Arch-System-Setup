#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Source utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting Chaotic-AUR setup..."

# Checking if chaotic-aur is already configured
if grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
    log SUCCESS "Chaotic-AUR repository is already configured!"
    exit 0
fi

log INFO "Configuring Chaotic-AUR repository..."

# Getting the public key to verify packages from Chaotic-AUR
log INFO "Receiving GPG key..."
if ! sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; then
    error_exit "Failed to receive GPG key from keyserver"
fi

# Locally signing the key
log INFO "Locally signing the key..."
if ! sudo pacman-key --lsign-key 3056513887B78AEB; then
    error_exit "Failed to locally sign the key"
fi

# Installing chaotic-keyring
log INFO "Installing chaotic-keyring..."
if ! sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm; then
    error_exit "Failed to install chaotic-keyring"
fi

# Installing chaotic-mirrorlist
log INFO "Installing chaotic-mirrorlist..."
if ! sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm; then
    error_exit "Failed to install chaotic-mirrorlist"
fi

log INFO "Adding [chaotic-aur] repository to /etc/pacman.conf..."

# Creating a backup of pacman.conf
if ! sudo cp /etc/pacman.conf /etc/pacman.conf.backup; then
    log WARNING "Could not create backup of pacman.conf"
fi

# Appending the chaotic-aur repository to pacman.conf
if cat << 'EOF' | sudo tee -a /etc/pacman.conf > /dev/null

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
then
    log SUCCESS "Added [chaotic-aur] repository to pacman.conf"
else
    error_exit "Failed to add repository to pacman.conf"
fi

log INFO "Performing system update..."
if sudo pacman -Syu; then
    log SUCCESS "System updated successfully"
else
    error_exit "Failed to update system"
fi

log SUCCESS "Chaotic-AUR setup completed successfully!"
