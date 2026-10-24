import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('M131: V2 passwords support strong Unicode passphrases and reject short/oversized inputs', () {
    const valid=['Waffra-2026-Strong','correct horse battery','أمان-وفرة-2026','Secure_Archive#2026'];
    for(final password in valid){
      expect(WaffraSecureBackup.isValidNewPassword(password),isTrue,reason:password);
    }
    const invalid=['','Abcd1234','12345678901','short'];
    for(final password in invalid){
      expect(WaffraSecureBackup.isValidNewPassword(password),isFalse,reason:password);
    }
    expect(WaffraSecureBackup.isValidNewPassword(List<String>.filled(256,'A').join()),isTrue);
    expect(WaffraSecureBackup.isValidNewPassword(List<String>.filled(257,'A').join()),isFalse);
  });

  test('M131: each export has unique random salt and nonce', () async {
    final a=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','Waffra-2026-Strong'))
        as Map<String,dynamic>;
    final b=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','Waffra-2026-Strong'))
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
      await WaffraSecureBackup.encryptUserBackup(plaintext,'Waffra-2026-Strong'),
    ) as Map<String,dynamic>;
    for (final field in ['data','mac','nonce']) {
      final changed=Map<String,dynamic>.from(original);
      final bytes=base64Decode(changed[field] as String);
      bytes[0]^=1;
      changed[field]=base64Encode(bytes);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Waffra-2026-Strong'),
        throwsA(isA<Exception>()),
        reason:'Modified $field must not decrypt',
      );
    }
  });

  test('M131: malformed metadata fails without returning finance data', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('secret','Waffra-2026-Strong'),
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
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Waffra-2026-Strong'),
        throwsA(isA<Exception>()),
        reason:'Invalid metadata $patch must fail closed',
      );
    }
  });
}
