#!/usr/bin/env bash

################################################################################
# CPU Power Management Configuration Script (TLP)
#
# This script installs and configures TLP for optimal CPU power management.
# Sets performance mode on AC power and power-saving mode on battery.
#
# Documentation:
# https://linrunner.de/tlp/
#
# Version: 1.0
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# Configuration
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# TLP Configuration File
TLP_CONF="/etc/tlp.conf"
TLP_BACKUP="/etc/tlp.conf.backup.$(date +%Y%m%d_%H%M%S)"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    print_success "Running with root privileges"
}

################################################################################
# System Requirements Check
################################################################################

check_system_requirements() {
    print_header "Checking System Requirements"

    local all_ok=true

    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_success "Operating System: Linux"
    else
        print_error "This script only supports Linux"
        all_ok=false
    fi

    # Check if running on laptop (optional warning)
    if [ -d "/sys/class/power_supply" ]; then
        local has_battery=false
        for supply in /sys/class/power_supply/*; do
            if [ -f "$supply/type" ] && grep -q "Battery" "$supply/type" 2>/dev/null; then
                has_battery=true
                break
            fi
        done

        if [ "$has_battery" = true ]; then
            print_success "Battery detected - TLP will manage AC/Battery power profiles"
        else
            print_warning "No battery detected - TLP will use AC settings only"
        fi
    fi

    # Check for conflicting services
    local conflicts=("laptop-mode-tools" "power-profiles-daemon")
    for service in "${conflicts[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_warning "Conflicting service detected: $service (will be disabled)"
        fi
    done

    if [ "$all_ok" = false ]; then
        print_error "System requirements not met"
        exit 1
    fi

    print_success "All system requirements met!"
}

################################################################################
# Install TLP
################################################################################

install_tlp() {
    print_header "Installing TLP and TLP-RDW"

    # Update package list
    print_info "Updating package list..."
    apt update || {
        print_error "Failed to update package list"
        exit 1
    }
    print_success "Package list updated"

    # Check if already installed
    if check_command tlp; then
        print_warning "TLP is already installed"
        local tlp_version=$(tlp-stat -s 2>/dev/null | grep "TLP version" | awk '{print $3}' || echo "unknown")
        print_info "Installed version: $tlp_version"

        read -p "Reinstall TLP? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping installation, will configure existing TLP"
            return 0
        fi
    fi

    # Install TLP and TLP-RDW
    print_info "Installing tlp and tlp-rdw packages..."
    apt install -y tlp tlp-rdw || {
        print_error "Failed to install TLP"
        exit 1
    }
    print_success "TLP and TLP-RDW installed successfully"

    # Remove conflicting packages
    print_info "Removing conflicting power management services..."
    apt remove -y laptop-mode-tools power-profiles-daemon 2>/dev/null || {
        print_info "No conflicting services found"
    }
}

################################################################################
# Configure TLP
################################################################################

configure_tlp() {
    print_header "Configuring TLP for Performance/Power Balance"

    # Backup existing configuration
    if [ -f "$TLP_CONF" ]; then
        cp "$TLP_CONF" "$TLP_BACKUP"
        print_success "Backed up existing configuration to: $TLP_BACKUP"
    fi

    print_info "Applying optimized TLP configuration..."

    # Create optimized TLP configuration
    cat > "$TLP_CONF" << 'EOF'
################################################################################
# TLP Configuration - Optimized for Isaac Sim Development
# Generated by configure_cpu_power.sh
################################################################################

# Operation mode: set to 1 to enable TLP
TLP_ENABLE=1

# Hint: use tlp-stat -p to show active settings

################################################################################
# CPU Settings
################################################################################

# CPU scaling governor
# performance = maximum performance, no power saving
# powersave = maximum power saving
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU energy/performance policy (HWP.EPP)
# performance = maximum performance
# balance_performance = balance favoring performance
# default = balanced
# balance_power = balance favoring power saving
# power = maximum power saving
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# CPU frequency scaling (Intel only)
# Min/max frequency in MHz
CPU_SCALING_MIN_FREQ_ON_AC=0
CPU_SCALING_MAX_FREQ_ON_AC=9999999
CPU_SCALING_MIN_FREQ_ON_BAT=0
CPU_SCALING_MAX_FREQ_ON_BAT=9999999

# CPU boost
# 0 = disable turbo boost
# 1 = enable turbo boost
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# CPU HWP dynamic boost
# 0 = disable
# 1 = enable
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0

################################################################################
# Platform Profile (AMD/Intel)
################################################################################

# Platform profile
# performance, balanced, low-power
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

################################################################################
# Disk Settings
################################################################################

# SATA link power management
# max_performance = maximum performance
# medium_power = medium power saving
# min_power = minimum power consumption
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=min_power

# NVMe power management
AHCI_RUNTIME_PM_ON_AC=on
AHCI_RUNTIME_PM_ON_BAT=auto

################################################################################
# PCI Express
################################################################################

# PCIe Active State Power Management (ASPM)
# default, performance, powersave, powersupersave
PCIE_ASPM_ON_AC=performance
PCIE_ASPM_ON_BAT=powersupersave

# Runtime Power Management for PCI(e) devices
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto

################################################################################
# GPU Settings
################################################################################

# Radeon GPU power management
# auto = enabled
# low = minimum power saving
# high = maximum power saving
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=auto

# Radeon power method
RADEON_DPM_STATE_ON_AC=performance
RADEON_DPM_STATE_ON_BAT=battery

# Intel GPU power management
# 0 = disable GPU power management
# 1 = enable GPU power management
INTEL_GPU_MIN_FREQ_ON_AC=0
INTEL_GPU_MIN_FREQ_ON_BAT=0
INTEL_GPU_MAX_FREQ_ON_AC=0
INTEL_GPU_MAX_FREQ_ON_BAT=0
INTEL_GPU_BOOST_FREQ_ON_AC=0
INTEL_GPU_BOOST_FREQ_ON_BAT=0

################################################################################
# USB Settings
################################################################################

# USB autosuspend
# 1 = enable
# 0 = disable
USB_AUTOSUSPEND=1

# Exclude specific USB devices from autosuspend
# USB_DENYLIST="1111:2222 3333:4444"

################################################################################
# Audio
################################################################################

# Audio power saving (Intel HDA, AC97)
# Timeout in seconds (0 = disable)
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1

################################################################################
# Networking
################################################################################

# WiFi power saving
# on = enable, off = disable
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Ethernet wake-on-LAN
WOL_DISABLE=Y

################################################################################
# System
################################################################################

# Restore radio device state on startup
# 0 = disable
# 1 = enable
RESTORE_DEVICE_STATE_ON_STARTUP=0

# Battery charge thresholds (ThinkPad, LG, Samsung, Huawei, Asus)
# START_CHARGE_THRESH_BAT0=75
# STOP_CHARGE_THRESH_BAT0=80

EOF

    print_success "TLP configuration file created"
    print_info "Configuration highlights:"
    echo "  - AC Power:     Performance mode, turbo boost enabled"
    echo "  - Battery:      Power-saving mode, turbo boost disabled"
    echo "  - Disk/PCIe:    Optimized for performance on AC"
    echo "  - USB/Audio:    Smart power management enabled"
}

################################################################################
# Enable and Start TLP
################################################################################

enable_tlp() {
    print_header "Enabling and Starting TLP Service"

    # Mask conflicting services
    print_info "Masking conflicting services..."
    systemctl mask power-profiles-daemon 2>/dev/null || true
    systemctl mask laptop-mode 2>/dev/null || true

    # Stop conflicting services
    systemctl stop power-profiles-daemon 2>/dev/null || true
    systemctl stop laptop-mode 2>/dev/null || true

    # Enable TLP service
    print_info "Enabling TLP service..."
    systemctl enable tlp || {
        print_error "Failed to enable TLP service"
        exit 1
    }
    print_success "TLP service enabled"

    # Start TLP service
    print_info "Starting TLP service..."
    systemctl start tlp || {
        print_error "Failed to start TLP service"
        exit 1
    }
    print_success "TLP service started"

    # Verify service status
    if systemctl is-active --quiet tlp; then
        print_success "TLP service is running"
    else
        print_error "TLP service failed to start"
        print_info "Check status with: systemctl status tlp"
        exit 1
    fi
}

################################################################################
# Verification
################################################################################

verify_configuration() {
    print_header "Verifying TLP Configuration"

    # Check TLP version
    if check_command tlp-stat; then
        local tlp_version=$(tlp-stat -s 2>/dev/null | grep "TLP version" | awk '{print $3}' || echo "unknown")
        print_success "TLP version: $tlp_version"
    fi

    # Show current power mode
    print_info "Current TLP status:"
    tlp-stat -s | grep -E "Mode|Power source" || true

    # Show CPU governor
    print_info "Current CPU governor:"
    cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u || {
        print_warning "Unable to read CPU governor (may require reboot)"
    }

    # Show CPU boost status (Intel)
    if [ -f "/sys/devices/system/cpu/intel_pstate/no_turbo" ]; then
        local no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
        if [ "$no_turbo" -eq 0 ]; then
            print_success "CPU Turbo Boost: ENABLED"
        else
            print_warning "CPU Turbo Boost: DISABLED"
        fi
    fi

    # Show CPU boost status (AMD)
    if [ -f "/sys/devices/system/cpu/cpufreq/boost" ]; then
        local boost=$(cat /sys/devices/system/cpu/cpufreq/boost)
        if [ "$boost" -eq 1 ]; then
            print_success "CPU Boost: ENABLED"
        else
            print_warning "CPU Boost: DISABLED"
        fi
    fi

    print_success "Configuration verification complete"
}

################################################################################
# Post-Installation Info
################################################################################

post_installation() {
    print_header "Post-Installation Information"

    # Save configuration info
    cat > "/root/tlp_installation_info.txt" << EOF
TLP Installation Summary
========================

Installation Date: $(date)
Script Version: 1.0

TLP Version: $(tlp-stat -s 2>/dev/null | grep "TLP version" | awk '{print $3}' || echo "unknown")
Configuration File: $TLP_CONF
Backup File: $TLP_BACKUP

Applied Settings:
- AC Power: Performance governor, turbo boost enabled
- Battery: Powersave governor, turbo boost disabled
- PCIe ASPM: Performance on AC, powersave on battery
- USB Autosuspend: Enabled

Useful Commands:
- Check TLP status:        sudo tlp-stat
- Show current settings:   sudo tlp-stat -s
- Show CPU settings:       sudo tlp-stat -p
- Show disk settings:      sudo tlp-stat -d
- Manual start:            sudo tlp start
- Apply settings now:      sudo tlp start

Configuration File: $TLP_CONF

Documentation:
https://linrunner.de/tlp/
EOF

    print_success "Installation info saved to: /root/tlp_installation_info.txt"
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "TLP Configuration Complete! 🎉"

    echo -e "${GREEN}TLP has been successfully installed and configured!${NC}\n"

    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo -e "   Config File:  $TLP_CONF"
    echo -e "   Backup:       $TLP_BACKUP"
    echo -e "   Service:      $(systemctl is-active tlp 2>/dev/null || echo 'unknown')"

    echo -e "\n${BLUE}⚡ Power Profiles:${NC}"
    echo -e "   ${GREEN}AC Power:${NC}      Performance mode, turbo boost ON"
    echo -e "   ${YELLOW}Battery:${NC}       Power-saving mode, turbo boost OFF"

    echo -e "\n${BLUE}🔧 Useful Commands:${NC}"
    echo -e "   ${GREEN}sudo tlp-stat${NC}              - Full TLP status"
    echo -e "   ${GREEN}sudo tlp-stat -s${NC}           - Short status summary"
    echo -e "   ${GREEN}sudo tlp-stat -p${NC}           - CPU settings"
    echo -e "   ${GREEN}sudo tlp start${NC}             - Apply settings now"
    echo -e "   ${GREEN}sudo systemctl status tlp${NC}  - Service status"

    echo -e "\n${BLUE}📝 Edit Configuration:${NC}"
    echo -e "   ${GREEN}sudo nano $TLP_CONF${NC}"
    echo -e "   Then run: ${GREEN}sudo tlp start${NC}"

    echo -e "\n${BLUE}🔄 Restore Backup:${NC}"
    echo -e "   ${YELLOW}sudo cp $TLP_BACKUP $TLP_CONF${NC}"
    echo -e "   ${YELLOW}sudo tlp start${NC}"

    echo -e "\n${GREEN}Configuration successful! 🎊${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    clear

    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          TLP CPU Power Management Configuration              ║
║                                                               ║
║   This will:                                                  ║
║   • Install TLP and TLP-RDW packages                         ║
║   • Configure performance mode on AC power                   ║
║   • Configure power-saving mode on battery                   ║
║   • Enable CPU turbo boost on AC power                       ║
║   • Optimize disk and PCIe power management                  ║
║                                                               ║
║   Note: Requires root/sudo privileges                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"

    # Check if running as root
    check_root

    # Confirm installation
    read -p "Proceed with TLP installation and configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Record start time
    local start_time=$(date +%s)

    # Run installation
    check_system_requirements
    install_tlp
    configure_tlp
    enable_tlp
    verify_configuration
    post_installation

    # Calculate time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo -e "\n${BLUE}⏱  Configuration time: ${minutes}m ${seconds}s${NC}\n"

    print_summary
}

# Handle interruption
trap 'echo -e "\n${RED}Configuration interrupted${NC}"; exit 130' INT TERM

# Run
main "$@"