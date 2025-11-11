#!/usr/bin/env python3
# Filename: scripts/diagnose_sdrpp.py
# Diagnose SDR++ configuration issues

import os
import json
import subprocess
import socket
from pathlib import Path

def print_header(msg):
    print("\n" + "=" * 70)
    print(f"  {msg}")
    print("=" * 70)

def check_config_files():
    """Check if SDR++ config files exist and are valid"""
    print_header("Checking SDR++ Configuration Files")

    config_dir = Path.home() / ".config" / "sdrpp"

    # Check main config
    main_config = config_dir / "config.json"
    if main_config.exists():
        print(f"✓ Main config exists: {main_config}")
        try:
            with open(main_config, 'r') as f:
                config = json.load(f)

            # Check for rigctl_server in moduleInstances
            module_instances = config.get("moduleInstances", {})
            rigctl_found = False
            for name, instance in module_instances.items():
                if instance.get("module") == "rigctl_server":
                    enabled = instance.get("enabled", False)
                    print(f"  → Found '{name}': enabled={enabled}")
                    rigctl_found = True

            if not rigctl_found:
                print("  ✗ rigctl_server NOT found in moduleInstances")
        except Exception as e:
            print(f"  ✗ Error reading config: {e}")
    else:
        print(f"✗ Main config missing: {main_config}")

    # Check rigctl_server config
    rigctl_config = config_dir / "rigctl_server_config.json"
    if rigctl_config.exists():
        print(f"✓ Rigctl config exists: {rigctl_config}")
        try:
            with open(rigctl_config, 'r') as f:
                config = json.load(f)
            print(f"  → host: {config.get('host')}")
            print(f"  → port: {config.get('port')}")
            print(f"  → autoStart: {config.get('autoStart')}")
        except Exception as e:
            print(f"  ✗ Error reading config: {e}")
    else:
        print(f"✗ Rigctl config missing: {rigctl_config}")

def check_sdrpp_process():
    """Check if SDR++ is running"""
    print_header("Checking SDR++ Process")

    try:
        result = subprocess.run(['pgrep', '-a', 'sdrpp'],
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ SDR++ is running:")
            for line in result.stdout.strip().split('\n'):
                print(f"  {line}")
        else:
            print("✗ SDR++ is NOT running")
    except Exception as e:
        print(f"✗ Error checking process: {e}")

def check_port_4532():
    """Check if port 4532 is listening"""
    print_header("Checking Port 4532 (Rigctl Server)")

    try:
        # Check with netstat or ss
        result = subprocess.run(['ss', '-lntp'],
                              capture_output=True, text=True)

        port_found = False
        for line in result.stdout.split('\n'):
            if ':4532' in line:
                print(f"✓ Port 4532 is listening:")
                print(f"  {line.strip()}")
                port_found = True

        if not port_found:
            print("✗ Port 4532 is NOT listening")
            print("  → Rigctl server may not be running")
    except Exception as e:
        print(f"⚠ Could not check ports: {e}")

    # Try to connect
    print("\nTrying to connect to localhost:4532...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex(('localhost', 4532))
        sock.close()

        if result == 0:
            print("✓ Successfully connected to port 4532")
        else:
            print(f"✗ Cannot connect to port 4532 (error code: {result})")
    except Exception as e:
        print(f"✗ Connection failed: {e}")

def check_sdrpp_logs():
    """Check SDR++ logs if available"""
    print_header("Checking for SDR++ Output")

    print("SDR++ typically logs to stdout/stderr")
    print("If started from terminal, check the terminal output")
    print("\nLooking for common issues:")
    print("  - Module loading errors")
    print("  - Port binding failures")
    print("  - Configuration warnings")

def main():
    print_header("SDR++ Diagnostic Tool")

    check_config_files()
    check_sdrpp_process()
    check_port_4532()
    check_sdrpp_logs()

    print_header("Summary")
    print("\nIf SDR++ is running but rigctl server isn't working:")
    print("  1. Check SDR++ terminal output for errors")
    print("  2. Open SDR++ → Hamburger menu → Module Manager")
    print("  3. Verify 'rigctl_server' is checked (enabled)")
    print("  4. If not enabled, enable it and restart SDR++")
    print("\nIf configs look wrong, run:")
    print("  python3 scripts/configure_sdrpp.py")
    print()

if __name__ == '__main__':
    main()
