#!/usr/bin/env python3
"""Capture a connected Android screen via ADB, entirely from Terminal."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("device")
parser.add_argument("--output", default="build/android-device.png")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = root / args.output
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(subprocess.check_output(["adb", "-s", args.device, "exec-out", "screencap", "-p"]))
print(output)
