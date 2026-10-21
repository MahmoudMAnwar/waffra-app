import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  late Directory sandbox;
  late File file;
  late WaffraEncryptedStore database;
  late WaffraEncryptedCloudOutbox outbox;
  late WaffraCloudCipher cipher;
  late SecretKey key;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-cloud-queue-');
    file = File('${sandbox.path}/encrypted.db');
    database = WaffraEncryptedStore.openAt(
      file, key: 'testing-project-funds-not-production-32');
    outbox = WaffraEncryptedCloudOutbox(database);
    cipher = WaffraCloudCipher();
    key = await cipher.newRandomVaultKey();
  });

  tearDown(() async {
    await database.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<WaffraEncryptedCloudRecord> encrypted({
    String vault = 'vault-A',
    String kind = 'entry',
    String recordId = 'record-1',
    String mutationId = 'mutation-1',
    String deviceId = 'device-A',
    int version = 1,
  }) => cipher.encrypt(
    vaultKey: key,
    vaultId: vault,
    kind: kind,
    recordId: recordId,
    deviceId: deviceId,
    mutationId: mutationId,
    localVersion: version,
    record: kind == 'goal'
        ? {'id': recordId, 'name': 'Emergency', 'target': 100, 'saved': 5}
        : {
            'id': recordId,
            'title': 'قهوة خاصة',
            'category': 'مقهى',
            'amount': 21.25,
            'income': false,
            'date': '2026-10-21T08:30:00',
          },
  );

  WaffraRemoteRevision acknowledged(WaffraCloudQueueItem item) =>
      WaffraRemoteRevision(
        documentId: item.documentId,
        kind: item.envelope.kind,
        mutationId: item.envelope.mutationId,
        deviceId: item.envelope.deviceId,
        localVersion: item.envelope.localVersion,
        deleted: item.deleted,
      );

  test('encrypted queue persists across SQLite restart, no cleartext in file',
      () async {
    final e = await encrypted();
    await outbox.enqueue(vaultId: 'vault-A', envelope: e);
    final first = await outbox.pending(vaultId: 'vault-A');
    expect(first, hasLength(1));
    expect(first.single.envelope.mutationId, 'mutation-1');
    expect(first.single.envelope.ciphertext, e.ciphertext);
    expect(first.single.documentId, hasLength(64));

    // Reopen to prove this is an encrypted persistent queue, not memory only.
    await database.close();
    database = WaffraEncryptedStore.openAt(
      file, key: 'testing-project-funds-not-production-32');
    outbox = WaffraEncryptedCloudOutbox(database);
    final restored = await outbox.pending(vaultId: 'vault-A');
    expect(restored, hasLength(1));
    final clear = await cipher.decrypt(
      vaultKey: key, vaultId: 'vault-A', envelope: restored.single.envelope);
    expect(clear['title'], 'قهوة خاصة');
    expect(clear['amount'], 21.25);

    await database.close();
    final raw = await file.readAsBytes();
    expect(raw.take(16).toList(), isNot(utf8.encode('SQLite format 3\u0000')));
    expect(utf8.decode(raw, allowMalformed: true), isNot(contains('قهوة خاصة')));
    expect(utf8.decode(raw, allowMalformed: true), isNot(contains('21.25')));
    database = WaffraEncryptedStore.openAt(
      file, key: 'testing-project-funds-not-production-32');
    outbox = WaffraEncryptedCloudOutbox(database);
  });

  test('same mutation retries idempotently but different bytes fail closed',
      () async {
    final e = await encrypted();
    await outbox.enqueue(vaultId: 'vault-A', envelope: e);
    await outbox.enqueue(vaultId: 'vault-A', envelope: e);
    expect(await outbox.pending(vaultId: 'vault-A'), hasLength(1));
    await expectLater(
      outbox.enqueue(
        vaultId: 'vault-A',
        envelope: e.copyWith(ciphertext: base64Encode([1, 2, 3])),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await outbox.pending(vaultId: 'vault-A'), hasLength(1));
  });

  test('one pending mutation per record, FIFO continues only after ack',
      () async {
    await outbox.enqueue(
      vaultId: 'vault-A', envelope: await encrypted());
    await outbox.enqueue(
      vaultId: 'vault-A',
      envelope: await encrypted(mutationId: 'mutation-2', version: 2));
    await outbox.enqueue(
      vaultId: 'vault-A',
      envelope: await encrypted(recordId: 'record-2', mutationId: 'mutation-3'));
    final ready = await outbox.pending(vaultId: 'vault-A');
    expect(ready, hasLength(2));
    expect(ready.map((x) => x.envelope.mutationId),
      containsAll(['mutation-1', 'mutation-3']));
    expect(ready.map((x) => x.envelope.mutationId), isNot(contains('mutation-2')));

    final first = ready.firstWhere(
      (item) => item.envelope.mutationId == 'mutation-1');
    await outbox.acknowledge(item: first, confirmedRemote: acknowledged(first));
    final next = await outbox.pending(vaultId: 'vault-A');
    expect(next.map((x) => x.envelope.mutationId), contains('mutation-2'));
    expect(next, hasLength(2));
    await expectLater(
      outbox.enqueue(
        vaultId: 'vault-A',
        envelope: await encrypted(mutationId: 'bad-old', version: 2)),
      throwsA(isA<StateError>()),
    );
  });

  test('explicit sync gate and optimistic conflict detection fail closed',
      () async {
    await outbox.enqueue(vaultId: 'vault-A', envelope: await encrypted());
    final item = (await outbox.pending(vaultId: 'vault-A')).single;

    WaffraRemoteAction check(
        WaffraRemoteRevision? remote, {
        bool consent = true, bool identity = true,
        bool recovery = true, bool transport = true,
      }) => WaffraEncryptedCloudOutbox.preflight(
        item: item, remote: remote, consentGiven: consent,
        identityVerified: identity, recoveryReady: recovery,
        atomicRemoteTransportReady: transport,
      );

    expect(check(null, consent: false), WaffraRemoteAction.blocked);
    expect(check(null, identity: false), WaffraRemoteAction.blocked);
    expect(check(null, recovery: false), WaffraRemoteAction.blocked);
    expect(check(null, transport: false), WaffraRemoteAction.blocked);
    expect(check(null), WaffraRemoteAction.createIfAbsent);
    expect(check(acknowledged(item)), WaffraRemoteAction.alreadyApplied);
    expect(check(WaffraRemoteRevision(
      documentId: item.documentId, kind: 'entry',
      mutationId: 'other-device-write', deviceId: 'device-B',
      localVersion: 999, deleted: false,
    )), WaffraRemoteAction.manualConflict);
  });

  test('a conflict or different acknowledgement never removes local data',
      () async {
    await outbox.enqueue(vaultId: 'vault-A', envelope: await encrypted());
    final item = (await outbox.pending(vaultId: 'vault-A')).single;
    final different = WaffraRemoteRevision(
      documentId: item.documentId, kind: 'entry',
      mutationId: 'other-mutation', deviceId: 'device-B',
      localVersion: 20, deleted: false,
    );
    await expectLater(
      outbox.acknowledge(item: item, confirmedRemote: different),
      throwsA(isA<StateError>()),
    );
    expect(await outbox.pending(vaultId: 'vault-A'), hasLength(1));
  });

  test('vault separation, type-safe IDs, and deletion tombstones are retained',
      () async {
    await outbox.enqueue(
      vaultId: 'vault-A',
      envelope: await encrypted(mutationId: 'mutation-deleted'), deleted: true);
    await outbox.enqueue(
      vaultId: 'vault-A',
      envelope: await encrypted(kind: 'goal', mutationId: 'goal-mutation'));
    await outbox.enqueue(
      vaultId: 'vault-B',
      envelope: await encrypted(vault: 'vault-B', mutationId: 'other-vault'));
    final a = await outbox.pending(vaultId: 'vault-A');
    final b = await outbox.pending(vaultId: 'vault-B');
    expect(a, hasLength(2));
    expect(b, hasLength(1));
    expect(a.map((e) => e.documentId).toSet(), hasLength(2));
    expect(a.first.deleted, isTrue);
    expect(a.first.envelope.toFirestoreDocument(deleted: a.first.deleted)
        ['deleted'], isTrue);
    expect(b.single.envelope.mutationId, 'other-vault');
    expect(() => WaffraEncryptedCloudOutbox.documentId('entry', ''),
        throwsA(isA<ArgumentError>()));
  });
}
