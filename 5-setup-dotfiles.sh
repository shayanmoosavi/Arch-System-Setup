#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Source utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting dotfiles setup..."

# Configuration
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/shayanmoosavi/dotfiles.git}"
DOTFILES_DIR="$HOME/dotfiles"

# Check if GNU stow is installed
if ! command -v stow &> /dev/null; then
    log INFO "GNU stow not found. Installing..."
    if sudo pacman -S --needed --noconfirm stow; then
        log SUCCESS "GNU stow installed successfully"
    else
        error_exit "Failed to install GNU stow"
    fi
else
    log SUCCESS "GNU stow is already installed"
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    log INFO "Git not found. Installing..."
    if sudo pacman -S --needed --noconfirm git; then
        log SUCCESS "Git installed successfully"
    else
        error_exit "Failed to install git"
    fi
else
    log SUCCESS "Git is already installed"
fi

# Clone or update dotfiles repository
if [[ -d "$DOTFILES_DIR" ]]; then
    log INFO "Dotfiles directory already exists at $DOTFILES_DIR"

    # Check if it's a git repository
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log INFO "Updating existing dotfiles repository..."
        cd "$DOTFILES_DIR"

        # Store current branch
        current_branch=$(git branch --show-current)

        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD --; then
            log WARNING "You have uncommitted changes in your dotfiles"
            log WARNING "Please commit or stash them before continuing"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log INFO "Dotfiles update cancelled"
                exit 0
            fi
        fi

        # Pull latest changes
        if git pull origin "$current_branch"; then
            log SUCCESS "Dotfiles updated successfully"
        else
            log WARNING "Failed to update dotfiles, continuing with existing version"
        fi
    else
        log WARNING "$DOTFILES_DIR exists but is not a git repository"
        read -p "Remove and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$DOTFILES_DIR"
        else
            error_exit "Cannot proceed without a valid dotfiles repository"
        fi
    fi
fi

# Clone repository if it doesn't exist
if [[ ! -d "$DOTFILES_DIR" ]]; then
    log INFO "Cloning dotfiles repository from $DOTFILES_REPO..."

    # Reason: Clone using HTTPS for public repos (no authentication needed)
    if git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
        log SUCCESS "Dotfiles repository cloned successfully"
    else
        error_exit "Failed to clone dotfiles repository"
    fi
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR"

# Get list of packages to stow
log INFO "Discovering stow packages..."
packages=()

while IFS= read -r -d $'\0' dir; do
    package=$(basename "$dir")

    # Skip hidden directories and common non-package directories
    if [[ "$package" =~ ^\. ]] || [[ "$package" == "README.md" ]] || [[ "$package" == "LICENSE" ]]; then
        continue
    fi

    packages+=("$package")
done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

if [ ${#packages[@]} -eq 0 ]; then
    log WARNING "No stow packages found in $DOTFILES_DIR"
    exit 0
fi

log INFO "Found ${#packages[@]} stow packages: ${packages[*]}"

# Ask for confirmation
echo ""
read -p "Stow all packages? (y/N): " -n 1 -r
echo
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log INFO "Dotfiles stow cancelled"
    log INFO "You can manually stow packages with: cd $DOTFILES_DIR && stow <package-name>"
    exit 0
fi

# Stow each package
installed_count=0
failed_count=0

for package in "${packages[@]}"; do
    log INFO "Stowing package: $package"

    # Using stow command with verbose, restow, and target options
    if stow -v -R -t "$HOME" "$package" 2>&1 | while read -r line; do
        # Filter out informational messages and only show important ones
        if [[ "$line" =~ "LINK" ]] || [[ "$line" =~ "ERROR" ]] || [[ "$line" =~ "WARNING" ]]; then
            echo "  $line"
        fi
    done; then
        log SUCCESS "  ✓ $package stowed successfully"
        ((installed_count+=1))
    else
        log ERROR "  ✗ Failed to stow $package"
        log WARNING "  This might be due to existing files. You may need to remove them manually."
        ((failed_count+=1))
    fi
    echo ""
done

# Summary
log SUCCESS "Dotfiles setup completed!"
log INFO "Successfully stowed: $installed_count packages"
if [ $failed_count -gt 0 ]; then
    log WARNING "Failed to stow: $failed_count packages"
    log INFO "Check for conflicting files and stow manually if needed"
fi

log INFO "Dotfiles location: $DOTFILES_DIR"
log INFO "To stow a package manually: cd $DOTFILES_DIR && stow -v <package-name>"
log INFO "To unstow a package: cd $DOTFILES_DIR && stow -D <package-name>"
