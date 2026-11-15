import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_saudi_template_registry.dart';
import 'package:waffra/waffra_sms_account_learning.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';

void main(){
 test('M992 v1 templates cover Saudi debit/credit/status message families',(){
  const notices=<String,String>{
   'Purchase Card 100 SAR':'purchase',
   'شراء عبر نقاط البيع ١٠٠ ريال':'purchase',
   'Outgoing Transfer 100 SAR':'outgoing_transfer',
   'حوالة صادرة 100 SAR':'outgoing_transfer',
   'Incoming Transfer 100 SAR':'incoming_transfer',
   'حوالة واردة ١٠٠ ريال':'incoming_transfer',
   'Salary Deposit 5000 SAR':'salary',
   'راتب ٥٠٠٠ ريال':'salary',
   'ATM withdrawal 200 SAR':'atm_withdrawal',
   'سحب نقدي 200 ريال':'atm_withdrawal',
   'Bill Payment 100 SAR':'bill_payment',
   'سداد فاتورة كهرباء':'bill_payment',
   'Credit Card Settlement 100 SAR':'card_settlement',
   'إيداع 200 ريال':'deposit',
   'Refund received 20 SAR':'reversal_or_refund',
   'Purchase Card reversed 20 SAR':'reversal_or_refund',
   'Pending Purchase Card 100 SAR':'non_posted',
   'Declined Transaction Purchase 100 SAR':'non_posted',
   'OTP 445566':'verification',
   'رمز التحقق ١٢٣٤٥٦':'verification',
  };
  for(final row in notices.entries){
   final match=WaffraSaudiSmsTemplateRegistry.identify(
    providerId:'rajhi',body:row.key);
   expect(match,isNotNull,reason:row.key);
   expect(match!.family,row.value,reason:row.key);
   expect(match.version,1);
   expect(match.fixtureId,'sa-v1:rajhi:'+row.value);
  }
 });

 test('M992 provider coverage table stays offline and owner-safe',(){
  const senders=<String,String>{
   'AlRajhi':'rajhi',
   'AlInma':'inma',
   'SNB':'snb',
   'Riyad':'riyad',
   'Bilad':'bilad',
   'SABB':'sabb',
   'ANB':'anb',
   'BSF':'bsf',
   'SAIB':'saib',
   'Jazira':'jazira',
   'D360':'d360',
   'Barq':'barq',
  };
  for(final sender in senders.entries){
   expect(WaffraSmsAccountLearning.bankGroup(sender.key),
    sender.value,reason:sender.key);
   final context=WaffraSmsStructuredBankContext.parse(
    'Purchase Card\nAmount: 100 SAR\nAccount: **1234',
    sender:sender.key);
   expect(context.providerId,sender.value);
   expect(context.templateFamily,'purchase');
   expect(context.templateVersion,1);
   expect(context.accountLastFour,
    sender.value=='barq'?isNull:'1234',reason:sender.key);
  }
 });

 test('M992 unknown sender or combined actions cannot gain family',(){
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:null,body:'Purchase Card 20 SAR'),isNull);
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'unknown',body:'Purchase Card 20 SAR'),isNull);
  const combined='Purchase Card 20 SAR; Outgoing Transfer 15 SAR';
  final ctx=WaffraSmsStructuredBankContext.parse(
   combined,sender:'AlRajhi');
  expect(ctx.composite,isTrue);
  expect(ctx.templateFamily,isNull);
  expect(ctx.principalSar,isNull);
  expect(ctx.requiresReview,isTrue);
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'rajhi',body:combined,multipleFinancialEvents:true),isNull);
 });

 test('M992 template must never be a finance permission',(){
  final pending=WaffraSmsStructuredBankContext.parse(
   'Pending Purchase Card\nAmount: 100 SAR\nAccount: **1234',
   sender:'AlRajhi');
  expect(pending.templateFamily,'non_posted');
  expect(pending.principalSar,isNull);
  expect(pending.requiresReview,isTrue);
  final otp=WaffraSmsStructuredBankContext.parse(
   'OTP 123456',sender:'AlRajhi');
  expect(otp.templateFamily,'verification');
  expect(otp.principalSar,isNull);
 });
}
