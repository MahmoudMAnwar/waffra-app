#!/usr/bin/env bash
# M553: Pin original llamadart 0.8.24 native runtime release v0.4.1.
# Reuse original hook archive path without changing user code/native cryptography.
set -Eeuo pipefail
upstream='leehack/llamadart-native'
tag='v0.4.1'
pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"
root="$pub_cache/hosted/pub.dev/llamadart-0.8.24/.dart_tool/llamadart/native_bundles/$tag"
mkdir -p "$root"
# Pin SHA256 values from the official GitHub API release manifest.
items=(
  'linux-x64:d71b8a74b330275efbebd9bd345140645a6c3388cc51e4a6ad3f556d7b0f33c3'
  'android-arm64:fca52f625e196b4f5d53b5dcbe9646b6b7641eedbd7f61ab1272ddd5ec0a9ee4'
  'android-x64:221c6b74eacbba43dfd46b069d0e8a786d6cfb9ac56d64898e1aff0d3480ae84'
)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for spec in "${items[@]}"; do
  bundle="${spec%%:*}"
  digest="${spec#*:}"
  asset="llamadart-native-$bundle-$tag.tar.gz"
  target="$root/$bundle/$asset"
  if [[ -f "$target" ]] && printf '%s  %s\n' "$digest" "$target" | sha256sum --check --status; then
    echo "PASS cached $asset (official SHA256)"
    continue
  fi
  rm -f "$target"
  # Release API works when GitHub's direct CDN serves an HTTP-504 response.
  gh release download "$tag" --repo "$upstream" --pattern "$asset" --dir "$work" --clobber
  original="$work/$asset"
  [[ -f "$original" ]] || { echo "FATAL: official artifact missing: $asset" >&2; exit 1; }
  printf '%s  %s\n' "$digest" "$original" | sha256sum --check --status || {
    echo "FATAL: official artifact SHA256 mismatch: $asset" >&2
    exit 1
  }
  mkdir -p "$(dirname "$target")"
  mv "$original" "$target"
  printf '%s  %s\n' "$digest" "$target" | sha256sum --check --status || exit 1
  echo "PASS retrieved $asset (official SHA256)"
done
