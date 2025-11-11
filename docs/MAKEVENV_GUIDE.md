# makevenv.bash - Python Virtual Environment Creator

Robust script for creating Python virtual environments with version checking and validation.

## Features

- ✅ **Version Validation**: Enforces Python 3.13+ minimum requirement
- ✅ **Flexible Usage**: Specify version and directory or use defaults
- ✅ **Error Checking**: Comprehensive validation and helpful error messages
- ✅ **Safe Overwrite**: Prompts before overwriting existing venvs
- ✅ **Colored Output**: Clear, color-coded messages
- ✅ **Installation Help**: Provides instructions for installing missing Python versions

## Usage

### Basic Usage (Defaults)

```bash
# Creates venv in current directory with Python 3.13
./makevenv.bash
```

### Specify Directory Only

```bash
# Creates venv in G90-SDR directory with Python 3.13 (default)
./makevenv.bash G90-SDR
```

### Specify Version and Directory

```bash
# Creates venv in G90-SDR with Python 3.14
./makevenv.bash 3.14 G90-SDR

# Creates venv in current directory with Python 3.13
./makevenv.bash 3.13 .
```

### Arguments

```
makevenv.bash [python_version] [venv_directory]

Arguments:
  python_version    Python version to use (default: 3.13)
                    Format: X.Y (e.g., 3.13, 3.14)
  venv_directory    Directory for venv (default: .)
                    Use "." for current directory
```

## Examples

### Example 1: Create G90-SDR venv with Python 3.13

```bash
cd ~
./makevenv.bash 3.13 G90-SDR
cd G90-SDR
source bin/activate
```

### Example 2: Create venv in current directory

```bash
mkdir -p my-project
cd my-project
./makevenv.bash
source bin/activate
```

### Example 3: Use Python 3.14 (if installed)

```bash
./makevenv.bash 3.14 test-env
cd test-env
source bin/activate
```

### Example 4: Quick directory name only

```bash
# Assumes Python 3.13 (default)
./makevenv.bash my-venv
```

## Version Requirements

**Minimum Python Version**: 3.13

The script enforces this minimum and will:
1. Check if requested Python version exists
2. Verify the version meets the 3.13+ requirement
3. Provide installation instructions if version is missing or too old

## Installing Python 3.13+

### Option 1: Build from Source (Recommended)

Best for getting exact version you need:

```bash
# Download source
cd /tmp
wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tar.xz
tar -xf Python-3.13.0.tar.xz
cd Python-3.13.0

# Configure with optimizations
./configure --enable-optimizations

# Build (this takes time)
make -j$(nproc)

# Install (altinstall to avoid overwriting system python3)
sudo make altinstall

# Verify
python3.13 --version
```

### Option 2: Use deadsnakes PPA (Ubuntu/Debian)

Quick and easy for Ubuntu/Debian:

```bash
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.13 python3.13-venv python3.13-dev
```

### Option 3: Use pyenv (Any Linux)

For managing multiple Python versions:

```bash
# Install pyenv
curl https://pyenv.run | bash

# Add to shell (follow pyenv instructions)

# Install Python 3.13
pyenv install 3.13.0
pyenv global 3.13.0
```

## Integration with G90-SDR

This script is the standard way to create the G90-SDR virtual environment:

```bash
cd ~
./makevenv.bash 3.13 G90-SDR
cd G90-SDR
# Copy G90-SDR files here
source bin/activate
pip install -r requirements.txt
```

## Benefits Over Manual Creation

1. **Validation**: Ensures Python version meets requirements
2. **Safety**: Prevents accidental overwrites
3. **Consistency**: Same process across all installations
4. **Helpful**: Provides clear installation instructions
5. **User Control**: Explicit version selection

## Why Python 3.13+ Required?

G90-SDR requires Python 3.13+ to:
- Use modern typing features
- Benefit from performance improvements
- Ensure security updates
- Avoid future compatibility issues
- Access latest standard library features

---

**makevenv.bash - Robust virtual environment creation for G90-SDR**
