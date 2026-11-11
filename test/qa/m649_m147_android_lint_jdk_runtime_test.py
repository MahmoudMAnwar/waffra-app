"""M649: keep native Android Lint and ARM64 release checks compatible with the JDK runtime."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
M147 = ROOT / ".github/workflows/m147-final-main-review-gate.yml"


class M649AndroidLintRuntimeTest(unittest.TestCase):
    def test_m147_arm64_uses_java21_and_keeps_release_verification(self):
        source = M147.read_text(encoding="utf-8")
        marker = "\n  android-arm64-compilation:\n"
        self.assertEqual(source.count(marker), 1)
        build = source.split(marker, 1)[1]
        self.assertIn("needs: review-exact-main-diff", build)
        self.assertIn("uses: actions/setup-java@v4", build)
        self.assertIn("distribution: temurin", build)
        self.assertIn("java-version: '21'", build)
        self.assertNotIn("java-version: '17'", build)
        self.assertIn("uses: subosito/flutter-action@v2", build)
        self.assertIn("Prefetch SHA256-verified Gradle wrapper distribution", build)
        self.assertIn("Prefetch SHA256-verified official SQLite3MC native release assets", build)
        self.assertIn("flutter create --no-pub --platforms=android", build)
        self.assertIn("flutter build apk --release --no-pub --target-platform android-arm64", build)
        self.assertIn("ARM64 compilation failed; never accept or publish a failed build.", build)
        self.assertNotIn("lintVital=false", build)
        self.assertNotIn("abortOnError false", build)
        self.assertNotIn("lintOptions { disable", build)

    def test_exact_checkout_and_full_flutter_gate_remain(self):
        source = M147.read_text(encoding="utf-8")
        self.assertIn("Checkout exactly reviewed head", source)
        self.assertIn("github.event.pull_request.head.sha || github.sha", source)
        self.assertIn("flutter test", source)
        self.assertIn("full-flutter-regression:", source)


if __name__ == "__main__":
    unittest.main()
