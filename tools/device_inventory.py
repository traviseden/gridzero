#!/usr/bin/env python3
"""Record layout dimensions from Apple's installed simulator profiles.

Includes the iPhone 16 family and newer, iPhone Air, and every iPad profile
compatible with iPadOS 26. RAM variants share a display and are deduplicated.
This is development-time data; the app never branches on model names.
"""
import json
import pathlib
import plistlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
types = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "-j"]))["devicetypes"]
records = []
for device in types:
    name = device["name"]
    number = re.match(r"iPhone (\d+)", name)
    phone = (number and int(number[1]) >= 16) or name == "iPhone Air"
    tablet = device.get("productFamily") == "iPad" and device.get("maxRuntimeVersion", 0) >= 26 << 16
    if not (phone or tablet) or "(16GB)" in name:
        continue
    capabilities = pathlib.Path(device["bundlePath"]) / "Contents/Resources/capabilities.plist"
    with capabilities.open("rb") as stream:
        values = plistlib.load(stream)["capabilities"]
    display = next(d for d in values["displays"] if d["displayType"] == "integrated")
    scale = display["scale"]
    records.append({
        "name": name, "family": device["productFamily"], "identifier": device["identifier"],
        "pixelWidth": display["width"], "pixelHeight": display["height"], "scale": scale,
        "width": display["width"] / scale, "height": display["height"] / scale,
        "dynamicIsland": values.get("DeviceSupportsDynamicIsland", False),
        "homeButton": values.get("HomeButtonType", 2) == 1,
        "minimumOS": device["minRuntimeVersionString"],
    })
records.sort(key=lambda d: (d["family"], d["width"], d["height"], d["name"]))
destination = ROOT / "Tests/GridZeroCoreTests/Resources/devices.json"
destination.write_text(json.dumps(records, indent=2) + "\n")
lines = ["# Device layout inventory\n\n",
         "Extracted from Apple's installed CoreSimulator `capabilities.plist` profiles. "
         "Includes the iPhone 16 family and later / Air, plus all installed iPad profiles compatible with iPadOS 26. "
         "RAM variants have identical geometry and are represented once. SDK profiles may include models newer than the launch baseline.\n\n",
         "**These are physical display dimensions, not hard-coded application layouts.** "
         "GridZero uses the current window's safe-area size at runtime, including rotation, "
         "Display Zoom, and iPad window resizing. Safe-area insets vary by OS and window state.\n\n",
         "| Model | Portrait points | Native pixels | Scale | Minimum OS |\n",
         "|---|---:|---:|---:|---|\n"]
for d in records:
    lines.append(f"| {d['name']} | {d['width']:g} × {d['height']:g} | {d['pixelWidth']} × {d['pixelHeight']} | {d['scale']}× | {d['minimumOS']} |\n")
groups = {(d["family"], d["width"], d["height"]) for d in records}
lines.append(f"\n{len(records)} model profiles, {len(groups)} distinct family/display geometries.\n\n")
lines.append("## Layout behavior\n\n"
             "- Phone portrait: edge-to-edge square grid, staggered keypad below.\n"
             "- Tablet portrait / tall windows: centered square grid, capped at 720 points; keypad capped at 480 points.\n"
             "- Landscape / sufficiently wide short windows: square grid on the left, staggered keypad on the right.\n"
             "- Narrow or short windows: tighter spacing first; the grid scales down only when needed to preserve all controls.\n"
             "- Key touch targets remain at least 44 × 44 points in the tested window range. No gameplay scrolling.\n\n"
             "The inventory feeds geometry tests for every model in both orientations with conservative safe-area budgets. "
             "Additional tests sweep resizable windows and Display Zoom sizes. "
             "See `layout-verification.md` for actual simulator checks; mathematical coverage and simulator execution are recorded separately.\n")
(ROOT / "docs/device-layouts.md").write_text("".join(lines))
print(f"Recorded {len(records)} models / {len(groups)} display geometries")
for family, width, height in sorted(groups):
    print(f"  {family}: {width:g} × {height:g} points")
