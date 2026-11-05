import 'package:flutter/material.dart';
import 'waffra_auto_sms.dart';
import 'waffra_sms_cloud_service.dart';

/// Follow-up to account creation: only Android's SMS and notification
/// permission dialogs, in that order. No cloud or classification choice.
/// Refusing either OS permission must not block account access.
class WaffraAutoSmsConsentPage extends StatefulWidget {
 const WaffraAutoSmsConsentPage({
  super.key,required this.english,required this.onComplete,
 });
 final bool english;
 final Future<void> Function() onComplete;
 @override State<WaffraAutoSmsConsentPage> createState()=>
  _WaffraAutoSmsConsentPageState();
}
class _WaffraAutoSmsConsentPageState extends State<WaffraAutoSmsConsentPage> {
 bool busy=false;
 String? error;
 @override void initState(){
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(mounted)_requestPermissions();
  });
 }

 Future<void> _requestPermissions()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   // Never opt in to the external AI on behalf of the user.
   await WaffraSmsCloudService.setConsent(false);
   // WaffraAutoSms.optIn first requests READ_SMS and RECEIVE_SMS; when
   // granted, it then requests Android notification permission.
   final smsAllowed=await WaffraAutoSms.optIn();
   if(!smsAllowed){
    // Declining SMS does not deny or skip notification permission.
    await WaffraAutoSms.requestNotificationPermission();
   }
   await widget.onComplete();
  }catch(_){
   if(mounted)setState(()=>error=widget.english?
    'Permission setup could not finish. Retry to continue securely.':
    'تعذر استكمال إعداد الأذونات. أعد المحاولة للمتابعة بأمان.');
  }finally{
   if(mounted)setState(()=>busy=false);
  }
 }

 @override Widget build(BuildContext context)=>Scaffold(
  body:SafeArea(child:Center(child:Padding(
   padding:const EdgeInsets.all(24),
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.verified_user_outlined,
     size:65,color:Color(0xFF087A54)),
    const SizedBox(height:18),
    Text(widget.english?'Set up Waffra permissions':'إعداد أذونات وفرة',
     style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
    const SizedBox(height:12),
    Text(widget.english?
     'Android will ask for bank SMS access, then notifications. '
     'Local SMS classification works without AI. You can change permissions later.':
     'أندرويد هيطلب إذن الرسائل البنكية، وبعده إذن الإشعارات. '
     'تحليل الرسائل محليًا من غير ذكاء اصطناعي سحابي. '
     'تقدر تغيّر الأذونات بعدين.',
     textAlign:TextAlign.center),
    const SizedBox(height:20),
    if(busy)const CircularProgressIndicator(),
    if(error!=null)...[
     Text(error!,textAlign:TextAlign.center,
      style:TextStyle(color:Theme.of(context).colorScheme.error)),
     const SizedBox(height:12),
     FilledButton(onPressed:_requestPermissions,
      child:Text(widget.english?'Retry':'إعادة المحاولة')),
    ],
   ]),
  ))),
 );
}
