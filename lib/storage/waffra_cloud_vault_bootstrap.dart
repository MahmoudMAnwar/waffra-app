import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'waffra_firestore_encrypted_sync_transport.dart';

enum WaffraCloudVaultSetupResult {
  blocked, created, alreadyVerified,
}

/// Creates an opt-in Firestore E2EE vault ONLY after independent key recovery,
/// local SQLCipher routing and explicit user consent have all been verified.
/// No account/profile/banking or encryption key is uploaded in metadata.
///
/// The actual first-device key is created/recovered elsewhere; this component
/// never invents an empty financial source or changes the local finance DB.
class WaffraCloudVaultBootstrap {
  const WaffraCloudVaultBootstrap({
    required this.firestore,
    required this.auth,
    this.experimentalEnabled = false,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final bool experimentalEnabled;

  Future<WaffraCloudVaultSetupResult> ensureVerifiedVault({
    required String ownerUid,
    required String vaultId,
    required WaffraCloudSyncAuthorization authorization,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      return WaffraCloudVaultSetupResult.blocked;
    }
    if (auth.currentUser?.uid != ownerUid ||
        ownerUid.isEmpty || ownerUid.contains('/') ||
        !RegExp(r'^[A-Za-z0-9_-]{12,128}$').hasMatch(vaultId)) {
      throw StateError('Invalid authenticated cloud vault identity.');
    }
    final reference = firestore.collection('users').doc(ownerUid)
        .collection('vaults').doc(vaultId);
    return firestore.runTransaction<WaffraCloudVaultSetupResult>((tx) async {
      final current = await tx.get(reference);
      if (current.exists) {
        final data = current.data();
        if (data == null ||
            data['ownerUid'] != ownerUid ||
            data['schemaVersion'] != 1 ||
            data['syncEnabled'] != true) {
          throw StateError('Cloud vault metadata needs manual reconciliation.');
        }
        return WaffraCloudVaultSetupResult.alreadyVerified;
      }
      tx.set(reference, <String, Object>{
        'ownerUid': ownerUid,
        'schemaVersion': 1,
        'syncEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return WaffraCloudVaultSetupResult.created;
    }, maxAttempts: 5);
  }
}
