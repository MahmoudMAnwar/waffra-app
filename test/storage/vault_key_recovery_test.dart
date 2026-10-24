import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_vault_key_recovery.dart';

void main() {
  late WaffraVaultKeyRecovery recovery;
  late WaffraCloudCipher cipher;

  setUp(() {
    recovery = WaffraVaultKeyRecovery();
    cipher = WaffraCloudCipher();
  });

  test('random recovery code restores E2EE payload on a different device',
      () async {
    final original = await cipher.newRandomVaultKey();
    final bundle = await recovery.create(
      vaultKey: original, vaultId: 'vault-one');
    expect(bundle.recoveryCode, hasLength(43));
    final encrypted = await cipher.encrypt(
      vaultKey: original, vaultId: 'vault-one',
      kind: 'entry', recordId: 'tx-1',
      deviceId: 'old-phone', mutationId: 'm-1', localVersion: 1,
      record: {
        'id': 'tx-1', 'title': 'مرتب خاص', 'category': 'دخل',
        'amount': 100.50, 'income': true,
        'date': '2026-10-21T12:00:00',
      },
    );
    final restored = await recovery.recover(
      vaultId: 'vault-one',
      recoveryCode: bundle.recoveryCode, envelope: bundle.envelope);
    expect(await original.extractBytes(), await restored.extractBytes());
    final result = await cipher.decrypt(
      vaultKey: restored, vaultId: 'vault-one', envelope: encrypted);
    expect(result['title'], 'مرتب خاص');
    expect(result['amount'], 100.50);

    final publicDoc = jsonEncode(bundle.envelope.toPublicDocument());
    expect(publicDoc, isNot(contains(bundle.recoveryCode)));
    expect(publicDoc, isNot(contains('مرتب خاص')));
    expect(publicDoc, isNot(contains('100.50')));
    expect(publicDoc, isNot(contains('secretKey')));
  });

  test('wrong recovery code and wrong vault fail closed', () async {
    final key = await cipher.newRandomVaultKey();
    final first = await recovery.create(
      vaultKey: key, vaultId: 'vault-one');
    final second = await recovery.create(
      vaultKey: key, vaultId: 'vault-one');
    await expectLater(
      recovery.recover(
        vaultId: 'vault-one', recoveryCode: second.recoveryCode,
        envelope: first.envelope),
      throwsA(anything),
    );
    await expectLater(
      recovery.recover(
        vaultId: 'another-vault', recoveryCode: first.recoveryCode,
        envelope: first.envelope),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      recovery.recover(
        vaultId: 'vault-one',
        recoveryCode: first.recoveryCode.substring(0, 42),
        envelope: first.envelope),
      throwsA(isA<FormatException>()),
    );
  });

  test('tampering with AES-GCM tag, nonce or key version cannot decrypt',
      () async {
    final key = await cipher.newRandomVaultKey();
    final bundle = await recovery.create(
      vaultKey: key, vaultId: 'vault-one');
    final e = bundle.envelope;
    Future<void> fails(WaffraVaultRecoveryEnvelope altered) async {
      await expectLater(
        recovery.recover(
          vaultId: 'vault-one', recoveryCode: bundle.recoveryCode,
          envelope: altered),
        throwsA(anything),
      );
    }

    await fails(WaffraVaultRecoveryEnvelope(
      vaultId: e.vaultId, keyVersion: e.keyVersion + 1,
      recoveryRevision: e.recoveryRevision, wrappedKey: e.wrappedKey,
      nonce: e.nonce, mac: e.mac,
    ));
    await fails(WaffraVaultRecoveryEnvelope(
      vaultId: e.vaultId, keyVersion: e.keyVersion,
      recoveryRevision: e.recoveryRevision, wrappedKey: e.wrappedKey,
      nonce: e.nonce, mac: base64Encode(List<int>.filled(16, 0)),
    ));
    await fails(WaffraVaultRecoveryEnvelope(
      vaultId: e.vaultId, keyVersion: e.keyVersion,
      recoveryRevision: e.recoveryRevision, wrappedKey: e.wrappedKey,
      nonce: base64Encode(List<int>.filled(12, 0)), mac: e.mac,
    ));
  });

  test('recovery code rotation changes code without changing vault key',
      () async {
    final key = await cipher.newRandomVaultKey();
    final old = await recovery.create(
      vaultKey: key, vaultId: 'vault-one');
    final newer = await recovery.rotateCode(
      vaultKey: key, previous: old.envelope);
    expect(newer.recoveryCode, isNot(old.recoveryCode));
    expect(newer.envelope.recoveryRevision, 2);
    final restored = await recovery.recover(
      vaultId: 'vault-one', recoveryCode: newer.recoveryCode,
      envelope: newer.envelope);
    expect(await restored.extractBytes(), await key.extractBytes());
    await expectLater(
      recovery.recover(
        vaultId: 'vault-one', recoveryCode: old.recoveryCode,
        envelope: newer.envelope),
      throwsA(anything),
    );
  });

  test('strict document parsing prevents accidental secret fields', () async {
    final bundle = await recovery.create(
      vaultKey: await cipher.newRandomVaultKey(), vaultId: 'vault-one');
    final map = bundle.envelope.toPublicDocument();
    final decoded = WaffraVaultRecoveryEnvelope.fromPublicDocument(
      Map<String, dynamic>.from(map));
    expect(decoded.toPublicDocument(), map);
    expect(() => WaffraVaultRecoveryEnvelope.fromPublicDocument(
      Map<String, dynamic>.from(map)..['recoveryCode'] = bundle.recoveryCode),
      throwsA(isA<FormatException>()),
    );
    expect(() => WaffraVaultRecoveryEnvelope.fromPublicDocument(
      Map<String, dynamic>.from(map)..remove('mac')),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      recovery.create(
        vaultKey: await cipher.newRandomVaultKey(), vaultId: 'invalid/vault'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
