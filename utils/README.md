# Utils Directory - G90-SDR Build and Maintenance Scripts

This directory contains modular utility scripts used by the G90-SDR installation and maintenance system.

---

## ⚠️ IMPORTANT WARNING

**DO NOT run these scripts directly unless you know exactly what you're doing.**

These scripts are designed to be called by:
- `install.bash` (main installation script)
- `rebuild_all.bash` (orchestrator for rebuilding)

Running individual scripts out of sequence can cause:
- Missing dependencies
- Incomplete installations
- System configuration errors
- Build failures

---

## Safe Scripts to Run Manually

These scripts are safe and designed for standalone use:

### `start_sdr.py` ⭐ RECOMMENDED (Python version)
**Purpose:** Start complete G90 SDR system with one command
**When to use:** Normal operation - this is the main way to run the system
**Usage:**
```bash
python3 scripts/start_sdr.py
```
**What it does:**
- Starts FlRig with G90 configuration
- Starts GQRX with SDR configuration
- Starts frequency sync for bidirectional control
- Automatically stops everything when you press Ctrl+C

**Advantages:**
- Direct integration with frequency_sync (no subprocess overhead)
- Better error handling and status reporting
- Cleaner process management

**Bidirectional frequency control:**
- Turn VFO knob on G90 → GQRX waterfall follows
- Click GQRX waterfall → G90 radio QSYs (changes frequency)

**Time to start:** ~5-10 seconds

**Note:** There's also `bash utils/start-sdr.bash` if you prefer the bash version.

---

### `rebuild_all.bash`
**Purpose:** Rebuild both FlRig and GQRX to latest versions
**When to use:** Update software to latest stable releases
**Usage:**
```bash
bash utils/rebuild_all.bash
```
**What it does:**
- Shows current installed versions
- Calls build-flrig.bash to rebuild FlRig
- Calls build-gqrx.bash to rebuild GQRX
- Verifies installations

**Time required:** 20-30 minutes

---

### `start-flrig.bash`
**Purpose:** Start FlRig with G90 configuration
**When to use:** Launch FlRig with proper G90 settings
**Usage:**
```bash
bash utils/start-flrig.bash
```
**What it does:**
- Finds G90-SDR installation directory
- Copies G90 config files to ~/.flrig/
- Launches FlRig with G90 settings (serial port, baud rate, etc.)
- Enables XML-RPC server on port 12345 for CAT control

---

### `start-gqrx.bash`
**Purpose:** Start GQRX with G90 SDR configuration
**When to use:** Launch GQRX with proper G90 panadapter settings
**Usage:**
```bash
bash utils/start-gqrx.bash
```
**What it does:**
- Finds G90-SDR installation directory
- Copies GQRX config to ~/.config/gqrx/default.conf
- Launches GQRX with PulseAudio input, USB mode
- Enables remote control on port 7356 for frequency sync

**Note:** After starting both FlRig and GQRX, run `python3 scripts/frequency_sync.py` to synchronize frequency between G90 and GQRX.

---

## Build Scripts (Called by install.bash and rebuild_all.bash)

### ⛔ `build-flrig.bash`
**DO NOT RUN STANDALONE**

**Purpose:** Build FlRig from latest SourceForge release
**Called by:** install.bash, rebuild_all.bash
**What it does:**
- Installs FlRig build dependencies
- Downloads latest FlRig from SourceForge
- Compiles from source
- Installs to /usr/local/bin/flrig

**Why not standalone:**
- Assumes system dependencies are installed
- May skip interactive prompts during install.bash
- Could interfere with installation process

---

### ⛔ `build-gqrx.bash`
**DO NOT RUN STANDALONE**

**Purpose:** Build GQRX from latest GitHub stable release
**Called by:** install.bash, rebuild_all.bash
**What it does:**
- Installs GQRX build dependencies (Qt5, GNU Radio)
- Clones latest stable GQRX from GitHub
- Compiles with cmake
- Installs to /usr/local/bin/gqrx

**Why not standalone:**
- Assumes system dependencies are installed
- May skip interactive prompts during install.bash
- Could interfere with installation process

---

## Other Utility Scripts

### `makevenv.bash`
**Purpose:** Create Python virtual environment
**Called by:** install.bash
**DO NOT RUN STANDALONE** - Part of installation sequence

---

### `create_universal_launchers.bash`
**Purpose:** Create desktop launcher files
**Called by:** install.bash
**DO NOT RUN STANDALONE** - Requires completed installation

---

### `show-env.bash`
**Purpose:** Display environment variables
**Safe to run:** Yes - informational only

---

### `bump_version.bash`
**Purpose:** Development tool for version management
**Safe to run:** Only for developers

---

## How the Modular System Works

```
User runs install.bash
    │
    ├──> Calls build-flrig.bash ──> Builds FlRig
    │
    ├──> Calls build-gqrx.bash ──> Builds GQRX
    │
    └──> Calls makevenv.bash ──> Creates Python venv

User runs rebuild_all.bash
    │
    ├──> Calls build-flrig.bash ──> Rebuilds FlRig
    │
    └──> Calls build-gqrx.bash ──> Rebuilds GQRX
```

**Key Principle:** Single source of truth
- FlRig build logic exists in ONE place: build-flrig.bash
- GQRX build logic exists in ONE place: build-gqrx.bash
- install.bash and rebuild_all.bash use the SAME scripts

This prevents bugs where different parts of the system build software differently.

---

## Maintenance Commands

### Update to Latest FlRig and GQRX
```bash
cd /path/to/xiegu-g90-sdr
bash utils/rebuild_all.bash
```

### Rebuild Just FlRig (Advanced Users Only)
```bash
# Only if you understand the risks
bash utils/build-flrig.bash
```

### Rebuild Just GQRX (Advanced Users Only)
```bash
# Only if you understand the risks
bash utils/build-gqrx.bash
```

---

## When Things Go Wrong

### "Script not found" error
You're probably in the wrong directory. Run from the G90-SDR root:
```bash
cd /path/to/xiegu-g90-sdr
bash utils/rebuild_all.bash  # NOT: cd utils && bash rebuild_all.bash
```

### Build fails partway through
Don't try to resume manually. Re-run the full installation:
```bash
bash install.bash
```

### FlRig or GQRX won't start after rebuild
1. Log out and back in (PATH may need refresh)
2. Check installation:
```bash
which flrig
flrig --version
which gqrx
gqrx --version
```

---

## For Developers

If you need to modify build logic:

1. **Modify the source:** Edit build-flrig.bash or build-gqrx.bash
2. **Test standalone:** Verify the script works independently
3. **Test with install.bash:** Ensure integration works
4. **Test with rebuild_all.bash:** Ensure orchestration works

**Never duplicate build code** - This causes the exact bug we just fixed where install.bash had different (broken) FlRig build code than rebuild_all.bash.

---

## Summary

**Run these safely:**
- ✅ `rebuild_all.bash` - Update software
- ✅ `start-flrig.bash` - Launch FlRig with G90 config
- ✅ `start-gqrx.bash` - Launch GQRX with G90 SDR config
- ✅ `show-env.bash` - Check environment

**Don't run these directly:**
- ⛔ `build-flrig.bash` - Use rebuild_all.bash instead
- ⛔ `build-gqrx.bash` - Use rebuild_all.bash instead
- ⛔ `makevenv.bash` - Use install.bash instead
- ⛔ `create_universal_launchers.bash` - Use install.bash instead

**When in doubt, use:**
```bash
bash install.bash        # Full installation/reinstallation
bash utils/rebuild_all.bash  # Update FlRig and GQRX
```

---

**Last Updated:** 2025-11-08
**G90-SDR Version:** 0.2.0
