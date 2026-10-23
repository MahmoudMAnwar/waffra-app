import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  const newPassword = 'Abcd1234';

  test('M140: Arabic/English finance and 100 entries round-trip byte-exactly', () async {
    final transactions = List<Map<String, dynamic>>.generate(100, (index) => {
      'id': 'tx-${index + 1}',
      'description': index.isEven ? 'مطاعم وكافيهات — الرياض' : 'Salary / راتب 💚',
      'amountMinor': index.isEven ? -(index + 1) : index + 1,
      'currency': 'SAR',
      'attachmentNames': <String>['فاتورة-${index + 1}.pdf'],
    });
    final finance = jsonEncode(<String, dynamic>{
      'format': 'waffra-backup',
      'transactions': transactions,
      'memo': 'ريال • € / zero byte: \\u0000 / أسطر\\nمتعددة',
    });

    final archive = await WaffraSecureBackup.encryptUserBackup(finance, newPassword);
    expect(archive, isNot(contains('مطاعم وكافيهات')));
    expect(archive, isNot(contains('Salary / راتب')));
    final restored = await WaffraSecureBackup.decrypt(archive, newPassword);
    expect(restored, finance);
    final restoredTransactions =
        (jsonDecode(restored) as Map<String, dynamic>)['transactions'] as List<dynamic>;
    expect(restoredTransactions, hasLength(100));
    expect((restoredTransactions.last as Map<String, dynamic>)['amountMinor'], 100);
  });

  test('M140: mixing encrypted fields from two valid archives fails closed', () async {
    final first = jsonDecode(await WaffraSecureBackup.encryptUserBackup(
      'ledger A: confidential', newPassword,
    )) as Map<String, dynamic>;
    final second = jsonDecode(await WaffraSecureBackup.encryptUserBackup(
      'ledger B: confidential', newPassword,
    )) as Map<String, dynamic>;

    for (final field in <String>['salt', 'nonce', 'data', 'mac']) {
      final mixed = Map<String, dynamic>.from(first);
      mixed[field] = second[field];
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(mixed), newPassword),
        throwsA(isA<Exception>()),
        reason: 'A $field from a different encrypted export must not authenticate',
      );
    }
    expect(await WaffraSecureBackup.decrypt(jsonEncode(first), newPassword),
        'ledger A: confidential');
    expect(await WaffraSecureBackup.decrypt(jsonEncode(second), newPassword),
        'ledger B: confidential');
  });

  test('M140: legacy encrypted backup accepts long international passphrase', () async {
    const legacyPassword = 'قديم-Backup-Password-2025';
    const payload = '{"format":"waffra-backup","note":"بيانات قديمة ✅"}';
    final archive = await WaffraSecureBackup.encrypt(payload, legacyPassword);
    expect(await WaffraSecureBackup.decrypt(archive, legacyPassword), payload);
    await expectLater(
      WaffraSecureBackup.decrypt(archive, 'Wrong123'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      WaffraSecureBackup.encryptUserBackup(payload, legacyPassword),
      throwsFormatException,
      reason: 'Legacy restore flexibility must not weaken new export requirements',
    );
  });

  test('M140: legacy plaintext finance archive stays exactly compatible', () async {
    const plaintext = '{"format":"waffra-backup","entries":[{"name":"فاتورة","amount":0.01}]}';
    expect(await WaffraSecureBackup.decrypt(plaintext, ''), plaintext);
    await expectLater(
      WaffraSecureBackup.decrypt(
        '{"format":"unknown-backup","entries":[]}', '',
      ),
      throwsFormatException,
      reason: 'Unknown formats must never enter the legacy restore route',
    );
  });

  test('M140: empty authenticated export restores and altered tag is rejected', () async {
    final archive = await WaffraSecureBackup.encryptUserBackup('', newPassword);
    expect(await WaffraSecureBackup.decrypt(archive, newPassword), '');
    final changed = jsonDecode(archive) as Map<String, dynamic>;
    final tag = base64Decode(changed['mac'] as String);
    tag[tag.length - 1] ^= 0x80;
    changed['mac'] = base64Encode(tag);
    await expectLater(
      WaffraSecureBackup.decrypt(jsonEncode(changed), newPassword),
      throwsA(isA<Exception>()),
    );
  });
}
