import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'm64-portable-disposable-encrypted-key-32';
  const password = 'test-only portable archive strong passphrase';
  late Directory temporary;
  late WaffraEncryptedStore vault;
  WaffraPortableEncryptedVaultRestorer restorer({bool enabled = true}) =>
      WaffraPortableEncryptedVaultRestorer(
        disposableStore: vault, experimentalEnabled: enabled,
      );

  Map<String, Object?> source({bool receipts = true}) => {
    'entries': jsonEncode([
      {
        'id': 'expense-one', 'title': 'مشتريات', 'category': 'أكل',
        'amount': 24.75, 'income': false,
        'date': '2026-10-21T12:00:00',
        'receiptPath': receipts
            ? jsonEncode(['/old-device/img-1.jpg','/old-device/img-2.png'])
            : null,
      },
      {
        'id': 'income-one', 'title': 'Salary', 'category': 'Income',
        'amount': 2000, 'income': true,
        'date': '2026-10-20T11:00:00', 'receiptPath': null,
      }
    ]),
    'waffra_goals_v24':
        '[{"id":"goal-1","name":"Trip","target":1000,"saved":100}]',
    'waffra_recurring_v24': '[]',
    'waffra_categories_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>['prior-hash'],
    'waffra_monthly_budget_v1': 1050.25,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_custom_goals_v1': <String>['شراء سيارة'],
  };

  List<WaffraReceiptBackupPart> parts() => [
    const WaffraReceiptBackupPart(
      entryId: 'expense-one', position: 0, bytes: [1, 2, 3, 4]),
    const WaffraReceiptBackupPart(
      entryId: 'expense-one', position: 1, bytes: [5, 6, 7]),
  ];

  Future<String> archive({bool receipts = true}) =>
      WaffraPortableBackupV2.create(
        financialSnapshot: source(receipts: receipts),
        receipts: receipts ? parts() : [],
        password: password,
      );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('waffra-m64-restore-');
    vault = WaffraEncryptedStore.openAt(
      File('${temporary.path}/receipts.sqlite'), key: key,
    );
  });

  tearDown(() async {
    await vault.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('restores finances and exact receipts inside one SQLCipher transaction',
      () async {
    final result = await restorer().restore(
      encryptedArchive: await archive(), password: password,
    );
    expect(result.encryptedGeneration, 1);
    expect(result.transactionCount, 2);
    expect(result.receiptCount, 2);
    expect(result.receiptBytes, 7);
    final snapshot = await WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    ).read();
    expect(snapshot.generation, 1);
    expect(snapshot.values['waffra_goals_v24'], contains('goal-1'));
    expect(snapshot.values['waffra_sms_hashes_v1'], ['prior-hash']);
    final entries = jsonDecode(snapshot.values['entries'] as String) as List;
    final first = entries.first as Map;
    expect(first['receiptPath'], contains('waffra-receipt://'));
    expect(first['receiptPath'], isNot(contains('/old-device/')));
    final tokens = jsonDecode(first['receiptPath'] as String) as List;
    expect(tokens, [
      WaffraEncryptedReceiptReference.of('expense-one', 0),
      WaffraEncryptedReceiptReference.of('expense-one', 1),
    ]);
    final blob = await WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    ).readAll('expense-one');
    expect(blob.map((v) => v.bytes.toList()).toList(),
        [[1, 2, 3, 4], [5, 6, 7]]);
    final suggestions = await vault.customSelect(
      'SELECT suggestion FROM fresh_finance_custom_goals',
    ).get();
    expect(suggestions.single.read<String>('suggestion'), 'شراء سيارة');
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${temporary.path}/receipts.sqlite'), key: key,
    );
    final cold = await WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    ).read();
    expect(cold.digest, snapshot.digest);
    expect((await WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    ).readAll('expense-one')).length, 2);
  });

  test('a second restore cannot overwrite the first imported ledger',
      () async {
    final encrypted = await archive();
    await restorer().restore(
      encryptedArchive: encrypted, password: password,
    );
    await expectLater(
      restorer().restore(encryptedArchive: encrypted, password: password),
      throwsA(isA<StateError>()),
    );
    expect((await WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    ).read()).generation, 1);
  });

  test('incorrect password never creates tables or a fake empty vault',
      () async {
    final encrypted = await archive();
    await expectLater(restorer().restore(
      encryptedArchive: encrypted, password: 'incorrect',
    ), throwsA(anything));
    final tables = await vault.customSelect(
      "SELECT name FROM sqlite_master WHERE name='fresh_finance_meta'",
    ).get();
    expect(tables, isEmpty);
  });

  test('disabled mode cannot install any user data', () async {
    await expectLater(restorer(enabled: false).restore(
      encryptedArchive: await archive(), password: password,
    ), throwsA(isA<StateError>()));
    final tables = await vault.customSelect(
      "SELECT name FROM sqlite_master WHERE name='fresh_finance_entries'",
    ).get();
    expect(tables, isEmpty);
  });

  test('backup without photos restores zero receipt records', () async {
    final result = await restorer().restore(
      encryptedArchive: await archive(receipts: false),
      password: password,
    );
    expect(result.receiptCount, 0);
    final record = (jsonDecode((await WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    ).read()).values['entries'] as String) as List).first as Map;
    expect(record['receiptPath'], isNull);
  });

  test('tampered metadata cannot create partial finance', () async {
    final encrypted = await archive();
    // A valid-format encrypted archive with wrong password is never accepted.
    final forged = encrypted.replaceFirst(
      'waffra-secure-backup', 'unknown-backup-format',
    );
    await expectLater(restorer().restore(
      encryptedArchive: forged, password: password,
    ), throwsA(anything));
    final active = await vault.customSelect(
      "SELECT name FROM sqlite_master WHERE name='fresh_finance_meta'",
    ).get();
    expect(active, isEmpty);
  });
}
