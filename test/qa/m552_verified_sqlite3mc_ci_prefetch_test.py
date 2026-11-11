"""M552: Every Flutter CI job must verify pinned official sqlite3mc binaries."""
from pathlib import Path
import hashlib
import re
import subprocess
import tempfile
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
        self.assertIn('verify_sha256() {', script)
        self.assertIn('shasum -a 256 "$file"', script)
        self.assertIn('sha256sum "$file"', script)
        self.assertIn('[[ "$actual" == "$expected" ]]', script)
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
        # M636: only SQLCipher cryptography requires verified native bundles.
        # The optional Qwen/llamadart runtime has been retired entirely.
        self.assertNotIn('prefetch_verified_llamadart', action)
        self.assertNotIn('llamadart', action)
        self.assertNotIn('llama_cpp', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))

    def test_retired_qwen_dependency_never_restores_native_download(self):
        pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        action = (ROOT / '.github/actions/prefetch-sqlite3mc/action.yml').read_text(encoding='utf-8')
        self.assertNotIn('llamadart:', pub)
        self.assertNotIn('llamadart_native_runtimes', pub)
        self.assertNotIn('llamadart-native', action)
        self.assertIn('prefetch_verified_sqlite3mc.sh', action)

    def test_pinned_sha256_check_succeeds_only_for_matching_bytes(self):
        script = (ROOT / 'scripts/qa/prefetch_verified_sqlite3mc.sh').read_text(encoding='utf-8')
        function = script.split('verify_sha256() {', 1)[1].split('\n}\nfor spec', 1)[0]
        verifier = 'verify_sha256() {' + function + '\n}\nverify_sha256 "$1" "$2"'
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / 'sqlite3mc.so'
            artifact.write_bytes(b'official release SHA256 regression fixture')
            pinned = hashlib.sha256(artifact.read_bytes()).hexdigest()
            good = subprocess.run(['bash', '-c', verifier, 'bash', pinned, str(artifact)],
                                  capture_output=True, text=True, check=False)
            self.assertEqual(0, good.returncode, good.stderr)
            wrong = subprocess.run(['bash', '-c', verifier, 'bash', '0' * 64, str(artifact)],
                                   capture_output=True, text=True, check=False)
            self.assertNotEqual(0, wrong.returncode)
            artifact.write_bytes(b'changed/corrupted native asset')
            tampered = subprocess.run(['bash', '-c', verifier, 'bash', pinned, str(artifact)],
                                      capture_output=True, text=True, check=False)
            self.assertNotEqual(0, tampered.returncode)

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
