import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

class WaffraProductionCopyStageReport {
  const WaffraProductionCopyStageReport({
    required this.sourceDigest,
    required this.transactions,
    required this.receipts,
    required this.receiptBytes,
    required this.targetGeneration,
  });

  final String sourceDigest;
  final int transactions, receipts, receiptBytes, targetGeneration;
}

/// PRE-ACTIVATION COPY ONLY: stages all existing finance keys and verified
/// on-device receipt images into a separately owned EMPTY SQLCipher vault.
/// The original user source is never removed, edited or hidden.
///
/// Dashboard and quick-add Widget finance writes cooperate through the same
/// application-support native file lock while the source is captured and
/// copied. This is NOT a substitute for the final all-writer activation gate:
/// no preference pointer, new source routing, Firestore sync or key rotation
/// may happen here. A later cutover MUST recheck sourceDigest and all writers.
class WaffraProductionFinanceCopyStager {
  const WaffraProductionFinanceCopyStager({
    required this.coordinator,
    required this.destination,
    required this.trustedReceiptDirectory,
    this.experimentalEnabled = false,
  });

  final WaffraLegacyFinanceWriterCoordinator coordinator;
  final WaffraEncryptedStore destination;
  final Directory trustedReceiptDirectory;
  final bool experimentalEnabled;

  static Map<String, Object?> _capture(SharedPreferences prefs) {
    final snapshot = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      snapshot[key] = value is List<String>
          ? List<String>.unmodifiable(value)
          : value;
    }
    if (prefs.containsKey('waffra_custom_goals_v1')) {
      final custom = prefs.getStringList('waffra_custom_goals_v1');
      if (custom == null) {
        throw StateError('Custom goal catalog type is unsafe.');
      }
      snapshot['waffra_custom_goals_v1'] =
          List<String>.unmodifiable(custom);
    }
    return Map<String, Object?>.unmodifiable(snapshot);
  }

  static List<String> _strictPaths(Object? raw) {
    if (raw == null || raw == '') return const [];
    if (raw is! String || raw.trim().isEmpty) {
      throw StateError('Receipt path is corrupt.');
    }
    if (!raw.startsWith('[')) return [raw];
    final decoded = jsonDecode(raw);
    if (decoded is! List ||
        decoded.any((part) =>
            part is! String || part.trim().isEmpty)) {
      throw StateError('Receipt path list is corrupt.');
    }
    return decoded.cast<String>();
  }

  Future<List<WaffraReceiptBackupPart>> _readReceiptBytes(
    Map<String, Object?> snapshot,
  ) async {
    final raw = snapshot['entries'];
    if (raw == null) return const [];
    if (raw is! String) throw StateError('Ledger serialization is unsafe.');
    final rows = jsonDecode(raw);
    if (rows is! List) throw StateError('Finance ledger is not a list.');
    final attachments = <WaffraReceiptBackupPart>[];
    var total = 0;
    var rootCanonical = '';
    for (final item in rows) {
      if (item is! Map) throw StateError('Malformed saved entry.');
      final entryId = item['id'];
      if (entryId is! String || entryId.trim().isEmpty) {
        throw StateError('Receipt owner is missing.');
      }
      final paths = _strictPaths(item['receiptPath']);
      if (paths.length > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
        throw StateError('Excessive receipt attachments.');
      }
      if (paths.isNotEmpty && rootCanonical.isEmpty) {
        if (await FileSystemEntity.type(trustedReceiptDirectory.path,
              followLinks: false) != FileSystemEntityType.directory) {
          throw StateError('Approved local receipt folder is missing.');
        }
        rootCanonical = await trustedReceiptDirectory.resolveSymbolicLinks();
        if (rootCanonical == Platform.pathSeparator) {
          throw StateError('Filesystem root cannot store app receipts.');
        }
        if (!rootCanonical.endsWith(Platform.pathSeparator)) {
          rootCanonical += Platform.pathSeparator;
        }
      }
      for (var i = 0; i < paths.length; i++) {
        if (attachments.length >= WaffraPortableBackupV2.maxReceipts) {
          throw StateError('Too many receipts for a verified migration.');
        }
        final file = File(paths[i]);
        if (!file.isAbsolute ||
            await FileSystemEntity.type(file.path, followLinks: false) !=
                FileSystemEntityType.file) {
          throw StateError('Receipt file is missing or not a regular file.');
        }
        final canonical = await file.resolveSymbolicLinks();
        if (!canonical.startsWith(rootCanonical)) {
          throw StateError('Receipt lies outside the approved app directory.');
        }
        final before = await file.stat();
        if (before.size <= 0 ||
            before.size > WaffraPortableBackupV2.maxReceiptBytes ||
            total + before.size >
                WaffraPortableBackupV2.maxCombinedReceiptBytes) {
          throw StateError('Receipt byte size is unsafe.');
        }
        final bytes = Uint8List.fromList(await file.readAsBytes());
        final after = await file.stat();
        if (after.size != before.size ||
            after.modified != before.modified ||
            bytes.length != before.size) {
          throw StateError('Receipt changed during encrypted migration.');
        }
        attachments.add(WaffraReceiptBackupPart(
          entryId: entryId, position: i,
          bytes: List<int>.unmodifiable(bytes),
        ));
        total += bytes.length;
      }
    }
    return List<WaffraReceiptBackupPart>.unmodifiable(attachments);
  }

  Future<WaffraProductionCopyStageReport> stage({
    required String userChosenBackupPassword,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Production encrypted copy staging is not enabled.');
    }
    // This caller must opt in explicitly and supply an exclusively owned
    // candidate destination. Neither this code nor the app autogenerates a
    // recovery password or stores it in preferences, Firestore or logs.
    if (userChosenBackupPassword.length < 12) {
      throw ArgumentError('An authenticated backup password is required.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final captured = _capture(prefs);
      final audited = WaffraLegacyPreflight.inspect(captured);
      if (!audited.canStage) {
        throw StateError('Original finance failed integrity validation.');
      }
      final receipts = await _readReceiptBytes(captured);
      final archive = await WaffraPortableBackupV2.create(
        financialSnapshot: captured,
        receipts: receipts,
        password: userChosenBackupPassword,
      );
      // A password-encrypted transient archive is never written to disk;
      // authenticate the content and receipt associations before SQL writes.
      final verified = await WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: archive, password: userChosenBackupPassword,
      );
      if (verified.sourceChecksum != audited.sourceSha256 ||
          verified.receiptCount != receipts.length) {
        throw StateError('Encrypted backup source or receipts disagree.');
      }
      final restored = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: destination,
        experimentalEnabled: true,
      ).restore(
        encryptedArchive: archive,
        password: userChosenBackupPassword,
      );
      if (restored.sourceChecksum != audited.sourceSha256 ||
          restored.receiptCount != receipts.length) {
        throw StateError('Encrypted staged copy does not match the source.');
      }
      final coldWitness = await WaffraAtomicFinanceSnapshot(
        store: destination, experimentalEnabled: true,
      ).read();
      if (coldWitness.generation != restored.encryptedGeneration) {
        throw StateError('Staged encrypted generation changed unexpectedly.');
      }
      // Native lock is still held. Reload current OS preferences, not an
      // in-memory cache. A modified source invalidates the candidate copy.
      await prefs.reload();
      final after = _capture(prefs);
      if (WaffraLegacyPreflight.inspect(after).sourceSha256 !=
              audited.sourceSha256 ||
          jsonEncode(after['waffra_custom_goals_v1']) !=
              jsonEncode(captured['waffra_custom_goals_v1'])) {
        throw StateError('Finance source changed during encrypted staging.');
      }
      return WaffraProductionCopyStageReport(
        sourceDigest: audited.sourceSha256,
        transactions: restored.transactionCount,
        receipts: restored.receiptCount,
        receiptBytes: restored.receiptBytes,
        targetGeneration: restored.encryptedGeneration,
      );
    });
  }

  /// Revalidate the LEGACY source after a staging run, before even considering
  /// future activation. All participating writers are serialized by the
  /// native lock. This method NEVER selects an encrypted source.
  Future<bool> sourceStillMatches(String expectedDigest) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedDigest)) {
      throw ArgumentError('Invalid expected financial digest.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final checksum = WaffraLegacyPreflight.inspect(_capture(prefs));
      return checksum.canStage && checksum.sourceSha256 == expectedDigest;
    });
  }
}
