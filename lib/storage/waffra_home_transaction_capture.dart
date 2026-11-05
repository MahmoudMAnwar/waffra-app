import 'dart:convert';

import 'waffra_production_finance_routing_gate.dart';
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
  /// M461: an encrypted editor may send only its own typed projection keys.
  /// A freshly created SQLCipher vault does not contain the optional Home
  /// fields. Reposting all displayed defaults makes unrelated keys look like
  /// edits and SQLCipher must (correctly) reject that unsafe capture.
  ///
  /// Never swallow an actual unrelated user edit: compare it with the loaded
  /// verified witness and reject modified keys or non-empty missing modules.
  static void narrowVerifiedModuleEdit({
    required WaffraFinanceRoute route,
    required WaffraRuntimeFinanceBackend? source,
    required Map<String, Object> snapshot,
    required Map<String, Object?>? witnessedValues,
  }) {
    if (source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        route == WaffraFinanceRoute.manualTransactionSave) return;
    final allowed = switch (route) {
      WaffraFinanceRoute.transactionEdit => const <String>{'entries'},
      WaffraFinanceRoute.goalCreateEditDeleteRestore =>
        const <String>{'waffra_goals_v24', 'waffra_recurring_v24'},
      WaffraFinanceRoute.recurringCreateEditDeleteRestore =>
        const <String>{'waffra_recurring_v24'},
      WaffraFinanceRoute.categoryCreateEditDeleteRestore =>
        const <String>{'waffra_categories_v24'},
      _ => const <String>{},
    };
    if (allowed.isEmpty) return; // Other routes retain their own strict gates.
    if (witnessedValues == null) {
      throw StateError('Encrypted module edit requires a source witness.');
    }
    for (final field in snapshot.entries) {
      if (allowed.contains(field.key)) continue;
      if (witnessedValues.containsKey(field.key)) {
        if (jsonEncode(witnessedValues[field.key]) != jsonEncode(field.value)) {
          throw StateError('Unrelated finance field changed during module edit.');
        }
      } else if (!_emptyOptionalModule(field.value)) {
        throw StateError('Missing encrypted field has an unconfirmed value.');
      }
    }
    snapshot.removeWhere((key, _) => !allowed.contains(key));
    if (snapshot.isEmpty) {
      throw StateError('Encrypted module edit has no scoped changes.');
    }
  }

  static bool _emptyOptionalModule(Object value) =>
    value == '[]' || value == '{}' || value == '' ||
    value == false || value == 0 || value == 0.0;

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
