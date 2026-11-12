import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'legacy_financial_snapshot.dart' show WaffraLegacySnapshotInspector;
import 'waffra_accounts_finance_history.dart';
import 'waffra_accounts_portable_backup_v3.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_finance_domain_legacy_importer.dart';
import 'waffra_fresh_finance_modules_repository.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

/// A cold-verifiable, accountless V3 restore candidate built from an already
/// authenticated V24 user backup. Never touches the live financial source.
/// This does NOT perform a legacy device in-place migration.
class WaffraLegacyV24RestoreCandidate {
  const WaffraLegacyV24RestoreCandidate({
    required this.encryptedV3,
    required this.transactionCount,
    required this.unavailableReceiptCount,
  });
  final String encryptedV3;
  final int transactionCount;
  final int unavailableReceiptCount;
}

/// Bridge old, encrypted user exports to the existing independently verified
/// V3 rescue/preflight/atomic SQLCipher restore pipeline. Import is opt-in.
/// Do not persist decrypted text, personal metadata, passwords or source paths.
abstract final class WaffraLegacyV24SqlCipherConverter {
  static Map<String, Object?> _requireV24(Map<String, dynamic> payload) {
    if (payload['format'] != 'waffra-backup' || payload['version'] != 24) {
      throw const FormatException('Unsupported legacy backup version.');
    }
    const requiredLists = [
      'entries', 'categories', 'goals', 'recurring',
    ];
    for (final key in requiredLists) {
      if (payload[key] is! List) {
        throw FormatException('Missing legacy backup collection: $key.');
      }
    }
    if (payload['namedBudgets'] != null && payload['namedBudgets'] is! List) {
      throw const FormatException('Invalid legacy budgets.');
    }
    for (final key in [
      'challenges', 'deletedCategories', 'deletedGoals', 'deletedRecurring',
    ]) {
      if (payload[key] != null && payload[key] is! List) {
        throw FormatException('Invalid legacy backup collection: $key.');
      }
    }
    if (payload['smsHashes'] != null &&
        (payload['smsHashes'] is! List ||
         (payload['smsHashes'] as List).any((v) =>
           v is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(v)))) {
      throw const FormatException('Invalid historical SMS deduplication keys.');
    }
    if (payload['recurringPostponed'] != null &&
        payload['recurringPostponed'] is! Map) {
      throw const FormatException('Invalid recurring postponements.');
    }
    if (payload['learnedMerchants'] != null &&
        payload['learnedMerchants'] is! Map) {
      throw const FormatException('Invalid merchant rules.');
    }
    final categories = payload['categories'] as List;
    if (categories.isEmpty || categories.any((v) => v is! Map)) {
      throw const FormatException('Missing valid category inventory.');
    }
    for (final key in ['entries', 'goals', 'recurring', 'namedBudgets',
      'challenges', 'deletedCategories', 'deletedGoals', 'deletedRecurring']) {
      if ((payload[key] as List? ?? const []).any((v) => v is! Map)) {
        throw FormatException('Malformed historical collection: $key.');
      }
    }
    return <String, Object?>{
      'entries': payload['entries'],
      'categories': categories,
      'namedBudgets': payload['namedBudgets'] ?? <Object>[],
      'goals': payload['goals'],
      'recurring': payload['recurring'],
      'challenges': payload['challenges'] ?? <Object>[],
      'deletedCategories': payload['deletedCategories'] ?? <Object>[],
      'deletedGoals': payload['deletedGoals'] ?? <Object>[],
      'deletedRecurring': payload['deletedRecurring'] ?? <Object>[],
      'recurringPostponed': payload['recurringPostponed'] ?? <String, Object?>{},
      'learnedMerchants': payload['learnedMerchants'] ?? <String, Object?>{},
      'smsHashes': payload['smsHashes'] ?? <String>[],
      'monthlyBudget': payload['monthlyBudget'] ?? 0.0,
      'monthlyBudgetEnabled': payload['monthlyBudgetEnabled'] ??
        ((payload['monthlyBudget'] as num? ?? 0)>0),
    };
  }

  static int unavailableReceiptCount(Map<String, dynamic> payload) {
    final data = _requireV24(payload);
    var count = 0;
    for (final item in data['entries'] as List) {
      final row = Map<String, dynamic>.from(item as Map);
      count += WaffraLegacySnapshotInspector.receiptPaths(
        row['receiptPath']).length;
    }
    return count;
  }

  static int _minor(Object? raw) {
    if (raw is! num || !raw.isFinite || raw <= 0 ||
        raw > 90071992547409 || ((raw * 100).round() - raw * 100).abs() > 0.00001) {
      throw const FormatException('Invalid historical budget amount.');
    }
    return (raw * 100).round();
  }

  static Future<WaffraLegacyV24RestoreCandidate> prepare({
    required Map<String, dynamic> payload,
    required String password,
    required bool userApprovedMissingReceipts,
  }) async {
    final legacy = _requireV24(payload);
    final entries = (legacy['entries'] as List)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList(growable: false);
    final missing = unavailableReceiptCount(payload);
    if (missing != 0 && !userApprovedMissingReceipts) {
      throw StateError('Legacy backup has path-only receipts; permission required.');
    }

    // Old V24 exports only contain path references, NEVER the receipt bytes.
    // An explicit, separate user warning permits restoring the finance record
    // without promising to restore the unavailable images. Keep ALL entry
    // identities, amounts and history; never fabricate a receipt BLOB.
    final normalizedEntries = [
      for (final row in entries)
        if (WaffraLegacySnapshotInspector.receiptPaths(
              row['receiptPath']).isNotEmpty)
          {...row, 'receiptPath': ''}
        else row,
    ];
    final hashes = List<String>.from(legacy['smsHashes'] as List);
    if (hashes.toSet().length != hashes.length) {
      throw const FormatException('Duplicate historical SMS fingerprint.');
    }
    final financial = <String, Object?>{
      'entries': jsonEncode(normalizedEntries),
      'waffra_categories_v24': jsonEncode(legacy['categories']),
      'waffra_named_budgets_v1': jsonEncode(legacy['namedBudgets']),
      'waffra_goals_v24': jsonEncode(legacy['goals']),
      'waffra_recurring_v24': jsonEncode(legacy['recurring']),
      'waffra_challenges_v1': jsonEncode(legacy['challenges']),
      'waffra_deleted_categories_v1': jsonEncode(legacy['deletedCategories']),
      'waffra_deleted_goals_v1': jsonEncode(legacy['deletedGoals']),
      'waffra_deleted_recurring_v1': jsonEncode(legacy['deletedRecurring']),
      'waffra_recurring_postponed_v1':
        jsonEncode(legacy['recurringPostponed']),
      'waffra_monthly_budget_v1': legacy['monthlyBudget']!,
      'waffra_monthly_budget_enabled_v1': legacy['monthlyBudgetEnabled']!,
      'waffra_learned_merchants_v1': jsonEncode(legacy['learnedMerchants']),
      'waffra_sms_hashes_v1': hashes,
    };
    // V2 creation authenticates the exact whitelisted financial keys and
    // validates entries before the first SQLCipher staging write.
    final encryptedV2 = await WaffraPortableBackupV2.create(
      financialSnapshot: financial,
      receipts: const <WaffraReceiptBackupPart>[],
      password: password,
    );
    final staging = await Directory.systemTemp.createTemp('waffra-v24-to-v3-');
    final key = base64UrlEncode(List<int>.generate(
      32, (_) => Random.secure().nextInt(256)));
    WaffraEncryptedStore? db;
    try {
      db = WaffraEncryptedStore.openAt(
        File('${staging.path}/legacy-candidate.sqlite'), key: key);
      final restored = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: db, experimentalEnabled: true,
      ).restore(encryptedArchive: encryptedV2, password: password);
      if (restored.transactionCount != normalizedEntries.length ||
          restored.receiptCount != 0) {
        throw StateError('Legacy ledger parity was not preserved.');
      }
      final module = WaffraFreshModulesRepository(
        store: db, experimentalEnabled: true);
      final categories = (legacy['categories'] as List)
        .map((v) => Map<String, Object?>.from(v as Map))
        .toList(growable: false);
      // Parent consistency triggers require roots before children.
      for (final c in categories.where((v) =>
          (v['parentId'] as String? ?? '').isEmpty)) {
        await module.save(WaffraFinanceModule.categories, c);
      }
      for (final c in categories.where((v) =>
          (v['parentId'] as String? ?? '').isNotEmpty)) {
        await module.save(WaffraFinanceModule.categories, c);
      }
      for (final raw in legacy['goals'] as List) {
        await module.save(WaffraFinanceModule.goals,
          Map<String, Object?>.from(raw as Map));
      }
      for (final raw in legacy['recurring'] as List) {
        await module.save(WaffraFinanceModule.recurring,
          Map<String, Object?>.from(raw as Map));
      }
      final stamp = DateTime.now().toUtc().toIso8601String();
      // Keep original source-json budgets and their owner classification.
      for (final raw in legacy['namedBudgets'] as List) {
        final b = Map<String, Object?>.from(raw as Map);
        final id = b['id'];
        final name = b['name'];
        if (id is! String || id.trim().isEmpty ||
            name is! String || name.trim().isEmpty) {
          throw const FormatException('Invalid named historical budget.');
        }
        final amount = _minor(b['budget']);
        final alert = b['alertPercent'] is int ? b['alertPercent'] as int : 80;
        if (alert < 1 || alert > 100 || b['income'] != false) {
          throw const FormatException('Invalid legacy budget category.');
        }
        final parentId = b['parentId'] as String? ?? '';
        if (parentId.isEmpty) {
          await db.customStatement(
            'INSERT INTO fresh_finance_standalone_budgets '
            '(budget_id,name,monthly_limit_minor,is_active,alert_percent,'
            'created_at_iso,source_json) VALUES (?,?,?,?,?,?,?)',
            [id, name, amount, b['budgetActive'] == false ? 0 : 1,
             alert, stamp, jsonEncode(b)],
          );
        } else {
          await db.customStatement(
            'INSERT INTO fresh_finance_named_budgets '
            '(budget_id,name,category_id,monthly_limit_minor,is_active,'
            'alert_percent,created_at_iso,source_json) '
            'VALUES (?,?,?,?,?,?,?,?)',
            [id, name, parentId, amount,
             b['budgetActive'] == false ? 0 : 1, alert, stamp, jsonEncode(b)],
          );
        }
      }
      await WaffraFinanceDomainLegacyImporter(
        store: db, experimentalEnabled: true,
      ).importCapturedDomain(explicitlyAuthorized: true, importedAtIso: stamp);
      // V24 budgetId is a prior user-confirmed association, not a new guess.
      // Recreate exact historical links in typed SQL without a second expense.
      // The same source_json retains every old budgetId for parity checks.
      final budgetsById = <String, Map<String, Object?>>{
        for (final raw in legacy['namedBudgets'] as List)
          (raw as Map)['id'] as String: Map<String, Object?>.from(raw),
      };
      for (final row in normalizedEntries) {
        final budgetId = row['budgetId'];
        if (budgetId == null || budgetId == '') continue;
        if (budgetId is! String || !budgetsById.containsKey(budgetId) ||
            row['income'] != false || row['id'] is! String) {
          throw const FormatException('Historical budget association is not verifiable.');
        }
        final budget = budgetsById[budgetId]!;
        final minor = _minor(row['amount']);
        final isStandalone = (budget['parentId'] as String? ?? '').isEmpty;
        if (isStandalone) {
          await db.customStatement(
            'INSERT INTO fresh_finance_standalone_allocations '
            '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
            'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
            ['v24-standalone:${row['id']}',budgetId,row['id'],minor,stamp]);
        } else {
          await db.customStatement(
            'INSERT INTO fresh_finance_budget_allocations '
            '(allocation_id,budget_id,entry_id,amount_minor,'
            'explicitly_confirmed,assigned_at_iso) VALUES (?,?,?,?,1,?)',
            ['v24-named:${row['id']}',budgetId,row['id'],minor,stamp]);
        }
      }
      final history = await WaffraAccountsFinanceHistory.capture(db);
      final candidate = await WaffraAccountsPortableBackupV3.bundle(
        encryptedV2: encryptedV2,
        capturedAccounts: <String, Object?>{
          'accounts': <Map<String, Object?>>[],
          'links': <Map<String, Object?>>[],
          'transfers': <Map<String, Object?>>[],
        },
        history: history,
        password: password,
      );
      return WaffraLegacyV24RestoreCandidate(
        encryptedV3: candidate, transactionCount: normalizedEntries.length,
        unavailableReceiptCount: missing);
    } finally {
      try {
        if (db != null) await db.close();
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    }
  }
}
