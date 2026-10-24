import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'waffra_encrypted_store.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_restored_finance_receipt_attestor.dart';
import 'waffra_runtime_finance_route_contract.dart';
import 'waffra_verified_finance_authority.dart';

/// A deliberately read-only decision. It cannot replace, swap, wipe,
/// migrate, update a source marker or activate an encrypted finance vault.
class WaffraVerifiedRestorePreflightResult {
  const WaffraVerifiedRestorePreflightResult({
    required this.sourceGeneration,
    required this.sourceDigest,
    required this.archiveChecksum,
    required this.transactionCount,
    required this.receiptCount,
    required this.receiptBytes,
  });

  final int sourceGeneration;
  final String sourceDigest;
  final String archiveChecksum;
  final int transactionCount;
  final int receiptCount;
  final int receiptBytes;

  /// Only the explicit cross-device activation/coordinator can ever authorize
  /// replacing an active vault. This preflight is NEVER such approval.
  bool get activationAuthorized => false;
  bool get activeSourceReplaced => false;
  bool get requiresIndependentDeviceRecovery => true;
}

/// Read-only, password-authenticated preflight BEFORE restoring a portable
/// archive to an already active encrypted finance source.
///
/// The existing source is checked through the SAME authority route used for
/// Home and Widget. The candidate is restored to an independently generated
/// temporary SQLCipher database, independently byte-attested and COLD reopened.
/// The candidate file + disposable key are destroyed on every exit path.
/// NO caller-selected database path or key is accepted, to prevent accidentally
/// passing the live source as a staging destination.
///
/// This does not restore/replace an active vault or approve production cutover.
class WaffraVerifiedActiveRestorePreflight {
  const WaffraVerifiedActiveRestorePreflight({
    required this.authority,
    this.experimentalEnabled = false,
  });

  final WaffraVerifiedFinanceAuthority authority;
  final bool experimentalEnabled;

  Future<WaffraVerifiedRestorePreflightResult> inspect({
    required WaffraFinanceAuthorityRead selectedSource,
    required String encryptedArchive,
    required String password,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed ||
        authority.encryptedSession?.experimentalEnabled != true ||
        selectedSource.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        selectedSource.encryptedWitness == null) {
      throw StateError('Verified source and explicit restore preflight are required.');
    }
    if (password.length < 12 || password.length > 4096) {
      throw ArgumentError('Restore password length is invalid.');
    }

    Future<WaffraFinanceAuthorityRead> fresh() =>
        authority.load(route: WaffraFinanceRoute.backupRestore);
    final current = await fresh();
    current.finance.requireIntegrity();
    final selected = selectedSource.encryptedWitness!;
    final witness = current.encryptedWitness;
    if (current.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        witness == null ||
        witness.generation != selected.generation ||
        witness.digest != selected.digest ||
        current.widgetRevision != selectedSource.widgetRevision) {
      throw StateError('Active Home/Widget finance changed before preview.');
    }

    // The encrypted archive is authenticated before opening ANY candidate.
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedArchive,
      password: password,
    );

    // These bytes live only in a uniquely generated temporary SQLCipher file.
    // The user cannot select an active vault path or provide its secure key.
    final stagingDirectory = await Directory.systemTemp.createTemp(
      'waffra-verified-restore-preflight-',
    );
    final keyBytes = List<int>.generate(
      32, (_) => Random.secure().nextInt(256),
      growable: false,
    );
    final disposableKey = base64UrlEncode(keyBytes);
    final candidateFile = File('${stagingDirectory.path}/candidate.sqlite');
    WaffraEncryptedStore? candidate;
    try {
      candidate = WaffraEncryptedStore.openAt(
        candidateFile, key: disposableKey,
      );
      final result = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: candidate,
        experimentalEnabled: true,
      ).restore(
        encryptedArchive: encryptedArchive,
        password: password,
      );
      if (result.sourceChecksum != preview.sourceChecksum ||
          result.receiptCount != preview.receiptCount) {
        throw StateError('Staged backup and authenticated receipt manifest disagree.');
      }
      await WaffraRestoredFinanceReceiptAttestor(
        store: candidate, experimentalEnabled: true,
      ).attest(authenticatedArchive: preview, reported: result);

      // Durable DB reopen proves nothing lived only in a warm SQLite cache.
      await candidate.close();
      candidate = null;
      candidate = WaffraEncryptedStore.openAt(
        candidateFile, key: disposableKey,
      );
      await WaffraRestoredFinanceReceiptAttestor(
        store: candidate, experimentalEnabled: true,
      ).attest(authenticatedArchive: preview, reported: result);

      // Another Home/Widget write during the expensive archive validation
      // invalidates this preflight. Never overwrite or update that live source.
      final after = await fresh();
      after.finance.requireIntegrity();
      final latest = after.encryptedWitness;
      if (after.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
          latest == null ||
          latest.generation != witness.generation ||
          latest.digest != witness.digest ||
          after.widgetRevision != current.widgetRevision) {
        throw StateError('Active financial source changed during backup preflight.');
      }
      return WaffraVerifiedRestorePreflightResult(
        sourceGeneration: witness.generation,
        sourceDigest: witness.digest,
        archiveChecksum: result.sourceChecksum,
        transactionCount: result.transactionCount,
        receiptCount: result.receiptCount,
        receiptBytes: result.receiptBytes,
      );
    } finally {
      try {
        if (candidate != null) await candidate.close();
      } finally {
        if (await stagingDirectory.exists()) {
          await stagingDirectory.delete(recursive: true);
        }
      }
    }
  }
}
