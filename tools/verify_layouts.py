#!/usr/bin/env python3
"""Execute real SwiftUI layout checks on one simulator per display geometry.

Creates its own disposable simulators, uses a prebuilt test bundle, and runs
sequentially so it does not boot dozens of devices at once. Results and PNG
attachments live in build/layout-results. Does not touch personal simulators.
"""
import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--group", help="One portrait geometry, e.g. 390x844 or 1032x1376")
parser.add_argument("--windows", action="store_true", help="Run embedded viewport sweep on the largest iPad")
parser.add_argument("--gameplay", action="store_true", help="Run gameplay regression tests on the iPhone 16e geometry")
parser.add_argument("--resume", action="store_true", help="Skip groups already passed by this build")
args = parser.parse_args()
records = json.loads((ROOT / "Tests/GridZeroCoreTests/Resources/devices.json").read_text())
runtimes = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"]))["runtimes"]
runtime = next(r for r in reversed(runtimes) if r.get("isAvailable") and r.get("platform") == "iOS")
supported = {d["identifier"] for d in runtime["supportedDeviceTypes"]}
groups = {}
for record in records:
    key = f"{record['width']:g}x{record['height']:g}"
    if args.windows and (record["family"] != "iPad" or key != "1032x1376"):
        continue
    if args.gameplay and (record["family"] != "iPhone" or key != "390x844"):
        continue
    if args.group and key != args.group:
        continue
    groups.setdefault(key, []).append(record)
output = ROOT / "build/layout-results"
output.mkdir(parents=True, exist_ok=True)
summary_path = output / "summary.json"
summary = json.loads(summary_path.read_text()) if args.resume and summary_path.exists() else {}
sources = sorted((ROOT / "GridZero").rglob("*.swift")) + sorted((ROOT / "Sources").rglob("*.swift"))
sources += [ROOT / "project.yml", ROOT / "UITests/LayoutUITests.swift"]
sources += [ROOT / "GridZero/Info.plist"]
fingerprint = hashlib.sha256(b"".join(p.read_bytes() for p in sources)).hexdigest()
run_id = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")

def command(arguments, **kwargs):
    return subprocess.run(arguments, cwd=ROOT, check=True, **kwargs)

for key, models in groups.items():
    if (args.resume and summary.get(key, {}).get("result") == "Passed"
            and summary[key].get("fingerprint") == fingerprint and not args.windows and not args.gameplay):
        print(f"Already passed: {key}", flush=True)
        continue
    eligible = [m for m in models if m["identifier"] in supported]
    if not eligible:
        summary[key] = {"result": "Geometry tests only", "models": [m["name"] for m in models],
                        "reason": "No installed runtime supports this older profile; same-sized embedded viewport is checked on a 13-inch iPad."}
        summary_path.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"No compatible installed runtime: {key}", flush=True)
        continue
    model = eligible[0]
    name = f"GridZero Layout {key} {run_id}"
    device_id = subprocess.check_output(["xcrun", "simctl", "create", name, model["identifier"], runtime["identifier"]], text=True).strip()
    result_path = output / f"{key}-{run_id}.xcresult"
    log_path = output / f"{key}-{run_id}.log"
    print(f"Checking {model['name']} ({key}) on iOS {runtime['version']}", flush=True)
    try:
        with log_path.open("w") as log:
            command(["xcrun", "simctl", "boot", device_id], stdout=log, stderr=subprocess.STDOUT)
            command(["xcrun", "simctl", "bootstatus", device_id, "-b"], stdout=log, stderr=subprocess.STDOUT, timeout=180)
            test = ("GridZeroUITests" if args.gameplay else "LayoutUITests/testResizableTabletViewports" if args.windows
                    else "LayoutUITests/testPortraitAndLandscapeLayouts")
            arguments = ["xcodebuild", "-quiet", "-project", "GridZero.xcodeproj", "-scheme", "GridZero",
                         "-destination", f"platform=iOS Simulator,id={device_id}", "-derivedDataPath", "build",
                         "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
                         "-resultBundlePath", str(result_path), f"-only-testing:GridZeroUITests/{test}",
                         "CODE_SIGNING_ALLOWED=NO", "test-without-building"]
            process = subprocess.run(arguments, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=480)
        result = json.loads(subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result_path)]))
        summary[key + ("-gameplay" if args.gameplay else "-windows" if args.windows else "")] = {
            "result": result["result"], "representative": model["name"], "runtime": runtime["version"],
            "fingerprint": fingerprint,
            "models": [m["name"] for m in models], "passedTests": result["passedTests"],
            "failedTests": result["failedTests"], "resultBundle": str(result_path.relative_to(ROOT)),
            "failures": result.get("testFailures", []),
        }
        summary_path.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"  {result['result']}", flush=True)
        attachments = output / f"{key}-{run_id}-screenshots"
        command(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_path),
                 "--output-path", str(attachments)], stdout=subprocess.DEVNULL)
        if process.returncode or result["failedTests"]:
            print(f"Inspect {log_path.relative_to(ROOT)}", flush=True)
            sys.exit(1)
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", device_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "delete", device_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(f"Results: {summary_path.relative_to(ROOT)}", flush=True)
