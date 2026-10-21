import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';

/// Crash-recoverable whole-dashboard finance batch for the current LEGACY
/// SharedPreferences source. Only call prepare/recover while holding the
/// app-widget file lock in WaffraLegacyFinanceWriterCoordinator.
///
/// A committed journal is a replay intent, not a rollback: each field must
/// still equal either its recorded before or after value. Unexpected values
/// fail closed rather than overwriting newer transactions or goals.
/// This is not SQLCipher, cloud sync or source activation.
class WaffraLegacyFinanceBatchJournal {
  const WaffraLegacyFinanceBatchJournal();

  static const pendingKey = 'waffra_legacy_finance_batch_pending_v1';
  static const maxJournalCharacters = 20 * 1024 * 1024;
  static const _version = 1;

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static bool _supported(String key, Object? value) {
    if (WaffraLegacyPreflight.financeListKeys.contains(key) ||
        WaffraLegacyPreflight.financeMapKeys.contains(key)) {
      return value is String;
    }
    if (WaffraLegacyPreflight.financeListOfStringsKeys.contains(key)) {
      return value is List<String>;
    }
    if (key == 'waffra_monthly_budget_v1') {
      return value is num && value.isFinite && value >= 0;
    }
    if (WaffraLegacyPreflight.financialScalarKeys.contains(key)) {
      return value is bool;
    }
    return false;
  }

  static Map<String, Object?> _cell(String key, Object? value,
      {bool present = true}) {
    if (!present) return <String, Object?>{'present': false};
    if (!_supported(key, value)) {
      throw StateError('Invalid finance type in recoverable batch.');
    }
    if (value is String) {
      return <String, Object?>{
        'present': true, 'kind': 'string', 'value': value,
      };
    }
    if (value is bool) {
      return <String, Object?>{
        'present': true, 'kind': 'bool', 'value': value,
      };
    }
    if (value is num) {
      return <String, Object?>{
        'present': true, 'kind': 'double', 'value': value.toDouble(),
      };
    }
    if (value is List<String>) {
      return <String, Object?>{
        'present': true, 'kind': 'strings', 'value': List<String>.of(value),
      };
    }
    throw StateError('Unsupported recoverable finance type.');
  }

  static Map<String, Object?> _current(
      SharedPreferences prefs, String key) {
    if (!prefs.containsKey(key)) return _cell(key, null, present: false);
    return _cell(key, prefs.get(key));
  }

  static Map<String, Object?> _parseCell(String key, Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Expected a finance journal cell.');
    }
    final value = Map<String, dynamic>.from(raw);
    if (value['present'] == false) {
      if (value.length != 1) {
        throw const FormatException('Malformed absent field.');
      }
      return _cell(key, null, present: false);
    }
    if (value['present'] != true || value.length != 3 ||
        value['kind'] is! String) {
      throw const FormatException('Malformed present field.');
    }
    final kind = value['kind'] as String;
    final field = value['value'];
    if (kind == 'string' && field is String) return _cell(key, field);
    if (kind == 'bool' && field is bool) return _cell(key, field);
    if (kind == 'double' && field is num && field.isFinite) {
      return _cell(key, field.toDouble());
    }
    if (kind == 'strings' && field is List &&
        field.every((v) => v is String)) {
      return _cell(key, field.cast<String>());
    }
    throw const FormatException('Invalid finance journal field value.');
  }

  static bool _matches(
      Map<String, Object?> first, Map<String, Object?> second) =>
      jsonEncode(first) == jsonEncode(second);

  /// First record all before/after fields, then replay under the SAME lock.
  /// The coordinator will replay this after an interrupted app termination.
  Future<void> prepare({
    required SharedPreferences prefs,
    required Map<String, Object> nextValues,
  }) async {
    if (prefs.containsKey(pendingKey)) {
      throw StateError('Unfinished dashboard finance batch needs recovery.');
    }
    final allowed = WaffraLegacyPreflight.allKeys.toSet();
    if (nextValues.isEmpty ||
        nextValues.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Unexpected finance key in dashboard batch.');
    }
    final before = <String, Object?>{};
    final after = <String, Object?>{};
    for (final key in nextValues.keys.toList()..sort()) {
      before[key] = _current(prefs, key);
      after[key] = _cell(key, nextValues[key]);
    }
    final payload = jsonEncode({
      'version': _version,
      'before': before,
      'after': after,
    });
    final envelope = jsonEncode({
      'payload': payload,
      'checksum': _digest(payload),
    });
    if (envelope.length > maxJournalCharacters) {
      throw StateError('Dashboard finance batch journal is too large.');
    }
    if (!await prefs.setString(pendingKey, envelope)) {
      throw StateError('Could not persist the dashboard finance batch intent.');
    }
  }

  /// Replay only previously witnessed values. Two-phase validation BEFORE
  /// mutation ensures a conflicting field prevents any further overwrite.
  Future<bool> recover(SharedPreferences prefs) async {
    if (!prefs.containsKey(pendingKey)) return false;
    final envelopeRaw = prefs.getString(pendingKey);
    if (envelopeRaw == null ||
        envelopeRaw.length > maxJournalCharacters) {
      throw StateError('Invalid dashboard finance batch journal.');
    }
    Map<String, Object?> before;
    Map<String, Object?> after;
    try {
      final decodedEnvelope = jsonDecode(envelopeRaw);
      if (decodedEnvelope is! Map<String, dynamic> ||
          decodedEnvelope.length != 2 ||
          decodedEnvelope['payload'] is! String ||
          decodedEnvelope['checksum'] is! String ||
          _digest(decodedEnvelope['payload'] as String) !=
              decodedEnvelope['checksum']) {
        throw const FormatException('Corrupt batch checksum.');
      }
      final parsed = jsonDecode(decodedEnvelope['payload'] as String);
      if (parsed is! Map<String, dynamic> ||
          parsed.length != 3 || parsed['version'] != _version ||
          parsed['before'] is! Map || parsed['after'] is! Map) {
        throw const FormatException('Malformed batch payload.');
      }
      before = Map<String, Object?>.from(parsed['before'] as Map);
      after = Map<String, Object?>.from(parsed['after'] as Map);
      final allowed = WaffraLegacyPreflight.allKeys.toSet();
      if (after.isEmpty || before.keys.toSet().length != after.length ||
          before.keys.toSet().difference(after.keys.toSet()).isNotEmpty ||
          after.keys.any((key) => !allowed.contains(key))) {
        throw const FormatException('Invalid batch finance keys.');
      }
      for (final key in after.keys) {
        before[key] = _parseCell(key, before[key]);
        after[key] = _parseCell(key, after[key]);
      }
    } catch (error) {
      throw StateError('Cannot safely recover dashboard finances: $error');
    }

    final changed = <String, Map<String, Object?>>{};
    for (final key in after.keys.toList()..sort()) {
      final current = _current(prefs, key);
      final previous = before[key] as Map<String, Object?>;
      final desired = after[key] as Map<String, Object?>;
      if (!_matches(current, previous) && !_matches(current, desired)) {
        throw StateError(
          'Unexpected newer finance field conflicts with pending batch.',
        );
      }
      if (!_matches(current, desired)) changed[key] = desired;
    }

    for (final entry in changed.entries) {
      final key = entry.key;
      final desired = entry.value;
      if (desired['present'] != true) {
        throw StateError('Finance batch cannot silently remove a field.');
      }
      final value = desired['value'];
      final bool saved;
      if (value is String) {
        saved = await prefs.setString(key, value);
      } else if (value is bool) {
        saved = await prefs.setBool(key, value);
      } else if (value is num) {
        saved = await prefs.setDouble(key, value.toDouble());
      } else if (value is List<String>) {
        saved = await prefs.setStringList(key, value);
      } else {
        throw StateError('Invalid finance batch value during recovery.');
      }
      if (!saved) {
        throw StateError('Finance batch replay could not persist a field.');
      }
    }
    if (!await prefs.remove(pendingKey)) {
      throw StateError('Could not complete dashboard finance batch journal.');
    }
    return true;
  }
}
