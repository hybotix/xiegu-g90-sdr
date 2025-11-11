# G90-SDR Quick Reference Card

Fast reference for common commands and operations.

---

## ðŸ”§ Environment Setup

**L_SDR_DIR Environment Variable:**
```bash
# Add to ~/.bashrc:
export L_SDR_DIR=$HOME/Virtual/G90-SDR

# Apply changes:
source ~/.bashrc

# Verify it's set:
echo $L_SDR_DIR
./check_env.sh
```

All scripts use `$L_SDR_DIR` to find the installation directory.

---

## ðŸš€ Quick Start Commands

```bash
# Navigate to project (uses L_SDR_DIR)
cd $L_SDR_DIR

# Activate environment
source bin/activate

# Start system
python3 scripts/start_sdr.py

# Stop system
python3 scripts/stop_sdr.py
# OR press Ctrl+C
```

---

## ðŸ”§ Diagnostic Commands

```bash
# Complete system check
python3 tests/DiagnoseSystem.py

# Test hardware connection
python3 tests/TestConnection.py

# Test audio devices
python3 tests/TestAudio.py

# Test CAT control
python3 tests/TestCatControl.py

# Calibrate audio levels
python3 tests/CalibrateAudio.py

# Monitor device connections
python3 scripts/device_monitor.py
```

---

## ðŸ“ Important Files

```
config/g90_sdr.yaml          # Main configuration
logs/g90_sdr.log             # Application logs
requirements.txt              # Python dependencies
install.sh                    # Installation script
```

---

## ðŸŽ›ï¸ Configuration Locations

**FlRig Settings:**
- File: `config/flrig_g90.xml`
- GUI: Config â†’ Setup â†’ Transceiver

**SDR++ Settings:**
- GUI: Hamburger menu (≡) → Module Manager
- Enable rigctl_server on port 4532

**System Config:**
- File: `config/g90_sdr.yaml`
- Edit: `nano config/g90_sdr.yaml`

---

## ðŸ”Œ Hardware Troubleshooting

**Check USB Connection:**
```bash
lsusb                        # List USB devices
ls -l /dev/ttyUSB*          # List serial ports
dmesg | grep ttyUSB          # Check device messages
```

**Check Permissions:**
```bash
groups                       # Check group membership
sudo usermod -a -G dialout $USER  # Add to dialout
sudo usermod -a -G audio $USER    # Add to audio
sudo reboot                  # Reboot required
```

**Fix Serial Port:**
```bash
sudo chmod 666 /dev/ttyUSB0  # Temporary fix
```

---

## ðŸ”Š Audio Troubleshooting

**List Audio Devices:**
```bash
aplay -l                     # List playback devices
arecord -l                   # List capture devices
pactl list sinks short       # PulseAudio sinks
pactl list sources short     # PulseAudio sources
```

**Restart Audio:**
```bash
systemctl --user restart pulseaudio
```

**Check Audio Levels:**
```bash
pavucontrol                  # GUI volume control
```

---

## ðŸ“¡ FlRig Commands

**Start FlRig:**
```bash
flrig &
```

**FlRig Configuration:**
1. Config â†’ Setup â†’ Transceiver
2. Select: Xiegu G90
3. Device: /dev/ttyUSB0
4. Baud: 19200
5. Click "Init"

**Enable XML-RPC:**
1. Config â†’ Setup â†’ Server
2. Enable "Use XML-RPC"
3. Port: 12345

---


## 📺 SDR++ Commands



**Start SDR++:**
```bash
sdrpp &
```

**SDR++ Configuration:**
1. Click hamburger menu (≡)
2. Go to "Audio"
3. Select audio device
4. Sample Rate: 48000

**Enable rigctl Server:**
1. Hamburger menu (≡) → Module Manager
2. Enable "rigctl_server"
3. Port: 4532

---

## ðŸ” System Information

**Check System Status:**
```bash
# CPU usage
top

# Memory usage
free -h

# Disk usage
df -h

# Temperature
vcgencmd measure_temp

# Running processes
ps aux | grep -E 'flrig|sdrpp|python'
```

---

## ðŸ“Š Log Management

**View Logs:**
```bash
# Real-time log viewing
tail -f logs/g90_sdr.log

# View last 50 lines
tail -n 50 logs/g90_sdr.log

# Search logs
grep ERROR logs/g90_sdr.log

# Clear logs
> logs/g90_sdr.log
```

---

## ðŸ’¾ Backup and Restore

**Backup Configuration:**
```bash
tar -czf g90_backup.tar.gz config/ logs/
```

**Restore Configuration:**
```bash
tar -xzf g90_backup.tar.gz
```

**Backup Entire Project:**
```bash
cd ~
tar -czf g90_full_backup.tar.gz G90-SDR/
```

---

## âš™ï¸ Common Configuration Changes

**Change Sync Interval:**
```yaml
# Edit config/g90_sdr.yaml
sync:
  interval: 1.0  # Change from 0.5 to 1.0
```

**Change FlRig Port:**
```yaml
flrig:
  port: 12345  # Default port
```

**Change SDR++ Sample Rate:**
```yaml
sdr:
  sample_rate: 48000  # Or 96000 for higher quality
```

---

## ðŸ› Emergency Fixes

**Kill All Processes:**
```bash
pkill -9 flrig
pkill -9 sdrpp
pkill -9 -f start_sdr.py
```

**Reset Configuration:**
```bash
cd ~/G90-SDR
rm -rf config/
bash install.sh  # Recreate config
```

**Reset PulseAudio:**
```bash
systemctl --user restart pulseaudio
pulseaudio -k
pulseaudio --start
```

**Reset USB Device:**
```bash
# Unplug USB cable, wait 5 seconds, replug
# Or reset USB bus (advanced):
sudo sh -c "echo 0 > /sys/bus/usb/devices/1-1/authorized"
sudo sh -c "echo 1 > /sys/bus/usb/devices/1-1/authorized"
```

---

## ðŸ“ž Help Resources

**Documentation:**
```bash
cat README.md                # Project overview
cat INSTALL.md               # Installation guide
cat docs/USER_GUIDE.md       # User guide
cat docs/TROUBLESHOOTING.md  # Troubleshooting
```

**System Diagnostics:**
```bash
python3 tests/DiagnoseSystem.py > diagnostic.txt
cat diagnostic.txt
```

---

## ðŸŽ¯ Optimal Settings

**Audio Levels:**
- Peak: -12 to -6 dB
- RMS: -20 to -15 dB
- Headroom: 6+ dB

**Performance:**
- FFT Size: 4096 (standard) or 2048 (lower CPU)
- FFT Rate: 25 (standard) or 15 (lower CPU)
- Sample Rate: 48000 Hz

**Sync:**
- Interval: 0.5 seconds (fast) or 1.0 (slower systems)

---

## ðŸ”‘ Keyboard Shortcuts

**SDR++:**
- `F11` - Full screen
- Mouse wheel - Tune frequency
- `Shift+Mouse wheel` - Adjust zoom
- Drag waterfall - Pan view
- Right click - Context menu

**Terminal:**
- `Ctrl+C` - Stop current process
- `Ctrl+Z` - Suspend process
- `Ctrl+L` - Clear screen

---

## ðŸŒ Network Ports

```
12345  # FlRig XML-RPC server
4532   # SDR++ rigctl server
```

**Test Connectivity:**
```bash
telnet localhost 12345       # Test FlRig
telnet localhost 4532        # Test SDR++ rigctl
```

---

## ðŸ“‹ Checklist Before Use

- [ ] G90 powered on
- [ ] DE-19 connected via USB
- [ ] USB device detected (`lsusb`)
- [ ] Serial port exists (`ls /dev/ttyUSB*`)
- [ ] User in dialout group (`groups`)
- [ ] Audio device detected (`aplay -l`)
- [ ] FlRig installed (`which flrig`)
- [ ] SDR++ installed (`which sdrpp`)
- [ ] Python environment activated (`source bin/activate`)

---

## ðŸš¨ Common Error Messages

| Error | Solution |
|-------|----------|
| "Permission denied" | `sudo chmod 666 /dev/ttyUSB0` |
| "No module named..." | `pip install -r requirements.txt` |
| "Connection refused" | Start FlRig/SDR++ first |
| "Device not found" | Check USB connection |
| "Import error" | Activate venv: `source bin/activate` |

---

## ðŸ“– Quick Links

- **Installation**: `INSTALL.md`
- **User Guide**: `docs/USER_GUIDE.md`
- **Troubleshooting**: `docs/TROUBLESHOOTING.md`
- **Project Structure**: `docs/PROJECT_STRUCTURE.md`

---

## ðŸ’¡ Pro Tips

1. **Always activate venv** before running scripts
2. **Check logs first** when troubleshooting
3. **Run diagnostics** regularly
4. **Backup config** before major changes
5. **Use quality USB cables** for reliability
6. **Monitor CPU temperature** during long sessions
7. **Keep system updated** but test after updates
8. **Document custom changes** in config comments

---

**Print this card or save as bookmark for quick reference!**

**73 and happy operating! ðŸ“»âœ¨**
