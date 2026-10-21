import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_normalized_import.dart';

void main() {
  late Directory directory;
  setUp(() async => directory = await Directory.systemTemp.createTemp('waffra-normalized-'));
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  final key = 'test-only-32-byte-local-key-for-ci--';
  Map<String, Object?> sample({num coffee = 2.50}) => {
    'entries': jsonEncode([
      {
        'id': 'exp1', 'title': 'قهوة', 'category': 'مطاعم',
        'amount': coffee, 'income': false, 'date': '2026-10-21T23:55:00.000',
        'receiptPath': jsonEncode(['/pictures/first.jpg', '/pictures/second.png']),
      },
      {
        'id': 'inc1', 'title': 'راتب', 'category': 'راتب',
        'amount': 100.25, 'income': true, 'date': '2026-10-20T00:00:00.000',
        'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': jsonEncode([
      {
        'id': 'food1', 'name': 'مطاعم', 'icon': 'restaurant',
        'color': 0xFF087A54, 'income': false, 'parentId': '',
        'budget': 150.75, 'alertPercent': 80,
      },
    ]),
    'waffra_goals_v24': jsonEncode([
      {'id': 'goal1', 'name': 'سيارة', 'target': 9000.0, 'saved': 400.0},
    ]),
    'waffra_recurring_v24': jsonEncode([
      {
        'id': 'rent1', 'title': 'إيجار', 'category': 'سكن', 'amount': 1000.0,
        'income': false, 'day': 25, 'active': true,
        'startAt': '2026-10-01T12:00:00.000',
      }
    ]),
    'waffra_challenges_v1': jsonEncode([
      {
        'id': 'challenge1', 'title': 'ادخار يومي', 'dailyAmount': 5.0,
        'days': 30, 'completedDays': 3, 'lastDone': null,
      }
    ]),
    'waffra_deleted_categories_v1': jsonEncode([
      {
        'category': {
          'id': 'food1', 'name': 'مطاعم محذوفة', 'icon': 'restaurant',
          'color': 0xFF087A54, 'income': false, 'parentId': '',
          'budget': 0.0, 'alertPercent': 80,
        },
        'deletedAt': '2026-10-20T22:00:00.000'
      }
    ]),
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': jsonEncode({'rec_rent1_2026-10-25': '2026-10-26'}),
    'waffra_learned_merchants_v1': jsonEncode({'merchant': 'مطاعم'}),
    'waffra_sms_hashes_v1': <String>['hashed-value'],
    'waffra_monthly_budget_v1': 2000.0,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  test('typed projection preserves dates, halalas, raw receipts and deleted history', () async {
    final file = File('${directory.path}/ledger.sqlite');
    final store = WaffraEncryptedStore.openAt(file, key: key);
    final importer = WaffraNormalizedImporter(store);
    final raw = sample();
    final before = jsonEncode(raw);
    final report = await importer.stage('vault1', raw);
    expect(jsonEncode(raw), before);
    expect(report.entries, 2);
    expect(report.categories, 1);
    expect(report.goals, 1);
    expect(report.recurring, 1);
    expect(report.challenges, 1);
    expect(report.trash, 1);
    expect(report.receipts, 2);
    expect(report.incomeMinor, 10025);
    expect(report.expenseMinor, 250);
    final ledger = await importer.readEntries('vault1');
    expect(ledger.length, 2);
    final exp = ledger.singleWhere((e) => e.id == 'exp1');
    expect(exp.dateIso, '2026-10-21T23:55:00.000');
    expect(exp.amountMinor, 250);
    expect(exp.categorySnapshot, 'مطاعم');
    expect(await importer.readEntries('vault-other'), isEmpty);
    final receiptRows = await store.customSelect(
      "SELECT local_file_path FROM normalized_receipts "
      "WHERE vault_id = 'vault1' AND entry_id = 'exp1' ORDER BY position",
    ).get();
    expect(receiptRows.map((e) => e.read<String>('local_file_path')).toList(),
        ['/pictures/first.jpg', '/pictures/second.png']);
    expect((await store.customSelect(
      "SELECT count(*) AS n FROM normalized_deleted WHERE vault_id = 'vault1'",
    ).getSingle()).read<int>('n'), 1);
    // Original snapshot preserves fields not yet mapped into typed columns.
    expect((await store.customSelect(
      "SELECT original_json AS j FROM normalized_goals WHERE vault_id = 'vault1'",
    ).getSingle()).read<String>('j'), contains('"saved":400'));
    await store.close();
    final reopened = WaffraEncryptedStore.openAt(file, key: key);
    final again = WaffraNormalizedImporter(reopened);
    expect((await again.stage('vault1', raw)).sourceSha256, report.sourceSha256);
    expect((await again.readEntries('vault1')).length, 2);
    await reopened.close();
  });

  test('separate financial vaults are isolated and snapshots cannot be overwritten', () async {
    final store = WaffraEncryptedStore.openAt(
      File('${directory.path}/vault.sqlite'), key: key);
    final importer = WaffraNormalizedImporter(store);
    await importer.stage('family-a', sample());
    await importer.stage('family-b', sample(coffee: 3.50));
    expect((await importer.readEntries('family-a')).firstWhere((e) => !e.income).amountMinor, 250);
    expect((await importer.readEntries('family-b')).firstWhere((e) => !e.income).amountMinor, 350);
    await expectLater(
      importer.stage('family-a', sample(coffee: 4.25)), throwsStateError);
    expect((await importer.readEntries('family-a')).firstWhere((e) => !e.income).amountMinor, 250);
    await store.close();
  });

  test('preflight prevents corrupt amount, and no typed rows are committed', () async {
    final store = WaffraEncryptedStore.openAt(
      File('${directory.path}/vault.sqlite'), key: key);
    final importer = WaffraNormalizedImporter(store);
    final changed = sample(coffee: 2.005);
    await expectLater(importer.stage('vault-a', changed), throwsStateError);
    expect(await importer.readEntries('vault-a'), isEmpty);
    await store.close();
  });

  test('missing field aborts typed transaction without deleting shadow or legacy data', () async {
    final store = WaffraEncryptedStore.openAt(
      File('${directory.path}/vault.sqlite'), key: key);
    final importer = WaffraNormalizedImporter(store);
    final original = sample();
    final records = jsonDecode(original['entries'] as String) as List<dynamic>;
    (records.first as Map<String, dynamic>).remove('title');
    original['entries'] = jsonEncode(records);
    final before = original['entries'];
    await expectLater(importer.stage('vault', original), throwsStateError);
    expect(original['entries'], before);
    // Importing a fixed source is disallowed into the existing, differing
    // shadow vault; the app must use a fresh vault / recovery path.
    await expectLater(importer.stage('vault', sample()), throwsStateError);
    await store.close();
  });
}
