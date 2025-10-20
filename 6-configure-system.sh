#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Source utilities
source "$(dirname "$0")/utils.sh"

log INFO "Starting system configuration..."

# Configuration - Modify these according to your preferences
TIMEZONE="Asia/Tehran"      # Change to your timezone
LOCALE="en_US.UTF-8"        # Change to your preferred locale
KEYMAP="us"                 # Change to your keyboard layout

# Essential services to enable
SERVICES=(
    "NetworkManager"       # Network management
    "bluetooth"            # Bluetooth support
    "avahi-daemon"         # Network service discovery
    "fstrim.timer"         # SSD optimization (periodic TRIM)
)

# Optional services (will ask before enabling)
OPTIONAL_SERVICES=(
    "sshd"                 # SSH server
    "docker"               # Docker daemon
)

# Function to set timezone
configure_timezone() {
    log INFO "Configuring timezone..."

    # Check current timezone
    current_tz=$(timedatectl show --property=Timezone --value)

    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        log SUCCESS "Timezone already set to $TIMEZONE"
        return 0
    fi

    # Check if timezone is valid
    if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
        log WARNING "Timezone $TIMEZONE not found"
        log INFO "Current timezone: $current_tz"
        read -p "Keep current timezone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        else
            error_exit "Invalid timezone: $TIMEZONE"
        fi
    fi

    log INFO "Setting timezone to $TIMEZONE..."
    if sudo timedatectl set-timezone "$TIMEZONE"; then
        log SUCCESS "Timezone set to $TIMEZONE"
    else
        log ERROR "Failed to set timezone"
        return 1
    fi

    # Enable NTP for time synchronization
    log INFO "Enabling NTP..."
    if sudo timedatectl set-ntp true; then
        log SUCCESS "NTP enabled"
    else
        log WARNING "Failed to enable NTP"
    fi
}

# Function to configure locale
configure_locale() {
    log INFO "Configuring locale..."

    # Check if locale is already generated
    if locale -a | grep -qi "^${LOCALE}$"; then
        log SUCCESS "Locale $LOCALE already generated"
    else
        log INFO "Generating locale $LOCALE..."

        # Uncomment locale in /etc/locale.gen
        # Reason: Locales must be uncommented before generation
        if sudo sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen; then
            log SUCCESS "Uncommented $LOCALE in /etc/locale.gen"
        else
            log ERROR "Failed to uncomment locale"
            return 1
        fi

        # Generate locale
        if sudo locale-gen; then
            log SUCCESS "Locale generated successfully"
        else
            log ERROR "Failed to generate locale"
            return 1
        fi
    fi

    # Set system locale
    log INFO "Setting system locale to $LOCALE..."
    if sudo localectl set-locale LANG="$LOCALE"; then
        log SUCCESS "System locale set to $LOCALE"
    else
        log ERROR "Failed to set system locale"
        return 1
    fi
}

# Function to configure keyboard layout
configure_keymap() {
    log INFO "Configuring keyboard layout..."

    current_keymap=$(localectl status | grep "VC Keymap" | awk '{print $3}')

    if [[ "$current_keymap" == "$KEYMAP" ]]; then
        log SUCCESS "Keymap already set to $KEYMAP"
        return 0
    fi

    log INFO "Setting keymap to $KEYMAP..."
    if sudo localectl set-keymap "$KEYMAP"; then
        log SUCCESS "Keymap set to $KEYMAP"
    else
        log ERROR "Failed to set keymap"
        return 1
    fi
}

# Function to enable systemd service
enable_service() {
    local service="$1"

    # Check if service unit exists
    if ! systemctl list-unit-files | grep -q "^${service}.service"; then
        log WARNING "Service $service not found (package may not be installed)"
        return 1
    fi

    # Check if already enabled
    if systemctl is-enabled "$service" &> /dev/null; then
        log INFO "Service $service is already enabled"

        # Check if running
        if systemctl is-active "$service" &> /dev/null; then
            log SUCCESS "  ✓ $service is running"
        else
            log WARNING "  ! $service is enabled but not running"
            read -p "  Start $service now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo systemctl start "$service"
                log SUCCESS "  ✓ $service started"
            fi
        fi
        return 0
    fi

    log INFO "Enabling service: $service"
    if sudo systemctl enable "$service"; then
        log SUCCESS "  ✓ $service enabled"

        # Ask to start now
        read -p "  Start $service now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if sudo systemctl start "$service"; then
                log SUCCESS "  ✓ $service started"
            else
                log WARNING "  ! Failed to start $service"
            fi
        fi
    else
        log ERROR "  ✗ Failed to enable $service"
        return 1
    fi
}

# Main function
main() {
    # Main configuration
    log INFO "═══════════════════════════════════════════════════"
    log INFO "System Configuration"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    # Configure timezone
    configure_timezone
    echo ""

    # Configure locale
    configure_locale
    echo ""

    # Configure keymap
    configure_keymap
    echo ""

    # Enable essential services
    log INFO "═══════════════════════════════════════════════════"
    log INFO "Enabling Essential Services"
    log INFO "═══════════════════════════════════════════════════"
    echo ""

    enabled_count=0
    failed_count=0

    for service in "${SERVICES[@]}"; do
        if enable_service "$service"; then
            ((enabled_count+=1))
        else
            ((failed_count+=1))
        fi
        echo ""
    done

    # Handle optional services
    if [ ${#OPTIONAL_SERVICES[@]} -gt 0 ]; then
        log INFO "═══════════════════════════════════════════════════"
        log INFO "Optional Services"
        log INFO "═══════════════════════════════════════════════════"
        echo ""

        for service in "${OPTIONAL_SERVICES[@]}"; do
            read -p "Enable $service? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if enable_service "$service"; then
                    ((enabled_count+=1))
                else
                    ((failed_count+=1))
                fi
            else
                log INFO "Skipping $service"
            fi
            echo ""
        done
    fi

    # Summary
    log SUCCESS "System configuration completed!"
    log INFO "Enabled services: $enabled_count"
    if [ $failed_count -gt 0 ]; then
        log WARNING "Failed services: $failed_count"
    fi

    log INFO ""
    log INFO "Configuration summary:"
    log INFO "  Timezone: $(timedatectl show --property=Timezone --value)"
    log INFO "  Locale: $(localectl status | grep 'System Locale' | cut -d= -f2)"
    log INFO "  Keymap: $(localectl status | grep 'VC Keymap' | awk '{print $3}')"
}

main "$@"
