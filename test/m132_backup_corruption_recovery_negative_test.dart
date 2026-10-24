import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('M132: truncated, non-JSON and non-object archives fail closed', () async {
    for (final payload in <String>['', '{', 'not-json', 'null', '[]', '"archive"', '42']) {
      await expectLater(
        WaffraSecureBackup.decrypt(payload,'Waffra-2026-Strong'),
        throwsA(isA<Exception>()),
        reason:'Invalid archive must not return finance data: $payload',
      );
    }
  });

  test('M132: missing encrypted archive fields never return plaintext', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('private-finance','Waffra-2026-Strong'),
    ) as Map<String,dynamic>;
    for (final field in <String>['format','version','kdf','iterations','memory','parallelism','cipher','salt','nonce','data','mac']) {
      final changed=Map<String,dynamic>.from(original)..remove(field);
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(changed),'Waffra-2026-Strong'),
        throwsFormatException,
        reason:'Missing $field must fail with a controlled format error',
      );
    }
  });

  test('M132: null, numeric and structured cipher fields fail predictably', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('private-finance','Waffra-2026-Strong'),
    ) as Map<String,dynamic>;
    for (final field in <String>['salt','nonce','data','mac']) {
      for (final wrongType in <dynamic>[null,42,<String,dynamic>{'not':'base64'}]) {
        final changed=Map<String,dynamic>.from(original);
        changed[field]=wrongType;
        await expectLater(
          WaffraSecureBackup.decrypt(jsonEncode(changed),'Waffra-2026-Strong'),
          throwsFormatException,
          reason:'Malformed field $field with wrong type must throw FormatException',
        );
      }
    }
  });

  test('M132: wrong and empty passwords cannot unlock encrypted backups', () async {
    const privateData='{"transactions":[{"amount":123456}]}';
    final archive=await WaffraSecureBackup.encryptUserBackup(privateData,'Waffra-2026-Strong');
    for (final password in <String>['','Abcd1235','abcd1234','Wrong123']) {
      await expectLater(
        WaffraSecureBackup.decrypt(archive,password),
        throwsA(isA<Exception>()),
        reason:'Wrong password must fail: $password',
      );
    }
    expect(await WaffraSecureBackup.decrypt(archive,'Waffra-2026-Strong'),privateData);
  });

  test('M132: invalid base64 or truncated ciphertext cannot be restored', () async {
    final original=jsonDecode(
      await WaffraSecureBackup.encryptUserBackup('private-finance','Waffra-2026-Strong'),
    ) as Map<String,dynamic>;
    for (final field in <String>['salt','nonce','data','mac']) {
      final invalid=Map<String,dynamic>.from(original)..[field]='not-base64!?';
      await expectLater(
        WaffraSecureBackup.decrypt(jsonEncode(invalid),'Waffra-2026-Strong'),
        throwsA(isA<Exception>()),
        reason:'Malformed base64 in $field',
      );
    }
    final truncated=Map<String,dynamic>.from(original);
    final bytes=base64Decode(truncated['data'] as String);
    truncated['data']=base64Encode(bytes.sublist(0,bytes.length-1));
    await expectLater(
      WaffraSecureBackup.decrypt(jsonEncode(truncated),'Waffra-2026-Strong'),
      throwsA(isA<Exception>()),
    );
  });
}
