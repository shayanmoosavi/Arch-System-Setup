#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Sourceing utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting package installation..."

# Installing the packages
log INFO "Installing packages from official repositories and Chaotic-AUR..."
install_packages

# Defining packages to install
aur_pkgs=(
    grub-customizer
    marp-cli
    matugen-bin
    megasync-bin
    megacmd-bin
    klogg-bin
    pdf4qt-bin
)

# Installing AUR packages
log INFO "Installing AUR packages..."
install_aur_packages "${aur_pkgs[@]}"

log SUCCESS "Package installation completed successfully!"
