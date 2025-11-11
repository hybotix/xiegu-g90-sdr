#!/bin/bash
# Filename: utils/build-flrig.bash
# Build FlRig from source - always pulls latest stable release
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details

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

print_header() {
    echo ""
    echo "========================================================================"
    echo "  $1"
    echo "========================================================================"
}

# Check log level from parent install.bash (defaults to normal if not set)
INSTALL_LOG_LEVEL="${INSTALL_LOG_LEVEL:-normal}"

# Helper function for apt-get quiet flags
get_apt_quiet_flags() {
    if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
        echo "-qq"
    else
        echo ""
    fi
}

# Welcome
clear
echo "████████████████████████████████████████████████████████████████████████"
echo "  FlRig Source Build Script"
echo "  Builds latest stable FlRig from source"
echo "████████████████████████████████████████████████████████████████████████"
echo ""

# Check current version
if command -v flrig &> /dev/null; then
    CURRENT_VERSION=$(flrig --version 2>&1 | head -1 || echo "unknown")
    print_info "Currently installed: $CURRENT_VERSION"
else
    print_info "FlRig not currently installed"
fi

# Install dependencies
print_header "Installing Build Dependencies"

print_info "Installing FlRig build dependencies..."
sudo apt-get $(get_apt_quiet_flags) update
sudo apt-get $(get_apt_quiet_flags) install -y \
    build-essential \
    libfltk1.3-dev \
    libfltk-images1.3 \
    libfltk-forms1.3 \
    libx11-dev \
    libxinerama-dev \
    libxft-dev \
    libxcursor-dev \
    wget \
    curl

print_success "Dependencies installed"

# Get latest version from SourceForge
print_header "Finding Latest FlRig Release"

print_info "Querying SourceForge for latest release..."

# Scrape SourceForge to find latest version
FLRIG_LATEST=$(curl -s https://sourceforge.net/projects/fldigi/files/flrig/ | \
    grep -oP 'flrig-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
    sort -V | tail -1)

if [ -z "$FLRIG_LATEST" ]; then
    print_error "Could not determine latest version from SourceForge"
    print_info "Defaulting to known stable version 2.0.03"
    FLRIG_LATEST="flrig-2.0.03.tar.gz"
fi

LATEST_VERSION=${FLRIG_LATEST#flrig-}
LATEST_VERSION=${LATEST_VERSION%.tar.gz}

print_success "Latest stable release: $LATEST_VERSION"

# Download source
print_header "Downloading FlRig Source"

cd /tmp

TARBALL="flrig-${LATEST_VERSION}.tar.gz"
DOWNLOAD_URL="https://sourceforge.net/projects/fldigi/files/flrig/${TARBALL}/download"

print_info "Downloading: $TARBALL"

if [ -f "$TARBALL" ]; then
    print_info "Removing old tarball..."
    rm "$TARBALL"
fi

wget -O "$TARBALL" "$DOWNLOAD_URL"

print_success "Downloaded successfully"

# Extract
print_header "Extracting Source"

EXTRACT_DIR="flrig-${LATEST_VERSION}"

if [ -d "$EXTRACT_DIR" ]; then
    print_info "Removing old source directory..."
    rm -rf "$EXTRACT_DIR"
fi

tar -xzf "$TARBALL"

if [ ! -d "$EXTRACT_DIR" ]; then
    print_error "Extraction failed or unexpected directory name"
    exit 1
fi

cd "$EXTRACT_DIR"

print_success "Source extracted"

# Configure
print_header "Configuring Build"

print_info "Running configure script..."
if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
    ./configure --prefix=/usr/local >/dev/null 2>&1
else
    ./configure --prefix=/usr/local
fi

print_success "Configuration complete"

# Build
print_header "Compiling FlRig"

print_info "Building with $(nproc) CPU cores..."
print_info "This will take ~10-15 minutes..."

if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
    echo "  → Build in progress (output suppressed for quiet mode)"
    make -j$(nproc) >/dev/null 2>&1
else
    make -j$(nproc)
fi

print_success "Compilation complete"

# Install
print_header "Installing FlRig"

print_info "Installing to /usr/local/bin/..."
if [ "$INSTALL_LOG_LEVEL" = "quiet" ]; then
    sudo make install >/dev/null 2>&1
else
    sudo make install
fi

print_success "FlRig installed"

# Verify
print_header "Verifying Installation"

if command -v flrig &> /dev/null; then
    INSTALLED_VERSION=$(flrig --version 2>&1 | head -1)
    print_success "FlRig is installed and available"
    print_info "Version: $INSTALLED_VERSION"
    print_info "Location: $(which flrig)"
else
    print_error "FlRig command not found after installation"
    print_warning "You may need to log out and back in"
fi

# Cleanup (silent - users don't need to know)
cd /tmp
rm -rf "$EXTRACT_DIR" "$TARBALL" 2>/dev/null || true

# Summary
print_header "Build Complete!"

echo ""
echo "FlRig has been built and installed from source"
echo ""
echo "Built version: $LATEST_VERSION"
echo "Installed to: /usr/local/bin/flrig"
echo ""
echo "To run FlRig:"
echo "  • From terminal: flrig"
echo "  • With G90 config: g90-flrig"
echo "  • Use G90-SDR launcher: g90-sdr"
echo ""
echo "To rebuild in the future:"
echo "  bash utils/build-flrig.bash"
echo ""
