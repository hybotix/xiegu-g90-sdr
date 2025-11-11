# Digital Modes Configuration Guide

Complete guide for using WSJT-X, JTDX, fldigi, and other digital mode software with the G90-SDR system.

## Table of Contents
- [Overview](#overview)
- [WSJT-X Configuration](#wsjt-x-configuration)
- [JTDX Configuration](#jtdx-configuration)
- [fldigi Configuration](#fldigi-configuration)
- [Audio Setup](#audio-setup)
- [Troubleshooting](#troubleshooting)
- [PTT Safety](#ptt-safety)

---

## Overview

The G90-SDR system includes a **rigctld bridge** that provides HamLib protocol support for digital mode applications. This prevents serial port conflicts and PTT stuck issues.

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Xiegu G90 Radio                           │
└───────────────────────────┬──────────────────────────────────┘
                            │ /dev/ttyUSB0 (exclusive)
                            ↓
                     ┌──────────────┐
                     │    FlRig     │ (single serial connection)
                     │  XML-RPC     │ (proper CAT + PTT control)
                     └──────┬───────┘
                            │ port 12345
           ┌────────────────┼────────────────┐
           ↓                ↓                ↓
    ┌─────────────┐  ┌──────────┐    ┌──────────┐
    │ rigctld     │  │frequency │    │  GQRX    │
    │  bridge     │  │  _sync   │    │          │
    │ port 4532   │  │          │    │          │
    └──────┬──────┘  └──────────┘    └──────────┘
           │ HamLib protocol
    ┌──────┴────────┬─────────────┐
    ↓               ↓             ↓
┌────────┐    ┌─────────┐   ┌────────┐
│ WSJT-X │    │  JTDX   │   │ fldigi │
└────────┘    └─────────┘   └────────┘
```

### Why This Works

- **Single Serial Connection**: Only FlRig talks to the G90 directly
- **No Conflicts**: Multiple apps can use rigctld simultaneously
- **PTT Safety**: Built-in timeout prevents stuck transmit (3 minutes max)
- **Automatic Management**: rigctld starts/stops with the SDR system

---

## WSJT-X Configuration

### Prerequisites

1. Start the G90-SDR system:
   ```bash
   python3 scripts/start_sdr.py
   ```
   This automatically starts rigctld on port 4532.

2. Verify rigctld is running:
   ```
   ✓ rigctld_bridge (thread) - HamLib protocol on port 4532
   ```

### Radio Configuration

1. **Open WSJT-X** → File → Settings → Radio tab

2. **Rig Settings:**
   - **Rig:** `Hamlib NET rigctl`
   - **Network Server:** `localhost:4532`
   - **Poll Interval:** `1 second` (or `2 seconds` for slower systems)

3. **PTT Method:**
   - **PTT Method:** `CAT`
   - **Mode:** `None`
   - **Split Operation:** `None` (G90 doesn't support split)

4. **Serial Port Settings:**
   - **Serial Port:** (leave empty - using network)
   - **Baud Rate:** (ignored for network)
   - **Data Bits:** (ignored for network)
   - **Stop Bits:** (ignored for network)

5. **Click "Test CAT":**
   - You should see your current frequency displayed
   - If it works, click OK

### Audio Configuration

1. **Open WSJT-X** → File → Settings → Audio tab

2. **Input Settings:**
   - **Input:** Select your G90/DE-19 audio input device
   - **Channel:** Mono

3. **Output Settings:**
   - **Output:** Select your G90/DE-19 audio output device
   - **Channel:** Mono

4. **Test Audio:**
   - Click "Test" buttons to verify audio routing
   - Adjust levels as needed

### Operating Mode

1. **Select Mode:**
   - FT8, FT4, WSPR, etc.

2. **Set Radio Mode:**
   - WSJT-X will automatically set G90 to USB (or LSB below 10 MHz)
   - You'll see frequency changes reflected on G90 display

3. **Power Settings:**
   - Set WSJT-X power slider (typically 25-50W for FT8)
   - Set G90 power level appropriately

### Test Transmission

1. Click **Generate Std Msgs** to create CQ message
2. Click **Enable TX** checkbox
3. **IMPORTANT:** Monitor PTT behavior:
   - PTT should turn on during TX periods
   - PTT should turn off immediately after transmission
   - If PTT stays on, **STOP IMMEDIATELY** (see Troubleshooting)

---

## JTDX Configuration

JTDX is a fork of WSJT-X with enhanced features. Configuration is nearly identical:

### Radio Settings

1. **Open JTDX** → Settings → Radio

2. **Rig Configuration:**
   - **Rig:** `Hamlib NET rigctl`
   - **Network Server:** `localhost`
   - **Network Port:** `4532`
   - **Poll Interval:** `1000 ms` (or `2000 ms`)

3. **PTT Configuration:**
   - **PTT Method:** `CAT`
   - **Split:** Off (G90 doesn't support split)

4. **Test Connection:**
   - Click "Test CAT"
   - Verify frequency display updates

### Audio Configuration

Same as WSJT-X - select G90/DE-19 audio devices for input/output.

---

## fldigi Configuration

### Radio Setup

1. **Open fldigi** → Configure → Rig Control → Hardware

2. **Hamlib Settings:**
   - **Use Hamlib:** ✓ (checked)
   - **Rig:** `Hamlib NET rigctl`
   - **Device:** `localhost:4532`
   - **Retries:** `5`
   - **Retry Interval:** `50 ms`
   - **Write Delay:** `0 ms`
   - **Post Write Delay:** `0 ms`

3. **PTT Control:**
   - **PTT via Hamlib:** ✓ (checked)
   - **PTT Right Channel:** ☐ (unchecked)

4. **Commands:**
   - Use default settings

### Audio Setup

1. **Configure** → Soundcard → Devices

2. **Audio Settings:**
   - **Capture:** Select G90/DE-19 input
   - **Playback:** Select G90/DE-19 output
   - **Sample Rate:** `48000 Hz`

### Test

1. **Tune Mode:**
   - Press **Tune** button
   - PTT should activate
   - Stop tuning - PTT should release immediately

---

## Audio Setup

### PulseAudio Configuration

The G90-SDR system uses PulseAudio for audio routing. The DE-19 interface provides audio to/from the G90.

### Find Audio Devices

```bash
pactl list sources short    # List input devices
pactl list sinks short       # List output devices
```

Look for devices related to:
- DE-19 Data Interface
- USB Audio Device
- Xiegu G90

### Set Default Devices

If needed, set defaults for digital modes:

```bash
# Set default input
pactl set-default-source <source-name>

# Set default output
pactl set-default-sink <sink-name>
```

### Audio Levels

**Critical for digital modes:**

1. **Input Level:**
   - Too low: Weak decodes, poor SNR
   - Too high: Distortion, splatter
   - **Target:** -20 to -10 dBFS in WSJT-X waterfall

2. **Output Level:**
   - Too low: Weak transmissions
   - Too high: ALC activation, distortion
   - **Target:** No ALC activation on G90

3. **Adjust:**
   - Use `pavucontrol` for graphical control
   - Or `alsamixer` for command-line control

---

## Troubleshooting

### Problem: CAT Control Not Working

**Symptoms:**
- WSJT-X can't detect rig
- "Test CAT" fails
- No frequency display

**Solutions:**

1. **Verify rigctld is running:**
   ```bash
   netstat -an | grep 4532
   ```
   Should show: `0.0.0.0:4532` (LISTEN)

2. **Check FlRig connection:**
   ```bash
   # FlRig should be connected to G90
   # Check FlRig window - should show "Connected"
   ```

3. **Test rigctld manually:**
   ```bash
   telnet localhost 4532
   f              # Get frequency
   # Should return frequency in Hz
   ^]             # Exit (Ctrl+])
   quit
   ```

4. **Restart system:**
   ```bash
   python3 scripts/stop_sdr.py
   python3 scripts/start_sdr.py
   ```

### Problem: PTT Stuck in Transmit

**DANGER:** This can damage your radio and violate regulations!

**Immediate Action:**
1. **STOP TRANSMISSION IMMEDIATELY**
2. Close digital mode software
3. Stop rigctld: `python3 scripts/stop_sdr.py`
4. Turn off G90 if needed

**Prevention:**
- rigctld has built-in 3-minute PTT timeout
- Always monitor PTT during first test transmissions
- Use low power for testing

**Diagnosis:**
1. Check FlRig PTT control works:
   - Open FlRig
   - Click PTT button
   - Radio should transmit
   - Release - should return to receive

2. Check WSJT-X settings:
   - PTT Method must be "CAT"
   - Not "VOX" or "DTR"

3. Check for conflicts:
   ```bash
   # Only one app should use serial port
   lsof | grep ttyUSB0
   # Should only show FlRig
   ```

### Problem: No Audio

**Check:**

1. **Audio device selection:**
   - WSJT-X → Settings → Audio
   - Verify correct input/output devices

2. **PulseAudio:**
   ```bash
   pavucontrol
   ```
   - Check "Recording" tab during RX
   - Check "Playback" tab during TX

3. **GQRX interference:**
   - GQRX also uses audio input
   - Usually not a problem (PulseAudio handles sharing)
   - If issues, stop GQRX temporarily

### Problem: rigctld Won't Start

**Check:**

1. **Port already in use:**
   ```bash
   sudo netstat -tulpn | grep 4532
   ```
   If another process is using port 4532, stop it.

2. **FlRig not running:**
   - rigctld requires FlRig
   - Start SDR system properly:
     ```bash
     python3 scripts/start_sdr.py
     ```

3. **Python dependencies:**
   ```bash
   source bin/activate
   pip list | grep xmlrpc
   ```

---

## PTT Safety

### Built-in Protections

The rigctld bridge includes multiple safety features:

1. **PTT Timeout:**
   - Maximum TX time: 3 minutes
   - Automatic PTT release after timeout
   - Logged warning message

2. **Graceful Shutdown:**
   - Ctrl+C releases PTT
   - `stop_sdr.py` releases PTT
   - Emergency shutdown forces PTT off

3. **Error Handling:**
   - PTT errors force PTT off
   - Connection loss releases PTT

### Best Practices

1. **Testing:**
   - Use low power for initial tests
   - Monitor PTT LED on G90
   - Verify PTT releases between transmissions

2. **Operating:**
   - Don't leave unattended during TX
   - Monitor for errors in terminal
   - Have emergency stop ready (Ctrl+C or power off)

3. **Emergencies:**
   - If PTT stuck: Stop all software immediately
   - If still stuck: Turn off G90
   - Investigate cause before resuming

### PTT Monitoring

Watch terminal output for PTT activity:

```
[INFO] PTT ON - Transmitting
[INFO] PTT OFF - Receiving (TX duration: 15.2s)
```

If you see:
```
[WARNING] PTT timeout! (180.0s > 180s)
[WARNING] Forcing PTT OFF for safety
```

**This is abnormal** - investigate before continuing.

---

## Multi-Application Support (v0.3.1)

**Coming soon:** Multiple applications can connect to rigctld simultaneously!

Current status (v0.3.0):
- One digital mode app at a time
- GQRX works alongside digital modes
- FlRig can be controlled directly (advanced users)

Future (v0.3.1):
- Run WSJT-X and fldigi simultaneously
- Independent frequency/mode control
- Cooperative PTT management

---

## Summary

### Quick Start

1. **Start SDR system:**
   ```bash
   python3 scripts/start_sdr.py
   ```

2. **Configure WSJT-X:**
   - Rig: `Hamlib NET rigctl`
   - Server: `localhost:4532`
   - PTT: `CAT`

3. **Test CAT control**

4. **Configure audio devices**

5. **Test with low power**

6. **Operate!**

### Support

For issues:
- Check troubleshooting section above
- Check rigctld logs in terminal
- Report issues with logs

### Safety First

- **Monitor PTT behavior**
- **Use low power for testing**
- **Have emergency stop ready**
- **Don't leave unattended during TX**

---

**G90-SDR v0.3.0** - Digital modes done right! 📻✨
