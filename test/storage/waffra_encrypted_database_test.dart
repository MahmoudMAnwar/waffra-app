import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_database.dart';
import 'package:waffra/storage/waffra_vault_keys.dart';

class _MemoryVaultKeys implements WaffraVaultKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> readKey(String vaultId) async => values[vaultId];

  @override
  Future<void> writeKey(String vaultId, String value) async {
    values[vaultId] = value;
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waffra-vault-smoke-');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('each vault gets a 256-bit key, persisted independently', () async {
    final store = _MemoryVaultKeys();
    final manager = WaffraVaultKeyManager(store);
    final first = await manager.getOrCreate(
      vaultId: 'vault_test_001',
      databaseFile: File('${temp.path}/one.db'),
    );
    final second = await manager.getOrCreate(
      vaultId: 'vault_test_002',
      databaseFile: File('${temp.path}/two.db'),
    );

    expect(base64Url.decode(first), hasLength(32));
    expect(base64Url.decode(second), hasLength(32));
    expect(first, isNot(second));
    expect(
      await manager.getOrCreate(
        vaultId: 'vault_test_001',
        databaseFile: File('${temp.path}/one.db'),
      ),
      first,
    );
  });

  test('missing device-wrapped key blocks opening an existing vault', () async {
    final file = File('${temp.path}/orphan.db');
    await file.writeAsBytes([7, 8, 9]);
    final manager = WaffraVaultKeyManager(_MemoryVaultKeys());

    await expectLater(
      manager.getOrCreate(vaultId: 'vault_test_001', databaseFile: file),
      throwsA(isA<StateError>()),
    );
    expect(await file.readAsBytes(), [7, 8, 9]);
  });

  test('new key requires a verified secure-storage round trip', () async {
    final store = _FailingVaultKeys();
    final manager = WaffraVaultKeyManager(store);

    await expectLater(
      manager.getOrCreate(
        vaultId: 'vault_test_001',
        databaseFile: File('${temp.path}/new.db'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await File('${temp.path}/new.db').exists(), isFalse);
  });

  test('encrypted Drift vault round-trips across process-style reopen', () async {
    final file = File('${temp.path}/ledger.enc');
    const password = 'test-only-encryption-key-not-for-production';
    final db = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: password,
    );

    try {
      await db.createVault('vault_test_001');
      await db.createVault('vault_test_002');
      await db.insertShadowEntry(
        vaultId: 'vault_test_001',
        entryId: 'exp001',
        title: 'قهوة',
        categorySnapshot: 'مطاعم',
        amountMinor: 2050,
        isIncome: false,
        occurredIso: '2026-10-21T03:30:00',
        localDate: '2026-10-21',
      );
      await db.insertShadowEntry(
        vaultId: 'vault_test_001',
        entryId: 'inc001',
        title: 'Salary',
        categorySnapshot: 'Salary',
        amountMinor: 250000,
        isIncome: true,
        occurredIso: '2026-10-20T10:20:00',
        localDate: '2026-10-20',
      );
      expect(await db.countActiveEntries('vault_test_001'), 2);
      expect(await db.countActiveEntries('vault_test_002'), 0);
      expect(await db.sumBySide('vault_test_001'),
          (income: 250000, expense: 2050));
      await db.verifyIntegrity();

      await expectLater(
        db.insertShadowEntry(
          vaultId: 'vault_test_001',
          entryId: 'exp001',
          title: 'Duplicate',
          categorySnapshot: 'Other',
          amountMinor: 100,
          isIncome: false,
          occurredIso: '2026-10-21T03:30:00',
          localDate: '2026-10-21',
        ),
        throwsA(isA<Exception>()),
      );
      expect(await db.countActiveEntries('vault_test_001'), 2);
    } finally {
      await db.close();
    }

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(64));
    expect(
      bytes.take(16).toList(),
      isNot(utf8.encode('SQLite format 3\u0000')),
      reason: 'A real encrypted database must not have a plaintext SQLite header.',
    );

    final reopened = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: password,
    );
    try {
      expect(await reopened.countActiveEntries('vault_test_001'), 2);
      expect(await reopened.sumBySide('vault_test_001'),
          (income: 250000, expense: 2050));
      await reopened.verifyIntegrity();
    } finally {
      await reopened.close();
    }
  });

  test('opening with wrong key fails and does not modify encrypted DB', () async {
    final file = File('${temp.path}/locked.enc');
    final db = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: 'correct-secret',
    );
    await db.createVault('vault_test_001');
    await db.close();

    final original = await file.readAsBytes();
    final bad = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: 'wrong-secret',
    );
    await expectLater(
      bad.countActiveEntries('vault_test_001'),
      throwsA(anything),
    );
    try {
      await bad.close();
    } catch (_) {
      // Closing a failed connection must not erase the protected DB.
    }
    expect(await file.readAsBytes(), original);

    final valid = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: 'correct-secret',
    );
    try {
      expect(await valid.countActiveEntries('vault_test_001'), 0);
    } finally {
      await valid.close();
    }
  });

  test('unconfigured or plaintext SQLite engine is never silently accepted',
      () async {
    final file = File('${temp.path}/protected.enc');
    final db = WaffraEncryptedVaultDatabase.open(
      file: file,
      passphrase: 'encryption-verification-secret',
    );
    try {
      await db.createVault('vault_test_001');
      await db.verifyIntegrity();
    } finally {
      await db.close();
    }
    // If build hooks accidentally bundle plaintext SQLite instead of
    // sqlite3mc, this test fails in the database setup callback (in release
    // too, because cipher validation is not gated behind assert()).
  });
}

class _FailingVaultKeys implements WaffraVaultKeyStore {
  @override
  Future<String?> readKey(String vaultId) async => null;

  @override
  Future<void> writeKey(String vaultId, String value) async {}
}
