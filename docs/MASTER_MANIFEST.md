# G90-SDR Master File Manifest

Complete inventory of all files in the G90-SDR project with descriptions and purposes.

**Version:** 1.0.0
**Date:** 2025-01-XX
**Total Files:** 47

---

## ðŸ“ Root Directory (/)

### Documentation Files

| File                       | Type          | Purpose                                              |
|----------------------------|---------------|------------------------------------------------------|
| `README.md`                | Documentation | Project overview, features, quick start guide       |
| `INSTALL.md`               | Documentation | Complete installation instructions for Ubuntu 24.04 |
| `LICENSE`                  | Legal         | MIT License with amateur radio requirements         |
| `QUICK_REFERENCE.md`       | Documentation | Command quick reference card                        |
| `NAMING_CONVENTIONS.md`    | Documentation | File naming standards and conventions               |
| `DISTRIBUTION_README.md`   | Documentation | Guide for sharing with community                    |
| `BUILDING_FROM_SOURCE.md`  | Documentation | Why and how to build from source                    |
| `ENVIRONMENT_VARIABLES.md` | Documentation | Multi-environment workflow guide                    |
| `MASTER_MANIFEST.md`       | Documentation | This file - complete file inventory                 |

### Configuration Files

| File               | Type   | Purpose                               |
|--------------------|--------|---------------------------------------|
| `requirements.txt` | Python | Python package dependencies (pip)    |
| `.gitignore`       | Git    | Files to exclude from version control |

### Installation Scripts

| File                              | Type  | Purpose                                              |
|-----------------------------------|-------|------------------------------------------------------|
| `install.bash`                    | Shell | Main installation script (builds from source)       |
| `update.bash`                     | Shell | System update script                                 |
| `install_launchers.bash`          | Shell | Desktop launcher installer (MATE optimized)         |
| `install_wrappers.bash`           | Shell | Universal wrapper installation to /usr/local/bin    |
| `create_universal_launchers.bash` | Shell | Create universal desktop launchers                  |

### Utility Scripts

| File                    | Type  | Purpose                                   |
|-------------------------|-------|-------------------------------------------|
| `make_executable.bash`  | Shell | Make all scripts executable              |
| `fix_permissions.bash`  | Shell | Comprehensive permission fixing          |
| `fix_all.bash`          | Shell | Simple permission fixer                  |
| `verify_files.bash`     | Shell | Verify all required files present        |
| `check_env.bash`        | Shell | Check environment variable configuration |
| `set_path.bash`         | Shell | Configure installation path              |
| `create_all_files.bash` | Shell | Create all project files (deprecated)    |

### Desktop Integration

| File            | Type    | Purpose                          |
|-----------------|---------|----------------------------------|
| `flrig.desktop` | Desktop | FlRig desktop launcher template |

---

## ðŸ“ config/

Configuration files and templates.

| File                 | Type | Purpose                                                   |
|----------------------|------|-----------------------------------------------------------|
| `g90_sdr.yaml`       | YAML | Main system configuration (FlRig, GQRX, Audio, Sync)     |
| `flrig_g90.xml`      | XML  | FlRig configuration template for G90                      |
| `gqrx_config.conf`   | INI  | GQRX SDR receiver configuration template                  |
| `audio_routing.conf` | INI  | PulseAudio audio routing configuration                    |

**Note:** `audio_calibration.json` created at runtime by CalibrateAudio.py

---

## ðŸ“ scripts/

Main application Python scripts (all executable).

| File                | Type   | Lines* | Purpose                                                 |
|---------------------|--------|--------|---------------------------------------------------------|
| `rig_control.py`    | Python | ~300   | FlRig XML-RPC interface, CAT control for G90           |
| `frequency_sync.py` | Python | ~350   | Real-time frequency synchronization (G90 â†” GQRX)       |
| `audio_router.py`   | Python | ~350   | Audio device detection and PulseAudio routing          |
| `config_manager.py` | Python | ~300   | Configuration file management (load/save/import/export)|
| `device_monitor.py` | Python | ~250   | Hardware connection monitoring with callbacks          |
| `start_sdr.py`      | Python | ~250   | Main system startup orchestration                      |
| `stop_sdr.py`       | Python | ~150   | Graceful system shutdown                               |
| `safe_start.py`     | Python | ~200   | Safe startup with manual verification steps            |

**Total Python Code:** ~2,150 lines

---

## ðŸ“ tests/

Diagnostic and testing scripts (all executable).

| File                | Type   | Lines* | Purpose                                             |
|---------------------|--------|--------|-----------------------------------------------------|
| `TestConnection.py` | Python | ~250   | USB device, serial port, FlRig connectivity tests  |
| `TestAudio.py`      | Python | ~250   | Audio device detection and quality testing         |
| `TestCatControl.py` | Python | ~200   | CAT command verification and rapid command testing |
| `DiagnoseSystem.py` | Python | ~400   | Complete system health check and diagnostics       |
| `CalibrateAudio.py` | Python | ~250   | Audio level calibration with visual meters         |
| `DiagnoseCrash.py`  | Python | ~250   | Post-crash diagnosis and recovery recommendations  |
| `DebugUsb.py`       | Python | ~150   | Detailed USB device debug information              |

**Total Test Code:** ~1,750 lines

---

## ðŸ“ utils/

Utility and maintenance scripts.

| File               | Type  | Lines* | Purpose                                              |
|--------------------|-------|--------|------------------------------------------------------|
| `rebuild_all.bash` | Shell | ~450   | Build FlRig and GQRX from source (latest versions)  |

**Total Utility Code:** ~550 lines

---

## ðŸ“ docs/

Detailed documentation files.

| File                    | Type          | Pages* | Purpose                                     |
|-------------------------|---------------|--------|---------------------------------------------|
| `USER_GUIDE.md`         | Documentation | ~20    | Complete user guide with daily operation   |
| `TROUBLESHOOTING.md`    | Documentation | ~18    | Problem solving guide with solutions        |
| `PROJECT_STRUCTURE.md`  | Documentation | ~15    | Complete project organization reference     |
| `FLRIG_PARAMETERS.md`   | Documentation | ~12    | FlRig command-line parameters guide         |
| `MATE_DESKTOP_GUIDE.md` | Documentation | ~10    | MATE Desktop integration guide              |

**Total Documentation:** ~75 pages

---

## ðŸ“ logs/

Log file directory (created during installation).

| File          | Type   | Purpose                                          |
|---------------|--------|--------------------------------------------------|
| `.gitkeep`    | Marker | Keeps empty directory in git                    |
| `g90_sdr.log` | Log    | Main application log (created at runtime)       |

---

## ðŸ“ venv/

Python virtual environment (created during installation, not in git).

**Status:** Created by `install.bash`
**Size:** ~200-300 MB
**Contents:** Python 3.13+ and all dependencies from requirements.txt

---

## ðŸ”§ System-Wide Files (Not in Repository)

These files are installed to the system during setup:

### /usr/local/bin/

| File        | Type   | Purpose                                              |
|-------------|--------|------------------------------------------------------|
| `g90-sdr`   | Shell  | Universal wrapper - finds and starts G90-SDR        |
| `g90-flrig` | Shell  | Universal wrapper - starts FlRig with G90 config    |
| `flrig`     | Binary | FlRig application (built from source)               |
| `gqrx`      | Binary | GQRX application (built from source)                |

### ~/.local/share/applications/

| File                   | Type    | Purpose                                  |
|------------------------|---------|------------------------------------------|
| `flrig-g90.desktop`    | Desktop | FlRig launcher for G90                  |
| `gqrx-g90.desktop`     | Desktop | GQRX launcher                           |
| `g90-sdr.desktop`      | Desktop | Complete G90-SDR system launcher        |
| `g90-sdr-safe.desktop` | Desktop | Safe start troubleshooting launcher     |

---

## ðŸ“Š Statistics

### File Count by Type

| Type               | Count  |
|--------------------|--------|
| Python Scripts     | 15     |
| Shell Scripts      | 17     |
| Documentation      | 15     |
| Configuration      | 4      |
| Desktop Files      | 5      |
| **Total**          | **56** |

### Code Statistics

| Category           | Lines of Code |
|--------------------|---------------|
| Python (scripts/)  | ~2,150        |
| Python (tests/)    | ~1,750        |
| Shell (utils/)     | ~550          |
| Shell (root)       | ~1,500        |
| **Total Code**     | **~5,950**    |

### Documentation

| Type                       | Pages |
|----------------------------|-------|
| User Documentation         | ~75   |
| Technical Documentation    | ~30   |
| Quick References           | ~15   |
| **Total Documentation**    | **~120 pages** |

---

## ðŸ—‚ï¸ File Categories

### Executable Scripts (32 files)

**Shell Scripts (17):**
- install.bash
- update.bash
- install_launchers.bash
- install_wrappers.bash
- create_universal_launchers.bash
- make_executable.bash
- fix_permissions.bash
- fix_all.bash
- verify_files.bash
- check_env.bash
- set_path.bash
- create_all_files.bash
- utils/rebuild_all.bash
- g90-sdr (system wrapper)
- g90-flrig (system wrapper)

**Python Scripts (15):**
- scripts/rig_control.py
- scripts/frequency_sync.py
- scripts/audio_router.py
- scripts/config_manager.py
- scripts/device_monitor.py
- scripts/start_sdr.py
- scripts/stop_sdr.py
- scripts/safe_start.py
- tests/TestConnection.py
- tests/TestAudio.py
- tests/TestCatControl.py
- tests/DiagnoseSystem.py
- tests/CalibrateAudio.py
- tests/DiagnoseCrash.py
- tests/DebugUsb.py

### Configuration Files (4)

- requirements.txt
- config/g90_sdr.yaml
- config/flrig_g90.xml
- config/gqrx_config.conf
- config/audio_routing.conf

### Documentation (15)

- README.md
- INSTALL.md
- LICENSE
- QUICK_REFERENCE.md
- NAMING_CONVENTIONS.md
- DISTRIBUTION_README.md
- BUILDING_FROM_SOURCE.md
- ENVIRONMENT_VARIABLES.md
- MASTER_MANIFEST.md
- docs/USER_GUIDE.md
- docs/TROUBLESHOOTING.md
- docs/PROJECT_STRUCTURE.md
- docs/FLRIG_PARAMETERS.md
- docs/MATE_DESKTOP_GUIDE.md

---

## ðŸ” File Dependencies

### Core Dependencies

```
start_sdr.py
â”œâ”€â”€ requires: rig_control.py
â”œâ”€â”€ requires: frequency_sync.py
â”œâ”€â”€ requires: FlRig (system)
â”œâ”€â”€ requires: GQRX (system)
â””â”€â”€ requires: venv/

install.bash
â”œâ”€â”€ creates: venv/
â”œâ”€â”€ builds: FlRig (to /usr/local/bin/)
â”œâ”€â”€ builds: GQRX (to /usr/local/bin/)
â””â”€â”€ installs: Python packages

install_wrappers.bash
â”œâ”€â”€ creates: /usr/local/bin/g90-sdr
â””â”€â”€ creates: /usr/local/bin/g90-flrig
```

---

## ðŸ“ File Purposes Summary

### Installation & Setup
- install.bash, update.bash, requirements.txt
- install_wrappers.bash, install_launchers.bash
- Permission fixers, environment checkers

### Core Functionality
- rig_control.py, frequency_sync.py, audio_router.py
- start_sdr.py, stop_sdr.py, safe_start.py
- config_manager.py, device_monitor.py

### Testing & Diagnostics
- All files in tests/ directory
- Comprehensive system testing and troubleshooting

### Maintenance
- All files in utils/ directory
- Rebuild scripts for source updates

### Documentation
- User guides, installation guides, troubleshooting
- Technical references, conventions, distribution guides

### Configuration
- Template files for FlRig, GQRX, audio routing
- System configuration management

---

## ðŸš€ Critical Files (Do Not Delete)

These files are essential for system operation:

1. âœ… **install.bash** - Without this, installation impossible
2. âœ… **requirements.txt** - Python dependencies
3. âœ… **scripts/start_sdr.py** - Main entry point
4. âœ… **scripts/rig_control.py** - FlRig communication
5. âœ… **scripts/frequency_sync.py** - Core synchronization
6. âœ… **config/g90_sdr.yaml** - System configuration
7. âœ… **install_wrappers.bash** - System integration
8. âœ… **README.md** - Project overview
9. âœ… **INSTALL.md** - Installation instructions

---

## ðŸ”„ Files Modified During Runtime

These files are created or modified during operation:

- `logs/g90_sdr.log` - Application logs
- `config/audio_calibration.json` - Audio calibration data
- `venv/` - Virtual environment (created once)

---

## ðŸ“¦ Files for Distribution

When distributing G90-SDR, include these files:

**Include:**
- All Python scripts (scripts/, tests/)
- All shell scripts (root, utils/)
- All documentation (docs/, root *.md)
- All configuration templates (config/)
- requirements.txt
- LICENSE
- .gitignore

**Exclude:**
- venv/ (users create their own)
- logs/*.log (user-specific)
- config/audio_calibration.json (user-specific)
- __pycache__/ (Python cache)
- *.pyc (compiled Python)

---

## ðŸŽ¯ File Verification Checklist

Use this checklist to verify complete installation:

```bash
cd $G90_SDR_DIR

# Root directory
[ -f README.md ] && echo "âœ“ README.md"
[ -f INSTALL.md ] && echo "âœ“ INSTALL.md"
[ -f install.bash ] && echo "âœ“ install.bash"
[ -f requirements.txt ] && echo "âœ“ requirements.txt"

# Core scripts
[ -f scripts/start_sdr.py ] && echo "âœ“ start_sdr.py"
[ -f scripts/rig_control.py ] && echo "âœ“ rig_control.py"
[ -f scripts/frequency_sync.py ] && echo "âœ“ frequency_sync.py"

# Test scripts
[ -f tests/TestConnection.py ] && echo "âœ“ TestConnection.py"
[ -f tests/DiagnoseSystem.py ] && echo "âœ“ DiagnoseSystem.py"

# Utils
[ -f utils/rebuild_all.bash ] && echo "âœ“ rebuild_all.bash"

# Directories
[ -d config ] && echo "âœ“ config/"
[ -d scripts ] && echo "âœ“ scripts/"
[ -d tests ] && echo "âœ“ tests/"
[ -d docs ] && echo "âœ“ docs/"
[ -d utils ] && echo "âœ“ utils/"
[ -d logs ] && echo "âœ“ logs/"
```

---

## ðŸ“… Version History

| Version | Date    | Files | Description                          |
|---------|---------|-------|--------------------------------------|
| 1.0.0   | 2025-01 | 56    | Initial release - complete system   |

---

## ðŸ” File Permissions

### Executable Files (755)
All .bash and .py files should be executable:
```bash
chmod +x scripts/*.py tests/*.py utils/*.bash *.bash
```

### Configuration Files (644)
Configuration files should be readable but not executable:
```bash
chmod 644 config/* *.md *.txt LICENSE
```

---

## ðŸ“§ Manifest Maintenance

**When adding files:**
1. Add entry to appropriate section
2. Update file count statistics
3. Update version history
4. Commit with manifest update

**When removing files:**
1. Remove from appropriate section
2. Update file count statistics
3. Document reason in version history

---

**This manifest documents every file in G90-SDR v1.0.0**

**Maintained by:** Project maintainer
**Last Updated:** 2025-01-XX
**Status:** Production Ready âœ…
