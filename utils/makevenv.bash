#!/bin/bash
# Filename: makevenv.bash
# Create Python virtual environment with version checking
# Usage: makevenv.bash [python_version] [venv_directory]
# Defaults: python_version=3.13, venv_directory=.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Minimum required Python version
MIN_MAJOR=3
MIN_MINOR=13

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to compare version numbers
version_compare() {
    # Returns: 0 if $1 >= $2, 1 if $1 < $2
    local ver1_major=$(echo "$1" | cut -d. -f1)
    local ver1_minor=$(echo "$1" | cut -d. -f2)
    local ver2_major=$(echo "$2" | cut -d. -f1)
    local ver2_minor=$(echo "$2" | cut -d. -f2)

    if [ "$ver1_major" -gt "$ver2_major" ]; then
        return 0
    elif [ "$ver1_major" -eq "$ver2_major" ] && [ "$ver1_minor" -ge "$ver2_minor" ]; then
        return 0
    else
        return 1
    fi
}

# Parse arguments
PYTHON_VERSION=${1:-3.13}
VENV_DIR=${2:-.}

print_info "Creating Python virtual environment"
print_info "Python version: $PYTHON_VERSION"
print_info "Directory: $VENV_DIR"

# Check if only directory was provided (single argument that's not a version number)
if [ $# -eq 1 ] && [[ ! "$1" =~ ^[0-9]+\.[0-9]+$ ]] && [[ ! "$1" =~ ^[0-9]+$ ]]; then
    # Single argument that doesn't look like a version number - treat as directory
    VENV_DIR="$1"
    PYTHON_VERSION="3.13"
    print_warning "Single argument interpreted as directory name"
    print_info "Using default Python version: $PYTHON_VERSION"
fi

# Build the python command
PYTHON_CMD="python${PYTHON_VERSION}"

# Check if the specified Python version exists
if ! command -v "$PYTHON_CMD" &> /dev/null; then
    print_error "Python $PYTHON_VERSION not found"
    print_info "Command tried: $PYTHON_CMD"
    print_info ""
    print_info "Available Python versions:"
    compgen -c python | grep -E '^python[0-9]' | sort -V || echo "  None found"
    print_info ""
    print_error "Python $PYTHON_VERSION is required but not installed"
    print_info ""
    print_info "To install Python $PYTHON_VERSION, you have these options:"
    print_info ""
    print_info "Option 1: Build from source (recommended for specific versions)"
    print_info "  1. Visit: https://www.python.org/downloads/"
    print_info "  2. Download Python $PYTHON_VERSION source"
    print_info "  3. Build and install:"
    print_info "     ./configure --enable-optimizations"
    print_info "     make -j\$(nproc)"
    print_info "     sudo make altinstall"
    print_info ""
    print_info "Option 2: Use deadsnakes PPA (Ubuntu/Debian)"
    print_info "  sudo apt install software-properties-common"
    print_info "  sudo add-apt-repository ppa:deadsnakes/ppa"
    print_info "  sudo apt update"
    print_info "  sudo apt install python${PYTHON_VERSION} python${PYTHON_VERSION}-venv"
    print_info ""
    exit 1
fi

# Get the actual version of the Python command
ACTUAL_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
print_info "Found: Python $ACTUAL_VERSION"

# Extract major and minor version numbers
ACTUAL_MAJOR=$(echo "$ACTUAL_VERSION" | cut -d. -f1)
ACTUAL_MINOR=$(echo "$ACTUAL_VERSION" | cut -d. -f2)

# Check if version meets minimum requirement
if ! version_compare "$ACTUAL_MAJOR.$ACTUAL_MINOR" "$MIN_MAJOR.$MIN_MINOR"; then
    print_error "Python version $ACTUAL_VERSION does not meet minimum requirement"
    print_error "Required: Python $MIN_MAJOR.$MIN_MINOR or higher"
    print_error "Found: Python $ACTUAL_VERSION"
    print_info ""
    print_info "G90-SDR requires Python $MIN_MAJOR.$MIN_MINOR+ for:"
    print_info "  - Modern typing features"
    print_info "  - Performance improvements"
    print_info "  - Security updates"
    print_info "  - Future feature compatibility"
    print_info ""
    print_info "Please install Python $MIN_MAJOR.$MIN_MINOR or higher and try again"
    exit 1
fi

print_success "Python version check passed: $ACTUAL_VERSION >= $MIN_MAJOR.$MIN_MINOR"

# Check if venv module is available
if ! $PYTHON_CMD -m venv --help &> /dev/null; then
    print_error "Python venv module not available"
    print_info "Install with: sudo apt install python${PYTHON_VERSION}-venv"
    exit 1
fi

# Check if directory will be overwritten
if [ "$VENV_DIR" = "." ]; then
    # Creating venv in current directory
    if [ -f "pyvenv.cfg" ] || [ -d "bin" ]; then
        print_warning "Current directory appears to already contain a virtual environment"
        read -p "Recreate virtual environment? This will remove existing venv files. (y/n) " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
        print_info "Removing existing virtual environment files..."
        rm -rf bin lib lib64 include pyvenv.cfg
    fi
else
    # Creating venv in specified directory
    if [ -d "$VENV_DIR" ]; then
        if [ -f "$VENV_DIR/pyvenv.cfg" ]; then
            print_warning "Directory '$VENV_DIR' already contains a virtual environment"
            read -p "Recreate virtual environment? (y/n) " -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Cancelled"
                exit 0
            fi
            print_info "Removing existing virtual environment..."
            rm -rf "$VENV_DIR"
        else
            print_warning "Directory '$VENV_DIR' exists but doesn't appear to be a venv"
            read -p "Use this directory anyway? (y/n) " -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Cancelled"
                exit 0
            fi
        fi
    fi
fi

# Create the virtual environment
print_info "Creating virtual environment with Python $ACTUAL_VERSION..."
if $PYTHON_CMD -m venv "$VENV_DIR"; then
    print_success "Virtual environment created successfully"
else
    print_error "Failed to create virtual environment"
    exit 1
fi

# Provide activation instructions
print_info ""
print_success "Virtual environment ready!"
print_info ""
print_info "To activate the virtual environment:"
if [ "$VENV_DIR" = "." ]; then
    print_info "  source bin/activate"
else
    print_info "  cd $VENV_DIR"
    print_info "  source bin/activate"
fi
print_info ""
print_info "To deactivate:"
print_info "  deactivate"
print_info ""
print_info "To verify Python version:"
print_info "  python --version"
print_info ""
