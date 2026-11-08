#!/usr/bin/env bash
# M552: Prefetch official immutable sqlite3mc 3.7.0 release assets.
# The upstream package's built-in SHA256 native hook remains authoritative.
set -Eeuo pipefail
release='sqlite3-3.7.0'
repo='simolus3/sqlite3.dart'
root="${GITHUB_WORKSPACE:-$PWD}/.dart_tool/hooks_runner/shared/sqlite3/build"
mkdir -p "$root"
assets=(
  'libsqlite3mc.x64.linux.so:3dfe8bcd00e34c705de14acd1c1a0d283b9fd7d20fbd49b0aa0196b85a1d7741'
  'libsqlite3mc.arm.android.so:dfcf871c49223135b11a79c52669c359e6c818d4a351c5985dcb393ac8e873d4'
  'libsqlite3mc.arm64.android.so:f0c07e18d083282a3f9252623ff65a59d3e99370d8af8404519d471455922149'
  'libsqlite3mc.ia32.android.so:9883154123c6d85eb2bd87980143ab442b77ebeb6e437dfb222bdbb9720244b7'
  'libsqlite3mc.x64.android.so:d864384afd0b6738dc82d3cd3aa8bb8c80fa987fe6eddb376e29ff3017b14b04'
)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for spec in "${assets[@]}"; do
  asset="${spec%%:*}"
  expected="${spec#*:}"
  target="$root/download-${expected:0:8}/libsqlite3mc.so"
  if [[ -f "$target" ]] && echo "$expected  $target" | sha256sum --check --status; then
    echo "PASS cached $asset SHA256 $expected"
    continue
  fi
  # Official GitHub release API, not the poisoned direct release CDN cache.
  gh release download "$release" --repo "$repo" --pattern "$asset" --dir "$work" --clobber
  source_file="$work/$asset"
  [[ -f "$source_file" ]] || { echo "FATAL: missing $asset" >&2; exit 1; }
  echo "$expected  $source_file" | sha256sum --check --status || {
    echo "FATAL: official sqlite3mc asset SHA256 mismatch: $asset" >&2
    exit 1
  }
  mkdir -p "$(dirname "$target")"
  install -m 0644 "$source_file" "$target"
  echo "$expected  $target" | sha256sum --check --status || exit 1
  echo "PASS fetched $asset SHA256 $expected"
done
