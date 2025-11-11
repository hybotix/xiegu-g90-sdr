# G90-SDR System Architecture

**Version:** 0.2.0
**Platform:** Ubuntu 24.04 LTS on Raspberry Pi 5
**Last Updated:** 2025-11-08

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Component Deep Dive](#component-deep-dive)
4. [Configuration System](#configuration-system)
5. [Modular Build System](#modular-build-system)
6. [Environment Variable System](#environment-variable-system)
7. [Installation Philosophy](#installation-philosophy)
8. [Design Decisions and Trade-offs](#design-decisions-and-trade-offs)
9. [Extending the System](#extending-the-system)
10. [Troubleshooting Architecture](#troubleshooting-architecture)

---

## Overview

### What is G90-SDR?

G90-SDR transforms the Xiegu G90 HF transceiver into a software-defined radio (SDR) panadapter display. It provides a waterfall spectrum display synchronized with the radio's frequency, along with computer-aided transceiver (CAT) control.

### Design Goals

1. **Ease of Use** - Single installation script, automatic configuration
2. **Reliability** - Known-good configurations, modular architecture
3. **Flexibility** - Multiple installations (production + testing), environment variables
4. **Maintainability** - Single source of truth, comprehensive documentation
5. **Performance** - Real-time frequency synchronization, low latency

### Technology Stack

- **Hardware:** Xiegu G90 + DE-19 data interface (USB audio + serial)
- **OS:** Ubuntu 24.04 LTS (ARM64 for Raspberry Pi 5)
- **Languages:** Bash (installation/startup), Python 3.13 (control scripts)
- **Radio Control:** FlRig (CAT control via XML-RPC)
- **SDR Display:** GQRX (spectrum/waterfall from audio)
- **Audio:** PulseAudio (48 kHz I/Q from G90)

---

## System Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Xiegu G90 Radio                             │
│                                                                     │
│  ┌──────────────┐                           ┌──────────────┐       │
│  │   RF Front   │                           │ Audio IF Out │       │
│  │     End      │                           │  (I/Q Audio) │       │
│  └──────────────┘                           └──────────────┘       │
│         ↑                                           │               │
│         │ CAT Control                               │ Audio         │
│         │ (Serial)                                  │ (USB)         │
└─────────┼───────────────────────────────────────────┼───────────────┘
          │                                           │
          │ /dev/ttyUSB0                              │
          │ 19200 baud                                ↓
          │                                  ┌─────────────────┐
          │                                  │   PulseAudio    │
          │                                  │   (48 kHz)      │
          │                                  └─────────────────┘
          ↓                                           │
   ┌─────────────┐                                   │
   │    FlRig    │                                   │
   │ (CAT Control│                                   │
   │  & XML-RPC) │                                   │
   └─────────────┘                                   │
          ↑                                           ↓
          │ XML-RPC                          ┌─────────────────┐
          │ Port 12345                       │      GQRX       │
          │                                  │ (Panadapter/    │
   ┌──────┴────────┐                        │  Waterfall)     │
   │ frequency_sync│←──TCP Port 7356────────┤  Remote Control │
   │    (Python)   │                        └─────────────────┘
   └───────────────┘
```

### Component Responsibilities

| Component | Purpose | Interface | Port |
|-----------|---------|-----------|------|
| **G90 Radio** | HF transceiver | USB (audio + serial) | - |
| **FlRig** | CAT control, rig abstraction | XML-RPC server | 12345 |
| **GQRX** | Spectrum display, waterfall | TCP remote control | 7356 |
| **frequency_sync.py** | Sync frequency G90→GQRX | XML-RPC client + TCP client | - |
| **PulseAudio** | Audio routing | ALSA → apps | - |

---

## Component Deep Dive

### FlRig: CAT Control Layer

**Why FlRig?**

- **Rig Abstraction:** FlRig speaks native Xiegu G90 CAT protocol
- **XML-RPC API:** Python scripts can control rig without serial protocol knowledge
- **Stability:** Mature codebase (v2.0.9), active development since 2010s
- **Features:** PTT control, frequency/mode setting, meter reading

**FlRig Configuration:**

FlRig uses **FLTK (Fast Light Toolkit) preferences format**, NOT XML!

Three files required:

1. **`Xiegu-G90.prefs`** (7KB) - Main configuration
   ```
   ; FLTK preferences file format 1.0
   ; vendor: w1hkj.com
   ; application: Xiegu-G90

   [.]
   version:2.0.09
   xcvr_serial_port:/dev/ttyUSB0
   serial_baudrate:6       # Code for 19200 baud
   xmlport:12345           # XML-RPC server port
   ptt_via_cat:1           # PTT via CAT commands
   ```

2. **`flrig.prefs`** - Tells FlRig which rig
   ```
   ; FLTK preferences file format 1.0
   ; vendor: w1hkj.com
   ; application: flrig

   [.]
   xcvr_name:Xiegu-G90
   ```

3. **`default.prefs`** - UI colors and fonts

**Why SourceForge for FlRig?**

- Official release tarballs (stable versions like `flrig-2.0.09.tar.gz`)
- GitHub has development code (may be unstable between releases)
- Predictable versioning

### GQRX: SDR Display

**Why GQRX?**

- **Audio Input Support:** Can use PulseAudio as "SDR device"
- **Remote Control:** TCP interface for frequency control
- **Mature:** Based on GNU Radio, well-tested
- **Performance:** Real-time waterfall on Raspberry Pi 5

**GQRX Configuration:**

File: `~/.config/gqrx/default.conf`

```ini
[General]
configversion=2

[input]
device="audio_source=pulse"  # Use PulseAudio, not hardware SDR
sample_rate=48000             # Match G90 IF output
bandwidth=1000000

[receiver]
mode="USB"                    # Upper Sideband for SSB
sql_level=-150.0

[remote_control]
enabled=true                  # CRITICAL for frequency sync
port=7356
```

**Why GitHub for GQRX?**

- GitHub is the official repository (https://github.com/gqrx-sdr/gqrx)
- Active development, we clone latest stable tag
- CMake build system (modern, cross-platform)

### frequency_sync.py: The Bridge

**Purpose:** Keep GQRX frequency synchronized with G90

**How It Works:**

1. **Poll FlRig** via XML-RPC (port 12345):
   ```python
   frequency = rig_proxy.rig.get_vfo()  # Get current VFO frequency
   mode = rig_proxy.rig.get_mode()      # Get current mode (USB/LSB/etc.)
   ```

2. **Update GQRX** via TCP (port 7356):
   ```python
   sock.sendall(b"F 14074000\n")  # Set frequency to 14.074 MHz
   ```

3. **Repeat** every 0.5 seconds (configurable)

**Why Not Direct G90 → GQRX?**

- GQRX doesn't speak Xiegu CAT protocol
- FlRig provides stable abstraction layer
- Easier to swap radios in future (just configure FlRig)

---

## Configuration System

### Directory Structure

```
G90-SDR/
├── config/
│   ├── Xiegu-G90.prefs     # FlRig main config (FLTK format)
│   ├── flrig.prefs         # FlRig rig selection
│   ├── default.prefs       # FlRig UI settings
│   └── gqrx_config.conf    # GQRX configuration
├── scripts/
│   ├── frequency_sync.py   # Sync script
│   ├── rig_control.py      # FlRig XML-RPC wrapper
│   └── ...
├── utils/
│   ├── start-flrig.bash    # Launch FlRig with config
│   ├── start-gqrx.bash     # Launch GQRX with config
│   ├── build-flrig.bash    # Build FlRig from source
│   └── build-gqrx.bash     # Build GQRX from source
└── install.bash            # Main installer
```

### Configuration File Locations

**At Installation Time:**
- Repository config files: `<repo>/config/`

**At Runtime:**
- FlRig: `~/.flrig/` (copied from repo on each launch)
- GQRX: `~/.config/gqrx/` (copied from repo on each launch)

**Why Copy on Every Launch?**

- **Reset to Known-Good:** User might change settings during operation
- **Consistency:** Every launch starts from same state
- **Debugging:** If something breaks, next launch fixes it

---

## Modular Build System

### The Problem We Solved

**Original Bug (before modular system):**

```
install.bash:       Cloned FlRig from GitHub → v2.0.0 (OLD, BROKEN)
rebuild_all.bash:   Downloaded from SourceForge → v2.0.9 (CORRECT)
```

Users would install, get broken FlRig, then be confused when rebuild worked!

### The Solution: Single Source of Truth

```
┌─────────────────┐
│  install.bash   │───┐
└─────────────────┘   │
                      ├──→ bash utils/build-flrig.bash
┌─────────────────┐   │
│ rebuild_all.bash│───┘
└─────────────────┘
```

**Key Principle:** Build logic exists in ONE place per software

- **FlRig build:** `utils/build-flrig.bash` (downloads from SourceForge)
- **GQRX build:** `utils/build-gqrx.bash` (clones from GitHub)

Both `install.bash` and `rebuild_all.bash` **CALL** these scripts.
**Impossible** for them to build differently!

### Build Script Architecture

**`utils/build-flrig.bash`:**

```bash
# 1. Detect latest version from SourceForge
LATEST=$(curl -s https://sourceforge.net/... | parse version)

# 2. Download tarball
wget https://sourceforge.net/projects/fldigi/files/flrig/${LATEST}.tar.gz

# 3. Extract and build
tar xzf flrig-${LATEST}.tar.gz
cd flrig-${LATEST}
./configure && make -j$(nproc) && sudo make install
```

**`utils/build-gqrx.bash`:**

```bash
# 1. Install dependencies (Qt5, GNU Radio, etc.)
sudo apt install -y libqt5-dev gnuradio-dev ...

# 2. Clone from GitHub
git clone https://github.com/gqrx-sdr/gqrx.git
cd gqrx
git checkout $(git tag -l "v*" | sort -V | tail -1)  # Latest stable tag

# 3. Build with CMake
mkdir build && cd build
cmake .. && make -j$(nproc) && sudo make install
```

---

## Environment Variable System

### Purpose

Support **multiple installations** on the same system:

- **Production:** Stable installation for daily operation
- **Development:** Testing new configs without breaking production

### Variable Priority (Highest to Lowest)

1. **`G90_SDR_DIR`** - Canonical production installation
   ```bash
   export G90_SDR_DIR="$HOME/ham-radio/G90-SDR"
   ```

2. **`L_SDR_DIR`** - Active development/testing
   ```bash
   export L_SDR_DIR="$HOME/development/G90-test"
   ```

3. **`L_VIRT_DIR`** - Parent directory for virtual environments
   ```bash
   export L_VIRT_DIR="$HOME/Virtual"
   # install.bash will ask for subdirectory name
   ```

4. **No variables** - Interactive prompt or default `$HOME/G90-SDR`

### How Scripts Use These

**`install.bash`** - Determines installation location

**`start-flrig.bash` and `start-gqrx.bash`** - Find config files:

```bash
# Priority 1: G90_SDR_DIR
if [ -n "$G90_SDR_DIR" ] && [ -f "$G90_SDR_DIR/config/Xiegu-G90.prefs" ]; then
    SDR_DIR="$G90_SDR_DIR"
# Priority 2: L_SDR_DIR
elif [ -n "$L_SDR_DIR" ] && [ -f "$L_SDR_DIR/config/Xiegu-G90.prefs" ]; then
    SDR_DIR="$L_SDR_DIR"
# Priority 3: Current directory
elif [ -f "config/Xiegu-G90.prefs" ]; then
    SDR_DIR="$(pwd)"
# Priority 4: Common locations
else
    for location in "$HOME/Virtual/G90-SDR" "$HOME/G90-SDR" ...; do
        if [ -f "$location/config/Xiegu-G90.prefs" ]; then
            SDR_DIR="$location"
            break
        fi
    done
fi
```

### Example: Development Workflow

```bash
# Setup
export G90_SDR_DIR="$HOME/ham-radio/G90-SDR"      # Production
export L_SDR_DIR="$HOME/development/G90-test"     # Testing

# Install production version
bash install.bash  # Uses G90_SDR_DIR

# Install testing version
unset G90_SDR_DIR  # Temporarily hide production
bash install.bash  # Uses L_SDR_DIR

# Test new configuration
cd $L_SDR_DIR
nano config/Xiegu-G90.prefs  # Modify test config
bash utils/start-flrig.bash   # Launches with test config

# Switch back to production
export G90_SDR_DIR="$HOME/ham-radio/G90-SDR"
bash utils/start-flrig.bash   # Launches with production config
```

---

## Installation Philosophy

### Why This Order?

```
1. Python 3.13 Setup          (15-30 min if building from source)
2. Virtual Environment         (< 1 min)
3. Python Dependencies         (2-5 min) ← CRITICAL POSITIONING
4. System Updates              (5-10 min)
5. System Dependencies         (2-5 min)
6. Build FlRig and GQRX       (20-30 min)
7. Configure Permissions       (< 1 min)
8. Verify Installation         (< 1 min)
```

**Why Python Deps Before Builds?**

1. **Fast Failure Detection**
   - If `requirements.txt` has problems: Find out in 2 minutes
   - Alternative: Wait 30 minutes for builds, THEN discover pip issues
   - User experience: Fail fast, not slow

2. **Complete Environment Before Builds**
   - Python environment fully functional before lengthy compiles
   - If FlRig/GQRX builds fail, Python scripts still work
   - User can test Python while troubleshooting build issues

3. **Logical Grouping**
   - All Python setup together: Python 3.13 → venv → packages
   - System builds (FlRig/GQRX) are separate concern

4. **No Dependency**
   - Python packages don't need FlRig or GQRX
   - Connection is runtime-only (XML-RPC calls)

### Virtual Environment Strategy

**Why Use venv?**

- **Isolation:** Project dependencies don't conflict with system Python
- **Portability:** All files in one directory, easy to backup/move
- **Cleanup:** Delete directory = complete uninstall

**Why Call pip Directly?**

```bash
# We do this:
$INSTALL_DIR/bin/pip install -r requirements.txt

# Instead of this:
source $INSTALL_DIR/bin/activate
pip install -r requirements.txt
```

**Reasons:**
- Works in non-interactive scripts (no shell state to manage)
- Explicit about which Python environment
- No risk of forgetting to deactivate

---

## Design Decisions and Trade-offs

### FlRig vs Direct Serial Control

**Decision:** Use FlRig as intermediary

**Pros:**
- **Abstraction:** Don't need to know Xiegu CAT protocol details
- **Features:** PTT, meter reading, frequency memory built-in
- **Stability:** Mature codebase, handles edge cases
- **Future-proof:** Easy to swap radios (just configure FlRig)

**Cons:**
- **Extra Process:** FlRig must be running
- **Latency:** Small additional delay (negligible for HF)
- **Dependency:** Requires building/installing FlRig

**Verdict:** Pros outweigh cons for maintainability and reliability

### GQRX vs Custom Display

**Decision:** Use GQRX for spectrum display

**Pros:**
- **Mature:** Well-tested GNU Radio-based application
- **Features:** Waterfall, spectrum, recording, etc.
- **Remote Control:** TCP interface for frequency sync
- **Performance:** Hardware-accelerated, real-time on Pi 5

**Cons:**
- **Size:** Large dependency tree (Qt5, GNU Radio)
- **Build Time:** 15-20 minutes to compile
- **Overkill:** Many features we don't use

**Verdict:** Maturity and reliability worth the build time

### PulseAudio vs ALSA Direct

**Decision:** Use PulseAudio

**Pros:**
- **Routing:** Easy to route G90 audio to GQRX
- **Mixing:** Can use other audio apps simultaneously
- **Compatibility:** GQRX works well with PulseAudio

**Cons:**
- **Latency:** Slightly higher than ALSA direct (not noticeable for HF)
- **Complexity:** Another layer in audio stack

**Verdict:** Flexibility worth small latency increase

### Configuration Reset on Launch

**Decision:** Copy configs on every start

**Pros:**
- **Consistency:** Always start from known-good state
- **Recovery:** If user breaks config, next launch fixes it
- **Debugging:** Easier to isolate issues

**Cons:**
- **User Changes Lost:** Settings revert each launch
- **Disk I/O:** Small overhead copying files

**Verdict:** Reliability worth losing custom settings

**Workaround:** Users can modify repository config files to make permanent changes

---

## Extending the System

### Adding a New Radio

1. **Configure FlRig** for new radio (use FlRig GUI)
2. **Export Configuration:**
   ```bash
   cp ~/.flrig/NewRig.prefs ~/G90-SDR/config/
   cp ~/.flrig/flrig.prefs ~/G90-SDR/config/
   ```
3. **Update start-flrig.bash:** Change config file names
4. **Test:** Verify XML-RPC works, frequency sync functions

### Adding Custom Control Scripts

Example: Auto-tune to contest frequencies

```python
# scripts/contest_qsy.py
from rig_control import RigControl

rig = RigControl()
rig.connect()

# QSY to 20m CW contest frequency
rig.set_frequency(14030000)  # 14.030 MHz
rig.set_mode("CW")

rig.disconnect()
```

### Adding New Features to frequency_sync

Example: Log frequency changes

```python
# In frequency_sync.py, add to sync_once():
if frequency_changed:
    with open('frequency_log.txt', 'a') as f:
        f.write(f"{datetime.now()} | {frequency/1e6:.6f} MHz | {mode}\n")
    self.gqrx.set_frequency(frequency)
```

### Custom Build Scripts

Example: Build specific FlRig version

```bash
# utils/build-flrig-v2.0.8.bash
FLRIG_VERSION="2.0.08"
wget "https://sourceforge.net/projects/fldigi/files/flrig/flrig-${FLRIG_VERSION}.tar.gz"
# ... rest of build
```

---

## Troubleshooting Architecture

### FlRig Won't Connect to G90

**Check:**

1. **Serial Port:** `ls /dev/ttyUSB*` (should see `/dev/ttyUSB0`)
2. **Permissions:** `groups` (should include `dialout`)
3. **Baud Rate:** FlRig config must be 19200
4. **G90 CAT:** Menu → Function → CAT/LINEAR → ON

**Verify:**
```bash
# Test serial port
screen /dev/ttyUSB0 19200
# Type: FA; (get frequency command)
# Should see: FA00014074000; (or similar)
```

### GQRX Not Receiving Audio

**Check:**

1. **PulseAudio:** `pacmd list-sources` (G90 should be listed)
2. **GQRX Config:** `device="audio_source=pulse"`
3. **Sample Rate:** Must be 48000 Hz

**Verify:**
```bash
# Record test audio
parecord --channels=2 --rate=48000 test.wav
# Play back
paplay test.wav
```

### Frequency Sync Not Working

**Check:**

1. **FlRig XML-RPC:**
   ```python
   from xmlrpc.client import ServerProxy
   rig = ServerProxy("http://127.0.0.1:12345")
   print(rig.rig.get_vfo())  # Should print frequency
   ```

2. **GQRX Remote Control:**
   ```bash
   telnet 127.0.0.1 7356
   # Type: f (get frequency)
   # Should see frequency response
   ```

3. **Script Running:** `ps aux | grep frequency_sync`

### Build Failures

**FlRig:**
- **Missing FLTK:** `sudo apt install libfltk1.3-dev`
- **Version Parse Fail:** Check SourceForge is accessible
- **Compile Errors:** Check GCC version (`gcc --version`, need >= 9.0)

**GQRX:**
- **Qt5 Missing:** `sudo apt install qtbase5-dev qtchooser`
- **GNU Radio Missing:** `sudo apt install gnuradio-dev`
- **Volk Error:** Use `libvolk-dev` (not `libvolk2.5-dev` on Ubuntu 24.04)

---

## Performance Considerations

### Latency Budget

```
G90 CAT Command → FlRig → frequency_sync.py → GQRX
     <10ms          <5ms         <50ms         <10ms

Total: ~75ms typical, <100ms worst case
```

For HF operation, this is imperceptible.

### CPU Usage (Raspberry Pi 5)

```
FlRig:             ~5% CPU (1 core)
GQRX:              ~15% CPU (waterfall rendering)
frequency_sync:    ~1% CPU (polling loop)
Total:             ~20-25% CPU
```

Plenty of headroom for other applications.

### Memory Footprint

```
FlRig:             ~50 MB RSS
GQRX:              ~200 MB RSS
Python venv:       ~100 MB
Total:             ~350 MB
```

Well within Pi 5's 4-8 GB RAM.

---

## Conclusion

The G90-SDR system is designed for **reliability**, **maintainability**, and **extensibility**. The modular architecture allows components to be swapped or upgraded independently. The environment variable system supports multiple installations. Comprehensive inline comments make the codebase approachable for hams who want to dig deeper.

**Key Architectural Principles:**

1. **Single Source of Truth** - Build logic in one place
2. **Fail Fast** - Detect problems early (Python deps before builds)
3. **Known-Good Configs** - Reset on launch
4. **Environment Flexibility** - Support production + testing
5. **Comprehensive Documentation** - Every decision explained

For questions or contributions, see the GitHub repository.

**73 de G90-SDR Team**

---

*This architecture document is maintained alongside the codebase. If you modify the system, update this document!*
