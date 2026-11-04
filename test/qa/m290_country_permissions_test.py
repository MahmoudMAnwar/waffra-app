import tempfile
import unittest
from pathlib import Path

from scripts.qa.m290_configure_country_permissions import apply_manifest, PERMISSION


class CountryPermissionManifestTest(unittest.TestCase):
    def test_saudi_default_does_not_request_location(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                '<application android:label="Waffra" /></manifest>',
                encoding="utf-8")
            apply_manifest(manifest)
            apply_manifest(manifest)
            result = manifest.read_text(encoding="utf-8")
            self.assertEqual(result.count(PERMISSION), 0)
            for denied in ('ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION',
                           'ACCESS_BACKGROUND_LOCATION', 'READ_SMS',
                           'RECEIVE_SMS'):
                self.assertNotIn(denied, result)

    def test_old_location_permission_is_removed_on_saudi_build(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                +PERMISSION+'<application /></manifest>',encoding="utf-8")
            apply_manifest(manifest)
            self.assertNotIn(PERMISSION, manifest.read_text(encoding="utf-8"))

    def test_global_reactivation_remains_explicit_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text('<manifest><application /></manifest>',encoding="utf-8")
            apply_manifest(manifest,enable_global_location=True)
            apply_manifest(manifest,enable_global_location=True)
            self.assertEqual(manifest.read_text(encoding="utf-8").count(PERMISSION),1)

    def test_missing_file_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                apply_manifest(Path(directory) / "missing.xml")

if __name__ == "__main__":
    unittest.main()
