import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_vault_key_recovery.dart';

/// M88 synthetic recovery-key tests. No secrets, user identifiers or
/// Firebase account accessed; checks offline authentication primitives only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recovery = WaffraVaultKeyRecovery();
  final crypto = WaffraCloudCipher();

  test('M88 recovery code safely opens a private E2EE record on new device',
      () async {
    final key = await crypto.newRandomVaultKey();
    final bundle = await recovery.create(
      vaultKey: key, vaultId: 'm88-vault',
    );
    final envelope = await crypto.encrypt(
      vaultKey: key, vaultId: 'm88-vault', kind: 'entry',
      recordId: 'm88-transaction', deviceId: 'device-one',
      mutationId: 'm88-write-1', localVersion: 1,
      record: {
        'id': 'm88-transaction', 'title': 'Synthetic finance',
        'category': 'أخرى', 'amount': 84.72,
        'income': false, 'date': '2026-10-22T12:00:00',
      },
    );
    final recovered = await recovery.recover(
      vaultId: 'm88-vault', recoveryCode: bundle.recoveryCode,
      envelope: bundle.envelope,
    );
    final clear = await crypto.decrypt(
      vaultKey: recovered, vaultId: 'm88-vault', envelope: envelope,
    );
    expect(clear['amount'], 84.72);
    expect(clear['title'], 'Synthetic finance');
    final publicJson = jsonEncode(bundle.envelope.toPublicDocument());
    expect(publicJson, isNot(contains(bundle.recoveryCode)));
    expect(publicJson, isNot(contains('Synthetic finance')));
  });

  test('M88 mismatched vault and unrelated recovery code cannot recover data',
      () async {
    final key = await crypto.newRandomVaultKey();
    final first = await recovery.create(vaultKey: key, vaultId: 'm88-vault');
    final second = await recovery.create(vaultKey: key, vaultId: 'm88-vault');
    await expectLater(recovery.recover(
      vaultId: 'm88-vault', recoveryCode: second.recoveryCode,
      envelope: first.envelope,
    ), throwsA(anything));
    await expectLater(recovery.recover(
      vaultId: 'm88-other-vault', recoveryCode: first.recoveryCode,
      envelope: first.envelope,
    ), throwsA(isA<StateError>()));
  });

  test('M88 rotated code recovers same encryption key but old code fails',
      () async {
    final original = await crypto.newRandomVaultKey();
    final first = await recovery.create(
      vaultKey: original, vaultId: 'm88-vault',
    );
    final rotated = await recovery.rotateCode(
      vaultKey: original, previous: first.envelope,
    );
    expect(rotated.envelope.recoveryRevision,
        first.envelope.recoveryRevision + 1);
    expect(rotated.recoveryCode, isNot(first.recoveryCode));
    final nextKey = await recovery.recover(
      vaultId: 'm88-vault', recoveryCode: rotated.recoveryCode,
      envelope: rotated.envelope,
    );
    expect(await nextKey.extractBytes(), await original.extractBytes());
    await expectLater(recovery.recover(
      vaultId: 'm88-vault', recoveryCode: first.recoveryCode,
      envelope: rotated.envelope,
    ), throwsA(anything));
  });

  test('M88 public recovery document rejects extra private fields',
      () async {
    final current = await recovery.create(
      vaultKey: await crypto.newRandomVaultKey(), vaultId: 'm88-vault',
    );
    final document = Map<String, dynamic>.from(
      current.envelope.toPublicDocument(),
    );
    expect(() => WaffraVaultRecoveryEnvelope.fromPublicDocument(
      {...document, 'recoveryCode': current.recoveryCode},
    ), throwsA(isA<FormatException>()));
    expect(() => WaffraVaultRecoveryEnvelope.fromPublicDocument(
      {...document}..remove('mac'),
    ), throwsA(isA<FormatException>()));
  });
}
