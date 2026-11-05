import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_account_learning.dart';

void main(){
 test('Sender account suggestion requires TWO matching confirmations',(){
  final once=WaffraSmsAccountLearning.confirmed(
   const <WaffraSmsAccountEvidence>[],
   sender:'AlRajhiBank',accountId:'rajhi-1',suffix:'١٢٣٤');
  expect(WaffraSmsAccountLearning.suffix4('١٢٣٤'),'1234');
  expect(WaffraSmsAccountLearning.suggest(
   once,sender:'AlRajhiBank',suffix:null,
   activeAccountIds:{'rajhi-1'},sameBankAccountIds:{'rajhi-1'}),isNull);
  final twice=WaffraSmsAccountLearning.confirmed(
   once,sender:'AlRajhiBank',accountId:'rajhi-1',suffix:'1234');
  expect(WaffraSmsAccountLearning.suggest(
   twice,sender:'AlRajhiBank',suffix:null,
   activeAccountIds:{'rajhi-1','inma-1'},
   sameBankAccountIds:{'rajhi-1'}),'rajhi-1');
  expect(WaffraSmsAccountLearning.suggest(
   twice,sender:'AlRajhiBank',suffix:'1234',
   activeAccountIds:{'rajhi-1','inma-1'},
   sameBankAccountIds:{'rajhi-1'}),'rajhi-1');
 });

 test('Two accounts at the same bank NEVER resolve sender only',(){
  var learned=WaffraSmsAccountLearning.confirmed(
   const <WaffraSmsAccountEvidence>[],
   sender:'AlRajhiBank',accountId:'rajhi-1',suffix:'1234');
  learned=WaffraSmsAccountLearning.confirmed(
   learned,sender:'AlRajhiBank',accountId:'rajhi-1',suffix:'1234');
  expect(WaffraSmsAccountLearning.suggest(
   learned,sender:'AlRajhiBank',suffix:null,
   activeAccountIds:{'rajhi-1','rajhi-2'},
   sameBankAccountIds:{'rajhi-1','rajhi-2'}),isNull);
  // A stale account cannot be suggested after archived/removed.
  expect(WaffraSmsAccountLearning.suggest(
   learned,sender:'AlRajhiBank',suffix:'1234',
   activeAccountIds:{'rajhi-2'},
   sameBankAccountIds:{'rajhi-2'}),isNull);
 });

 test('Conflicting account selection resets confidence',(){
  var learned=WaffraSmsAccountLearning.confirmed(
   const <WaffraSmsAccountEvidence>[],
   sender:'AlRajhiBank',accountId:'rajhi-1',suffix:null);
  learned=WaffraSmsAccountLearning.confirmed(
   learned,sender:'AlRajhiBank',accountId:'rajhi-1',suffix:null);
  learned=WaffraSmsAccountLearning.confirmed(
   learned,sender:'AlRajhiBank',accountId:'rajhi-2',suffix:null);
  expect(WaffraSmsAccountLearning.suggest(
   learned,sender:'AlRajhiBank',suffix:null,
   activeAccountIds:{'rajhi-1','rajhi-2'},
   sameBankAccountIds:{'rajhi-2'}),isNull);
  learned=WaffraSmsAccountLearning.confirmed(
   learned,sender:'AlRajhiBank',accountId:'rajhi-2',suffix:null);
  expect(WaffraSmsAccountLearning.suggest(
   learned,sender:'AlRajhiBank',suffix:null,
   activeAccountIds:{'rajhi-1','rajhi-2'},
   sameBankAccountIds:{'rajhi-2'}),'rajhi-2');
 });

 test('Unrecognized sender cannot create bank-account learning',(){
  final learned=WaffraSmsAccountLearning.confirmed(
   const <WaffraSmsAccountEvidence>[],
   sender:'Random Sender',accountId:'cash-1');
  expect(learned,isEmpty);
  expect(WaffraSmsAccountLearning.suggest(
   learned,sender:'Random Sender',suffix:null,
   activeAccountIds:{'cash-1'},sameBankAccountIds:{'cash-1'}),isNull);
 });
}
