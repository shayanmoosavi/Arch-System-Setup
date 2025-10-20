#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Source utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting system verification..."

# Counters for summary
total_checks=0
passed_checks=0
failed_checks=0
warning_checks=0

# Function to perform a check
perform_check() {
    local check_name="$1"
    local check_command="$2"
    local success_message="$3"
    local failure_message="$4"

    ((total_checks+=1))

    log INFO "Checking: $check_name"

    if eval "$check_command" &> /dev/null; then
        log SUCCESS "  ✓ $success_message"
        ((passed_checks+=1))
        return 0
    else
        log ERROR "  ✗ $failure_message"
        ((failed_checks+=1))
        return 1
    fi
}

# Function to perform a warning check (not critical)
perform_warning_check() {
    local check_name="$1"
    local check_command="$2"
    local success_message="$3"
    local warning_message="$4"

    ((total_checks+=1))

    log INFO "Checking: $check_name"

    if eval "$check_command" &> /dev/null; then
        log SUCCESS "  ✓ $success_message"
        ((passed_checks+=1))
        return 0
    else
        log WARNING "  ! $warning_message"
        ((warning_checks+=1))
        return 1
    fi
}

# Function to verify package related checks
verify_packages() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Package Manager Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check pacman
    perform_check \
        "Pacman" \
        "command -v pacman" \
        "Pacman is installed" \
        "Pacman not found"

    # Check paru
    perform_check \
        "Paru (AUR helper)" \
        "command -v paru" \
        "Paru is installed" \
        "Paru not found - run 1-setup-paru.sh"

    # Check if Chaotic-AUR is configured
    perform_check \
        "Chaotic-AUR repository" \
        "grep -q '^\[chaotic-aur\]' /etc/pacman.conf" \
        "Chaotic-AUR is configured" \
        "Chaotic-AUR not configured - run 2-setup-chaotic-aur.sh"

    # Check flatpak
    perform_warning_check \
        "Flatpak" \
        "command -v flatpak" \
        "Flatpak is installed" \
        "Flatpak not found (optional)"
}

# Function to verify system config
verify_system_config() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "System Configuration Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check timezone
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
    if [[ "$current_tz" != "unknown" && "$current_tz" != "n/a" ]]; then
        log SUCCESS "  ✓ Timezone is set to: $current_tz"
        ((passed_checks+=1))
    else
        log WARNING "  ! Timezone not properly configured"
        ((warning_checks+=1))
    fi
    ((total_checks+=1))

    # Check locale
    current_locale=$(localectl status 2>/dev/null | grep "System Locale" | cut -d= -f2 | head -n1 || echo "unknown")
    if [[ "$current_locale" != "unknown" && -n "$current_locale" ]]; then
        log SUCCESS "  ✓ System locale is set to: $current_locale"
        ((passed_checks+=1))
    else
        log WARNING "  ! System locale not properly configured"
        ((warning_checks+=1))
    fi
    ((total_checks+=1))

    # Check NTP synchronization
    perform_warning_check \
        "NTP time synchronization" \
        "timedatectl show | grep -q 'NTPSynchronized=yes'" \
        "System clock is synchronized via NTP" \
        "NTP synchronization not enabled"
}

# Function to verify bootloader
verify_bootloader() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Bootloader Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check GRUB
    if perform_check \
        "GRUB bootloader" \
        "command -v grub-mkconfig" \
        "GRUB is installed" \
        "GRUB not found"; then

        # Check if GRUB config exists
        perform_check \
            "GRUB configuration" \
            "test -f /boot/grub/grub.cfg" \
            "GRUB configuration exists" \
            "GRUB configuration not found at /boot/grub/grub.cfg"

        # Check for os-prober (needed for dual boot)
        perform_warning_check \
            "os-prober (for dual-boot)" \
            "command -v os-prober" \
            "os-prober is installed (dual-boot detection)" \
            "os-prober not found (needed for Windows dual-boot detection)"
    fi
}

# Function to verify essential services
verify_essential_services() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Essential Services Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Essential services to check
    essential_services=(
        "NetworkManager"
        "bluetooth"
    )

    for service in "${essential_services[@]}"; do
        # Check if service exists
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            # Check if enabled
            if systemctl is-enabled "$service" &> /dev/null; then
                # Check if running
                if systemctl is-active "$service" &> /dev/null; then
                    log SUCCESS "  ✓ $service is enabled and running"
                    ((passed_checks+=1))
                else
                    log WARNING "  ! $service is enabled but not running"
                    ((warning_checks+=1))
                fi
            else
                log WARNING "  ! $service is not enabled"
                ((warning_checks+=1))
            fi
        else
            log WARNING "  ! $service not found (package may not be installed)"
            ((warning_checks+=1))
        fi
        ((total_checks+=1))
    done
}

# Function to verify fonts
verify_fonts() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Fonts Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check font directory
    if [[ -d "$HOME/.local/share/fonts" ]]; then
        font_count=$(find "$HOME/.local/share/fonts" -type f \( -name "*.ttf" -o -name "*.otf" \) | wc -l)
        if [[ $font_count -gt 0 ]]; then
            log SUCCESS "  ✓ Found $font_count custom font files"
            ((passed_checks+=1))
        else
            log WARNING "  ! Font directory exists but no fonts found"
            ((warning_checks+=1))
        fi
    else
        log WARNING "  ! Custom font directory does not exist"
        ((warning_checks+=1))
    fi
    ((total_checks+=1))

    # Check font cache
    perform_warning_check \
        "Font cache" \
        "test -d $HOME/.cache/fontconfig" \
        "Font cache exists" \
        "Font cache not found"
}

# Function to verify dotfiles
verify_dotfiles() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Dotfiles Verification"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check if dotfiles directory exists
    if [[ -d "$HOME/dotfiles" ]]; then
        # Check if it's a git repo
        if [[ -d "$HOME/dotfiles/.git" ]]; then
            log SUCCESS "  ✓ Dotfiles directory exists and is a git repository"
            ((passed_checks+=1))

            # Count stowed packages (check for symlinks in home directory)
            stowed_count=$(find "$HOME" -maxdepth 1 -type l | wc -l)
            log INFO "  Symlinks in home directory: $stowed_count"
        else
            log WARNING "  ! Dotfiles directory exists but is not a git repository"
            ((warning_checks+=1))
        fi
    else
        log WARNING "  ! Dotfiles directory not found at ~/dotfiles"
        ((warning_checks+=1))
    fi
    ((total_checks+=1))

    # Check if stow is installed
    perform_warning_check \
        "GNU Stow" \
        "command -v stow" \
        "GNU Stow is installed" \
        "GNU Stow not found"
}

# Function to verify filesystem
verify_filesystem() {
    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Storage and Filesystem"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Check if fstrim.timer is enabled (for SSD)
    perform_warning_check \
        "SSD TRIM timer" \
        "systemctl is-enabled fstrim.timer" \
        "fstrim.timer is enabled (SSD optimization)" \
        "fstrim.timer not enabled (recommended for SSDs)"

    # Check available disk space
    available_space=$(df -h / | awk 'NR==2 {print $4}')
    log INFO "  Available disk space on /: $available_space"
}

# Main function
main() {
    verify_packages
    verify_system_config
    verify_bootloader
    verify_essential_services
    verify_fonts
    verify_dotfiles
    verify_filesystem

    echo ""
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Verification Summary"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    log INFO "Total checks performed: $total_checks"
    log SUCCESS "Passed: $passed_checks"

    if [[ $warning_checks -gt 0 ]]; then
        log WARNING "Warnings: $warning_checks"
    fi

    if [[ $failed_checks -gt 0 ]]; then
        log ERROR "Failed: $failed_checks"
    fi

    echo ""

    # Overall assessment
    if [[ $failed_checks -eq 0 && $warning_checks -eq 0 ]]; then
        log SUCCESS "🎉 All checks passed! Your system is properly configured."
        exit 0
    elif [[ $failed_checks -eq 0 ]]; then
        log SUCCESS "✓ All critical checks passed with $warning_checks warnings."
        log INFO "System is functional but some optional features may not be configured."
        exit 0
    else
        log ERROR "✗ $failed_checks critical checks failed."
        log INFO "Please review the failed checks and run the appropriate setup scripts."
        exit 1
    fi
}

main "$@"
