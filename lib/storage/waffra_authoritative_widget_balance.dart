import 'dart:convert';

import '../waffra_recurring_policy.dart';
import 'legacy_snapshot_preflight.dart';

/// Computes the widget balance from an *independently source-verified*
/// finance ledger. This class never reads SharedPreferences or a UI cache.
/// Both the Home engine and Widget engine must call the production finance
/// authority (widgetBalanceRefresh route) BEFORE passing a ledger here.
class WaffraAuthoritativeWidgetBalance {
  const WaffraAuthoritativeWidgetBalance._();

  static int netHalalas(String ledgerRaw) {
    final parsed = jsonDecode(ledgerRaw);
    if (parsed is! List || parsed.length > 100000) {
      throw StateError('Widget balance ledger is invalid.');
    }
    final ids = <String>{};
    var net = 0;
    for (final record in parsed) {
      if (record is! Map ||
          record['id'] is! String ||
          (record['id'] as String).trim().isEmpty ||
          !ids.add(record['id'] as String) ||
          record['income'] is! bool ||
          record['amount'] is! num) {
        throw StateError('Widget balance transaction is malformed.');
      }
      final value = (record['amount'] as num).toDouble();
      if (!value.isFinite || value < 0 || value > 1000000000000 ||
          !WaffraLegacyPreflight.canRepresentHalalas(value)) {
        // Never round invalid sub-halalah values into a seemingly valid
        // displayed balance. Hide the widget until the source is reconciled.
        throw StateError('Widget balance amount violates ledger precision.');
      }
      final halalas = WaffraRecurringPolicy.toHalalas(value);
      net += record['income'] == true ? halalas : -halalas;
      if (net.abs() > 9000000000000000) {
        throw StateError('Widget balance total exceeds safe precision.');
      }
    }
    return net;
  }
}
