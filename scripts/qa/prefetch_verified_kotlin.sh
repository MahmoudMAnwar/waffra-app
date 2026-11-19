#!/usr/bin/env bash
# M555: Keep Gradle's Kotlin compiler module at its original immutable version.
# Scope is CI only; no substitution of Kotlin versions or Gradle verification.
set -Eeuo pipefail
upstream='JetBrains/kotlin'
# Keep each native Android plugin on its existing Kotlin version.
# Both immutable compiler artifacts are verified against JetBrains release SHA.
module='kotlin-compiler-embeddable'
home="${GRADLE_USER_HOME:-$HOME/.gradle}"
mkdir -p "$home/init.d"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
versions=(
 '2.2.21:9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295'
 '2.4.0:c2b25e8c1c93ec416ba4327f5e31eaec0f0c8847241b9353e294b8db9dce564f'
)

# M1043 / Issue #774: an upstream Maven 404 must not permanently block Android
# CI when the original Kotlin JAR is SHA256-valid. Two canonical Maven Central
# endpoints are the ONLY permitted POM/sidecar sources. Both POM and SHA1
# MUST be fetched from the same endpoint and verified before installation.
fetch_verified_kotlin_pom() {
  local version="$1" pom="$2" work="$3"
  local module='kotlin-compiler-embeddable'
  local relative="org/jetbrains/kotlin/$module/$version"
  local pom_file="$work/$pom" sha_file="$work/$pom.sha1"
  local base digest
  for base in 'https://repo.maven.apache.org/maven2' 'https://repo1.maven.org/maven2'; do
    rm -f "$pom_file" "$sha_file"
    if ! curl --fail --silent --show-error --location --retry 2 \
        --retry-all-errors --retry-delay 1 --connect-timeout 15 \
        --max-time 40 "$base/$relative/$pom" -o "$pom_file"; then
      echo "M1043: official Kotlin $version POM unavailable at $base; checking alternate" >&2
      continue
    fi
    if ! curl --fail --silent --show-error --location --retry 2 \
        --retry-all-errors --retry-delay 1 --connect-timeout 15 \
        --max-time 40 "$base/$relative/$pom.sha1" -o "$sha_file"; then
      echo "M1043: official Kotlin $version checksum unavailable at $base; checking alternate" >&2
      continue
    fi
    digest="$(tr -d '[:space:]' < "$sha_file")"
    if [[ ! "$digest" =~ ^[A-Fa-f0-9]{40}$ ]]; then
      echo "FATAL: malformed official Kotlin $version POM checksum" >&2
      return 1
    fi
    if ! printf '%s  %s\n' "$digest" "$pom_file" | sha1sum --check --status; then
      echo "FATAL: Kotlin $version official POM digest mismatch" >&2
      return 1
    fi
    echo "PASS verified Kotlin $version POM SHA1 from $base"
    return 0
  done
  echo "FATAL: official Kotlin $version POM and SHA1 unavailable from both Maven Central endpoints" >&2
  return 1
}


# Reuse the exact Maven POM from the immutable Actions cache even when BOTH
# Maven Central endpoints are 404, but ONLY after checking its SHA256 against
# JetBrains' version-matched official Maven release manifest on GitHub.
# No fabricated POM, no unverified cache hit and no relaxed compiler/JAR pin.
verify_cached_kotlin_pom_release() {
  local version="$1" pom="$2" root="$3" work="$4"
  local cached_pom="$root/$pom" cached_sha="$root/$pom.sha1"
  local manifest="$work/maven-$version-sha256.txt"
  local record digest
  [[ -s "$cached_pom" ]] || return 1
  if ! gh release download "v$version" --repo "$upstream" \
      --pattern "maven-$version-sha256.txt" --dir "$work" --clobber; then
    echo "M1043: signed-release Maven SHA256 manifest unavailable for Kotlin $version" >&2
    return 1
  fi
  [[ -s "$manifest" ]] || return 1
  # Exactly one POM basename, not .pom.sha1/.pom.sha256 nor unrelated plugins.
  record="$(grep -F "$pom" "$manifest" | grep -E '\.pom([[:space:]]|$)' || true)"
  if [[ -z "$record" || "$(printf '%s\n' "$record" | wc -l)" -ne 1 ]]; then
    echo "FATAL: Kotlin $version release SHA256 manifest missing/ambiguous exact POM" >&2
    return 1
  fi
  digest="$(printf '%s\n' "$record" | grep -Eo '[A-Fa-f0-9]{64}' || true)"
  if [[ ! "$digest" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    echo "FATAL: Kotlin $version release POM SHA256 malformed" >&2
    return 1
  fi
  if ! printf '%s  %s\n' "$digest" "$cached_pom" | sha256sum --check --status; then
    echo "FATAL: Kotlin $version cached POM SHA256 release digest mismatch" >&2
    return 1
  fi
  # The SHA1 sidecar is now derived FROM a SHA256-verified original POM.
  sha1sum "$cached_pom" | cut -d' ' -f1 > "$cached_sha"
  echo "PASS verified cached Kotlin $version POM SHA256 against JetBrains release manifest"
  return 0
}

for spec in "${versions[@]}"; do
  version="${spec%%:*}"
  expected="${spec#*:}"
  release="v$version"
  jar="$module-$version.jar"
  pom="$module-$version.pom"
  root="$home/waffra-verified-maven/org/jetbrains/kotlin/$module/$version"
  mkdir -p "$root"
  file="$root/$jar"
  if [[ -f "$file" ]] && printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status; then
    echo "PASS cached official Kotlin compiler $version SHA256"
  else
    rm -f "$file"
    if ! gh release download "$release" --repo "$upstream" --pattern "$jar" --dir "$work" --clobber; then
      curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
        "https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/$module/$version/$jar" -o "$work/$jar"
    fi
    printf '%s  %s\n' "$expected" "$work/$jar" | sha256sum --check --status || {
      echo "FATAL: mismatched official Kotlin $version compiler artifact" >&2; exit 1
    }
    install -m 0644 "$work/$jar" "$file"
  fi
  # Reuse only a previously verified POM + SHA1, avoiding unrelated CDN
  # outages on every Android rebuild; otherwise fetch and revalidate both.
  cached_pom="$root/$pom"
  cached_sha="$root/$pom.sha1"
  cached_digest=''
  if [[ -s "$cached_pom" && -s "$cached_sha" ]]; then
    cached_digest="$(tr -d '[:space:]' < "$cached_sha")"
  fi
  if [[ "$cached_digest" =~ ^[A-Fa-f0-9]{40}$ ]] &&
      printf '%s  %s\n' "$cached_digest" "$cached_pom" | sha1sum --check --status; then
    echo "PASS cached official Kotlin $version POM SHA1"
  elif verify_cached_kotlin_pom_release "$version" "$pom" "$root" "$work"; then
    echo "PASS release-verified Kotlin $version cached POM reused safely"
  else
    fetch_verified_kotlin_pom "$version" "$pom" "$work"
    install -m 0644 "$work/$pom" "$cached_pom"
    install -m 0644 "$work/$pom.sha1" "$cached_sha"
  fi
  printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status || exit 1
done

# Gradle/Flutter included builds can enforce FAIL_ON_PROJECT_REPOS.
# Do not mutate Project.repositories. Register this exact official, SHA-pinned
# Maven module at SETTINGS initialization, before settings.gradle.kts is read.
# All other modules still use their unchanged official upstream repositories.
cat > "$home/init.d/waffra-verified-kotlin-2.2.21.gradle" <<'GROOVY'
// Kotlin's included Flutter Gradle build mandates FAIL_ON_PROJECT_REPOS,
// whereas generated Android/Firebase builds may retain PREFER_PROJECT.
// Never change a build's repository policy. Route only two SHA-verified
// original Kotlin compiler artifacts through the policy it already uses.
gradle.beforeSettings { settings ->
    def repos = settings.dependencyResolutionManagement.repositories
    def verifiedMaven = repos.maven {
        name = 'WaffraPinnedOfficialKotlinCompiler'
        url = new File(gradle.gradleUserHomeDir, 'waffra-verified-maven').toURI()
    }
    repos.exclusiveContent {
        forRepositories(verifiedMaven)
        filter {
            includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')
            includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.4.0')
        }
    }
}
gradle.settingsEvaluated { settings ->
    // Do not inject a project repository into settings-enforced builds.
    // A PREFER_PROJECT build ignores settings-level dependency repositories,
    // so give only that build an exact-module verified local repository.
    if (settings.dependencyResolutionManagement.repositoriesMode.get().name() == 'PREFER_PROJECT') {
        gradle.beforeProject { project ->
            def projectRepos = project.repositories
            def verifiedProjectMaven = projectRepos.maven {
                name = 'WaffraPinnedOfficialKotlinCompilerForProject'
                url = new File(gradle.gradleUserHomeDir, 'waffra-verified-maven').toURI()
            }
            projectRepos.exclusiveContent {
                forRepositories(verifiedProjectMaven)
                filter {
                    includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')
                    includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.4.0')
                }
            }
        }
    }
}
GROOVY
printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status
echo "PASS official Kotlin 2.2.21 + 2.4.0 compiler JAR/POM verified, exact-module local settings repository active"
