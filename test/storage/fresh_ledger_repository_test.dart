import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';

void main() {
  const fresh = WaffraFirstRunDecision.freshCandidate;
  const secret = 'fresh-ledger-repository-test-key-32';
  late Directory temporary;
  late WaffraEncryptedStore vault;

  WaffraFreshLedgerRepository repo({bool enabled = true}) =>
      WaffraFreshLedgerRepository(
        store: vault, experimentalEnabled: enabled,
      );

  WaffraFreshLedgerEntry entry({
    String id = 'expense-1', String title = 'قهوة',
    String category = 'مقاهي', int halalas = 1250,
    bool income = false, String date = '2026-10-21T13:30:00',
  }) => WaffraFreshLedgerEntry(
    id: id, title: title, categorySnapshot: category,
    amountMinor: halalas, isIncome: income, occurredIso: date,
  );

  Future<void> initialize() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: fresh);
  }

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('waffra-fresh-crud-');
    vault = WaffraEncryptedStore.openAt(
      File('${temporary.path}/ledger.sqlite'), key: secret,
    );
  });
  tearDown(() async {
    await vault.close();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('empty secure ledger reports zero and no injected sample data', () async {
    await initialize();
    expect(await repo().list(), isEmpty);
    final report = await repo().totals();
    expect(report.count, 0);
    expect(report.incomeMinor, 0);
    expect(report.expenseMinor, 0);
  });

  test('records exact halalas and computes income minus expenses offline',
      () async {
    await initialize();
    await repo().add(entry());
    await repo().add(entry(
      id: 'income-1', title: 'مرتب', category: 'راتب',
      halalas: 250099, income: true,
      date: '2026-10-20T13:30:00',
    ));
    final rows = await repo().list();
    expect(rows.length, 2);
    expect(rows.first.title, 'قهوة');
    expect(rows.first.toLegacyShape()['amount'], 12.5);
    final report = await repo().totals();
    expect(report.count, 2);
    expect(report.incomeMinor, 250099);
    expect(report.expenseMinor, 1250);
    expect(report.incomeMinor - report.expenseMinor, 248849);
  });

  test('reopen the real encrypted file and keep Arabic/English entries',
      () async {
    await initialize();
    await repo().add(entry(
      id: 'one', title: 'شراء اختبار', category: 'مصروفات',
      halalas: 301,
    ));
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${temporary.path}/ledger.sqlite'), key: secret,
    );
    final rows = await repo().list();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'شراء اختبار');
    expect(rows.single.amountMinor, 301);
  });

  test('duplicate IDs fail without changing totals or prior row', () async {
    await initialize();
    await repo().add(entry());
    await expectLater(repo().add(entry(halalas: 8888)),
        throwsA(isA<Exception>()));
    expect((await repo().list()).single.amountMinor, 1250);
    expect((await repo().totals()).expenseMinor, 1250);
  });

  test('negative amounts, bad dates, empty IDs and titles are rejected',
      () async {
    await initialize();
    for (final invalid in [
      entry(halalas: -1),
      entry(id: ''),
      entry(title: ' '),
      entry(date: 'not-a-date'),
      entry(category: ''),
    ]) {
      await expectLater(repo().add(invalid),
          throwsA(isA<ArgumentError>()));
    }
    expect((await repo().totals()).count, 0);
  });

  test('update is atomic and tracks totals without duplicate records',
      () async {
    await initialize();
    await repo().add(entry());
    await repo().replace(entry(
      halalas: 50000, title: 'تصحيح القيمة',
      income: true, category: 'دخل',
    ));
    final rows = await repo().list();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'تصحيح القيمة');
    expect(rows.single.isIncome, isTrue);
    final totals = await repo().totals();
    expect(totals.incomeMinor, 50000);
    expect(totals.expenseMinor, 0);
  });

  test('deletion removes one unattached record, not entire ledger',
      () async {
    await initialize();
    await repo().add(entry());
    await repo().add(entry(id: 'keep-me', halalas: 800));
    await repo().remove('expense-1');
    final rows = await repo().list();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'keep-me');
    expect((await repo().totals()).expenseMinor, 800);
  });

  test('deletion and updates cannot silently target missing records',
      () async {
    await initialize();
    await expectLater(repo().remove('nonexistent'),
        throwsA(isA<StateError>()));
    await expectLater(repo().replace(entry()),
        throwsA(isA<StateError>()));
  });

  test('never modifies a record with existing receipt metadata',
      () async {
    await initialize();
    await repo().add(entry());
    await vault.customStatement(
      'UPDATE fresh_finance_entries SET receipt_count = 1 '
      "WHERE entry_id = 'expense-1'",
    );
    await expectLater(repo().remove('expense-1'),
        throwsA(isA<StateError>()));
    await expectLater(repo().replace(entry(halalas: 1)),
        throwsA(isA<StateError>()));
    expect((await repo().totals()).expenseMinor, 1250);
  });

  test('no reads/writes without explicitly enabled repository', () async {
    await initialize();
    await expectLater(repo(enabled: false).list(),
        throwsA(isA<StateError>()));
    await expectLater(repo(enabled: false).add(entry()),
        throwsA(isA<StateError>()));
    expect((await repo().totals()).count, 0);
  });

  test('cannot write before a fresh encrypted schema exists', () async {
    await expectLater(repo().add(entry()),
        throwsA(isA<StateError>()));
  });

  test('wrong schema version blocks read and write, preserving rows',
      () async {
    await initialize();
    await repo().add(entry());
    await vault.customStatement(
      'UPDATE fresh_finance_meta SET schema_version = 999',
    );
    await expectLater(repo().list(), throwsA(isA<StateError>()));
    await expectLater(repo().add(entry(id: 'second')),
        throwsA(isA<StateError>()));
    final existing = await vault.customSelect(
      "SELECT count(*) AS n FROM fresh_finance_entries",
    ).getSingle();
    expect(existing.read<int>('n'), 1);
  });
}
