import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_compare_and_swap.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

/// M82 standalone E2EE outbox/conflict QA with a private synthetic SQLCipher
/// database. No Firebase deployment, account login or plaintext uploads.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore db;
  late WaffraEncryptedCloudOutbox outbox;
  final cipher = WaffraCloudCipher();
  const sqlKey = 'm82-independent-disposable-cloud-outbox-key';
  const vaultName = 'm82-private-test-vault';

  Future<WaffraEncryptedCloudRecord> mutation({
    required String mutationId,
    int version = 1,
    String vaultId = vaultName,
    String deviceId = 'phone-A',
    String recordId = 'invoice-1',
  }) async {
    // The key must be private and stable for a given synthetic test fixture.
    return cipher.encrypt(
      vaultKey: await cipher.newRandomVaultKey(),
      vaultId: vaultId,
      kind: 'entry',
      recordId: recordId,
      deviceId: deviceId,
      mutationId: mutationId,
      localVersion: version,
      record: {
        'id': recordId,
        'title': 'Synthetic purchase',
        'category': 'أخرى',
        'amount': 2.50,
        'income': false,
        'date': '2026-10-22T15:00:00',
      },
    );
  }

  WaffraRemoteRevision server(WaffraCloudQueueItem item, {
    bool? deleted,
    String? mutationId,
    int? version,
    String? ciphertext,
  }) => WaffraRemoteRevision(
    documentId: item.documentId,
    kind: item.envelope.kind,
    mutationId: mutationId ?? item.envelope.mutationId,
    deviceId: item.envelope.deviceId,
    localVersion: version ?? item.envelope.localVersion,
    ciphertext: ciphertext ?? item.envelope.ciphertext,
    nonce: item.envelope.nonce,
    mac: item.envelope.mac,
    deleted: deleted ?? item.deleted,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m82-conflicts-');
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/outbox.sqlite'), key: sqlKey,
    );
    outbox = WaffraEncryptedCloudOutbox(db);
  });
  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M82 server acknowledgement cannot silently convert deletion into live entry',
      () async {
    await outbox.enqueue(
      vaultId: vaultName,
      envelope: await mutation(mutationId: 'delete-1'),
      deleted: true,
    );
    final pending = (await outbox.pending(vaultId: vaultName)).single;
    expect(pending.deleted, isTrue);
    final wrong = server(pending, deleted: false);
    expect(WaffraCloudCompareAndSwap.plan(
      item: pending, remote: wrong, expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
    await expectLater(outbox.acknowledge(
      item: pending, confirmedRemote: wrong,
    ), throwsA(isA<StateError>()));
    expect((await outbox.pending(vaultId: vaultName)).single.deleted, isTrue);

    // Only the exact remote tombstone may retire the local mutation.
    await outbox.acknowledge(
      item: pending, confirmedRemote: server(pending),
    );
    expect(await outbox.pending(vaultId: vaultName), isEmpty);
  });

  test('M82 offline FIFO queue cannot acknowledge a forged second revision',
      () async {
    await outbox.enqueue(
      vaultId: vaultName,
      envelope: await mutation(mutationId: 'rev-1', version: 1),
    );
    await outbox.enqueue(
      vaultId: vaultName,
      envelope: await mutation(mutationId: 'rev-2', version: 2),
    );
    final first = (await outbox.pending(vaultId: vaultName)).single;
    expect(first.envelope.mutationId, 'rev-1');
    await outbox.acknowledge(
      item: first, confirmedRemote: server(first),
    );
    final second = (await outbox.pending(vaultId: vaultName)).single;
    expect(second.envelope.mutationId, 'rev-2');
    await expectLater(outbox.acknowledge(
      item: second, confirmedRemote: server(
        second, ciphertext: first.envelope.ciphertext,
      ),
    ), throwsA(isA<StateError>()));
    await expectLater(outbox.acknowledge(
      item: second, confirmedRemote: server(second, version: 5),
    ), throwsA(isA<StateError>()));
    expect((await outbox.pending(vaultId: vaultName)).single
        .envelope.mutationId, 'rev-2');
    await outbox.acknowledge(
      item: second, confirmedRemote: server(second),
    );
    expect(await outbox.pending(vaultId: vaultName), isEmpty);
  });

  test('M82 unresolved cross-device conflict survives encrypted cold restart',
      () async {
    await outbox.enqueue(
      vaultId: vaultName,
      envelope: await mutation(mutationId: 'phone-A-change'),
    );
    final local = (await outbox.pending(vaultId: vaultName)).single;
    final competing = server(local, mutationId: 'phone-B-change');
    expect(WaffraCloudCompareAndSwap.plan(
      item: local, remote: competing,
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
    await expectLater(outbox.acknowledge(
      item: local, confirmedRemote: competing,
    ), throwsA(isA<StateError>()));

    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/outbox.sqlite'), key: sqlKey,
    );
    outbox = WaffraEncryptedCloudOutbox(db);
    final replay = (await outbox.pending(vaultId: vaultName)).single;
    expect(replay.envelope.mutationId, 'phone-A-change');
    expect(replay.envelope.ciphertext, local.envelope.ciphertext);
  });

  test('M82 one private vault acknowledgement cannot clear another vault queue',
      () async {
    await outbox.enqueue(
      vaultId: vaultName,
      envelope: await mutation(mutationId: 'account-a'),
    );
    await outbox.enqueue(
      vaultId: 'm82-other-private-vault',
      envelope: await mutation(
        vaultId: 'm82-other-private-vault',
        mutationId: 'account-b',
      ),
    );
    final a = (await outbox.pending(vaultId: vaultName)).single;
    final b = (await outbox.pending(
      vaultId: 'm82-other-private-vault',
    )).single;
    expect(a.envelope.mutationId, 'account-a');
    expect(b.envelope.mutationId, 'account-b');
    expect(a.envelope.toFirestoreDocument().containsKey('amount'), isFalse);
    expect(a.envelope.toFirestoreDocument().containsKey('title'), isFalse);
    await outbox.acknowledge(item: a, confirmedRemote: server(a));
    expect(await outbox.pending(vaultId: vaultName), isEmpty);
    expect((await outbox.pending(
      vaultId: 'm82-other-private-vault',
    )).single.envelope.mutationId, 'account-b');
  });
}
