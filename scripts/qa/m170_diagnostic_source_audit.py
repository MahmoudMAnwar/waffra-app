#!/usr/bin/env python3
"""M170 default-off and source allowlist audit, no Firebase operations."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
dependency = (root / "pubspec.yaml").read_text()
opt = (root / "lib/diagnostics/waffra_crashlytics_opt_in.dart").read_text()
boundary = (root / "lib/diagnostics/waffra_private_release_diagnostics.dart").read_text()
android = (root / ".github/workflows/android.yml").read_text()
checks = {
    "crashlytics_sdk_present": "firebase_crashlytics:" in dependency,
    "native_startup_collection_disabled": 'firebase_crashlytics_collection_enabled' in android
        and 'android:value="false"' in android,
    "compile_flag_reviewer_default_off": "WAFFRA_CRASHLYTICS_READY" in opt
        and "defaultValue: false" in opt,
    "persisted_consent_required": "consentKey = " in opt
        and "prefs.getBool(consentKey) ?? false" in opt,
    "sdk_auto_collection_follows_gate": "setCrashlyticsCollectionEnabled(allow)" in opt,
    "delete_unsent_on_opt_out": "deleteUnsentReports()" in opt,
    "sender_uses_safe_enum_only": "WaffraSafeDiagnosticEvent(code).safeTag" in opt
        and "enum WaffraSafeDiagnosticCode" in boundary,
    "no_direct_raw_exception_to_sdk": ".recordError(" not in opt
        and ".setUserIdentifier(" not in opt and ".setCustomKey(" not in opt,
}
for label, good in checks.items():
    print(("PASS" if good else "BLOCK") + " " + label)
if not all(checks.values()):
    raise SystemExit("M170 diagnostics source audit denied")
print("Source review only: signed APK, native startup transmission and user opt-in remain unverified.")
