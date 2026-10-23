import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_verified_legacy_backup_restore.dart';
import 'package:waffra/waffra_secure_backup.dart';

/// M167 disposable legacy finance/backup acceptance; no live accounts touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  WaffraHomeFinancePersistence finance() => WaffraHomeFinancePersistence(
    coordinator: WaffraLegacyFinanceWriterCoordinator(
      testDirectory: root,
      testBypassNativeLock: true,
    ),
  );

  Map<String, Object> archive({String ledger = '[]', String goals = '[]'}) => {
    'entries': ledger,
    'waffra_categories_v24': '[]',
    'waffra_goals_v24': goals,
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[],
    'waffra_recurring_reminders_enabled_v1': false,
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m167-no-real-data-');
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_profile': '{"provider":"google","uid":"synthetic-only"}',
      'waffra_language': 'en',
      'waffra_sms_hashes_v1': <String>[],
    });
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('new empty app accepts explicit empty finance restore without losing login',
      () async {
    final restored = await WaffraVerifiedLegacyBackupRestore(
      persistence: finance(),
    ).restore(
      finance: archive(),
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    );
    expect(restored.transactionCount, 0);
    expect(restored.ledgerRaw, '[]');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getString('waffra_profile'),
        '{"provider":"google","uid":"synthetic-only"}');
    expect(prefs.getString('waffra_language'), 'en');
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

  test('fresh manual income/expense writes survive guarded cold reload', () async {
    final entries = jsonEncode([
      {
        'id': 'synthetic-expense',
        'title': 'Test grocery',
        'category': 'Food',
        'amount': 2.25,
        'income': false,
        'date': '2026-10-23T08:00:00',
        'receiptPath': null,
      },
      {
        'id': 'synthetic-income',
        'title': 'Test salary',
        'category': 'Income',
        'amount': 16.50,
        'income': true,
        'date': '2026-10-23T09:00:00',
        'receiptPath': null,
      },
    ]);
    final saved = await finance().saveLegacy(
      snapshot: {'entries': entries},
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    );
    expect(saved, entries);
    final reopened = await finance().loadWithWitness();
    expect(reopened.ledgerRaw, entries);
    final persisted = jsonDecode(reopened.ledgerRaw!) as List<dynamic>;
    expect(persisted, hasLength(2));
    expect((persisted.first as Map)['amount'], 2.25);
    expect((persisted.last as Map)['income'], isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('waffra_profile'),
        '{"provider":"google","uid":"synthetic-only"}');
  });

  test('bad backup cannot overwrite newer expense, income or Google profile',
      () async {
    final current = jsonEncode([
      {
        'id': 'newer-entry', 'title': 'Already saved',
        'category': 'Food', 'amount': 2,
        'income': false, 'date': '2026-10-23T11:00:00',
        'receiptPath': null,
      },
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', current);
    final unsafe = archive(goals:
        '[{"id":"synthetic-goal","name":"Test","target":50,"saved":-1}]');
    await expectLater(
      WaffraVerifiedLegacyBackupRestore(persistence: finance()).restore(
        finance: unsafe,
        expectedLedgerRaw: current,
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    await prefs.reload();
    expect(prefs.getString('entries'), current);
    expect(prefs.getString('waffra_profile'),
        '{"provider":"google","uid":"synthetic-only"}');
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

  test('V2 encrypted user export and legacy V1 decrypt remain compatible',
      () async {
    const raw = '{"format":"waffra-backup","entries":[]}';
    const passphrase = 'Long-test-only-passphrase-2026';
    final latest = await WaffraSecureBackup.encryptUserBackup(raw, passphrase);
    final header = jsonDecode(latest) as Map<String, dynamic>;
    expect(header['version'], 2);
    expect(header['kdf'], 'argon2id');
    expect(latest, isNot(contains('"entries":[]')));
    expect(await WaffraSecureBackup.decrypt(latest, passphrase), raw);
    final legacy = await WaffraSecureBackup.encrypt(raw, passphrase);
    expect((jsonDecode(legacy) as Map)['version'], 1);
    expect(await WaffraSecureBackup.decrypt(legacy, passphrase), raw);
    await expectLater(WaffraSecureBackup.decrypt(latest, 'wrong-password'),
        throwsA(isA<Exception>()));
  });
}
