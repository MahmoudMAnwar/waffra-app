/// Non-destructive, Flutter-independent preflight for legacy Waffra financial data.
////
//// This module deliberately does not write preferences, SQLite, files or cloud.
//// Call it with a stable copy of all legacy SharedPreferences values while
//// application financial writers are paused. It is the first executable step
//// of the migration, NOT a completed migration or an encryption implementation.
library;

import 'dart:convert';

const Map<String, String> waffraLegacyArrayKeys = {
  'entries': 'ledger_entries',
  'waffra_categories_v24': 'categories',
  'waffra_goals_v24': 'saving_goals',
  'waffra_recurring_v24': 'recurring_bills',
  'waffra_challenges_v1': 'saving_challenges',
  'waffra_deleted_categories_v1': 'deleted_categories',
  'waffra_deleted_goals_v1': 'deleted_goals',
  'waffra_deleted_recurring_v1': 'deleted_recurring',
};

const Set<String> waffraLegacyMapKeys = {
  'waffra_recurring_postponed_v1',
  'waffra_learned_merchants_v1',
};

const Set<String> waffraLegacyScalarKeys = {
  'waffra_monthly_budget_v1',
  'waffra_monthly_budget_enabled_v1',
  'waffra_recurring_reminders_enabled_v1',
};

class WaffraLegacyIssue {
  const WaffraLegacyIssue(this.sourceKey, this.index, this.code);
  final String sourceKey;
  final int? index;
  final String code;

  @override
  String toString() => '$sourceKey[${index ?? '-'}]: $code';
}

class WaffraLegacyPreflight {
  const WaffraLegacyPreflight({
    required this.counts,
    required this.issues,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.receiptReferences,
    required this.missingKeys,
  });

  final Map<String, int> counts;
  final List<WaffraLegacyIssue> issues;
  final int incomeMinor;
  final int expenseMinor;
  final int receiptReferences;
  final List<String> missingKeys;

  /// Cutover requires this plus encrypted DB parity checks and a safe journal.
  bool get canStage => issues.isEmpty;

  /// Never include raw transaction names, SMS messages or receipt paths.
  Map<String, Object> get safeDiagnostics => {
    'counts': counts,
    'issueCodes': issues.map((e) => e.code).toList(growable: false),
    'incomeMinor': incomeMinor,
    'expenseMinor': expenseMinor,
    'receiptReferences': receiptReferences,
    'missingKeys': missingKeys,
    'canStage': canStage,
  };
}

class WaffraLegacySnapshotInspector {
  const WaffraLegacySnapshotInspector();

  /// A double is converted only if its binary representation is within
  /// floating-point tolerance of an exact 2-decimal SAR amount.
  /// This is a *validation* rule, not a silently rounding migration.
  static int? amountToHalalas(Object? amount) {
    if (amount is! num || !amount.isFinite || amount < 0) return null;
    final scaled = amount * 100;
    if (!scaled.isFinite || scaled > 9007199254740991) return null;
    final rounded = scaled.round();
    if ((scaled - rounded).abs() > 1e-7) return null;
    return rounded;
  }

  static List<String> receiptPaths(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List || decoded.any((e) => e is! String)) return const [];
        return decoded.cast<String>().where((e) => e.isNotEmpty).toList();
      } on FormatException {
        return const [];
      }
    }
    return [raw];
  }

  WaffraLegacyPreflight inspect(Map<String, Object?> snapshot) {
    final counts = <String, int>{};
    final issues = <WaffraLegacyIssue>[];
    final missing = <String>[];
    var income = 0, expense = 0, receipts = 0;

    for (final key in waffraLegacyArrayKeys.keys) {
      if (!snapshot.containsKey(key)) {
        missing.add(key);
        counts[key] = 0;
        continue;
      }
      final raw = snapshot[key];
      Object? decoded;
      try {
        decoded = raw is String ? jsonDecode(raw) : null;
      } on FormatException {
        issues.add(WaffraLegacyIssue(key, null, 'invalid_json'));
        continue;
      }
      if (decoded is! List) {
        issues.add(WaffraLegacyIssue(key, null, 'not_array'));
        continue;
      }
      counts[key] = decoded.length;
      final ids = <String>{};
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map<String, dynamic>) {
          issues.add(WaffraLegacyIssue(key, i, 'not_object'));
          continue;
        }
        final deleted = key.startsWith('waffra_deleted_');
        final kind = deleted
            ? (key == 'waffra_deleted_categories_v1'
                ? 'category'
                : key == 'waffra_deleted_goals_v1'
                    ? 'goal'
                    : 'recurring')
            : null;
        final data = deleted ? item[kind] : item;
        if (data is! Map<String, dynamic>) {
          issues.add(WaffraLegacyIssue(key, i, 'missing_payload'));
          continue;
        }
        if (deleted && DateTime.tryParse('${item['deletedAt'] ?? ''}') == null) {
          issues.add(WaffraLegacyIssue(key, i, 'invalid_deleted_at'));
        }
        final id = data['id'];
        if (id is! String || id.trim().isEmpty) {
          issues.add(WaffraLegacyIssue(key, i, 'missing_id'));
        } else if (!ids.add(id)) {
          issues.add(WaffraLegacyIssue(key, i, 'duplicate_id'));
        }
        final isMoney = key == 'entries';
        final amountFields = <String>[
          if (isMoney || key == 'waffra_recurring_v24') 'amount',
          if (key == 'waffra_goals_v24') ...['target', 'saved'],
          if (key == 'waffra_challenges_v1') 'dailyAmount',
        ];
        for (final field in amountFields) {
          if (amountToHalalas(data[field]) == null) {
            issues.add(WaffraLegacyIssue(key, i, 'invalid_$field'));
          }
        }
        if (key == 'waffra_goals_v24' && amountToHalalas(data['target']) == 0) {
          issues.add(WaffraLegacyIssue(key, i, 'zero_goal_target'));
        }
        if (isMoney) {
          final amount = amountToHalalas(data['amount']);
          if (data['income'] is! bool) {
            issues.add(WaffraLegacyIssue(key, i, 'invalid_income_flag'));
          }
          final originalDate = data['date'];
          if (originalDate is! String ||
              DateTime.tryParse(originalDate) == null ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(originalDate)) {
            issues.add(WaffraLegacyIssue(key, i, 'invalid_date'));
          }
          if (amount != null && data['income'] is bool) {
            if (data['income'] == true) {
              income += amount;
            } else {
              expense += amount;
            }
          }
          final receipt = data['receiptPath'];
          if (receipt != null && receipt is! String) {
            issues.add(WaffraLegacyIssue(key, i, 'invalid_receipt_format'));
          } else if (receipt is String && receipt.isNotEmpty) {
            final paths = receiptPaths(receipt);
            if (paths.isEmpty) {
              issues.add(WaffraLegacyIssue(key, i, 'invalid_receipt_format'));
            } else {
              receipts += paths.length;
            }
          }
        }
        if (key == 'waffra_recurring_v24') {
          final day = data['day'];
          if (day is! int || day < 1 || day > 31) {
            issues.add(WaffraLegacyIssue(key, i, 'invalid_due_day'));
          }
        }
      }
    }

    for (final key in waffraLegacyMapKeys) {
      if (!snapshot.containsKey(key)) {
        missing.add(key);
        counts[key] = 0;
        continue;
      }
      try {
        final raw = snapshot[key];
        final decoded = raw is String ? jsonDecode(raw) : null;
        if (decoded is! Map<String, dynamic>) {
          issues.add(WaffraLegacyIssue(key, null, 'not_map'));
        } else {
          counts[key] = decoded.length;
        }
      } on FormatException {
        issues.add(WaffraLegacyIssue(key, null, 'invalid_json'));
      }
    }

    const smsKey = 'waffra_sms_hashes_v1';
    if (!snapshot.containsKey(smsKey)) {
      missing.add(smsKey);
      counts[smsKey] = 0;
    } else {
      final hashes = snapshot[smsKey];
      if (hashes is! List<String>) {
        issues.add(const WaffraLegacyIssue(smsKey, null, 'not_string_list'));
      } else {
        counts[smsKey] = hashes.length;
      }
    }

    for (final key in waffraLegacyScalarKeys) {
      if (!snapshot.containsKey(key)) missing.add(key);
    }

    return WaffraLegacyPreflight(
      counts: Map.unmodifiable(counts),
      issues: List.unmodifiable(issues),
      incomeMinor: income,
      expenseMinor: expense,
      receiptReferences: receipts,
      missingKeys: List.unmodifiable(missing),
    );
  }
}
