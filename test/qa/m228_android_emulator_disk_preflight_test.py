from pathlib import Path
import unittest

class M228AndroidEmulatorSpace(unittest.TestCase):
 def test_real_encrypted_android_assertions_remain_required_with_smaller_avd(self):
  source=Path('.github/workflows/storage-android-integration.yml').read_text(encoding='utf8')
  self.assertEqual(source.count('disk-size: 3072M'),2)
  self.assertIn('sudo rm -rf /usr/share/dotnet /usr/local/share/powershell /opt/hostedtoolcache/CodeQL',source)
  self.assertIn('emulator-boot-timeout: 600',source)
  self.assertEqual(source.count('script: bash .github/scripts/run-android-finance-integration.sh'),2)
  self.assertIn("steps.emulator_primary.outcome == 'failure'",source)
  self.assertNotIn('continue-on-error: true\n        uses: reactivecircus/android-emulator-runner@v2\n        with:\n          api-level: 35',source)

if __name__=='__main__': unittest.main()
