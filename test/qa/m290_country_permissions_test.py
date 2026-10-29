import tempfile
import unittest
from pathlib import Path

from scripts.qa.m290_configure_country_permissions import apply_manifest, PERMISSION


class CountryPermissionManifestTest(unittest.TestCase):
    def test_adds_coarse_once_without_sensitive_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                '<application android:label="Waffra" /></manifest>',
                encoding="utf-8")
            apply_manifest(manifest)
            apply_manifest(manifest)
            result = manifest.read_text(encoding="utf-8")
            self.assertEqual(result.count(PERMISSION), 1)
            for disallowed in (
                'ACCESS_FINE_LOCATION', 'ACCESS_BACKGROUND_LOCATION',
                'READ_SMS', 'RECEIVE_SMS',
            ):
                self.assertNotIn(disallowed, result)

    def test_missing_file_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                apply_manifest(Path(directory) / "missing.xml")


if __name__ == "__main__":
    unittest.main()
