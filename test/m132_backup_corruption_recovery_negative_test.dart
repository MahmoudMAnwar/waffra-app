import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('M132: truncated, non-JSON and non-object archives fail closed', () async {
    for (final payload in <String>['', '{', 'not-json', 'null', '[]', '"archive"', '42']) {
      await expectLater(
        WaffraSecureBackup.decrypt(payload,'Abcd1234'),
        throwsA(isA<Exception>()),
        reason:'Invalid archive must not return finance data: $payload',
      );
    }
  });

  test('M132: missing encrypted archive fields never return plaintext', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('private-finance','Abcd1234'),
    ) as Map<String,dynamic>;
    for (final field in <String>['format','version','iterations','cipher','salt','nonce','data','mac']) {
      final changed=Map<String,dynamic>.from(original)..remove(field);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Abcd1234'),
        throwsA(isA<Exception>()),
        reason:'Missing $field must fail closed',
      );
    }
  });

  test('M132: wrong and empty passwords cannot unlock encrypted backups', () async {
    const privateData='{"transactions":[{"amount":123456}]}';
    final archive=await WaffraSecureBackup.encryptUserBackup(privateData,'Abcd1234');
    for (final password in <String>['','Abcd1235','abcd1234','Wrong123']) {
      await expectLater(
        WaffraSecureBackup.decrypt(archive,password),
        throwsA(isA<Exception>()),
        reason:'Wrong password must fail: $password',
      );
    }
    expect(await WaffraSecureBackup.decrypt(archive,'Abcd1234'),privateData);
  });

  test('M132: invalid base64 or truncated ciphertext cannot be restored', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('private-finance','Abcd1234'),
    ) as Map<String,dynamic>;
    for (final field in <String>['salt','nonce','data','mac']) {
      final invalid=Map<String,dynamic>.from(original)..[field]='not-base64!?';
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(invalid),'Abcd1234'),
        throwsA(isA<Exception>()),
        reason:'Malformed base64 in $field',
      );
    }
    final truncated=Map<String,dynamic>.from(original);
    final bytes=base64Decode(truncated['data'] as String);
    truncated['data']=base64Encode(bytes.sublist(0,bytes.length-1));
    await expectLater(
      WaffraSecureBackup.decrypt(jsonEncode(truncated),'Abcd1234'),
      throwsA(isA<Exception>()),
    );
  });
}
