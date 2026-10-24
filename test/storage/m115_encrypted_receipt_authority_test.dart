import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const authority = WaffraVerifiedFinanceAuthority();

  test('encrypted receipt attachment rejects wrong finance route', () async {
    await expectLater(authority.commitWithReceiptBytes(
      route: WaffraFinanceRoute.manualTransactionSave,
      record: const {},
      images: [Uint8List.fromList([1, 2, 3])],
      userConfirmed: true,
    ), throwsArgumentError);
  });

  test('unconfirmed attachment fails before touching source', () async {
    await expectLater(authority.commitWithReceiptBytes(
      route: WaffraFinanceRoute.receiptCopyAndAttach,
      record: const {'id': 'never-write'},
      images: [Uint8List.fromList([1, 2, 3])],
      userConfirmed: false,
    ), throwsStateError);
  });

  test('legacy source refuses encrypted receipt write and read', () async {
    await expectLater(authority.commitWithReceiptBytes(
      route: WaffraFinanceRoute.receiptCopyAndAttach,
      record: const {'id': 'never-write'},
      images: [Uint8List.fromList([1, 2, 3])],
      userConfirmed: true,
    ), throwsStateError);
    await expectLater(authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.receiptView,
      entryId: 'never-write',
    ), throwsStateError);
  });

  test('receipt reader rejects wrong route and invalid owner', () async {
    await expectLater(authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.dashboardRead,
      entryId: 'entry',
    ), throwsArgumentError);
    await expectLater(authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.receiptView,
      entryId: '  ',
    ), throwsArgumentError);
  });
}
