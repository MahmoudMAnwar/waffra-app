import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_receipt_screen_contract.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/waffra_verified_receipt_screen_gateway.dart';

class _LegacySource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
    'entries': '[]',
  }));
  const route = WaffraFinanceRoute.receiptRemoveAndRollback;

  WaffraVerifiedFinanceAuthority authority() =>
      WaffraVerifiedFinanceAuthority(sourceGuard: _LegacySource());

  WaffraReceiptScreenState archive() => WaffraReceiptScreenState(
    entryId: 'legacy-record',
    generation: 4,
    images: const [],
    recoverUntilMs: DateTime.utc(2026, 11, 20).millisecondsSinceEpoch,
  );

  test('M119 legacy finance authority cannot read SQLCipher receipt UI',
      () async {
    final gateway = WaffraVerifiedReceiptScreenGateway(
      authority: authority(),
    );
    await expectLater(gateway.load('legacy-record'), throwsStateError);
  });

  test('M119 old source refuses receipt recycle and restore routes', () async {
    final legacy = authority();
    final active = WaffraReceiptScreenState(
      entryId: 'legacy-record', generation: 0,
      images: [Uint8List.fromList([5, 6])],
    );
    await expectLater(legacy.moveEncryptedReceiptBatchToRecycle(
      route: route,
      baseline: active,
      userConfirmed: true,
      now: DateTime.utc(2026, 10, 23),
    ), throwsStateError);
    await expectLater(legacy.restoreEncryptedReceiptBatchFromRecycle(
      route: route,
      baseline: archive(),
      now: DateTime.utc(2026, 10, 23),
    ), throwsStateError);
  });

  test('M119 route confusion and unconfirmed remove stop before source',
      () async {
    final a = authority();
    final state = WaffraReceiptScreenState(
      entryId: 'synthetic', generation: 0,
      images: [Uint8List.fromList([1])],
    );
    await expectLater(a.loadVerifiedReceiptScreen(
      route: WaffraFinanceRoute.dashboardRead,
      entryId: 'synthetic',
    ), throwsArgumentError);
    await expectLater(a.moveEncryptedReceiptBatchToRecycle(
      route: route, baseline: state,
      userConfirmed: false,
      now: DateTime.utc(2026, 10, 23),
    ), throwsStateError);
    await expectLater(a.restoreEncryptedReceiptBatchFromRecycle(
      route: WaffraFinanceRoute.receiptView,
      baseline: archive(),
      now: DateTime.utc(2026, 10, 23),
    ), throwsArgumentError);
  });
}
