# G90-SDR Change Log

All notable changes to the G90-SDR project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v0.5.3] - 2025-11-09

### Added
- **Automatic SDR++ Configuration** - SDR++ now starts pre-configured and ready to work
  - New `scripts/configure_sdrpp.py`: Automatically configures SDR++ for G90-SDR operation
  - Creates `~/.config/sdrpp/rigctl_server_config.json` with optimal settings
  - Enables rigctl_server module in SDR++ main config
  - Sets rigctl server to auto-start on SDR++ launch (port 4532)
  - No more manual module enabling needed!

### Changed
- **install.bash**: Added Step 10 - "Configuring SDR++ for G90-SDR"
  - Runs `configure_sdrpp.py` automatically after SDR++ installation
  - Handles both first-time and existing SDR++ configurations
  - Renumbered subsequent steps (Step 10→11, 11→12, 12→13)

- **scripts/start_sdr.py**: Simplified SDR++ startup
  - Removed manual configuration instructions
  - Removed "enable rigctl server" prompt
  - Users no longer need to manually enable modules
  - SDR++ launches pre-configured and ready for frequency sync

### Benefits
- **One-Time Setup**: SDR++ configuration happens during installation
- **No Manual Steps**: Rigctl server auto-starts, no Module Manager needed
- **Matches GQRX Experience**: SDR++ now "dances to the same tune" as GQRX did
- **Faster Startup**: No waiting for user to enable modules manually
- **Reliable**: Configuration persists across SDR++ updates

### Technical Details
SDR++ configuration includes:
- `rigctl_server_config.json`: host=localhost, port=4532, autoStart=true
- Main config.json: rigctl_server module instance enabled
- Compatible with SDR++ master branch (latest development)

---

## [v0.5.2] - 2025-11-09

### Added
- **User-Configurable Interactive Startup Mode**
  - Installation now prompts for interactive mode preference (y/n)
  - Settings stored in `config/settings.json` for persistence
  - Users can edit JSON file to change settings after installation
  - Framework for future configurable settings (network ports, etc.)

### Changed
- **scripts/start_sdr.py**: Implements conditional interactive prompts
  - Loads settings from `config/settings.json`
  - Interactive mode (default): Pauses for user confirmation at each step
  - Automatic mode: Launches all components without prompting
  - Audio reset: Automatic in non-interactive mode
  - Falls back gracefully to interactive if settings file missing

- **install.bash**: Added user preference configuration step
  - Prompts: "Enable interactive startup prompts? (y/n)"
  - Default: 'yes' (safe for new users)
  - Creates `config/settings.json` with user preference

### Benefits
- **New Users**: Get hand-holding with step-by-step prompts (default behavior)
- **Experienced Users**: One-time configuration for auto-start
- **Easy Configuration**: Human-readable JSON file with comments
- **Extensible**: Framework ready for additional settings

### Configuration Format
```json
{
  "startup": {
    "interactive_mode": true,
    "_comment": "Set to false for automatic startup"
  },
  "network": {
    "flrig_host": "127.0.0.1",
    "flrig_port": 12345,
    "sdr_host": "127.0.0.1",
    "sdr_port": 4532
  }
}
```

---

## [v0.5.1] - 2025-11-09

### Changed
- **SDR++ Build Strategy**: Changed from building stable tagged releases to building from master branch
  - Updated `install.bash`: Build SDR++ from master branch instead of latest stable tag
  - Updated `utils/build-sdrpp.bash`: Build from master branch
  - Removed Ubuntu 24.04 compatibility patch (no longer needed - fix is in master)
  - Display commit hash during build for version tracking

### Fixed
- **Ubuntu 24.04 Compatibility**: Eliminated need for stdexcept patch by using master branch
  - Master branch already includes fix for missing `#include <stdexcept>` in networking.cpp
  - Commit 27ab5bf3 (Jan 22, 2024) fixed compilation errors with GCC 13

### Rationale
- **Latest Fixes**: Get all recent bug fixes and Ubuntu 24.04 compatibility improvements
- **Active Development**: SDR++ master branch is actively maintained and stable
- **No Stable Release**: Latest stable tag (1.0.4) predates Ubuntu 24.04 compatibility fixes
- **Simpler Maintenance**: Eliminates need to maintain compatibility patches

### Notes
- This is a **development version** strategy - master branch instead of stable tags
- Build process now displays commit hash for tracking: `Building SDR++ from commit: [hash]`
- When SDR++ releases next stable version with fixes, we can evaluate reverting to stable tags

---

## [v0.5.0] - 2025-11-09

### Changed
- **BREAKING: Replaced GQRX with SDR++** as the software-defined radio receiver application
  - Updated `install.bash` Step 5: Removed GQRX build, added SDR++ build from source
  - Removed GNU Radio, Qt5, and Boost dependencies (no longer needed)
  - Added SDR++ specific dependencies: libfftw3-dev, libglfw3-dev, libglew-dev, libvolk2-dev, libsoapysdr-dev, etc.
  - Updated build time estimate: 5-10 minutes (was 10-20 minutes for GQRX)
  - Updated version string to 0.5.0 in install script welcome message

### Changed - Python Scripts
- **Renamed GQRXControl to SDRControl** in `scripts/frequency_sync.py`
  - Updated to use SDR++ rigctl server (port 4532) instead of GQRX remote control (port 7356)
  - Renamed `gqrx` variable to `sdr` throughout FrequencySync class
  - Updated all log messages and docstrings to reference SDR++ instead of GQRX
  - Updated parameter names: `gqrx_host`/`gqrx_port` → `sdr_host`/`sdr_port`

- **Updated start_sdr.py launcher script**
  - Changed process kill list: `gqrx` → `sdrpp`
  - Updated startup instructions for SDR++ rigctl server configuration
  - Updated user prompts and messages to reference SDR++ instead of GQRX

### Changed - Installation Script
- **Updated verification step** (Step 9 in install.bash)
  - Changed check from `gqrx` to `sdrpp` command
  - Updated success/warning messages accordingly

- **Updated final instructions**
  - Changed "Launch GQRX" → "Launch SDR++"
  - Updated command: `gqrx` → `sdrpp`

### Rationale
- **Performance**: SDR++ is significantly lighter and faster on Raspberry Pi 5 compared to GQRX
- **Build Time**: Reduced compile time by ~50% (5-10 min vs 10-20 min)
- **Dependencies**: Eliminated heavy GNU Radio stack, reducing installation complexity
- **Resource Usage**: Lower memory and CPU usage during operation
- **Modern Development**: SDR++ is actively developed with excellent ARM optimization
- **Multi-VFO Support**: SDR++ supports multiple VFO operation, enabling future expansion for dual-VFO radios
- **Use Case Alignment**: For basic SDR reception with radio control, GNU Radio's complexity was unnecessary

### Migration Notes
- **Breaking Change**: Users upgrading from v0.1.x will need to:
  1. Uninstall GQRX if desired: `sudo apt remove gqrx`
  2. Run fresh installation to build SDR++
  3. Configure SDR++ rigctl server (port 4532) instead of GQRX remote control

- **Frequency Sync Changes**: The frequency synchronization now connects to SDR++ rigctl server on port 4532 (was GQRX on port 7356)

### Files Modified
- `install.bash` - Step 5, verification, final messages, version string
- `scripts/frequency_sync.py` - Class rename, port change, all references
- `scripts/start_sdr.py` - SDR++ launch and configuration instructions

### Future Expansion Opportunities
- Multi-VFO operation support (SDR++ native capability)
- Lighter resource usage enables more simultaneous operations
- Active SDR++ development community for potential feature contributions

---

## [v0.1.1] - 2025-11-04

### Changed
- **Group Permission Instructions**: Updated instructions for group membership changes to use logout/login instead of reboot
  - Updated `INSTALL.md` Step 1.1: Changed from `sudo reboot` to logout/login instruction
  - Updated `install.bash`: Changed final message from requiring reboot to requiring logout/login

### Rationale
- A full system reboot is unnecessary for group membership changes to take effect
- Users only need to logout and login for new group permissions to be applied
- Reduces installation time and improves user experience

### Files Modified
- `INSTALL.md`
- `install.bash`

---

## [v0.1.0] - 2025-11-04

### Changed
- **Python Version References**: Removed all hardcoded Python 3.13 version references to support flexible Python version selection
  - Updated `INSTALL.md`: Changed `python3.13` and `python3.13-dev` to generic `python3` and `python3-dev`
  - Updated `install.bash`: Simplified Python installation to use generic `python3` package names
  - Updated `install.bash`: Removed conditional Python 3.13 detection in virtual environment creation
  - Updated `update.bash`: Removed Python 3.13 fallback logic in virtual environment creation
  - All scripts now use `python3 -m venv venv` instead of version-specific commands

### Rationale
- Users can now specify their preferred Python version using custom tools (e.g., `makevenv` script)
- Removes hardcoded version assumptions that become outdated
- Simplifies installation logic and improves maintainability
- Provides flexibility for users to work with different Python 3 versions (3.9, 3.10, 3.11, 3.12, 3.13+)

### Files Modified
- `INSTALL.md`
- `install.bash`
- `update.bash`

### Documentation Added
- `PYTHON_VERSION_UPDATES.md`: Detailed documentation of Python version reference changes

---

## Version Number Guidelines

This project uses Semantic Versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Incompatible API changes or major feature overhauls
- **MINOR**: New features added in a backwards-compatible manner
- **PATCH**: Backwards-compatible bug fixes

---

## Categories Used

- **Added**: New features or files
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future versions
- **Removed**: Features or files that have been removed
- **Fixed**: Bug fixes
- **Security**: Security-related changes

---

## Initial Release

This is the initial documented version of the G90-SDR project. Previous development was undocumented.
