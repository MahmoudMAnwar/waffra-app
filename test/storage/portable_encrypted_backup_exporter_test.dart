import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore encrypted;
  const key = 'm68-test-only-vault-encryption-key-secret';
  const password = 'm68-password-only-for-test-archives';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m68-export-');
    encrypted = WaffraEncryptedStore.openAt(
      File('${root.path}/original.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await encrypted.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  WaffraPortableEncryptedBackupExporter exporter({
    bool enabled = true,
    Future<void> Function()? verifier,
  }) => WaffraPortableEncryptedBackupExporter(
    snapshot: WaffraAtomicFinanceSnapshot(
      store: encrypted, experimentalEnabled: true,
    ),
    receiptVault: WaffraEncryptedReceiptVault(
      store: encrypted, experimentalEnabled: true,
    ),
    writerDirectory: root,
    verifySourceUnderLock: verifier ?? () async {},
    experimentalEnabled: enabled,
  );

  Future<void> install() async {
    final archive = await WaffraPortableBackupV2.create(
      financialSnapshot: {
        'entries': jsonEncode([
          {
            'id': 'receipt-1', 'title': 'Family supplies',
            'category': 'Food', 'amount': 42.5,
            'income': false, 'date': '2026-10-22T07:00:00',
            'receiptPath': jsonEncode([
              '/old-phone/one.jpg', '/old-phone/two.jpg',
            ]),
          },
          {
            'id': 'salary-1', 'title': 'Salary',
            'category': 'Income', 'amount': 2000.0,
            'income': true, 'date': '2026-10-21T07:00:00',
            'receiptPath': null,
          },
        ]),
        'waffra_goals_v24': '[]',
        'waffra_sms_hashes_v1': <String>['previous-transaction-hash'],
        'waffra_custom_goals_v1': <String>['سيارة'],
      },
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: 'receipt-1', position: 0, bytes: [1, 2, 3, 4],
        ),
        const WaffraReceiptBackupPart(
          entryId: 'receipt-1', position: 1, bytes: [5, 6, 7],
        ),
      ],
      password: password,
    );
    await WaffraPortableEncryptedVaultRestorer(
      disposableStore: encrypted, experimentalEnabled: true,
    ).restore(encryptedArchive: archive, password: password);
  }

  test('M68 exports ciphertext-only backups and roundtrips images to a second SQLCipher vault',
      () async {
    await install();
    final encryptedArchive = await exporter().export(password: password);
    expect(encryptedArchive, contains('waffra-secure-backup'));
    expect(encryptedArchive, isNot(contains('Family supplies')));
    expect(encryptedArchive, isNot(contains('previous-transaction-hash')));
    expect(encryptedArchive, isNot(contains('/old-phone/')));
    final verified = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedArchive, password: password,
    );
    expect(verified.receiptCount, 2);
    expect(verified.receipts.map((r) => r.bytes).toList(),
        [[1, 2, 3, 4], [5, 6, 7]]);
    expect(verified.financialSnapshot['waffra_custom_goals_v1'], ['سيارة']);
    final entries = jsonDecode(verified.financialSnapshot['entries'] as String) as List;
    expect((entries.first as Map)['receiptPath'],
        contains('waffra-receipt://'));

    final imported = WaffraEncryptedStore.openAt(
      File('${root.path}/second.sqlite'), key: key,
    );
    try {
      final result = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: imported, experimentalEnabled: true,
      ).restore(
        encryptedArchive: encryptedArchive, password: password,
      );
      expect(result.transactionCount, 2);
      expect(result.receiptCount, 2);
      expect((await WaffraEncryptedReceiptVault(
        store: imported, experimentalEnabled: true,
      ).readAll('receipt-1')).map((r) => r.bytes.toList()).toList(),
          [[1, 2, 3, 4], [5, 6, 7]]);
      expect((await WaffraAtomicFinanceSnapshot(
        store: imported, experimentalEnabled: true,
      ).read()).values['waffra_sms_hashes_v1'],
          ['previous-transaction-hash']);
    } finally {
      await imported.close();
    }
  });

  test('M293 encrypted backup refuses a foreign-currency SQL row omitted by snapshot',
      () async {
    await install();
    final at = DateTime.utc(2026, 10, 27, 9);
    final now = DateTime.utc(2026, 10, 28);
    final quote = WaffraSmsFxQuote.fromUsdRates({
      'result': 'success',
      'rates': {'USD': 1.0, 'SAR': 3.75},
      'time_last_update_unix': at.millisecondsSinceEpoch ~/ 1000,
    }, originalCurrency: 'USD', targetCurrency: 'SAR', now: now);
    final fx = WaffraSmsFxReview.approve(
      originalAmount: 100, quote: quote, userConfirmed: true, now: now);
    await WaffraFreshLedgerRepository(
      store: encrypted, experimentalEnabled: true,
    ).add(WaffraFreshLedgerEntry(
      id: 'usd-after-snapshot',
      title: 'International purchase',
      categorySnapshot: 'Shopping',
      amountMinor: 37500,
      isIncome: false,
      occurredIso: '2026-10-27T18:30:00',
      fxReview: fx,
    ));
    await expectLater(exporter().export(password: password),
        throwsA(isA<StateError>()),
        reason: 'Never silently omit foreign-currency approval from backup');
  });

  test('M68 refuses export if source is unverified or feature disabled',
      () async {
    await install();
    await expectLater(exporter(enabled: false).export(password: password),
        throwsA(isA<StateError>()));
    await expectLater(exporter(verifier: () async {
      throw StateError('Production source witness missing');
    }).export(password: password), throwsA(isA<StateError>()));
  });

  test('M68 refuses tampered receipt checksums rather than exporting corrupt photos',
      () async {
    await install();
    await encrypted.customStatement(
      'UPDATE fresh_finance_receipt_blobs SET content_sha256=? '
      'WHERE entry_id=? AND position=?',
      [List.filled(64, '0').join(), 'receipt-1', 0],
    );
    await expectLater(exporter().export(password: password),
        throwsA(isA<StateError>()));
  });
}
