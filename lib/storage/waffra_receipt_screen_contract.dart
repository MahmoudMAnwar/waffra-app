import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// One immutable, screen-facing view of the single verified SQLCipher source.
/// Images are copied to memory; no file paths or decrypted temporary files.
class WaffraReceiptScreenState {
  WaffraReceiptScreenState({
    required this.entryId,
    required this.generation,
    required List<Uint8List> images,
    this.recoverUntilMs,
  }) : images = List<Uint8List>.unmodifiable(
         images.map((bytes) => Uint8List.fromList(bytes)),
       ),
       imageSha256 = List<String>.unmodifiable(
         images.map((bytes) => sha256.convert(bytes).toString()),
       ) {
    if (entryId.trim().isEmpty || entryId.length > 128 ||
        generation < 0 || (images.isNotEmpty && recoverUntilMs != null)) {
      throw StateError('Inconsistent encrypted receipt screen witness.');
    }
  }

  final String entryId;
  final int generation;
  final List<Uint8List> images;
  final List<String> imageSha256;
  final int? recoverUntilMs;

  bool get hasActiveImages => images.isNotEmpty;
  bool get isInRecycleBin => recoverUntilMs != null;
}

/// Explicit production UI port. The implementation MUST select a verified
/// encrypted source; a legacy source never silently falls through here.
abstract class WaffraReceiptScreenPort {
  Future<WaffraReceiptScreenState> load(String entryId);
  Future<WaffraReceiptScreenState> moveToRecycle({
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  });
  Future<WaffraReceiptScreenState> restore({
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  });
}
