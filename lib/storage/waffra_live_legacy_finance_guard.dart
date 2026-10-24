import 'package:shared_preferences/shared_preferences.dart';

/// A real, fail-closed guard for the CURRENT Waffra finance source.
///
/// Existing application and quick-add widget routes use SharedPreferences.
/// If any future finance cutover marker appears, these legacy writers must
/// NOT overwrite a newer encrypted vault or silently show an empty balance.
///
/// This is a protection against unsafe *legacy access*, NOT a source
/// activation mechanism. No code here writes markers or opens a new vault.
class WaffraLiveLegacyFinanceGuard {
  const WaffraLiveLegacyFinanceGuard();

  static const activeKey = 'waffra_encrypted_finance_active_v1';
  static const pendingKey = 'waffra_finance_cutover_pending_v1';

  static bool containsCutoverEvidence(SharedPreferences preferences) =>
      preferences.containsKey(activeKey) ||
      preferences.containsKey(pendingKey);

  /// Reload from native storage so a second Flutter engine (quick-add widget)
  /// or previous activation attempt cannot be ignored due to a stale cache.
  Future<void> requireLegacySource(
    SharedPreferences preferences, {
    bool reload = true,
  }) async {
    if (reload) await preferences.reload();
    if (containsCutoverEvidence(preferences)) {
      throw StateError(
        'Finance storage is changing or encrypted storage is active. '
        'Legacy SharedPreferences finance access is blocked to protect data.',
      );
    }
  }
}
