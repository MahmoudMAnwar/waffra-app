# Waffra — Crash Monitoring Production Wiring Plan

**Status: secure event boundary implemented; Firebase Crashlytics SDK is NOT integrated/active yet.**

## Mandatory prerequisites before enabling any diagnostic transmission
- Add and configure FlutterFire Crashlytics via an independently tested change (firebase_crashlytics dependency, Firebase Gradle plugin, current Firebase app configuration, Android and eventually iOS setup).
- Explicitly suppress native automatic collection in the AndroidManifest BEFORE building the release:
  android:name="firebase_crashlytics_collection_enabled" android:value="false".
  Flutter runtime false alone is not a sufficient startup privacy boundary.
- Persist explicit user opt-in/out in app settings. Honor opt-out across launches and do not send buffered previous crashes without considering how the SDK handles local caching.
- Review whether Google Analytics / Analytics breadcrumbs are enabled in Firebase project; prevent automatic content-rich analytics parameters.
- Send ONLY static safe event tags from WaffraPrivateDiagnostics; never attach exception.toString, arbitrary stack trace, transaction amount/title, phone, bank SMS, receipt path/content, Firebase ID token or user encryption key.
- Native crash collection may still include automatically generated stack metadata and device details; disclose the actual processor and data types in EN/AR policy and Play Data Safety.
- Run a disposable intentional test crash on internal test channel with synthetic data, confirm exact visible event payload in Firebase console, check user opt-out and app relaunch, then request security/privacy approval.
- Store an incident owner and critical alerts for elevated fatal crashes, ANR, sign-in failures, finance restore/cutover failure and data corruption. Alerts must not reveal user data.
- Record version, release channel, signing/build SHA and GitHub Actions run ID as **build metadata**, not user identifiers.

## Explicitly forbidden collection
No raw user-entered descriptions, copied SMS, bank transaction IDs, email, phone, account ID, file names, backup password, recovery code, SQLCipher secret, receipt content, clipboard data, stack exception text containing financial input or identity tokens.

## CI acceptance prior to enabling SDK
1. Default-off native SDK configuration in generated and release Android projects, checked by build script.
2. Flutter opt-in preference and consent withdrawal tested with fake sender.
3. Cross-device startup before a user has consented sends **zero** diagnostics.
4. Privacy policy and Data Safety disclose actual Crashlytics and its provider.
5. Debug test sends only static allowlisted code. No production data uploads.
6. Firebase Crashlytics release native/Flutter integration passes full regression and is tested on a signed internal APK/AAB.

**References:** Firebase Crashlytics official Flutter get-started and customize-crash-reports docs. Implement opt-in correctly rather than claiming a feature exists based solely on a staging adapter.
