import 'package:flutter/material.dart';
import 'waffra_auto_sms.dart';

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
 Future<void> allow()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  final allowed=await WaffraAutoSms.optIn();
  if(!mounted)return;
  if(allowed){await widget.onComplete();return;}
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
    Text(en?'Waffra can detect bank transactions as SMS arrive. '
     'Review the suggested income, expense, account and budget before saving.':
     'وفرة يكتشف الرسائل البنكية عند وصولها ويقترح الدخل والمصروف '
     'والحساب والميزانية. تراجع العملية قبل الحفظ.',
     textAlign:TextAlign.center),
    const SizedBox(height:14),
    Text(en?'Only qualifying financial SMS are kept in an encrypted '
     'on-device queue. Verification codes and personal messages are excluded. '
     'No SMS is uploaded or sent to a third-party AI service.':
     'يتم حفظ الرسائل المالية المطابقة فقط في قائمة مشفّرة على الهاتف. '
     'نستبعد رموز التحقق والرسائل الشخصية، ولا نرسل الرسائل إلى الإنترنت.',
     textAlign:TextAlign.center,
     style:Theme.of(context).textTheme.bodySmall),
    const Spacer(),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),
     child:Text(error!,textAlign:TextAlign.center,
      style:TextStyle(color:Theme.of(context).colorScheme.error))),
    FilledButton.icon(
     key:const Key('m417-permission-allow'),
     onPressed:busy?null:allow,
     icon:const Icon(Icons.mark_email_read_outlined),
     label:Text(en?'Allow access to bank SMS':'السماح بالوصول لرسائل البنوك'),
     style:FilledButton.styleFrom(minimumSize:const Size(double.infinity,56))),
    const SizedBox(height:8),
    TextButton(key:const Key('m417-permission-skip'),
     onPressed:busy?null:skip,child:Text(en?'Not now':'تخطي الآن')),
    if(busy)const LinearProgressIndicator(),
   ]))));
 }
}
