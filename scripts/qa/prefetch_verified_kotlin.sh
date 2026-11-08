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
  url="https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/$module/$version"
  curl --fail --location --retry 2 --connect-timeout 15 --max-time 40 "$url/$pom" -o "$work/$pom"
  curl --fail --location --retry 2 --connect-timeout 15 --max-time 40 "$url/$pom.sha1" -o "$work/pom-$version.sha1"
  pinned_sha1="$(grep -Eo '[a-fA-F0-9]{40}' "$work/pom-$version.sha1" | head -1 | tr 'A-F' 'a-f')"
  [[ -n "$pinned_sha1" ]] || { echo "FATAL: official Kotlin $version POM digest unavailable" >&2; exit 1; }
  printf '%s  %s\n' "$pinned_sha1" "$work/$pom" | sha1sum --check --status || {
    echo "FATAL: Kotlin $version official POM digest mismatch" >&2; exit 1
  }
  install -m 0644 "$work/$pom" "$root/$pom"
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
