#!/bin/bash
# Filename: utils/build_sdrpp.bash
# Build SDR++ from source - always pulls latest stable release

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

# Welcome
clear
echo "████████████████████████████████████████████████████████████████████████"
echo "  SDR++ Source Build Script"
echo "  Builds latest stable SDR++ from source"
echo "████████████████████████████████████████████████████████████████████████"
echo ""

# Check if already installed
if command -v sdrpp &> /dev/null; then
    print_info "SDR++ is currently installed"
    echo ""
    read -p "Rebuild SDR++ from latest source? (y/n) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Build cancelled"
        exit 0
    fi
else
    print_info "SDR++ not currently installed"
fi

# Check for existing build
print_header "Checking for Previous Builds"

if [ -d "/tmp/SDRPlusPlus" ]; then
    print_warning "Found existing SDR++ source in /tmp/SDRPlusPlus"
    read -p "Remove and start fresh? (y/n) " -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf /tmp/SDRPlusPlus
        print_success "Cleaned up old source"
    fi
fi

# Install dependencies
print_header "Installing Build Dependencies"

print_info "This will install required development packages..."
sudo apt update

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

print_success "Dependencies installed"

# Clone repository
print_header "Downloading SDR++ Source"

cd /tmp

print_info "Cloning SDR++ repository from GitHub..."
if [ -d "SDRPlusPlus" ]; then
    print_info "Removing old source directory..."
    rm -rf SDRPlusPlus
fi

git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
cd SDRPlusPlus

# Build from master branch (development version)
print_info "Using SDR++ master branch (development version)..."
print_info "This includes all latest bug fixes for Ubuntu 24.04"
git checkout master

# Get current commit hash for version tracking
BUILD_VERSION=$(git rev-parse --short HEAD)
print_success "Building from commit: $BUILD_VERSION"

# Configure build
print_header "Configuring Build"

if [ -d "build" ]; then
    print_info "Cleaning previous build directory..."
    rm -rf build
fi

mkdir build
cd build

print_info "Running cmake..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

print_success "Build configured"

# Build
print_header "Compiling SDR++"

print_info "This will take 5-10 minutes on Raspberry Pi 5..."
print_info "Using $(nproc) CPU cores for compilation"
echo ""

# Show compilation progress
make -j$(nproc)

print_success "Compilation complete"

# Install
print_header "Installing SDR++"

print_info "Installing to /usr/local/bin/..."
sudo make install

print_info "Updating library cache..."
sudo ldconfig

# Create desktop entry if it doesn't exist
if [ ! -f "/usr/local/share/applications/sdrpp.desktop" ]; then
    print_info "Creating desktop entry..."
    sudo mkdir -p /usr/local/share/applications

    sudo tee /usr/local/share/applications/sdrpp.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=SDR++
GenericName=Software Defined Radio
Comment=Cross-platform SDR receiver
Icon=sdrpp
Exec=sdrpp
Terminal=false
Categories=HamRadio;Network;
Keywords=sdr;radio;receiver;
EOF

    print_success "Desktop entry created"
fi

print_success "SDR++ installed"

# Verify installation
print_header "Verifying Installation"

if command -v sdrpp &> /dev/null; then
    print_success "SDR++ is installed and available"
    print_info "Location: $(which sdrpp)"
else
    print_error "SDR++ command not found after installation"
    print_warning "You may need to log out and back in, or reboot"
fi

# Cleanup (silent - users don't need to know)
cd /tmp
rm -rf SDRPlusPlus 2>/dev/null || true

# Summary
print_header "Build Complete!"

echo ""
echo "SDR++ has been built and installed from source"
echo ""
echo "Built version: $BUILD_VERSION"
echo "Installed to: /usr/local/bin/sdrpp"
echo ""
echo "To run SDR++:"
echo "  • From terminal: sdrpp"
echo "  • From applications menu: Look for 'SDR++'"
echo "  • Use G90-SDR launcher: g90-sdr"
echo ""
echo "IMPORTANT: Enable rigctl server in SDR++"
echo "  1. Click hamburger menu (≡)"
echo "  2. Go to 'Module Manager'"
echo "  3. Enable 'rigctl_server'"
echo "  4. Set port to 4532"
echo ""
echo "Benefits of source build:"
echo "  ✓ Latest features and bug fixes"
echo "  ✓ Optimized for your system (ARM)"
echo "  ✓ Full control over version"
echo "  ✓ No package manager conflicts"
echo "  ✓ Lighter than GQRX (no GNU Radio)"
echo ""
echo "To rebuild in the future:"
echo "  bash build_sdrpp.bash"
echo ""
