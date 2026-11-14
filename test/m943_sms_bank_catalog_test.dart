import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_account_learning.dart';
import 'package:waffra/waffra_saudi_financial_providers.dart';

void main(){
 test('M943 sender aliases cover every approved local/digital/wallet provider',(){
  const identities=<String,String>{
   'ALRAJHI':'rajhi','ALINMA':'inma','SNB':'snb',
   'RiyadBank':'riyad','AlBilad':'bilad','STCBANK':'stc',
   'SABB':'sabb','ANB':'anb','BSF':'bsf','SAIB':'saib',
   'AlJazira':'jazira','GIB':'gib','VisionBank':'vision',
   'D360':'d360','Barq':'barq','EnjazPay':'enjazpay',
   'AlinmaPay':'alinmapay',
  };
  expect(identities.values.toSet(),
   WaffraSaudiFinancialProviders.all.map((p)=>p.id).toSet());
  for(final entry in identities.entries){
   expect(WaffraSmsAccountLearning.bankGroup(entry.key),entry.value,
    reason:'Sender suggestion only for catalog institution');
  }
 });
 test('M943 malicious or ambiguous snippets do not assign an institution',(){
  for(final sender in const [
   'notrajhi','notbarq','you-paid-alrajhi-order','random transfer',
   'ALINMAFAKE','bankuser','bank-alinma-payfake','cash',
   'تم تنشيط المستفيد في بنك الراجحي',
  ]){
   expect(WaffraSmsAccountLearning.bankGroup(sender),isNull,
    reason:'No substring guessing: $sender');
  }
 });
}
