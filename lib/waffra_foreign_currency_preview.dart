import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'waffra_sms_fx_review.dart';
import 'waffra_sms_multicurrency_review.dart';

/// Only previews a live FX quote. The legacy production ledger MUST NOT
/// commit conversion without atomic encrypted provenance.
abstract final class WaffraForeignCurrencyPreview {
 static Future<WaffraSmsFxReview?> show(
   BuildContext context, {
   required double originalAmount,
   required String originalCurrency,
   required String targetCurrency,
   required bool english,
   Future<WaffraSmsFxQuote> Function(String source,String target)? fetchQuote,
 }) async {
  if (!WaffraSmsCurrencies.supported.contains(originalCurrency)||
      !WaffraSmsCurrencies.supported.contains(targetCurrency)||
      WaffraCurrencyMinor.exact(originalAmount,originalCurrency)==null||
      originalCurrency==targetCurrency) return null;
  WaffraSmsFxQuote quote;
  try {
   quote=await (fetchQuote==null
      ?WaffraSmsFxQuote.fetch(originalCurrency:originalCurrency,
          targetCurrency:targetCurrency)
      :fetchQuote(originalCurrency,targetCurrency));
  }catch(_){
   if(context.mounted)await showDialog<void>(context:context,
    builder:(dialog)=>AlertDialog(
     content:Text(english?'A verified rate is unavailable; nothing was saved.':
      'سعر الصرف الموثوق غير متاح حاليًا، ولم يتم حفظ أي معاملة.'),
     actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
      child:Text(english?'OK':'حسنًا'))]));
   return null;
  }
  if(!context.mounted)return null;
  // Do not construct an "approved" FX witness before the user acts.
  // Source rates can be daily rather than tick-by-tick: reject an old quote
  // and label the publication time instead of claiming an executable rate.
  final at=DateTime.now().toUtc();
  if(quote.sourceTimestampUtc.isAfter(at.add(const Duration(hours:1)))||
      at.difference(quote.sourceTimestampUtc)>const Duration(hours:72)){
   await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
    content:Text(english?
     'The published rate is too old to approve. Retry when an updated rate is available.':
     'سعر الصرف المنشور قديم ولا يمكن اعتماده. حاول عند توفر سعر أحدث.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
     child:Text(english?'OK':'حسنًا'))]));
   return null;
  }
  final sourceMinor=WaffraCurrencyMinor.exact(originalAmount,originalCurrency)!;
  final digits=WaffraCurrencyMinor.digits(targetCurrency);
  final minorFactor=math.pow(10,digits).toDouble();
  final convertedMinor=(WaffraCurrencyMinor.major(sourceMinor,originalCurrency)*
      quote.targetPerOriginal*minorFactor).round();
  if(convertedMinor<=0||convertedMinor>1000000000000)return null;
  final previewAmount=convertedMinor/minorFactor;
  final stamp=quote.sourceTimestampUtc.toUtc().toIso8601String()+' UTC';
  final accepted=await showDialog<bool>(context:context,
   builder:(dialog)=>AlertDialog(
    key:const Key('waffra-fx-consent-preview'),
    title:Text(english?'Foreign currency review':'مراجعة تحويل العملة'),
    content:SingleChildScrollView(child:Column(
     crossAxisAlignment:CrossAxisAlignment.stretch,
     mainAxisSize:MainAxisSize.min,children:[
      Text(english?'Original bank amount':'المبلغ الأصلي للرسالة'),
      SelectableText(originalAmount.toStringAsFixed(
       WaffraCurrencyMinor.digits(originalCurrency))+' '+originalCurrency),
      const SizedBox(height:10),
      Text(english?'Latest available exchange rate':'أحدث سعر صرف متاح'),
      SelectableText('1 '+originalCurrency+' = '+
       quote.targetPerOriginal.toStringAsPrecision(9)+' '+targetCurrency),
      Text((english?'Source: ':'المصدر: ')+quote.provider),
      Text((english?'Last published: ':'آخر تحديث: ')+stamp),
      const SizedBox(height:10),
      Text(english?'Estimated converted amount':'القيمة المتوقعة بعد التحويل'),
      SelectableText(previewAmount.toStringAsFixed(digits)+' '+targetCurrency),
      const SizedBox(height:12),
      Text(english?
       'Do you approve this quote? Rates are indicative. Converted transactions cannot be saved until their encrypted FX provenance is certified.':
       'هل توافق على سعر الصرف؟ السعر استرشادي. حفظ العمليات المحوّلة متوقف حتى اعتماد توثيق المبلغ الأصلي وسعر الصرف في السجل المشفّر.',
       style:const TextStyle(fontSize:12)),
     ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog,false),
      child:Text(english?'Not now':'ليس الآن')),
     FilledButton(key:const Key('waffra-fx-explicit-approval'),
      onPressed:()=>Navigator.pop(dialog,true),
      child:Text(english?'Approve preview':'الموافقة على المعاينة')),
    ],
   ));
  if(accepted!=true)return null;
  // Record the user's actual approval time, never the quote-screen open time.
  try{
   return WaffraSmsFxReview.approve(
    originalAmount:originalAmount,quote:quote,userConfirmed:true);
  }catch(_){return null;}
 }
}
