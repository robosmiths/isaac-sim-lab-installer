#!/usr/bin/env bash

################################################################################
# NVIDIA GPU Power Management Configuration Script
#
# This script configures NVIDIA Dynamic Boost daemon (nvidia-powerd) to
# restore full GPU power limits for Isaac Sim workloads.
#
# Problem: Some systems limit GPU power to 95W, causing performance issues
# Solution: Reconfigure nvidia-powerd to enable full power (e.g., 175W)
#
# Documentation:
# https://docs.nvidia.com/deploy/nvml-api/group__nvmlDeviceQueries.html
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

# NVIDIA PowerD paths
NVIDIA_POWERD_BIN="/usr/bin/nvidia-powerd"
NVIDIA_POWERD_SERVICE="/etc/systemd/system/nvidia-powerd.service"
NVIDIA_POWERD_DBUS="/etc/dbus-1/system.d/nvidia-powerd.conf"
NVIDIA_LOG_DIR="/var/log/nvtopps"

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

    # Check for NVIDIA GPU
    if check_command nvidia-smi; then
        print_success "nvidia-smi found"

        # Get GPU info
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
        local gpu_count=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)

        if [ -n "$gpu_name" ]; then
            print_success "NVIDIA GPU detected: $gpu_name"
            print_info "GPU count: $gpu_count"
        else
            print_warning "nvidia-smi present but no GPU detected"
        fi
    else
        print_error "nvidia-smi not found. NVIDIA drivers may not be installed."
        print_info "Install NVIDIA drivers first"
        all_ok=false
    fi

    # Check for nvidia-powerd binary
    if [ -f "$NVIDIA_POWERD_BIN" ]; then
        print_success "nvidia-powerd binary found: $NVIDIA_POWERD_BIN"
    else
        print_error "nvidia-powerd binary not found at: $NVIDIA_POWERD_BIN"
        print_info "This may be included in newer NVIDIA driver packages"
        all_ok=false
    fi

    # Check current power limit
    if check_command nvidia-smi; then
        print_info "Current GPU power status:"
        nvidia-smi --query-gpu=index,name,power.draw,power.limit --format=csv,noheader 2>/dev/null | while IFS=',' read -r idx name draw limit; do
            echo "     GPU $idx: $name"
            echo "     Power: $draw / $limit"
        done
    fi

    if [ "$all_ok" = false ]; then
        print_error "System requirements not met"
        exit 1
    fi

    print_success "All system requirements met!"
}

################################################################################
# Backup Existing Configuration
################################################################################

backup_existing_config() {
    print_header "Backing Up Existing Configuration"

    local backup_dir="/root/nvidia_powerd_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    # Backup systemd service if exists
    if [ -f "$NVIDIA_POWERD_SERVICE" ]; then
        cp "$NVIDIA_POWERD_SERVICE" "$backup_dir/"
        print_success "Backed up systemd service file"
    fi

    # Backup D-Bus config if exists
    if [ -f "$NVIDIA_POWERD_DBUS" ]; then
        cp "$NVIDIA_POWERD_DBUS" "$backup_dir/"
        print_success "Backed up D-Bus configuration"
    fi

    # Save current GPU power limits
    if check_command nvidia-smi; then
        nvidia-smi --query-gpu=index,name,power.limit --format=csv > "$backup_dir/gpu_power_limits.txt" 2>/dev/null || true
        print_success "Saved current GPU power limits"
    fi

    print_info "Backup location: $backup_dir"
}

################################################################################
# Stop Existing Service
################################################################################

stop_existing_service() {
    print_header "Stopping Existing nvidia-powerd Service"

    # Stop service if running
    if systemctl is-active --quiet nvidia-powerd 2>/dev/null; then
        print_info "Stopping nvidia-powerd service..."
        systemctl stop nvidia-powerd || true
        print_success "Service stopped"
    else
        print_info "Service not currently running"
    fi

    # Disable service if enabled
    if systemctl is-enabled --quiet nvidia-powerd 2>/dev/null; then
        print_info "Disabling nvidia-powerd service..."
        systemctl disable nvidia-powerd || true
        print_success "Service disabled"
    fi
}

################################################################################
# Create Log Directory
################################################################################

create_log_directory() {
    print_header "Creating Log Directory"

    # Remove existing log directory if present
    if [ -d "$NVIDIA_LOG_DIR" ]; then
        print_warning "Log directory already exists, recreating..."
        rm -rf "$NVIDIA_LOG_DIR"
    fi

    # Create log directory
    mkdir -p "$NVIDIA_LOG_DIR"
    chown root:root "$NVIDIA_LOG_DIR"
    chmod 755 "$NVIDIA_LOG_DIR"

    print_success "Log directory created: $NVIDIA_LOG_DIR"
    print_info "Permissions: $(ls -ld $NVIDIA_LOG_DIR | awk '{print $1, $3, $4}')"
}

################################################################################
# Create D-Bus Policy
################################################################################

create_dbus_policy() {
    print_header "Creating D-Bus Policy Configuration"

    # Ensure D-Bus directory exists
    mkdir -p /etc/dbus-1/system.d

    # Create D-Bus policy file
    cat > "$NVIDIA_POWERD_DBUS" << 'EOF'
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="nvidia.powerd.server"/>
  </policy>
  <policy context="default">
    <allow send_destination="nvidia.powerd.server"/>
    <allow receive_sender="nvidia.powerd.server"/>
  </policy>
</busconfig>
EOF

    print_success "D-Bus policy created: $NVIDIA_POWERD_DBUS"

    # Reload D-Bus configuration
    if check_command dbus-send; then
        print_info "Reloading D-Bus configuration..."
        systemctl reload dbus 2>/dev/null || {
            print_warning "Could not reload D-Bus (will take effect on next reboot)"
        }
    fi
}

################################################################################
# Create Systemd Service
################################################################################

create_systemd_service() {
    print_header "Creating Systemd Service Unit"

    # Create systemd service file
    cat > "$NVIDIA_POWERD_SERVICE" << 'EOF'
[Unit]
Description=NVIDIA Dynamic Boost Daemon
Documentation=https://docs.nvidia.com/
After=dbus.service
Wants=dbus.service

[Service]
Type=simple
ExecStartPre=/bin/mkdir -p /var/log/nvtopps
ExecStartPre=/bin/chmod 755 /var/log/nvtopps
ExecStart=/usr/bin/nvidia-powerd
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log/nvtopps
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    print_success "Systemd service created: $NVIDIA_POWERD_SERVICE"
}

################################################################################
# Enable and Start Service
################################################################################

enable_and_start_service() {
    print_header "Enabling and Starting nvidia-powerd Service"

    # Reload systemd daemon
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"

    # Enable service
    print_info "Enabling nvidia-powerd service..."
    systemctl enable nvidia-powerd || {
        print_error "Failed to enable service"
        exit 1
    }
    print_success "Service enabled"

    # Start service
    print_info "Starting nvidia-powerd service..."
    systemctl start nvidia-powerd || {
        print_error "Failed to start service"
        print_info "Checking service status..."
        systemctl status nvidia-powerd --no-pager || true
        print_info "Checking recent logs..."
        journalctl -u nvidia-powerd -n 50 --no-pager || true
        exit 1
    }
    print_success "Service started"

    # Wait for service to initialize
    sleep 2

    # Verify service is running
    if systemctl is-active --quiet nvidia-powerd; then
        print_success "nvidia-powerd service is running"
    else
        print_error "Service failed to start"
        exit 1
    fi
}

################################################################################
# Verify Configuration
################################################################################

verify_configuration() {
    print_header "Verifying GPU Power Configuration"

    # Check service status
    print_info "Service status:"
    systemctl status nvidia-powerd --no-pager | grep -E "Active|Main PID|Tasks" || true
    echo ""

    # Check recent logs
    print_info "Recent service logs:"
    journalctl -u nvidia-powerd -n 10 --no-pager || true
    echo ""

    # Show current GPU power limits
    if check_command nvidia-smi; then
        print_info "Current GPU power status:"
        nvidia-smi --query-gpu=index,name,power.draw,power.limit,power.default_limit --format=table 2>/dev/null || {
            nvidia-smi --query-gpu=index,name,power.draw,power.limit --format=table 2>/dev/null
        }
        echo ""

        # Check if power limit has increased
        local max_limit=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits 2>/dev/null | sort -n | tail -1)
        if [ -n "$max_limit" ]; then
            # Remove decimal point if present
            max_limit=$(echo "$max_limit" | cut -d'.' -f1)

            if [ "$max_limit" -ge 150 ]; then
                print_success "GPU power limit appears normal: ${max_limit}W"
            else
                print_warning "GPU power limit may still be restricted: ${max_limit}W"
                print_info "Power limit may increase under load - test with a workload"
            fi
        fi
    fi

    print_success "Verification complete"
}

################################################################################
# Power Test Instructions
################################################################################

print_test_instructions() {
    print_header "Testing GPU Power Under Load"

    echo -e "${BLUE}To verify GPU power increases under load:${NC}\n"

    echo -e "${YELLOW}1. Monitor GPU power in real-time:${NC}"
    echo -e "   ${GREEN}watch -n 0.5 nvidia-smi${NC}"
    echo -e ""

    echo -e "${YELLOW}2. In another terminal, run a GPU workload:${NC}"
    echo -e "   ${GREEN}# Option A: Launch Isaac Sim and play a scene${NC}"
    echo -e "   ${GREEN}cd ~/workspace/isaac-sim && ./isaac-sim.sh${NC}"
    echo -e ""
    echo -e "   ${GREEN}# Option B: Run a GPU benchmark${NC}"
    echo -e "   ${GREEN}# Install: sudo apt install glmark2${NC}"
    echo -e "   ${GREEN}glmark2${NC}"
    echo -e ""
    echo -e "   ${GREEN}# Option C: Run stress test${NC}"
    echo -e "   ${GREEN}# Install: sudo apt install nvidia-cuda-toolkit${NC}"
    echo -e "   ${GREEN}nvidia-smi -i 0 -pl 175  # Set power limit manually${NC}"
    echo -e ""

    echo -e "${YELLOW}3. Expected Results:${NC}"
    echo -e "   ${GREEN}✓${NC} Power limit (Pwr: xxx / ${GREEN}175W${NC}) shows full capacity"
    echo -e "   ${GREEN}✓${NC} GPU utilization increases during load"
    echo -e "   ${GREEN}✓${NC} Temperature rises appropriately"
    echo -e ""

    echo -e "${YELLOW}4. If power is still limited to ~95W:${NC}"
    echo -e "   ${RED}✗${NC} Check service logs: ${GREEN}journalctl -u nvidia-powerd -n 50${NC}"
    echo -e "   ${RED}✗${NC} Restart service: ${GREEN}sudo systemctl restart nvidia-powerd${NC}"
    echo -e "   ${RED}✗${NC} Reboot system: ${GREEN}sudo reboot${NC}"
    echo -e ""
}

################################################################################
# Post-Installation
################################################################################

post_installation() {
    print_header "Post-Installation Information"

    # Save installation info
    cat > "/root/nvidia_powerd_installation_info.txt" << EOF
NVIDIA PowerD Installation Summary
==================================

Installation Date: $(date)
Script Version: 1.0

NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || echo "unknown")
GPU Information:
$(nvidia-smi --query-gpu=index,name,power.limit --format=csv 2>/dev/null || echo "Unable to query GPU")

Service Configuration:
- Binary:        $NVIDIA_POWERD_BIN
- Service File:  $NVIDIA_POWERD_SERVICE
- D-Bus Policy:  $NVIDIA_POWERD_DBUS
- Log Directory: $NVIDIA_LOG_DIR

Service Status:
$(systemctl status nvidia-powerd --no-pager 2>/dev/null || echo "Service not running")

Useful Commands:
- Check service status:    sudo systemctl status nvidia-powerd
- View service logs:       sudo journalctl -u nvidia-powerd -n 50
- Restart service:         sudo systemctl restart nvidia-powerd
- Monitor GPU power:       watch -n 0.5 nvidia-smi
- Set power limit:         sudo nvidia-smi -pl 175

Troubleshooting:
- If service fails:        journalctl -u nvidia-powerd --no-pager
- Check D-Bus:             sudo systemctl status dbus
- Verify binary:           ls -l $NVIDIA_POWERD_BIN
- Check logs:              ls -la $NVIDIA_LOG_DIR

Documentation:
https://docs.nvidia.com/deploy/nvml-api/
EOF

    print_success "Installation info saved to: /root/nvidia_powerd_installation_info.txt"
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "NVIDIA GPU Power Configuration Complete! 🎉"

    echo -e "${GREEN}nvidia-powerd has been successfully configured!${NC}\n"

    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo -e "   Service File:  $NVIDIA_POWERD_SERVICE"
    echo -e "   D-Bus Policy:  $NVIDIA_POWERD_DBUS"
    echo -e "   Log Directory: $NVIDIA_LOG_DIR"
    echo -e "   Service Status: $(systemctl is-active nvidia-powerd 2>/dev/null || echo 'unknown')"

    echo -e "\n${BLUE}🔧 Useful Commands:${NC}"
    echo -e "   ${GREEN}sudo systemctl status nvidia-powerd${NC}  - Check service status"
    echo -e "   ${GREEN}sudo journalctl -u nvidia-powerd -f${NC}  - Follow service logs"
    echo -e "   ${GREEN}watch -n 0.5 nvidia-smi${NC}              - Monitor GPU real-time"
    echo -e "   ${GREEN}nvidia-smi -q -d POWER${NC}               - Detailed power info"

    echo -e "\n${BLUE}⚡ Current GPU Status:${NC}"
    if check_command nvidia-smi; then
        nvidia-smi --query-gpu=name,power.limit --format=csv,noheader 2>/dev/null | while IFS=',' read -r name limit; do
            echo -e "   $name: ${GREEN}$limit${NC}"
        done
    fi

    echo -e "\n${BLUE}📝 Next Steps:${NC}"
    echo -e "   1. Test GPU under load (see instructions above)"
    echo -e "   2. Monitor power consumption with: ${GREEN}watch -n 0.5 nvidia-smi${NC}"
    echo -e "   3. Run Isaac Sim to verify full performance"

    echo -e "\n${BLUE}🔍 Troubleshooting:${NC}"
    echo -e "   View logs:     ${GREEN}sudo journalctl -u nvidia-powerd -n 120${NC}"
    echo -e "   Restart:       ${GREEN}sudo systemctl restart nvidia-powerd${NC}"
    echo -e "   Check D-Bus:   ${GREEN}sudo systemctl status dbus${NC}"

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
║         NVIDIA GPU Power Management Configuration            ║
║                                                               ║
║   This will:                                                  ║
║   • Configure nvidia-powerd daemon                           ║
║   • Create required log directories                          ║
║   • Set up D-Bus policies                                    ║
║   • Create systemd service                                   ║
║   • Enable full GPU power limits                             ║
║                                                               ║
║   Problem: GPU power limited to ~95W                         ║
║   Solution: Restore full power capacity (e.g., 175W)         ║
║                                                               ║
║   Note: Requires root/sudo privileges                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"

    # Check if running as root
    check_root

    # Confirm installation
    read -p "Proceed with nvidia-powerd configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Configuration cancelled"
        exit 0
    fi

    # Record start time
    local start_time=$(date +%s)

    # Run configuration
    check_system_requirements
    backup_existing_config
    stop_existing_service
    create_log_directory
    create_dbus_policy
    create_systemd_service
    enable_and_start_service
    verify_configuration
    print_test_instructions
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
