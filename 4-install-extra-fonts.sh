#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Source utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting font installation..."

# Configuration
FONT_SRC_DIR="./extra-fonts"
FONT_DEST_DIR="$HOME/.local/share/fonts"

# Checking if source directory exists
if [[ ! -d "$FONT_SRC_DIR" ]]; then
    error_exit "Font source directory '$FONT_SRC_DIR' not found"
fi

# Creating destination directory if it doesn't exist
log INFO "Ensuring font directory exists: $FONT_DEST_DIR"
mkdir -p "$FONT_DEST_DIR"

# Function to install fonts from a directory
install_font_family() {
    local src="$1"
    local family_name=$(basename "$src")
    local dest="$FONT_DEST_DIR/$family_name"

    log INFO "Installing font family: $family_name"

    # Checking if font family is already installed
    if [[ -d "$dest" ]]; then
        log INFO "Font family '$family_name' already exists, checking for updates..."
    else
        mkdir -p "$dest"
    fi

    # Copying font files (common font extensions)
    local font_files_found=0

    while IFS= read -r -d $'\0' font_file; do
        local font_name=$(basename "$font_file")
        local dest_file="$dest/$font_name"

        # Checking if file already exists and is identical
        if [[ -f "$dest_file" ]] && cmp -s "$font_file" "$dest_file"; then
            log INFO "  $font_name already installed and up to date"
        else
            cp "$font_file" "$dest_file"
            log SUCCESS "  Installed $font_name"
            ((font_files_found+=1))
        fi
    done < <(find "$src" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.woff" -o -iname "*.woff2" \) -print0)

    if [[ $font_files_found -eq 0 ]]; then
        log INFO "  No new fonts to install for $family_name"
    fi
}

# Installing each font family
log INFO "Scanning for font families in $FONT_SRC_DIR..."

font_families=0
while IFS= read -r -d $'\0' font_dir; do
    install_font_family "$font_dir"
    ((font_families+=1))
done < <(find "$FONT_SRC_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ $font_families -eq 0 ]]; then
    log WARNING "No font families found in $FONT_SRC_DIR"
    exit 0
fi

# Updating font cache
log INFO "Updating font cache..."
if fc-cache -f "$FONT_DEST_DIR"; then
    log SUCCESS "Font cache updated successfully"
else
    log WARNING "Failed to update font cache, but fonts may still work after reboot"
fi

# Verify installation
log INFO "Verifying font installation..."
installed_count=$(fc-list : family | grep -i -e "departure" -e "pixelon" | wc -l)

if [[ $installed_count -gt 0 ]]; then
    log SUCCESS "Found $installed_count installed font variants"
    log SUCCESS "Font installation completed successfully!"
else
    log WARNING "Fonts installed but not detected by fc-list. May need to log out and back in."
fi
