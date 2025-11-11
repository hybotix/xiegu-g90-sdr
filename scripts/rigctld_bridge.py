#!/usr/bin/env python3
# Filename: scripts/rigctld_bridge.py
# HamLib rigctld protocol bridge to FlRig XML-RPC
#
# Copyright (c) 2025 G90-SDR Contributors
# Licensed under the MIT License - see LICENSE file for details
#
#═══════════════════════════════════════════════════════════════════════════════
# PURPOSE: Allow WSJT-X, JTDX, fldigi, and other HamLib apps to control G90
#═══════════════════════════════════════════════════════════════════════════════
#
# THE PROBLEM THIS SOLVES:
# - Multiple applications trying to access G90 serial port → conflicts
# - Direct HamLib access → PTT stuck in transmit (dangerous!)
# - No coordination between apps → frequency jumps, mode changes
#
# THE SOLUTION:
# This script acts as a rigctld server that translates HamLib protocol
# commands into FlRig XML-RPC calls. FlRig maintains the single connection
# to the G90, preventing serial port conflicts and PTT issues.
#
# ARCHITECTURE:
#
#   ┌──────────────────────────────────────────────────────────────┐
#   │                    Xiegu G90 Radio                           │
#   └───────────────────────────┬──────────────────────────────────┘
#                               │ /dev/ttyUSB0 (exclusive)
#                               ↓
#                        ┌──────────────┐
#                        │    FlRig     │ (single serial connection)
#                        │  XML-RPC     │ (proper CAT + PTT control)
#                        └──────┬───────┘
#                               │ port 12345
#              ┌────────────────┼────────────────┐
#              ↓                ↓                ↓
#       ┌─────────────┐  ┌──────────┐    ┌──────────┐
#       │ rigctld     │  │frequency │    │  GQRX    │
#       │  bridge     │  │  _sync   │    │ (direct) │
#       │ port 4532   │  │          │    │          │
#       └──────┬──────┘  └──────────┘    └──────────┘
#              │ HamLib protocol
#       ┌──────┴────────┬─────────────┐
#       ↓               ↓             ↓
#   ┌────────┐    ┌─────────┐   ┌────────┐
#   │ WSJT-X │    │  JTDX   │   │ fldigi │
#   └────────┘    └─────────┘   └────────┘
#
# HAMLIB PROTOCOL:
# rigctld uses a simple text-based protocol over TCP:
#   Client sends: "f\n"          (get frequency)
#   Server responds: "14074000\n" (frequency in Hz)
#
#   Client sends: "F 14074000\n" (set frequency)
#   Server responds: "RPRT 0\n"  (success)
#
#   Client sends: "t 1\n"        (PTT on)
#   Server responds: "RPRT 0\n"  (success)
#
# SUPPORTED COMMANDS:
# - f / F : Get/Set frequency
# - m / M : Get/Set mode
# - t / T : Get/Set PTT
# - v / V : Get/Set VFO
# - s / S : Get/Set split
# - l / L : Get/Set power level
#
# PTT SAFETY:
# - Timeout on PTT (max 3 minutes, then auto-release)
# - PTT state monitoring
# - Graceful shutdown releases PTT
#
# USAGE:
#   python3 scripts/rigctld_bridge.py
#
# CONFIGURE WSJT-X:
#   File → Settings → Radio
#     Rig: Hamlib NET rigctl
#     Network Server: localhost:4532
#     PTT Method: CAT
#     Mode: USB (or data/USB for digital)
#
# CONFIGURE JTDX:
#   Settings → Radio
#     Rig: Hamlib NET rigctl
#     Network Server: localhost
#     Network Port: 4532
#     PTT via CAT
#

import socket
import threading
import time
import logging
import argparse
import sys
from typing import Optional, Dict, Tuple
from rig_control import RigControl

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RigctldBridge:
    """
    HamLib rigctld protocol bridge to FlRig XML-RPC

    Implements rigctld server that translates HamLib commands
    to FlRig XML-RPC calls, preventing serial port conflicts
    and PTT stuck issues.
    """

    def __init__(self,
                 host: str = '0.0.0.0',
                 port: int = 4532,
                 flrig_host: str = '127.0.0.1',
                 flrig_port: int = 12345,
                 rig_control: Optional[RigControl] = None):
        """
        Initialize rigctld bridge

        Args:
            host: Interface to bind to (0.0.0.0 = all interfaces)
            port: rigctld port (default 4532, standard HamLib port)
            flrig_host: FlRig XML-RPC server address
            flrig_port: FlRig XML-RPC port (default 12345)
            rig_control: Optional existing RigControl instance to share
                        (prevents multiple FlRig connections)
        """
        self.host = host
        self.port = port

        # Use provided RigControl or create new one
        if rig_control:
            self.rig = rig_control
            self.owns_rig = False  # Don't disconnect on cleanup
            logger.info("Using shared RigControl instance")
        else:
            self.rig = RigControl(flrig_host, flrig_port)
            self.owns_rig = True  # We created it, we clean it up
            logger.info("Created new RigControl instance")

        self.server_socket: Optional[socket.socket] = None
        self.running = False
        self.server_thread: Optional[threading.Thread] = None

        # PTT safety
        self.ptt_on_time: Optional[float] = None
        self.ptt_timeout = 180  # 3 minutes max PTT time
        self.ptt_monitor_thread: Optional[threading.Thread] = None

        # Mode mapping: HamLib mode names → FlRig mode names
        self.mode_map = {
            'USB': 'USB',
            'LSB': 'LSB',
            'CW': 'CW',
            'CWR': 'CW-R',
            'AM': 'AM',
            'FM': 'FM',
            'RTTY': 'RTTY',
            'RTTYR': 'RTTY-R',
            'PKTUSB': 'USB',  # Data modes use USB
            'PKTLSB': 'LSB',
        }

        # Reverse mapping for get_mode
        self.mode_map_reverse = {v: k for k, v in self.mode_map.items()}

    def connect_to_rig(self) -> bool:
        """
        Connect to FlRig (only if we own the RigControl instance)

        Returns:
            True if connected, False otherwise
        """
        # If using shared RigControl, assume it's already connected
        if not self.owns_rig:
            if self.rig.is_connected():
                logger.info("Using existing FlRig connection")
                return True
            else:
                logger.error("Shared RigControl is not connected")
                return False

        # We own the RigControl, so connect it
        logger.info("Connecting to FlRig...")
        if not self.rig.connect():
            logger.error("Failed to connect to FlRig")
            return False

        logger.info("Connected to FlRig")
        return True

    def start(self) -> bool:
        """
        Start rigctld bridge server

        Returns:
            True if started successfully, False otherwise
        """
        if self.running:
            logger.warning("Bridge already running")
            return False

        if not self.connect_to_rig():
            return False

        # Create server socket
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)

            logger.info(f"rigctld bridge listening on {self.host}:{self.port}")

        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            return False

        # Start server thread
        self.running = True
        self.server_thread = threading.Thread(target=self._server_loop, daemon=True)
        self.server_thread.start()

        # Start PTT monitor thread
        self.ptt_monitor_thread = threading.Thread(target=self._ptt_monitor_loop, daemon=True)
        self.ptt_monitor_thread.start()

        logger.info("rigctld bridge started successfully")
        return True

    def stop(self):
        """Stop rigctld bridge server"""
        if not self.running:
            return

        logger.info("Stopping rigctld bridge...")

        self.running = False

        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
            self.server_socket = None

        # Wait for threads
        if self.server_thread:
            self.server_thread.join(timeout=2.0)
        if self.ptt_monitor_thread:
            self.ptt_monitor_thread.join(timeout=2.0)

        # Ensure PTT is off
        try:
            self._set_ptt(False)
        except:
            pass

        # Disconnect from FlRig
        self.rig.disconnect()

        logger.info("rigctld bridge stopped")

    def _server_loop(self):
        """Main server loop - accepts client connections"""
        logger.info("Server loop started")

        while self.running:
            try:
                # Accept connection with timeout
                self.server_socket.settimeout(1.0)

                try:
                    client_socket, client_addr = self.server_socket.accept()
                except socket.timeout:
                    continue

                logger.info(f"Client connected from {client_addr}")

                # Handle client in separate thread
                client_thread = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket, client_addr),
                    daemon=True
                )
                client_thread.start()

            except Exception as e:
                if self.running:
                    logger.error(f"Error in server loop: {e}")
                    time.sleep(1.0)

        logger.info("Server loop stopped")

    def _handle_client(self, client_socket: socket.socket, client_addr: Tuple):
        """
        Handle a single client connection

        Args:
            client_socket: Client socket
            client_addr: Client address
        """
        try:
            client_socket.settimeout(30.0)

            while self.running:
                # Receive command
                data = client_socket.recv(1024)
                if not data:
                    break

                command = data.decode('ascii').strip()
                if not command:
                    continue

                logger.debug(f"Received command from {client_addr}: {command}")

                # Process command
                response = self._process_command(command)

                # Send response
                if response:
                    client_socket.sendall(f"{response}\n".encode('ascii'))
                    logger.debug(f"Sent response to {client_addr}: {response}")

        except Exception as e:
            logger.error(f"Error handling client {client_addr}: {e}")

        finally:
            try:
                client_socket.close()
            except:
                pass
            logger.info(f"Client disconnected: {client_addr}")

    def _process_command(self, command: str) -> Optional[str]:
        """
        Process a HamLib command

        Args:
            command: HamLib command string

        Returns:
            Response string or None
        """
        parts = command.split()
        if not parts:
            return "RPRT -1"  # Invalid command

        cmd = parts[0]  # Keep original case for command matching

        try:
            # Get frequency
            if cmd == 'f':
                freq = self.rig.get_frequency()
                if freq is not None:
                    return str(int(freq))
                return "RPRT -1"

            # Set frequency
            elif cmd == 'F':
                if len(parts) < 2:
                    return "RPRT -1"
                # WSJT-X sends frequency as float (e.g., '14074055.000000')
                # Convert to int Hz for FlRig
                freq = int(float(parts[1]))
                if self.rig.set_frequency(freq):
                    return "RPRT 0"
                return "RPRT -1"

            # Get mode
            elif cmd == 'm':
                mode = self.rig.get_mode()
                if mode:
                    hamlib_mode = self.mode_map_reverse.get(mode, 'USB')
                    return f"{hamlib_mode}\n0"  # mode and passband (0 = default)
                return "RPRT -1"

            # Set mode
            elif cmd == 'M':
                if len(parts) < 2:
                    return "RPRT -1"
                hamlib_mode = parts[1].upper()
                flrig_mode = self.mode_map.get(hamlib_mode, 'USB')
                if self.rig.set_mode(flrig_mode):
                    return "RPRT 0"
                return "RPRT -1"

            # Get PTT
            elif cmd == 't':
                ptt = self.rig.get_ptt()
                if ptt is not None:
                    return str(1 if ptt else 0)
                return "RPRT -1"

            # Set PTT
            elif cmd == 'T':
                if len(parts) < 2:
                    return "RPRT -1"
                ptt = int(parts[1])
                if self._set_ptt(ptt == 1):
                    return "RPRT 0"
                return "RPRT -1"

            # Get VFO
            elif cmd == 'v':
                return "VFOA"  # G90 uses single VFO

            # Set VFO
            elif cmd == 'V':
                return "RPRT 0"  # Accept but ignore (G90 single VFO)

            # Get split
            elif cmd == 's':
                return "0\nVFOA"  # No split

            # Set split
            elif cmd == 'S':
                return "RPRT 0"  # Accept but ignore (no split support)

            # Dump state (info request)
            elif cmd == '\\dump_state':
                return self._dump_state()

            # Get power status (WSJT-X compatibility)
            elif cmd == '\\get_powerstat':
                return "1"  # 1 = Power ON

            # Check VFO (WSJT-X compatibility)
            elif cmd == '\\chk_vfo':
                return "RPRT 0"  # VFO check OK

            # Quit/disconnect (WSJT-X sends this on close)
            elif cmd == 'q' or cmd == 'Q':
                return "RPRT 0"  # Acknowledge quit

            # Unknown command
            else:
                logger.warning(f"Unknown command: {command}")
                return "RPRT -1"

        except Exception as e:
            logger.error(f"Error processing command '{command}': {e}")
            return "RPRT -1"

    def _set_ptt(self, state: bool) -> bool:
        """
        Set PTT state with safety monitoring

        Args:
            state: True for PTT on, False for PTT off

        Returns:
            True if successful, False otherwise
        """
        try:
            if state:
                # PTT ON - start timing for safety monitoring
                if self.rig.set_ptt(True):
                    self.ptt_on_time = time.time()
                    logger.info("PTT ON - Transmitting")
                    return True
                else:
                    logger.error("Failed to set PTT ON")
                    return False
            else:
                # PTT OFF - calculate duration and release
                if self.rig.set_ptt(False):
                    if self.ptt_on_time:
                        duration = time.time() - self.ptt_on_time
                        logger.info(f"PTT OFF - Receiving (TX duration: {duration:.1f}s)")
                    else:
                        logger.info("PTT OFF - Receiving")
                    self.ptt_on_time = None
                    return True
                else:
                    logger.error("Failed to set PTT OFF")
                    return False

        except Exception as e:
            logger.error(f"Error setting PTT: {e}")
            # On error, attempt to force PTT off for safety
            try:
                self.rig.set_ptt(False)
                self.ptt_on_time = None
            except:
                pass
            return False

    def _ptt_monitor_loop(self):
        """Monitor PTT and enforce timeout"""
        logger.info("PTT monitor started")

        while self.running:
            try:
                if self.ptt_on_time:
                    duration = time.time() - self.ptt_on_time

                    if duration > self.ptt_timeout:
                        logger.warning(f"PTT timeout! ({duration:.1f}s > {self.ptt_timeout}s)")
                        logger.warning("Forcing PTT OFF for safety")
                        self._set_ptt(False)

                time.sleep(1.0)

            except Exception as e:
                logger.error(f"Error in PTT monitor: {e}")
                time.sleep(1.0)

        logger.info("PTT monitor stopped")

    def _dump_state(self) -> str:
        """
        Return rigctld state dump (for HamLib protocol negotiation)

        Returns:
            State dump string
        """
        return """0
2
2
150000.000000 30000000.000000 0x1ff -1 -1 0x10000003 0x3
0 0 0 0 0 0 0
150000.000000 30000000.000000 0x1ff -1 -1 0x10000003 0x3
0 0 0 0 0 0 0
0 0
0 0
0x1ff 1
0x1ff 0
0 0
0x1e 2400
0x2 500
0x1 8000
0x1 2400
0x20 15000
0x20 8000
0x40 230000
0 0
9990
9990
10000
0
10
10
10000
1
1
1
0
0
0
"""


def main():
    """Run rigctld bridge as a standalone process"""
    parser = argparse.ArgumentParser(
        description='G90-SDR rigctld Bridge (HamLib Protocol)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
This provides HamLib rigctld protocol for G90 control.
Compatible with: WSJT-X, JTDX, fldigi, and other HamLib apps

Examples:
  python3 scripts/rigctld_bridge.py
  python3 scripts/rigctld_bridge.py --port 4533
  python3 scripts/rigctld_bridge.py --flrig-port 12346 --port 4533

Configure WSJT-X:
  Radio: Hamlib NET rigctl
  Network Server: localhost:4532
  PTT Method: CAT
        '''
    )
    parser.add_argument('--host', default='0.0.0.0', help='Interface to bind to (default: 0.0.0.0 = all)')
    parser.add_argument('--port', type=int, default=4532, help='rigctld server port (default: 4532)')
    parser.add_argument('--flrig-host', default='127.0.0.1', help='FlRig XML-RPC host (default: 127.0.0.1)')
    parser.add_argument('--flrig-port', type=int, default=12345, help='FlRig XML-RPC port (default: 12345)')
    parser.add_argument('--quiet', action='store_true', help='Suppress informational output')

    args = parser.parse_args()

    if not args.quiet:
        print("G90-SDR rigctld Bridge")
        print("=" * 60)
        print(f"Listen:  {args.host}:{args.port}")
        print(f"FlRig:   {args.flrig_host}:{args.flrig_port}")
        print()

    # Create bridge with CLI arguments
    bridge = RigctldBridge(
        host=args.host,
        port=args.port,
        flrig_host=args.flrig_host,
        flrig_port=args.flrig_port
    )

    # Start bridge
    if not args.quiet:
        print("Starting rigctld bridge...")
    if not bridge.start():
        print("ERROR: Could not start bridge")
        print("\nMake sure:")
        print(f"  1. FlRig is running on {args.flrig_host}:{args.flrig_port}")
        print(f"  2. Port {args.port} is not already in use")
        return 1

    if not args.quiet:
        print(f"✓ rigctld bridge running on {args.host}:{args.port}")
        print("\nNow configure WSJT-X/JTDX:")
        print("  Radio: Hamlib NET rigctl")
        print(f"  Network Server: localhost:{args.port}")
        print("  PTT Method: CAT")
        print()
        print("Press Ctrl+C to stop")
        print()

    try:
        # Run until interrupted
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        if not args.quiet:
            print("\n\nStopped by user")

    # Stop bridge
    if not args.quiet:
        print("\nStopping bridge...")
    bridge.stop()
    if not args.quiet:
        print("✓ Stopped")

    return 0


if __name__ == '__main__':
    sys.exit(main())
