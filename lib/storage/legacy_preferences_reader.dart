import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';

/// Read-only bridge to Waffra's actual legacy SharedPreferences keys.
///
/// Must be invoked only after **all** financial writers (UI, widget imports,
/// recurring, bulk SMS and background tasks) have been paused. Double-reading
/// detects obvious concurrent changes but DOES NOT replace that write barrier.
class LegacyPreferencesSnapshotReader {
  const LegacyPreferencesSnapshotReader();

  /// The returned map contains only finance data, never login credentials,
  /// PIN hashes, Firebase identity, raw SMS or system app preferences.
  Future<Map<String, Object?>> readOnce(SharedPreferences prefs) async {
    await prefs.reload();
    final values = <String, Object?>{};

    for (final key in WaffraLegacyPreflight.financeListKeys) {
      if (prefs.containsKey(key)) {
        final value = prefs.getString(key);
        if (value == null) {
          throw StateError('Legacy financial key has invalid storage type.');
        }
        values[key] = value;
      }
    }
    for (final key in WaffraLegacyPreflight.financeMapKeys) {
      if (prefs.containsKey(key)) {
        final value = prefs.getString(key);
        if (value == null) {
          throw StateError('Legacy finance map has invalid storage type.');
        }
        values[key] = value;
      }
    }
    for (final key in WaffraLegacyPreflight.financeListOfStringsKeys) {
      if (prefs.containsKey(key)) {
        final value = prefs.getStringList(key);
        if (value == null) {
          throw StateError('Legacy financial hashes have invalid storage type.');
        }
        values[key] = List<String>.unmodifiable(value);
      }
    }
    const budget = 'waffra_monthly_budget_v1';
    if (prefs.containsKey(budget)) {
      // getDouble does not silently coerce Int or String. Fail safely.
      final value = prefs.getDouble(budget);
      if (value == null) throw StateError('Legacy monthly budget has invalid type.');
      values[budget] = value;
    }
    for (final key in const [
      'waffra_monthly_budget_enabled_v1',
      'waffra_recurring_reminders_enabled_v1',
    ]) {
      if (prefs.containsKey(key)) {
        final value = prefs.getBool(key);
        if (value == null) {
          throw StateError('Legacy financial setting has invalid type.');
        }
        values[key] = value;
      }
    }
    return Map.unmodifiable(values);
  }

  /// Returns a stable sample only. Caller must still hold an app-wide write
  /// barrier throughout this operation AND the subsequent encrypted import.
  Future<Map<String, Object?>> readStable(SharedPreferences prefs) async {
    final first = await readOnce(prefs);
    final second = await readOnce(prefs);
    final one = WaffraLegacyPreflight.inspect(first);
    final two = WaffraLegacyPreflight.inspect(second);
    if (!one.canStage || !two.canStage ||
        one.sourceSha256 != two.sourceSha256) {
      throw StateError('Legacy financial snapshot is invalid or changing.');
    }
    return second;
  }
}
