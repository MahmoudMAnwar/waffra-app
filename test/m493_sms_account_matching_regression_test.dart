import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_account_learning.dart';

void main(){
 test('M568 exact confirmed last-four reusable after first owner-confirmed save',(){
  var rows=<WaffraSmsAccountEvidence>[];
  rows=WaffraSmsAccountLearning.confirmed(rows,
   sender:'AlinmaPay',accountId:'inma-current',suffix:'٨٣٠٨');
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:{'inma-current'},
   sameBankAccountIds:{'inma-current'}),'inma-current');
  rows=WaffraSmsAccountLearning.confirmed(rows,
   sender:'AlinmaPay',accountId:'inma-current',suffix:'8308');
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:{'inma-current'},
   sameBankAccountIds:{'inma-current'}),'inma-current');
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'9999',activeAccountIds:{'inma-current'},
   sameBankAccountIds:{'inma-current'}),isNull);
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:{'inma-current'},
   sameBankAccountIds:{'rajhi-current'}),isNull);
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:<String>{},
   sameBankAccountIds:{'inma-current'}),isNull);
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'Other SMS',
   suffix:'8308',activeAccountIds:{'inma-current'},
   sameBankAccountIds:{'inma-current'}),isNull);
 });

 test('M493 #408 ambiguous same-bank accounts require explicit selection',(){
  var rows=<WaffraSmsAccountEvidence>[];
  for(var i=0;i<2;i++){
   rows=WaffraSmsAccountLearning.confirmed(rows,
    sender:'AlinmaPay',accountId:'inma-current',suffix:'8308');
  }
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:null,activeAccountIds:{'inma-current','inma-savings'},
   sameBankAccountIds:{'inma-current','inma-savings'}),isNull);
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:{'inma-current','inma-savings'},
   sameBankAccountIds:{'inma-current','inma-savings'}),'inma-current');
  // A new explicitly confirmed choice replaces the exact suffix mapping.
  rows=WaffraSmsAccountLearning.confirmed(rows,
   sender:'AlinmaPay',accountId:'inma-savings',suffix:'8308');
  expect(WaffraSmsAccountLearning.suggest(rows,sender:'AlinmaPay',
   suffix:'8308',activeAccountIds:{'inma-current','inma-savings'},
   sameBankAccountIds:{'inma-current','inma-savings'}),'inma-savings');
 });
}
