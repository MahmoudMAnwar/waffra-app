"""M552: Every Flutter CI job must verify pinned official sqlite3mc binaries."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / '.github' / 'workflows'

class VerifiedSqliteCiPrefetchTest(unittest.TestCase):
    def test_immutable_crypto_version_and_no_untrusted_url_override(self):
        pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertIn('  sqlite3: 3.7.0', pub)
        self.assertIn('    sqlite3:\n      source: sqlite3mc', pub)
        self.assertNotIn('source: system', pub)
        self.assertNotIn('url_pattern:', pub)

    def test_official_api_sha256_pins_every_supported_ci_abi(self):
        script = (ROOT / 'scripts/qa/prefetch_verified_sqlite3mc.sh').read_text(encoding='utf-8')
        self.assertIn('gh release download', script)
        self.assertIn("repo='simolus3/sqlite3.dart'", script)
        self.assertIn("release='sqlite3-3.7.0'", script)
        self.assertIn('sha256sum --check --status', script)
        for pin in (
            'libsqlite3mc.x64.linux.so:3dfe8bcd00e34c705de14acd1c1a0d283b9fd7d20fbd49b0aa0196b85a1d7741',
            'libsqlite3mc.arm.android.so:dfcf871c49223135b11a79c52669c359e6c818d4a351c5985dcb393ac8e873d4',
            'libsqlite3mc.arm64.android.so:f0c07e18d083282a3f9252623ff65a59d3e99370d8af8404519d471455922149',
            'libsqlite3mc.ia32.android.so:9883154123c6d85eb2bd87980143ab442b77ebeb6e437dfb222bdbb9720244b7',
            'libsqlite3mc.x64.android.so:d864384afd0b6738dc82d3cd3aa8bb8c80fa987fe6eddb376e29ff3017b14b04',
        ):
            self.assertIn(pin, script)
        action = (ROOT / '.github/actions/prefetch-sqlite3mc/action.yml').read_text(encoding='utf-8')
        self.assertIn('uses: actions/cache@v4', action)
        self.assertIn('run: bash scripts/qa/prefetch_verified_sqlite3mc.sh', action)
        self.assertIn('run: bash scripts/qa/prefetch_verified_llamadart.sh', action)
        self.assertIn('llamadart-0.8.24/.dart_tool/llamadart/native_bundles/v0.4.1', action)
        llama = (ROOT / 'scripts/qa/prefetch_verified_llamadart.sh').read_text(encoding='utf-8')
        self.assertIn("upstream='leehack/llamadart-native'", llama)
        self.assertIn("tag='v0.4.1'", llama)
        self.assertIn("d71b8a74b330275efbebd9bd345140645a6c3388cc51e4a6ad3f556d7b0f33c3", llama)
        self.assertIn('sha256sum --check --status', llama)

    def test_every_flutter_setup_job_has_verified_prefetch(self):
        count = 0
        for file in sorted(WORKFLOWS.glob('*.yml')):
            source = file.read_text(encoding='utf-8')
            positions = list(re.finditer(r'^  ([A-Za-z0-9_-]+):.*$', source, re.M))
            for idx, match in enumerate(positions):
                end = positions[idx + 1].start() if idx + 1 < len(positions) else len(source)
                block = source[match.start():end]
                if 'subosito/flutter-action@v2' not in block:
                    continue
                count += 1
                step = 'uses: ./.github/actions/prefetch-sqlite3mc'
                self.assertIn(step, block, file.name + ' / ' + match.group(1))
                self.assertLess(block.index('subosito/flutter-action@v2'),
                                block.index(step), file.name + ' / ' + match.group(1))
        self.assertGreaterEqual(count, 85, 'Regression covers current and historical Flutter jobs')

if __name__ == '__main__':
    unittest.main()
