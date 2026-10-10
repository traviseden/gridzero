#!/usr/bin/env python3
"""Install project-local Android command-line tools and the verified Gradle wrapper."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
SDK = ANDROID / ".sdk"
JAVA = Path(os.environ.get("JAVA_HOME", "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"))
assert (JAVA / "bin/java").exists(), "Install JDK 17 or set JAVA_HOME first"
SDK.mkdir(parents=True, exist_ok=True)
wrapper = ANDROID / "gradle/wrapper/gradle-wrapper.jar"
if not wrapper.exists():
    url = "https://raw.githubusercontent.com/gradle/gradle/v8.11.1/gradle/wrapper/gradle-wrapper.jar"
    data = urllib.request.urlopen(url).read()
    expected = urllib.request.urlopen("https://services.gradle.org/distributions/gradle-8.11.1-wrapper.jar.sha256").read().decode().strip()
    assert hashlib.sha256(data).hexdigest() == expected, "Gradle wrapper checksum mismatch"
    wrapper.write_bytes(data)
    print("Verified Gradle wrapper")
manager = SDK / "cmdline-tools/latest/bin/sdkmanager"
if not manager.exists():
    archive = SDK / "commandline-tools.zip"
    with urllib.request.urlopen("https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip") as response, archive.open("wb") as output:
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
subprocess.run([str(manager), f"--sdk_root={SDK}", "--licenses"], input="y\n" * 100, text=True, env=env, check=True)
subprocess.run([str(manager), f"--sdk_root={SDK}", "platforms;android-36", "build-tools;35.0.0", "platform-tools"], env=env, check=True)
(ANDROID / "local.properties").write_text(f"sdk.dir={SDK}\n")
(ANDROID / "gradlew").chmod(0o755)
print("Android SDK 36 ready; build with android/gradlew")
