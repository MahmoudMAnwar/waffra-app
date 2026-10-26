import 'waffra_runtime_finance_route_contract.dart';
import 'waffra_verified_finance_authority.dart';

/// Resolve the same legitimate first-install defaults as normal Home startup.
///
/// A missing field in GUARDED LEGACY preferences is not evidence of corruption:
/// a fresh install can have no saved transactions or category key at all.
/// Unlike legacy, an independently activated SQLCipher snapshot must expose
/// its complete authoritative ledger and catalog. Never synthesize a second
/// empty encrypted source or reinterpret malformed persisted JSON.
class WaffraVerifiedPullRefreshSource {
  const WaffraVerifiedPullRefreshSource._({
    required this.ledgerRaw,
    required this.categoriesRaw,
  });

  final String ledgerRaw;
  final String? categoriesRaw;

  static WaffraVerifiedPullRefreshSource fromAuthority(
    WaffraFinanceAuthorityRead current,
  ) {
    current.finance.requireIntegrity();
    final ledger = current.ledgerRaw;
    final categories = current.finance.getString('waffra_categories_v24');
    if (current.source == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        (ledger == null || categories == null)) {
      throw StateError('Verified encrypted refresh has an incomplete source.');
    }
    // Never replace an existing or corrupt ledger with a blank list. The
    // fallback is legal only when the guarded legacy key is genuinely absent.
    return WaffraVerifiedPullRefreshSource._(
      ledgerRaw: ledger ?? '[]',
      categoriesRaw: categories,
    );
  }
}
