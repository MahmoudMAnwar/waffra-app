import 'dart:io';

import 'waffra_encrypted_sms_notes_vault.dart';
import 'waffra_original_sms_portable_preflight.dart';

/// Verifies a portable original-SMS archive against a *brand-new disposable*
/// SQLCipher side vault. It never opens, points at or mutates a live Waffra
/// source and it does not import any finance records or receipt files.
class WaffraDisposableOriginalSmsRestoreReport {
  const WaffraDisposableOriginalSmsRestoreReport({
    required this.confirmedSmsCount,
    required this.verifiedAfterColdReopen,
    required this.financeLinkDigest,
  });

  final int confirmedSmsCount;
  final int verifiedAfterColdReopen;
  final String financeLinkDigest;

  bool get byteExactParityVerified =>
      confirmedSmsCount == verifiedAfterColdReopen;
  bool get activeSourceReplaced => false;
  bool get productionCutoverAuthorized => false;
  bool get twoPhysicalDevicesAttested => false;
}

/// A non-destructive second-side proof for future authenticated note recovery.
///
/// No caller can pass a directory, an OS key, a live database or a source
/// activation marker. After authenticating the password and verifying every
/// ledger ID and SHA-256 fingerprint, this creates a random temporary folder,
/// stages notes under an ephemeral key, closes/reopens the SQLCipher side
/// vault for every read, and destroys the folder on success *or* failure.
/// A full finance+receipt portable restore remains a separate release gate.
class WaffraDisposableOriginalSmsRestoreVerifier {
  const WaffraDisposableOriginalSmsRestoreVerifier();

  Future<WaffraDisposableOriginalSmsRestoreReport> inspect({
    required String encryptedArchive,
    required String password,
    required String expectedLedgerRaw,
    required List<String> expectedHashes,
  }) async {
    // The archive is authenticated BEFORE a destination is created.
    final preview = await WaffraOriginalSmsPortablePreflight.verifyAndPreview(
      encryptedArchive: encryptedArchive,
      password: password,
      expectedLedgerRaw: expectedLedgerRaw,
      expectedHashes: List<String>.unmodifiable(expectedHashes),
    );
    final ids = preview.originalsById.keys.toList()..sort();
    final directory = await Directory.systemTemp.createTemp(
      'waffra-disposable-original-sms-recovery-',
    );
    String? ephemeralKey;
    var counted = 0;
    try {
      final vault = WaffraEncryptedSmsNotesVault(
        directoryProvider: () async => directory,
        keyReader: () async => ephemeralKey,
        keyWriter: (value) async {
          if (ephemeralKey != null) {
            throw StateError('Disposable SMS vault key replacement refused.');
          }
          ephemeralKey = value;
        },
      );

      // The existing encrypted side-vault stage API caps an atomic batch at
      // 100 confirmed originals. Preserve this cap for each SQL transaction.
      for (var offset = 0; offset < ids.length; offset += 100) {
        final end = offset + 100 < ids.length ? offset + 100 : ids.length;
        final current = ids.sublist(offset, end);
        final records = <Map<String, Object?>>[];
        final hashes = <String>[];
        for (final id in current) {
          final original = preview.originalsById[id]!;
          records.add({
            'id': id,
            'sourceType': 'sms',
            'notes': original,
          });
          hashes.add(WaffraEncryptedSmsNotesVault.fingerprint(original));
        }
        await vault.stage(records: records, hashes: hashes);
      }

      if (ids.isNotEmpty) {
        final file = File(
          '${directory.path}/${WaffraEncryptedSmsNotesVault.filename}',
        );
        if (ephemeralKey == null || !await file.exists()) {
          throw StateError('Disposable encrypted SMS destination is missing.');
        }
        // A new reader opens the existing vault from disk with the same
        // ephemeral key, not a still-open staging connection.
        for (final id in ids) {
          final reopened = await vault.readVerifiedEntry(id);
          if (reopened != preview.originalsById[id]) {
            throw StateError('Original SMS bytes changed after cold reopen.');
          }
          counted++;
        }
      }
      if (counted != ids.length) {
        throw StateError('Original SMS restored note count mismatch.');
      }
    } finally {
      // Never leave a disposable plaintext, encrypted db, or temporary OS
      // key behind; it must not become a second authoritative finance vault.
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      ephemeralKey = null;
    }
    return WaffraDisposableOriginalSmsRestoreReport(
      confirmedSmsCount: ids.length,
      verifiedAfterColdReopen: counted,
      financeLinkDigest: preview.financeLinkDigest,
    );
  }
}
