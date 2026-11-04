import 'dart:io';
import 'dart:math';

/// Attachment labels are encoded in the private copy's filename, not stored
/// in plaintext preferences or a detached sidecar. Existing receiptPath
/// values remain a string or JSON string-array of paths and are not migrated.
abstract final class WaffraReceiptFilename {
  static const int maxLabelCharacters = 80;

  static String displayName(String path) {
    final basename = path.split(Platform.pathSeparator).last;
    final marker = basename.indexOf('__');
    final original = marker >= 0 ? basename.substring(marker + 2) : basename;
    final extension = original.lastIndexOf('.');
    return extension > 0 ? original.substring(0, extension) : original;
  }

  static String? validateLabel(String input) {
    final label = input.trim();
    if (label.isEmpty || label.runes.length > maxLabelCharacters) {
      return 'invalid_length';
    }
    if (RegExp(r'[\\/\x00-\x1F\x7F]').hasMatch(label) ||
        label == '.' || label == '..') {
      return 'invalid_characters';
    }
    return null;
  }

  static String? normalizedLabel(String input) {
    if (validateLabel(input) != null) return null;
    return input.trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('__', '_');
  }

  /// Stage a private copy before changing transaction.receiptPath. The
  /// caller deletes staged copies on cancellation/rejected financial commits.
  /// The committed record never points to an absent or renamed original.
  static Future<String> stageCopyWithName({
    required String sourcePath,
    required String appReceiptsDirectory,
    required String proposedLabel,
  }) async {
    final label = normalizedLabel(proposedLabel);
    if (label == null) throw const FormatException('invalid_attachment_name');
    final root = Directory(appReceiptsDirectory);
    final canonicalRoot = await root.resolveSymbolicLinks();
    final source = File(sourcePath);
    final canonicalSource = await source.resolveSymbolicLinks();
    final prefix = canonicalRoot.endsWith(Platform.pathSeparator)
        ? canonicalRoot : '$canonicalRoot${Platform.pathSeparator}';
    if (!canonicalSource.startsWith(prefix)) {
      throw const FileSystemException('attachment_outside_private_directory');
    }
    if (!await source.exists()) {
      throw const FileSystemException('attachment_not_found');
    }
    final basename = source.path.split(Platform.pathSeparator).last;
    final lastDot = basename.lastIndexOf('.');
    final extension = lastDot >= 0
        ? basename.substring(lastDot).toLowerCase() : '.jpg';
    if (!{'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(extension)) {
      throw const FormatException('unsupported_image_extension');
    }
    final random = Random.secure();
    final unique = List<int>.generate(12, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final target = '${prefix}${unique}__$label$extension';
    await source.copy(target);
    return target;
  }
}
