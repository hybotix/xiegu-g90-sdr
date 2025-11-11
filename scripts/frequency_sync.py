#!/usr/bin/env python3
# Filename: scripts/frequency_sync.py
# Synchronizes SDR++ frequency with Xiegu G90 via FlRig

import socket
import time
import logging
import threading
import signal
import sys
from typing import Optional
from rig_control import RigControl

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SDRControl:
    """Interface to control SDR++ via rigctl TCP remote control"""

    def __init__(self, host: str = '127.0.0.1', port: int = 4532):
        """
        Initialize SDR++ rigctl interface

        Args:
            host: SDR++ server IP address
            port: SDR++ rigctl port (default 4532)
        """
        self.host = host
        self.port = port
        self.sock: Optional[socket.socket] = None
        self._connected = False
    
    def connect(self) -> bool:
        """
        Connect to SDR++ rigctl interface

        Returns:
            True if connection successful, False otherwise
        """
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(5.0)
            self.sock.connect((self.host, self.port))
            self._connected = True
            logger.info(f"Connected to SDR++ at {self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to SDR++: {e}")
            self._connected = False
            return False

    def disconnect(self):
        """Disconnect from SDR++"""
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
        self.sock = None
        self._connected = False
        logger.info("Disconnected from SDR++")

    def is_connected(self) -> bool:
        """Check if connected to SDR++"""
        return self._connected and self.sock is not None
    
    def send_command(self, command: str) -> Optional[str]:
        """
        Send command to SDR++ and get response

        Args:
            command: Command string

        Returns:
            Response string or None if error
        """
        if not self.is_connected():
            logger.error("Not connected to SDR++")
            return None

        try:
            # Send command (must end with newline)
            self.sock.sendall(f"{command}\n".encode('ascii'))

            # Receive response
            response = self.sock.recv(1024).decode('ascii').strip()
            return response
        except Exception as e:
            logger.error(f"Error sending command to SDR++: {e}")
            self._connected = False
            return None
    
    def set_frequency(self, frequency: int) -> bool:
        """
        Set SDR++ frequency

        Args:
            frequency: Frequency in Hz

        Returns:
            True if successful, False otherwise
        """
        response = self.send_command(f"F {frequency}")
        if response and "RPRT 0" in response:
            logger.debug(f"Set SDR++ frequency to {frequency} Hz")
            return True
        return False

    def get_frequency(self) -> Optional[int]:
        """
        Get current SDR++ frequency

        Returns:
            Frequency in Hz, or None if error
        """
        response = self.send_command("f")
        if response:
            try:
                return int(response)
            except ValueError:
                logger.error(f"Invalid frequency response: {response}")
        return None

    def set_mode(self, mode: str) -> bool:
        """
        Set SDR++ demodulator mode

        Args:
            mode: Mode string (USB, LSB, CW, AM, FM, etc.)

        Returns:
            True if successful, False otherwise
        """
        response = self.send_command(f"M {mode}")
        if response and "RPRT 0" in response:
            logger.debug(f"Set SDR++ mode to {mode}")
            return True
        return False


class FrequencySync:
    """Synchronizes frequency between G90 and SDR++"""

    def __init__(self,
                 flrig_host: str = '127.0.0.1',
                 flrig_port: int = 12345,
                 sdr_host: str = '127.0.0.1',
                 sdr_port: int = 4532,
                 sync_interval: float = 0.5):
        """
        Initialize frequency synchronization

        Args:
            flrig_host: FlRig server address
            flrig_port: FlRig XML-RPC port
            sdr_host: SDR++ server address
            sdr_port: SDR++ rigctl port (default 4532)
            sync_interval: Sync interval in seconds (default 0.5)
        """
        self.rig = RigControl(flrig_host, flrig_port)
        self.sdr = SDRControl(sdr_host, sdr_port)
        self.sync_interval = sync_interval
        self.running = False
        self.thread: Optional[threading.Thread] = None
        # Track last known state for both rig and SDR separately
        self.last_rig_frequency = 0
        self.last_sdr_frequency = 0
        self.last_mode = ""
    
    def connect(self) -> bool:
        """
        Connect to both FlRig and SDR++

        Returns:
            True if both connections successful, False otherwise
        """
        logger.info("Connecting to FlRig and SDR++...")

        rig_ok = self.rig.connect()
        sdr_ok = self.sdr.connect()

        if rig_ok and sdr_ok:
            logger.info("✓ Connected to both FlRig and SDR++")
            return True
        else:
            if not rig_ok:
                logger.error("✗ Failed to connect to FlRig")
            if not sdr_ok:
                logger.error("✗ Failed to connect to SDR++")
            return False

    def disconnect(self):
        """Disconnect from both FlRig and SDR++"""
        self.stop()
        self.rig.disconnect()
        self.sdr.disconnect()
    
    def sync_once(self) -> bool:
        """
        Perform one bidirectional synchronization cycle

        Syncs frequency changes in both directions:
        - G90 → SDR++ (when G90 frequency changes)
        - SDR++ → G90 (when SDR++ frequency changes)

        Returns:
            True if sync successful, False otherwise
        """
        # Get current frequency and mode from both sources
        rig_frequency = self.rig.get_frequency()
        sdr_frequency = self.sdr.get_frequency()
        rig_mode = self.rig.get_mode()

        if rig_frequency is None or rig_mode is None:
            logger.warning("Could not get rig state")
            return False

        if sdr_frequency is None:
            logger.warning("Could not get SDR++ frequency")
            # Not fatal - SDR++ might not be tuned yet
            sdr_frequency = self.last_sdr_frequency

        # Detect which source changed
        rig_changed = (rig_frequency != self.last_rig_frequency)
        sdr_changed = (sdr_frequency != self.last_sdr_frequency)
        mode_changed = (rig_mode != self.last_mode)

        # Bidirectional frequency sync
        if rig_changed and sdr_changed:
            # Both changed - prioritize rig (G90 is authoritative)
            logger.info(f"Conflict detected - prioritizing G90 frequency")
            if self.sdr.set_frequency(rig_frequency):
                self.last_rig_frequency = rig_frequency
                self.last_sdr_frequency = rig_frequency
                logger.info(f"G90 → SDR++: {rig_frequency / 1e6:.6f} MHz")
            else:
                return False

        elif rig_changed:
            # G90 changed - sync to SDR++
            if self.sdr.set_frequency(rig_frequency):
                self.last_rig_frequency = rig_frequency
                self.last_sdr_frequency = rig_frequency
                logger.info(f"G90 → SDR++: {rig_frequency / 1e6:.6f} MHz")
            else:
                return False

        elif sdr_changed:
            # SDR++ changed - sync to G90
            if self.rig.set_frequency(sdr_frequency):
                self.last_sdr_frequency = sdr_frequency
                self.last_rig_frequency = sdr_frequency
                logger.info(f"SDR++ → G90: {sdr_frequency / 1e6:.6f} MHz")
            else:
                return False

        # Mode sync (only from G90 to SDR++)
        if mode_changed:
            if self.sdr.set_mode(rig_mode):
                self.last_mode = rig_mode
                logger.info(f"Synced mode: {rig_mode}")
            else:
                return False

        return True
    
    def sync_loop(self):
        """Main synchronization loop (runs in thread)"""
        logger.info("Frequency sync loop started")
        
        while self.running:
            try:
                self.sync_once()
                time.sleep(self.sync_interval)
            except Exception as e:
                logger.error(f"Error in sync loop: {e}")
                time.sleep(1.0)
        
        logger.info("Frequency sync loop stopped")
    
    def start(self) -> bool:
        """
        Start frequency synchronization thread
        
        Returns:
            True if started successfully, False otherwise
        """
        if self.running:
            logger.warning("Sync already running")
            return False

        if not self.rig.is_connected() or not self.sdr.is_connected():
            logger.error("Not connected to FlRig and/or SDR++")
            return False
        
        # Perform initial sync
        if not self.sync_once():
            logger.warning("Initial sync failed, but continuing...")
        
        # Start sync thread (non-daemon so it keeps running)
        self.running = True
        self.thread = threading.Thread(target=self.sync_loop, daemon=False)
        self.thread.start()

        logger.info("Frequency synchronization started")
        return True
    
    def stop(self):
        """Stop frequency synchronization thread"""
        if self.running:
            self.running = False
            if self.thread:
                self.thread.join(timeout=2.0)
            logger.info("Frequency synchronization stopped")


def main():
    """Test frequency synchronization"""
    print("G90-SDR Frequency Synchronization Test")
    print("=" * 50)
    
    # Create sync instance
    sync = FrequencySync(sync_interval=1.0)
    
    # Connect
    print("\nConnecting to FlRig and SDR++...")
    if not sync.connect():
        print("ERROR: Could not connect")
        print("\nMake sure:")
        print("  1. FlRig is running and connected to G90")
        print("  2. SDR++ is running with rigctl server enabled")
        return
    
    print("✓ Connected")
    
    # Start sync
    print("\nStarting frequency sync...")
    if not sync.start():
        print("ERROR: Could not start sync")
        sync.disconnect()
        return
    
    print("✓ Sync running")
    print("\nMonitoring for 30 seconds...")
    print("Change frequency on G90 to see sync in action")
    print("Press Ctrl+C to stop")
    
    try:
        # Run for 30 seconds
        for i in range(30):
            time.sleep(1)
            print(".", end="", flush=True)
    except KeyboardInterrupt:
        print("\n\nStopped by user")
    
    # Stop and disconnect
    print("\nStopping sync...")
    sync.disconnect()
    print("✓ Stopped")


def daemon_run():
    """Run frequency sync as a background daemon"""
    # Global sync instance for signal handler
    global sync_instance
    sync_instance = None

    def signal_handler(signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"Received signal {signum}, shutting down...")
        if sync_instance:
            sync_instance.disconnect()
        sys.exit(0)

    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Create sync instance
    sync_instance = FrequencySync(sync_interval=0.5)

    # Connect
    logger.info("Connecting to FlRig and SDR++...")
    if not sync_instance.connect():
        logger.error("Could not connect to FlRig and/or SDR++")
        sys.exit(1)

    logger.info("Connected to both FlRig and SDR++")

    # Start sync
    if not sync_instance.start():
        logger.error("Could not start frequency synchronization")
        sync_instance.disconnect()
        sys.exit(1)

    logger.info("Frequency synchronization running")

    # Keep running until killed
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Stopped by user")
    finally:
        sync_instance.disconnect()


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--daemon':
        daemon_run()
    else:
        main()
