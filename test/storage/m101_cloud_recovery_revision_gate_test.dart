import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_recovery_revision_gate.dart';
import 'package:waffra/storage/waffra_cloud_encrypted_pull_preview.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  const accepted = WaffraCloudRestoreProof(
    userRequestedRestore: true,
    keyRecovered: true, allRemoteRecordsVerified: true,
    localVaultEmpty: true, localBackupAuthenticated: true,
    receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
  );
  WaffraVerifiedCloudRecordPreview item(String id, {
    int version = 1, bool deleted = false,
  }) => WaffraVerifiedCloudRecordPreview(
    documentId: WaffraEncryptedCloudOutbox.documentId('entry', id),
    kind: 'entry', recordId: id,
    mutationId: 'mutation-v$version',
    remoteVersion: version, deleted: deleted,
    clearRecord: {'id': id, 'amount': 84.72, 'income': false},
  );

  test('M101 full recovered immutable finance index is reviewable', () {
    expect(() => WaffraCloudRecoveryRevisionGate.verify(
      remote: [item('entry-a'), item('entry-b', version: 2)],
      expectedRevisions: {'entry/entry-a': 1, 'entry/entry-b': 2},
      proof: accepted,
    ), returnsNormally);
  });

  test('M101 every absent proof independently blocks remote restoration', () {
    final missing = <WaffraCloudRestoreProof>[
      const WaffraCloudRestoreProof(
        keyRecovered: true, allRemoteRecordsVerified: true,
        localVaultEmpty: true, localBackupAuthenticated: true,
        receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, allRemoteRecordsVerified: true,
        localVaultEmpty: true, localBackupAuthenticated: true,
        receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, keyRecovered: true,
        localVaultEmpty: true, localBackupAuthenticated: true,
        receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, keyRecovered: true,
        allRemoteRecordsVerified: true, localBackupAuthenticated: true,
        receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, keyRecovered: true,
        allRemoteRecordsVerified: true, localVaultEmpty: true,
        receiptsCompleteOrExplicitlyAbsent: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, keyRecovered: true,
        allRemoteRecordsVerified: true, localVaultEmpty: true,
        localBackupAuthenticated: true, rollbackVerified: true,
      ),
      const WaffraCloudRestoreProof(
        userRequestedRestore: true, keyRecovered: true,
        allRemoteRecordsVerified: true, localVaultEmpty: true,
        localBackupAuthenticated: true,
        receiptsCompleteOrExplicitlyAbsent: true,
      ),
    ];
    for (final proof in missing) {
      expect(() => WaffraCloudRecoveryRevisionGate.verify(
        remote: [item('entry-a')],
        expectedRevisions: {'entry/entry-a': 1},
        proof: proof,
      ), throwsA(isA<StateError>()));
    }
  });

  test('M101 missing encrypted record cannot be mistaken for an empty vault',
      () {
    expect(() => WaffraCloudRecoveryRevisionGate.verify(
      remote: [item('entry-a')],
      expectedRevisions: {'entry/entry-a': 1,'entry/entry-b': 1},
      proof: accepted,
    ), throwsA(isA<StateError>()));
  });

  test('M101 old phone revision and duplicate recovery IDs fail closed', () {
    for (final remote in [
      [item('entry-a', version: 1)],
      [item('entry-a', version: 2), item('entry-a', version: 2)],
    ]) {
      expect(() => WaffraCloudRecoveryRevisionGate.verify(
        remote: remote,
        expectedRevisions: {'entry/entry-a': 2},
        proof: accepted,
      ), throwsA(isA<StateError>()));
    }
  });

  test('M101 altered public document hash prevents independent restore', () {
    final original = item('entry-a');
    final altered = WaffraVerifiedCloudRecordPreview(
      documentId: '00000000000000000000000000000000',
      kind: original.kind, recordId: original.recordId,
      mutationId: original.mutationId,
      remoteVersion: original.remoteVersion,
      deleted: false, clearRecord: original.clearRecord,
    );
    expect(() => WaffraCloudRecoveryRevisionGate.verify(
      remote: [altered],
      expectedRevisions: {'entry/entry-a': 1},
      proof: accepted,
    ), throwsA(isA<StateError>()));
  });

  test('M101 remote deletion never silently destroys restored history', () {
    expect(() => WaffraCloudRecoveryRevisionGate.verify(
      remote: [item('entry-a', deleted: true)],
      expectedRevisions: {'entry/entry-a': 1},
      proof: accepted,
    ), throwsA(isA<StateError>()));
  });
}
