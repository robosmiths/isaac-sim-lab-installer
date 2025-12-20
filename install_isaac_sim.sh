#!/usr/bin/env bash

################################################################################
# Isaac Sim Binary Installation Script
#
# This script downloads and installs Isaac Sim from NVIDIA servers.
# Installation method: Binary (standalone zip download)
#
# Documentation:
# https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/download.html
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

# Installation settings
WORKSPACE_DIR="${HOME}/workspace"
ISAAC_SIM_VERSION="5.1.0"

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

check_glibc_version() {
    local glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    local required_version="2.35"

    if awk "BEGIN {exit !($glibc_version >= $required_version)}"; then
        print_success "GLIBC version ${glibc_version} meets requirement (>= ${required_version})"
        return 0
    else
        print_error "GLIBC version ${glibc_version} is too old (requires >= ${required_version})"
        return 1
    fi
}

check_disk_space() {
    local available=$(df -BG "${HOME}" | tail -1 | awk '{print $4}' | sed 's/G//')
    local required=40  # GB

    if [ "$available" -ge "$required" ]; then
        print_success "Sufficient disk space: ${available}GB available"
        return 0
    else
        print_warning "Low disk space: ${available}GB available (recommended: ${required}GB+)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

################################################################################
# System Requirements Check
################################################################################

check_system_requirements() {
    print_header "Checking System Requirements for Isaac Sim"

    local all_ok=true

    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_success "Operating System: Linux"
    else
        print_error "This script only supports Linux"
        all_ok=false
    fi

    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "aarch64" ]]; then
        print_success "Architecture: $arch"
    else
        print_error "Unsupported architecture: $arch (requires x86_64 or aarch64)"
        all_ok=false
    fi

    # Check GLIBC
    if ! check_glibc_version; then
        print_error "Your system is too old. Ubuntu 22.04+ or equivalent required."
        all_ok=false
    fi

    # Check disk space
    check_disk_space

    # Check for required tools
    local tools=("wget" "unzip")
    for tool in "${tools[@]}"; do
        if check_command "$tool"; then
            print_success "$tool found"
        else
            print_error "$tool not found. Install with: sudo apt install $tool"
            all_ok=false
        fi
    done

    if [ "$all_ok" = false ]; then
        print_error "System requirements not met. Please install missing dependencies."
        exit 1
    fi

    print_success "All system requirements met!"
}

################################################################################
# Directory Setup
################################################################################

setup_directories() {
    print_header "Setting Up Directory Structure"

    # Create workspace directory
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$WORKSPACE_DIR"
        print_success "Created workspace directory: $WORKSPACE_DIR"
    else
        print_info "Workspace directory already exists: $WORKSPACE_DIR"
    fi

    cd "$WORKSPACE_DIR"
    print_success "Working in: $(pwd)"
}

################################################################################
# Isaac Sim Installation
################################################################################

install_isaac_sim() {
    print_header "Installing Isaac Sim ${ISAAC_SIM_VERSION}"

    local arch=$(uname -m)
    local download_url
    local filename

    # Determine download URL based on architecture
    if [ "$arch" = "x86_64" ]; then
        filename="isaac-sim-standalone-${ISAAC_SIM_VERSION}-linux-x86_64.zip"
        download_url="https://download.isaacsim.omniverse.nvidia.com/${filename}"
    elif [ "$arch" = "aarch64" ]; then
        filename="isaac-sim-standalone-${ISAAC_SIM_VERSION}-linux-aarch64.zip"
        download_url="https://download.isaacsim.omniverse.nvidia.com/${filename}"
    else
        print_error "Unsupported architecture: $arch"
        exit 1
    fi

    cd "$WORKSPACE_DIR"

    # Check if already downloaded
    if [ -f "$filename" ]; then
        print_info "Isaac Sim archive already downloaded: $filename"
        local file_size=$(du -h "$filename" | cut -f1)
        print_info "File size: $file_size"
    else
        print_info "Downloading Isaac Sim from NVIDIA servers..."
        print_info "URL: $download_url"
        print_warning "File size: ~8-10GB | Estimated time: 10-30 minutes on typical connection"
        echo ""

        # Download with progress bar
        wget --show-progress --progress=bar:force:noscroll "$download_url" || {
            print_error "Download failed. Please check your internet connection."
            print_info "You can also manually download from:"
            print_info "  https://docs.isaacsim.omniverse.nvidia.com/${ISAAC_SIM_VERSION}/installation/download.html"
            exit 1
        }
        print_success "Download completed: $filename"
    fi

    # Verify download
    local file_size=$(du -h "$filename" | cut -f1)
    print_info "Downloaded file size: $file_size"

    # Check if already extracted
    local extract_dir="isaacsim-${ISAAC_SIM_VERSION}"
    if [ -d "$extract_dir" ]; then
        print_warning "Isaac Sim directory already exists: $extract_dir"
        read -p "Remove and re-extract? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$extract_dir"
            print_info "Removed existing directory"
        else
            print_info "Using existing Isaac Sim installation"
            # Update symlink
            ln -sfn "$extract_dir" isaac-sim
            print_success "Symlink updated: isaac-sim -> $extract_dir"
            return 0
        fi
    fi

    # Extract
    print_info "Extracting Isaac Sim (this will take 5-10 minutes)..."

    # Create extraction directory
    mkdir -p "$extract_dir"

    # Extract directly into the target directory
    unzip -q "$filename" -d "$extract_dir" || {
        print_error "Extraction failed"
        exit 1
    }
    print_success "Extraction completed to $extract_dir"

    # Create symlink for easy access
    ln -sfn "$extract_dir" isaac-sim
    print_success "Created symlink: isaac-sim -> $extract_dir"

    # Verify installation
    if [ -f "${WORKSPACE_DIR}/isaac-sim/isaac-sim.sh" ]; then
        print_success "Isaac Sim installation verified"

        # Check VERSION file
        if [ -f "${WORKSPACE_DIR}/isaac-sim/VERSION" ]; then
            local installed_version=$(cat "${WORKSPACE_DIR}/isaac-sim/VERSION")
            print_info "Installed version: $installed_version"
        fi
    else
        print_error "Isaac Sim installation may be corrupted"
        exit 1
    fi

    # Optionally remove zip file
    echo ""
    read -p "Remove downloaded zip file to save ~8GB space? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        rm "$filename"
        print_success "Removed archive file"
    else
        print_info "Keeping archive file: $filename"
    fi
}

################################################################################
# Post-Installation
################################################################################

post_installation() {
    print_header "Post-Installation Setup"

    # Test Isaac Sim
    echo ""
    read -p "Test Isaac Sim installation (launches simulator)? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Testing Isaac Sim..."
        print_warning "Simulator window will open. Close it manually to continue."
        echo ""

        cd "${WORKSPACE_DIR}/isaac-sim"
        timeout 60 ./isaac-sim.sh --help > /dev/null 2>&1 || {
            print_info "Test completed (timeout is normal)"
        }
    fi

    # Save installation info
    cat > "${WORKSPACE_DIR}/isaac-sim/INSTALLATION_INFO.txt" << EOF
Isaac Sim Installation Summary
==============================

Installation Date: $(date)
Script Version: 1.0

Installed Version: ${ISAAC_SIM_VERSION}
Installation Method: Binary (standalone)
Installation Location: ${WORKSPACE_DIR}/isaac-sim

System Information:
- OS: $(uname -s)
- Architecture: $(uname -m)
- GLIBC: $(ldd --version | head -n1)

Executable: ${WORKSPACE_DIR}/isaac-sim/isaac-sim.sh
VERSION file: ${WORKSPACE_DIR}/isaac-sim/VERSION

Documentation:
https://docs.isaacsim.omniverse.nvidia.com/${ISAAC_SIM_VERSION}/

Next Steps:
1. Install Isaac Lab using: ~/install_isaac_lab.sh
2. Or test Isaac Sim: cd ${WORKSPACE_DIR}/isaac-sim && ./isaac-sim.sh
EOF

    print_success "Installation info saved"
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "Installation Complete! 🎉"

    echo -e "${GREEN}Isaac Sim ${ISAAC_SIM_VERSION} has been successfully installed!${NC}\n"

    echo -e "${BLUE}📁 Installation Location:${NC}"
    echo -e "   Directory: ${WORKSPACE_DIR}/isaac-sim/"
    echo -e "   Symlink:   ${WORKSPACE_DIR}/isaac-sim -> isaacsim-${ISAAC_SIM_VERSION}"
    echo -e "   Version:   $(cat ${WORKSPACE_DIR}/isaac-sim/VERSION 2>/dev/null || echo ${ISAAC_SIM_VERSION})"

    echo -e "\n${BLUE}🚀 Quick Test:${NC}"
    echo -e "   ${GREEN}cd ${WORKSPACE_DIR}/isaac-sim${NC}"
    echo -e "   ${GREEN}./isaac-sim.sh${NC}"

    echo -e "\n${BLUE}📚 Documentation:${NC}"
    echo -e "   ${YELLOW}https://docs.isaacsim.omniverse.nvidia.com/${ISAAC_SIM_VERSION}/${NC}"

    echo -e "\n${BLUE}⏭  Next Steps:${NC}"
    echo -e "   Install Isaac Lab with:"
    echo -e "   ${GREEN}~/install_isaac_lab.sh${NC}"

    echo -e "\n${GREEN}Installation successful! 🎊${NC}\n"
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
║          Isaac Sim Binary Installation Script                ║
║                                                               ║
║   Version: 5.1.0                                             ║
║   Method: Binary Download                                    ║
║   Size: ~8-10GB                                              ║
║   Time: ~10-30 minutes                                       ║
║                                                               ║
║   Installation: ~/workspace/isaac-sim/                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"

    # Confirm installation
    read -p "Proceed with Isaac Sim installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Record start time
    local start_time=$(date +%s)

    # Run installation
    check_system_requirements
    setup_directories
    install_isaac_sim
    post_installation

    # Calculate time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo -e "\n${BLUE}⏱  Installation time: ${minutes}m ${seconds}s${NC}\n"

    print_summary
}

# Handle interruption
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 130' INT TERM

# Run
main "$@"
