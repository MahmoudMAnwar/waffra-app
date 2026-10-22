import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_cutover_journal.dart';
import 'waffra_encrypted_finance_ui_patch.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_encrypted_receipt_vault.dart';
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
  /// Loads an attachment ONLY for an entry proven to exist in the current
  /// encrypted finance snapshot. No arbitrary user-supplied path or receipt
  /// identifier is accepted; the same native app/widget lock and activation
  /// witness protect the financial record and the encrypted BLOB read.
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
