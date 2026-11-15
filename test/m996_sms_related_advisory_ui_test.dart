import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_lifecycle_evidence.dart';

void main(){
 test('M996 visible SMS row shows distinct tentative related-event labels',(){
  final src=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(src,contains("final related=item['relatedSmsEvent'];"));
  for(final kind in const [
   'possibleDuplicate','possibleSettlement',
   'possibleReversal','relatedNeedsReview',
  ]){
   expect(src,contains("'"+kind+"'"));
  }
  expect(src,contains('قد يكون إشعارًا مكررًا'));
  expect(src,contains('قد تكون تسوية لعملية معلقة'));
  expect(src,contains('قد يكون استردادًا أو عكسًا'));
  expect(src,contains("if(relatedLabel!=null)Padding("));
  // Existing source text, three explicit edit actions and select-all remain.
  expect(src,contains("((item['body'] as String?)??'')"));
  expect(src,contains("for(final kind in const <String>['income','expense','transfer'])"));
  expect(src,contains("waffra-sms-select-message-"));
  expect(src,isNot(contains('commitConfirmedSms(')));
 });

 test('M996 no financial writer or native ACK from advisory relation engine',(){
  final src=File('lib/waffra_sms_lifecycle_evidence.dart').readAsStringSync();
  expect(src,isNot(contains('saveCaptured(')));
  expect(src,isNot(contains('acknowledgeCommitted(')));
  expect(src,isNot(contains('excludeMessages(')));
  expect(WaffraSmsRelatedEvent.values.length,5);
 });
}
