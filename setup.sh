#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Sourcing utilities
source "$(dirname "$0")/utils.sh"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPTS=(
    "1-setup-paru.sh"
    "2-setup-chaotic-aur.sh"
    "3-install-packages.sh"
    "4-install-extra-fonts.sh"
    "5-setup-dotfiles.sh"
    "6-configure-system.sh"
    "7-verify-system.sh"
)

# Displaying the banner
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════╗
║                                                  ║
║        Arch Linux Post-Installation Setup        ║
║                                                  ║
╚══════════════════════════════════════════════════╝
EOF
}

# Showing summary of what will be done
show_summary() {
    log INFO "This script will perform the following steps:"
    echo ""
    echo "  1. Install paru (AUR helper)"
    echo "  2. Setup Chaotic-AUR repository"
    echo "  3. Install packages from package lists"
    echo "  4. Install custom fonts"
    echo "  5. Clone and stow dotfiles"
    echo "  6. Configure system (timezone, locale, services)"
    echo "  7. Verify system configuration"
    echo ""
    log INFO "Total scripts to execute: ${#SETUP_SCRIPTS[@]}"
    echo ""
}

# Verify all required scripts exist
verify_scripts() {
    log INFO "Verifying setup scripts..."

    local missing_scripts=()

    for script in "${SETUP_SCRIPTS[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ ! -f "$script_path" ]]; then
            missing_scripts+=("$script")
        elif [[ ! -x "$script_path" ]]; then
            log WARNING "$script is not executable, making it executable..."
            chmod +x "$script_path"
        fi
    done

    if [[ ${#missing_scripts[@]} -ne 0 ]]; then
        error_exit "Missing required scripts: ${missing_scripts[*]}"
    fi

    log SUCCESS "All setup scripts found and verified"
}

# Execute a setup script
execute_script() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"

    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Executing: $script"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Execute the script
    if bash "$script_path"; then
        log SUCCESS "✓ $script completed successfully"
        return 0
    else
        error_exit "✗ $script failed with exit code $?"
    fi
}

# Main execution function
main() {
    show_banner

    # Check we're not running as root
    check_not_root

    # Show summary
    show_summary

    # Ask for confirmation
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log INFO "Setup cancelled by user"
        exit 0
    fi

    # Verify all scripts exist
    verify_scripts

    # Record start time
    local start_time=$(date +%s)

    log INFO "Starting setup process..."
    echo ""

    # Execute each script in order
    for script in "${SETUP_SCRIPTS[@]}"; do
        execute_script "$script"
    done

    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    # Show completion message
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log SUCCESS "🎉 All setup scripts completed successfully!"
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Total time: ${minutes}m ${seconds}s"
    log INFO "Log file: $log_file"
    echo ""
    log INFO "You may need to:"
    log INFO "  • Log out and back in for fonts to be available"
    log INFO "  • Restart your shell for environment changes"
    log INFO "  • Reboot for kernel modules to load"
    echo ""
}

# Run main function
main "$@"
