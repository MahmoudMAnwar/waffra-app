import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_batch_journal.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const journal = WaffraLegacyFinanceBatchJournal();
  late Directory temp;

  const oldEntries =
      '[{"id":"one","title":"old","category":"food","amount":1.5,'
      '"income":false,"date":"2026-10-20T00:00:00"}]';
  const newEntries =
      '[{"id":"two","title":"new","category":"food","amount":2.5,'
      '"income":false,"date":"2026-10-21T00:00:00"}]';

  Map<String, Object> next() => <String, Object>{
    'entries': newEntries,
    'waffra_goals_v24': '[]',
    'waffra_monthly_budget_v1': 250.25,
    'waffra_monthly_budget_enabled_v1': true,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': oldEntries,
      'waffra_goals_v24': '[{"id":"old-goal"}]',
      'waffra_monthly_budget_v1': 120.25,
      'waffra_monthly_budget_enabled_v1': false,
      'waffra_sms_hashes_v1': <String>['known-bank-sms'],
      'waffra_profile': '{"name":"preserved"}',
    });
    temp = await Directory.systemTemp.createTemp('waffra-batch-recovery-');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('prepared batch has no visible changes until replay', () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    expect(prefs.getString('entries'), oldEntries);
    expect(prefs.getString('waffra_goals_v24'), contains('old-goal'));
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        isTrue);
    expect(await journal.recover(prefs), isTrue);
    expect(prefs.getString('entries'), newEntries);
    expect(prefs.getString('waffra_goals_v24'), '[]');
    expect(prefs.getDouble('waffra_monthly_budget_v1'), 250.25);
    expect(prefs.getBool('waffra_monthly_budget_enabled_v1'), isTrue);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['known-bank-sms']);
    expect(prefs.getString('waffra_profile'), '{"name":"preserved"}');
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        isFalse);
    expect(await journal.recover(prefs), isFalse);
  });

  test('crash after saving ledger recovers ALL remaining finance fields',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    await prefs.setString('entries', newEntries);
    await prefs.setString('waffra_goals_v24', '[]');
    await prefs.reload();
    final restored = await WaffraLegacyFinanceWriterCoordinator(
      testDirectory: temp,
    ).withCurrentPreferences((current) async {
      expect(current.getString('entries'), newEntries);
      expect(current.getDouble('waffra_monthly_budget_v1'), 250.25);
      expect(current.getBool('waffra_monthly_budget_enabled_v1'), true);
      return current.getString('waffra_goals_v24');
    });
    expect(restored, '[]');
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        isFalse);
  });

  test('finance read replays app batch before showing a mixed screen',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    await prefs.setString('entries', newEntries);
    final gateway = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: temp,
      ),
    );
    final loaded = await gateway.loadWithWitness();
    expect(loaded.ledgerRaw, newEntries);
    expect(loaded.finance.getString('waffra_goals_v24'), '[]');
    expect(loaded.finance.getDouble('waffra_monthly_budget_v1'), 250.25);
  });

  test('unexpected newer field blocks ALL remaining replay writes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    await prefs.setString('entries', newEntries);
    await prefs.setString('waffra_goals_v24', '[{"id":"another-edit"}]');
    await expectLater(journal.recover(prefs), throwsA(isA<StateError>()));
    expect(prefs.getString('waffra_goals_v24'), contains('another-edit'));
    expect(prefs.getDouble('waffra_monthly_budget_v1'), 120.25);
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        isTrue);
  });

  test('tampered checksum refuses recovery and retains intent', () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    final envelope = jsonDecode(
        prefs.getString(WaffraLegacyFinanceBatchJournal.pendingKey)!)
        as Map<String, dynamic>;
    envelope['checksum'] = List.filled(64, '0').join();
    await prefs.setString(WaffraLegacyFinanceBatchJournal.pendingKey,
        jsonEncode(envelope));
    await expectLater(journal.recover(prefs), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), oldEntries);
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        isTrue);
  });

  test('cannot overwrite pending batch with a new dashboard batch',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(prefs: prefs, nextValues: next());
    await expectLater(
      journal.prepare(prefs: prefs, nextValues: next()),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString('entries'), oldEntries);
  });

  test('rejects unknown or wrongly typed finance fields without a marker',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      journal.prepare(prefs: prefs, nextValues: {
        'entries': newEntries, 'waffra_profile': '{}',
      }), throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      journal.prepare(prefs: prefs, nextValues: {
        'entries': newEntries, 'waffra_monthly_budget_enabled_v1': 'wrong',
      }), throwsA(isA<StateError>()),
    );
    expect(prefs.getString('entries'), oldEntries);
    expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),
        false);
  });
}
