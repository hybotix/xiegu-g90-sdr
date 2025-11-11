# TODO: Dual-Receiver Radio Support

**Status**: Future Enhancement (Not Implemented)
**Priority**: Medium
**Complexity**: High

## Overview

This document outlines the architecture and requirements for supporting radios with **dual independent receivers** (dual VFOs/sub-receivers). This is different from multi-radio support, which handles multiple physical radios.

## Dual-Receiver vs Multi-Radio

### Multi-Radio (IMPLEMENTED in v0.3.0-multi)
- Multiple **physical radios** (e.g., two G90s)
- Each radio has its own serial port, FlRig instance, GQRX instance
- Completely independent operation
- No shared resources except computer

### Dual-Receiver (TODO - This Document)
- **Single physical radio** with two independent receivers
- Examples: Icom IC-7610, IC-9700, Yaesu FT-991A, Elecraft K4
- One serial port, one FlRig instance
- Two VFOs (VFO A and VFO B) controlled independently
- Shared PTT (only one VFO can transmit at a time)

## Architecture

```
Dual-Receiver Radio (e.g., IC-7610)
         │
    One Serial Port (/dev/ttyUSB0)
         │
         ▼
    FlRig Instance (port 12345)
    ├─ VFO A Control (14.074 MHz - FT8)
    └─ VFO B Control (7.076 MHz - FT8)
         │
         ├────────────────────┬─────────────────────┐
         ▼                    ▼                     ▼
    RigControl          RigControl             PTT Arbiter
    (VFO A)             (VFO B)                (Shared Resource)
         │                    │                     │
         ▼                    ▼                     │
  FrequencySync A      FrequencySync B             │
         │                    │                     │
         ▼                    ▼                     │
    GQRX A               GQRX B                     │
  (port 7356)          (port 7357)                 │
         │                    │                     │
         ▼                    ▼                     │
  RigctldBridge A      RigctldBridge B             │
  (port 4532)          (port 4533)                 │
         │                    │                     │
         ▼                    ▼                     ▼
     WSJT-X                JTDX              PTT Management
   (20m FT8)             (40m FT8)          (Prevent conflicts)
```

## Key Challenges

### 1. VFO-Aware RigControl

Current `RigControl` class assumes single VFO. Need VFO-specific methods:

```python
class DualReceiverRigControl(RigControl):
    """Extended RigControl for dual-receiver radios"""

    def get_frequency_vfo_a(self) -> int:
        """Get frequency from VFO A"""

    def get_frequency_vfo_b(self) -> int:
        """Get frequency from VFO B"""

    def set_frequency_vfo_a(self, freq: int):
        """Set frequency on VFO A"""

    def set_frequency_vfo_b(self, freq: int):
        """Set frequency on VFO B"""

    def get_active_vfo(self) -> str:
        """Get which VFO is active (A or B)"""

    def set_active_vfo(self, vfo: str):
        """Set active VFO (A or B)"""
```

### 2. PTT Arbitration

**Problem**: Two digital mode apps trying to transmit simultaneously.

**Solution**: PTT arbiter that:
- Tracks which VFO is authorized to transmit
- Queues PTT requests if conflict occurs
- Enforces mutual exclusion (only one TX at a time)
- Respects PTT timeout per VFO

```python
class PTTArbiter:
    """Manages PTT for dual-receiver radios"""

    def request_ptt(self, vfo: str, state: bool) -> bool:
        """Request PTT on specific VFO (returns True if granted)"""

    def release_ptt(self, vfo: str):
        """Release PTT on specific VFO"""

    def get_transmitting_vfo(self) -> Optional[str]:
        """Get which VFO is currently transmitting (if any)"""
```

### 3. Audio Routing

**Requirement**: Radio must output separate I/Q audio for each receiver.

**Options**:
- **Dual USB Audio**: Some radios (IC-7610) have dual USB audio devices
- **Multi-channel Audio**: Single USB device with multiple channels
- **Virtual Audio**: Use PulseAudio to split/route audio streams

**Implementation**:
```yaml
# config/radios.yaml
radios:
  - name: "IC-7610"
    type: "dual_receiver"  # NEW: Identifies dual-receiver radio
    receivers:
      - vfo: "A"
        gqrx_port: 7356
        rigctld_port: 4532
        audio:
          source: "hw:CARD=IC7610,DEV=0"  # Main receiver audio
      - vfo: "B"
        gqrx_port: 7357
        rigctld_port: 4533
        audio:
          source: "hw:CARD=IC7610,DEV=1"  # Sub receiver audio
```

### 4. FlRig VFO Support

**Challenge**: FlRig must support VFO A/B commands via XML-RPC.

**Research Needed**:
- Does FlRig expose VFO A/B separately in XML-RPC API?
- Can we read/write frequencies for both VFOs independently?
- How does FlRig handle active VFO switching?

**Possible FlRig XML-RPC Methods** (need verification):
```python
# Hypothetical - need to verify with FlRig documentation
proxy.rig.get_vfoA()
proxy.rig.get_vfoB()
proxy.rig.set_vfoA(frequency)
proxy.rig.set_vfoB(frequency)
proxy.rig.get_split()
proxy.rig.set_split(enabled)
```

### 5. Mode Coordination

**Challenge**: VFO A in USB, VFO B in CW - different modes simultaneously.

**Solution**:
- Track mode per VFO
- FrequencySync respects mode differences
- GQRX configured with appropriate mode per VFO

### 6. Frequency Sync Complexity

**Challenge**: Current FrequencySync assumes single frequency. Need to track two.

**Solution**:
```python
class DualReceiverFrequencySync:
    """Frequency sync for dual-receiver radios"""

    def __init__(self, rig: DualReceiverRigControl):
        self.rig = rig
        self.vfo_a_sync = FrequencySync(...)  # Existing FrequencySync
        self.vfo_b_sync = FrequencySync(...)

    def sync_loop(self):
        """Sync both VFOs independently"""
        while running:
            # Sync VFO A
            vfo_a_freq = self.rig.get_frequency_vfo_a()
            self.vfo_a_sync.sync(vfo_a_freq)

            # Sync VFO B
            vfo_b_freq = self.rig.get_frequency_vfo_b()
            self.vfo_b_sync.sync(vfo_b_freq)
```

## Implementation Plan

### Phase 1: Research & Design
- [ ] Research FlRig XML-RPC API for VFO A/B support
- [ ] Identify dual-receiver radios to support (IC-7610, IC-9700, K4, etc.)
- [ ] Document audio routing requirements per radio model
- [ ] Design PTTArbiter class specification
- [ ] Create test plan for dual-receiver support

### Phase 2: Core Infrastructure
- [ ] Implement `DualReceiverRigControl` class
- [ ] Implement `PTTArbiter` class
- [ ] Extend `RadioConfig` dataclass for dual-receiver radios
- [ ] Add `type: dual_receiver` to YAML configuration schema

### Phase 3: Integration
- [ ] Create `DualReceiverFrequencySync` class
- [ ] Modify `start_sdr.py` to detect dual-receiver radios
- [ ] Implement dual-receiver audio routing
- [ ] Add dual-receiver startup logic to `RadioInstance`

### Phase 4: Testing & Documentation
- [ ] Test with Icom IC-7610 (if available)
- [ ] Test with Icom IC-9700 (if available)
- [ ] Create dual-receiver user guide
- [ ] Update main documentation

## Configuration Example (Future)

```yaml
# config/radios.yaml
radios:
  # Single-receiver radio (current implementation)
  - name: "G90-1"
    type: "single_receiver"
    enabled: true
    serial_port: "/dev/ttyUSB0"
    flrig_port: 12345
    gqrx_port: 7356
    rigctld_port: 4532

  # Dual-receiver radio (future implementation)
  - name: "IC-7610"
    type: "dual_receiver"  # NEW
    enabled: true
    serial_port: "/dev/ttyUSB1"
    flrig_port: 12346

    # VFO A configuration
    receiver_a:
      vfo: "A"
      gqrx_port: 7357
      rigctld_port: 4533
      initial_frequency: 14074000  # 20m FT8
      audio:
        source: "hw:CARD=IC7610,DEV=0"

    # VFO B configuration
    receiver_b:
      vfo: "B"
      gqrx_port: 7358
      rigctld_port: 4534
      initial_frequency: 7076000   # 40m FT8
      audio:
        source: "hw:CARD=IC7610,DEV=1"
```

## Use Cases

### Use Case 1: Dual-Band FT8 (Single Radio)
**Scenario**: Work FT8 on 20m and 40m with one IC-7610

**Setup**:
- VFO A on 14.074 MHz (20m) → WSJT-X
- VFO B on 7.076 MHz (40m) → JTDX
- PTT arbiter prevents TX conflicts

**Benefit**: Same as multi-radio, but with single physical radio

### Use Case 2: Diversity Reception
**Scenario**: Receive same signal on two antennas

**Setup**:
- VFO A on 14.200 MHz (Antenna 1)
- VFO B on 14.200 MHz (Antenna 2)
- Compare signal strength and quality

### Use Case 3: Contest Operation
**Scenario**: CQ on one VFO, search-and-pounce on other

**Setup**:
- VFO A running on frequency (CQing)
- VFO B scanning for multipliers
- Quick VFO switching for contacts

### Use Case 4: Satellite Operation
**Scenario**: Full-duplex satellite communication

**Setup**:
- VFO A on uplink frequency
- VFO B on downlink frequency
- Simultaneous TX/RX tracking

## Technical Considerations

### Performance
- Two GQRX instances will use more CPU/GPU
- Two frequency sync threads running concurrently
- Increased XML-RPC traffic to single FlRig instance

### Resource Management
- Shared FlRig instance (single radio, one serial port)
- Separate GQRX instances (two waterfalls)
- PTT mutual exclusion required
- Audio routing complexity

### Error Handling
- What if VFO A fails but VFO B is working?
- PTT timeout per VFO or global?
- Recovery from PTT conflicts

## Related Documents

- `docs/MULTI_RADIO.md` - Multi-radio support (implemented)
- `scripts/rig_control.py` - Current single-VFO implementation
- `scripts/frequency_sync.py` - Current frequency sync
- `config/radios.yaml` - Radio configuration schema

## References

**Radio Documentation**:
- Icom IC-7610 Manual: Dual receiver operation
- Icom IC-9700 Manual: Dual VFO control
- Elecraft K4 Manual: Sub-receiver configuration

**Software Integration**:
- FlRig XML-RPC API documentation
- HamLib rigctld dual VFO support
- WSJT-X split operation modes

## Questions to Answer

1. Does FlRig fully support dual-receiver radios via XML-RPC?
2. How do we detect if a radio is dual-receiver vs single-receiver?
3. Should PTT timeout be per-VFO or global?
4. How to handle mode differences between VFOs (USB vs CW)?
5. Can GQRX handle dual audio streams from same radio?
6. Should we support split operation (TX on A, RX on B)?

## Future Expansion

After dual-receiver support is stable:
- Triple-receiver radios (if any exist)
- Panadapter + main receiver combinations
- Multi-mode operation (SSB on A, CW on B)
- Advanced contest macros for VFO switching

---

**Last Updated**: 2025-11-08
**Version**: Draft v1.0
**Status**: Planning/Design Phase
