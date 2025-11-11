#!/usr/bin/env python3
# Filename: scripts/safe_start.py
# Safe startup with audio device checking and recovery

import sys
import os
import subprocess
import time
import json

sys.path.insert(0, os.path.dirname(__file__))

def load_settings():
    """Load user settings from config/settings.json"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, '..', 'config', 'settings.json')

    # Default settings if file doesn't exist
    defaults = {
        "startup": {"interactive_mode": True},
        "network": {
            "flrig_host": "127.0.0.1",
            "flrig_port": 12345,
            "sdr_host": "127.0.0.1",
            "sdr_port": 4532
        }
    }

    try:
        with open(config_path, 'r') as f:
            settings = json.load(f)
            # Merge with defaults for any missing keys
            for key in defaults:
                if key not in settings:
                    settings[key] = defaults[key]
            return settings
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"⚠ Could not load settings: {e}")
        print(f"  Using default settings")
        return defaults

def print_header(msg):
    print("\n" + "=" * 60)
    print(f"  {msg}")
    print("=" * 60)

def check_audio_available():
    """Check if audio device is available"""
    try:
        result = subprocess.run(['fuser', '/dev/snd/pcmC0D0c'], 
                              capture_output=True, text=True)
        if result.stdout.strip():
            print("⚠ Audio device in use by:")
            print(result.stdout)
            return False
        return True
    except:
        return True  # Assume available if can't check

def reset_audio():
    """Reset PulseAudio"""
    print("\nResetting audio system...")
    try:
        subprocess.run(['systemctl', '--user', 'restart', 'pulseaudio'],
                      capture_output=True)
        time.sleep(2)
        print("✓ Audio system reset")
        return True
    except Exception as e:
        print(f"✗ Could not reset audio: {e}")
        return False

def kill_existing():
    """Kill any existing instances"""
    print("\nCleaning up existing processes...")
    for proc in ['sdrpp', 'flrig', 'start_sdr']:
        try:
            subprocess.run(['pkill', '-9', proc],
                         stderr=subprocess.DEVNULL)
        except:
            pass
    time.sleep(1)
    print("✓ Cleanup complete")

def main():
    # Load user settings
    settings = load_settings()
    interactive = settings.get('startup', {}).get('interactive_mode', True)

    if not interactive:
        print("Running in automatic mode (no prompts)")

    print_header("G90-SDR Safe Startup")

    print("\nThis script performs safety checks before starting.")

    # Step 1: Kill existing
    kill_existing()
    
    # Step 2: Check audio
    print_header("Audio Device Check")
    if not check_audio_available():
        print("\n⚠ Audio device is in use!")
        if interactive:
            response = input("Try to reset audio? (y/n): ")
            should_reset = response.lower() == 'y'
        else:
            print("Attempting to reset audio automatically...")
            should_reset = True

        if should_reset:
            if not reset_audio():
                print("\n✗ Could not reset audio")
                if interactive:
                    print("Please close other audio applications and try again")
                    return 1
                else:
                    print("Continuing anyway (automatic mode)...")
        else:
            print("Proceeding anyway...")
    else:
        print("✓ Audio device available")
    
    # Step 3: Verify files exist
    print_header("File Check")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    required = ['rig_control.py', 'frequency_sync.py']
    
    for file in required:
        path = os.path.join(script_dir, file)
        if os.path.exists(path):
            print(f"✓ {file}")
        else:
            print(f"✗ {file} missing!")
            return 1
    
    # Step 4: Start FlRig manually
    print_header("Starting FlRig")
    print("\n1. FlRig will open")
    print("2. Wait for it to connect to G90")
    print("3. Ensure 'Connected' status is shown")

    if interactive:
        input("\nPress Enter to start FlRig...")
    else:
        print("\nStarting FlRig automatically...")
    
    try:
        flrig_proc = subprocess.Popen(['flrig'], 
                                     stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)
        print("✓ FlRig started (PID: {})".format(flrig_proc.pid))
        print("\nWaiting 5 seconds for FlRig to initialize...")
        time.sleep(5)
    except Exception as e:
        print(f"✗ Could not start FlRig: {e}")
        return 1
    
    # Verify FlRig is running
    try:
        from rig_control import RigControl
        rig = RigControl()
        if rig.connect():
            print("✓ FlRig is responding")
            rig.disconnect()
        else:
            print("⚠ FlRig not responding yet")
            if interactive:
                print("  Wait a moment and check FlRig shows 'Connected'")
                input("  Press Enter when FlRig is connected...")
            else:
                print("  Continuing anyway (automatic mode)...")
    except Exception as e:
        print(f"⚠ Could not verify FlRig: {e}")
    
    # Step 5: Start SDR++
    print_header("Starting SDR++")
    print("\nSDR++ is pre-configured with:")
    print("  ✓ Rigctl server enabled (port 4532)")
    print("  ✓ Auto-start on launch")
    print("\nSDR++ will open and be ready for frequency sync")

    if interactive:
        input("\nPress Enter to start SDR++...")
    else:
        print("\nStarting SDR++ automatically...")

    try:
        sdrpp_proc = subprocess.Popen(['sdrpp'],
                                     stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)
        print("✓ SDR++ started (PID: {})".format(sdrpp_proc.pid))
        print("\nWaiting 8 seconds for SDR++ to initialize...")
        time.sleep(8)
        print("✓ SDR++ should be ready (rigctl server auto-started)")
    except Exception as e:
        print(f"✗ Could not start SDR++: {e}")
        return 1
    
    # Step 6: Start frequency sync
    print_header("Starting Frequency Sync")

    print("Starting frequency synchronization daemon...")
    print("Waiting 2 seconds for FlRig and SDR++ to stabilize...")
    time.sleep(2)

    try:
        # Launch frequency_sync.py as a background daemon process
        sync_script = os.path.join(script_dir, 'frequency_sync.py')
        sync_proc = subprocess.Popen(
            ['python3', sync_script, '--daemon'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        print(f"✓ Frequency sync started (PID: {sync_proc.pid})")

        # Give it a moment to connect
        time.sleep(2)

        # Check if it's still running
        if sync_proc.poll() is not None:
            print("✗ Frequency sync failed to start")
            print("  Check that FlRig and SDR++ are running")
            print("  Run 'python3 scripts/frequency_sync.py' manually to diagnose")
            return 1

    except Exception as e:
        print(f"✗ Could not start frequency sync: {e}")
        return 1

    print_header("System Running")
    print("\n✓ All components started successfully!")
    print("\nRunning processes:")
    print("  - FlRig (rig control)")
    print("  - SDR++ (spectrum display)")
    print("  - frequency_sync (bidirectional sync)")
    print("\nYou can now:")
    print("  - Tune the G90 → SDR++ follows")
    print("  - Click SDR++ waterfall → G90 tunes")
    print("  - Use FlRig to control the radio")
    print(f"\nTo stop everything: python3 scripts/stop_sdr.py")
    print("Or use: pkill -f 'flrig|sdrpp|frequency_sync'")

    return 0

if __name__ == '__main__':
    sys.exit(main())
