import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';

/// M96 exercises the REAL shared app/widget legacy writer gate used by
/// HomeScreen while encrypted cutover is disabled. Synthetic fixture only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraHomeFinancePersistence finance;

  String hash(int i) => i.toRadixString(16).padLeft(64, '0');

  Map<String, Object?> entry(int i, {bool income = false}) => {
    'id': 'sms-confirmed-$i',
    'title': 'Synthetic bank message $i',
    'category': income ? 'راتب' : 'أخرى',
    'amount': income ? 16.50 : 84.72,
    'income': income,
    'date': '2026-10-22T12:00:00',
    'receiptPath': null,
  };

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m96-sms-');
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>[],
    });
    finance = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
      ),
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M96 cancelled SMS leaves all financial and hash values unmodified',
      () async {
    await expectLater(finance.commitConfirmedLegacySms(
      records: [entry(1)], messageHashes: [hash(1)],
      userConfirmed: false,
    ), throwsA(isA<StateError>()));
    final loaded = await finance.loadWithWitness();
    expect(loaded.ledgerRaw, '[]');
    expect(loaded.finance.getStringList('waffra_sms_hashes_v1'), isEmpty);
  });

  test('M96 confirmed five transactions commit 2 income and 3 expenses',
      () async {
    final result = await finance.commitConfirmedLegacySms(
      records: [
        entry(1, income: true), entry(2),
        entry(3), entry(4, income: true), entry(5),
      ],
      messageHashes: [for (var n = 1; n <= 5; n++) hash(n)],
      userConfirmed: true,
    );
    expect(result.added, 5);
    expect(result.savedIncome, 2);
    expect(result.savedExpenses, 3);
    expect(result.incomeMinor, 3300);
    expect(result.expenseMinor, 25416);
    expect(result.savedHashes.length, 5);
    final loaded = await finance.loadWithWitness();
    expect((jsonDecode(loaded.ledgerRaw!) as List), hasLength(5));
    expect(loaded.finance.getStringList('waffra_sms_hashes_v1'), hasLength(5));
    expect(loaded.widgetRevision, isNotNull);
  });

  test('M96 duplicate after cold reopen is skipped with no phantom row',
      () async {
    await finance.commitConfirmedLegacySms(
      records: [entry(1)], messageHashes: [hash(1)],
      userConfirmed: true,
    );
    final repeated = await finance.commitConfirmedLegacySms(
      records: [entry(999), entry(2)],
      messageHashes: [hash(1), hash(2)],
      userConfirmed: true,
    );
    expect(repeated.added, 1);
    expect(repeated.skippedDuplicates, 1);
    expect(repeated.savedHashes, [hash(1), hash(2)]);
    expect((jsonDecode(repeated.savedEntriesRaw) as List), hasLength(2));
  });

  test('M96 rejects 101 messages before any write or source revision',
      () async {
    await expectLater(finance.commitConfirmedLegacySms(
      records: List.generate(101, (n) => entry(n)),
      messageHashes: List.generate(101, hash),
      userConfirmed: true,
    ), throwsA(isA<ArgumentError>()));
    final loaded = await finance.loadWithWitness();
    expect(loaded.ledgerRaw, '[]');
    expect(loaded.widgetRevision, isNull);
  });

  test('M96 duplicate entry identity rolls back whole batch and hashes',
      () async {
    await expectLater(finance.commitConfirmedLegacySms(
      records: [entry(1), entry(1)],
      messageHashes: [hash(10), hash(11)],
      userConfirmed: true,
    ), throwsA(isA<StateError>()));
    final loaded = await finance.loadWithWitness();
    expect(loaded.ledgerRaw, '[]');
    expect(loaded.finance.getStringList('waffra_sms_hashes_v1'), isEmpty);
  });

  test('M96 exact 100 synthetic transactions save once in shared journal',
      () async {
    final result = await finance.commitConfirmedLegacySms(
      records: List.generate(
        100, (n) => entry(n + 1, income: n.isEven),
      ),
      messageHashes: List.generate(100, (n) => hash(n + 1)),
      userConfirmed: true,
    );
    expect(result.added, 100);
    expect(result.savedIncome, 50);
    expect(result.savedExpenses, 50);
    expect((jsonDecode(result.savedEntriesRaw) as List), hasLength(100));
    expect(result.savedHashes, hasLength(100));
  });
}
