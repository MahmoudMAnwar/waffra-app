import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Read-only, pure-Dart preflight for the legacy SharedPreferences finance keys.
///
/// This deliberately does not open SQLite, modify preferences, move receipts,
/// perform Firebase requests or change the app's active data source.
class WaffraLegacyPreflight {
  static const financeListKeys = <String>[
    'entries',
    'waffra_categories_v24',
    'waffra_goals_v24',
    'waffra_recurring_v24',
    'waffra_challenges_v1',
    'waffra_deleted_categories_v1',
    'waffra_deleted_goals_v1',
    'waffra_deleted_recurring_v1',
  ];

  static const financeMapKeys = <String>[
    'waffra_recurring_postponed_v1',
    'waffra_learned_merchants_v1',
  ];

  static const financeListOfStringsKeys = <String>['waffra_sms_hashes_v1'];

  static const financialScalarKeys = <String>[
    'waffra_monthly_budget_v1',
    'waffra_monthly_budget_enabled_v1',
    'waffra_recurring_reminders_enabled_v1',
  ];

  static const allKeys = <String>[
    ...financeListKeys,
    ...financeMapKeys,
    ...financeListOfStringsKeys,
    ...financialScalarKeys,
  ];

  static WaffraPreflightResult inspect(Map<String, Object?> snapshot) {
    final issues = <WaffraPreflightIssue>[];
    final counts = <String, int>{};
    final ids = <String, Set<String>>{};

    for (final key in financeListKeys) {
      if (!snapshot.containsKey(key)) {
        counts[key] = 0;
        continue;
      }
      final raw = snapshot[key];
      if (raw is! String) {
        issues.add(WaffraPreflightIssue(key, -1, 'expected_json_string'));
        continue;
      }
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        issues.add(WaffraPreflightIssue(key, -1, 'invalid_json'));
        continue;
      }
      if (decoded is! List) {
        issues.add(WaffraPreflightIssue(key, -1, 'expected_array'));
        continue;
      }
      counts[key] = decoded.length;
      final seen = ids.putIfAbsent(key, () => <String>{});
      for (var i = 0; i < decoded.length; i++) {
        final element = decoded[i];
        if (element is! Map) {
          issues.add(WaffraPreflightIssue(key, i, 'expected_object'));
          continue;
        }
        final item = Map<String, dynamic>.from(element);
        final payloadKey = switch (key) {
          'waffra_deleted_categories_v1' => 'category',
          'waffra_deleted_goals_v1' => 'goal',
          'waffra_deleted_recurring_v1' => 'recurring',
          _ => null,
        };
        if (payloadKey != null) {
          if (item['deletedAt'] is! String ||
              DateTime.tryParse(item['deletedAt'] as String) == null) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_deleted_at'));
          }
          if (item[payloadKey] is! Map) {
            issues.add(WaffraPreflightIssue(key, i, 'missing_deleted_payload'));
            continue;
          }
          item
            ..clear()
            ..addAll(Map<String, dynamic>.from(element[payloadKey] as Map));
        }

        final id = item['id'];
        if (id is! String || id.trim().isEmpty) {
          issues.add(WaffraPreflightIssue(key, i, 'missing_id'));
        } else if (!seen.add(id)) {
          issues.add(WaffraPreflightIssue(key, i, 'duplicate_id'));
        }

        if (key == 'entries') {
          _checkMoney(issues, key, i, item, 'amount');
          _checkDate(issues, key, i, item, 'date');
          if (item['income'] is! bool) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_income_flag'));
          }
          final receipt = item['receiptPath'];
          if (receipt != null && receipt is! String) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_receipt_path'));
          } else if (receipt is String && receipt.startsWith('[')) {
            try {
              final decodedPaths = jsonDecode(receipt);
              if (decodedPaths is! List ||
                  decodedPaths.any((e) => e is! String || e.isEmpty)) {
                issues.add(WaffraPreflightIssue(key, i, 'invalid_receipt_list'));
              }
            } catch (_) {
              issues.add(WaffraPreflightIssue(key, i, 'invalid_receipt_list'));
            }
          }
        } else if (key == 'waffra_goals_v24') {
          _checkMoney(issues, key, i, item, 'target', positive: true);
          _checkMoney(issues, key, i, item, 'saved');
        } else if (key == 'waffra_recurring_v24') {
          _checkMoney(issues, key, i, item, 'amount');
          _checkDate(issues, key, i, item, 'startAt');
          final day = item['day'];
          if (day is! int || day < 1 || day > 31) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_due_day'));
          }
        } else if (key == 'waffra_categories_v24') {
          _checkMoney(issues, key, i, item, 'budget');
        } else if (key == 'waffra_challenges_v1') {
          _checkMoney(issues, key, i, item, 'dailyAmount');
        }
      }
    }

    for (final key in financeMapKeys) {
      if (!snapshot.containsKey(key)) {
        counts[key] = 0;
        continue;
      }
      final raw = snapshot[key];
      if (raw is! String) {
        issues.add(WaffraPreflightIssue(key, -1, 'expected_json_string'));
        continue;
      }
      try {
        final value = jsonDecode(raw);
        if (value is! Map) {
          issues.add(WaffraPreflightIssue(key, -1, 'expected_object'));
        } else {
          counts[key] = value.length;
        }
      } catch (_) {
        issues.add(WaffraPreflightIssue(key, -1, 'invalid_json'));
      }
    }

    for (final key in financeListOfStringsKeys) {
      if (!snapshot.containsKey(key)) {
        counts[key] = 0;
        continue;
      }
      final raw = snapshot[key];
      if (raw is! List<String>) {
        issues.add(WaffraPreflightIssue(key, -1, 'expected_string_list'));
      } else {
        counts[key] = raw.length;
      }
    }

    for (final key in financialScalarKeys) {
      if (!snapshot.containsKey(key)) continue;
      final value = snapshot[key];
      if (key == 'waffra_monthly_budget_v1') {
        if (value is! num || !value.isFinite || value < 0 ||
            !canRepresentHalalas(value)) {
          issues.add(WaffraPreflightIssue(key, -1, 'invalid_money'));
        }
      } else if (value is! bool) {
        issues.add(WaffraPreflightIssue(key, -1, 'expected_boolean'));
      }
    }

    // Canonical digest includes key names, absent markers, types and values.
    // This is a checksum for migration idempotency, NOT encryption or a MAC.
    final canonical = <String, Object?>{};
    for (final key in allKeys.toList()..sort()) {
      final value = snapshot[key];
      canonical[key] = snapshot.containsKey(key)
          ? {'present': true, 'type': value.runtimeType.toString(), 'value': value}
          : {'present': false};
    }
    final checksum = sha256.convert(utf8.encode(jsonEncode(canonical))).toString();

    return WaffraPreflightResult(
      sourceSha256: checksum,
      itemCounts: Map.unmodifiable(counts),
      issues: List.unmodifiable(issues),
    );
  }

  static void _checkMoney(List<WaffraPreflightIssue> issues, String key,
      int index, Map<String, dynamic> item, String field,
      {bool positive = false}) {
    final amount = item[field];
    if (amount is! num || !amount.isFinite ||
        (positive ? amount <= 0 : amount < 0) ||
        !canRepresentHalalas(amount)) {
      issues.add(WaffraPreflightIssue(key, index, 'invalid_$field'));
    }
  }

  static void _checkDate(List<WaffraPreflightIssue> issues, String key,
      int index, Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! String || DateTime.tryParse(value) == null) {
      issues.add(WaffraPreflightIssue(key, index, 'invalid_$field'));
    }
  }

  /// Avoid silent precision loss or overflow when converting SAR to halalas.
  static bool canRepresentHalalas(num amount) {
    if (!amount.isFinite || amount < 0 || amount > 90071992547409) {
      return false;
    }
    final scaled = amount * 100;
    return (scaled - scaled.roundToDouble()).abs() < 1e-7;
  }
}

class WaffraPreflightIssue {
  const WaffraPreflightIssue(this.sourceKey, this.index, this.code);
  final String sourceKey;
  final int index;
  final String code;
}

class WaffraPreflightResult {
  const WaffraPreflightResult({
    required this.sourceSha256,
    required this.itemCounts,
    required this.issues,
  });

  final String sourceSha256;
  final Map<String, int> itemCounts;
  final List<WaffraPreflightIssue> issues;

  bool get canStage => issues.isEmpty;
}
