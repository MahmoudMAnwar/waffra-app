import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'waffra_offline_receipt_path_planner.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_receipt_restore_sandbox.dart';
import 'waffra_receipt_sandbox_auditor.dart';

/// Reports only disposable files that were copied and read back successfully.
/// It is NOT a production cutover confirmation.
class WaffraDisposableReceiptCopyReport {
  const WaffraDisposableReceiptCopyReport({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;
}

/// Copies authenticated, staged receipt bytes to a SECOND empty disposable
/// folder, matching the already verified M24 remapping plan exactly.
///
/// Does not touch app preferences, running ledger, original device receipts,
/// account identity, or Firebase. Both folders MUST be private disposable
/// single-writer directories. No live-path validation/activation is implied.
class WaffraDisposableReceiptCopier {
  const WaffraDisposableReceiptCopier({this.experimentalEnabled = false});

  final bool experimentalEnabled;

  Future<WaffraDisposableReceiptCopyReport> copy({
    required Directory stagingDirectory,
    required Directory emptyDestination,
    required WaffraBackupV2Preview preview,
    required WaffraReceiptSandboxResult staged,
    required WaffraReceiptRemapPlan plan,
    // Test-only fault injection; simulates interruption before completion.
    int? failAfterCopiesForTest,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Receipt file copy is disabled by default.');
    }
    if (failAfterCopiesForTest != null && failAfterCopiesForTest < 0) {
      throw ArgumentError('Invalid fault injection count.');
    }
    if (stagingDirectory.absolute.path ==
        emptyDestination.absolute.path) {
      throw StateError('Source and destination folders must differ.');
    }
    if (await FileSystemEntity.type(stagingDirectory.path,
            followLinks: false) != FileSystemEntityType.directory ||
        await FileSystemEntity.type(emptyDestination.path,
            followLinks: false) != FileSystemEntityType.directory ||
        (await emptyDestination.list(followLinks: false).toList()).isNotEmpty) {
      throw StateError('Both folders must be real; destination must be empty.');
    }

    // Recompute the exact plan instead of trusting an arbitrary caller map.
    final expectedPlan = await const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true,
    ).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stagingDirectory,
      emptyAppPrivateDestination: emptyDestination,
    );
    if (plan.sourceChecksum != expectedPlan.sourceChecksum ||
        plan.entryCount != expectedPlan.entryCount ||
        plan.receiptCount != expectedPlan.receiptCount ||
        jsonEncode(plan.remappedSnapshot) !=
            jsonEncode(expectedPlan.remappedSnapshot)) {
      throw StateError('Requested paths differ from verified finance plan.');
    }
    await const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true,
    ).verify(
      sandboxDirectory: stagingDirectory, preview: preview, staged: staged);

    // Index by archive association; never trust old paths or entry IDs as
    // filenames. Verify all source bytes BEFORE first destination write.
    final prepared = <(String, List<int>)>[];
    final observed = <String>{};
    var expectedBytes = 0;
    for (final item in staged.sandboxRelativePaths.entries) {
      for (var index = 0; index < item.value.length; index++) {
        final name = item.value[index];
        if (!RegExp(r'^[a-f0-9]{64}\.bin$').hasMatch(name) ||
            !observed.add(name)) {
          throw StateError('Unsafe or repeated staging filename.');
        }
        final matches = preview.receipts.where(
          (r) => r.entryId == item.key && r.position == index,
        ).toList();
        if (matches.length != 1) {
          throw StateError('Unexpected archive receipt association.');
        }
        final bytes = await File(
          '${stagingDirectory.path}${Platform.pathSeparator}$name',
        ).readAsBytes();
        if (sha256.convert(bytes) != sha256.convert(matches.single.bytes)) {
          throw StateError('Source receipt changed before copy.');
        }
        expectedBytes += bytes.length;
        prepared.add((name, bytes));
      }
    }
    if (prepared.length != preview.receiptCount ||
        expectedBytes != staged.restoredBytes) {
      throw StateError('Source receipt totals mismatch.');
    }

    final created = <File>[];
    var actualBytes = 0;
    try {
      for (final item in prepared) {
        if (failAfterCopiesForTest != null &&
            created.length == failAfterCopiesForTest) {
          throw StateError('Injected disposable copy interruption.');
        }
        final dest = File(
          '${emptyDestination.path}${Platform.pathSeparator}${item.$1}',
        );
        // No overwrite even if target appeared after initial preflight.
        await dest.create(exclusive: true);
        created.add(dest);
        await dest.writeAsBytes(item.$2, flush: true);
        final reloaded = await dest.readAsBytes();
        if (sha256.convert(reloaded) != sha256.convert(item.$2)) {
          throw StateError('Copied receipt failed read-back integrity.');
        }
        actualBytes += reloaded.length;
      }
      final all = await emptyDestination.list(followLinks: false).toList();
      if (all.length != prepared.length ||
          all.any((entry) =>
            !observed.contains(entry.uri.pathSegments.last) ||
            entry is! File)) {
        throw StateError('Extra or unexpected files in destination.');
      }
      if (actualBytes != expectedBytes) {
        throw StateError('Copied receipt byte totals differ.');
      }
      return WaffraDisposableReceiptCopyReport(
        fileCount: created.length,
        totalBytes: actualBytes,
      );
    } catch (_) {
      // Best effort cleanup only of files we created. Discard the WHOLE
      // disposable destination on ANY error; never reuse it as proof of
      // successful restoration or run this against live receipt folders.
      for (final file in created.reversed) {
        try {
          if (await FileSystemEntity.type(file.path, followLinks: false) ==
              FileSystemEntityType.file) {
            await file.delete();
          }
        } catch (_) {
          // Caller must discard the entire failed disposable directory.
        }
      }
      rethrow;
    }
  }
}
