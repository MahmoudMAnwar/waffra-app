import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_m154_transaction_schema_bridge.dart';

void main(){
 test('M154: preserved long legacy SMS title, notes, merchant key, receipt bytes reference',(){
  final before=<String,dynamic>{
   'id':'entry-1','title':'old bank text '+List.filled(5000,'x').join(),
   'category':'أخرى / تاجر مثال','amount':200.50,'income':false,
   'date':'2026-10-20T16:09:00','receiptPath':'private/receipt-key',
   'notes':'ملاحظات','sourceType':'sms','merchantKey':'example merchant',
   'futureAttribute':{'flag':true},
  };
  final after=WaffraM154TransactionSchemaBridge.captureLossless(before);
  expect(after,deepEquals(before));
  after['title']='new text';
  expect(before['title'],isNot('new text'));
  final array=WaffraM154TransactionSchemaBridge.canonicalList([before]);
  final roundTrip=Map<String,dynamic>.from((jsonDecode(array) as List).single as Map);
  expect(roundTrip,deepEquals(before));
 });

 test('M154: no silent loss or coercion of malformed finance entries',(){
  final base=<String,dynamic>{
   'id':'1','title':'X','category':'أخرى / مثال','amount':10.01,
   'income':false,'date':'2026-10-20T16:09:00',
  };
  for(final update in <Map<String,dynamic>>[
   {'id':''},{'amount':-3},{'amount':'100'},{'income':'false'},
   {'date':'not-a-date'},{'notes':42},{'merchantKey':42},
   {'sourceType':false},{'receiptPath':[]},
  ]){
   final bad=<String,dynamic>{...base,...update};
   expect(()=>WaffraM154TransactionSchemaBridge.captureLossless(bad),
     throwsFormatException);
  }
 });
}
