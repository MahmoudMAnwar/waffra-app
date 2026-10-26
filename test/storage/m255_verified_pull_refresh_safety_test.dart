import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/waffra_verified_pull_refresh_source.dart';

/// M255 is disposable source-contract QA. It cannot prove that build #705
/// refreshes correctly on a physical Android, and cannot authorize cutover.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WaffraFinanceAuthorityRead> legacy(
      Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return WaffraFinanceAuthorityRead(
      finance: WaffraFinanceReadView.fromLegacy(prefs),
      source: WaffraRuntimeFinanceBackend.guardedLegacy,
      widgetRevision: null,
      ledgerRaw: prefs.getString('entries'),
    );
  }

  WaffraFinanceAuthorityRead encrypted(Map<String, Object?> values) {
    return WaffraFinanceAuthorityRead(
      finance: WaffraFinanceReadView.fromEncrypted(
        WaffraFinanceSnapshotState(
          generation: 1,
          digest: 'synthetic-disposable-contract-test-only',
          values: values,
        ),
      ),
      source: WaffraRuntimeFinanceBackend.verifiedEncrypted,
      widgetRevision: 'synthetic-revision',
      ledgerRaw: values['entries'] as String?,
    );
  }

  test('M255 truly fresh guarded legacy permits absent finance keys', () async {
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(
      await legacy(const <String, Object>{}),
    );
    expect(source.ledgerRaw, '[]');
    expect(source.categoriesRaw, isNull);
  });

  test('M255 existing guarded legacy preserves the authoritative JSON', () async {
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(
      await legacy(const <String, Object>{
        'entries': '[]',
        'waffra_categories_v24': '[]',
      }),
    );
    expect(source.ledgerRaw, '[]');
    expect(source.categoriesRaw, '[]');
  });

  test('M255 verified encrypted only accepts an intact authoritative source', () {
    final source = WaffraVerifiedPullRefreshSource.fromAuthority(
      encrypted(const <String, Object?>{
        'entries': '[]',
        'waffra_categories_v24': '[]',
      }),
    );
    expect(source.ledgerRaw, '[]');
    expect(source.categoriesRaw, '[]');
  });

  test('M255 encrypted missing ledger never becomes a fabricated empty list', () {
    expect(
      () => WaffraVerifiedPullRefreshSource.fromAuthority(
        encrypted(const <String, Object?>{
          'waffra_categories_v24': '[]',
        }),
      ),
      throwsStateError,
    );
  });

  test('M255 encrypted missing category catalog fails closed', () {
    expect(
      () => WaffraVerifiedPullRefreshSource.fromAuthority(
        encrypted(const <String, Object?>{
          'entries': '[]',
        }),
      ),
      throwsStateError,
    );
  });

  test('M255 malformed legacy ledger cannot be silently replaced', () async {
    final current = await legacy(const <String, Object>{
      'entries': 'not-json',
    });
    expect(
      () => WaffraVerifiedPullRefreshSource.fromAuthority(current),
      throwsStateError,
    );
  });

  test('M255 malformed encrypted ledger cannot be silently replaced', () {
    expect(
      () => WaffraVerifiedPullRefreshSource.fromAuthority(
        encrypted(const <String, Object?>{
          'entries': 'not-json',
          'waffra_categories_v24': '[]',
        }),
      ),
      throwsStateError,
    );
  });

  test('M255 UI refresh keeps verified read + fail-closed recovery', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final start = mainSource.indexOf(
      'Future<void> _refreshFromVerifiedFinance()async {',
    );
    final end = mainSource.indexOf('Future<void> load()async {', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final refresh = mainSource.substring(start, end);
    expect(refresh, contains('await _financialWriteQueue.drain();'));
    expect(refresh, contains('await _ensureFinanceBound();'));
    expect(refresh, contains(
      '_financeAuthority.load(',
    ));
    expect(refresh, contains('route:WaffraFinanceRoute.dashboardRead'));
    expect(refresh, contains('view.requireIntegrity();'));
    expect(refresh, contains(
      'WaffraVerifiedPullRefreshSource.fromAuthority(current)',
    ));
    expect(refresh, contains('ready=false;'));
    expect(refresh, contains('_financeLoadFailure='));
    expect(refresh, isNot(contains('await persist(')));
    expect(refresh, isNot(contains('entries.clear();')));
    expect(refresh, isNot(contains('loadWithWitness(')));
    expect(mainSource, contains('onRefresh:_refreshFromVerifiedFinance'));
    // This static UI check supplements (does not replace) on-device #705 QA.
  });
}
