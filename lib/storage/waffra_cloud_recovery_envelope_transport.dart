import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'waffra_firestore_encrypted_sync_transport.dart';
import 'waffra_vault_key_recovery.dart';

/// Owner-only transport for a RECOVERY-CODE-WRAPPED encryption key.
/// Never send WaffraVaultRecoveryBundle (which contains the private code).
/// The actual end-to-end vault key is NEVER uploaded in cleartext.
class WaffraCloudRecoveryEnvelopeTransport {
  const WaffraCloudRecoveryEnvelopeTransport({
    required this.firestore,
    required this.auth,
    this.experimentalEnabled = false,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final bool experimentalEnabled;

  DocumentReference<Map<String, dynamic>> _path(
      String uid, String vaultId) {
    if (uid.trim().isEmpty || uid.contains('/') ||
        !RegExp(r'^[A-Za-z0-9_-]{12,128}$').hasMatch(vaultId) ||
        auth.currentUser?.uid != uid) {
      throw StateError('Authenticated vault owner does not match.');
    }
    return firestore.collection('users').doc(uid)
        .collection('vaults').doc(vaultId)
        .collection('recovery').doc('current');
  }

  /// Must be invoked only after the user explicitly saved their recovery
  /// code and confirmed upload. Versions are compare-and-set; a competing
  /// device is never allowed to silently replace the remote recovery code.
  Future<void> publish({
    required String ownerUid,
    required String vaultId,
    required WaffraVaultRecoveryEnvelope envelope,
    required WaffraCloudSyncAuthorization authorization,
    int? expectedRevision,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      throw StateError('Encrypted cloud recovery upload is not authorized.');
    }
    if (envelope.vaultId != vaultId ||
        envelope.schemaVersion != 1 ||
        envelope.keyVersion < 1 ||
        envelope.recoveryRevision < 1) {
      throw StateError('Vault recovery metadata is invalid.');
    }
    final destination = _path(ownerUid, vaultId);
    final parent = destination.parent.parent!;
    await firestore.runTransaction<void>((tx) async {
      final vault = await tx.get(parent);
      if (!vault.exists || vault.data()?['ownerUid'] != ownerUid ||
          vault.data()?['schemaVersion'] != 1 ||
          vault.data()?['syncEnabled'] != true) {
        throw StateError('User-owned opt-in E2EE vault has not been verified.');
      }
      final current = await tx.get(destination);
      if (!current.exists) {
        if (expectedRevision != null || envelope.recoveryRevision != 1) {
          throw StateError('Initial recovery revision must be exactly one.');
        }
      } else {
        final data = current.data();
        if (data == null ||
            data['vaultId'] != vaultId ||
            data['keyVersion'] != envelope.keyVersion ||
            data['recoveryRevision'] is! int ||
            expectedRevision != data['recoveryRevision'] ||
            envelope.recoveryRevision != expectedRevision! + 1) {
          throw StateError('Recovery code was concurrently rotated.');
        }
      }
      tx.set(destination, {
        ...envelope.toPublicDocument(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }, maxAttempts: 5);
  }

  /// Read the encrypted key package only. User must separately present the
  /// code locally to unwrap it; sign-in alone never grants decryption.
  Future<WaffraVaultRecoveryEnvelope> fetch({
    required String ownerUid,
    required String vaultId,
    required bool userRequestedRecovery,
  }) async {
    if (!experimentalEnabled || !userRequestedRecovery) {
      throw StateError('Encrypted vault recovery was not requested.');
    }
    final reference = _path(ownerUid, vaultId);
    final response = await reference.get(
      const GetOptions(source: Source.server),
    );
    final data = response.data();
    if (!response.exists || data == null ||
        data.keys.toSet().difference({
          'schemaVersion','vaultId','keyVersion','recoveryRevision',
          'wrappedKey','nonce','mac','updatedAt',
        }).isNotEmpty ||
        data['vaultId'] != vaultId) {
      throw StateError('Remote recovery envelope is missing or untrusted.');
    }
    final payload = Map<String, dynamic>.from(data)..remove('updatedAt');
    return WaffraVaultRecoveryEnvelope.fromPublicDocument(payload);
  }
}
