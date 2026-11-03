import 'package:flutter/material.dart';
import 'waffra_auto_sms.dart';
import 'waffra_sms_cloud_service.dart';

/// Presented once on the first foreground launch, before account screens.
/// The permission dialog is requested ONLY after the user chooses Allow.
class WaffraAutoSmsConsentPage extends StatefulWidget {
 const WaffraAutoSmsConsentPage({super.key,required this.english,
  required this.onComplete});
 final bool english;
 final Future<void> Function() onComplete;
 @override State<WaffraAutoSmsConsentPage> createState()=>
  _WaffraAutoSmsConsentPageState();
}
class _WaffraAutoSmsConsentPageState extends State<WaffraAutoSmsConsentPage> {
 bool busy=false;
 String? error;
 Future<void> allow({required bool cloud})async{
  if(busy)return;
  setState((){busy=true;error=null;});
  final allowed=await WaffraAutoSms.optIn();
  if(!mounted)return;
  if(allowed){
   final activated=await WaffraSmsCloudService.setConsent(cloud);
   if(cloud&&!activated){
    // Do not falsely claim third-party cloud processing is enabled.
    // SMS permission is already granted; user may choose local-only below.
    if(mounted)setState((){
     busy=false;
     error=widget.english?
      'Cloud analysis is unavailable. Choose SMS-only to continue.':
      'التحليل السحابي غير متاح حاليًا. اختر الرسائل فقط للمتابعة.';
    });
    return;
   }
   await widget.onComplete();return;
  }
  setState((){
   busy=false;
   error=widget.english?
    'Permission unavailable. Try again or continue manually.':
    'لم يتم السماح بالوصول. يمكنك المحاولة أو المتابعة يدويًا.';
  });
 }
 Future<void> skip()async{
  if(busy)return;
  setState(()=>busy=true);
  await WaffraSmsCloudService.setConsent(false);
  await widget.onComplete();
 }
 @override Widget build(BuildContext context){
  final en=widget.english;
  return Scaffold(body:SafeArea(child:Padding(
   padding:const EdgeInsets.all(22),
   child:Column(children:[
    const Spacer(),
    const Icon(Icons.sms_outlined,size:76,color:Color(0xFF087A54)),
    const SizedBox(height:24),
    Text(en?'Automatic bank SMS tracking':'تتبّع الرسائل البنكية تلقائيًا',
     textAlign:TextAlign.center,
     style:Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight:FontWeight.bold)),
    const SizedBox(height:18),
    Text(en?'Waffra queues bank SMS from the first day of the month you '
     'activate tracking and every new SMS. You must review and approve each '
     'transaction before it changes your balance.':
     'وفرة هيجمع الرسائل البنكية من أول يوم في شهر التفعيل وكمان الرسائل '
     'الجديدة ويحطها تحت عمليات تحتاج مراجعة. مش هيتسجل أي دخل أو '
     'مصروف تلقائيًا إلا بعد مراجعتك وتأكيدك.',
     textAlign:TextAlign.center),
    const SizedBox(height:14),
    Text(en?'Allowing bank SMS enables encrypted local review and private '
     'notification of new messages, not automatic financial posting. '
     'If you choose cloud analysis, eligible redacted SMS are analyzed '
     'automatically and the results await your confirmation. '
     'Bank messages stay encrypted on this device. This SMS permission '
     'does not send them to cloud AI unless you select cloud analysis. '
     'OpenRouter may process redacted financial data outside Saudi Arabia. '
     'OTPs and personal messages are excluded.':
     'بالموافقة تسمح لوفرة بتجميع الرسائل للمراجعة وإشعارك بالجديد '
     'بدون تسجيل تلقائي في رصيدك. عند اختيار التحليل السحابي، '
     'تُحلّل الرسائل المؤهلة تلقائيًا بعد حجب البيانات وتنتظر تأكيدك. '
     'الرسائل محفوظة مشفّرة على جهازك. صلاحية الرسائل '
     'لوحدها لا تسمح برفعها لخدمة سحابية؛ اختر الخيار السحابي للموافقة '
     'على إرسال البيانات المالية المحجوبة إلى OpenRouter وقد تتم معالجتها خارج السعودية. '
     'نستبعد رموز التحقق والرسائل الشخصية.',
     textAlign:TextAlign.center,
     style:Theme.of(context).textTheme.bodySmall),
    const Spacer(),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),
     child:Text(error!,textAlign:TextAlign.center,
      style:TextStyle(color:Theme.of(context).colorScheme.error))),
    FilledButton.icon(
     key:const Key('m417-permission-allow'),
     onPressed:busy?null:()=>allow(cloud:true),
     icon:const Icon(Icons.mark_email_read_outlined),
     label:Text(en?'Allow SMS and redacted cloud analysis':'السماح بالرسائل وتحليلها سحابيًا بعد حجب البيانات'),
     style:FilledButton.styleFrom(minimumSize:const Size(double.infinity,56))),
    const SizedBox(height:8),
    OutlinedButton.icon(
     key:const Key('m427-sms-local-only'),
     onPressed:busy?null:()=>allow(cloud:false),
     icon:const Icon(Icons.phone_android_outlined),
     label:Text(en?'Allow SMS only — keep data on this device':
      'السماح بالرسائل فقط — بدون تحليل سحابي')),
    const SizedBox(height:8),
    TextButton(key:const Key('m417-permission-skip'),
     onPressed:busy?null:skip,child:Text(en?'Not now':'تخطي الآن')),
    if(busy)const LinearProgressIndicator(),
   ]))));
 }
}
