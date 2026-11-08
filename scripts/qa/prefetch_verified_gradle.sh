#!/usr/bin/env bash
# M554: Preseed the original Gradle 9.3.1 ALL distribution through official API.
# Do NOT change wrapper version, checksum, Gradle flags, or any Android tests.
set -Eeuo pipefail
release='v9.3.1'
upstream='gradle/gradle-distributions'
asset='gradle-9.3.1-all.zip'
expected='17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43'
base="\${GRADLE_USER_HOME:-$HOME/.gradle}/wrapper/dists/gradle-9.3.1-all"
urls=(
  'https://services.gradle.org/distributions/gradle-9.3.1-all.zip'
  'https://downloads.gradle.org/distributions/gradle-9.3.1-all.zip'
  'https://github.com/gradle/gradle-distributions/releases/download/v9.3.1/gradle-9.3.1-all.zip'
)
# Source-of-truth Gradle PathAssembler uses MD5(url UTF8) -> positive base36.
key_for_url() {
 python3 - "$1" <<'PY'
import hashlib,sys
n = int.from_bytes(hashlib.md5(sys.argv[1].encode()).digest(),'big')
chars = '0123456789abcdefghijklmnopqrstuvwxyz'
s = ''
while n:
    n,r = divmod(n,36)
    s=chars[r]+s
print(s or '0')
PY
}
all_good=true
for url in "\${urls[@]}"; do
  key="$(key_for_url "$url")"
  target="$base/$key/$asset"
  if [[ ! -f "$target" ]] || ! printf '%s  %s\n' "$expected" "$target" | sha256sum --check --status; then
    all_good=false
  fi
done
if [[ "$all_good" == true ]]; then
  echo "PASS official Gradle $asset already cached and SHA256 verified"
  exit 0
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh release download "$release" --repo "$upstream" --pattern "$asset" --dir "$work" --clobber
archive="$work/$asset"
[[ -f "$archive" ]] || { echo "FATAL: official Gradle ZIP missing" >&2; exit 1; }
printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status || {
  echo "FATAL: official Gradle 9.3.1 distribution digest mismatch" >&2
  exit 1
}
for url in "\${urls[@]}"; do
  key="$(key_for_url "$url")"
  target="$base/$key/$asset"
  mkdir -p "$(dirname "$target")"
  if [[ ! -f "$target" ]] || ! printf '%s  %s\n' "$expected" "$target" | sha256sum --check --status; then
    rm -f "$target"
    cp "$archive" "$target"
  fi
  printf '%s  %s\n' "$expected" "$target" | sha256sum --check --status
done
echo "PASS pinned official Gradle distribution verified and preseeded for all supported wrapper URLs"
