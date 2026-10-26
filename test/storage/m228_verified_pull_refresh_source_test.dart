import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/waffra_verified_pull_refresh_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WaffraFinanceAuthorityRead> fixture(
    Map<String, Object> values, {
    WaffraRuntimeFinanceBackend source =
        WaffraRuntimeFinanceBackend.guardedLegacy,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    final view = WaffraFinanceReadView.fromLegacy(preferences);
    return WaffraFinanceAuthorityRead(
      finance: view,
      source: source,
      widgetRevision: null,
      ledgerRaw: view.getString('entries'),
    );
  }

  test('M228 empty legacy first install refresh matches normal startup', () async {
    final current = await fixture(<String, Object>{});
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(current);
    expect(source.ledgerRaw, '[]');
    expect(source.categoriesRaw, isNull);
  });

  test('M228 saved ledger with missing optional legacy catalog survives pull', () async {
    const existing = '[{"id":"confirmed","amount":12,"income":false}]';
    final current = await fixture(<String, Object>{'entries': existing});
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(current);
    expect(source.ledgerRaw, existing);
    expect(source.categoriesRaw, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), existing);
    expect(prefs.containsKey('waffra_categories_v24'), isFalse);
  });

  test('M228 existing empty category list is not fabricated by source reader',
      () async {
    final current = await fixture(<String, Object>{
      'entries': '[]',
      'waffra_categories_v24': '[]',
    });
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(current);
    expect(source.ledgerRaw, '[]');
    expect(source.categoriesRaw, '[]');
  });

  test('M228 incomplete encrypted catalog still fails closed', () async {
    final current = await fixture(<String, Object>{
      'entries': '[]',
    }, source: WaffraRuntimeFinanceBackend.verifiedEncrypted);
    expect(() => WaffraVerifiedPullRefreshSource.fromAuthority(current),
        throwsStateError);
  });

  test('M228 missing encrypted ledger still fails closed', () async {
    final current = await fixture(<String, Object>{
      'waffra_categories_v24': '[]',
    }, source: WaffraRuntimeFinanceBackend.verifiedEncrypted);
    expect(() => WaffraVerifiedPullRefreshSource.fromAuthority(current),
        throwsStateError);
  });

  test('M228 invalid saved legacy ledger never falls back to empty', () async {
    final current = await fixture(<String, Object>{
      'entries': '{corrupt-json',
      'waffra_categories_v24': '[]',
    });
    expect(() => WaffraVerifiedPullRefreshSource.fromAuthority(current),
        throwsStateError);
  });

  test('M228 malformed category JSON remains an integrity failure', () async {
    final current = await fixture(<String, Object>{
      'entries': '[]',
      'waffra_categories_v24': '{corrupt-json',
    });
    expect(() => WaffraVerifiedPullRefreshSource.fromAuthority(current),
        throwsStateError);
  });
}
