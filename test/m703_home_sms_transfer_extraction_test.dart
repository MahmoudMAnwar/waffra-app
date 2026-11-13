import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M703 / #633: verify the real transfer review was extracted to a
/// same-library Dart part without removing verified finance safeguards.
void main() {
 test('M703 Home registers the live SMS transfer review module', () {
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_transfer_review.part.dart')
   .readAsStringSync();
  expect(home,contains("part 'waffra_home_sms_transfer_review.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(home,contains('_reviewSmsAccountTransfer('));
  expect(part,contains('Future<void> _reviewSmsAccountTransfer('));
  expect(part,contains('await _ensureFinanceBound();'));
  expect(part,contains('WaffraVerifiedAccountsApi(bridge:bridge)'));
  expect(part,contains('await api.transferReviewedSmsWithFee('));
  expect(part,contains('await api.transfer(id:draft.requestId,'));
  expect(part,contains('acknowledgeCompletedTransfer([id])'));
  expect(part,contains('if(!mounted||!saved)return;'));
  expect(part,contains('originalSmsText:body'));
  expect(part,contains('requireSmsDateConfirmation:needsDateConfirmation'));
  expect(part,contains('await _refreshFromVerifiedFinance();'));
  expect(part,contains('await _refreshWidget();'));
 });
}
