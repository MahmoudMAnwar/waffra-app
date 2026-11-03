import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_auto_sms_policy.dart';

void main(){
 const debit='Card Purchase: SAR 75.00 at TEST FUEL station';
 const credit='Credit Transfer via Alinma Bank Amount: SAR 1900.00';
 final arrived=DateTime(2026,11,3,8,50);
 test('confirmed Alinma credit qualifies as income',(){
  final result=WaffraAutoSmsPolicy.decide(sender:'ALINMA',sms:credit,
   parsedAmount:1900,parsedIncome:true,foreignCurrency:false,arrived:arrived);
  expect(result.canPost,isTrue);
 });
 test('confirmed bank purchase qualifies as expense',(){
  final result=WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',sms:debit,
   parsedAmount:75,parsedIncome:false,foreignCurrency:false,arrived:arrived);
  expect(result.canPost,isTrue);
 });
 test('opposing transfer actions never post',(){
  final result=WaffraAutoSmsPolicy.decide(sender:'ALINMA',
   sms:'Credit Transfer debited SAR 1900.00 to other account',
   parsedAmount:1900,parsedIncome:true,foreignCurrency:false,arrived:arrived);
  expect(result.canPost,isFalse);
 });
 test('card settlement never counted as spending',(){
  final result=WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',
   sms:'Credit Card Payment debited SAR 200.00',
   parsedAmount:200,parsedIncome:false,foreignCurrency:false,arrived:arrived);
  expect(result.canPost,isFalse);
 });
 test('personal senders, foreign currency and unverified account all abstain',(){
  for(final sender in ['0551234567','Personal Friend']){
   expect(WaffraAutoSmsPolicy.decide(sender:sender,sms:debit,
    parsedAmount:75,parsedIncome:false,foreignCurrency:false,
    arrived:arrived).canPost,isFalse);
  }
  expect(WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',
   sms:'Card Purchase: AED 75.00',parsedAmount:75,
   parsedIncome:false,foreignCurrency:true,arrived:arrived).canPost,isFalse);
  expect(WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',sms:debit,
   parsedAmount:75,parsedIncome:false,foreignCurrency:false,
   arrived:arrived,accountLinked:false).canPost,isFalse);
 });
 test('OTP or invalid amounts cannot post',(){
  for(final amount in <double>[double.nan,double.infinity,-1.0,0.0,0.001]){
   expect(WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',sms:debit,
    parsedAmount:amount,parsedIncome:false,foreignCurrency:false,
    arrived:arrived).canPost,isFalse);
  }
  expect(WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',
   sms:'Your OTP 123456 for purchase of SAR 75.00',
   parsedAmount:75,parsedIncome:false,foreignCurrency:false,
   arrived:arrived).canPost,isFalse);
 });
 test('not valid with a mismatched extracted direction',(){
  expect(WaffraAutoSmsPolicy.decide(sender:'ALINMA',sms:credit,
   parsedAmount:1900,parsedIncome:false,foreignCurrency:false,
   arrived:arrived).canPost,isFalse);
 });
 test('too-old dates are referred for review',(){
  expect(WaffraAutoSmsPolicy.decide(sender:'ALRAJHI',sms:debit,
   parsedAmount:75,parsedIncome:false,foreignCurrency:false,
   arrived:arrived,verifiedDate:DateTime(2024,1,1)).canPost,isFalse);
 });
}
