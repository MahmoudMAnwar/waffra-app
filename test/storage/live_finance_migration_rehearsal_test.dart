import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_finance_migration_rehearsal.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() =>
      WaffraAtomicFinanceSnapshot(store: vault, experimentalEnabled: true);

  WaffraFinanceMigrationRehearsal rehearsal({bool enabled = true}) =>
      WaffraFinanceMigrationRehearsal(
        encrypted: snapshot(),
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: root,
        ),
        experimentalEnabled: enabled,
      );

  String entries({String? receiptPath}) => jsonEncode([
    {
      'id': 'transaction-one',
      'title': 'شراء تجريبي',
      'category': 'طعام',
      'amount': 15.25,
      'income': false,
      'date': '2026-10-21T16:00:00',
      'receiptPath': receiptPath,
    },
    {
      'id': 'transaction-two',
      'title': 'راتب',
      'category': 'راتب',
      'amount': 3900.0,
      'income': true,
      'date': '2026-10-20T16:00:00',
      'receiptPath': null,
    },
  ]);

  Map<String, Object> existingPreferences({String? receiptPath}) => {
    'entries': entries(receiptPath: receiptPath),
    'waffra_categories_v24': jsonEncode([
      {'id': 'food', 'name': 'طعام', 'budget': 400, 'income': false},
    ]),
    'waffra_goals_v24': jsonEncode([
      {'id': 'travel', 'name': 'سفر', 'target': 5000, 'saved': 125},
    ]),
    'waffra_recurring_v24': jsonEncode([
      {
        'id': 'internet',
        'title': 'إنترنت',
        'amount': 100,
        'day': 15,
        'startAt': '2026-10-21T16:00:00',
      },
    ]),
    'waffra_sms_hashes_v1': <String>['prior-message-digest'],
    'waffra_monthly_budget_v1': 2200.75,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_deleted_goals_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_language': 'ar',
    'waffra_appearance_mode_v1': 'dark',
    'waffra_profile': '{"local":true}',
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('waffra-live-rehearsal-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/isolated-finance.sqlite'),
      key: 'test-only-isolated-finance-key-2026',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('empty installation stages empty vault without touching preferences',
      () async {
    final report = await rehearsal().run();
    expect(report.itemCounts['entries'], 0);
    expect(report.stagedGeneration, 1);
    expect(report.legacyReceiptReferences, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect((await snapshot().read()).values, isEmpty);
  });

  test('preserves all finance collections and non-finance app settings',
      () async {
    final original = existingPreferences();
    SharedPreferences.setMockInitialValues(original);
    final report = await rehearsal().run();
    expect(report.itemCounts['entries'], 2);
    expect(report.itemCounts['waffra_goals_v24'], 1);
    expect(report.itemCounts['waffra_recurring_v24'], 1);
    expect(report.legacyReceiptReferences, 0);
    expect(report.encryptedDigest, (await snapshot().read()).digest);
    expect((await snapshot().read()).values['waffra_goals_v24'],
        original['waffra_goals_v24']);
    expect((await snapshot().read()).values['waffra_sms_hashes_v1'],
        ['prior-message-digest']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), original['entries']);
    expect(prefs.getString('waffra_profile'), original['waffra_profile']);
    expect(prefs.getString('waffra_language'), 'ar');
    expect(prefs.getString('waffra_appearance_mode_v1'), 'dark');
    expect(prefs.getKeys().contains(
      WaffraLiveLegacyFinanceGuard.activeKey,
    ), isFalse);
    expect(prefs.getKeys().contains(
      WaffraLiveLegacyFinanceGuard.pendingKey,
    ), isFalse);
  });

  test('receipt references are reported, not claimed as copied', () async {
    SharedPreferences.setMockInitialValues(
      existingPreferences(receiptPath: '/old/photo.jpg'),
    );
    final result = await rehearsal().run();
    expect(result.legacyReceiptReferences, 1);
    expect(result.needsReceiptMigration, isTrue);
    expect((await snapshot().read()).values['entries'],
        entries(receiptPath: '/old/photo.jpg'));
  });

  test('zero finance transactions still protects legacy goal data', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_goals_v24': jsonEncode([
        {'id': 'emergency', 'name': 'طوارئ', 'target': 2000, 'saved': 250},
      ]),
    });
    final result = await rehearsal().run();
    expect(result.itemCounts['entries'], 0);
    expect(result.itemCounts['waffra_goals_v24'], 1);
    expect((await snapshot().read()).values['waffra_goals_v24'],
        contains('emergency'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_goals_v24'), contains('emergency'));
  });

  test('preflight failure refuses migration with source unchanged', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"invalid","amount":1.005}]',
    });
    await expectLater(rehearsal().run(), throwsA(isA<StateError>()));
    expect((await snapshot().initializeEmpty()).generation, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('1.005'));
  });

  test('existing encrypted vault never overwritten by a new rehearsal',
      () async {
    SharedPreferences.setMockInitialValues(existingPreferences());
    final report = await rehearsal().run();
    await expectLater(rehearsal().run(), throwsA(isA<StateError>()));
    expect((await snapshot().read()).digest, report.encryptedDigest);
  });

  test('disconnected or interrupted encrypted activation blocks the copy',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.pendingKey: true,
    });
    await expectLater(rehearsal().run(), throwsA(isA<StateError>()));
    expect((await snapshot().initializeEmpty()).generation, 0);
  });

  test('experimental feature flag is disabled by default', () async {
    SharedPreferences.setMockInitialValues(existingPreferences());
    await expectLater(
      rehearsal(enabled: false).run(),
      throwsA(isA<StateError>()),
    );
    expect((await snapshot().initializeEmpty()).values, isEmpty);
  });

  test('encrypted rehearsal survives cold reopening without any cutover',
      () async {
    SharedPreferences.setMockInitialValues(existingPreferences());
    final report = await rehearsal().run();
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/isolated-finance.sqlite'),
      key: 'test-only-isolated-finance-key-2026',
    );
    final saved = await snapshot().read();
    expect(saved.digest, report.encryptedDigest);
    expect(saved.generation, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), entries());
    expect(prefs.containsKey(
      WaffraLiveLegacyFinanceGuard.activeKey,
    ), false);
  });
}
