# G90-SDR Installation Guide

Complete step-by-step installation instructions for Ubuntu 24.04 on a Raspberry Pi 5.

## Installation Methods

You have two options for installing G90-SDR:

### Option 1: Automated Installation (Recommended)

The automated `install.bash` script handles everything for you:

```bash
cd /path/to/xiegu-g90-sdr
bash install.bash
```

**What install.bash does:**
- Updates system packages
- Installs all dependencies (system, audio, build tools)
- Builds FlRig from source (latest version from SourceForge)
- Builds GQRX from source (latest stable from GitHub)
- Creates Python 3.13 virtual environment
- Installs Python packages from requirements.txt
- Configures permissions (dialout, audio groups)
- Creates configuration files
- Verifies installation

**Time required:** 20-30 minutes (most time spent building FlRig and GQRX)

**Note:** install.bash uses `utils/rebuild_all.bash` to build both FlRig and GQRX from source, ensuring you always get the latest stable versions.

### Option 2: Manual Installation

Follow the detailed steps below if you prefer manual control or need to troubleshoot specific components.

---

## Prerequisites

### Hardware Setup

1. **Raspberry Pi 5 Preparation**
   - Install Ubuntu 24.04 LTS (64-bit) on microSD card or NVMe
   - Recommended: 8GB RAM model for best performance
   - Ensure adequate cooling (heatsinks or active cooling)
   - Connect to network (Ethernet or WiFi)
   - Connect monitor, keyboard, and mouse

2. **Xiegu G90 Setup**
   - Power off the G90
   - Connect antenna
   - Ensure radio is in good working condition

3. **DE-19 Connection**
   - Connect DE-19 to G90's data port (6-pin connector on rear)
   - Connect USB cable from DE-19 to Raspberry Pi USB 3.0 port
   - Verify DE-19 power LED is lit when G90 is on

### Software Prerequisites

1. **Update System**
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

2. **Install Build Tools**
```bash
sudo apt install -y \
    build-essential \
    git \
    cmake \
    pkg-config \
    libusb-1.0-0-dev \
    libasound2-dev \
    portaudio19-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv
```

## Step 1: System Configuration

### 1.1 Configure Serial Port Access

```bash
# Add current user to dialout group for serial port access
sudo usermod -a -G dialout $USER

# Add user to audio group
sudo usermod -a -G audio $USER

# Logout and login for changes to take effect
# No reboot required - just logout/login
```

### 1.2 Disable Serial Console (if needed)

Ubuntu 24.04 may use the serial port for console. Disable it:

```bash
sudo systemctl stop serial-getty@ttyUSB0.service
sudo systemctl disable serial-getty@ttyUSB0.service
```

### 1.3 Configure USB Permissions

Create udev rule for DE-19:

```bash
sudo nano /etc/udev/rules.d/99-xiegu.rules
```

Add the following line:
```
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"
```

Reload udev rules:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Step 2: Install FlRig

### 2.1 Download and Install FlRig

```bash
# Install dependencies
sudo apt install -y \
    libfltk1.3-dev \
    libfltk-images1.3 \
    libx11-dev \
    libxext-dev \
    libxft-dev \
    libxinerama-dev \
    portaudio19-dev

# Download FlRig (automatically gets latest version)
cd /tmp

# Get latest FlRig version from SourceForge
FLRIG_LATEST=$(curl -s https://sourceforge.net/projects/fldigi/files/flrig/ | \
    grep -oP 'flrig-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
    sort -V | tail -1)

if [ -z "$FLRIG_LATEST" ]; then
    # Fallback to known good version if detection fails
    FLRIG_LATEST="flrig-2.0.03.tar.gz"
    echo "Could not detect latest version, using fallback: $FLRIG_LATEST"
fi

FLRIG_VERSION=${FLRIG_LATEST%.tar.gz}
echo "Downloading FlRig: $FLRIG_VERSION"

wget "https://sourceforge.net/projects/fldigi/files/flrig/$FLRIG_LATEST"
tar xzf "$FLRIG_LATEST"
cd "$FLRIG_VERSION"

# Build and install
./configure
make
sudo make install
sudo ldconfig

# Verify installation
flrig --version

# Clean up
cd /tmp
rm -rf "$FLRIG_VERSION" "$FLRIG_LATEST"
```

## Step 3: Install SDR++ Software

### 3.1 Build SDR++ from Source

```bash
# Install dependencies
sudo apt install -y \
    git \
    build-essential \
    cmake \
    libfftw3-dev \
    libglfw3-dev \
    libglew-dev \
    libvolk2-dev \
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

# Clone and build SDR++
cd /tmp
git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
cd SDRPlusPlus

# Get latest stable tag
git fetch --tags
LATEST_TAG=$(git tag --sort=-v:refname | grep -v -E 'nightly|beta|rc|alpha' | head -1)

if [ -z "$LATEST_TAG" ]; then
    echo "Could not determine latest stable release, using fallback: 1.2.0"
    LATEST_TAG="1.2.0"
fi

echo "Building SDR++ version: $LATEST_TAG"
git checkout $LATEST_TAG

# Build
mkdir build
cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify installation
which sdrpp

# Clean up
cd /tmp
rm -rf SDRPlusPlus
```

## Step 4: Set Up Python Environment

### 4.1 Create Virtual Environment

**Recommended Method (with version checking):**

```bash
cd ~

# Copy G90-SDR files including makevenv.bash to a directory
# Then use makevenv.bash to create venv with version checking

cd G90-SDR
./makevenv.bash

# This creates the venv in the current directory (G90-SDR becomes the venv)
# and verifies Python 3.13+ requirement is met

# Activate virtual environment
source bin/activate
```

**Alternative Method (manual):**

```bash
cd ~

# Create virtual environment (G90-SDR directory will be the venv itself)
python3 -m venv G90-SDR

# Enter the virtual environment directory
cd G90-SDR

# Activate virtual environment
source bin/activate
```

**Note:** Using `makevenv.bash` is recommended as it verifies Python 3.13+ requirement and provides helpful error messages if the version is not available.

### 4.2 Install Python Packages

Create `requirements.txt`:

```bash
cat > requirements.txt << 'EOF'
# Filename: requirements.txt
# G90-SDR Python Dependencies

# Serial communication
pyserial>=3.5

# XML-RPC for FlRig control
xmlrpc>=1.0.1

# Network communication
requests>=2.31.0

# Configuration file handling
pyyaml>=6.0.1
configparser>=6.0.0

# Audio processing
pyaudio>=0.2.14
sounddevice>=0.4.6

# System monitoring
psutil>=5.9.8

# Logging enhancements
colorlog>=6.8.2

# Date/time utilities
python-dateutil>=2.9.0

# Type checking
typing-extensions>=4.9.0
EOF
```

Install dependencies:

```bash
# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install requirements
pip install -r requirements.txt
```

## Step 5: Install G90-SDR Software

### 5.1 Create Directory Structure

```bash
mkdir -p config scripts tests docs logs
```

### 5.2 Copy Configuration Files

Create FlRig configuration:

```bash
cat > config/flrig_g90.xml << 'EOF'
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
```

SDR++ configuration will be created automatically on first run. The config file is stored at `~/.config/sdrpp/config.json`.

**Important:** After first launch, enable the rigctl server:
1. Click the hamburger menu (≡)
2. Go to "Module Manager"
3. Enable "rigctl_server"
4. Set port to 4532
5. Restart SDR++

### 5.3 Copy Python Scripts

Copy all scripts from the repository to your G90-SDR directory:

```bash
# Copy main scripts
cp /path/to/repo/*.py .
cp /path/to/repo/scripts/*.py scripts/
cp /path/to/repo/tests/*.py tests/

# Make scripts executable
chmod +x *.py scripts/*.py tests/*.py
```

## Step 6: Verify Installation

### 6.1 Check Serial Connection

```bash
# Activate virtual environment (from within G90-SDR directory)
source bin/activate

# Test connection
python3 tests/TestConnection.py
```

Expected output:
```
Testing G90 connection via DE-19...
✓ USB device found
✓ Serial port accessible
✓ CAT communication working
```

### 6.2 Test FlRig Connection

```bash
# Start FlRig in another terminal
flrig --config-dir ~/.flrig

# In your main terminal, test XML-RPC
python3 tests/TestCatControl.py
```

### 6.3 Test Audio Setup

```bash
python3 tests/TestAudio.py
```

## Step 7: Create Startup Scripts

### 7.1 Create Launcher Script

```bash
cat > ~/Desktop/G90-SDR.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=G90-SDR
Comment=Xiegu G90 SDR Interface
Exec=/home/$USER/G90-SDR/scripts/start_sdr.py
Icon=radio
Terminal=true
Categories=HamRadio;
EOF

chmod +x ~/Desktop/G90-SDR.desktop
```

### 7.2 Create System Service (Optional)

```bash
sudo nano /etc/systemd/system/g90-sdr.service
```

Add:
```ini
[Unit]
Description=G90-SDR Service
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/home/your_username/G90-SDR
ExecStart=/home/your_username/G90-SDR/venv/bin/python /home/your_username/G90-SDR/scripts/start_sdr.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable g90-sdr.service
sudo systemctl start g90-sdr.service
```

## Maintenance and Updates

### Rebuilding FlRig and GQRX

To update FlRig and GQRX to the latest versions:

```bash
cd /path/to/xiegu-g90-sdr
bash utils/rebuild_all.bash
```

**What rebuild_all.bash does:**
- Checks for currently installed versions
- Downloads latest FlRig source from SourceForge
- Downloads latest stable GQRX from GitHub
- Builds and installs both to `/usr/local/bin/`
- Verifies installations

**When to rebuild:**
- To get latest features and bug fixes
- After system upgrades
- If FlRig or GQRX crashes or misbehaves
- When new radio firmware requires updated software

**Time required:** 15-25 minutes

### Updating Python Dependencies

```bash
cd /path/to/xiegu-g90-sdr
source bin/activate
pip install --upgrade -r requirements.txt
```

### System Updates

```bash
bash update.bash
```

This updates system packages while preserving your G90-SDR installation.

---

## Troubleshooting

### No USB Device Found

1. Check physical connections
2. Verify DE-19 power LED is on
3. List USB devices: `lsusb`
4. Check for CH340 driver: `dmesg | grep ch341`

### Serial Port Permission Denied

```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Logout and login, or reboot
```

### FlRig Won't Start

1. Check if process is already running: `ps aux | grep flrig`
2. Kill existing process: `killall flrig`
3. Check config directory: `ls -la ~/.flrig`

### SDR++ Audio Issues

1. Check PulseAudio: `pulseaudio --check`
2. Start PulseAudio: `pulseaudio --start`
3. List audio devices: `pactl list sinks`

### Python Import Errors

```bash
# Activate virtual environment (from within G90-SDR directory)
source bin/activate

# Reinstall requirements
pip install --upgrade -r requirements.txt
```

## Next Steps

1. **Configure FlRig**: Adjust settings for your G90
2. **Test SDR Reception**: Tune to a known signal
3. **Calibrate Audio**: Run audio calibration script
4. **Create Frequency Presets**: Save favorite frequencies
5. **Join Ham Radio Community**: Share your experience!

## Additional Resources

- FlRig Documentation: https://sourceforge.net/projects/fldigi/
- SDR++ Documentation: https://github.com/AlexandreRouma/SDRPlusPlus
- Xiegu G90 Manual: Check manufacturer website
- Ubuntu HAM Radio: https://wiki.ubuntu.com/AmateurRadio

---

**Installation complete! Enjoy your G90-SDR setup!**
