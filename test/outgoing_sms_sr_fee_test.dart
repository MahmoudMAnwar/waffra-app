import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';
void main(){test('redacted owner outgoing SMS',(){
const sms='حوالة محلية صادرة بـSR 1900\nمن1111\nلـ2222;TEST RECIPIENT\nرسوم:SR 0.58\n26/11/1 08:46';
final f=WaffraBankSmsFactsParser.parse(sms);
final a=WaffraSmsCurrencies.originalAmount(sms);
expect(f.fee,0.58); expect(f.requiresBeneficiaryReview,isTrue); expect(f.canAutoPostAsIncomeExpense,isFalse);
expect(f.canOwnerConfirmAsIncomeExpense,isTrue);
expect(a?.amount,1900);expect(a?.currency,'SAR');
});
for(final fee in ['SR 0.581','USD 0.58','SR 0.58%']){
 test('reject unsafe fee $fee',(){
 final f=WaffraBankSmsFactsParser.parse('حوالة محلية صادرة بـSR 1900\nرسوم:$fee');
 expect(f.canOwnerConfirmAsIncomeExpense,isFalse);
 });
}
test('OTP stays blocked',(){
 final f=WaffraBankSmsFactsParser.parse('حوالة محلية صادرة بـSR 1900\nرسوم:SR 0.58\nرمز التحقق 123456');
 expect(f.canOwnerConfirmAsIncomeExpense,isFalse);
});}
