from pathlib import Path
import unittest

class M440EmulatorDiskFix(unittest.TestCase):
 def test_userdata_is_bounded_and_real_emulator_tests_still_run(self):
  s=Path('.github/workflows/storage-android-integration.yml').read_text(encoding='utf8')
  self.assertEqual(s.count('disk-size: 3072M'),2)
  self.assertIn('sudo rm -rf /usr/share/dotnet /usr/local/share/powershell /opt/hostedtoolcache/CodeQL',s)
  self.assertIn('emulator-boot-timeout: 600',s)
  self.assertIn('script: bash .github/scripts/run-android-finance-integration.sh',s)
  self.assertIn("steps.emulator_primary.outcome == 'failure'",s)
  self.assertNotIn("continue-on-error: true\n        uses: reactivecircus/android-emulator-runner@v2\n        with:\n          api-level: 35",s)

if __name__=='__main__': unittest.main()
