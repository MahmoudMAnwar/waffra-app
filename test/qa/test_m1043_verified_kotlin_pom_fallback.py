"""M1043 / #774: exercise official Kotlin POM fallback offline, not against public network."""
from __future__ import annotations

import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/prefetch_verified_kotlin.sh"


def _load_function() -> str:
    content = SCRIPT.read_text(encoding="utf-8")
    start = content.index("fetch_verified_kotlin_pom() {")
    end = content.index("\n}\n", start) + 2
    return content[start:end]



def _load_release_manifest_function() -> str:
    content = SCRIPT.read_text(encoding="utf-8")
    start = content.index("verify_cached_kotlin_pom_release() {")
    end = content.index("\n}\n", start) + 2
    return content[start:end]

class VerifiedKotlinPomFallbackTests(unittest.TestCase):
    def _simulate(self, mode: str):
        shell = (
            "set -Eeuo pipefail\n"
            + _load_function()
            + "\nwork=$(mktemp -d)\ntrap 'rm -rf \"$work\"' EXIT\n"
            + "pom='kotlin-compiler-embeddable-2.2.21.pom'\n"
            + "data='<project><modelVersion>4.0.0</modelVersion></project>'\n"
            + "digest=$(printf '%s' \"$data\" | sha1sum | cut -d' ' -f1)\n"
            + f"mode='{mode}'\n"
            + r'''curl() {
  local url='' target=''
  while (( $# )); do
    case "$1" in
      -o) target="$2"; shift 2;;
      https://*) url="$1"; shift;;
      *) shift;;
    esac
  done
  printf '%s\n' "$url" >> "$work/urls"
  if [[ "$url" == https://repo.maven.apache.org/* || "$mode" == 'both_down' ]]; then return 22; fi
  if [[ "$url" == *.sha1 ]]; then
    if [[ "$mode" == 'bad_digest' ]]; then
      printf '0000000000000000000000000000000000000000\n' > "$target"
    else
      printf '%s\n' "$digest" > "$target"
    fi
  else
    printf '%s' "$data" > "$target"
  fi
}
fetch_verified_kotlin_pom '2.2.21' "$pom" "$work"
[[ -s "$work/$pom" ]]
[[ $(wc -l < "$work/urls") -ge 3 ]]
'''
        )
        return subprocess.run(
            ["bash", "-c", shell], cwd=ROOT, capture_output=True, text=True, timeout=20
        )

    def test_fallback_to_second_official_origin_after_http_404(self):
        result = self._simulate("fallback")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS verified Kotlin", result.stdout)

    def test_missing_both_official_origins_fails_closed(self):
        result = self._simulate("both_down")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FATAL", result.stderr)

    def test_wrong_sha1_fails_without_approving_pom(self):
        result = self._simulate("bad_digest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("digest mismatch", result.stderr)

    def test_cached_pom_can_use_jetbrains_release_manifest_when_maven_is_404(self):
        manifest_function = _load_release_manifest_function()
        shell = (
            "set -Eeuo pipefail\n"
            + manifest_function
            + "\nwork=$(mktemp -d)\ntrap 'rm -rf \"$work\"' EXIT\n"
            + "upstream='JetBrains/kotlin'\n"
            + "root=\"$work/cache\"\nmkdir -p \"$root\"\n"
            + "pom='kotlin-compiler-embeddable-2.2.21.pom'\n"
            + "printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' > \"$root/$pom\"\n"
            + "actual=$(sha256sum \"$root/$pom\" | cut -d' ' -f1)\n"
            + r'''gh() {
  [[ "$1" == 'release' && "$2" == 'download' ]] || return 3
  printf '%s  %s\n' "$actual" \
    "org/jetbrains/kotlin/kotlin-compiler-embeddable/2.2.21/$pom" \
    > "$work/maven-2.2.21-sha256.txt"
}
verify_cached_kotlin_pom_release '2.2.21' "$pom" "$root" "$work"
[[ -s "$root/$pom.sha1" ]]
sha1sum --check --status <(printf '%s  %s\n' \
  "$(cat "$root/$pom.sha1")" "$root/$pom")
'''
        )
        result = subprocess.run(["bash", "-c", shell], cwd=ROOT,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS verified cached Kotlin", result.stdout)

    def test_cached_pom_manifest_digest_mismatch_fails_closed(self):
        manifest_function = _load_release_manifest_function()
        shell = (
            "set -Eeuo pipefail\n"
            + manifest_function
            + "\nwork=$(mktemp -d)\ntrap 'rm -rf \"$work\"' EXIT\n"
            + "upstream='JetBrains/kotlin'\n"
            + "root=\"$work/cache\"\nmkdir -p \"$root\"\n"
            + "pom='kotlin-compiler-embeddable-2.2.21.pom'\n"
            + "printf '%s' '<project>original</project>' > \"$root/$pom\"\n"
            + r'''gh() {
  printf '%064d  %s\n' 0 \
    "org/jetbrains/kotlin/kotlin-compiler-embeddable/2.2.21/$pom" \
    > "$work/maven-2.2.21-sha256.txt"
}
verify_cached_kotlin_pom_release '2.2.21' "$pom" "$root" "$work"
'''
        )
        result = subprocess.run(["bash", "-c", shell], cwd=ROOT,
                                capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mismatch", result.stderr)

    def test_original_sha256_jar_pinning_and_gradle_scope_still_enforced(self):
        content = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295", content)
        self.assertIn("c2b25e8c1c93ec416ba4327f5e31eaec0f0c8847241b9353e294b8db9dce564f", content)
        self.assertIn("sha256sum --check --status", content)
        self.assertIn("sha1sum --check --status", content)
        self.assertIn("includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')", content)
        self.assertIn("includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.4.0')", content)
        self.assertIn("fetch_verified_kotlin_pom \"$version\" \"$pom\" \"$work\"", content)


if __name__ == "__main__":
    unittest.main()
