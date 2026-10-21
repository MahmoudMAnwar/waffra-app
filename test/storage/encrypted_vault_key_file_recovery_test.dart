import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';

void main() {
  test('no previous key and no previous database is a legitimate new install',
      () {
    expect(() => WaffraEncryptedStore.requireConsistentVaultPresence(
      keyPresent: false, databasePresent: false,
    ), returnsNormally);
  });

  test('existing encrypted vault with matching key can reopen', () {
    expect(() => WaffraEncryptedStore.requireConsistentVaultPresence(
      keyPresent: true, databasePresent: true,
    ), returnsNormally);
  });

  test('OS restore cannot silently create an empty vault after losing DB',
      () {
    expect(() => WaffraEncryptedStore.requireConsistentVaultPresence(
      keyPresent: true, databasePresent: false,
    ), throwsA(isA<StateError>()));
  });

  test('lost secure key cannot overwrite existing SQLCipher database',
      () {
    expect(() => WaffraEncryptedStore.requireConsistentVaultPresence(
      keyPresent: false, databasePresent: true,
    ), throwsA(isA<StateError>()));
  });

  test('test vault rejects incorrect key but original key retains finances',
      () async {
    final dir = await Directory.systemTemp.createTemp('waffra-key-safety-');
    final file = File('${dir.path}/existing.sqlite');
    try {
      var db = WaffraEncryptedStore.openAt(
        file, key: 'first-valid-test-only-encrypted-key',
      );
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS finance_safety(id TEXT PRIMARY KEY)',
      );
      await db.customStatement(
        'INSERT INTO finance_safety(id) VALUES (?)', ['preserve-me'],
      );
      await db.close();
      db = WaffraEncryptedStore.openAt(
        file, key: 'different-test-only-encrypted-key',
      );
      await expectLater(
        db.customSelect('SELECT count(*) FROM finance_safety').get(),
        throwsA(isA<Exception>()),
      );
      await db.close();

      db = WaffraEncryptedStore.openAt(
        file, key: 'first-valid-test-only-encrypted-key',
      );
      final result = await db.customSelect(
        'SELECT id FROM finance_safety',
      ).getSingle();
      expect(result.read<String>('id'), 'preserve-me');
      await db.close();
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}
