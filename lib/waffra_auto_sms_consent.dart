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
    Text(en?
     'Waffra reads bank messages with your permission and prepares transactions for review. '
     'Messages are encrypted on your device; no balance changes without your approval.':
     'وفرة يقرأ رسائلك البنكية بموافقتك ويجهّز المعاملات للمراجعة. '
     'الرسائل محفوظة مشفّرة، ومش هيتغير رصيدك إلا بموافقتك.',
     textAlign:TextAlign.center),
    const SizedBox(height:12),
    Text(en?
     'Automatic cloud analysis sends redacted financial data to an external service. '
     'SMS-only keeps analysis on your device.':
     'التحليل التلقائي يستخدم خدمة سحابية خارجية بعد إخفاء البيانات الحساسة. '
     'تقدر تختار قراءة الرسائل فقط بدون تحليل سحابي.',
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
     label:Text(en?'Allow SMS and automatic analysis':'السماح بالرسائل والتحليل تلقائيًا'),
     style:FilledButton.styleFrom(minimumSize:const Size(double.infinity,56))),
    const SizedBox(height:8),
    OutlinedButton.icon(
     key:const Key('m427-sms-local-only'),
     onPressed:busy?null:()=>allow(cloud:false),
     icon:const Icon(Icons.phone_android_outlined),
     label:Text(en?'Allow SMS only':
      'السماح بالرسائل فقط')),
    const SizedBox(height:8),
    TextButton(key:const Key('m417-permission-skip'),
     onPressed:busy?null:skip,child:Text(en?'Not now':'تخطي الآن')),
    if(busy)const LinearProgressIndicator(),
   ]))));
 }
}
