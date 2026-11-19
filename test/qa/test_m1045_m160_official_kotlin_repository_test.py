"""M1045: M160 Kotlin plugin DSL resolves only from official Maven Central + portal."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
WORKFLOW=ROOT/'.github/workflows/m160-main-reconciliation.yml'

class KotlinPluginLoaderResolution(unittest.TestCase):
 def test_java21_precedes_flutter_and_native_qa(self):
  s=WORKFLOW.read_text(encoding='utf-8')
  self.assertIn("uses: actions/setup-java@v4",s)
  self.assertIn("distribution: temurin",s)
  self.assertIn("java-version: '21'",s)
  self.assertLess(s.index("uses: actions/setup-java@v4"),
                  s.index("uses: subosito/flutter-action@v2"))
  self.assertIn('uses: ./.github/actions/prefetch-sqlite3mc',s)
  self.assertIn('uses: ./.github/actions/prefetch-gradle',s)
  self.assertLess(s.index('prefetch-sqlite3mc'),s.index('prefetch-gradle'))

 def test_included_flutter_gradle_plugin_resolution_uses_official_maven_only(self):
  s=WORKFLOW.read_text(encoding='utf-8')
  self.assertIn('gradle.beforeSettings { settings ->',s)
  self.assertIn('settings.pluginManagement.repositories {',s)
  self.assertIn('mavenCentral()',s)
  self.assertIn('gradlePluginPortal()',s)
  self.assertIn('m160-official-kotlin-plugin-repositories.gradle',s)
  self.assertNotIn('allowInsecureProtocol = true',s)
  self.assertNotIn('continue-on-error: true',s)
  self.assertNotIn('--offline',s)

 def test_release_host_applies_m147_native_plugin_and_desugaring_guards(self):
  s=WORKFLOW.read_text(encoding='utf-8')
  self.assertIn('isCoreLibraryDesugaringEnabled = true',s)
  self.assertIn('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',s)
  self.assertIn('GeneratedPluginRegistrant.java',s)
  self.assertIn('IntegrationTestPlugin()',s)
  self.assertIn('debug/test-only',s)
  self.assertIn("raise SystemExit('Unexpected integration_test registrar form')",s)
  self.assertIn('flutter build apk --release --no-pub --target-platform android-arm64',s)
  self.assertNotIn('continue-on-error: true',s)

 def test_full_suite_and_real_apk_compilation_remain_mandatory(self):
  s=WORKFLOW.read_text(encoding='utf-8')
  self.assertIn('run: flutter test',s)
  self.assertIn('flutter analyze --no-fatal-warnings --no-fatal-infos',s)
  self.assertIn('flutter create --no-pub --platforms=android --project-name=waffra --org com.waffra .',s)
  start=s.index('flutter create --no-pub')
  self.assertIn('flutter pub get',s[start:])
  self.assertIn('flutter build apk --release --no-pub --target-platform android-arm64',s)
  self.assertNotIn('WAFFRA_COMPILE_ONLY_PREVIEW=true',s)
  self.assertNotIn('if: false',s)
  self.assertNotIn('|| true',s[s.index('Android release compile (unsigned validation only)'):])

if __name__=='__main__': unittest.main()
