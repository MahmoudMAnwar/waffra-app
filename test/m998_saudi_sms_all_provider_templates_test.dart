import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_saudi_financial_providers.dart';
import 'package:waffra/waffra_sms_saudi_template_registry.dart';
import 'package:waffra/waffra_sms_account_learning.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';

void main(){
 test('M998 every catalogued Saudi bank/digital bank/wallet has safe templates',(){
  final all=WaffraSaudiFinancialProviders.all;
  expect(all.length,17);
  expect(all.map((x)=>x.id).toSet().length,17);
  for(final provider in all){
   for(final row in <(String,String)>[
    ('Purchase Card\nAmount: 10 SAR','purchase'),
    ('Incoming Transfer\nAmount: 20 SAR','incoming_transfer'),
    ('Outgoing Transfer\nAmount: 30 SAR','outgoing_transfer'),
    ('Salary Deposit 4000 SAR','salary'),
    ('ATM Withdrawal 100 SAR','atm_withdrawal'),
    ('Wallet Top Up 20 SAR','wallet_topup'),
    ('Cashback Received 3 SAR','cashback_notice'),
    ('Beneficiary Added: Ahmed','beneficiary_notice'),
    ('Card Activated','card_activation'),
    ('Available Balance: 500 SAR','balance_notice'),
    ('Pending Purchase Card 50 SAR','non_posted'),
    ('OTP 123456','verification'),
    ('Refund Received 25 SAR','reversal_or_refund'),
   ]){
    final match=WaffraSaudiSmsTemplateRegistry.identify(
     providerId:provider.id,body:row.$1);
    expect(match?.family,row.$2,reason:provider.id+': '+row.$1);
    expect(match?.version,1);
   }
  }
 });

 test('M998 actual sender-alias entry points cover all 17 trusted institutions',(){
  const senders=<String,String>{
   'AlRajhi':'rajhi','AlInma':'inma','SNB':'snb',
   'Riyad':'riyad','Bilad':'bilad','SABB':'sabb',
   'ANB':'anb','BSF':'bsf','SAIB':'saib','Jazira':'jazira',
   'GIB':'gib','STCBank':'stc','VisionBank':'vision',
   'D360':'d360','Barq':'barq','EnjazPay':'enjazpay',
   'AlinmaPay':'alinmapay',
  };
  expect(senders.length,WaffraSaudiFinancialProviders.all.length);
  for(final sender in senders.entries){
   expect(WaffraSmsAccountLearning.bankGroup(sender.key),
    sender.value,reason:sender.key);
   final context=WaffraSmsStructuredBankContext.parse(
    'Purchase Card\nAmount: 20 SAR\nAccount: **1234',
    sender:sender.key);
   expect(context.providerId,sender.value);
   expect(context.templateFamily,'purchase');
   final provider=WaffraSaudiFinancialProviders.byId(sender.value);
   expect(provider,isNotNull);
   if(provider!.category==WaffraSaudiFinancialProviders.wallet){
    expect(context.accountLastFour,isNull,reason:sender.key);
   }else{
    expect(context.accountLastFour,'1234',reason:sender.key);
   }
  }
  for(final sender in const [
   'FakeAlRajhiBank','UnknownD360Wallet','BarqScam','SABBOffers',
  ]){
   expect(WaffraSmsAccountLearning.bankGroup(sender),isNull);
  }
 });

 test('M998 all 17 provider IDs have no account ownership permission',(){
  final all=WaffraSaudiFinancialProviders.all;
  for(final provider in all){
   final match=WaffraSaudiSmsTemplateRegistry.identify(
    providerId:provider.id,
    body:'Purchase Card\nAmount: 20 SAR\nAccount: **1234');
   expect(match?.providerId,provider.id);
   expect(match?.family,'purchase');
   if(provider.category==WaffraSaudiFinancialProviders.wallet){
    final sender=const <String,String>{
      'barq':'Barq','enjazpay':'EnjazPay','alinmapay':'AlinmaPay',
    }[provider.id]!;
    expect(WaffraSmsAccountLearning.bankGroup(sender),provider.id);
    final context=WaffraSmsStructuredBankContext.parse(
     'Purchase Card\nAmount: 20 SAR\nAccount: **1234',
     sender:sender);
    expect(context.accountLastFour,isNull);
   }
  }
 });

 test('M998 financial+OTP and two-action text cannot gain posting clearance',(){
  for(final body in const <String>[
   'Purchase Card 50 SAR\nOTP 123456',
   'Purchase Card 50 SAR\nOutgoing Transfer 10 SAR',
   'حوالة صادرة بمبلغ ١٠ ريال; شراء بقيمة ٢٠ ريال',
  ]){
   final context=WaffraSmsStructuredBankContext.parse(
    body,sender:'AlRajhi');
   expect(context.principalSar,isNull);
   expect(context.requiresReview,isTrue);
  }
 });

 test('M998 unknown catalog ID and ambiguous mixed transfer are not templates',(){
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'fake-bank',body:'Purchase Card 50 SAR'),isNull);
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'rajhi',body:'Transfer 15 SAR'),isNull);
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'rajhi',
   body:'Purchase Card 50 SAR\nOutgoing Transfer 10 SAR',
   multipleFinancialEvents:true),isNull);
 });
}
