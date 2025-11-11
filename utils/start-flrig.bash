#!/bin/bash
# Filename: utils/start-flrig.bash
# Start FlRig with G90 configuration
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details
#
#═══════════════════════════════════════════════════════════════════════════════
# PURPOSE: Launch FlRig with proper G90 transceiver configuration
#═══════════════════════════════════════════════════════════════════════════════
#
# WHAT THIS SCRIPT DOES:
# 1. Finds the G90-SDR installation directory (using environment variables)
# 2. Copies G90 configuration files to FlRig's config directory (~/.flrig/)
# 3. Launches FlRig, which reads the configuration and connects to the G90
#
# CONFIGURATION FILES (FLTK Preferences Format):
#
# FlRig uses FLTK (Fast Light Toolkit) preferences format, NOT XML!
# We had a bug where we used XML format - FlRig couldn't read it.
#
# Three files are required:
#
# 1. Xiegu-G90.prefs (7KB, main transceiver configuration)
#    - Serial port: /dev/ttyUSB0
#    - Baud rate: 19200
#    - XML-RPC server: 127.0.0.1:12345 (for Python scripts to control rig)
#    - Frequency/mode memory
#    - PTT settings, polling rates, etc.
#
# 2. flrig.prefs (tiny file, tells FlRig which transceiver to use)
#    - Contains: xcvr_name:Xiegu-G90
#    - This tells FlRig to load Xiegu-G90.prefs
#
# 3. default.prefs (UI settings)
#    - Color scheme
#    - Fonts
#    - Meter colors (S-meter green, power red, SWR purple, etc.)
#
# WHY WE COPY CONFIGS EVERY TIME:
# - User might modify FlRig settings during operation
# - Next launch, we restore known-good configuration
# - Prevents issues from user accidentally changing critical settings
# - User can still modify settings, they just reset on next launch
#
# ENVIRONMENT VARIABLE PRIORITY (same as install.bash):
# 1. G90_SDR_DIR (production installation)
# 2. L_SDR_DIR (development/testing)
# 3. Current directory (if running from G90-SDR directory)
# 4. Common locations ($HOME/Virtual/G90-SDR, $HOME/G90-SDR, etc.)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

#──────────────────────────────────────────────────────────────────────────────
# Function: find_installation
#──────────────────────────────────────────────────────────────────────────────
# PURPOSE: Locate the G90-SDR installation directory
#
# HOW IT WORKS:
# Searches multiple locations in priority order. First match wins.
# We verify each location has config/Xiegu-G90.prefs to confirm it's valid.
#
# PRIORITY ORDER (highest to lowest):
#
# 1. G90_SDR_DIR environment variable
#    - For production installations
#    - Example: export G90_SDR_DIR="$HOME/ham-radio/G90-SDR"
#    - This is the "canonical" installation
#
# 2. L_SDR_DIR environment variable
#    - For development/testing installations
#    - Example: export L_SDR_DIR="$HOME/development/G90-test"
#    - Allows testing new configs without affecting production
#
# 3. Current working directory
#    - If you're running from within the G90-SDR directory
#    - Checks for config/Xiegu-G90.prefs in current directory
#    - Convenient for development: cd G90-SDR && bash utils/start-flrig.bash
#
# 4. Common installation locations (hardcoded fallbacks)
#    - $HOME/Virtual/G90-SDR (virtual environments directory)
#    - $HOME/G90-SDR (user home directory)
#    - $HOME/Documents/G90-SDR (Documents folder)
#    - /opt/G90-SDR (system-wide installation)
#
# RETURNS:
# - Prints directory path to stdout (captured by caller)
# - Returns 0 (success) if found
# - Returns 1 (failure) if not found
#
# WHY THIS SYSTEM:
# - Allows multiple installations (production + testing)
# - Environment variables take precedence over hardcoded paths
# - Developers can easily switch between installations
# - Matches the same priority system used by install.bash
#
find_installation() {
    # Priority 1: G90_SDR_DIR (canonical production)
    if [ -n "$G90_SDR_DIR" ] && [ -d "$G90_SDR_DIR" ] && [ -f "$G90_SDR_DIR/config/Xiegu-G90.prefs" ]; then
        echo "$G90_SDR_DIR"
        return 0
    fi

    # Priority 2: L_SDR_DIR (active/testing)
    if [ -n "$L_SDR_DIR" ] && [ -d "$L_SDR_DIR" ] && [ -f "$L_SDR_DIR/config/Xiegu-G90.prefs" ]; then
        echo "$L_SDR_DIR"
        return 0
    fi

    # Priority 3: Current directory if running from G90-SDR directory
    if [ -f "config/Xiegu-G90.prefs" ]; then
        pwd  # Print current working directory
        return 0
    fi

    # Priority 4: Common locations (hardcoded fallbacks)
    local LOCATIONS=(
        "$HOME/Virtual/G90-SDR"
        "$HOME/G90-SDR"
        "$HOME/Documents/G90-SDR"
        "/opt/G90-SDR"
    )

    for location in "${LOCATIONS[@]}"; do
        if [ -d "$location" ] && [ -f "$location/config/Xiegu-G90.prefs" ]; then
            echo "$location"
            return 0
        fi
    done

    # Not found anywhere
    return 1
}

# Main
main() {
    echo "████████████████████████████████████████████████████████████████████████"
    echo "  FlRig Startup Script for Xiegu G90"
    echo "████████████████████████████████████████████████████████████████████████"
    echo ""

    # Check if FlRig is installed
    if ! command -v flrig &> /dev/null; then
        print_error "FlRig is not installed!"
        echo ""
        echo "Install FlRig using one of these methods:"
        echo "  1. From package manager: sudo apt install flrig"
        echo "  2. Build from source: bash utils/rebuild_all.bash"
        echo ""
        exit 1
    fi

    FLRIG_VERSION=$(flrig --version 2>&1 | head -1)
    print_success "FlRig found: $FLRIG_VERSION"

    # Find G90-SDR installation
    print_info "Searching for G90 configuration..."
    SDR_DIR=$(find_installation)

    if [ -z "$SDR_DIR" ]; then
        print_warning "G90-SDR config not found, launching FlRig with default settings"
        echo ""
        print_info "Starting FlRig..."
        exec flrig "$@"
    fi

    print_success "Found G90-SDR installation: $SDR_DIR"

    #──────────────────────────────────────────────────────────────────────────
    # Setup FlRig config directory and copy configuration files
    #──────────────────────────────────────────────────────────────────────────
    FLRIG_DIR="$HOME/.flrig"    # FlRig reads config from here
    CONFIG_DIR="$SDR_DIR/config" # Our known-good config files

    # Create FlRig config directory if it doesn't exist
    # (First time running FlRig, this won't exist yet)
    if [ ! -d "$FLRIG_DIR" ]; then
        print_info "Creating FlRig config directory: $FLRIG_DIR"
        mkdir -p "$FLRIG_DIR"
    fi

    # Copy all three FLTK preferences files to FlRig config directory
    # WHY THREE FILES:
    # - Xiegu-G90.prefs: Main config (serial port, baud rate, XML-RPC, etc.)
    # - flrig.prefs: Tells FlRig to load Xiegu-G90.prefs
    # - default.prefs: UI colors and fonts
    #
    # WHY COPY EVERY TIME:
    # - Resets to known-good configuration on each launch
    # - User might have changed settings during operation
    # - Prevents issues from accidental configuration changes
    if [ -f "$CONFIG_DIR/Xiegu-G90.prefs" ]; then
        print_info "Copying G90 configuration files to $FLRIG_DIR"
        cp "$CONFIG_DIR/Xiegu-G90.prefs" "$FLRIG_DIR/"
        cp "$CONFIG_DIR/flrig.prefs" "$FLRIG_DIR/"
        cp "$CONFIG_DIR/default.prefs" "$FLRIG_DIR/"
    else
        print_warning "G90 config not found at $CONFIG_DIR/Xiegu-G90.prefs"
    fi

    echo ""
    print_info "Starting FlRig with G90 configuration..."
    echo ""

    #──────────────────────────────────────────────────────────────────────────
    # Launch FlRig
    #──────────────────────────────────────────────────────────────────────────
    # WHY WE USE "exec":
    # - exec replaces this shell process with FlRig
    # - FlRig becomes process ID of this script (cleaner process tree)
    # - Signals (Ctrl+C, kill, etc.) go directly to FlRig
    # - When FlRig exits, script exits (no leftover shell process)
    #
    # "$@" passes all command-line arguments to FlRig
    # Example: bash start-flrig.bash --debug
    #   FlRig receives the --debug argument
    #
    # FlRig will now:
    # 1. Read ~/.flrig/flrig.prefs (sees xcvr_name:Xiegu-G90)
    # 2. Load ~/.flrig/Xiegu-G90.prefs (serial port /dev/ttyUSB0, 19200 baud)
    # 3. Load ~/.flrig/default.prefs (UI colors/fonts)
    # 4. Connect to G90 via /dev/ttyUSB0
    # 5. Start XML-RPC server on 127.0.0.1:12345 (for Python scripts)
    #
    exec flrig "$@"
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "FlRig Startup Script for Xiegu G90"
        echo ""
        echo "Usage: bash utils/start-flrig.bash [FLRIG_OPTIONS]"
        echo ""
        echo "This script will:"
        echo "  • Check if FlRig is installed"
        echo "  • Find the G90-SDR configuration"
        echo "  • Launch FlRig with G90 settings and auto-connect"
        echo ""
        echo "Any additional options are passed to FlRig"
        echo ""
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
