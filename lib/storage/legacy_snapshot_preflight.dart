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
    'waffra_named_budgets_v1',
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
          final budgetId=item['budgetId'];
          if(budgetId != null &&
             (budgetId is! String || budgetId.trim().isEmpty ||
              budgetId.length > 256 || item['income']==true)) {
            issues.add(WaffraPreflightIssue(key,i,'invalid_budget_assignment'));
          }
          // The wallet-funded portion is a verified property of a confirmed
          // goal-due ledger event, never inferred from mutable notes.
          final walletMinor=item['goalWalletPaidMinor'];
          if(walletMinor!=null) {
            final gross=item['amount'];
            if(item['sourceType']!='goal_due'||item['income']!=false||
               walletMinor is! int||walletMinor<0||gross is! num||
               !gross.isFinite||gross<0||
               walletMinor>(gross*100).round()) {
              issues.add(WaffraPreflightIssue(
                key,i,'invalid_goal_wallet_allocation'));
            }
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
          if (item['dueDate'] != null &&
              (item['dueDate'] is! String ||
               DateTime.tryParse(item['dueDate'] as String) == null)) {
            issues.add(WaffraPreflightIssue(key,i,'invalid_goal_due_date'));
          }
        } else if (key == 'waffra_recurring_v24') {
          _checkMoney(issues, key, i, item, 'amount');
          _checkDate(issues, key, i, item, 'startAt');
          if(item['linkedGoalId'] != null &&
             (item['linkedGoalId'] is! String ||
              (item['linkedGoalId'] as String).trim().isEmpty ||
              (item['linkedGoalId'] as String).length > 256)){
            issues.add(WaffraPreflightIssue(key,i,'invalid_linked_goal_id'));
          }
          final day = item['day'];
          if (day is! int || day < 1 || day > 31) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_due_day'));
          }
        } else if (key == 'waffra_categories_v24') {
          _checkMoney(issues, key, i, item, 'budget');
          if(item['budgetLabel'] != null &&
             (item['budgetLabel'] is! String ||
              (item['budgetLabel'] as String).length > 80)){
            issues.add(WaffraPreflightIssue(key,i,'invalid_budget_label'));
          }
        } else if (key == 'waffra_named_budgets_v1') {
          _checkMoney(issues, key, i, item, 'budget', positive: true);
          final name = item['name'];
          if (name is! String || name.trim().isEmpty ||
              name.runes.length > 80 || item['income'] != false ||
              item['parentId'] != '') {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_standalone_budget'));
          }
          if (item['budgetActive'] is! bool ||
              item['alertPercent'] is! int ||
              (item['alertPercent'] as int) < 1 ||
              (item['alertPercent'] as int) > 100) {
            issues.add(WaffraPreflightIssue(key, i, 'invalid_budget_controls'));
          }
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
    // DateTime.tryParse normalizes some impossible dates (e.g. 2026-02-30)
    // to the following month. For a money ledger, that is data corruption:
    // require the exact ISO calendar date to survive parsing unchanged.
    bool valid() {
      if (value is! String) return false;
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ].*)?$')
          .firstMatch(value);
      if (iso == null) return false;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return false;
      // DateTime.tryParse converts offset-bearing timestamps to UTC.
      // Compare the recorded *calendar date* instead: a valid local
      // 2026-11-01T00:15:00+03:00 becomes 2026-10-31 in UTC.
      // A UTC calendar constructor still rejects normalized impossible
      // dates such as 2026-02-30 by checking the exact components.
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      final calendar = DateTime.utc(year, month, day);
      return calendar.year == year &&
          calendar.month == month &&
          calendar.day == day;
    }
    if (!valid()) {
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
