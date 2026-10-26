import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_combined_portable_recovery.dart';
import 'package:waffra/storage/waffra_encrypted_sms_notes_vault.dart';
import 'package:waffra/storage/waffra_original_sms_portable_preflight.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'M233 strong synthetic backup password 2026';
  const original = 'رسالة تجريبية\\nشراء 19.25 ريال';

  Map<String, Object?> snapshot({String id = 'bank-entry'}) => {
    'entries': jsonEncode([{
      'id': id,
      'title': 'تم الدفع',
      'category': 'أخرى',
      'amount': 19.25,
      'income': false,
      'date': '2026-10-26T10:00:00Z',
      'sourceType': 'sms',
      'notes': '',
      'receiptPath': '/untrusted/old/device/bill.jpg',
    }]),
    'waffra_categories_v24': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_sms_hashes_v1':
      <String>[WaffraEncryptedSmsNotesVault.fingerprint(original)],
  };

  Future<String> finance(Map<String, Object?> snapshot) =>
      WaffraPortableBackupV2.create(
        financialSnapshot: snapshot,
        receipts: const [
          WaffraReceiptBackupPart(
            entryId: 'bank-entry',
            position: 0,
            bytes: [255, 216, 100, 45, 12, 8],
          )
        ],
        password: password,
      );

  Future<String> sms(String ledger, {String note = original}) =>
      WaffraSecureBackup.encryptUserBackup(jsonEncode({
        'format': 'waffra-original-sms-staging',
        'version': 1,
        'financeLinkDigest':
          WaffraOriginalSmsPortablePreflight.financeLinkDigest(ledger),
        'records': [{
          'id': 'bank-entry',
          'hash': WaffraEncryptedSmsNotesVault.fingerprint(note),
          'original': note,
        }],
      }), password);

  Future<String> complete() async {
    final source = snapshot();
    return WaffraCombinedPortableRecovery.seal(
      encryptedFinanceArchive: await finance(source),
      encryptedOriginalSmsArchive: await sms(source['entries']! as String),
      password: password,
    );
  }

  test('M233 full financial ledger, receipt bytes and original SMS cold-stage'
      ' to disposable SQLCipher with no active-source swap', () async {
    final encrypted = await complete();
    expect(encrypted, isNot(contains(original)));
    expect(encrypted, isNot(contains('/untrusted/old/device')));
    final report = await WaffraCombinedPortableRecovery
        .verifyDisposableRestore(
      encryptedBundle: encrypted, password: password,
    );
    expect(report.transactionCount, 1);
    expect(report.receiptCount, 1);
    expect(report.receiptBytes, 6);
    expect(report.originalSmsCount, 1);
    expect(report.financeChecksum, hasLength(64));
    expect(report.activeSourceReplaced, isFalse);
    expect(report.productionCutoverAuthorized, isFalse);
    expect(report.twoPhysicalDevicesAttested, isFalse);
  });

  test('M233 wrong strong-envelope password fails before restore', () async {
    await expectLater(WaffraCombinedPortableRecovery.verifyDisposableRestore(
      encryptedBundle: await complete(), password: 'wrong password',
    ), throwsA(anything));
  });

  test('M233 bank original tied to different finance row rejects sealing',
      () async {
    final source = snapshot(id: 'different-bank-entry');
    await expectLater(WaffraCombinedPortableRecovery.seal(
      encryptedFinanceArchive: await WaffraPortableBackupV2.create(
        financialSnapshot: source,
        receipts: const [
          WaffraReceiptBackupPart(
            entryId: 'different-bank-entry', position: 0, bytes: [1, 2, 3],
          ),
        ],
        password: password,
      ),
      encryptedOriginalSmsArchive: await sms(
        snapshot()['entries']! as String),
      password: password,
    ), throwsStateError);
  });

  test('M233 reject raw plaintext and unknown archive metadata', () async {
    await expectLater(WaffraCombinedPortableRecovery.verifyAndPreview(
      encryptedBundle: jsonEncode({
        'format': 'waffra-combined-recovery-candidate', 'version': 1,
      }),
      password: password,
    ), throwsFormatException);
    final encrypted = await complete();
    final clear = await WaffraSecureBackup.decrypt(encrypted, password);
    final tampered = Map<String, dynamic>.from(jsonDecode(clear) as Map)
      ..['financeChecksum'] = 'not-a-valid-financial-checksum';
    final authenticatedButWrong = await WaffraSecureBackup.encryptUserBackup(
      jsonEncode(tampered), password,
    );
    await expectLater(WaffraCombinedPortableRecovery.verifyAndPreview(
      encryptedBundle: authenticatedButWrong, password: password,
    ), throwsStateError);
  });
}
