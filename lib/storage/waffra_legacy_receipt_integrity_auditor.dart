import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';

class WaffraLegacyReceiptEvidence {
  const WaffraLegacyReceiptEvidence({
    required this.transactionId,
    required this.sourcePath,
    required this.byteLength,
    required this.sha256Hex,
  });

  final String transactionId;
  final String sourcePath;
  final int byteLength;
  final String sha256Hex;
}

class WaffraReceiptIntegrityReport {
  const WaffraReceiptIntegrityReport({
    required this.financeSourceDigest,
    required this.referenceCount,
    required this.totalBytes,
    required this.receipts,
  });

  final String financeSourceDigest;
  final int referenceCount;
  final int totalBytes;
  final List<WaffraLegacyReceiptEvidence> receipts;
}

/// Isolated, READ-ONLY receipt inspection for old Waffra transactions.
/// All recognized finance writers are paused by the same OS lock as the live
/// HomeScreen and Android widget. This never deletes, moves or copies files,
/// never changes the active finance source, and never contacts Firebase.
///
/// A successful inspection is NOT sufficient proof of a crash-safe migration:
/// each file must also be copied into the encrypted vault and re-hashed there
/// before source selection can change.
class WaffraLegacyReceiptIntegrityAuditor {
  const WaffraLegacyReceiptIntegrityAuditor({
    required this.coordinator,
    required this.trustedRoots,
    this.experimentalEnabled = false,
  });

  final WaffraLegacyFinanceWriterCoordinator coordinator;
  final List<Directory> trustedRoots;
  final bool experimentalEnabled;

  static const maxReceiptBytes = 8 * 1024 * 1024;

  static List<String> _paths(Object? value) {
    if (value == null || value == '') return const [];
    if (value is! String) {
      throw StateError('Unexpected receipt path type.');
    }
    if (value.startsWith('[')) {
      final parsed = jsonDecode(value);
      if (parsed is! List || parsed.any((element) =>
          element is! String || element.trim().isEmpty)) {
        throw StateError('Invalid legacy receipt path list.');
      }
      return parsed.cast<String>();
    }
    return [value];
  }

  Future<WaffraReceiptIntegrityReport> audit() async {
    if (!experimentalEnabled) {
      throw StateError('Receipt byte inspection is disabled by default.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final entries = prefs.getString('entries');
      final source = <String, Object?>{};
      for (final key in WaffraLegacyPreflight.allKeys) {
        if (prefs.containsKey(key)) source[key] = prefs.get(key);
      }
      final preflight = WaffraLegacyPreflight.inspect(source);
      if (!preflight.canStage) {
        throw StateError('Legacy finance preflight must pass before receipt inspection.');
      }

      final canonicalRoots = <String>[];
      for (final directory in trustedRoots) {
        if (!await directory.exists()) {
          throw StateError('Expected app-private receipt folder is missing.');
        }
        final root = await directory.resolveSymbolicLinks();
        // Do not allow accidentally configured filesystem-wide trust.
        if (root == Platform.pathSeparator) {
          throw StateError('Cannot trust the entire filesystem for receipts.');
        }
        canonicalRoots.add(root.endsWith(Platform.pathSeparator)
            ? root
            : '$root${Platform.pathSeparator}');
      }

      final found = <WaffraLegacyReceiptEvidence>[];
      var totalBytes = 0;
      if (entries != null) {
        final transactions = jsonDecode(entries) as List<dynamic>;
        for (final raw in transactions) {
          final row = raw as Map;
          final id = row['id'] as String;
          for (final name in _paths(row['receiptPath'])) {
            final file = File(name);
            if (!file.isAbsolute ||
                await FileSystemEntity.type(name, followLinks: false) !=
                    FileSystemEntityType.file) {
              throw StateError('Receipt is missing, unsafe, or a symbolic link.');
            }
            final canonical = await file.resolveSymbolicLinks();
            if (!canonicalRoots.any((root) => canonical.startsWith(root))) {
              throw StateError('Receipt is outside trusted app-private storage.');
            }
            final before = await file.stat();
            if (before.size <= 0 || before.size > maxReceiptBytes) {
              throw StateError('Receipt bytes are empty or exceed migration limit.');
            }
            final digest = await sha256.bind(file.openRead()).first;
            final after = await file.stat();
            if (after.size != before.size ||
                after.modified != before.modified ||
                after.type != FileSystemEntityType.file) {
              throw StateError('Receipt changed during byte inspection.');
            }
            totalBytes += after.size;
            found.add(WaffraLegacyReceiptEvidence(
              transactionId: id,
              sourcePath: canonical,
              byteLength: after.size,
              sha256Hex: digest.toString(),
            ));
          }
        }
      }
      // Source finance must remain untouched during this lock-held audit.
      await prefs.reload();
      final verified = <String, Object?>{};
      for (final key in WaffraLegacyPreflight.allKeys) {
        if (prefs.containsKey(key)) verified[key] = prefs.get(key);
      }
      if (WaffraLegacyPreflight.inspect(verified).sourceSha256 !=
          preflight.sourceSha256) {
        throw StateError('Finance changed during receipt byte inspection.');
      }
      return WaffraReceiptIntegrityReport(
        financeSourceDigest: preflight.sourceSha256,
        referenceCount: found.length,
        totalBytes: totalBytes,
        receipts: List.unmodifiable(found),
      );
    });
  }
}
