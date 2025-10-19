#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

source "$(dirname "$0")/utils.sh"

log INFO "Starting paru installation..."

if command -v paru &> /dev/null; then
    log SUCCESS "Paru is already installed!"
    paru --version | head -n1 | sed 's/^/  /' # Show version indented
    exit 0
fi

log INFO "Paru not found. Installing..."

# Store current directory
START_DIR=$(pwd)

# Ensure base-devel is installed (required for building AUR packages)
log INFO "Ensuring base-devel is installed..."
if ! sudo pacman -S --needed --noconfirm base-devel; then
    error_exit "Failed to install base-devel"
fi

BUILD_DIR=$(mktemp -d)
log INFO "Building paru in temporary directory: $BUILD_DIR"

# Cleanup function
cleanup() {
    log INFO "Cleaning up..."
    cd "$START_DIR"
    rm -rf "$BUILD_DIR"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Clone paru repository
log INFO "Cloning paru repository..."
if ! git clone https://aur.archlinux.org/paru.git "$BUILD_DIR"; then
    error_exit "Failed to clone paru repository"
fi

# Build and install paru
cd "$BUILD_DIR"
log INFO "Building and installing paru..."

if makepkg -si --noconfirm; then
    log SUCCESS "Paru installed successfully!"
else
    error_exit "Failed to build/install paru"
fi

# Verify installation
if command -v paru &> /dev/null; then
    log SUCCESS "Paru installation verified!"
    paru --version | head -n1 | sed 's/^/  /'
else
    error_exit "Paru installation completed but command not found"
fi
