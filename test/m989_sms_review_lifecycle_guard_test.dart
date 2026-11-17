import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M989 typed SMS editor cannot directly post composite or reversal',(){
  final src=readWaffraMainSourceForContracts();
  final direct=src.split('Future<void> _m983OpenSmsTypedTemplate({')[1]
   .split('Future<void> _reviewAutoSmsCandidates(')[0];
  expect(direct,contains('WaffraSmsLifecycleEvidence.inspect(body,sender:sender)'));
  expect(direct,contains('WaffraSmsStructuredBankContext.multipleEvents(body)'));
  expect(direct,contains('lifecycle.stage==WaffraSmsLifecycleStage.reversed'));
  expect(direct,contains('lifecycle.stage==WaffraSmsLifecycleStage.refunded'));
  expect(direct,contains('await _reviewAutoSmsCandidates(targetId:id);'));
 });
 test('M989 human review disabled Yes for composite and refund/reversal',(){
  final src=readWaffraMainSourceForContracts();
  final review=src.split('Future<void> _reviewAutoSmsCandidates({')[1]
   .split('Future<void> _m565ConfirmSms({')[0];
  expect(review,contains('final requiresSeparateReview=composite||'));
  expect(review,contains('bool canConfirm=ownerBlocker()==null;'));
  expect(review,contains('requiresSeparateReview:requiresSeparateReview'));
  expect(review,contains('WaffraBankSmsFactsParser.ownerConfirmationBlocker('));
  expect(review,contains('canConfirm=ownerBlocker()==null;'));
  expect(review,contains("Key('m989-lifecycle-manual-review-warning')"));
  expect(review,contains("key:const Key('m565-sms-yes-confirm')"));
 });
 test('M989 lifecycle guard remains UI-only and never writes ledger',(){
  final code=File('lib/waffra_sms_lifecycle_evidence.dart').readAsStringSync();
  expect(code,isNot(contains('saveCaptured(')));
  expect(code,isNot(contains('acknowledgeCommitted(')));
  expect(code,isNot(contains('excludeMessages(')));
 });
}
