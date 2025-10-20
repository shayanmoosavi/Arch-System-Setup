#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
pkg_dir="$SCRIPT_DIR/packages"
log_dir="$SCRIPT_DIR/logs"
log_file="$log_dir/setup-$(date +%Y-%m-%d).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "$log_dir"

# Logging function - writes to both stdout and log file
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$log_file"

    # Write to stdout with colors
    case "$level" in
        INFO)
            printf "${BLUE}[INFO]${NC} $message\n"
            ;;
        SUCCESS)
            printf "${GREEN}[SUCCESS]${NC} $message\n"
            ;;
        WARNING)
            printf "${YELLOW}[WARNING]${NC} $message\n"
            ;;
        ERROR)
            printf "${RED}[ERROR]${NC} $message\n"
            ;;
        *)
            printf "$message\n"
            ;;
    esac
}

# Error handler - logs errors and exits
error_exit() {
    log ERROR "$1"
    log ERROR "Setup failed. Check log file: $log_file"
    exit 1
}

# Check if running as root (we don't want that)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Run as normal user (sudo will be called when needed)."
    fi
}

# Check if pacman database is locked
check_pacman_lock() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        error_exit "Pacman database is locked. Another package manager instance may be running."
    fi
}

# Function to check whether a package is installed
is_installed() {
    pacman -Qi "$1" &> /dev/null
}

# Validate package exists in repositories or is already installed
validate_package() {
    local pkg="$1"

    # Check if already installed
    if is_installed "$pkg"; then
        return 0
    fi

    # Check if package exists in repos (using -Ss for search in sync databases)
    if pacman -Ss "^${pkg}$" &> /dev/null; then
        return 0
    fi

    log WARNING "Package '$pkg' not found in repositories"
    return 1
}

# Function to install packages
install_packages() {
    check_not_root
    check_pacman_lock

    # List of packages to install
    local packages=()
    local invalid_packages=()

    log INFO "Reading package lists from $pkg_dir..."

    # Check if package directory exists
    if [[ ! -d "$pkg_dir" ]]; then
        error_exit "Package directory '$pkg_dir' not found"
    fi

    # Use find to safely get files, then use while read to process line by line
    while IFS= read -r -d $'\0' file; do
        log INFO "Processing file: $file"

        # Read packages line by line from the file
        while IFS= read -r pkg; do

            # Strip leading/trailing whitespace
            pkg=$(echo "$pkg" | xargs)

            # Skip if line is empty or starts with #
            if [[ -z "$pkg" || "$pkg" =~ ^# ]]; then
                continue
            fi

            # Check if already installed
            if is_installed "$pkg"; then
                log INFO "Package '$pkg' is already installed, skipping"
                continue
            fi

            # Validate package exists
            if validate_package "$pkg"; then
                packages+=("$pkg")
            else
                invalid_packages+=("$pkg")
            fi
        done < "$file"
    done < <(find "$pkg_dir" -type f -print0)

    # Report invalid packages
    if [ ${#invalid_packages[@]} -ne 0 ]; then
        log WARNING "The following packages were not found: ${invalid_packages[*]}"
        log WARNING "These will be skipped. Please verify package names."
    fi

    # Install packages if any are found
    if [ ${#packages[@]} -eq 0 ]; then
        log SUCCESS "No new packages to install"
        return 0
    fi

    log INFO "Installing ${#packages[@]} packages: ${packages[*]}"

    if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
        log SUCCESS "Successfully installed ${#packages[@]} packages"
    else
        error_exit "Failed to install packages"
    fi
}

# Function to install AUR packages using paru
install_aur_packages() {
    local aur_pkgs=("$@")

    check_not_root

    # Check if paru is installed
    if ! command -v paru &> /dev/null; then
        error_exit "paru is not installed. Run 1-setup-paru.sh first."
    fi

    local packages_to_install=()

    for pkg in "${aur_pkgs[@]}"; do
        if is_installed "$pkg"; then
            log INFO "AUR package '$pkg' is already installed, skipping"
        else
            packages_to_install+=("$pkg")
        fi
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log SUCCESS "No new AUR packages to install"
        return 0
    fi

    log INFO "Installing ${#packages_to_install[@]} AUR packages: ${packages_to_install[*]}"

    if paru -S --needed --noconfirm "${packages_to_install[@]}"; then
        log SUCCESS "Successfully installed ${#packages_to_install[@]} AUR packages"
    else
        error_exit "Failed to install AUR packages"
    fi
}
