import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_read_gateway.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore db;
  const key = 'm66-private-receipt-readback-key-test';

  Future<void> install() async {
    final source = {
      'entries': jsonEncode([
        {
          'id': 'entry-1',
          'title': 'شراء',
          'category': 'أكل',
          'amount': 12.5,
          'income': false,
          'date': '2026-10-22T09:00:00',
          'receiptPath': '/old-device/receipt.jpg',
        },
      ]),
      'waffra_goals_v24': '[]',
    };
    final archive = await WaffraPortableBackupV2.create(
      financialSnapshot: source,
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: 'entry-1', position: 0,
          bytes: [0xFF, 0xD8, 0xFF, 0xE0, 0x01],
        ),
      ],
      password: 'receipt-test-strong-password',
    );
    await WaffraPortableEncryptedVaultRestorer(
      disposableStore: db, experimentalEnabled: true,
    ).restore(
      encryptedArchive: archive,
      password: 'receipt-test-strong-password',
    );
  }

  WaffraEncryptedReceiptReadGateway reader({
    bool enabled = true, Future<void> Function()? verifier,
  }) => WaffraEncryptedReceiptReadGateway(
    receiptVault: WaffraEncryptedReceiptVault(
      store: db, experimentalEnabled: true,
    ),
    experimentalEnabled: enabled,
    verifyEncryptedSource: verifier ?? () async {},
  );

  Future<String> references() async {
    final snapshot = await WaffraAtomicFinanceSnapshot(
      store: db, experimentalEnabled: true,
    ).read();
    final entries = jsonDecode(snapshot.values['entries'] as String) as List;
    return (entries.single as Map)['receiptPath'] as String;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m66-receipts-');
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('verified portable receipt resolves to exactly encrypted stored bytes',
      () async {
    await install();
    final loaded = await reader().read(
      entryId: 'entry-1', encodedReferences: await references(),
    );
    expect(loaded.length, 1);
    expect(loaded.single, [0xFF, 0xD8, 0xFF, 0xE0, 0x01]);
    expect((await references()).contains('/old-device/'), isFalse);
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: key,
    );
    expect((await reader().read(
      entryId: 'entry-1',
      encodedReferences: await references(),
    )).single, [0xFF, 0xD8, 0xFF, 0xE0, 0x01]);
  });

  test('forged, missing or wrong-owner references fail closed', () async {
    await install();
    await expectLater(reader().read(
      entryId: 'entry-1',
      encodedReferences: '/old-device/receipt.jpg',
    ), throwsA(isA<StateError>()));
    await expectLater(reader().read(
      entryId: 'entry-1',
      encodedReferences: null,
    ), throwsA(isA<StateError>()));
    await expectLater(reader().read(
      entryId: 'other-entry',
      encodedReferences: await references(),
    ), throwsA(isA<StateError>()));
  });

  test('default-disabled and unverified source can never open photos', () async {
    await install();
    await expectLater(reader(enabled: false).read(
      entryId: 'entry-1', encodedReferences: await references(),
    ), throwsA(isA<StateError>()));
    final unsafe = WaffraEncryptedReceiptReadGateway(
      receiptVault: WaffraEncryptedReceiptVault(
        store: db, experimentalEnabled: true,
      ),
      experimentalEnabled: true,
    );
    await expectLater(unsafe.read(
      entryId: 'entry-1', encodedReferences: await references(),
    ), throwsA(isA<StateError>()));
    final declined = reader(verifier: () async =>
        throw StateError('Source not proven'));
    await expectLater(declined.read(
      entryId: 'entry-1', encodedReferences: await references(),
    ), throwsA(isA<StateError>()));
  });
}
