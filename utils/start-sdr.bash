#!/bin/bash
# Filename: utils/start-sdr.bash
# Master startup script for G90 SDR system
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details
#
#═══════════════════════════════════════════════════════════════════════════════
# PURPOSE: Start complete G90 SDR system with one command
#═══════════════════════════════════════════════════════════════════════════════
#
# WHAT THIS SCRIPT DOES:
# 1. Starts FlRig (CAT control for G90 radio)
# 2. Starts GQRX (SDR waterfall display)
# 3. Starts frequency_sync.py (bidirectional frequency sync)
# 4. Monitors all three processes
# 5. Automatically stops everything when you press Ctrl+C
#
# SYSTEM ARCHITECTURE:
#
# ┌──────────┐  USB Serial   ┌───────────┐  XML-RPC      ┌────────────────┐
# │ Xiegu G90│◄────CAT──────►│   FlRig   │◄─port 12345──►│ frequency_sync │
# │   Radio  │               │ (Control) │               │   (Python)     │
# └──────────┘               └───────────┘               └────────────────┘
#      │                                                          │
#      │ Audio (I/Q)                                       TCP port 7356
#      ↓                                                          ↓
# ┌──────────┐            ┌────────────┐               ┌─────────────────┐
# │PulseAudio│───────────►│   GQRX    │◄──frequency───►│  GQRX Remote   │
# │ (48kHz)  │            │ (Display) │               │    Control      │
# └──────────┘            └───────────┘               └─────────────────┘
#
# STARTUP SEQUENCE:
# 1. Start FlRig → wait for XML-RPC server (port 12345)
# 2. Start GQRX → wait for remote control (port 7356)
# 3. Start frequency_sync.py → connects to both
# 4. Display status and sync messages
#
# SHUTDOWN SEQUENCE (Ctrl+C):
# 1. Stop frequency_sync.py (graceful disconnect)
# 2. Stop GQRX (closes waterfall display)
# 3. Stop FlRig (disconnects from G90)
# 4. All processes terminated cleanly
#
# USAGE:
#   bash utils/start-sdr.bash
#   Press Ctrl+C to stop everything
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_status() {
    echo -e "${CYAN}[STATUS]${NC} $1"
}

# Track PIDs of background processes
FLRIG_PID=""
GQRX_PID=""
SYNC_PID=""

# Cleanup function - stops all processes
cleanup() {
    echo ""
    print_info "Stopping G90 SDR system..."

    # Stop frequency sync first (graceful disconnect)
    if [ -n "$SYNC_PID" ]; then
        print_info "Stopping frequency sync..."
        kill $SYNC_PID 2>/dev/null || true
        wait $SYNC_PID 2>/dev/null || true
        SYNC_PID=""
    fi

    # Stop GQRX
    if [ -n "$GQRX_PID" ]; then
        print_info "Stopping GQRX..."
        kill $GQRX_PID 2>/dev/null || true
        wait $GQRX_PID 2>/dev/null || true
        GQRX_PID=""
    fi

    # Stop FlRig
    if [ -n "$FLRIG_PID" ]; then
        print_info "Stopping FlRig..."
        kill $FLRIG_PID 2>/dev/null || true
        wait $FLRIG_PID 2>/dev/null || true
        FLRIG_PID=""
    fi

    print_success "G90 SDR system stopped"
    exit 0
}

# Trap Ctrl+C and termination signals
trap cleanup SIGINT SIGTERM

#──────────────────────────────────────────────────────────────────────────────
# Function: find_installation
#──────────────────────────────────────────────────────────────────────────────
# Same priority system as start-flrig.bash and start-gqrx.bash
find_installation() {
    # Priority 1: G90_SDR_DIR (canonical production)
    if [ -n "$G90_SDR_DIR" ] && [ -d "$G90_SDR_DIR" ]; then
        echo "$G90_SDR_DIR"
        return 0
    fi

    # Priority 2: L_SDR_DIR (active/testing)
    if [ -n "$L_SDR_DIR" ] && [ -d "$L_SDR_DIR" ]; then
        echo "$L_SDR_DIR"
        return 0
    fi

    # Priority 3: Current directory
    if [ -f "scripts/frequency_sync.py" ]; then
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
        if [ -d "$location" ] && [ -f "$location/scripts/frequency_sync.py" ]; then
            echo "$location"
            return 0
        fi
    done

    return 1
}

#──────────────────────────────────────────────────────────────────────────────
# Function: wait_for_port
#──────────────────────────────────────────────────────────────────────────────
# Wait for a TCP port to become available (indicates service is ready)
wait_for_port() {
    local port=$1
    local service=$2
    local timeout=10
    local elapsed=0

    print_info "Waiting for $service (port $port)..."

    while [ $elapsed -lt $timeout ]; do
        if nc -z 127.0.0.1 $port 2>/dev/null; then
            print_success "$service is ready"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    print_warning "$service did not start within ${timeout}s"
    return 1
}

#──────────────────────────────────────────────────────────────────────────────
# Main
#──────────────────────────────────────────────────────────────────────────────
main() {
    echo "════════════════════════════════════════════════════════════════════"
    echo "  G90 SDR System Startup"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""

    # Find installation directory
    print_info "Locating G90-SDR installation..."
    SDR_DIR=$(find_installation)

    if [ -z "$SDR_DIR" ]; then
        print_error "G90-SDR installation not found"
        echo ""
        echo "Set G90_SDR_DIR environment variable or run from installation directory"
        exit 1
    fi

    print_success "Found installation: $SDR_DIR"

    # Check if required scripts exist
    if [ ! -f "$SDR_DIR/utils/start-flrig.bash" ]; then
        print_error "start-flrig.bash not found"
        exit 1
    fi

    if [ ! -f "$SDR_DIR/utils/start-gqrx.bash" ]; then
        print_error "start-gqrx.bash not found"
        exit 1
    fi

    if [ ! -f "$SDR_DIR/scripts/frequency_sync.py" ]; then
        print_error "frequency_sync.py not found"
        exit 1
    fi

    # Check if netcat is available (for port checking)
    if ! command -v nc &> /dev/null; then
        print_warning "netcat (nc) not installed - skipping port checks"
        print_info "Install with: sudo apt install netcat"
    fi

    echo ""
    print_status "Starting G90 SDR components..."
    echo ""

    #──────────────────────────────────────────────────────────────────────────
    # Step 1: Start FlRig
    #──────────────────────────────────────────────────────────────────────────
    print_info "Starting FlRig..."
    bash "$SDR_DIR/utils/start-flrig.bash" &>/dev/null &
    FLRIG_PID=$!

    # Wait for FlRig XML-RPC server (port 12345)
    if command -v nc &> /dev/null; then
        wait_for_port 12345 "FlRig XML-RPC server"
    else
        sleep 3  # Fallback: just wait 3 seconds
        print_info "FlRig started (PID: $FLRIG_PID)"
    fi

    #──────────────────────────────────────────────────────────────────────────
    # Step 2: Start GQRX
    #──────────────────────────────────────────────────────────────────────────
    print_info "Starting GQRX..."
    bash "$SDR_DIR/utils/start-gqrx.bash" &>/dev/null &
    GQRX_PID=$!

    # Wait for GQRX remote control (port 7356)
    if command -v nc &> /dev/null; then
        wait_for_port 7356 "GQRX remote control"
    else
        sleep 3  # Fallback: just wait 3 seconds
        print_info "GQRX started (PID: $GQRX_PID)"
    fi

    #──────────────────────────────────────────────────────────────────────────
    # Step 3: Start frequency sync
    #──────────────────────────────────────────────────────────────────────────
    print_info "Starting bidirectional frequency sync..."

    # Use the venv Python if available
    if [ -f "$SDR_DIR/bin/python" ]; then
        PYTHON="$SDR_DIR/bin/python"
    else
        PYTHON="python3"
    fi

    # Start frequency_sync.py in background, but show its output
    cd "$SDR_DIR"
    $PYTHON scripts/frequency_sync.py &
    SYNC_PID=$!

    # Give it a moment to connect
    sleep 2

    echo ""
    print_success "G90 SDR system is running!"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "  Active Components:"
    echo "════════════════════════════════════════════════════════════════════"
    echo "  • FlRig         (PID: $FLRIG_PID) - CAT control on port 12345"
    echo "  • GQRX          (PID: $GQRX_PID) - SDR display on port 7356"
    echo "  • frequency_sync (PID: $SYNC_PID) - Bidirectional sync"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "  Features:"
    echo "════════════════════════════════════════════════════════════════════"
    echo "  • Turn VFO knob on G90 → GQRX waterfall follows"
    echo "  • Click GQRX waterfall → G90 radio QSYs (changes frequency)"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    print_info "Press Ctrl+C to stop all components"
    echo ""

    # Wait for user to press Ctrl+C
    # The trap will handle cleanup
    wait $SYNC_PID
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "G90 SDR System Startup Script"
        echo ""
        echo "Usage: bash utils/start-sdr.bash"
        echo ""
        echo "This script starts the complete G90 SDR system:"
        echo "  1. FlRig (CAT control for G90)"
        echo "  2. GQRX (SDR waterfall display)"
        echo "  3. frequency_sync.py (bidirectional frequency control)"
        echo ""
        echo "All components start automatically and stop when you press Ctrl+C"
        echo ""
        echo "Bidirectional frequency control:"
        echo "  • Turn knob on G90 → GQRX follows"
        echo "  • Click GQRX waterfall → G90 QSYs"
        echo ""
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
