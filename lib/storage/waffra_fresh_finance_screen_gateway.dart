import 'dart:convert';

import '../waffra_sms_fx_review.dart';
import '../waffra_sms_multicurrency_review.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_modules_repository.dart';
import 'waffra_fresh_ledger_repository.dart';

/// App-compatible types expressed as JSON maps to avoid importing main.dart
/// into the storage layer. Current MoneyEntry/BudgetCategory/SavingGoal/
/// RecurringBill can all consume the returned shapes using fromJson().
///
/// THIS IS AN EXPERIMENTAL BRIDGE, NOT AN ACTIVE SOURCE SWITCH.
/// It must only run on a proven fresh encrypted vault, under a future durable
/// single-writer storage selector that also covers the Android widget.
class WaffraFinanceScreenState {
  const WaffraFinanceScreenState({
    required this.transactions,
    required this.categories,
    required this.goals,
    required this.recurring,
    required this.totals,
  });

  final List<Map<String, Object?>> transactions;
  final List<Map<String, Object?>> categories;
  final List<Map<String, Object?>> goals;
  final List<Map<String, Object?>> recurring;
  final WaffraFreshLedgerTotals totals;

  /// Only four active collections. Trash, challenges, merchant rules,
  /// reminders, SMS hashes, all settings and receipts have separate gates.
  /// NEVER replace an entire legacy preference snapshot with these four keys.
  Map<String, String> toScreenCollectionJson() => Map.unmodifiable({
    'entries': jsonEncode(transactions),
    'waffra_categories_v24': jsonEncode(categories),
    'waffra_goals_v24': jsonEncode(goals),
    'waffra_recurring_v24': jsonEncode(recurring),
  });
}

/// The next app integration will route HomeScreen reads/writes through this
/// bridge after a crash-safe, per-install activation and cross-process lock.
/// For now, it can only operate on explicitly gated DISPOSABLE SQLCipher vaults.
class WaffraFreshFinanceScreenGateway {
  const WaffraFreshFinanceScreenGateway({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  WaffraFreshLedgerRepository get _ledger => WaffraFreshLedgerRepository(
    store: store, experimentalEnabled: experimentalEnabled,
  );
  WaffraFreshModulesRepository get _modules => WaffraFreshModulesRepository(
    store: store, experimentalEnabled: experimentalEnabled,
  );

  Future<WaffraFinanceScreenState> readForHome() async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    final data = await Future.wait<dynamic>([
      _ledger.list(),
      _modules.list(WaffraFinanceModule.categories),
      _modules.list(WaffraFinanceModule.goals),
      _modules.list(WaffraFinanceModule.recurring),
      _ledger.totals(),
    ]);
    final entries = data[0] as List<WaffraFreshLedgerEntry>;
    final totals = data[4] as WaffraFreshLedgerTotals;
    final income = entries.where((e) => e.isIncome)
        .fold<int>(0, (sum, e) => sum + e.amountMinor);
    final expense = entries.where((e) => !e.isIncome)
        .fold<int>(0, (sum, e) => sum + e.amountMinor);
    if (entries.length != totals.count ||
        income != totals.incomeMinor || expense != totals.expenseMinor) {
      throw StateError('Encrypted home view and SQL totals differ.');
    }
    List<Map<String, Object?>> copy(List<Map<String, Object?>> items) =>
        List<Map<String, Object?>>.unmodifiable(
          items.map((e) => Map<String, Object?>.unmodifiable(e)),
        );
    return WaffraFinanceScreenState(
      transactions: copy(entries.map((e) => e.toLegacyShape()).toList()),
      categories: copy(data[1] as List<Map<String, Object?>>),
      goals: copy(data[2] as List<Map<String, Object?>>),
      recurring: copy(data[3] as List<Map<String, Object?>>),
      totals: totals,
    );
  }

  static WaffraFreshLedgerEntry _entry(Map<String, Object?> item) {
    final id = item['id'], title = item['title'];
    final amount = item['amount'], category = item['category'];
    final income = item['income'], date = item['date'];
    final receipts = item['receiptPath'];
    if (id is! String || id.trim().isEmpty ||
        title is! String || title.trim().isEmpty ||
        category is! String || category.trim().isEmpty ||
        amount is! num ||
        !WaffraLegacyPreflight.canRepresentHalalas(amount) ||
        income is! bool || date is! String ||
        DateTime.tryParse(date) == null) {
      throw ArgumentError('Invalid transaction screen payload.');
    }
    // Receipt paths are not safely installable until activation, archive byte
    // integrity, and file/SQL rollback are unified. Refuse rather than drop.
    if (receipts != null && receipts != '') {
      throw StateError('Receipt-bearing writes need a safe file installer.');
    }
    final fxData = item['waffra_fx_provenance_v1'];
    WaffraSmsFxReview? fx;
    if (fxData != null) {
      if (fxData is! Map<String, dynamic>) {
        throw ArgumentError('Invalid FX provenance payload.');
      }
      fx = WaffraSmsFxReview.fromProvenanceJson(fxData);
    }
    final originalCurrency = item['originalCurrency'];
    if (originalCurrency != null &&
        (originalCurrency is! String ||
         (originalCurrency != 'SAR' && fx == null))) {
      throw StateError('Foreign amount requires verified FX and explicit consent.');
    }
    // This bridge must never turn foreign pasted SMS into unlabelled SAR.
    if (item['sourceType'] == 'sms' && fx == null) {
      final sms = item['protectedOriginalSms'] ?? item['notes'];
      if (sms is String &&
          WaffraSmsCurrencies.requiresReviewForSarLedger(sms)) {
        throw StateError('Unreviewed foreign SMS cannot enter SAR ledger.');
      }
    }
    final entry = WaffraFreshLedgerEntry(
      id: id, title: title, categorySnapshot: category,
      amountMinor: (amount * 100).round(), isIncome: income,
      occurredIso: date,
      fxReview: fx,
    );
    WaffraFreshLedgerRepository.validateExperimentalEntry(entry);
    return entry;
  }

  Future<void> saveTransaction(
    Map<String, Object?> screenRecord, {
    bool replaceExisting = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    final entry = _entry(screenRecord);
    if (replaceExisting) {
      await _ledger.replace(entry);
    } else {
      await _ledger.add(entry);
    }
  }

  Future<void> removeUnattachedTransaction(String id) async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    await _ledger.remove(id);
  }

  Future<void> saveCategory(
    Map<String, Object?> record, {
    bool replaceExisting = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    await _modules.save(
      WaffraFinanceModule.categories, record,
      replaceExisting: replaceExisting,
    );
  }

  Future<void> saveGoal(
    Map<String, Object?> record, {
    bool replaceExisting = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    await _modules.save(
      WaffraFinanceModule.goals, record,
      replaceExisting: replaceExisting,
    );
  }

  Future<void> saveRecurring(
    Map<String, Object?> record, {
    bool replaceExisting = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Finance screen gateway is disabled by default.');
    }
    await _modules.save(
      WaffraFinanceModule.recurring, record,
      replaceExisting: replaceExisting,
    );
  }
}
