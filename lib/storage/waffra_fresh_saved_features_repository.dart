import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// Optional saved entities for features that used to be read-only projections.
/// Only explicit user opt-in/confirmation can create a durable record. This
/// repository does not attach itself to the live app or collect bank data.
class WaffraFreshSavedFeaturesRepository {
  const WaffraFreshSavedFeaturesRepository({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  Future<void> _ready() async {
    if (!experimentalEnabled) {
      throw StateError('SQLCipher production cutover not approved.');
    }
    await WaffraFreshFinanceDomainSchema.requireReady(store);
  }

  static void _id(String value) {
    if (value.trim().isEmpty || value.length > 256) {
      throw ArgumentError('Invalid entity ID.');
    }
  }

  static void _timestamp(String text) {
    if (text.length < 10 || DateTime.tryParse(text) == null) {
      throw ArgumentError('Invalid entity timestamp.');
    }
  }

  /// Projects are real entities only when the user creates/saves them.
  Future<void> createProject({
    required String id,
    required String title,
    required int targetMinor,
    required String createdAtIso,
    required bool userConfirmed,
  }) async {
    await _ready();
    _id(id);
    _timestamp(createdAtIso);
    if (!userConfirmed || title.trim().isEmpty || targetMinor < 0) {
      throw StateError('Project wallet was not explicitly confirmed.');
    }
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_project_wallets '
        '(project_id,title,target_minor,is_archived,created_at_iso) '
        'VALUES (?,?,?,0,?)',
        [id,title.trim(),targetMinor,createdAtIso],
      );
    });
  }

  Future<void> linkProjectExpense({
    required String projectId,
    required String entryId,
    required int allocatedMinor,
    required bool userConfirmed,
  }) async {
    await _ready();
    _id(projectId);
    _id(entryId);
    if (!userConfirmed || allocatedMinor <= 0) {
      throw StateError('Project allocation needs user confirmation.');
    }
    await store.transaction(() async {
      final project = await store.customSelect(
        'SELECT is_archived FROM fresh_finance_project_wallets '
        'WHERE project_id=?', variables:[Variable.withString(projectId)],
      ).get();
      final entry = await store.customSelect(
        'SELECT is_income,amount_minor FROM fresh_finance_entries '
        'WHERE entry_id=?',variables:[Variable.withString(entryId)],
      ).get();
      if (project.length!=1 || project.single.read<int>('is_archived')!=0 ||
          entry.length!=1 || entry.single.read<int>('is_income')!=0) {
        throw StateError('Project and saved expense must both be active.');
      }
      final allocated=await store.customSelect(
        'SELECT COALESCE(SUM(allocation_minor),0) AS total '
        'FROM fresh_finance_project_wallet_links WHERE entry_id=?',
        variables:[Variable.withString(entryId)],
      ).getSingle();
      if (allocated.read<int>('total')+allocatedMinor >
          entry.single.read<int>('amount_minor')) {
        throw StateError('Project allocations exceed original expense.');
      }
      await store.customStatement(
        'INSERT INTO fresh_finance_project_wallet_links '
        '(project_id,entry_id,allocation_minor) VALUES (?,?,?)',
        [projectId,entryId,allocatedMinor],
      );
    });
  }

  /// Subscription detection alone must never save a bill or post money.
  /// A confirmed subscription has its own immutable ID and can be paused.
  Future<void> confirmSubscription({
    required String id,
    required String merchant,
    required int amountMinor,
    required String currencyCode,
    required int renewalDay,
    required String confirmedAtIso,
    required bool userConfirmed,
    String? categoryId,
  }) async {
    await _ready();
    _id(id);
    _timestamp(confirmedAtIso);
    if (!userConfirmed || merchant.trim().isEmpty || amountMinor <= 0 ||
        currencyCode.length!=3 || renewalDay<1 || renewalDay>31) {
      throw StateError('Invalid or unconfirmed subscription.');
    }
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_confirmed_subscriptions '
        '(subscription_id,merchant_label,amount_minor,currency_code,'
        'renewal_day,status,confirmed_at_iso,linked_category_id) '
        "VALUES (?,?,?,?,?,'confirmed',?,?)",
        [id,merchant.trim(),amountMinor,currencyCode.toUpperCase(),
         renewalDay,confirmedAtIso,categoryId],
      );
    });
  }

  Future<void> pauseSubscription(String id,{required bool paused}) async {
    await _ready();
    _id(id);
    await store.transaction(() async {
      final exists=await store.customSelect(
        'SELECT status FROM fresh_finance_confirmed_subscriptions '
        'WHERE subscription_id=?',variables:[Variable.withString(id)],
      ).get();
      if (exists.length!=1 ||
          exists.single.read<String>('status')=='cancelled') {
        throw StateError('Subscription does not exist or is cancelled.');
      }
      await store.customStatement(
        'UPDATE fresh_finance_confirmed_subscriptions SET status=? '
        'WHERE subscription_id=?',
        [paused ? 'paused' : 'confirmed',id],
      );
    });
  }

  /// Saving a hypothetical scenario never changes actual ledger money.
  Future<void> saveScenario({
    required String id,
    required String kind,
    required String name,
    required Map<String,Object?> values,
    required String savedAtIso,
    required bool userConfirmed,
  }) async {
    await _ready();
    _id(id);
    _timestamp(savedAtIso);
    if (!userConfirmed || !const {
      'affordability','before_spend','safety_buffer','seasonal','challenge',
    }.contains(kind) || name.trim().isEmpty) {
      throw StateError('Scenario is not confirmed.');
    }
    final payload=jsonEncode(values);
    if (payload.length>50000) throw ArgumentError('Scenario is too large.');
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_saved_scenarios '
        '(scenario_id,kind,name,payload_json,saved_at_iso) VALUES (?,?,?,?,?)',
        [id,kind,name.trim(),payload,savedAtIso],
      );
    });
  }

  /// Ask Waffra responses remain ephemeral by default: only a user-enabled
  /// local chat-history setting may write message text to encrypted storage.
  Future<void> startAiThread({
    required String id,
    required String title,
    required String createdAtIso,
    required bool saveHistoryOptIn,
  }) async {
    await _ready();
    _id(id);
    _timestamp(createdAtIso);
    if (!saveHistoryOptIn) throw StateError('AI chat history is disabled.');
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_ai_threads '
        '(thread_id,title,user_opted_in,created_at_iso) VALUES (?,?,1,?)',
        [id,title,createdAtIso],
      );
    });
  }

  Future<void> appendAiMessage({
    required String id,
    required String threadId,
    required String role,
    required String text,
    required String occurredAtIso,
    required bool saveHistoryOptIn,
  }) async {
    await _ready();
    _id(id);
    _id(threadId);
    _timestamp(occurredAtIso);
    if (!saveHistoryOptIn || !const {'user','assistant'}.contains(role) ||
        text.isEmpty || text.length>20000) {
      throw StateError('AI message must be explicitly authorized.');
    }
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_ai_messages '
        '(message_id,thread_id,role,content,occurred_at_iso) '
        'VALUES (?,?,?,?,?)',
        [id,threadId,role,text,occurredAtIso],
      );
    });
  }

  /// Historical price caching requires a named data provider and explicit
  /// opt-in. It must never create real finance entries or claim live prices.
  Future<void> recordPriceObservation({
    required String id,
    required String instrument,
    required String currency,
    required int priceMicro,
    required String source,
    required String observedAtIso,
    required bool cacheApproved,
  }) async {
    await _ready();
    _id(id);
    _timestamp(observedAtIso);
    if (!cacheApproved || instrument.trim().isEmpty || source.trim().isEmpty ||
        currency.length!=3 || priceMicro<0) {
      throw StateError('Invalid price observation or no local cache consent.');
    }
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_price_observations '
        '(observation_id,instrument,currency_code,price_micro,'
        'source_label,observed_at_iso) VALUES (?,?,?,?,?,?)',
        [id,instrument,currency.toUpperCase(),priceMicro,
         source,observedAtIso],
      );
    });
  }
}
