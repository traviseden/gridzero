#!/usr/bin/env python3
"""Install project-local Android command-line tools and the verified Gradle wrapper."""
import hashlib
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--accept-licenses", action="store_true", help="Explicitly accept Android SDK licenses non-interactively")
args = parser.parse_args()
ANDROID = ROOT / "android"
SDK = ANDROID / ".sdk"
JAVA = Path(os.environ.get("JAVA_HOME", "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"))
if not (JAVA / "bin/java").exists():
    raise RuntimeError("Install JDK 17 or set JAVA_HOME first; use bash tools/setup_android.sh")
SDK.mkdir(parents=True, exist_ok=True)
wrapper = ANDROID / "gradle/wrapper/gradle-wrapper.jar"
expected = urllib.request.urlopen("https://services.gradle.org/distributions/gradle-8.11.1-wrapper.jar.sha256", timeout=60).read().decode().strip()
if not wrapper.exists():
    url = "https://raw.githubusercontent.com/gradle/gradle/v8.11.1/gradle/wrapper/gradle-wrapper.jar"
    data = urllib.request.urlopen(url, timeout=60).read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise RuntimeError("Gradle wrapper checksum mismatch")
    wrapper.write_bytes(data)
if hashlib.sha256(wrapper.read_bytes()).hexdigest() != expected:
    raise RuntimeError("Existing Gradle wrapper checksum mismatch; not overwriting it")
print("Verified Gradle wrapper")
manager = SDK / "cmdline-tools/latest/bin/sdkmanager"
if not manager.exists():
    archive = SDK / "commandline-tools.zip"
    with urllib.request.urlopen("https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip", timeout=60) as response, archive.open("wb") as output:
        shutil.copyfileobj(response, output)
    with zipfile.ZipFile(archive) as package:
        package.extractall(SDK / "download")
    (SDK / "cmdline-tools").mkdir(exist_ok=True)
    shutil.move(str(SDK / "download/cmdline-tools"), str(SDK / "cmdline-tools/latest"))
    shutil.rmtree(SDK / "download")
    archive.unlink()
    for executable in (SDK / "cmdline-tools/latest/bin").iterdir():
        executable.chmod(0o755)
env = dict(os.environ, JAVA_HOME=str(JAVA), ANDROID_HOME=str(SDK))
licenses = [str(manager), f"--sdk_root={SDK}", "--licenses"]
if args.accept_licenses:
    subprocess.run(licenses, input="y\n" * 100, text=True, env=env, check=True)
else:
    # Review and accept licenses in the user's terminal, not silently in an agent.
    subprocess.run(licenses, env=env, check=True)
subprocess.run([str(manager), f"--sdk_root={SDK}", "platforms;android-36", "build-tools;35.0.0", "platform-tools"], env=env, check=True)
properties = ANDROID / "local.properties"
existing = properties.read_text().splitlines() if properties.exists() else []
existing = [line for line in existing if not line.strip().startswith("sdk.dir=")]
# Java properties require escaping path backslashes / punctuation.
escaped = str(SDK).replace("\\", "\\\\").replace(":", "\\:").replace(" ", "\\ ")
properties.write_text("\n".join(existing + [f"sdk.dir={escaped}"]) + "\n")
(ANDROID / "gradlew").chmod(0o755)
print("Android SDK 36 ready; build with android/gradlew")
