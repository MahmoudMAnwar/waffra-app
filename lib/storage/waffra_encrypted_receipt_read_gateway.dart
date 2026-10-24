import 'dart:convert';
import 'dart:typed_data';

import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

/// Resolves only verified SQLCipher BLOB receipt references to memory.
/// Never opens old absolute filesystem paths, writes decrypted images to
/// public temporary files, or silently ignores a missing/tampered attachment.
///
/// A production caller MUST first verify the active SQLCipher source and
/// appropriate account/transaction identity using a shared writer lock.
class WaffraEncryptedReceiptReadGateway {
  const WaffraEncryptedReceiptReadGateway({
    required this.receiptVault,
    this.experimentalEnabled = false,
    this.verifyEncryptedSource,
  });
  final WaffraEncryptedReceiptVault receiptVault;
  final bool experimentalEnabled;
  final Future<void> Function()? verifyEncryptedSource;

  static List<String> _references(Object? raw) {
    if (raw == null || raw == '') return const [];
    if (raw is! String) {
      throw StateError('Invalid encrypted receipt references.');
    }
    if (!raw.startsWith('[')) return [raw];
    final parsed = jsonDecode(raw);
    if (parsed is! List || parsed.any((x) => x is! String)) {
      throw StateError('Receipt references must be a string array.');
    }
    return List<String>.unmodifiable(parsed.cast<String>());
  }

  Future<List<Uint8List>> read({
    required String entryId,
    required String? encodedReferences,
  }) async {
    if (!experimentalEnabled || verifyEncryptedSource == null) {
      throw StateError('Verified encrypted receipt reading is not enabled.');
    }
    if (entryId.trim().isEmpty || entryId.length > 128) {
      throw ArgumentError('Invalid receipt owner.');
    }
    final refs = _references(encodedReferences);
    await verifyEncryptedSource!.call();
    final receipts = await receiptVault.readAll(entryId);
    if (refs.length != receipts.length) {
      throw StateError('Finance metadata and encrypted receipt count differ.');
    }
    final result = <Uint8List>[];
    for (var i = 0; i < receipts.length; i++) {
      if (!WaffraEncryptedReceiptReference.matches(
          refs[i], entryId, i) || receipts[i].position != i) {
        throw StateError('Encrypted receipt reference mismatch.');
      }
      // Return owned buffers, not mutable pointers into any SQL row object.
      result.add(Uint8List.fromList(receipts[i].bytes));
    }
    return List<Uint8List>.unmodifiable(result);
  }
}
