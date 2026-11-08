#!/usr/bin/env bash
# M555: Keep Gradle's Kotlin compiler module at its original immutable version.
# Scope is CI only; no substitution of Kotlin versions or Gradle verification.
set -Eeuo pipefail
upstream='JetBrains/kotlin'
release='v2.2.21'
version='2.2.21'
module='kotlin-compiler-embeddable'
jar="$module-$version.jar"
pom="$module-$version.pom"
expected='9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295'
home="${GRADLE_USER_HOME:-$HOME/.gradle}"
root="$home/waffra-verified-maven/org/jetbrains/kotlin/$module/$version"
mkdir -p "$root" "$home/init.d"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
file="$root/$jar"
if [[ -f "$file" ]] && printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status; then
  echo "PASS cached official Kotlin compiler artifact SHA256"
else
  rm -f "$file"
  if ! gh release download "$release" --repo "$upstream" --pattern "$jar" --dir "$work" --clobber; then
    curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
      "https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/$module/$version/$jar" -o "$work/$jar"
  fi
  printf '%s  %s\n' "$expected" "$work/$jar" | sha256sum --check --status || {
    echo "FATAL: mismatched official Kotlin compiler artifact" >&2; exit 1
  }
  install -m 0644 "$work/$jar" "$file"
fi
url="https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/$module/$version"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 40 "$url/$pom" -o "$work/$pom"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 40 "$url/$pom.sha1" -o "$work/pom.sha1"
pinned_sha1="$(grep -Eo '[a-fA-F0-9]{40}' "$work/pom.sha1" | head -1 | tr 'A-F' 'a-f')"
[[ -n "$pinned_sha1" ]] || { echo "FATAL: official POM digest unavailable" >&2; exit 1; }
printf '%s  %s\n' "$pinned_sha1" "$work/$pom" | sha1sum --check --status || {
  echo "FATAL: Kotlin official POM digest mismatch" >&2; exit 1
}
install -m 0644 "$work/$pom" "$root/$pom"
# Before each Gradle project's normal repositories, expose ONLY this exact
# official Kotlin compiler artifact from the SHA-verified local Maven cache.
# Transitive dependencies are resolved against the unchanged official POM.
cat > "$home/init.d/waffra-verified-kotlin-2.2.21.gradle" <<'GROOVY'
gradle.beforeProject { project ->
    project.repositories.maven {
        name = 'WaffraPinnedOfficialKotlinCompiler'
        url = new File(gradle.gradleUserHomeDir, 'waffra-verified-maven').toURI()
        content {
            includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')
        }
    }
}
GROOVY
printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status
echo "PASS official Kotlin 2.2.21 JAR/POM verified, exact-module local repository installed for Gradle"
