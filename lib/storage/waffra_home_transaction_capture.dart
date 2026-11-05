import 'waffra_runtime_finance_route_contract.dart';

/// Reduce only a new manual SQLCipher posting to its requested ledger delta.
///
/// A newly registered encrypted vault intentionally has just the mandatory
/// ledger and category fields. The Home editor displays optional empty budgets,
/// goals, and recurring values without writing those defaults to SQLCipher.
/// Sending the whole displayed Home snapshot for one manual transaction would
/// be rejected as an unrelated finance mutation. Do not weaken that guard:
/// submit only the entry list for the specifically witnessed append route.
abstract final class WaffraHomeTransactionCapture {
  static void narrowVerifiedManualAppend({
    required WaffraFinanceRoute route,
    required WaffraRuntimeFinanceBackend? source,
    required Map<String, Object> snapshot,
  }) {
    if (route != WaffraFinanceRoute.manualTransactionSave ||
        source != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      return;
    }
    if (snapshot['entries'] is! String) {
      throw StateError('Verified manual save requires captured entries.');
    }
    snapshot.removeWhere((key, _) => key != 'entries');
  }
}
