part of 'main.dart';

/// M929 / Issue #633: byte-preserved Home method extraction; no financial writer change.
extension _WaffraHomeFxPreview on _HomeScreenState {
 // M643: Saudi FX posting stays disabled; retain non-posting preview for strict FX QA.
 // ignore: unused_element
 Future<void> _previewForeignBankCurrency(String raw)async {
  if(!WaffraSaudiRelease.bankSmsForeignCurrencyPreview){
   if(mounted)snack(context,waffraIsEnglish?
    'Non-SAR transactions cannot be saved in this Saudi release.':
    'العمليات بغير الريال غير مدعومة في النسخة السعودية الحالية.');
   return;
  }
  // No bank message contents, personal identifiers, photos or notes are
  // included in the FX network request: only original and target codes.
  final source=WaffraSmsCurrencies.originalAmount(raw);
  if(!mounted)return;
  if(source==null){
   snack(context,waffraIsEnglish?
    'Original currency or amount is uncertain. Check the bank message first.':
    'العملة أو المبلغ الأصلي غير مؤكد. راجع الرسالة البنكية أولًا.');
   return;
  }
  final target=WaffraDisplayCurrency.country.code;
  if(source.currency==target){
   snack(context,waffraIsEnglish?
    'Bank currency matches the app display currency. Encrypted foreign-currency saving is not enabled yet.':
    'عملة الرسالة مطابقة لعملة العرض. حفظ العملات الأجنبية المشفر غير مفعل بعد.');
   return;
  }
  snack(context,waffraIsEnglish?
   'Retrieving the latest available exchange rate…':
   'جاري جلب أحدث سعر صرف متاح…',isError:false);
  final approved=await WaffraForeignCurrencyPreview.show(context,
   originalAmount:source.amount,originalCurrency:source.currency,
   targetCurrency:target,english:waffraIsEnglish);
  if(approved!=null&&mounted){
   // Do not write an FX amount to the guarded legacy ledger. We can only
   // persist the conversion together with original currency + approved quote
   // in the atomically encrypted FX finance source after cutover approval.
   snack(context,waffraIsEnglish?
    'Conversion preview approved. No amount was saved; encrypted FX posting is not active.':
    'تمت الموافقة على معاينة التحويل فقط. لم يُحفظ أي مبلغ؛ تسجيل العملات المحوّلة ينتظر تفعيل التخزين المعتمد.');
  }
 }

}
