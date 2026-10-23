import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('M131: password boundaries are exactly eight ASCII alphanumeric', () {
    const valid=['A1234567','1abcdefg','abcde123','1234567Z','Z1234567'];
    for (final password in valid) {
      expect(WaffraSecureBackup.isValidNewPassword(password),isTrue,
          reason:password);
    }
    const invalid=['','A123456','A12345678','abcdefgh','12345678',
      'A12345 7','A12345-7','A12345_7','A12345\u00e9','A12345\n7',
      'A12345\u06617','A12345\u00df','A12345\u200b7'];
    for (final password in invalid) {
      expect(WaffraSecureBackup.isValidNewPassword(password),isFalse,
          reason:password);
    }
  });

  test('M131: each export has unique random salt and nonce', () async {
    final a=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','Abcd1234'))
        as Map<String,dynamic>;
    final b=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','Abcd1234'))
        as Map<String,dynamic>;
    expect(a['salt'],isNot(b['salt']));
    expect(a['nonce'],isNot(b['nonce']));
    expect(a['data'],isNotNull);
    expect(a['mac'],isNotNull);
    expect(a.containsKey('password'),isFalse);
  });

  test('M131: tampering with authenticated ciphertext fails closed', () async {
    const plaintext='{"amount":125.50,"kind":"expense"}';
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup(plaintext,'Abcd1234'),
    ) as Map<String,dynamic>;
    for (final field in ['data','mac','nonce']) {
      final changed=Map<String,dynamic>.from(original);
      final bytes=base64Decode(changed[field] as String);
      bytes[0]^=1;
      changed[field]=base64Encode(bytes);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Abcd1234'),
        throwsA(isA<Exception>()),
        reason:'Modified $field must not decrypt',
      );
    }
  });

  test('M131: malformed metadata fails without returning finance data', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('secret','Abcd1234'),
    ) as Map<String,dynamic>;
    for (final patch in <Map<String,dynamic>>[
      {'format':'unexpected'}, {'version':999},
      {'iterations':1}, {'cipher':'aes-128-cbc'},
      {'salt':base64Encode(List<int>.filled(2,0))},
      {'nonce':base64Encode(List<int>.filled(2,0))},
      {'mac':base64Encode(List<int>.filled(2,0))},
    ]) {
      final changed=Map<String,dynamic>.from(original)..addAll(patch);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Abcd1234'),
        throwsA(isA<Exception>()),
        reason:'Invalid metadata $patch must fail closed',
      );
    }
  });
}
