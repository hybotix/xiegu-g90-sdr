# Multi-Radio Support

G90-SDR now supports running multiple radios simultaneously! This allows you to:

- Run WSJT-X on one radio and JTDX on another at the same time
- Monitor multiple frequencies independently
- Control each radio with its own dedicated GQRX waterfall display
- Use different digital mode applications per radio

## Architecture

Each radio gets its own complete software stack:

```
Radio 1 (G90 #1 on /dev/ttyUSB0)          Radio 2 (G90 #2 on /dev/ttyUSB1)
    ↓                                         ↓
FlRig instance 1 (port 12345)             FlRig instance 2 (port 12346)
    ↓                                         ↓
RigControl instance 1                     RigControl instance 2
    ↓                                         ↓
├─ FrequencySync 1                        ├─ FrequencySync 2
│  └─ GQRX 1 (port 7356)                 │  └─ GQRX 2 (port 7357)
│                                         │
└─ RigctldBridge 1 (port 4532)           └─ RigctldBridge 2 (port 4533)
   └─ WSJT-X                                 └─ JTDX
```

## Configuration

Multi-radio configuration is stored in `config/radios.yaml`.

### Example Configuration

```yaml
radios:
  # Radio 1: Primary G90 for FT8 on 20m
  - name: "G90-1"
    enabled: true
    description: "Primary Xiegu G90 on USB0"
    serial_port: "/dev/ttyUSB0"
    flrig_port: 12345
    gqrx_port: 7356
    rigctld_port: 4532
    initial_frequency: 14074000  # 20m FT8
    audio:
      source: "pulse"
      sample_rate: 48000
      bandwidth: 1000000

  # Radio 2: Secondary G90 for FT8 on 40m
  - name: "G90-2"
    enabled: true
    description: "Secondary Xiegu G90 on USB1"
    serial_port: "/dev/ttyUSB1"
    flrig_port: 12346
    gqrx_port: 7357
    rigctld_port: 4533
    initial_frequency: 7076000   # 40m FT8
    audio:
      source: "pulse"
      sample_rate: 48000
      bandwidth: 1000000
```

### Port Allocation Strategy

Each radio requires **unique ports** for all services:

| Radio | FlRig | GQRX | rigctld |
|-------|-------|------|---------|
| G90-1 | 12345 | 7356 | 4532    |
| G90-2 | 12346 | 7357 | 4533    |
| G90-3 | 12347 | 7358 | 4534    |

## Usage

### Start All Enabled Radios

```bash
python3 scripts/start_sdr.py
```

This will start all radios marked with `enabled: true` in the configuration file.

### Start Specific Radio Only

```bash
python3 scripts/start_sdr.py --radio G90-1
```

This starts only the specified radio, ignoring all others.

### Skip rigctld Bridge

```bash
python3 scripts/start_sdr.py --no-rigctld
```

Starts all radios but without rigctld bridge (no HamLib support).

## Digital Mode Applications

When running multiple radios, each digital mode application needs to connect to the **correct rigctld port**.

### WSJT-X Configuration (Radio 1)

1. Open WSJT-X
2. Go to **File → Settings → Radio**
3. Set:
   - **Rig**: Hamlib NET rigctl
   - **Network Server**: `localhost`
   - **Network Port**: `4532` (Radio 1)

### JTDX Configuration (Radio 2)

1. Open JTDX
2. Go to **Settings → Radio**
3. Set:
   - **Rig**: Hamlib NET rigctl
   - **Network Server**: `localhost`
   - **Network Port**: `4533` (Radio 2)

## Current Limitations

The current multi-radio implementation has some limitations that will be addressed in future versions:

### 1. FlRig Configuration

FlRig currently uses the same startup script for all radios. To support multiple radios, you need:

- Separate FlRig configuration files per radio
- Different XML-RPC ports configured per instance
- Different serial ports per radio

**Workaround**: Manually start FlRig instances with unique configurations before running `start_sdr.py`.

### 2. GQRX Configuration

GQRX currently uses the same configuration file for all radios. To support multiple radios, you need:

- Separate GQRX config files per radio (`~/.config/gqrx/radio1.conf`, etc.)
- Different remote control ports per instance
- Different audio sources per radio (if using separate audio interfaces)

**Workaround**: Manually start GQRX instances with unique configurations before running `start_sdr.py`.

### 3. Audio Routing

When using multiple radios, you need to configure PulseAudio to route each radio's I/Q audio to the correct GQRX instance.

**Recommendations**:
- Use separate USB audio interfaces per radio
- Configure PulseAudio virtual sinks
- Use `pavucontrol` to route audio correctly

## Future Enhancements

Planned improvements for multi-radio support:

1. **FlRig Multi-Instance Management**
   - Auto-generate FlRig config files per radio
   - Launch FlRig with unique configs and ports
   - Configure serial ports from `radios.yaml`

2. **GQRX Multi-Instance Management**
   - Auto-generate GQRX config files per radio
   - Launch GQRX with unique configs and ports
   - Configure audio sources from `radios.yaml`

3. **Audio Routing Automation**
   - Auto-configure PulseAudio virtual sinks
   - Route radio audio to correct GQRX instance
   - Support for USB audio interfaces

4. **Web Dashboard**
   - Monitor all radios from single interface
   - View frequency, mode, signal strength per radio
   - Control PTT and frequency from browser

## Example Use Case

### Scenario: Dual-Band FT8 Operation

You have two Xiegu G90 radios and want to work FT8 on both 20m and 40m simultaneously.

**Hardware Setup**:
- G90 #1 on 20m → USB serial `/dev/ttyUSB0`
- G90 #2 on 40m → USB serial `/dev/ttyUSB1`
- Both radios connected to computer via USB audio

**Software Setup**:

1. Edit `config/radios.yaml`:
   ```yaml
   radios:
     - name: "G90-20m"
       enabled: true
       serial_port: "/dev/ttyUSB0"
       flrig_port: 12345
       gqrx_port: 7356
       rigctld_port: 4532
       initial_frequency: 14074000  # 20m FT8

     - name: "G90-40m"
       enabled: true
       serial_port: "/dev/ttyUSB1"
       flrig_port: 12346
       gqrx_port: 7357
       rigctld_port: 4533
       initial_frequency: 7076000   # 40m FT8
   ```

2. Start the system:
   ```bash
   python3 scripts/start_sdr.py
   ```

3. Configure WSJT-X for G90-20m (port 4532)
4. Configure JTDX for G90-40m (port 4533)

**Result**: You can now work FT8 on two bands simultaneously with independent control!

## Troubleshooting

### Port Conflicts

If you get "Address already in use" errors:

1. Check for existing processes: `netstat -tulpn | grep <port>`
2. Kill conflicting processes
3. Ensure unique ports in `config/radios.yaml`

### Serial Port Permissions

If FlRig can't access serial port:

```bash
sudo usermod -a -G dialout $USER
# Log out and log back in
```

### Audio Routing Issues

Use `pavucontrol` (PulseAudio Volume Control) to:

1. See all audio sources and sinks
2. Route radio 1 audio → GQRX 1
3. Route radio 2 audio → GQRX 2

## Questions?

For issues or questions about multi-radio support:

1. Check logs: `~tail -f ~/G90-SDR-install.log`
2. Review configuration: `config/radios.yaml`
3. Open an issue: https://github.com/yourusername/xiegu-g90-sdr/issues
