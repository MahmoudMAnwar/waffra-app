import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'waffra_portable_backup_v2.dart';
import 'waffra_receipt_restore_sandbox.dart';

/// Fail-closed post-stage verification. Never edits any file.
class WaffraReceiptSandboxAuditor {
  const WaffraReceiptSandboxAuditor({this.experimentalEnabled = false});

  final bool experimentalEnabled;

  /// Return verified file and byte counts only after *all* checks succeed.
  Future<WaffraReceiptSandboxResult> verify({
    required Directory sandboxDirectory,
    required WaffraBackupV2Preview preview,
    required WaffraReceiptSandboxResult staged,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Receipt audit is disabled by default.');
    }
    if (await FileSystemEntity.type(sandboxDirectory.path,
            followLinks: false) != FileSystemEntityType.directory) {
      throw StateError('Audit directory must be a real directory.');
    }

    final expected = <String, List<int>>{};
    final expectedPositions = <String, Set<int>>{};
    for (final part in preview.receipts) {
      final key = jsonEncode([part.entryId, part.position]);
      if (part.position < 0 || expected.containsKey(key)) {
        throw StateError('Duplicate or invalid source receipt.');
      }
      expected[key] = part.bytes;
      expectedPositions.putIfAbsent(part.entryId, () => <int>{})
          .add(part.position);
    }
    final mappedNames = <String>{};
    if (staged.sandboxRelativePaths.length != expectedPositions.length) {
      throw StateError('Receipt entry mapping count differs.');
    }

    var totalBytes = 0;
    for (final entry in staged.sandboxRelativePaths.entries) {
      final positions = expectedPositions[entry.key];
      if (positions == null || entry.value.length != positions.length) {
        throw StateError('Receipt mapping differs from archive.');
      }
      for (var index = 0; index < entry.value.length; index++) {
        if (!positions.contains(index)) {
          throw StateError('Missing or unordered receipt position.');
        }
        final name = entry.value[index];
        final expectedName =
            '${sha256.convert(utf8.encode(jsonEncode([entry.key, index])))}.bin';
        if (name != expectedName || !mappedNames.add(name)) {
          throw StateError('Untrusted or duplicate receipt filename.');
        }
        final file = File('${sandboxDirectory.path}${Platform.pathSeparator}$name');
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('Receipt is missing or is not a regular file.');
        }
        final bytes = await file.readAsBytes();
        final original = expected[jsonEncode([entry.key, index])];
        if (original == null ||
            bytes.length != original.length ||
            sha256.convert(bytes) != sha256.convert(original)) {
          throw StateError('Staged receipt failed byte-integrity audit.');
        }
        totalBytes += bytes.length;
      }
    }

    final children = await sandboxDirectory.list(followLinks: false).toList();
    if (children.length != mappedNames.length ||
        children.any((entity) =>
            !mappedNames.contains(entity.uri.pathSegments.last))) {
      throw StateError('Unexpected sandbox files or directories.');
    }
    if (totalBytes != staged.restoredBytes ||
        mappedNames.length != staged.restoredFiles) {
      throw StateError('Staged receipt totals differ.');
    }
    return staged;
  }
}
