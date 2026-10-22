import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_encrypted_pull_preview.dart';
import 'package:waffra/storage/waffra_cloud_recovery_manifest.dart';
import 'package:waffra/storage/waffra_cloud_remote_manifest_verifier.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const vault = 'unified-synthetic-recovery-vault';
  late SecretKey key;

  const records = [
    WaffraCloudRecordPointer(
      kind: 'entry', id: 'entry-a', mutationId: 'commit-a',
      version: 1, deleted: false,
    ),
    WaffraCloudRecordPointer(
      kind: 'goal', id: 'goal-b', mutationId: 'commit-b',
      version: 2, deleted: false,
    ),
  ];

  Future<WaffraCloudQueueItem> preparedManifest() async {
    final envelope = await WaffraCloudRecoveryManifest.encrypt(
      recoveredVaultKey: key, vaultId: vault,
      deviceId: 'test-device', mutationId: 'manifest-mutation-1',
      version: 1, records: records,
    );
    return WaffraCloudQueueItem(
      vaultId: vault,
      documentId: WaffraEncryptedCloudOutbox.documentId(
        'manifest', 'finance-index',
      ),
      envelope: envelope, deleted: false,
    );
  }

  WaffraVerifiedCloudRecordPreview remote(
    WaffraCloudRecordPointer p, {
      int? version, String? mutationId, bool? deleted,
      String? recordId, String? kind,
    }
  ) => WaffraVerifiedCloudRecordPreview(
    kind: kind ?? p.kind, recordId: recordId ?? p.id,
    documentId: WaffraEncryptedCloudOutbox.documentId(p.kind, p.id),
    mutationId: mutationId ?? p.mutationId,
    remoteVersion: version ?? p.version,
    deleted: deleted ?? p.deleted,
    clearRecord: {'id': p.id},
  );

  setUp(() async {
    key = await AesGcm.with256bits().newSecretKey();
  });

  test('remote-proof checks exact ID, kind, revision and mutation', () async {
    final index = await preparedManifest();
    final ok = await WaffraCloudRemoteManifestVerifier.verifyWithSource(
      pendingManifest: index,
      vaultKey: key,
      fetchRemote: (pointer) async => remote(pointer),
    );
    expect(ok, isTrue);
  });

  test('remote missing document never allows a recovery index', () async {
    final index = await preparedManifest();
    expect(await WaffraCloudRemoteManifestVerifier.verifyWithSource(
      pendingManifest: index,
      vaultKey: key,
      fetchRemote: (pointer) async =>
          pointer.id == 'goal-b' ? null : remote(pointer),
    ), isFalse);
  });

  test('conflicting second device, stale version and tombstone fail closed',
      () async {
    final index = await preparedManifest();
    for (final mode in ['version', 'mutation', 'deleted', 'kind', 'id']) {
      final accepted =
          await WaffraCloudRemoteManifestVerifier.verifyWithSource(
        pendingManifest: index, vaultKey: key,
        fetchRemote: (pointer) async {
          if (pointer.id != 'goal-b') return remote(pointer);
          return switch (mode) {
            'version' => remote(pointer, version: pointer.version + 1),
            'mutation' => remote(pointer, mutationId: 'other-phone-write'),
            'deleted' => remote(pointer, deleted: true),
            'kind' => remote(pointer, kind: 'entry'),
            _ => remote(pointer, recordId: 'wrong-finance-record'),
          };
        },
      );
      expect(accepted, isFalse, reason: mode);
    }
  });

  test('wrong E2EE key cannot prove remote finance inventory', () async {
    final index = await preparedManifest();
    final wrong = await AesGcm.with256bits().newSecretKey();
    await expectLater(WaffraCloudRemoteManifestVerifier.verifyWithSource(
      pendingManifest: index, vaultKey: wrong,
      fetchRemote: (pointer) async => remote(pointer),
    ), throwsA(anything));
  });

  test('unknown index identity and remote deletion cannot publish', () async {
    final index = await preparedManifest();
    final wrongDocument = WaffraCloudQueueItem(
      vaultId: vault, documentId: 'wrong-document',
      envelope: index.envelope, deleted: false,
    );
    final deleted = WaffraCloudQueueItem(
      vaultId: vault, documentId: index.documentId,
      envelope: index.envelope, deleted: true,
    );
    for (final invalid in [wrongDocument, deleted]) {
      expect(await WaffraCloudRemoteManifestVerifier.verifyWithSource(
        pendingManifest: invalid,
        vaultKey: key,
        fetchRemote: (p) async => remote(p),
      ), isFalse);
    }
  });
}
