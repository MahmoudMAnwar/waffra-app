import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M929 Home logout, finance notice, and no-post FX keep exact production contracts',(){
  final main=File('lib/main.dart').readAsStringSync();
  final restored=readWaffraMainSourceForContracts();
  final contracts=<String,List<String>>{
   'lib/waffra_home_logout_guard.part.dart':[
    ' Future<void> _m627CloseForLogout()async{',
    '_m630HomeStartupEpoch++;',
    'await pendingLoad.future.timeout(const Duration(seconds:20));',
    '_m627OutstandingAccountReads.toList()',
    'await _m468PersistSequence.timeout(const Duration(seconds:20));',
    'await _financialWriteQueue.drain().timeout(const Duration(seconds:20));',
    'if(binding!=null)await binding.close();',
    '_financeBindingFuture=null;',
    ' void _m627AbortFailedLogout(){',
   ],
   'lib/waffra_home_finance_notification_route.part.dart':[
    ' void _m621OnFinanceNoticeTap(){',
    'AppLifecycleState.resumed',
    'await _reviewAutoSmsCandidates(targetId:target.id)',
    "record.id==target.entryId&&record.sourceType=='sms'",
    'await transactionDetails(matching.single)',
   ],
   'lib/waffra_home_fx_preview.part.dart':[
    ' Future<void> _previewForeignBankCurrency(String raw)async {',
    'if(!WaffraSaudiRelease.bankSmsForeignCurrencyPreview)',
    'WaffraSmsCurrencies.originalAmount(raw)',
    'WaffraForeignCurrencyPreview.show(context,',
    'No amount was saved;',
   ],
  };
  for(final item in contracts.entries){
   final file=File(item.key).readAsStringSync();
   expect(file,startsWith("part of 'main.dart';"),reason:item.key);
   expect(main,contains("part '${item.key.split('/').last}';"),reason:item.key);
   for(final fragment in item.value){
    expect(file,contains(fragment),reason:'${item.key}: $fragment');
    expect(restored,contains(fragment),reason:'contract source ${item.key}: $fragment');
   }
  }
  expect(File('lib/waffra_home_fx_preview.part.dart').readAsStringSync(),
    isNot(contains('saveCaptured(')));
  expect(File('lib/waffra_home_finance_notification_route.part.dart').readAsStringSync(),
    isNot(contains('commitConfirmedSms(')));
  expect(main,isNot(contains(' Future<void> _m627CloseForLogout()async{')));
  expect(main,isNot(contains(' void _m621OnFinanceNoticeTap(){')));
  expect(main,isNot(contains(' Future<void> _previewForeignBankCurrency(String raw)async {')));
 });
}
