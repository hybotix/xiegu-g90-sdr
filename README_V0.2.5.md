# G90-SDR v0.2.5 - Major Milestone Release

**Release Date:** 2025-11-08

## 🎯 Major Features

This release represents a **MAJOR MILESTONE** in the G90-SDR project with revolutionary improvements to usability and functionality.

### Bidirectional Frequency Control ⭐
The game-changer: GQRX can now control your G90 radio!

- **Click GQRX waterfall → G90 changes frequency** (NEW!)
- **Turn G90 VFO knob → GQRX follows** (enhanced)
- Smart priority system prevents oscillation
- 100 Hz deadband for stable operation
- Real-time bidirectional synchronization

### One-Command System Startup 🚀
No more juggling three terminal windows!

```bash
# Start everything with one command
python3 scripts/start_sdr.py

# Press Ctrl+C to stop everything cleanly
```

**What it does:**
- Starts FlRig automatically
- Starts GQRX automatically
- Starts frequency sync automatically
- Monitors all processes
- Clean shutdown on Ctrl+C

### Professional Documentation 📚
"I never met a comment I did not like" - comprehensive documentation everywhere!

- **714-line ARCHITECTURE.md** with complete system diagrams
- **Inline comments throughout all scripts**
- **ASCII diagrams** showing data flow
- **utils/README.md** guide for all utilities
- Technical deep-dives and design rationale

## 📦 What's Included

### New Scripts
- `scripts/start_sdr.py` - Master startup script (Python, RECOMMENDED)
- `utils/start-sdr.bash` - Master startup script (Bash alternative)
- `utils/start-flrig.bash` - FlRig launcher with config management
- `utils/start-gqrx.bash` - GQRX launcher with config management

### New Documentation
- `docs/ARCHITECTURE.md` - Complete system architecture (714 lines)
- `utils/README.md` - Utility scripts guide

### New Configuration Files
- `config/Xiegu-G90.prefs` - FlRig configuration (FLTK format, 542 lines)
- `config/flrig.prefs` - Transceiver selection
- `config/default.prefs` - FlRig UI settings

### Enhanced Scripts
- `scripts/frequency_sync.py` - Bidirectional sync implementation
- `install.bash` - Refactored with comprehensive documentation

## 🔧 Technical Improvements

### FlRig Configuration Fix
- **Replaced broken XML config** with proper FLTK format
- FlRig now starts reliably every time
- Three-file config system for clean organization
- Reset to known-good state at each startup

### Build System Overhaul
- **Modular build scripts** prevent version mismatches
- Single source of truth for FlRig and GQRX builds
- Fixed FlRig v2.0.0 vs v2.0.9 inconsistency bug
- Consistent builds across install and rebuild

### Installation Improvements
- **Python dependencies before builds** - fail fast
- Optimized installation order
- Better error handling and status reporting
- Comprehensive inline documentation

## 📊 User Experience

### Before v0.2.5
```bash
# Three separate terminals needed
Terminal 1: bash utils/start-flrig.bash
Terminal 2: bash utils/start-gqrx.bash
Terminal 3: python3 scripts/frequency_sync.py

# GQRX could only display, not control the radio
```

### After v0.2.5
```bash
# One terminal, one command
python3 scripts/start_sdr.py

# Features:
✅ Turn G90 knob → GQRX follows
✅ Click GQRX waterfall → G90 QSYs
✅ Press Ctrl+C → Everything stops cleanly
```

## ✅ Testing Status

All features tested and verified:
- ✅ FlRig starts with correct G90 configuration
- ✅ GQRX starts with SDR configuration
- ✅ PTT control works
- ✅ G90 → GQRX frequency sync works
- ✅ **GQRX → G90 frequency sync works (NEW!)**
- ✅ Auto start/stop works correctly
- ✅ Clean shutdown handling
- ✅ Fresh install tested

## 📈 Statistics

- **23 files changed**
- **+3,431 additions**
- **-1,584 deletions**
- **714 lines** of architecture documentation
- **542 lines** of FlRig configuration
- **200+ lines** of inline comments added

## 🎓 Learning Resources

### Quick Start
1. Run fresh install: `bash install.bash`
2. Start system: `python3 scripts/start_sdr.py`
3. Use your radio normally - bidirectional sync works automatically!

### Documentation
- **ARCHITECTURE.md** - Understand how everything works
- **utils/README.md** - Learn all available utilities
- **CHANGE_LOG.md** - See complete v0.2.5 changes
- **Inline comments** - Read the source for deep understanding

## 🔄 Migration from v0.2.0

No migration needed! Everything is backward compatible.

Just pull the latest code and enjoy the new features:
```bash
cd ~/xiegu-g90-sdr
git pull
python3 scripts/start_sdr.py
```

## 🎯 Why This Is a Major Milestone

1. **First bidirectional frequency control** - Industry first for G90 panadapter
2. **Complete automation** - One command does everything
3. **Production-ready** - Tested, documented, reliable
4. **Professional quality** - Clean code, extensive docs
5. **User-friendly** - Easy to use, easy to understand

## 🙏 Acknowledgments

Special thanks to the user who said:
> "I never met a comment I did not like..."

This inspired the comprehensive documentation throughout this release!

## 📝 License

Same as G90-SDR project main license.

---

**G90-SDR v0.2.5** - Where panadapter meets perfection! 📻✨
