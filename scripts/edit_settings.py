#!/usr/bin/env python3
# Filename: scripts/edit_settings.py
# Interactive configuration utility for G90-SDR settings

import sys
import os
import json

def load_settings():
    """Load current settings from config/settings.json"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, '..', 'config', 'settings.json')

    try:
        with open(config_path, 'r') as f:
            return json.load(f), config_path
    except FileNotFoundError:
        print("ERROR: Settings file not found!")
        print(f"Expected location: {config_path}")
        print("\nPlease run install.bash first to create the configuration.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Settings file is corrupted: {e}")
        print(f"File location: {config_path}")
        print("\nPlease fix the JSON syntax or delete the file and re-run install.bash")
        sys.exit(1)

def save_settings(settings, config_path):
    """Save settings back to config/settings.json"""
    try:
        with open(config_path, 'w') as f:
            json.dump(settings, f, indent=2)
        return True
    except Exception as e:
        print(f"ERROR: Could not save settings: {e}")
        return False

def print_header(msg):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"  {msg}")
    print("=" * 70)

def print_current_settings(settings):
    """Display current settings in a readable format"""
    print_header("Current G90-SDR Settings")
    print()

    # Startup settings
    interactive = settings.get('startup', {}).get('interactive_mode', True)
    mode_text = "Interactive" if interactive else "Automatic"
    print(f"  Startup Mode:     {mode_text}")
    if interactive:
        print("                    → start_sdr.py will pause for confirmation at each step")
    else:
        print("                    → start_sdr.py will launch everything automatically")

    print()

    # Network settings
    network = settings.get('network', {})
    print(f"  FlRig Host:       {network.get('flrig_host', '127.0.0.1')}")
    print(f"  FlRig Port:       {network.get('flrig_port', 12345)}")
    print(f"  SDR++ Host:       {network.get('sdr_host', '127.0.0.1')}")
    print(f"  SDR++ Port:       {network.get('sdr_port', 4532)}")
    print()

def configure_startup_mode(settings):
    """Configure interactive/automatic startup mode"""
    print_header("Configure Startup Mode")
    print()

    current = settings.get('startup', {}).get('interactive_mode', True)
    current_text = "I)nteractive" if current else "A)utomatic"
    print(f"Current: {current_text}")
    print()
    print("  I)nteractive (pause at each step)")
    print("  A)utomatic (launch everything)")
    print()

    while True:
        choice = input("Change to A)utomatic or I)nteractive, or Enter to keep current: ").strip()

        if not choice:  # Keep current
            print(f"Keeping current setting: {current_text}")
            return False  # No change

        if choice.lower() in ['i', 'interactive']:
            if 'startup' not in settings:
                settings['startup'] = {}
            settings['startup']['interactive_mode'] = True
            print("✓ I)nteractive mode selected")
            return True  # Changed
        elif choice.lower() in ['a', 'automatic', 'auto']:
            if 'startup' not in settings:
                settings['startup'] = {}
            settings['startup']['interactive_mode'] = False
            print("✓ A)utomatic mode selected")
            return True  # Changed
        else:
            print(f"Invalid input '{choice}' - please enter 'A' or 'I', or press Enter to keep current")
            print()

def main_menu():
    """Main configuration menu"""
    settings, config_path = load_settings()

    print_header("G90-SDR Configuration Tool")
    print()
    print("Configuration file: config/settings.json")
    print()

    while True:
        print_current_settings(settings)

        print("=" * 70)
        print()
        print("What would you like to configure?")
        print()

        # Show current startup mode
        interactive = settings.get('startup', {}).get('interactive_mode', True)
        mode_text = "I)nteractive" if interactive else "A)utomatic"
        print(f"  1) Startup behavior: {mode_text}")

        # Show current network settings
        network = settings.get('network', {})
        flrig_host = network.get('flrig_host', '127.0.0.1')
        flrig_port = network.get('flrig_port', 12345)
        sdr_host = network.get('sdr_host', '127.0.0.1')
        sdr_port = network.get('sdr_port', 4532)
        print(f"  2) Network settings: FlRig {flrig_host}:{flrig_port}, SDR++ {sdr_host}:{sdr_port}")

        print("  3) Reset to defaults")
        print("  Q) Quit")
        print()

        choice = input("Enter your choice: ").strip().lower()

        if choice == '1':
            changed = configure_startup_mode(settings)
            if changed:
                if save_settings(settings, config_path):
                    print("✓ Settings saved successfully")
                else:
                    print("✗ Failed to save settings")
            print()
            input("Press Enter to continue...")

        elif choice == '2':
            print()
            print("Network settings configuration - Coming soon!")
            print("For now, edit config/settings.json manually to change ports/hosts")
            print()
            input("Press Enter to continue...")

        elif choice == '3':
            print()
            confirm = input("Reset all settings to defaults? Y)es, or N)o: ").strip()
            if confirm.lower() in ['y', 'yes']:
                settings = {
                    "startup": {
                        "interactive_mode": True,
                        "_comment": "Set to false for automatic startup"
                    },
                    "network": {
                        "flrig_host": "127.0.0.1",
                        "flrig_port": 12345,
                        "sdr_host": "127.0.0.1",
                        "sdr_port": 4532,
                        "_comment": "Network settings for FlRig XML-RPC and SDR++ rigctl server"
                    },
                    "_info": "To change settings, run: python3 scripts/edit_settings.py (or edit this file manually)"
                }
                if save_settings(settings, config_path):
                    print("✓ Settings reset to defaults")
                else:
                    print("✗ Failed to reset settings")
            else:
                print("Reset cancelled")
            print()
            input("Press Enter to continue...")

        elif choice in ['q', 'quit', 'e', 'exit']:
            print()
            print("Configuration complete!")
            print()
            sys.exit(0)

        else:
            print()
            print(f"Invalid choice '{choice}' - please enter 1, 2, 3, or q")
            print()
            input("Press Enter to continue...")

if __name__ == '__main__':
    try:
        main_menu()
    except KeyboardInterrupt:
        print()
        print()
        print("Configuration cancelled")
        sys.exit(0)
