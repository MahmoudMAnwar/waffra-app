import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';
import 'package:waffra/waffra_secure_backup.dart';

/// M81 synthetic, disposable, offline restoration security acceptance.
/// Deliberately independent of M79 Android tests and any live account data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sqlKey = 'm81-only-disposable-encrypted-vault-test-key';
  const password = 'm81 synthetic independent recovery password';
  late Directory root;
  late WaffraEncryptedStore database;

  Map<String, Object?> source() => {
    'entries': jsonEncode([
      {
        'id': 'm81-expense',
        'title': 'Synthetic offline receipt',
        'category': 'أخرى',
        'amount': 84.72,
        'income': false,
        'date': '2026-10-22T15:00:00',
        'receiptPath': jsonEncode([
          '/previous-device/private-photo.jpg',
          '/previous-device/other-photo.png',
        ]),
      },
      {
        'id': 'm81-salary',
        'title': 'Synthetic income',
        'category': 'دخل',
        'amount': 200.0,
        'income': true,
        'date': '2026-10-22T10:00:00',
        'receiptPath': null,
      },
    ]),
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_sms_hashes_v1': <String>['m81-previous-fingerprint'],
    'waffra_custom_goals_v1': <String>['سفر'],
  };

  List<WaffraReceiptBackupPart> receipts() => [
    const WaffraReceiptBackupPart(
      entryId: 'm81-expense', position: 0, bytes: [10, 20, 30],
    ),
    const WaffraReceiptBackupPart(
      entryId: 'm81-expense', position: 1, bytes: [40, 50, 60, 70],
    ),
  ];

  Future<String> archive() => WaffraPortableBackupV2.create(
    financialSnapshot: source(), receipts: receipts(), password: password,
  );

  WaffraPortableEncryptedVaultRestorer restorer() =>
      WaffraPortableEncryptedVaultRestorer(
        disposableStore: database, experimentalEnabled: true,
      );

  Future<bool> hasFinancialSchema() async =>
      (await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_meta'",
      ).get()).isNotEmpty;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m81-recovery-');
    database = WaffraEncryptedStore.openAt(
      File('${root.path}/encrypted.sqlite'), key: sqlKey,
    );
  });
  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M81 a validly re-encrypted but altered financial snapshot cannot install',
      () async {
    final original = await archive();
    final clear = await WaffraSecureBackup.decrypt(original, password);
    final parsed = jsonDecode(clear) as Map<String, dynamic>;
    // Authentication alone is insufficient: source checksum must still match.
    final finance = parsed['snapshot'] as Map<String, dynamic>;
    finance['waffra_goals_v24'] = '[{"id":"injected","name":"bad"}]';
    final forged = await WaffraSecureBackup.encrypt(
      jsonEncode(parsed), password,
    );
    await expectLater(restorer().restore(
      encryptedArchive: forged, password: password,
    ), throwsA(anything));
    expect(await hasFinancialSchema(), isFalse);

    // A rejected import must not poison a later valid recovery attempt.
    final restored = await restorer().restore(
      encryptedArchive: original, password: password,
    );
    expect(restored.transactionCount, 2);
    expect(restored.receiptCount, 2);
  });

  test('M81 a forged invoice SHA blocks whole restore; valid retry keeps bytes',
      () async {
    final original = await archive();
    final clear = await WaffraSecureBackup.decrypt(original, password);
    final parsed = jsonDecode(clear) as Map<String, dynamic>;
    final chunks = parsed['receipts'] as List<dynamic>;
    (chunks.first as Map<String, dynamic>)['sha256'] = '0' * 64;
    final forged = await WaffraSecureBackup.encrypt(
      jsonEncode(parsed), password,
    );
    await expectLater(restorer().restore(
      encryptedArchive: forged, password: password,
    ), throwsA(anything));
    expect(await hasFinancialSchema(), isFalse);

    final accepted = await restorer().restore(
      encryptedArchive: original, password: password,
    );
    expect(accepted.receiptBytes, 7);
    final files = await WaffraEncryptedReceiptVault(
      store: database, experimentalEnabled: true,
    ).readAll('m81-expense');
    expect(files.map((part) => part.bytes.toList()).toList(), [
      [10, 20, 30], [40, 50, 60, 70],
    ]);
  });

  test('M81 recovered receipt references never preserve original device paths',
      () async {
    final encrypted = await archive();
    expect(encrypted, isNot(contains('/previous-device/private-photo.jpg')));
    expect(encrypted, isNot(contains('m81-previous-fingerprint')));
    final outcome = await restorer().restore(
      encryptedArchive: encrypted, password: password,
    );
    expect(outcome.encryptedGeneration, 1);
    final before = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    final entries = jsonDecode(before.values['entries'] as String) as List;
    final expense = entries.first as Map;
    expect(expense['receiptPath'], isNot(contains('/previous-device/')));
    final references = jsonDecode(expense['receiptPath'] as String) as List;
    expect(references, [
      WaffraEncryptedReceiptReference.of('m81-expense', 0),
      WaffraEncryptedReceiptReference.of('m81-expense', 1),
    ]);
    expect(before.values['waffra_sms_hashes_v1'],
        ['m81-previous-fingerprint']);

    // Cold reopening must retain BOTH immutable finance and encrypted images.
    await database.close();
    database = WaffraEncryptedStore.openAt(
      File('${root.path}/encrypted.sqlite'), key: sqlKey,
    );
    final after = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    expect(after.generation, 1);
    expect(after.digest, before.digest);
    final exact = await WaffraEncryptedReceiptVault(
      store: database, experimentalEnabled: true,
    ).readAll('m81-expense');
    expect(exact.map((part) => part.bytes.toList()).toList(), [
      [10, 20, 30], [40, 50, 60, 70],
    ]);
  });

  test('M81 wrong password and replay never overwrite a recovered SQLCipher vault',
      () async {
    final encrypted = await archive();
    await restorer().restore(
      encryptedArchive: encrypted, password: password,
    );
    final before = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    await expectLater(restorer().restore(
      encryptedArchive: encrypted, password: 'incorrect password',
    ), throwsA(anything));
    await expectLater(restorer().restore(
      encryptedArchive: encrypted, password: password,
    ), throwsA(isA<StateError>()));
    final after = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    expect(after.digest, before.digest);
    expect(after.generation, before.generation);
    expect((jsonDecode(after.values['entries'] as String) as List).length, 2);
  });
}
