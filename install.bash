#!/bin/bash
# Filename: install.bash
# G90-SDR System Installation Script for Ubuntu 24.04 on Raspberry Pi 5
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details
#
# INSTALLATION PHILOSOPHY:
# This script follows a specific order designed to provide the best user experience:
#
# 1. Python 3.13 Setup (FIRST)
#    - Users need to know if Python is available before committing to installation
#    - Building Python from source takes 15-30 minutes - do this early
#    - Python must be ready before creating the virtual environment
#
# 2. Virtual Environment Creation (SECOND)
#    - Create the installation directory as a Python venv
#    - Copy all project files into the venv
#    - This makes the installation self-contained
#
# 3. Python Dependencies (THIRD - CRITICAL ORDERING)
#    - Install Python packages BEFORE building FlRig/GQRX
#    - WHY: If requirements.txt has problems, find out in 2 minutes, not 30 minutes
#    - WHY: Python environment is complete before 20-30 minute builds begin
#    - WHY: If builds fail, Python scripts are still usable
#
# 4. System Updates and Dependencies (FOURTH)
#    - Update system packages
#    - Install build tools, USB libraries, audio dependencies
#    - These are needed for FlRig and GQRX builds
#
# 5. Build FlRig and GQRX (FIFTH)
#    - These take 20-30 minutes to compile
#    - FlRig: Downloaded from SourceForge (official releases)
#    - GQRX: Cloned from GitHub (latest stable)
#    - Uses modular build-*.bash scripts for single source of truth
#
# 6. System Configuration (SIXTH)
#    - Set up permissions (dialout, audio groups)
#    - Create udev rules for USB devices
#    - These don't require user interaction
#
# 7. Verification (LAST)
#    - Confirm everything is installed correctly
#    - Provide next steps to user

set -e  # Exit on error (stop if any command fails)

#═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION LOGGING SETUP
#═══════════════════════════════════════════════════════════════════════════════
# Create comprehensive installation log that captures:
# - All output (stdout and stderr)
# - Timestamps for each operation
# - Success and failure messages
# - Build progress
#
# The log is saved to: $HOME/G90-SDR-install.log
#
# WHY WE LOG EVERYTHING:
# - Troubleshooting installation failures
# - Verifying what was installed
# - Debugging build issues
# - Keeping record of installation for support
#

# Create log file with timestamp
LOG_FILE="$HOME/G90-SDR-install-$(date +%Y%m%d-%H%M%S).log"
LATEST_LOG="$HOME/G90-SDR-install.log"

# Set log level (controls terminal verbosity, log always gets everything)
# Levels:
#   normal  - Show all output on terminal and in log (default)
#   quiet   - Show only major steps on terminal, all details in log
#   verbose - Extra debugging info (reserved for future use)
INSTALL_LOG_LEVEL="${INSTALL_LOG_LEVEL:-normal}"

# Validate log level
if [[ ! "$INSTALL_LOG_LEVEL" =~ ^(normal|quiet|verbose)$ ]]; then
    echo "Warning: Invalid INSTALL_LOG_LEVEL='$INSTALL_LOG_LEVEL', using 'normal'"
    INSTALL_LOG_LEVEL="normal"
fi

# Check if we're already logging (to prevent recursive re-execution)
if [ -z "$G90_INSTALL_LOGGING" ]; then
    # Not logging yet - set up logging and re-execute script
    export G90_INSTALL_LOGGING=1
    export INSTALL_LOG_LEVEL  # Make available to child processes

    # Print initial message to terminal
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "G90-SDR Installation - Logging Enabled (Level: $INSTALL_LOG_LEVEL)"
    echo "════════════════════════════════════════════════════════════════════"
    echo "All output will be saved to:"
    echo "  Log file: $LOG_FILE"
    echo "  Latest log: $LATEST_LOG"
    echo ""
    if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
        echo "Quiet mode: Terminal shows summaries, log has full details"
    fi
    echo "Monitor installation progress with:"
    echo "  tail -f ~/G90-SDR-install.log"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""

    # Create log file with header
    {
        echo "════════════════════════════════════════════════════════════════════"
        echo "G90-SDR Installation Log"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Log file: $LOG_FILE"
        echo "════════════════════════════════════════════════════════════════════"
        echo ""
    } > "$LOG_FILE"

    # Create symlink to latest log
    ln -sf "$LOG_FILE" "$LATEST_LOG"

    # Re-execute script with tee to capture all output
    bash "$0" "$@" 2>&1 | tee -a "$LOG_FILE"

    # Exit after re-execution completes
    exit ${PIPESTATUS[0]}
fi

# If we reach here, we're in the re-executed script with logging active

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================================================"
    echo "  $1"
    echo "========================================================================"
}

# Function to get apt-get quiet flags based on log level
get_apt_quiet_flags() {
    if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
        echo "-qq"
    else
        echo ""
    fi
}

# Store the script directory for reference
# We need this because we change directories during installation
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if running as root
# WHY: Virtual environments should be owned by the user, not root
# WHY: Building software as root is a security risk
# WHY: User permissions won't work correctly if installed as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    print_info "Run as normal user: bash install.sh"
    exit 1
fi

#═══════════════════════════════════════════════════════════════════════════════
# PRE-INSTALLATION ANALYSIS
#═══════════════════════════════════════════════════════════════════════════════
# Before asking user to commit to installation, we analyze their system to:
# 1. Detect what Python 3.13 version is available
# 2. Determine if we need to build Python from source (15-30 min)
# 3. Calculate accurate installation time estimate
# 4. Show user exactly what will happen on THEIR system
#
# This prevents surprises like "oh by the way, this will take an hour..."

# Step 1: Find the LATEST Python 3.13.x version from python.org
LATEST_313=$(curl -s https://www.python.org/ftp/python/ | grep -oP '3\.13\.\d+' | sort -V | tail -1)
if [ -z "$LATEST_313" ]; then
    LATEST_313="3.13.1"  # Fallback version
fi

# Step 2: Check if distro has Python 3.13 available
DISTRO_HAS_PYTHON313=false
DISTRO_PYTHON_VERSION=""
if apt-cache show python3.13 >/dev/null 2>&1; then
    DISTRO_PYTHON_VERSION=$(apt-cache show python3.13 | grep "^Version:" | head -1 | awk '{print $2}' | grep -oP '3\.13\.\d+')
    if [ -n "$DISTRO_PYTHON_VERSION" ]; then
        DISTRO_HAS_PYTHON313=true
    fi
fi

# Step 3: Check what's currently installed
CURRENT_INSTALLED_VERSION=""
if command -v python3.13 &> /dev/null; then
    CURRENT_INSTALLED_VERSION=$(python3.13 --version 2>&1 | awk '{print $2}')
fi

# Step 4: Decide what will happen with Python installation
PYTHON_ACTION=""
PYTHON_INSTALL_TIME=""

if [ "$CURRENT_INSTALLED_VERSION" = "$LATEST_313" ]; then
    PYTHON_ACTION="Python $LATEST_313 is already installed - no installation needed"
    PYTHON_INSTALL_TIME="0"
elif [ "$DISTRO_HAS_PYTHON313" = true ] && [ "$DISTRO_PYTHON_VERSION" = "$LATEST_313" ]; then
    PYTHON_ACTION="Install Python $LATEST_313 from distribution repositories"
    PYTHON_INSTALL_TIME="5-10"
elif [ "$DISTRO_HAS_PYTHON313" = true ]; then
    PYTHON_ACTION="Install Python $DISTRO_PYTHON_VERSION from distro, then upgrade to $LATEST_313 by building from source"
    PYTHON_INSTALL_TIME="20-30"
else
    PYTHON_ACTION="Build Python $LATEST_313 from source (distro does not provide Python 3.13)"
    PYTHON_INSTALL_TIME="15-30"
fi

# Calculate total installation time
if [ "$PYTHON_INSTALL_TIME" = "0" ]; then
    TOTAL_TIME="20-30 minutes"
else
    TOTAL_TIME="30-60 minutes"
fi

# Now show welcome message with specific information for this system
clear
echo "â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆ"
echo "  G90-SDR Installation Script"
echo "  Xiegu G90 Software Defined Radio Interface"
echo "  Version 0.5.0 - For Ubuntu 24.04 on Raspberry Pi 5"
echo "â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆ"
echo ""
echo "SYSTEM ANALYSIS COMPLETE - This installation will:"
echo ""
echo "  1. Python 3.13 Setup:"
echo "     → $PYTHON_ACTION"
if [ "$PYTHON_INSTALL_TIME" != "0" ]; then
    echo "     → Estimated time: $PYTHON_INSTALL_TIME minutes"
fi
echo ""
echo "  2. Virtual Environment:"
echo "     → Create Python virtual environment at your chosen location"
echo "     → All project files will be installed in this directory"
echo "     → Parent directories will be created automatically if needed"
echo ""
echo "  3. Software Installation (requires building from source):"
echo "     → FlRig - Radio control interface"
echo "     → GQRX - SDR receiver application"
echo "     → Python packages and dependencies"
echo ""
echo "  4. System Configuration:"
echo "     → Configure system for G90 SDR operation"
echo "     → Set up required permissions and scripts"
echo ""
echo "  ESTIMATED TOTAL TIME: $TOTAL_TIME"
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""

#═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION DIRECTORY SELECTION
#═══════════════════════════════════════════════════════════════════════════════
# The installation directory becomes a Python virtual environment containing:
# - Python interpreter and packages (in bin/, lib/)
# - All project files (scripts/, tests/, config/, etc.)
# - Documentation and utilities
#
# ENVIRONMENT VARIABLE PRIORITY (highest to lowest):
#
# 1. G90_SDR_DIR - Canonical production installation location
#    Example: export G90_SDR_DIR="$HOME/ham-radio/G90-SDR"
#    Use this for your main installation
#
# 2. L_SDR_DIR - Active development/testing installation
#    Example: export L_SDR_DIR="$HOME/development/G90-test"
#    Use this when testing changes before deploying to production
#
# 3. L_VIRT_DIR - Parent directory for virtual environments
#    Example: export L_VIRT_DIR="$HOME/Virtual"
#    Script will ask for directory name and create $L_VIRT_DIR/<name>
#    Use this if you keep all virtual environments in one place
#
# 4. No environment variables - Interactive prompt
#    User provides complete path or accepts default $HOME/G90-SDR
#
# WHY THIS SYSTEM:
# - Allows multiple installations (production + testing)
# - Scripts can find installation via environment variables
# - start-flrig.bash and start-gqrx.bash use same priority system

print_header "Installation Directory Selection"

INSTALL_DIR=""

# Check G90_SDR_DIR first (highest priority)
if [ -n "$G90_SDR_DIR" ]; then
    INSTALL_DIR="$G90_SDR_DIR"
    print_info "Using G90_SDR_DIR environment variable"
    print_info "Installation path: $INSTALL_DIR"
# Check L_SDR_DIR second
elif [ -n "$L_SDR_DIR" ]; then
    INSTALL_DIR="$L_SDR_DIR"
    print_info "Using L_SDR_DIR environment variable"
    print_info "Installation path: $INSTALL_DIR"
# Check L_VIRT_DIR third - ask for directory name to create within it
elif [ -n "$L_VIRT_DIR" ]; then
    print_info "Using L_VIRT_DIR environment variable: $L_VIRT_DIR"
    echo ""
    read -p "Enter installation directory name (or press Enter for default: G90-SDR): " DIR_NAME
    if [ -z "$DIR_NAME" ]; then
        DIR_NAME="G90-SDR"
    fi
    INSTALL_DIR="$L_VIRT_DIR/$DIR_NAME"
    print_info "Installation path: $INSTALL_DIR"
# If no environment variables set, ask for complete installation path
else
    echo ""
    print_warning "No environment variables are set (G90_SDR_DIR, L_SDR_DIR, or L_VIRT_DIR)"
    print_info "Please provide a complete installation path including directory name"
    echo ""
    read -p "Enter complete installation path (or press Enter for default: $HOME/G90-SDR): " USER_PATH
    if [ -z "$USER_PATH" ]; then
        INSTALL_DIR="$HOME/G90-SDR"
    else
        INSTALL_DIR="$USER_PATH"
    fi
    print_info "Installation path: $INSTALL_DIR"
fi

echo ""
print_success "Installation directory: $INSTALL_DIR"
print_info "This directory will be created as a Python virtual environment"
print_info "All Python packages will be installed within this virtual environment"
echo ""

# Confirm installation path with user
while true; do
    print_header "Confirm Installation Path"
    echo "Installation directory: $INSTALL_DIR"
    echo ""
    read -p "Use this installation path? Y)es, or N)o: " -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Validate write permissions by checking nearest existing ancestor
        CHECK_DIR="$INSTALL_DIR"
        while [ ! -d "$CHECK_DIR" ]; do
            CHECK_DIR=$(dirname "$CHECK_DIR")
        done

        if [ ! -w "$CHECK_DIR" ]; then
            echo ""
            print_error "Cannot write to directory: $CHECK_DIR"
            print_error "Please provide a path where you have write permissions"
            echo ""
            read -p "Enter complete installation path: " NEW_PATH
            if [ -n "$NEW_PATH" ]; then
                INSTALL_DIR="$NEW_PATH"
                print_info "Updated installation path: $INSTALL_DIR"
                echo ""
            fi
            continue
        fi

        # Show what will be created if path doesn't exist
        if [ ! -d "$INSTALL_DIR" ]; then
            print_info "Installation directory will be created: $INSTALL_DIR"
            echo ""
        fi

        break
    else
        echo ""
        print_warning "Please provide a different installation path"
        read -p "Enter complete installation path: " NEW_PATH
        if [ -n "$NEW_PATH" ]; then
            INSTALL_DIR="$NEW_PATH"
            print_info "Updated installation path: $INSTALL_DIR"
            echo ""
        else
            print_error "No path provided, keeping current path"
            echo ""
        fi
    fi
done

echo ""
print_success "Installation path confirmed: $INSTALL_DIR"
echo ""

# Python 3.13 Installation
print_header "Python 3.13 Setup"

print_info "Required: Python 3.13.x"
print_info "Latest available: $LATEST_313"

if [ -n "$CURRENT_INSTALLED_VERSION" ]; then
    print_info "Currently installed: $CURRENT_INSTALLED_VERSION"
fi

echo ""

# Determine what needs to be done based on earlier analysis
NEED_TO_INSTALL=false
INSTALL_METHOD="none"

if [ "$CURRENT_INSTALLED_VERSION" = "$LATEST_313" ]; then
    print_success "Python $LATEST_313 is already installed - no action needed"
elif [ "$DISTRO_HAS_PYTHON313" = true ] && [ "$DISTRO_PYTHON_VERSION" = "$LATEST_313" ]; then
    INSTALL_METHOD="distro"
    NEED_TO_INSTALL=true
    print_info "Will install Python $LATEST_313 from distribution repositories"
elif [ "$DISTRO_HAS_PYTHON313" = true ]; then
    INSTALL_METHOD="source"
    NEED_TO_INSTALL=true
    print_warning "Distribution has Python $DISTRO_PYTHON_VERSION, but latest is $LATEST_313"
    print_info "Will build Python $LATEST_313 from source"
else
    INSTALL_METHOD="source"
    NEED_TO_INSTALL=true
    print_warning "Distribution does not provide Python 3.13"
    print_info "Will build Python $LATEST_313 from source"
fi

echo ""

# Perform installation if needed
if [ "$NEED_TO_INSTALL" = true ]; then
    if [ "$INSTALL_METHOD" = "distro" ]; then
        read -p "Install Python $LATEST_313 from repository? Y)es, or N)o: " -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installing from repository..."
            sudo apt-get $(get_apt_quiet_flags) update
            sudo apt-get $(get_apt_quiet_flags) install -y python3.13 python3.13-dev python3.13-venv
            print_success "Python $LATEST_313 installed from repository"
        else
            print_error "Installation cancelled - Python 3.13 is required"
            exit 1
        fi
    elif [ "$INSTALL_METHOD" = "source" ]; then
        read -p "Build Python $LATEST_313 from source? (This will take 15-30 minutes) Y)es, or N)o: " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled - Python 3.13 is required"
            exit 1
        fi

        # Install build dependencies
        print_info "Installing Python build dependencies..."
        sudo apt-get $(get_apt_quiet_flags) install -y \
            build-essential \
            libssl-dev \
            zlib1g-dev \
            libncurses5-dev \
            libncursesw5-dev \
            libreadline-dev \
            libsqlite3-dev \
            libgdbm-dev \
            libdb5.3-dev \
            libbz2-dev \
            libexpat1-dev \
            liblzma-dev \
            tk-dev \
            libffi-dev \
            uuid-dev

        cd /tmp

        PYTHON_VERSION="$LATEST_313"
        print_info "Downloading Python ${PYTHON_VERSION}..."

        if [ -d "Python-${PYTHON_VERSION}" ]; then
            rm -rf "Python-${PYTHON_VERSION}"
        fi

        if ! wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"; then
            print_error "Failed to download Python ${PYTHON_VERSION}"
            print_error "Check internet connection or try again later"
            exit 1
        fi

        print_info "Extracting Python source..."
        tar xzf "Python-${PYTHON_VERSION}.tgz"
        cd "Python-${PYTHON_VERSION}"

        print_info "Configuring Python build..."
        if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
            ./configure --enable-optimizations --prefix=/usr/local >> "$LOG_FILE" 2>&1
        else
            ./configure --enable-optimizations --prefix=/usr/local
        fi

        print_info "Compiling Python (this will take 15-30 minutes)..."
        if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
            echo "  → Build in progress (full output in $LOG_FILE)"
            make -j$(nproc) >> "$LOG_FILE" 2>&1
            print_success "Python compilation completed"
        else
            make -j$(nproc)
        fi

        print_info "Installing Python (requires root)..."
        if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
            sudo make altinstall >> "$LOG_FILE" 2>&1
        else
            sudo make altinstall
        fi

        # Clean up (need sudo for root-owned files)
        cd /tmp
        sudo rm -rf "Python-${PYTHON_VERSION}" "Python-${PYTHON_VERSION}.tgz"

        cd "$SCRIPT_DIR"

        # Verify installation
        if command -v python3.13 &> /dev/null; then
            INSTALLED_VERSION=$(python3.13 --version 2>&1 | awk '{print $2}')
            print_success "Python ${INSTALLED_VERSION} built and installed successfully"
        else
            print_error "Python build completed but command not found"
            exit 1
        fi
    fi
fi

echo ""

# Final verification that we have python3.13
if ! command -v python3.13 &> /dev/null; then
    print_error "Python 3.13 is not available"
    print_error "Cannot proceed without Python 3.13"
    exit 1
fi

PYTHON_CMD="python3.13"
VERIFIED_VERSION=$(python3.13 --version 2>&1 | awk '{print $2}')
print_success "Using Python $VERIFIED_VERSION for virtual environment"

echo ""

# Create Python virtual environment immediately
print_header "Creating Python Virtual Environment"

print_info "Using Python command: $PYTHON_CMD"

print_info "Installation directory: $INSTALL_DIR"

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
        print_error "Failed to create directory: $INSTALL_DIR"
        print_error "Check permissions or path validity"
        exit 1
    fi
fi

# Check if virtual environment already exists
if [ -f "$INSTALL_DIR/bin/activate" ]; then
    # Venv exists - ask if user wants to recreate it
    print_warning "Virtual environment already exists at $INSTALL_DIR"
    read -p "Recreate virtual environment? Y)es, or N)o: " -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing existing virtual environment..."
        if ! rm -rf "$INSTALL_DIR" 2>/dev/null; then
            print_error "Failed to remove existing virtual environment"
            print_error "Check permissions for: $INSTALL_DIR"
            exit 1
        fi
        mkdir -p "$INSTALL_DIR"
        # Force recreation below
        FORCE_VENV_CREATE=1
    else
        # User chose not to recreate - skip venv creation
        FORCE_VENV_CREATE=0
    fi
else
    # No venv exists - will create it below
    FORCE_VENV_CREATE=1
fi

# Create virtual environment if needed
if [ "$FORCE_VENV_CREATE" = "1" ] && [ ! -f "$INSTALL_DIR/bin/activate" ]; then
    print_info "Creating virtual environment at $INSTALL_DIR..."
    if ! $PYTHON_CMD -m venv "$INSTALL_DIR"; then
        print_error "Failed to create Python virtual environment"
        print_error "Target directory: $INSTALL_DIR"
        print_error "Ensure python venv module is available"
        exit 1
    fi
    print_success "Virtual environment created at $INSTALL_DIR"
elif [ -f "$INSTALL_DIR/bin/activate" ]; then
    print_success "Using existing virtual environment at $INSTALL_DIR"
fi

# Copy repository files to installation directory
print_header "Copying Repository Files"
print_info "Copying project files to $INSTALL_DIR..."

# Copy directories
for dir in scripts tests utils docs config misc; do
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        print_info "Copying $dir/..."
        cp -r "$SCRIPT_DIR/$dir" "$INSTALL_DIR/"
    fi
done

# Copy important files from root
print_info "Copying configuration and documentation files..."
for file in requirements.txt README.md INSTALL.md CHANGE_LOG.md USER_GUIDE.md; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp "$SCRIPT_DIR/$file" "$INSTALL_DIR/"
    fi
done

# Copy bash scripts (make them executable)
print_info "Copying utility scripts..."
for script in *.bash CheckCrashes.bash; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$script"
    fi
done

# Remove any __pycache__ directories that were copied
find "$INSTALL_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

print_success "Repository files copied to installation directory"

# Run fix_all.bash to set proper permissions on all copied files
print_info "Setting executable permissions on scripts..."
if [ -f "$INSTALL_DIR/fix_all.bash" ]; then
    cd "$INSTALL_DIR"
    bash fix_all.bash
    cd "$SCRIPT_DIR"
    print_success "Permissions fixed on all executable files"
else
    print_warning "fix_all.bash not found, skipping permission fix"
fi

#═══════════════════════════════════════════════════════════════════════════════
# Step 4: Install Python dependencies
#═══════════════════════════════════════════════════════════════════════════════
# CRITICAL: Python dependencies are installed BEFORE building FlRig and GQRX
#
# WHY THIS ORDER IS IMPORTANT:
#
# 1. FAST FAILURE DETECTION
#    - If requirements.txt has problems, we find out in ~2 minutes
#    - Alternative: Wait 20-30 minutes for builds, THEN discover pip issues
#    - Better user experience: Fail fast, not slow
#
# 2. COMPLETE PYTHON ENVIRONMENT BEFORE BUILDS
#    - Python environment is fully functional before lengthy builds
#    - If FlRig or GQRX builds fail, Python scripts still work
#    - User can test Python functionality while troubleshooting builds
#
# 3. LOGICAL GROUPING
#    - All Python setup happens together:
#      * Python 3.13 installation
#      * Virtual environment creation
#      * Package installation
#    - System builds (FlRig/GQRX) are separate concern
#
# 4. NO DEPENDENCY ON FLRIG/GQRX
#    - Python packages don't need FlRig or GQRX to be installed
#    - FlRig and GQRX are standalone C++ applications
#    - Only connection: Python scripts CALL FlRig via XML-RPC (at runtime)
#
# TECHNICAL NOTE:
# We call pip directly ($VENV_PIP) instead of activating the venv because:
# - Works in non-interactive scripts
# - Explicit about which Python environment we're using
# - No need to source activate script and manage shell state
#
print_header "Step 4: Installing Python Dependencies in Virtual Environment"

print_info "Using virtual environment at $INSTALL_DIR..."
# Use the venv's pip directly instead of activating
VENV_PIP="$INSTALL_DIR/bin/pip"
VENV_PYTHON="$INSTALL_DIR/bin/python"

# Verify venv exists (safety check - should always pass if we got here)
if [ ! -f "$VENV_PIP" ]; then
    print_error "Virtual environment pip not found: $VENV_PIP"
    print_error "Virtual environment may not be properly created"
    exit 1
fi

# Upgrade pip/setuptools/wheel first to avoid compatibility issues
# Old versions of pip can fail to install modern packages
print_info "Upgrading pip..."
if ! "$VENV_PIP" install --upgrade pip setuptools wheel; then
    print_error "Failed to upgrade pip, setuptools, and wheel"
    exit 1
fi

# Install all Python packages from requirements.txt
# This includes: pyserial, xmlrpc, etc. for talking to FlRig
print_info "Installing Python dependencies from requirements.txt..."
if [ ! -f "$INSTALL_DIR/requirements.txt" ]; then
    print_error "Requirements file not found: $INSTALL_DIR/requirements.txt"
    exit 1
fi

if ! "$VENV_PIP" install -r "$INSTALL_DIR/requirements.txt"; then
    print_error "Failed to install Python dependencies"
    print_error "Check $INSTALL_DIR/requirements.txt for issues"
    exit 1
fi

print_success "Python dependencies installed in virtual environment"

echo ""
print_header "Confirm Installation"
echo "This will install G90-SDR and its dependencies to:"
echo "  $INSTALL_DIR"
echo ""
read -p "Continue with installation? Y)es, or N)o: " -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 0
fi
echo ""

# Step 5: Update system
print_header "Step 5: Updating System"
print_info "Updating package lists..."
sudo apt-get $(get_apt_quiet_flags) update

print_info "Upgrading packages (this may take a while)..."
sudo apt-get $(get_apt_quiet_flags) upgrade -y

print_success "System updated"

# Step 6: Install system dependencies
print_header "Step 6: Installing System Dependencies"

print_info "Installing build tools..."
sudo apt-get $(get_apt_quiet_flags) install -y \
    build-essential \
    git \
    cmake \
    pkg-config \
    wget \
    curl

print_info "Installing Python 3..."
sudo apt-get $(get_apt_quiet_flags) install -y python3 python3-dev python3-pip python3-venv

print_info "Installing USB and serial libraries..."
sudo apt-get $(get_apt_quiet_flags) install -y \
    libusb-1.0-0-dev \
    libudev-dev \
    python3-serial

print_success "System dependencies installed"

# Step 7: Install audio dependencies
print_header "Step 7: Installing Audio Dependencies"

print_info "Installing PulseAudio..."
sudo apt-get $(get_apt_quiet_flags) install -y \
    pulseaudio \
    pulseaudio-utils \
    pavucontrol \
    libasound2-dev \
    portaudio19-dev

print_info "Installing Python audio libraries dependencies..."
sudo apt-get $(get_apt_quiet_flags) install -y \
    python3-pyaudio \
    libportaudio2 \
    libportaudiocpp0

print_success "Audio dependencies installed"

#═══════════════════════════════════════════════════════════════════════════════
# Step 8: Build FlRig and GQRX from Source
#═══════════════════════════════════════════════════════════════════════════════
# MODULAR BUILD SYSTEM - Single Source of Truth Architecture
#
# WHY WE USE MODULAR BUILD SCRIPTS:
#
# This install.bash script CALLS utils/build-flrig.bash and utils/build-gqrx.bash
# rather than duplicating the build logic here. This is intentional and critical.
#
# HISTORY - THE BUG THAT TAUGHT US:
# Originally, install.bash had its own FlRig build code that was DIFFERENT from
# rebuild_all.bash. The result:
#   - install.bash: Cloned FlRig from GitHub → got v2.0.0 (old, broken)
#   - rebuild_all.bash: Downloaded from SourceForge → got v2.0.9 (correct)
# Users would install, get a broken version, then be confused when rebuild worked!
#
# SOLUTION - SINGLE SOURCE OF TRUTH:
# Build logic exists in ONE place per software:
#   - FlRig build: utils/build-flrig.bash (downloads from SourceForge)
#   - GQRX build: utils/build-gqrx.bash (clones from GitHub)
#
# Both install.bash and rebuild_all.bash CALL these same scripts.
# Now it's impossible for them to build differently!
#
# WHY SOURCEFORGE FOR FLRIG:
# - SourceForge has official release tarballs (stable versions)
# - GitHub has development code (may be unstable)
# - We download latest stable: flrig-2.0.09.tar.gz
#
# WHY GITHUB FOR GQRX:
# - GitHub is the official GQRX repository
# - We clone and build from latest stable tag
# - Active development, frequent updates
#
# INTERACTIVE PROMPTS:
# - If software already installed: Ask user if they want to rebuild
# - If not installed: Build automatically
# - This prevents re-downloading/rebuilding unnecessarily
#
# ESTIMATED TIME:
# - FlRig: ~10-15 minutes (FLTK GUI toolkit, smaller codebase)
# - GQRX: ~15-20 minutes (Qt5, GNU Radio, larger dependencies)
# - Total: ~20-30 minutes
#
print_header "Step 8: Building FlRig from Source"

#──────────────────────────────────────────────────────────────────────────────
# FlRig Build
#──────────────────────────────────────────────────────────────────────────────
# Check if FlRig is already installed
BUILD_FLRIG=0
if command -v flrig &> /dev/null; then
    # Already installed - ask user if they want to rebuild
    FLRIG_VERSION=$(flrig --version 2>&1 | head -1 || echo "unknown")
    print_info "FlRig already installed: $FLRIG_VERSION"
    read -p "Rebuild FlRig from latest source? Y)es, or N)o: " -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BUILD_FLRIG=1
    else
        print_info "Skipping FlRig build (using existing installation)"
    fi
else
    # Not installed - build it
    print_info "FlRig not currently installed"
    BUILD_FLRIG=1
fi

# Build FlRig if needed by calling modular build script
if [ $BUILD_FLRIG -eq 1 ]; then
    if [ -f "$SCRIPT_DIR/utils/build-flrig.bash" ]; then
        print_info "Building FlRig from SourceForge latest release..."
        # Call the modular build script - single source of truth
        bash "$SCRIPT_DIR/utils/build-flrig.bash"
    else
        print_error "build-flrig.bash not found at $SCRIPT_DIR/utils/build-flrig.bash"
        print_error "Cannot continue without build script"
        exit 1
    fi
fi

# Step 9: Install SDR++ from source (latest stable version)
print_header "Step 9: Building SDR++ from Source"

if command -v sdrpp &> /dev/null; then
    SDRPP_VERSION=$(sdrpp --help 2>&1 | head -1 | grep -oP 'SDR\+\+ v[\d.]+' || echo "SDR++ (version unknown)")
    print_info "SDR++ already installed: $SDRPP_VERSION"
    read -p "Rebuild SDR++ from latest source? Y)es, or N)o: " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping SDR++ installation"
    else
        BUILD_SDRPP=1
    fi
else
    BUILD_SDRPP=1
fi

if [ -n "$BUILD_SDRPP" ]; then
    print_info "Installing SDR++ dependencies..."
    sudo apt install -y \
        git \
        build-essential \
        cmake \
        libfftw3-dev \
        libglfw3-dev \
        libglew-dev \
        libvolk-dev \
        librtaudio-dev \
        librtlsdr-dev \
        libsoapysdr-dev \
        libairspyhf-dev \
        libiio-dev \
        libad9361-dev \
        libhackrf-dev \
        libairspy-dev \
        zlib1g-dev \
        libzstd-dev

    print_info "Cloning SDR++ repository..."
    cd /tmp

    if [ -d "SDRPlusPlus" ]; then
        rm -rf SDRPlusPlus
    fi

    git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
    cd SDRPlusPlus

    # Build from master branch (includes all latest fixes for Ubuntu 24.04)
    print_info "Using SDR++ master branch (development version)..."
    print_info "This includes all latest bug fixes and features"
    git checkout master

    # Get current commit hash for version tracking
    SDRPP_COMMIT=$(git rev-parse --short HEAD)
    print_info "Building SDR++ from commit: $SDRPP_COMMIT"

    print_info "Configuring SDR++ build..."
    mkdir build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

    print_info "Compiling SDR++ (this will take 5-10 minutes on Raspberry Pi 5)..."
    make -j$(nproc)

    print_info "Installing SDR++..."
    sudo make install
    sudo ldconfig

    # Clean up
    cd /tmp
    rm -rf SDRPlusPlus

    cd "$SCRIPT_DIR"

    # Verify installation
    if command -v sdrpp &> /dev/null; then
        print_success "SDR++ built and installed successfully"
    else
        print_error "SDR++ build succeeded but command not found in PATH"
        print_warning "This may resolve after logout/login"
    fi
fi

# Verify installations
print_info "Verifying builds..."
if command -v flrig &> /dev/null; then
    FLRIG_VERSION=$(flrig --version 2>&1 | head -1)
    print_success "FlRig: $FLRIG_VERSION"
else
    print_warning "FlRig: Not found (may require logout/reboot)"
fi

if command -v sdrpp &> /dev/null; then
    print_success "SDR++: Installed"
else
    print_warning "SDR++: Not found (may require logout/reboot)"
fi

# Configure SDR++ for G90-SDR
print_header "Step 10: Configuring SDR++ for G90-SDR"

print_info "Configuring SDR++ rigctl server..."
if source "$INSTALL_DIR/bin/activate" && python3 "$INSTALL_DIR/scripts/configure_sdrpp.py"; then
    print_success "SDR++ configured successfully"
else
    print_warning "SDR++ configuration completed with notes (see above)"
    print_info "You may need to run SDR++ once, then run configure_sdrpp.py again"
fi

# Step 11: Configure system permissions
print_header "Step 11: Configuring System Permissions"

print_info "Adding user to dialout group (for serial port access)..."
sudo usermod -a -G dialout "$USER"

print_info "Adding user to audio group..."
sudo usermod -a -G audio "$USER"

print_info "Creating udev rules for DE-19 interface..."
sudo tee /etc/udev/rules.d/99-xiegu.rules > /dev/null << 'EOF'
# Xiegu DE-19 Data Interface (CH340 USB-to-serial)
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"
EOF

print_info "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

print_success "Permissions configured"

# Step 11: Create configuration files
print_header "Step 12: Creating Configuration Files"

print_info "Creating config directory in installation..."
mkdir -p "$INSTALL_DIR/config"

if [ ! -f "$INSTALL_DIR/config/flrig_g90.xml" ]; then
    print_info "Creating FlRig configuration..."
    cat > "$INSTALL_DIR/config/flrig_g90.xml" << 'EOF'
<?xml version="1.0"?>
<FLRIG>
  <RIG>
    <XCVR>Xiegu G90</XCVR>
    <DEVICE>/dev/ttyUSB0</DEVICE>
    <BAUDRATE>19200</BAUDRATE>
    <RETRIES>5</RETRIES>
    <TIMEOUT>200</TIMEOUT>
    <WRITE_DELAY>0</WRITE_DELAY>
    <INIT_DELAY>0</INIT_DELAY>
    <RESTORE_TTY>1</RESTORE_TTY>
    <CAT_COMMANDS>1</CAT_COMMANDS>
    <RTS_CTS_FLOW>0</RTS_CTS_FLOW>
    <RTSptt>0</RTSptt>
    <DTRptt>0</DTRptt>
  </RIG>
  <SERVER>
    <USE_XML_RPC>1</USE_XML_RPC>
    <PORT>12345</PORT>
    <ADDRESS>127.0.0.1</ADDRESS>
  </SERVER>
</FLRIG>
EOF
    print_success "FlRig configuration created"
else
    print_info "FlRig configuration already exists, skipping"
fi

# Create user settings file
if [ ! -f "$INSTALL_DIR/config/settings.json" ]; then
    print_info "Creating user settings configuration..."
    echo ""
    echo "When you run 'start_sdr.py' to launch the G90-SDR system, you can choose:"
    echo ""
    echo "  I)nteractive mode:"
    echo "    - Script pauses before starting FlRig (wait for your confirmation)"
    echo "    - Script pauses before starting SDR++ (wait for your confirmation)"
    echo "    - You manually verify each step before continuing"
    echo "    - Good for learning the system or troubleshooting"
    echo ""
    echo "  A)utomatic mode:"
    echo "    - Script launches FlRig and SDR++ automatically"
    echo "    - No pauses or confirmations needed"
    echo "    - Faster startup once you know the system works"
    echo "    - Good for experienced users"
    echo ""

    # Loop until valid choice is made
    while true; do
        read -p "Which mode do you prefer? A)utomatic or I)nteractive: " -r

        if [[ -z "$REPLY" ]]; then
            echo ""
            print_warning "Please make a choice - press 'A' or 'I'"
            echo ""
            continue
        fi

        if [[ $REPLY =~ ^[Ii]$ ]]; then
            INTERACTIVE_JSON="true"
            print_success "I)nteractive mode selected - start_sdr.py will pause for confirmation at each step"
            break
        elif [[ $REPLY =~ ^[Aa]$ ]]; then
            INTERACTIVE_JSON="false"
            print_success "A)utomatic mode selected - start_sdr.py will launch everything automatically"
            break
        else
            echo ""
            print_warning "Invalid input '$REPLY' - please enter 'A' or 'I'"
            echo ""
        fi
    done
    echo ""
    print_info "You can change this later by editing: config/settings.json"
    echo ""

    cat > "$INSTALL_DIR/config/settings.json" << EOF
{
  "startup": {
    "interactive_mode": $INTERACTIVE_JSON,
    "_comment": "Set interactive_mode to false to skip manual confirmation prompts during startup"
  },
  "network": {
    "flrig_host": "127.0.0.1",
    "flrig_port": 12345,
    "sdr_host": "127.0.0.1",
    "sdr_port": 4532,
    "_comment": "Network settings for FlRig XML-RPC and SDR++ rigctl server"
  },
  "_info": "To change settings, run: python3 scripts/edit_settings.py (or edit this file manually)"
}
EOF

    print_success "User settings saved to: config/settings.json"
else
    print_info "User settings already exist, skipping configuration prompt"
fi
echo ""

# Step 12: Verify installation
print_header "Step 13: Verifying Installation"

print_info "Checking Python version..."
PYTHON_VERSION=$(python3 --version)
print_success "Python: $PYTHON_VERSION"

print_info "Checking FlRig..."
if command -v flrig &> /dev/null; then
    FLRIG_VERSION=$(flrig --version 2>&1 | head -1 || echo "unknown")
    print_success "FlRig: $FLRIG_VERSION"
else
    print_warning "FlRig: Not found"
fi

print_info "Checking SDR++..."
if command -v sdrpp &> /dev/null; then
    print_success "SDR++: Installed"
else
    print_warning "SDR++: Not found"
fi

print_info "Checking USB device..."
if lsusb | grep -i "1a86:7523" &> /dev/null; then
    print_success "CH340 USB-to-serial device detected"
else
    print_warning "CH340 device not detected (G90 may not be connected)"
fi

# Final message
print_header "Installation Complete!"

echo ""
echo "Installation Directory: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "1. Logout and login for group permissions to take effect"
echo "   (No reboot required)"
echo ""
echo "2. After logging back in, navigate to the installation directory:"
echo "   cd $INSTALL_DIR"
echo ""
echo "3. Activate the virtual environment:"
echo "   source bin/activate"
echo ""
echo "4. Test the connection:"
echo "   python tests/TestConnection.py"
echo ""
echo "5. Start FlRig:"
echo "   flrig --config-dir ~/.flrig"
echo ""
echo "4. Launch SDR++:"
echo "   sdrpp"
echo ""
echo "For more information, see USER_GUIDE.md"
echo ""
echo "Environment variables used:"
echo "  G90_SDR_DIR: ${G90_SDR_DIR:-not set}"
echo "  L_SDR_DIR: ${L_SDR_DIR:-not set}"
echo "  L_VIRT_DIR: ${L_VIRT_DIR:-not set}"
echo ""

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "Installation Log"
echo "════════════════════════════════════════════════════════════════════"
echo "Complete installation log saved to:"
echo "  $LOG_FILE"
echo ""
echo "Symlink to latest log:"
echo "  $LATEST_LOG"
echo ""
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════════════════"
echo ""
