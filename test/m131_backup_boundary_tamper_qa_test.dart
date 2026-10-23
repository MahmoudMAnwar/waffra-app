import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('M131: V2 requires a long passphrase but accepts all scripts',(){
    for(final password in ['LongPass1234!', 'عبارة مرور قوية ٢٠٢٦','Long passphrase'] ){
      expect(WaffraSecureBackup.isValidNewPassword(password),isTrue);
    }
    for(final password in ['','12345678','Abcd1234567']){
      expect(WaffraSecureBackup.isValidNewPassword(password),isFalse);
    }
  });

  test('M131: each export has unique random salt and nonce', () async {
    final a=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','StrongPassphrase123!2026'))
        as Map<String,dynamic>;
    final b=jsonDecode(await WaffraSecureBackup.encryptUserBackup('same','StrongPassphrase123!2026'))
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
      await WaffraSecureBackup.encryptUserBackup(plaintext,'StrongPassphrase123!2026'),
    ) as Map<String,dynamic>;
    for (final field in ['data','mac','nonce']) {
      final changed=Map<String,dynamic>.from(original);
      final bytes=base64Decode(changed[field] as String);
      bytes[0]^=1;
      changed[field]=base64Encode(bytes);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'StrongPassphrase123!2026'),
        throwsA(isA<Exception>()),
        reason:'Modified $field must not decrypt',
      );
    }
  });

  test('M131: malformed metadata fails without returning finance data', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('secret','StrongPassphrase123!2026'),
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
        WaffraSecureBackup.decrypt(jsonEncode(changed),'StrongPassphrase123!2026'),
        throwsA(isA<Exception>()),
        reason:'Invalid metadata $patch must fail closed',
      );
    }
  });
}
