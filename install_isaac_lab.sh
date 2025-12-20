#!/usr/bin/env bash

################################################################################
# Isaac Lab Installation Script
#
# This script installs Isaac Lab and its dependencies.
# Requires: Isaac Sim must be installed first (use install_isaac_sim.sh)
#
# Documentation:
# https://isaac-sim.github.io/IsaacLab/main/source/setup/installation/
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
ISAAC_SIM_DIR="${WORKSPACE_DIR}/isaac-sim"
ISAAC_LAB_DIR="${WORKSPACE_DIR}/IsaacLab"
ISAAC_LAB_REPO="https://github.com/isaac-sim/IsaacLab.git"
ISAAC_LAB_BRANCH="main"  # or "v2.3.0" for stable
PYTHON_VERSION="3.11"
VENV_NAME="env_isaaclab"  # Created inside IsaacLab directory

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

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"

    local all_ok=true

    # Check if Isaac Sim is installed
    if [ -d "$ISAAC_SIM_DIR" ] && [ -f "${ISAAC_SIM_DIR}/isaac-sim.sh" ]; then
        print_success "Isaac Sim found: $ISAAC_SIM_DIR"

        # Check version
        if [ -f "${ISAAC_SIM_DIR}/VERSION" ]; then
            local sim_version=$(cat "${ISAAC_SIM_DIR}/VERSION")
            print_info "Isaac Sim version: $sim_version"
        fi
    else
        print_error "Isaac Sim not found at: $ISAAC_SIM_DIR"
        print_info "Please install Isaac Sim first using: ~/install_isaac_sim.sh"
        all_ok=false
    fi

    # Check Python (optional with uv - uv will download it automatically)
    if check_command python${PYTHON_VERSION}; then
        print_success "Python ${PYTHON_VERSION} found locally"
    else
        print_info "Python ${PYTHON_VERSION} not found locally (uv will download it automatically)"
    fi

    # Check for git
    if check_command git; then
        print_success "git found"
    else
        print_error "git not found. Install with: sudo apt install git"
        all_ok=false
    fi

    # Check for uv package manager
    if check_command uv; then
        print_success "uv package manager found"
    else
        print_warning "uv package manager not found. Installing..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
        if check_command uv; then
            print_success "uv installed successfully"
        else
            print_error "Failed to install uv. Install manually: https://docs.astral.sh/uv/"
            all_ok=false
        fi
    fi

    # Check for build tools
    if check_command gcc; then
        print_success "Build tools found"
    else
        print_warning "Build tools not found. Install with: sudo apt install build-essential"
    fi

    # Check disk space
    local available=$(df -BG "${HOME}" | tail -1 | awk '{print $4}' | sed 's/G//')
    local required=10  # GB
    if [ "$available" -ge "$required" ]; then
        print_success "Sufficient disk space: ${available}GB available"
    else
        print_warning "Low disk space: ${available}GB (recommended: ${required}GB+)"
    fi

    if [ "$all_ok" = false ]; then
        print_error "Prerequisites not met. Please resolve issues above."
        exit 1
    fi

    print_success "All prerequisites met!"
}

################################################################################
# Clone Isaac Lab Repository
################################################################################

clone_isaac_lab() {
    print_header "Cloning Isaac Lab Repository"

    cd "$WORKSPACE_DIR"

    # Clone repository
    if [ -d "IsaacLab" ]; then
        print_warning "IsaacLab directory already exists"
        read -p "Pull latest changes? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cd IsaacLab
            git pull || {
                print_warning "Git pull failed, continuing with existing version"
            }
            print_success "Updated Isaac Lab repository"
            cd ..
        fi
    else
        print_info "Cloning Isaac Lab repository..."
        print_info "Branch: $ISAAC_LAB_BRANCH"

        git clone --branch "$ISAAC_LAB_BRANCH" "$ISAAC_LAB_REPO" || {
            print_error "Failed to clone Isaac Lab repository"
            exit 1
        }
        print_success "Isaac Lab repository cloned"
    fi
}

################################################################################
# Python Environment Setup
################################################################################

setup_python_environment() {
    print_header "Setting Up Python Virtual Environment with Isaac Lab + UV"

    cd "${WORKSPACE_DIR}/IsaacLab"

    # Check if virtual environment exists
    if [ -d "${VENV_NAME}" ]; then
        print_warning "Virtual environment already exists: ${VENV_NAME}"
        read -p "Remove and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "${VENV_NAME}"
            print_info "Removed existing environment"
        else
            print_info "Using existing environment"
            source "${VENV_NAME}/bin/activate"
            return 0
        fi
    fi

    # IMPORTANT: For binary Isaac Sim, use Isaac Lab's official method
    # This ensures proper integration with Isaac Sim's modules
    print_info "Creating virtual environment using Isaac Lab's official method..."
    print_info "This ensures proper integration with binary Isaac Sim installation"

    ./isaaclab.sh --uv || {
        print_error "Failed to create virtual environment with isaaclab.sh --uv"
        exit 1
    }

    print_success "Virtual environment created with Isaac Sim integration"

    # Activate environment (it's in IsaacLab/env_isaaclab)
    if [ -f "env_isaaclab/bin/activate" ]; then
        source "env_isaaclab/bin/activate"
        print_success "Virtual environment activated"
    else
        print_error "Failed to find env_isaaclab/bin/activate"
        exit 1
    fi
}

################################################################################
# Isaac Lab Installation
################################################################################

install_isaac_lab() {
    print_header "Installing Isaac Lab Extensions"

    cd "${WORKSPACE_DIR}/IsaacLab"

    # Create symlink to Isaac Sim
    if [ -L "_isaac_sim" ]; then
        print_info "Isaac Sim symlink already exists"
        rm -f _isaac_sim
    fi

    ln -s "$ISAAC_SIM_DIR" _isaac_sim
    print_success "Created symlink: _isaac_sim -> $ISAAC_SIM_DIR"

    # Verify symlink
    if [ -f "_isaac_sim/VERSION" ]; then
        local sim_version=$(cat _isaac_sim/VERSION)
        print_success "Symlink verified - Isaac Sim version: $sim_version"
    else
        print_error "Symlink verification failed"
        exit 1
    fi

    # Ensure virtual environment is activated
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        source "${ISAAC_LAB_DIR}/${VENV_NAME}/bin/activate"
    fi

    # Ask user which RL frameworks to install
    echo ""
    print_info "Select RL frameworks to install:"
    echo "  1) All frameworks (default)"
    echo "  2) RSL-RL only (lightweight, recommended for Isaac Lab)"
    echo "  3) Stable Baselines 3 (sb3)"
    echo "  4) SKRL"
    echo "  5) None (minimal installation)"
    read -p "Enter choice [1-5] (default: 2): " framework_choice

    local framework_arg=""
    case "${framework_choice:-2}" in
        1) framework_arg="" ;;  # All frameworks
        2) framework_arg="rsl_rl" ;;
        3) framework_arg="sb3" ;;
        4) framework_arg="skrl" ;;
        5) framework_arg="none" ;;
        *) framework_arg="rsl_rl" ;;  # Default to rsl_rl
    esac

    # Install Isaac Lab extensions
    print_info "Installing Isaac Lab extensions and dependencies..."
    if [ -n "$framework_arg" ]; then
        print_info "Framework: $framework_arg"
    else
        print_info "Framework: all"
    fi
    print_warning "This may take 15-25 minutes depending on your system..."
    echo ""

    if [ -n "$framework_arg" ]; then
        ./isaaclab.sh --install "$framework_arg" || {
            print_error "Failed to install Isaac Lab extensions"
            print_info "Check the error messages above for details"
            exit 1
        }
    else
        ./isaaclab.sh --install || {
            print_error "Failed to install Isaac Lab extensions"
            print_info "Check the error messages above for details"
            exit 1
        }
    fi

    print_success "Isaac Lab installed successfully"
}

################################################################################
# Environment Configuration
################################################################################

configure_environment() {
    print_header "Configuring Environment"

    local activate_script="${ISAAC_LAB_DIR}/${VENV_NAME}/bin/activate"

    # Check if already configured
    if grep -q "ISAACLAB_PATH" "$activate_script" 2>/dev/null; then
        print_info "Environment activation already configured"
    else
        print_info "Adding Isaac Sim environment to activation script..."

        cat >> "$activate_script" << EOF

# Isaac Lab Environment Setup
export ISAACLAB_PATH="${ISAAC_LAB_DIR}"
export ISAACSIM_PATH="\${ISAACLAB_PATH}/_isaac_sim"
alias isaaclab="\${ISAACLAB_PATH}/isaaclab.sh"
export RESOURCE_NAME="IsaacSim"
EOF
        print_success "Environment configuration added"
    fi

    # Re-source to apply changes
    source "$activate_script"
    print_success "Environment variables configured"
}

################################################################################
# Verification
################################################################################

verify_installation() {
    print_header "Verifying Installation"

    cd "${WORKSPACE_DIR}/IsaacLab"

    # Ensure environment is active
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        source "${ISAAC_LAB_DIR}/${VENV_NAME}/bin/activate"
    fi

    # Set environment variables
    export ISAACLAB_PATH="${ISAAC_LAB_DIR}"
    export ISAACSIM_PATH="${ISAACLAB_PATH}/_isaac_sim"

    # Test imports
    print_info "Testing Python imports..."

    python -c "import isaacsim; print('✓ isaacsim module found')" 2>/dev/null || {
        print_warning "isaacsim module import failed (may need environment reactivation)"
    }

    python -c "from isaaclab.app import AppLauncher; print('✓ isaaclab.app module found')" 2>/dev/null || {
        print_warning "isaaclab.app import failed (environment may need reactivation)"
    }

    print_success "Basic verification completed"

    # Optional simulation test
    echo ""
    read -p "Run test simulation (opens simulator window)? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Running test script..."
        print_warning "Close the simulator window manually to continue"
        echo ""

        timeout 60 ./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py 2>&1 || {
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                print_info "Test timed out (normal for automated verification)"
            else
                print_warning "Test exited with code: $exit_code"
            fi
        }
    fi

    print_success "Installation verification complete"
}

################################################################################
# Post-Installation
################################################################################

post_installation() {
    print_header "Post-Installation Setup"

    # Shell configuration
    local shell_rc="${HOME}/.bashrc"
    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_rc="${HOME}/.zshrc"
    fi

    print_info "Adding shell aliases to $shell_rc"

    if grep -q "# Isaac Lab Environment" "$shell_rc" 2>/dev/null; then
        print_warning "Shell aliases already exist"
    else
        cat >> "$shell_rc" << EOF

# Isaac Lab Environment
export ISAAC_WORKSPACE="${WORKSPACE_DIR}"
alias isaac-lab='cd \${ISAAC_WORKSPACE}/IsaacLab && source \${ISAAC_WORKSPACE}/IsaacLab/${VENV_NAME}/bin/activate'
alias isaac-activate='source \${ISAAC_WORKSPACE}/IsaacLab/${VENV_NAME}/bin/activate'
alias isaac-sim='cd \${ISAAC_WORKSPACE}/isaac-sim'
EOF
        print_success "Added shell aliases"
        print_info "Restart terminal or run: source $shell_rc"
    fi

    # Quick-start script
    cat > "${WORKSPACE_DIR}/start_isaac_lab.sh" << 'EOF'
#!/bin/bash
# Isaac Lab Quick-Start Script

WORKSPACE_DIR="${HOME}/workspace"

cd "${WORKSPACE_DIR}/IsaacLab"
source "${WORKSPACE_DIR}/IsaacLab/env_isaaclab/bin/activate"

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   Isaac Lab Environment Activated!                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Quick Commands:"
echo "  ./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py"
echo "  ./isaaclab.sh -p scripts/tutorials/01_assets/run_articulation.py"
echo ""
echo "Documentation: https://isaac-sim.github.io/IsaacLab/"
echo ""

exec bash
EOF

    chmod +x "${WORKSPACE_DIR}/start_isaac_lab.sh"
    print_success "Created quick-start script: ${WORKSPACE_DIR}/start_isaac_lab.sh"

    # Installation info
    cat > "${WORKSPACE_DIR}/IsaacLab/INSTALLATION_INFO.txt" << EOF
Isaac Lab Installation Summary
==============================

Installation Date: $(date)
Script Version: 1.0

Isaac Lab:
- Location: ${WORKSPACE_DIR}/IsaacLab
- Branch: ${ISAAC_LAB_BRANCH}
- Repository: ${ISAAC_LAB_REPO}

Isaac Sim:
- Location: ${ISAAC_SIM_DIR}
- Symlink: ${WORKSPACE_DIR}/IsaacLab/_isaac_sim

Python Environment:
- Version: ${PYTHON_VERSION}
- Virtual Env: ${ISAAC_LAB_DIR}/${VENV_NAME}

System Information:
- OS: $(uname -s)
- Architecture: $(uname -m)

Quick Start:
1. cd ${ISAAC_LAB_DIR}
2. source ${VENV_NAME}/bin/activate
3. ./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py

Documentation:
https://isaac-sim.github.io/IsaacLab/

Support:
- Issues: https://github.com/isaac-sim/IsaacLab/issues
- Discussions: https://github.com/isaac-sim/IsaacLab/discussions
EOF

    print_success "Installation info saved"
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "Installation Complete! 🎉"

    echo -e "${GREEN}Isaac Lab has been successfully installed!${NC}\n"

    echo -e "${BLUE}📁 Installation Details:${NC}"
    echo -e "   Isaac Lab:    ${ISAAC_LAB_DIR}"
    echo -e "   Isaac Sim:    ${ISAAC_SIM_DIR}"
    echo -e "   Virtual Env:  ${ISAAC_LAB_DIR}/${VENV_NAME}"

    echo -e "\n${BLUE}🚀 Quick Start:${NC}"
    echo -e "   ${YELLOW}Option 1: Use quick-start script${NC}"
    echo -e "   ${GREEN}${WORKSPACE_DIR}/start_isaac_lab.sh${NC}"
    echo -e ""
    echo -e "   ${YELLOW}Option 2: Manual activation${NC}"
    echo -e "   ${GREEN}cd ${ISAAC_LAB_DIR}${NC}"
    echo -e "   ${GREEN}source ${VENV_NAME}/bin/activate${NC}"
    echo -e "   ${GREEN}./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py${NC}"

    echo -e "\n${BLUE}🔧 Shell Aliases (restart terminal):${NC}"
    echo -e "   ${YELLOW}isaac-lab${NC}       - Go to Isaac Lab and activate environment"
    echo -e "   ${YELLOW}isaac-activate${NC}  - Activate virtual environment"
    echo -e "   ${YELLOW}isaac-sim${NC}       - Go to Isaac Sim directory"

    echo -e "\n${BLUE}📚 Learning Resources:${NC}"
    echo -e "   Tutorials:      ${YELLOW}https://isaac-sim.github.io/IsaacLab/main/source/tutorials/${NC}"
    echo -e "   Documentation:  ${YELLOW}https://isaac-sim.github.io/IsaacLab/${NC}"
    echo -e "   Examples:       ${YELLOW}${WORKSPACE_DIR}/IsaacLab/scripts/tutorials/${NC}"

    echo -e "\n${GREEN}Happy Simulating! 🤖${NC}\n"
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
║            Isaac Lab Installation Script                     ║
║                                                               ║
║   This will install:                                          ║
║   • Isaac Lab (from GitHub)                                  ║
║   • Python 3.11 virtual environment                          ║
║   • All Isaac Lab dependencies                               ║
║                                                               ║
║   Prerequisites:                                              ║
║   • Isaac Sim must be installed first                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"

    # Confirm
    read -p "Proceed with Isaac Lab installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Record start time
    local start_time=$(date +%s)

    # Run installation
    check_prerequisites
    clone_isaac_lab
    setup_python_environment
    install_isaac_lab
    configure_environment
    verify_installation
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
