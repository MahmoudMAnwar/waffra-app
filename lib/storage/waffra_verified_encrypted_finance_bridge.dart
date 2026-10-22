import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'waffra_encrypted_cutover_journal.dart';
import 'waffra_encrypted_finance_ui_patch.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_encrypted_receipt_recycle.dart';
import 'waffra_receipt_screen_contract.dart';
import 'waffra_encrypted_receipt_read_gateway.dart';
import 'waffra_live_legacy_finance_guard.dart';
import 'waffra_unified_finance_writer.dart';

/// A single immutable read of the encrypted finance source. The revision can
/// also be observed by a separate Android widget engine and HomeScreen.
class WaffraEncryptedHomeWitness {
  const WaffraEncryptedHomeWitness({
    required this.snapshot,
    required this.finance,
  });

  final WaffraFinanceSnapshotState snapshot;
  final WaffraFinanceReadView finance;
  int get generation => snapshot.generation;
  String get digest => snapshot.digest;
  String? get ledgerRaw => finance.getString('entries');
  String get widgetRevision => snapshot.generation.toString();
}

/// Candidate runtime bridge for a future verified SQLCipher activation.
///
/// Runs the same source witness and file-lock check for HomeScreen and widget
/// finance mutations. Does NOT create an encrypted key or vault, set source
/// markers, migrate legacy data, or modify production app routing.
///
/// It must only be constructed for a previously activated vault with external
/// source and independently verified SQL witnesses. Flags here are supplied
/// by the future production activation coordinator, NOT a user preference.
class WaffraVerifiedEncryptedFinanceBridge {
  const WaffraVerifiedEncryptedFinanceBridge({
    required this.snapshot,
    required this.cutoverJournal,
    required this.writerDirectory,
    this.allWritersRoutedVerified = false,
    this.secureKeyVerified = false,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final WaffraEncryptedCutoverJournal cutoverJournal;
  final Directory writerDirectory;
  final bool allWritersRoutedVerified;
  final bool secureKeyVerified;
  final bool experimentalEnabled;

  Future<void> _requireActivatedUnderLock() async {
    if (!experimentalEnabled ||
        !allWritersRoutedVerified ||
        !secureKeyVerified) {
      throw StateError('Verified encrypted runtime is not enabled.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(WaffraLiveLegacyFinanceGuard.activeKey) != true ||
        prefs.containsKey(WaffraLiveLegacyFinanceGuard.pendingKey)) {
      throw StateError('Encrypted source witness is missing or pending.');
    }
    final recovery = await cutoverJournal.recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: secureKeyVerified,
      allWritersRouted: allWritersRoutedVerified,
    );
    if (recovery != WaffraCutoverRecoveryStatus.encryptedReady) {
      throw StateError('SQLCipher activation witness needs reconciliation.');
    }
  }

  Future<WaffraEncryptedHomeWitness> loadForHomeAndWidget() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      return WaffraEncryptedHomeWitness(
        snapshot: current,
        finance: WaffraFinanceReadView.fromEncrypted(current),
      );
    });
  }

  /// Applies only user-edited finance keys. If a widget saved an unrelated
  /// field meanwhile, that value survives; a same-key edit fails closed.
  Future<WaffraFinanceSnapshotState> saveHomeChanges({
    required WaffraEncryptedHomeWitness baseline,
    required Map<String, Object?> replacements,
    required Set<String> changedKeys,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraEncryptedFinanceUiPatch(
      snapshot: snapshot,
      writerDirectory: writerDirectory,
      experimentalEnabled: true,
      verifySourceUnderLock: _requireActivatedUnderLock,
    ).saveScreenChanges(
      screenBaseline: baseline.snapshot.values,
      replacementValues: replacements,
      changedKeys: changedKeys,
    );
  }

  /// Receives explicitly confirmed SMS/manual transaction JSON from either
  /// engine. Dedupe and ledger update commit together under ONE source lock.
  Future<WaffraUnifiedWriteResult> appendConfirmedTransactions({
    required List<Map<String, Object?>> records,
    required List<String?> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraUnifiedFinanceWriter(
      writerDirectory: writerDirectory,
      snapshot: snapshot,
      experimentalEnabled: true,
      verifySourceUnderLock: _requireActivatedUnderLock,
    ).appendTransactions(
      records: records,
      messageHashes: messageHashes,
      userConfirmed: userConfirmed,
      allowDuplicateHashes: allowDuplicateHashes,
    );
  }
  /// Save a confirmed transaction and its attached images as ONE encrypted
  /// SQLCipher commit. Uses the same source witness as dashboard and widget.
  /// No plaintext disk receipt path or separate partial finance update.
  Future<WaffraEncryptedReceiptTransactionResult>
      appendConfirmedWithReceiptBytes({
    required Map<String, Object?> record,
    required List<Uint8List> images,
    required bool userConfirmed,
    String? messageHash,
  }) {
    return WaffraAtomicEncryptedReceiptTransactionWriter(
      snapshot: snapshot,
      receiptVault: WaffraEncryptedReceiptVault(
        store: snapshot.store,
        experimentalEnabled: true,
      ),
      writerDirectory: writerDirectory,
      verifySourceUnderLock: _requireActivatedUnderLock,
      experimentalEnabled: experimentalEnabled,
    ).save(
      record: record,
      receiptImages: images,
      userConfirmed: userConfirmed,
      smsHash: messageHash,
    );
  }

  /// Replace one existing image after verifying source and the expected
  /// previous image digest under the common Home/Widget native lock.
  /// Never delete, renumber, or modify transaction history in this path.
  Future<void> replaceVerifiedReceiptImage({
    required String entryId,
    required int position,
    required Uint8List image,
    required String expectedSha256,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt replacement is disabled.');
    }
    final captured = Uint8List.fromList(image);
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      final raw = current.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted finance ledger is unavailable.');
      }
      final rows = jsonDecode(raw);
      if (rows is! List) {
        throw StateError('Encrypted finance ledger is malformed.');
      }
      final matching = rows.where((row) =>
          row is Map && row['id'] == entryId).toList();
      if (matching.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final refs = (matching.single as Map)['receiptPath'];
      if (refs is! String || refs.isEmpty) {
        throw StateError('Encrypted receipt references are missing.');
      }
      final vault = WaffraEncryptedReceiptVault(
        store: snapshot.store, experimentalEnabled: true,
      );
      final prior = await vault.readAll(entryId);
      if (position < 0 || position >= prior.length) {
        throw StateError('Encrypted receipt position is invalid.');
      }
      // The existing verified read gateway checks that references and blobs
      // belong to this same transaction before any destructive mutation.
      await WaffraEncryptedReceiptReadGateway(
        receiptVault: vault,
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(entryId: entryId, encodedReferences: refs);
      await vault.replaceExistingImage(
        entryId: entryId,
        position: position,
        image: captured,
        expectedSha256: expectedSha256,
      );
    });
  }

  WaffraEncryptedReceiptRecycle get _receiptRecycle =>
      WaffraEncryptedReceiptRecycle(
        snapshot: snapshot,
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store,
          experimentalEnabled: true,
        ),
        writerDirectory: writerDirectory,
        verifySourceUnderLock: _requireActivatedUnderLock,
        experimentalEnabled: experimentalEnabled,
      );

  /// Screen reads always use encrypted in-memory BLOBs, a single finance
  /// generation and the 30-day recycle witness. No plain file fallback.
  /// A concurrent writer forces the UI to reload instead of showing a
  /// mismatched receipt count or archive status.
  Future<WaffraReceiptScreenState> loadVerifiedReceiptScreen(
    String entryId,
  ) async {
    if (!experimentalEnabled || entryId.trim().isEmpty ||
        entryId.length > 128) {
      throw StateError('Verified encrypted receipt screen is unavailable.');
    }

    // M121: the legacy four-lock sequence could combine an old image set
    // with a newer recycle status or in-place M116 replacement. A receipt
    // replacement does not increment the finance generation. Capture the
    // ledger, normalized SQL owner, BLOB bytes and recycle status beneath
    // ONE Home/Widget native lock, with no public file or legacy fallback.
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final finance = await snapshot.read();
      final raw = finance.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted financial ledger is missing.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw StateError('Encrypted transaction list is malformed.');
      }
      final matching = decoded.where(
        (item) => (item as Map)['id'] == entryId,
      ).toList();
      if (matching.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final owner = Map<String, dynamic>.from(matching.single as Map);
      final refs = owner['receiptPath'];
      if (refs != null && refs is! String) {
        throw StateError('Encrypted receipt reference has an invalid type.');
      }

      // Refuse a split-brain ledger even if the JSON snapshot itself is valid.
      final sqlOwner = await snapshot.store.customSelect(
        'SELECT source_json,receipt_count FROM fresh_finance_entries '
        'WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).get();
      if (sqlOwner.length != 1 ||
          jsonEncode(jsonDecode(sqlOwner.single.read<String>('source_json'))) !=
              jsonEncode(owner)) {
        throw StateError('Encrypted receipt SQL owner differs from ledger.');
      }

      final imageBytes = await WaffraEncryptedReceiptReadGateway(
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store,
          experimentalEnabled: true,
        ),
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(entryId: entryId, encodedReferences: refs as String?);
      if (sqlOwner.single.read<int>('receipt_count') != imageBytes.length) {
        throw StateError('Encrypted receipt SQL count differs from images.');
      }

      int? recoverUntilMs;
      final table = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_receipt_recycle'",
      ).get();
      if (table.isNotEmpty) {
        final archived = await snapshot.store.customSelect(
          'SELECT receipt_count,deleted_at_ms,expires_at_ms '
          'FROM fresh_finance_receipt_recycle WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (archived.length > 1) {
          throw StateError('Duplicated encrypted receipt archive.');
        }
        final orphanCheck = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM fresh_finance_receipt_recycle_blobs '
          'WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).getSingle();
        final archivedCount = orphanCheck.read<int>('n');
        if (archived.isEmpty) {
          if (archivedCount != 0) {
            throw StateError('Orphaned encrypted receipt archive BLOBs.');
          }
        } else {
          final row = archived.single;
          final deletedAt = row.read<int>('deleted_at_ms');
          final expiry = row.read<int>('expires_at_ms');
          if (refs != null || imageBytes.isNotEmpty ||
              row.read<int>('receipt_count') != archivedCount ||
              archivedCount < 1 ||
              archivedCount > WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
              deletedAt < 0 ||
              expiry - deletedAt !=
                  WaffraEncryptedReceiptRecycle.retention.inMilliseconds) {
            throw StateError('Encrypted receipt archive witness mismatch.');
          }
          recoverUntilMs = expiry;
        }
      }

      // Check the durable source again before publishing UI data. This is
      // still under the same writer lock, so a cooperating widget cannot
      // interleave a finance write or an image replacement.
      await _requireActivatedUnderLock();
      final unchanged = await snapshot.read();
      if (unchanged.generation != finance.generation ||
          unchanged.digest != finance.digest) {
        throw StateError('Encrypted finance source changed during receipt read.');
      }
      return WaffraReceiptScreenState(
        entryId: entryId,
        generation: finance.generation,
        images: imageBytes,
        recoverUntilMs: recoverUntilMs,
      );
    });
  }

  Future<WaffraReceiptRecycleResult> moveReceiptBatchToRecycle({
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  }) {
    if (!experimentalEnabled || !baseline.hasActiveImages ||
        baseline.isInRecycleBin) {
      throw StateError('No verified active receipt batch may be removed.');
    }
    return _receiptRecycle.moveToRecycle(
      entryId: baseline.entryId,
      expectedGeneration: baseline.generation,
      expectedImageHashes: List<String>.unmodifiable(baseline.imageSha256),
      now: now,
      userConfirmed: userConfirmed,
    );
  }

  Future<WaffraReceiptRecycleResult> restoreReceiptBatchFromRecycle({
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  }) {
    if (!experimentalEnabled || !baseline.isInRecycleBin ||
        baseline.hasActiveImages) {
      throw StateError('No archived receipt batch is eligible for restore.');
    }
    return _receiptRecycle.restore(
      entryId: baseline.entryId,
      expectedGeneration: baseline.generation,
      now: now,
    );
  }

  /// Merge confirmed SHA-256 SMS fingerprints under one native app/widget lock.
  /// No raw bank SMS is stored or sent anywhere.
  Future<WaffraFinanceSnapshotState> mergeConfirmedSmsHashes(
    List<String> additions,
  ) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted SMS deduplication runtime is disabled.');
    }
    const digits = '0123456789abcdef';
    if (additions.length > 1000 ||
        additions.any((hash) => hash.length != 64 ||
            hash.split('').any((character) => !digits.contains(character)))) {
      throw ArgumentError('Only SHA-256 SMS fingerprints are allowed.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      final existing = Set<String>.from(
        current.values['waffra_sms_hashes_v1'] as List<String>? ??
            const <String>[],
      );
      final oldCount = existing.length;
      existing.addAll(additions);
      if (oldCount == existing.length) return current;
      final next = Map<String, Object?>.from(current.values);
      next['waffra_sms_hashes_v1'] = existing.toList()..sort();
      return snapshot.commit(
        expectedGeneration: current.generation,
        fullFinanceSnapshot: next,
      );
    });
  }

  /// Read only existing and owner-verified encrypted attachment BLOBs.
  Future<List<Uint8List>> loadReceiptImages({required String entryId}) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt runtime is disabled by default.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      final raw = current.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted finance ledger is unavailable.');
      }
      final rows = jsonDecode(raw);
      if (rows is! List) {
        throw StateError('Encrypted finance ledger is malformed.');
      }
      final exact = rows.where((row) =>
          row is Map && row['id'] == entryId).toList();
      if (exact.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final references = (exact.single as Map)['receiptPath'];
      if (references != null && references is! String) {
        throw StateError('Encrypted receipt references are malformed.');
      }
      return WaffraEncryptedReceiptReadGateway(
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store, experimentalEnabled: true,
        ),
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(
        entryId: entryId,
        encodedReferences: references as String?,
      );
    });
  }

}
