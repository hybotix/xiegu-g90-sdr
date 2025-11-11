#!/usr/bin/env python3
# Filename: scripts/configure_sdrpp.py
# Auto-configure SDR++ for G90-SDR operation

import os
import json
import sys
from pathlib import Path

def print_header(msg):
    print("\n" + "=" * 70)
    print(f"  {msg}")
    print("=" * 70)

def ensure_sdrpp_config_dir():
    """Create SDR++ config directory if it doesn't exist"""
    config_dir = Path.home() / ".config" / "sdrpp"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir

def create_rigctl_server_config(config_dir):
    """Create rigctl_server configuration"""
    rigctl_config = {
        "host": "localhost",
        "port": 4532,
        "tuning": True,
        "recording": True,  # Enable recording control
        "autoStart": True,  # Auto-start on SDR++ launch (Listen on startup)
        "vfo": "",
        "recorder": ""
    }

    config_path = config_dir / "rigctl_server_config.json"

    if config_path.exists():
        print(f"✓ Rigctl server config already exists: {config_path}")
        # Load and ensure all required settings are correct
        try:
            with open(config_path, 'r') as f:
                existing = json.load(f)

            updated = False
            # Ensure all three checkboxes are enabled
            if not existing.get('tuning', False):
                existing['tuning'] = True
                updated = True
            if not existing.get('recording', False):
                existing['recording'] = True
                updated = True
            if not existing.get('autoStart', False):
                existing['autoStart'] = True
                updated = True

            if updated:
                with open(config_path, 'w') as f:
                    json.dump(existing, f, indent=2)
                print("  → Updated settings: tuning=true, recording=true, autoStart=true")
        except:
            pass
    else:
        with open(config_path, 'w') as f:
            json.dump(rigctl_config, f, indent=2)
        print(f"✓ Created rigctl server config: {config_path}")

    return True

def create_default_config(config_dir):
    """Create a minimal valid SDR++ config with rigctl_server enabled"""
    config = {
        "bandColors": {},
        "bandPlan": "General",
        "bandPlanEnabled": False,
        "centerTuning": False,
        "fftHeight": 300,
        "fftHold": False,
        "fftHoldSpeed": 60,
        "fftSize": 65536,
        "fftSmoothing": False,
        "fftSmoothingSpeed": 100,
        "fftRate": 20,
        "frequency": 100000000,
        "max": 0.0,
        "menuElements": {},
        "menuWidth": 300,
        "min": -70.0,
        "moduleInstances": {
            "Rigctl Server": {
                "module": "rigctl_server",
                "enabled": True
            }
        },
        "modules": [],
        "showMenu": True,
        "showWaterfall": True,
        "snrSmoothing": False,
        "snrSmoothingSpeed": 20,
        "source": "",
        "streams": {},
        "theme": "Dark",
        "uiScale": 1.0,
        "windowSize": {
            "h": 720,
            "w": 1280
        }
    }

    config_path = config_dir / "config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)

    print(f"✓ Created default SDR++ config: {config_path}")
    print("  → Rigctl server module pre-enabled")
    return True

def update_main_config(config_dir):
    """Update main SDR++ config to enable rigctl_server module"""
    config_path = config_dir / "config.json"

    if not config_path.exists():
        print("⚠ Main SDR++ config doesn't exist yet")
        print("  Creating default config with rigctl_server enabled...")
        return create_default_config(config_dir)

    try:
        with open(config_path, 'r') as f:
            config = json.load(f)

        # Ensure moduleInstances exists
        if "moduleInstances" not in config:
            config["moduleInstances"] = {}

        # Check if rigctl_server is already enabled
        rigctl_instance_name = None
        for name, instance in config.get("moduleInstances", {}).items():
            if instance.get("module") == "rigctl_server":
                rigctl_instance_name = name
                break

        if rigctl_instance_name:
            # Already exists, just ensure it's enabled
            config["moduleInstances"][rigctl_instance_name]["enabled"] = True
            print(f"✓ Rigctl server module already configured: '{rigctl_instance_name}'")
            print("  → Ensured it's enabled")
        else:
            # Add new instance
            config["moduleInstances"]["Rigctl Server"] = {
                "module": "rigctl_server",
                "enabled": True
            }
            print("✓ Added Rigctl Server module instance")

        # Write back
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)

        print(f"✓ Updated main config: {config_path}")
        return True

    except Exception as e:
        print(f"✗ Error updating config: {e}")
        return False

def main():
    print_header("SDR++ Auto-Configuration for G90-SDR")

    print("\nThis script configures SDR++ to:")
    print("  • Enable rigctl server module")
    print("  • Set port to 4532 (matches G90-SDR settings)")
    print("  • Auto-start rigctl server on SDR++ launch")
    print()

    # Create config directory
    print("Creating SDR++ config directory...")
    config_dir = ensure_sdrpp_config_dir()
    print(f"✓ Config directory: {config_dir}")
    print()

    # Create rigctl_server config
    print("Configuring rigctl server...")
    create_rigctl_server_config(config_dir)
    print()

    # Update or create main config
    print("Configuring main SDR++ settings...")
    success = update_main_config(config_dir)
    print()

    if success:
        print_header("Configuration Complete!")
        print()
        print("✓ SDR++ is now configured for G90-SDR")
        print()
        print("When you start SDR++:")
        print("  • Rigctl server will start automatically")
        print("  • Port 4532 is ready for frequency sync")
        print("  • No manual module enabling needed")
        print()
        print("You can now run: python3 scripts/start_sdr.py")
        print()
        return 0
    else:
        print_header("Configuration Incomplete")
        print()
        print("Please check the errors above and try again")
        return 1

if __name__ == '__main__':
    sys.exit(main())
