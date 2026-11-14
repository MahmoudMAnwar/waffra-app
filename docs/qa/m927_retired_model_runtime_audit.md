# M927 — Runtime audit: retired Qwen / AI / Cloud SMS

Issue #632, #634 and #637; Draft PR #638.

## Scope

Only the real production `lib/main.dart` import, export and part dependency graph, together with the Android SMS permissions page and native background SMS poster, can determine whether an obsolete model is reachable by installed Waffra. Historical tests may still import compatibility validators but must not re-enable a discontinued outbound SMS transport.

## Enforced source evidence

`test/qa/m927_retired_model_runtime_graph_guard_test.py` walks the actual repository Dart graph, resolving `package:waffra/…` to `lib/`, including same-library `part` imports. The test rejects all paths from the live Waffra roots to the retired AI finance brain/coach, recorded answers, Ask scope, Cloudflare SMS gateway, external SMS cloud service and retired cloud redactor.

The retired `WaffraSmsCloudService.hasConsent()` is hardwired false, `analyzeIfConsented()` returns null; `WaffraCloudflareSmsGateway.configured` is false and `analyze()` returns null even if a stale build supplies a URL; Android permissions onboarding erases the old `waffra_cloud_sms_installation_consent_v2` preference. The live local `WaffraSmsIntelligence` and bank SMS parser are retained.

## Safe exceptions and blockers

The historical model/currency helpers still exist for negative tests of ambiguous currency, competing amount and invented model answers. They are **not** exposed through active Home, native SMS processing or Android permission flow. This static finding is not proof of an actual APK/network trace, an Android device layout, original phone backup, or the old spouse archive. Separate encrypted backup/cloud vault features unrelated to retired *SMS analysis* are not removed. Do not claim that every obsolete AI source file has been deleted.
