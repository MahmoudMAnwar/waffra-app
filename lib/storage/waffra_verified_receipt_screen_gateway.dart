import 'waffra_production_finance_routing_gate.dart';
import 'waffra_receipt_screen_contract.dart';
import 'waffra_verified_finance_authority.dart';

/// Screen adapter for a PREVIOUSLY VERIFIED encrypted runtime.
///
/// Never constructs, initializes or activates SQLCipher, never reads legacy
/// receipt paths, and cannot be used as a preference-based source switch.
/// Every operation rechecks both the finance authority and encrypted bridge.
class WaffraVerifiedReceiptScreenGateway implements WaffraReceiptScreenPort {
  const WaffraVerifiedReceiptScreenGateway({
    required this.authority,
  });

  final WaffraVerifiedFinanceAuthority authority;

  @override
  Future<WaffraReceiptScreenState> load(String entryId) =>
      authority.loadVerifiedReceiptScreen(
        route: WaffraFinanceRoute.receiptView,
        entryId: entryId,
      );

  @override
  Future<WaffraReceiptScreenState> moveToRecycle({
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  }) async {
    await authority.moveEncryptedReceiptBatchToRecycle(
      route: WaffraFinanceRoute.receiptRemoveAndRollback,
      baseline: baseline,
      userConfirmed: userConfirmed,
      now: now,
    );
    return load(baseline.entryId);
  }

  @override
  Future<WaffraReceiptScreenState> restore({
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  }) async {
    await authority.restoreEncryptedReceiptBatchFromRecycle(
      route: WaffraFinanceRoute.receiptRemoveAndRollback,
      baseline: baseline,
      now: now,
    );
    return load(baseline.entryId);
  }
}
