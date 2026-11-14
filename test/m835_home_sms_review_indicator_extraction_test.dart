import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M835 original local SMS Review status card remains registered and manual-only',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_review_indicator.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_sms_review_indicator.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsReviewIndicator on _HomeScreenState'));
  expect(part,contains(' Widget _autoSmsReviewCard(){'));
  expect(part,contains("'waffra-auto-sms-review-open'"));
  expect(part,contains("'waffra-auto-sms-review-refresh'"));
  expect(part,contains('_openAutoSmsInbox'));
  expect(part,contains('_rescanAutoSmsInbox'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(main,isNot(contains(' Widget _autoSmsReviewCard(){')));
 });
 test('M835 old SMS progress/error UX source tests inspect actual original part',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' // ignore: unused_element\n Widget _autoSmsReviewCard(){');
  final end=full.indexOf(' /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.',start);
  final part=File('lib/waffra_home_sms_review_indicator.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' // ignore: unused_element\n Widget _autoSmsReviewCard(){'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}
