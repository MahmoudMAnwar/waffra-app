import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';

/// A screen-facing view of ALL finance fields; app/account/appearance settings
/// deliberately remain in their own SharedPreferences store.
///
/// The active source MUST be chosen by the verified cutover coordinator.
/// Never use an older legacy finance value as fallback for a missing encrypted
/// value: missing and empty are distinct and cross-source mixing loses money.
class WaffraFinanceReadView {
  WaffraFinanceReadView._(Map<String, Object?> values)
      : _values = Map<String, Object?>.unmodifiable(values);

  final Map<String, Object?> _values;

  factory WaffraFinanceReadView.fromLegacy(
    SharedPreferences preferences,
  ) {
    final values = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys) {
      if (!preferences.containsKey(key)) continue;
      final current = preferences.get(key);
      values[key] = current is List<String>
          ? List<String>.unmodifiable(current)
          : current;
    }
    return WaffraFinanceReadView._(values);
  }

  factory WaffraFinanceReadView.fromEncrypted(
    WaffraFinanceSnapshotState snapshot,
  ) {
    final known = WaffraLegacyPreflight.allKeys.toSet();
    final extras = snapshot.values.keys.toSet().difference(known);
    if (extras.isNotEmpty) {
      throw StateError('Encrypted finance snapshot contains unknown keys.');
    }
    return WaffraFinanceReadView._(snapshot.values);
  }

  /// Validate the COMPLETE captured finance source before a live screen uses
  /// any part of it. Missing finance keys are allowed on first install, but
  /// malformed transaction, goal, trash, SMS hash or budget values must never
  /// be silently replaced with defaults and then persisted over old data.
  ///
  /// This is read-only and works for both legacy and encrypted snapshots.
  void requireIntegrity() {
    final result = WaffraLegacyPreflight.inspect(_values);
    if (!result.canStage) {
      throw StateError(
        'Financial source failed integrity validation; recovery is required.',
      );
    }
  }

  bool containsKey(String key) {
    _requireFinanceKey(key);
    return _values.containsKey(key);
  }

  void _requireFinanceKey(String key) {
    if (!WaffraLegacyPreflight.allKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Not a finance field');
    }
  }

  T? _get<T>(String key) {
    _requireFinanceKey(key);
    if (!_values.containsKey(key)) return null;
    final value = _values[key];
    if (value is! T) {
      throw StateError('Finance value $key has an invalid type.');
    }
    return value;
  }

  String? getString(String key) => _get<String>(key);
  double? getDouble(String key) {
    _requireFinanceKey(key);
    if (!_values.containsKey(key)) return null;
    final value = _values[key];
    if (value is! num) {
      throw StateError('Finance value $key is not numeric.');
    }
    return value.toDouble();
  }
  bool? getBool(String key) => _get<bool>(key);
  List<String>? getStringList(String key) {
    final values = _get<List<String>>(key);
    return values == null ? null : List<String>.unmodifiable(values);
  }
}
