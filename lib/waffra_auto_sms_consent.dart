import 'package:flutter/material.dart';
import 'waffra_auto_sms.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

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
   // M705: retire the exact old cloud consent locally without importing
   // any dormant network/AI module into the live permission route.
   if(Platform.isAndroid){
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove('waffra_cloud_sms_installation_consent_v2');
   }
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
    Text(widget.english?'Waffra permissions':'أذونات وفرة',
     style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
    const SizedBox(height:12),
    Text(widget.english?
     "We'll request SMS access to show financial messages that need review, "
     "then notification permission for important alerts. "
     "You can decline either permission or change it later in your device settings.":
     'هنطلب إذن الرسائل علشان نعرض العمليات المالية اللي تحتاج مراجعة، '
     'وبعده إذن الإشعارات علشان توصلك التنبيهات المهمة. '
     'تقدر ترفض الأذونات أو تغيّرها لاحقًا من إعدادات جهازك.',
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
