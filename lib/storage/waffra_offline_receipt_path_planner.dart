import 'dart:convert';
import 'dart:io';

import 'legacy_financial_snapshot.dart' show WaffraLegacySnapshotInspector;
import 'legacy_snapshot_preflight.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_receipt_restore_sandbox.dart';
import 'waffra_receipt_sandbox_auditor.dart';

/// NO files are moved, copied or renamed by this planning step.
/// The returned snapshot is a COPY with future private receipt paths.
/// Only the destination installer may create and commit those paths.
class WaffraReceiptRemapPlan {
  const WaffraReceiptRemapPlan({
    required this.remappedSnapshot,
    required this.entryCount,
    required this.receiptCount,
    required this.sourceChecksum,
  });

  final Map<String, Object?> remappedSnapshot;
  final int entryCount;
  final int receiptCount;
  final String sourceChecksum;

  Map<String, Object> get redactedDiagnostics => {
    'entry_count': entryCount,
    'receipt_count': receiptCount,
    'finance_preserved': true,
    'files_written': false,
  };
}

/// Build a fail-closed attachment path rewrite plan from authenticated backup
/// bytes after M19 staging + M20 independent file verification.
/// This API never edits active receiptPath, SharedPreferences, SQLite or cloud.
class WaffraOfflineReceiptPathPlanner {
  const WaffraOfflineReceiptPathPlanner({
    this.experimentalEnabled = false,
  });

  final bool experimentalEnabled;

  Future<WaffraReceiptRemapPlan> plan({
    required WaffraBackupV2Preview verifiedPreview,
    required WaffraReceiptSandboxResult stagedReceipts,
    required Directory receiptSandboxDirectory,
    required Directory emptyAppPrivateDestination,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Receipt remapping is disabled by default.');
    }
    if (receiptSandboxDirectory.absolute.path ==
        emptyAppPrivateDestination.absolute.path) {
      throw StateError('Source and target receipt directories must differ.');
    }
    if (await FileSystemEntity.type(emptyAppPrivateDestination.path,
            followLinks: false) != FileSystemEntityType.directory ||
        (await emptyAppPrivateDestination
            .list(followLinks: false).toList()).isNotEmpty) {
      throw StateError('Receipt destination must be a real empty directory.');
    }

    final source = verifiedPreview.financialSnapshot;
    final strict = WaffraLegacyPreflight.inspect(source);
    final original = const WaffraLegacySnapshotInspector().inspect(source);
    if (!strict.canStage || !original.canStage ||
        strict.sourceSha256 != verifiedPreview.sourceChecksum) {
      throw StateError('Source financial snapshot did not pass preflight.');
    }
    await const WaffraReceiptSandboxAuditor(experimentalEnabled: true)
        .verify(
      sandboxDirectory: receiptSandboxDirectory,
      preview: verifiedPreview,
      staged: stagedReceipts,
    );

    final remapped = Map<String, Object?>.from(source);
    final entries = <Map<String, dynamic>>[];
    final raw = source['entries'];
    final originalEntries =
        raw == null ? <dynamic>[] : jsonDecode(raw as String) as List;
    var mappedCount = 0;
    for (final value in originalEntries) {
      final entry = Map<String, dynamic>.from(value as Map);
      final id = entry['id'] as String;
      final oldPaths =
          WaffraLegacySnapshotInspector.receiptPaths(entry['receiptPath']);
      final mapped = stagedReceipts.sandboxRelativePaths[id];
      if (oldPaths.isNotEmpty) {
        if (mapped == null || mapped.length != oldPaths.length) {
          throw StateError('Receipt association cannot be remapped safely.');
        }
        final paths = <String>[];
        for (final filename in mapped) {
          if (!RegExp(r'^[a-f0-9]{64}\.bin$').hasMatch(filename)) {
            throw StateError('Unsafe receipt filename in staged archive.');
          }
          paths.add('${emptyAppPrivateDestination.path}'
              '${Platform.pathSeparator}$filename');
          mappedCount++;
        }
        entry['receiptPath'] =
            paths.length == 1 ? paths.single : jsonEncode(paths);
      } else if (mapped != null && mapped.isNotEmpty) {
        throw StateError('Unexpected receipt mapping for empty entry.');
      }
      entries.add(entry);
    }
    if (mappedCount != stagedReceipts.restoredFiles ||
        mappedCount != verifiedPreview.receiptCount) {
      throw StateError('Planned receipt totals do not match source.');
    }
    if (raw != null) remapped['entries'] = jsonEncode(entries);

    final after = const WaffraLegacySnapshotInspector().inspect(remapped);
    if (!after.canStage ||
        after.receiptReferences != original.receiptReferences ||
        after.incomeMinor != original.incomeMinor ||
        after.expenseMinor != original.expenseMinor ||
        after.counts['entries'] != original.counts['entries']) {
      throw StateError('Receipt planning changed financial information.');
    }
    return WaffraReceiptRemapPlan(
      remappedSnapshot: Map<String, Object?>.unmodifiable(remapped),
      entryCount: entries.length,
      receiptCount: mappedCount,
      sourceChecksum: verifiedPreview.sourceChecksum,
    );
  }
}
