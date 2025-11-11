#!/bin/bash
# Filename: utils/start-gqrx.bash
# Start GQRX with G90 SDR configuration
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details
#
#═══════════════════════════════════════════════════════════════════════════════
# PURPOSE: Launch GQRX with proper G90 panadapter configuration
#═══════════════════════════════════════════════════════════════════════════════
#
# WHAT THIS SCRIPT DOES:
# 1. Finds the G90-SDR installation directory (using environment variables)
# 2. Copies GQRX configuration to ~/.config/gqrx/default.conf
# 3. Launches GQRX, which displays waterfall and spectrum for G90 audio
#
# HOW THE G90 SDR SYSTEM WORKS:
#
# ┌──────────┐  USB Serial   ┌───────────┐  XML-RPC      ┌────────────────┐
# │ Xiegu G90│─────CAT──────>│   FlRig   │<─port 12345──>│ frequency_sync │
# │   Radio  │               │ (Control) │               │   (Python)     │
# └──────────┘               └───────────┘               └────────────────┘
#      │                                                          │
#      │ Audio                                             TCP port 7356
#      │ (I/Q from IF Out)                                       │
#      ↓                                                          ↓
# ┌──────────┐            ┌────────────┐               ┌─────────────────┐
# │Pulse Audio│─────────>│   GQRX    │<──frequency──>│   GQRX Remote   │
# │  (48kHz) │            │ (Display) │               │     Control     │
# └──────────┘            └───────────┘               └─────────────────┘
#
# DATA FLOW:
# 1. G90 sends I/Q audio to computer (PulseAudio captures it)
# 2. GQRX reads audio from PulseAudio, displays waterfall/spectrum
# 3. FlRig talks to G90 via USB serial (CAT control)
# 4. frequency_sync.py reads frequency from FlRig (XML-RPC port 12345)
# 5. frequency_sync.py sends frequency to GQRX (TCP port 7356)
# 6. Result: GQRX waterfall follows G90 frequency changes!
#
# CONFIGURATION FILE (gqrx_config.conf):
#
# Key settings:
# - device="audio_source=pulse" (use PulseAudio, not hardware SDR)
# - sample_rate=48000 (48 kHz audio from G90)
# - mode="USB" (Upper Sideband, for SSB reception)
# - enabled=true (remote control on port 7356)
# - port=7356 (frequency_sync.py connects here)
#
# WHY REMOTE CONTROL IS CRITICAL:
# Without remote control enabled, frequency_sync.py cannot talk to GQRX!
# The Python script needs TCP port 7356 to send frequency updates.
#
# ENVIRONMENT VARIABLE PRIORITY (same as install.bash and start-flrig.bash):
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

# Function to find G90-SDR installation
find_installation() {
    # Priority 1: G90_SDR_DIR (canonical production)
    if [ -n "$G90_SDR_DIR" ] && [ -d "$G90_SDR_DIR" ] && [ -f "$G90_SDR_DIR/config/gqrx_config.conf" ]; then
        echo "$G90_SDR_DIR"
        return 0
    fi

    # Priority 2: L_SDR_DIR (active/testing)
    if [ -n "$L_SDR_DIR" ] && [ -d "$L_SDR_DIR" ] && [ -f "$L_SDR_DIR/config/gqrx_config.conf" ]; then
        echo "$L_SDR_DIR"
        return 0
    fi

    # Priority 3: Current directory if running from G90-SDR directory
    if [ -f "config/gqrx_config.conf" ]; then
        pwd
        return 0
    fi

    # Priority 4: Common locations
    local LOCATIONS=(
        "$HOME/Virtual/G90-SDR"
        "$HOME/G90-SDR"
        "$HOME/Documents/G90-SDR"
        "/opt/G90-SDR"
    )

    for location in "${LOCATIONS[@]}"; do
        if [ -d "$location" ] && [ -f "$location/config/gqrx_config.conf" ]; then
            echo "$location"
            return 0
        fi
    done

    return 1
}

# Main
main() {
    echo "████████████████████████████████████████████████████████████████████████"
    echo "  GQRX Startup Script for Xiegu G90 SDR"
    echo "████████████████████████████████████████████████████████████████████████"
    echo ""

    # Check if GQRX is installed
    if ! command -v gqrx &> /dev/null; then
        print_error "GQRX is not installed!"
        echo ""
        echo "Install GQRX using one of these methods:"
        echo "  1. From package manager: sudo apt install gqrx-sdr"
        echo "  2. Build from source: bash utils/rebuild_all.bash"
        echo ""
        exit 1
    fi

    GQRX_VERSION=$(gqrx --version 2>&1 | head -1)
    print_success "GQRX found: $GQRX_VERSION"

    # Find G90-SDR installation
    print_info "Searching for G90 configuration..."
    SDR_DIR=$(find_installation)

    if [ -z "$SDR_DIR" ]; then
        print_warning "G90-SDR config not found, launching GQRX with default settings"
        echo ""
        print_info "Starting GQRX..."
        exec gqrx "$@"
    fi

    print_success "Found G90-SDR installation: $SDR_DIR"

    # Setup GQRX config directory
    GQRX_DIR="$HOME/.config/gqrx"
    CONFIG_FILE="$SDR_DIR/config/gqrx_config.conf"

    if [ ! -d "$GQRX_DIR" ]; then
        print_info "Creating GQRX config directory: $GQRX_DIR"
        mkdir -p "$GQRX_DIR"
    fi

    # Copy G90 config to GQRX directory
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Copying G90 configuration to $GQRX_DIR"
        cp "$CONFIG_FILE" "$GQRX_DIR/default.conf"
        print_success "Configuration copied"
    else
        print_warning "G90 config not found at $CONFIG_FILE"
    fi

    echo ""
    print_info "Starting GQRX with G90 configuration..."
    print_info "Remote control enabled on port 7356"
    echo ""

    # Launch GQRX - it will use config from ~/.config/gqrx
    exec gqrx "$@"
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "GQRX Startup Script for Xiegu G90 SDR"
        echo ""
        echo "Usage: bash utils/start-gqrx.bash [GQRX_OPTIONS]"
        echo ""
        echo "This script will:"
        echo "  • Check if GQRX is installed"
        echo "  • Find the G90-SDR configuration"
        echo "  • Launch GQRX with G90 settings and remote control enabled"
        echo ""
        echo "GQRX will be configured with:"
        echo "  • Audio source: PulseAudio"
        echo "  • Sample rate: 48 kHz"
        echo "  • Mode: USB"
        echo "  • Remote control: Enabled on port 7356"
        echo ""
        echo "After starting GQRX, you can run the frequency sync script:"
        echo "  python3 scripts/frequency_sync.py"
        echo ""
        echo "Any additional options are passed to GQRX"
        echo ""
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
