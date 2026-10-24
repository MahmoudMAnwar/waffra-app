import 'dart:convert';

/// Pure validation of one transaction selected by an encrypted Home screen.
/// A stale UI tile must never delete a different SQLCipher transaction when
/// a Widget or another screen has edited it since it was rendered.
class WaffraVerifiedTransactionUiGuard {
  const WaffraVerifiedTransactionUiGuard._();

  static List<Map<String, dynamic>> decodeLedger(String? raw) {
    if (raw == null) {
      throw StateError('Verified financial ledger is unavailable.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw StateError('Verified financial ledger is not a transaction list.');
    }
    final ids = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Verified financial row is not an object.');
      }
      final id = item['id'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw StateError('Verified financial transaction identity is ambiguous.');
      }
      result.add(Map<String, dynamic>.unmodifiable(item));
    }
    return List<Map<String, dynamic>>.unmodifiable(result);
  }

  static void requireUnchangedSelected({
    required String? ledgerRaw,
    required Map<String, dynamic> selected,
  }) {
    final id = selected['id'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('Selected transaction identity is missing.');
    }
    final rows = decodeLedger(ledgerRaw);
    final matches = rows.where((entry) => entry['id'] == id).toList();
    if (matches.length != 1 ||
        jsonEncode(matches.single) != jsonEncode(selected)) {
      throw StateError('Selected transaction changed; reload before deleting.');
    }
  }
}
