"""M554: official pinned Gradle distro is verified before Android compile."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
WORKFLOWS=ROOT/'.github'/'workflows'
EXPECTED='17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43'

class VerifiedGradleCache(unittest.TestCase):
    def test_preseed_uses_exact_original_official_signed_release(self):
        s=(ROOT/'scripts/qa/prefetch_verified_gradle.sh').read_text()
        self.assertIn("release='v9.3.1'",s)
        self.assertIn("upstream='gradle/gradle-distributions'",s)
        self.assertIn("asset='gradle-9.3.1-all.zip'",s)
        self.assertIn(EXPECTED,s)
        self.assertIn('gh release download',s)
        self.assertIn('https://downloads.gradle.org/distributions',s)
        self.assertIn('sha256sum --check --status',s)
        self.assertIn('hashlib.md5',s)
        self.assertIn("n,r = divmod(n,36)",s)
        action=(ROOT/'.github/actions/prefetch-gradle/action.yml').read_text()
        self.assertIn('uses: actions/cache@v4',action)
        self.assertIn('bash scripts/qa/prefetch_verified_gradle.sh',action)
        kotlin=(ROOT/'scripts/qa/prefetch_verified_kotlin.sh').read_text()
        self.assertIn("upstream='JetBrains/kotlin'",kotlin)
        self.assertIn("release='v2.2.21'",kotlin)
        self.assertIn("expected='9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295'",kotlin)
        self.assertIn('sha256sum --check --status',kotlin)
        self.assertIn('sha1sum --check --status',kotlin)
        self.assertIn("includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')",kotlin)
        self.assertIn('bash scripts/qa/prefetch_verified_kotlin.sh',action)
        # Flutter's included Gradle build enforces FAIL_ON_PROJECT_REPOS.
        # Only settings-level exact-module routing is allowed in the init hook.
        self.assertIn('gradle.beforeSettings { settings ->',kotlin)
        self.assertIn('settings.dependencyResolutionManagement.repositories.exclusiveContent',kotlin)
        self.assertNotIn('gradle.beforeProject',kotlin)
        self.assertNotIn('project.repositories.maven',kotlin)

    def test_critical_android_jobs_prefetch_verified_gradle(self):
        critical={
          'android.yml': 'build',
          'android-full-smoke.yml': 'build',
          'm147-final-main-review-gate.yml': 'android-arm64-compilation',
          'm202-android-sqlcipher-source-binder-dryrun.yml': 'android-source-binder-and-migration',
          'm417-auto-bank-sms.yml': 'android-sms-native-compile',
          'storage-android-integration.yml': 'android-encrypted-db',
          'storage-android-emulator.yml': 'encrypted-storage-device',
        }
        for file,job in critical.items():
            s=(WORKFLOWS/file).read_text()
            self.assertIn('  '+job+':',s,file)
            block=s.split('  '+job+':',1)[1]
            self.assertIn('uses: ./.github/actions/prefetch-sqlite3mc',block,file)
            self.assertIn('uses: ./.github/actions/prefetch-gradle',block,file)
            self.assertLess(block.index('uses: ./.github/actions/prefetch-sqlite3mc'),
                            block.index('uses: ./.github/actions/prefetch-gradle'),file)

if __name__=='__main__':
    unittest.main()
