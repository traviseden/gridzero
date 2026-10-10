#!/usr/bin/env python3
"""Report APK contents and ensure GridZero has no network/native/GMS payload."""
import pathlib
import subprocess
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
apk = root / "android/app/build/outputs/apk/release/app-release.apk"
aapt = root / "android/.sdk/build-tools/35.0.0/aapt"
permissions = subprocess.check_output([str(aapt), "dump", "permissions", str(apk)], text=True)
assert "android.permission.INTERNET" not in permissions
assert "android.permission.ACCESS_NETWORK_STATE" not in permissions
with zipfile.ZipFile(apk) as package:
    names = package.namelist()
    assert not any(name.startswith("lib/") for name in names), "Unexpected native library"
    assert package.read("assets/puzzles.txt") == (root / "Sources/GridZeroCore/Resources/puzzles.txt").read_bytes()
    assert "assets/Apache-2.0.txt" in names and "assets/Puzzle-LICENSE.txt" in names
    assert not any("google/play" in name or "firebase" in name for name in names)
print(f"Release APK: {apk.stat().st_size:,} bytes ({apk.stat().st_size / 1024:.1f} KiB)")
print("No network permission, no native ABI payload, shared collection matches, licenses included")
print(permissions.strip())
