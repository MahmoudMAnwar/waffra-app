import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_encrypted_sms_notes_vault.dart';
import 'package:waffra/storage/waffra_original_sms_portable_preflight.dart';
import 'package:waffra/storage/waffra_original_sms_disposable_restore_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const passphrase = 'synthetic offline encryption passphrase 2026';

  Map<String, Object?> finance(String id) => {
        'id': id,
        'sourceType': 'sms',
        'category': 'أخرى',
        'date': '2026-10-26T12:00:00.000Z',
        'amount': 125.50,
        'income': false,
      };

  Future<String> archive(String ledger, Map<String, String> originals) async {
    final records = <Map<String, String>>[];
    final ids = originals.keys.toList()..sort();
    for (final id in ids) {
      final original = originals[id]!;
      records.add({
        'id': id,
        'hash': WaffraEncryptedSmsNotesVault.fingerprint(original),
        'original': original,
      });
    }
    return WaffraSecureBackup.encryptUserBackup(jsonEncode({
      'format': 'waffra-original-sms-staging',
      'version': 1,
      'financeLinkDigest':
          WaffraOriginalSmsPortablePreflight.financeLinkDigest(ledger),
      'records': records,
    }), passphrase);
  }

  test('M232 encrypted original notes restore byte-exact to disposable SQLCipher'
      ' and cold-reopen without source activation', () async {
    final ledger = jsonEncode([finance('sms-a'), finance('sms-b')]);
    final original = <String, String>{
      'sms-a': 'شراء بنكي\\nالمبلغ ١٢٥٫٥٠ ريال\\nالمتجر تجريبي',
      'sms-b': 'Incoming transfer\\r\\n225 SAR\\nREF TEST',
    };
    final cipher = await archive(ledger, original);
    for (final note in original.values) {
      expect(cipher.contains(note), isFalse);
    }
    final digestList = original.values
        .map(WaffraEncryptedSmsNotesVault.fingerprint).toList();
    final result = await const WaffraDisposableOriginalSmsRestoreVerifier()
        .inspect(
          encryptedArchive: cipher,
          password: passphrase,
          expectedLedgerRaw: ledger,
          expectedHashes: digestList,
        );
    expect(result.confirmedSmsCount, 2);
    expect(result.verifiedAfterColdReopen, 2);
    expect(result.byteExactParityVerified, isTrue);
    expect(result.activeSourceReplaced, isFalse);
    expect(result.productionCutoverAuthorized, isFalse);
    expect(result.twoPhysicalDevicesAttested, isFalse);
  });

  test('M232 rejects mismatched finance source before staging', () async {
    final ledger = jsonEncode([finance('a')]);
    final cipher = await archive(ledger, {'a': 'Deposit\\n125.50 SAR'});
    final hashes = [WaffraEncryptedSmsNotesVault.fingerprint(
        'Deposit\\n125.50 SAR')];
    await expectLater(
      const WaffraDisposableOriginalSmsRestoreVerifier().inspect(
        encryptedArchive: cipher,
        password: passphrase,
        expectedLedgerRaw: jsonEncode([finance('b')]),
        expectedHashes: hashes,
      ),
      throwsStateError,
    );
  });

  test('M232 wrong password refuses disposable recovery', () async {
    final ledger = jsonEncode([finance('a')]);
    final cipher = await archive(ledger, {'a': 'Withdrawal\\n15.00 SAR'});
    await expectLater(
      const WaffraDisposableOriginalSmsRestoreVerifier().inspect(
        encryptedArchive: cipher,
        password: 'wrong passphrase',
        expectedLedgerRaw: ledger,
        expectedHashes: [WaffraEncryptedSmsNotesVault.fingerprint(
            'Withdrawal\\n15.00 SAR')],
      ),
      throwsA(anything),
    );
  });

  test('M232 missing authenticated SMS record fails instead of inventing it',
      () async {
    final ledger = jsonEncode([finance('a'), finance('b')]);
    final cipher = await archive(ledger, {'a': 'Purchase\\n15 SAR'});
    await expectLater(
      const WaffraDisposableOriginalSmsRestoreVerifier().inspect(
        encryptedArchive: cipher,
        password: passphrase,
        expectedLedgerRaw: ledger,
        expectedHashes: [
          WaffraEncryptedSmsNotesVault.fingerprint('Purchase\\n15 SAR'),
        ],
      ),
      throwsStateError,
    );
  });

  test('M232 zero-confirmed-SMS archive does not authorize activation',
      () async {
    const ledger = '[]';
    final cipher = await archive(ledger, const <String, String>{});
    final result = await const WaffraDisposableOriginalSmsRestoreVerifier()
        .inspect(
      encryptedArchive: cipher,
      password: passphrase,
      expectedLedgerRaw: ledger,
      expectedHashes: const [],
    );
    expect(result.confirmedSmsCount, 0);
    expect(result.byteExactParityVerified, isTrue);
    expect(result.productionCutoverAuthorized, isFalse);
  });
}
