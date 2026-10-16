"""Exercise the Android helper without installing SDKs or touching a phone."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class AndroidHelperTests(unittest.TestCase):
    def setUp(self):
        (ROOT / "build").mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="gridzero-helper-", dir=ROOT / "build")
        self.root = Path(self.temporary.name)
        (self.root / "tools").mkdir()
        shutil.copyfile(ROOT / "tools/android.sh", self.root / "tools/android.sh")
        self.android = self.root / "android"
        self.java = self.root / "jdk"
        self.sdk = self.android / ".sdk"
        self.log = self.root / "commands.txt"
        for directory in [self.java / "bin", self.sdk / "platform-tools", self.sdk / "build-tools/35.0.0"]:
            directory.mkdir(parents=True)
        self.executable(self.java / "bin/java", "exit 0")
        self.executable(self.sdk / "platform-tools/adb", '''
printf '%s\\n' "$*" >> "$TEST_LOG"
case "$*" in
  *"install -r"*) exit "${TEST_INSTALL_EXIT:-0}" ;;
  *"get-state"*) echo device ;;
esac
''')
        self.executable(self.sdk / "build-tools/35.0.0/apksigner", 'printf "signer %s\\n" "$*" >> "$TEST_LOG"')
        self.executable(self.android / "gradlew", '''
printf 'gradle %s\\n' "$*" >> "$TEST_LOG"
mkdir -p "$TEST_ANDROID/app/build/outputs/apk/release" "$TEST_ANDROID/app/build/outputs/bundle/release"
touch "$TEST_ANDROID/app/build/outputs/apk/release/app-release.apk" "$TEST_ANDROID/app/build/outputs/bundle/release/app-release.aab"
''')
        (self.android / "env.local.sh").write_text(f'export JAVA_HOME="{self.java}"\nexport ANDROID_HOME="{self.sdk}"\n')
        self.env = dict(os.environ, TEST_LOG=str(self.log), TEST_ANDROID=str(self.android))

    def tearDown(self):
        self.temporary.cleanup()

    def executable(self, path, body):
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run_helper(self, *args, **env):
        return subprocess.run(["bash", str(self.root / "tools/android.sh"), *args],
                              env=dict(self.env, **env), text=True, capture_output=True)

    def signed_build(self):
        (self.android / "Signing.local.properties").write_text("fixture=true\n")
        result = self.run_helper("build")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_environment_stops_before_any_command(self):
        (self.android / "env.local.sh").unlink()
        result = self.run_helper("devices")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("setup_android.sh", result.stderr)
        self.assertFalse(self.log.exists())

    def test_signed_build_requires_local_signing(self):
        result = self.run_helper("build")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Signing.local.properties", result.stderr)
        self.assertFalse(self.log.exists())

    def test_build_runs_checks_and_verifies_certificate(self):
        self.signed_build()
        commands = self.log.read_text()
        for action in [":app:clean", ":app:testDebugUnitTest", ":app:lintDebug", ":app:assembleRelease", ":app:bundleRelease", "verify --verbose --print-certs"]:
            self.assertIn(action, commands)

    def test_install_requires_explicit_serial(self):
        result = self.run_helper("install")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.log.exists())

    def test_install_updates_only_selected_device_and_launches(self):
        self.signed_build()
        result = self.run_helper("install", "phone-123")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.log.read_text()
        self.assertIn("-s phone-123 install -r", commands)
        self.assertIn("-s phone-123 shell am start -n win.gridzero.android/.MainActivity", commands)
        self.assertNotIn("uninstall", commands)
        self.assertNotIn("pm clear", commands)

    def test_failed_update_never_uninstalls_or_launches(self):
        self.signed_build()
        result = self.run_helper("install", "phone-123", TEST_INSTALL_EXIT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("NEVER uninstalls", result.stderr)
        commands = self.log.read_text()
        self.assertNotIn("uninstall", commands)
        self.assertNotIn("am start", commands)

if __name__ == "__main__":
    unittest.main()
