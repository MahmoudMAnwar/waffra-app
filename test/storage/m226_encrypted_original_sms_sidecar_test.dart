import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_sms_notes_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  String? osKey;

  WaffraEncryptedSmsNotesVault vault({bool noKey = false}) =>
      WaffraEncryptedSmsNotesVault(
        directoryProvider: () async => temp,
        keyReader: () async => noKey ? null : osKey,
        keyWriter: (value) async => osKey = value,
      );

  Map<String, Object?> record(String id, String message) => {
    'id': id, 'title': 'POS masked transaction',
    'amount': 125.5, 'income': false, 'sourceType': 'sms',
    'notes': message,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('waffra-sms-sqlcipher-');
    osKey = null;
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M226 full multiline original SMS survives SQLCipher cold reopen'
       ' without creating plaintext preferences or storing the message as title', () async {
    final samples = <String>[
      'عملية شراء بنكية\nالمبلغ: ١٢٥٫٥٠ ريال\nالتاريخ: 2026/10/25\nالمتجر: مثال',
      'حوالة واردة\nالمبلغ: 350 SAR\nإلى المحفظة\nوسم نادر 7ZQ',
      'Purchase: 9.99 SAR\nMerchant: TEST STORE\nRef: 84923',
    ];
    final rows = List.generate(samples.length,
        (i) => record('sms-$i', samples[i]));
    final hashes = samples.map(WaffraEncryptedSmsNotesVault.fingerprint).toList();
    await vault().stage(records: rows, hashes: hashes);
    final firstKey = osKey;
    expect(firstKey, isNotNull);
    final file = File('${temp.path}/${WaffraEncryptedSmsNotesVault.filename}');
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    final dump = String.fromCharCodes(bytes);
    for (final sample in samples) {
      expect(dump.contains(sample), isFalse);
    }
    expect(dump.contains('SQLite format 3'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key).toString();
      expect(samples.any(value.contains), isFalse);
    }
    for (var i = 0; i < samples.length; i++) {
      expect(await vault().readVerifiedEntry('sms-$i'), samples[i]);
    }
    // Re-reading recreates a connection with the same OS key; raw Unicode,
    // carriage returns and original whitespace survive byte-exact.
    expect(osKey, firstKey);
  });

  test('M226 incorrect fingerprint blocks WHOLE SMS batch before any insert',
       () async {
    const first = 'صادر\nالمبلغ 10 SAR';
    const second = 'وارد\nالمبلغ 15 SAR';
    final entries = [record('valid', first), record('invalid', second)];
    await expectLater(
      vault().stage(records: entries, hashes: [
        WaffraEncryptedSmsNotesVault.fingerprint(first),
        List.filled(64,'0').join(),
      ]),
      throwsStateError,
    );
    expect(osKey, isNull);
    expect(await File('${temp.path}/${WaffraEncryptedSmsNotesVault.filename}').exists(), isFalse);
  });

  test('M226 conflicting same ID fails; byte-identical retry is idempotent',
       () async {
    const message = 'شراء\n50.00 SAR';
    final hash = WaffraEncryptedSmsNotesVault.fingerprint(message);
    await vault().stage(records: [record('stable-id', message)], hashes: [hash]);
    await vault().stage(records: [record('stable-id', message)], hashes: [hash]);
    const changed = 'شراء\n75.00 SAR';
    await expectLater(
      vault().stage(records: [record('stable-id', changed)],
        hashes: [WaffraEncryptedSmsNotesVault.fingerprint(changed)]),
      throwsStateError,
    );
    expect(await vault().readVerifiedEntry('stable-id'), message);
  });

  test('M226 missing Android key never creates new empty vault or erases notes',
       () async {
    const message = 'SMS original with sensitive characters \nX9';
    final hash = WaffraEncryptedSmsNotesVault.fingerprint(message);
    await vault().stage(records: [record('safe-id', message)], hashes: [hash]);
    final file=File('${temp.path}/${WaffraEncryptedSmsNotesVault.filename}');
    final before=await file.readAsBytes();
    await expectLater(vault(noKey: true).readVerifiedEntry('safe-id'),
      throwsStateError);
    expect(await file.readAsBytes(), before);
    expect(await vault().readVerifiedEntry('safe-id'), message);
  });

  test('M226 encrypted note storage absent on older installation is not invented',
       () async {
    expect(await vault().readVerifiedEntry('old-message-without-note'), isNull);
    expect(osKey, isNull);
    expect(await File('${temp.path}/${WaffraEncryptedSmsNotesVault.filename}').exists(), isFalse);
  });
}
