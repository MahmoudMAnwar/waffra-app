import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Local-only migration after user opened the existing legacy account.
/// Preserves financial journal, encrypted backups and old Google recovery.
class WaffraLocalAccountMigration extends StatefulWidget {
 const WaffraLocalAccountMigration({super.key,required this.english,
  required this.onConfirm});
 final bool english;
 final Future<void> Function(String phone,String password) onConfirm;
 @override State<WaffraLocalAccountMigration> createState()=>
  _WaffraLocalAccountMigrationState();
}
class _WaffraLocalAccountMigrationState
 extends State<WaffraLocalAccountMigration>{
 final phone=TextEditingController(),pass=TextEditingController(),
  confirm=TextEditingController();
 bool saving=false;
 String? error;
 @override void dispose(){
  phone.dispose();pass.dispose();confirm.dispose();super.dispose();
 }
 Future<void> migrate()async{
  if(saving)return;
  final number=phone.text.trim();
  if(!RegExp(r'^05[0-9]{8}$').hasMatch(number)||
    pass.text.length<8||pass.text.length>128||
    pass.text!=confirm.text){
   setState(()=>error=widget.english?
    'Enter a Saudi mobile and matching 8+ character passwords.':
    'أدخل رقم جوال سعودي وكلمة مرور ٨ خانات أو أكثر مع تأكيدها.');
   return;
  }
  setState((){saving=true;error=null;});
  try{
   await widget.onConfirm(number,pass.text);
   if(mounted)Navigator.pop(context);
  }catch(_){
   if(mounted)setState(()=>error=widget.english?
    'Migration stopped. Your existing data was not deleted.':
    'تعذر نقل الحساب. بياناتك السابقة لم تُحذف.');
  }finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.english?
   'Move existing account to mobile':'نقل حسابك القديم للجوال')),
  body:SafeArea(child:ListView(padding:const EdgeInsets.all(22),children:[
   Text(widget.english?
    'Keep the existing finance history on this device. Save an encrypted .waffra backup before updating. This mobile number is a local username, not an SMS-verified identity.':
    'بياناتك المالية القديمة ستظل على الجهاز. احفظ نسخة .waffra مشفرة قبل التحديث. رقم الجوال اسم مستخدم محلي فقط، بدون رسالة تحقق.'),
   const SizedBox(height:18),
   TextField(controller:phone,textDirection:TextDirection.ltr,
    keyboardType:TextInputType.phone,
    inputFormatters:[FilteringTextInputFormatter.digitsOnly,
     LengthLimitingTextInputFormatter(10)],
    decoration:InputDecoration(labelText:widget.english?
     'Saudi mobile number':'رقم الجوال السعودي',
     hintText:'05XXXXXXXX',border:const OutlineInputBorder())),
   const SizedBox(height:12),
   TextField(controller:pass,obscureText:true,
    decoration:InputDecoration(labelText:widget.english?
     'New local password':'كلمة المرور الجديدة',
     border:const OutlineInputBorder())),
   const SizedBox(height:12),
   TextField(controller:confirm,obscureText:true,
    decoration:InputDecoration(labelText:widget.english?
     'Confirm password':'تأكيد كلمة المرور',
     border:const OutlineInputBorder())),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:14),
    child:Text(error!,style:const TextStyle(color:Colors.red))),
   const SizedBox(height:20),
   FilledButton.icon(
    key:const Key('waffra-migrate-to-local-phone'),
    onPressed:saving?null:migrate,
    icon:const Icon(Icons.phonelink_lock),
    label:Text(saving?(widget.english?'Saving…':'جارٍ الحفظ…'):
     (widget.english?'Move without deleting data':'نقل الحساب بدون حذف البيانات'))),
  ])));
}
