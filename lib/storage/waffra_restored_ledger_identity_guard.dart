/// Read-only source/SQLCipher/Home identity attestation after an encrypted
/// restore. No archive bytes, transactions or personal IDs are logged.
class WaffraRestoredLedgerIdentityReport {
  const WaffraRestoredLedgerIdentityReport({
    required this.sourceCount,
    required this.verifiedCount,
  });

  final int sourceCount;
  final int verifiedCount;
}

/// Never infer duplication from date, amount, title or sender. Distinct IDs
/// may represent legitimate identical-looking purchases or recurring entries.
/// A failed parity check NEVER removes or rewrites financial rows.
abstract final class WaffraRestoredLedgerIdentityGuard {
  static Map<String, (int amountMinor, bool income, String date)> _records(
    List<dynamic> raw,
  ) {
    final values = <String, (int, bool, String)>{};
    for (final item in raw) {
      if (item is! Map || item['id'] is! String ||
          (item['id'] as String).trim().isEmpty ||
          item['amount'] is! num || item['income'] is! bool ||
          item['date'] is! String) {
        throw StateError('M620_INVALID_VERIFIED_TRANSACTION');
      }
      final id = item['id'] as String;
      final amount = item['amount'] as num;
      final minor = (amount * 100).round();
      if (!amount.isFinite || minor <= 0 ||
          (amount * 100 - minor).abs() > 0.00001 ||
          values.containsKey(id)) {
        throw StateError('M620_DUPLICATE_OR_INVALID_TRANSACTION_ID');
      }
      final parsedDate = DateTime.tryParse(item['date'] as String);
      if (parsedDate == null) {
        throw StateError('M620_INVALID_TRANSACTION_DATE');
      }
      // The legacy JSON can use a UTC suffix or local ISO notation. DateTime
      // model serialization can normalize formatting without moving money.
      values[id] = (minor, item['income'] as bool,
          parsedDate.toUtc().toIso8601String());
    }
    return values;
  }

  static WaffraRestoredLedgerIdentityReport verify({
    required List<dynamic> authenticatedSource,
    required List<dynamic> verifiedSnapshot,
  }) {
    final source = _records(authenticatedSource);
    final actual = _records(verifiedSnapshot);
    if (source.length != actual.length ||
        source.keys.any((id) => actual[id] != source[id])) {
      throw StateError('M620_RESTORE_LEDGER_PARITY');
    }
    return WaffraRestoredLedgerIdentityReport(
      sourceCount: source.length,
      verifiedCount: actual.length,
    );
  }
}
