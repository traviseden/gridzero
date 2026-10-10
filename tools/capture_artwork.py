#!/usr/bin/env python3
"""Refresh real light/dark phone screenshots without opening a GUI."""
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]

def run(*args):
    return subprocess.run(args, cwd=ROOT, check=True)

device = subprocess.check_output([
    "xcrun", "simctl", "create", "GridZero Artwork",
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16e",
    "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
], text=True).strip()
try:
    run("xcrun", "simctl", "boot", device)
    run("xcrun", "simctl", "bootstatus", device, "-b")
    run("xcrun", "simctl", "status_bar", device, "override", "--time", "9:41",
        "--batteryState", "charged", "--batteryLevel", "100", "--dataNetwork", "wifi",
        "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4")
    run("xcrun", "simctl", "ui", device, "appearance", "light")
    run("xcrun", "simctl", "install", device, "build/Build/Products/Debug-iphonesimulator/GridZero.app")
    run("xcrun", "simctl", "launch", device, "win.gridzero.app")
    time.sleep(4)
    for appearance in ["light", "dark"]:
        run("xcrun", "simctl", "ui", device, "appearance", appearance)
        time.sleep(1)
        original = f"build/artwork-{appearance}.png"
        run("xcrun", "simctl", "io", device, "screenshot", original)
        run("sips", "--resampleWidth", "720", original, "--out", f"site/assets/game-{appearance}.png")
finally:
    subprocess.run(["xcrun", "simctl", "shutdown", device], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["xcrun", "simctl", "delete", device], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
