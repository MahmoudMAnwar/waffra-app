import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'legacy_financial_snapshot.dart' show WaffraLegacySnapshotInspector;
import 'legacy_snapshot_preflight.dart' as strict;
import 'waffra_portable_backup_v2.dart';

/// Read-only mapping of receipts restored into an isolated disposable folder.
/// A real app restore must still move files into a private final directory,
/// rewrite receipt paths atomically with the ledger, and support rollback.
class WaffraReceiptSandboxResult {
  const WaffraReceiptSandboxResult({
    required this.sandboxRelativePaths,
    required this.restoredBytes,
  });

  final Map<String, List<String>> sandboxRelativePaths;
  final int restoredBytes;

  int get restoredFiles => sandboxRelativePaths.values
      .fold<int>(0, (total, files) => total + files.length);
}

/// Secure-path staging *prototype*. It never accesses live receipt files,
/// SharedPreferences, app directories or Firebase. The caller supplies a
/// freshly created, EMPTY disposable directory and an already decrypted
/// WaffraBackupV2Preview from the authenticated M16 verifier.
class WaffraReceiptSandboxStager {
  const WaffraReceiptSandboxStager({this.experimentalEnabled = false});

  final bool experimentalEnabled;

  Future<WaffraReceiptSandboxResult> stage({
    required Directory emptySandboxDirectory,
    required WaffraBackupV2Preview preview,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Receipt restoration is disabled by default.');
    }
    if (await FileSystemEntity.type(emptySandboxDirectory.path,
            followLinks: false) != FileSystemEntityType.directory) {
      throw StateError('Sandbox must be an existing real directory.');
    }
    if ((await emptySandboxDirectory.list(followLinks: false).toList()).isNotEmpty) {
      throw StateError('Sandbox must be empty to prevent overwriting data.');
    }
    final valid = strict.WaffraLegacyPreflight.inspect(
      preview.financialSnapshot);
    if (!valid.canStage || valid.sourceSha256 != preview.sourceChecksum) {
      throw StateError('Unverified financial source provided for receipts.');
    }
    final raw = preview.financialSnapshot['entries'];
    final requirements = <String, int>{};
    if (raw != null) {
      for (final entry in jsonDecode(raw as String) as List) {
        final item = Map<String, dynamic>.from(entry as Map);
        final id = item['id'] as String;
        final count = WaffraLegacySnapshotInspector.receiptPaths(
            item['receiptPath']).length;
        if (count != 0) requirements[id] = count;
      }
    }
    final count = requirements.values.fold<int>(0, (a, b) => a + b);
    if (count != preview.receipts.length ||
        count > WaffraPortableBackupV2.maxReceipts) {
      throw StateError('Receipt associations do not match the source.');
    }
    final seen = <String>{};
    final prepared = <(String, int, String, List<int>)>[];
    var byteCount = 0;
    for (final part in preview.receipts) {
      final allowedCount = requirements[part.entryId];
      final slot = jsonEncode([part.entryId, part.position]);
      if (allowedCount == null || part.position < 0 ||
          part.position >= allowedCount || !seen.add(slot)) {
        throw StateError('Duplicate or unexpected restored receipt.');
      }
      if (part.bytes.isEmpty ||
          part.bytes.length > WaffraPortableBackupV2.maxReceiptBytes) {
        throw StateError('Invalid receipt payload.');
      }
      byteCount += part.bytes.length;
      if (byteCount > WaffraPortableBackupV2.maxCombinedReceiptBytes) {
        throw StateError('Restored receipt size budget exceeded.');
      }
      // Never use user-supplied IDs or legacy absolute paths as filenames.
      final safeName = sha256.convert(utf8.encode(slot)).toString() + '.bin';
      prepared.add((part.entryId, part.position, safeName, part.bytes));
    }
    if (seen.length != count) throw StateError('Missing restored receipt.');

    // Work is all-or-nothing for this disposable folder. All preflight
    // completes before the first write. On an I/O failure, remove the files
    // created by this stage; NEVER modify anything outside the sandbox.
    final created = <File>[];
    final mapped = <String, Map<int, String>>{};
    try {
      for (final item in prepared) {
        final file = File(
          emptySandboxDirectory.path +
          Platform.pathSeparator + item.$3,
        );
        if (await file.exists()) {
          throw StateError('Existing sandbox receipt would be overwritten.');
        }
        created.add(file); // Also cleanup a partially written file.
        await file.writeAsBytes(item.$4, flush: true);
        final stored = await file.readAsBytes();
        if (sha256.convert(stored).toString() !=
            sha256.convert(item.$4).toString()) {
          throw StateError('Receipt bytes changed during sandbox staging.');
        }
        mapped.putIfAbsent(item.$1, () => <int, String>{})[item.$2] = item.$3;
      }
      final relative = <String, List<String>>{};
      for (final row in mapped.entries) {
        final positions = List.generate(
          requirements[row.key]!, (index) => row.value[index]!,
        );
        relative[row.key] = List<String>.unmodifiable(positions);
      }
      return WaffraReceiptSandboxResult(
        sandboxRelativePaths: Map<String, List<String>>.unmodifiable(relative),
        restoredBytes: byteCount,
      );
    } catch (_) {
      for (final file in created.reversed) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          // A failed disposable sandbox must be discarded completely by its
          // caller. Never claim a partial sandbox is safe to reuse.
        }
      }
      rethrow;
    }
  }
}
