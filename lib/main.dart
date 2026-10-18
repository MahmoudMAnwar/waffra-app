import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_welcome_background.dart';
import 'currency_converter.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const WaffraApp()); }
const emerald=Color(0xFF087A54), forest=Color(0xFF064D3B), sand=Color(0xFFF8F6EF), gold=Color(0xFFD8BA78);
String formatMoney(num value) {
  final n=value.toDouble();
  if(n==n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'),'').replaceFirst(RegExp(r'\.$'),'');
}
String cash(num value)=>'${formatMoney(value)} ﷼';
String dayText(DateTime d)=>'${d.day}/${d.month}/${d.year}';
String digits(String s) {
  const a='٠١٢٣٤٥٦٧٨٩',p='۰۱۲۳۴۵۶۷۸۹';
  return s.replaceAllMapped(RegExp('[٠-٩۰-۹]'),(m){final c=m.group(0)!;final i=a.indexOf(c);return '${i>=0?i:p.indexOf(c)}';});
}
double? amountOf(String s) {
  var v=digits(s).replaceAll(' ','');
  if(v.contains('.')&&v.contains(','))v=v.replaceAll(',','');
  else if(RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(v))v=v.replaceAll(',','');
  else v=v.replaceAll(',','.');
  final n=double.tryParse(v);
  return n!=null&&n.isFinite&&n>0?n:null;
}
String newId()=>DateTime.now().microsecondsSinceEpoch.toString();

class RiyalAmount extends StatelessWidget {
 final num amount;final TextStyle? style;final String prefix;
 const RiyalAmount(this.amount,{super.key,this.style,this.prefix=''});
 @override Widget build(BuildContext context) {
  final effective=DefaultTextStyle.of(context).style.merge(style);
  final color=effective.color??Theme.of(context).colorScheme.onSurface;
  final size=effective.fontSize??16;
  return Row(mainAxisSize:MainAxisSize.min,textDirection:TextDirection.ltr,children:[
   Text('$prefix${formatMoney(amount)}',style:effective),const SizedBox(width:4),
   Image.asset('assets/Saudi_Riyal_Symbol-1.png',width:size*.9,height:size*.9,
    color:color,colorBlendMode:BlendMode.srcIn,
    errorBuilder:(_,__,___)=>Text('﷼',style:effective)),
  ]);
 }
}
class MoneyEntry {
 final String id,title,category;final double amount;final bool income;final DateTime date;
 final String? receiptPath;
 MoneyEntry({required this.id,required this.title,required this.category,required this.amount,required this.income,required this.date,this.receiptPath});
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'income':income,'date':date.toIso8601String(),'receiptPath':receiptPath};
 factory MoneyEntry.fromJson(Map<String,dynamic> j)=>MoneyEntry(id:'${j['id']??newId()}',title:'${j['title']??''}',category:'${j['category']??'أخرى'}',amount:(j['amount'] as num).toDouble(),income:j['income']==true,date:DateTime.tryParse('${j['date']}')??DateTime.now(),receiptPath:j['receiptPath']?.toString());
}
class Person {
 final String name,email,provider,gender,avatar;final DateTime birthday;
 Person({required this.name,required this.email,required this.provider,required this.gender,required this.avatar,required this.birthday});
 Map<String,dynamic> toJson()=>{'name':name,'email':email,'provider':provider,'gender':gender,'avatar':avatar,'birthday':birthday.toIso8601String()};
 factory Person.fromJson(Map<String,dynamic> j)=>Person(name:'${j['name']??''}',email:'${j['email']??''}',provider:'${j['provider']??'محلي'}',gender:'${j['gender']??'غير محدد'}',avatar:'${j['avatar']??'person'}',birthday:DateTime.tryParse('${j['birthday']}')??DateTime(2000));
}
class BudgetCategory {
 final String id,name,icon;final int color;final bool income;final double budget;final int alertPercent;
 BudgetCategory({required this.id,required this.name,required this.icon,required this.color,required this.income,this.budget=0,this.alertPercent=80});
 BudgetCategory copy({String? name,String? icon,int? color,double? budget,int? alertPercent})=>BudgetCategory(id:id,name:name??this.name,icon:icon??this.icon,color:color??this.color,income:income,budget:budget??this.budget,alertPercent:alertPercent??this.alertPercent);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'icon':icon,'color':color,'income':income,'budget':budget,'alertPercent':alertPercent};
 factory BudgetCategory.fromJson(Map<String,dynamic> j)=>BudgetCategory(id:'${j['id']??newId()}',name:'${j['name']??'أخرى'}',icon:'${j['icon']??'category'}',color:(j['color'] as num?)?.toInt()??0xFF087A54,income:j['income']==true,budget:(j['budget'] as num?)?.toDouble()??0,alertPercent:(j['alertPercent'] as num?)?.toInt()??80);
}
class SavingGoal {
 final String id,name;final double target,saved;
 SavingGoal({required this.id,required this.name,required this.target,required this.saved});
 SavingGoal copy({double? saved})=>SavingGoal(id:id,name:name,target:target,saved:saved??this.saved);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'target':target,'saved':saved};
 factory SavingGoal.fromJson(Map<String,dynamic> j)=>SavingGoal(id:'${j['id']??newId()}',name:'${j['name']??''}',target:(j['target'] as num).toDouble(),saved:(j['saved'] as num?)?.toDouble()??0);
}
class RecurringBill {
 final String id,title,category;final double amount;final bool income;final int day;
 RecurringBill({required this.id,required this.title,required this.category,required this.amount,required this.income,required this.day});
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'income':income,'day':day};
 factory RecurringBill.fromJson(Map<String,dynamic> j)=>RecurringBill(id:'${j['id']??newId()}',title:'${j['title']??''}',category:'${j['category']??'أخرى'}',amount:(j['amount'] as num).toDouble(),income:j['income']==true,day:(j['day'] as num?)?.toInt()??1);
}
const iconNames=['restaurant','shopping','car','receipt','health','transfer','salary','home','education','sport','gift','travel','coffee','category'];
IconData categoryIcon(String n) {
 switch(n) {
  case 'restaurant':return Icons.restaurant;case 'shopping':return Icons.shopping_bag;
  case 'car':return Icons.directions_car;case 'receipt':return Icons.receipt_long;
  case 'health':return Icons.local_hospital;case 'transfer':return Icons.swap_horiz;
  case 'salary':return Icons.payments;case 'home':return Icons.home;
  case 'education':return Icons.school;case 'sport':return Icons.fitness_center;
  case 'gift':return Icons.card_giftcard;case 'travel':return Icons.flight;
  case 'coffee':return Icons.local_cafe;default:return Icons.category;
 }
}
IconData avatarIcon(String s)=>s=='male'?Icons.face:s=='female'?Icons.face_3:s=='smile'?Icons.sentiment_very_satisfied:Icons.person;
Widget saudiAvatar(String gender,{double radius=25})=>CircleAvatar(radius:radius,backgroundColor:const Color(0xFFE5F1E9),backgroundImage:AssetImage(gender=='أنثى'||gender=='female'?'assets/avatar_saudi_female.png':'assets/avatar_saudi_male.png'));

const colors=[0xFF087A54,0xFFED7045,0xFF3867D6,0xFF9C56B8,0xFFDF9C24,0xFF008C9E,0xFFDA5079,0xFF687B42];
List<BudgetCategory> defaultCategories()=>[
 BudgetCategory(id:'food',name:'مطاعم وكافيهات',icon:'restaurant',color:colors[1],income:false),
 BudgetCategory(id:'shopping',name:'تسوّق',icon:'shopping',color:colors[3],income:false),
 BudgetCategory(id:'transport',name:'مواصلات',icon:'car',color:colors[2],income:false),
 BudgetCategory(id:'bills',name:'فواتير',icon:'receipt',color:colors[4],income:false),
 BudgetCategory(id:'health',name:'صحة',icon:'health',color:colors[6],income:false),
 BudgetCategory(id:'transfers',name:'تحويلات',icon:'transfer',color:colors[5],income:false),
 BudgetCategory(id:'housing',name:'سكن',icon:'home',color:colors[0],income:false),
 BudgetCategory(id:'other',name:'أخرى',icon:'category',color:colors[7],income:false),
 BudgetCategory(id:'salary',name:'راتب',icon:'salary',color:colors[0],income:true),
 BudgetCategory(id:'extra',name:'عمل إضافي',icon:'salary',color:colors[2],income:true),
 BudgetCategory(id:'other-income',name:'دخل آخر',icon:'category',color:colors[5],income:true),
];
class BankResult {
 final double? amount;final bool income;final String title,category;final String? suggestedCategory;
 BankResult(this.amount,this.income,this.title,this.category,this.suggestedCategory);
}
class BankParser {
 static BankResult parse(String original) {
  final s=digits(original).replaceAll('\u200f','').replaceAll('\u200e','').replaceAll('\u00a0',' ');
  final incoming=RegExp(r'حوال[ةه].{0,25}وارد|تحويل.{0,25}وارد|استلام.{0,25}حوال|credited|deposit|راتب|إيداع|ايداع',caseSensitive:false).hasMatch(s);
  final outgoing=RegExp(r'حوال[ةه].{0,25}صادر|تحويل.{0,25}صادر|شراء|نقاط\s*بيع|pos\b|مدى|سحب|خصم|دفع|فاتورة|purchase|debit\b',caseSensitive:false).hasMatch(s);
  final income=incoming&&!outgoing;
  const n=r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';
  const currency=r'(?:SR|SAR|ر\.?\s?س\.?|ريال(?:\s*سعودي)?|﷼|⃁)';
  final patterns=[RegExp('$currency\\s*[:：-]?\\s*$n',caseSensitive:false),RegExp('$n\\s*$currency',caseSensitive:false),RegExp('(?:المبلغ|مبلغ|بقيمة|بمبلغ|amount|amt)\\s*[:：-]?\\s*$n',caseSensitive:false)];
  double? value;
  for(final p in patterns){final m=p.firstMatch(s);if(m!=null){value=amountOf(m.group(1)??'');if(value!=null)break;}}
  var title=income?'مبلغ وارد':'عملية بنكية',cat=income?'دخل آخر':'أخرى';
  String? suggestion;
  if(RegExp(r'راتب|salary',caseSensitive:false).hasMatch(s)){title='راتب';cat='راتب';}
  else if(income){title='حوالة واردة';}
  else if(RegExp(r'شراء|pos\b|مدى|mada',caseSensitive:false).hasMatch(s)){title='شراء نقاط بيع';cat='تسوّق';}
  else if(RegExp(r'حوال[ةه]|تحويل').hasMatch(s)){title='حوالة صادرة';cat='تحويلات';}
  if(!income) {
   if(RegExp(r'مطعم|كافيه|قهوة|coffee|restaurant|برجر|بيتزا',caseSensitive:false).hasMatch(s))cat='مطاعم وكافيهات';
   else if(RegExp(r'بنزين|وقود|محطة|uber|careem|أوبر|كريم',caseSensitive:false).hasMatch(s))cat='مواصلات';
   else if(RegExp(r'فاتورة|كهرباء|مياه|stc|mobily|زين',caseSensitive:false).hasMatch(s))cat='فواتير';
   else if(RegExp(r'صيدلية|مستشفى|عيادة|pharmacy',caseSensitive:false).hasMatch(s))cat='صحة';
   else if(RegExp(r'إيجار|ايجار|rent',caseSensitive:false).hasMatch(s))cat='سكن';
   else if(RegExp(r'نادي|gym|fitness|رياضة',caseSensitive:false).hasMatch(s)){cat='رياضة ولياقة';suggestion=cat;}
   else if(RegExp(r'مدرسة|جامعة|تعليم',caseSensitive:false).hasMatch(s)){cat='تعليم';suggestion=cat;}
   else if(RegExp(r'سفر|طيران|فندق|hotel',caseSensitive:false).hasMatch(s)){cat='سفر';suggestion=cat;}
  }
  return BankResult(value,income,title,cat,suggestion);
 }
}
String bankSmsHash(String raw)=>sha256.convert(utf8.encode(digits(raw).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
List<String> splitBankMessages(String raw){
 final clean=raw.replaceAll('\r\n','\n').replaceAll('\u200f','').replaceAll('\u200e','').trim();
 if(clean.isEmpty)return [];
 // Bank SMS messages often start with a transaction heading, even without dates.
 final heading=RegExp(r'(?im)^\s*(?:شراء(?:\s+PoS)?|حوال[ةه]|تحويل|إيداع|ايداع|راتب|سحب|دفع|نقاط بيع|POS|Purchase|Debit|Credit)(?=\s|$|[:：])');
 final starts=heading.allMatches(clean).map((m)=>m.start).toList();
 if(starts.length>1){
  final result=<String>[];
  for(var i=0;i<starts.length;i++){
   final from=i==0?0:starts[i];
   final to=i+1<starts.length?starts[i+1]:clean.length;
   final part=clean.substring(from,to).trim();
   if(part.isNotEmpty)result.add(part);
  }
  return result;
 }
 final dateLine=RegExp(r'(?m)^\s*[0-9٠-٩]{1,2}[/\-][0-9٠-٩]{1,2}[/\-][0-9٠-٩]{2,4}\s+[0-9٠-٩]{1,2}:[0-9٠-٩]{2}\s*$');
 final dates=dateLine.allMatches(clean).toList();
 if(dates.length>1){
  final result=<String>[];var start=0;
  for(final d in dates){final part=clean.substring(start,d.end).trim();if(part.isNotEmpty)result.add(part);start=d.end;}
  final rest=clean.substring(start).trim();if(rest.isNotEmpty)result.add(rest);
  return result;
 }
 final separated=clean.split(RegExp(r'\n\s*\n+'));
 return separated.where((x)=>x.trim().isNotEmpty).map((x)=>x.trim()).toList();
}

class WaffraApp extends StatefulWidget {
 const WaffraApp({super.key});
 @override State<WaffraApp> createState()=>_WaffraAppState();
}
class _WaffraAppState extends State<WaffraApp> {
 bool loading=true,onboarded=false,dark=false,locked=false,showLogin=false;
 String? pinHash;Person? profile;
 @override void initState(){super.initState();load();}
 Future<void> load()async {
  final p=await SharedPreferences.getInstance();Person? u;
  try{final s=p.getString('waffra_profile');if(s!=null)u=Person.fromJson(Map<String,dynamic>.from(jsonDecode(s)));}catch(e){debugPrint('$e');}
  if(!mounted)return;
  setState((){
   onboarded=p.getBool('waffra_onboarding_completed')??false;dark=p.getBool('waffra_dark_mode')??false;
   profile=u;pinHash=p.getString('waffra_pin_sha256');locked=pinHash!=null;loading=false;
  });
 }
 Future<void> quickStart()async {
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_onboarding_completed',true);
  final u=profile??Person(name:'يا غالي',email:'',provider:'محلي',gender:'غير محدد',avatar:'person',birthday:DateTime(2000));
  await saveUser(u);
  if(mounted)setState((){onboarded=true;showLogin=false;});
 }
 Future<void> intro()async {
  final p=await SharedPreferences.getInstance();await p.setBool('waffra_onboarding_completed',true);
  if(mounted)setState((){onboarded=true;showLogin=true;});
 }
 Future<void> saveUser(Person u)async {
  final p=await SharedPreferences.getInstance();await p.setString('waffra_profile',jsonEncode(u.toJson()));
  if(mounted)setState((){profile=u;showLogin=false;});
 }
 Future<void> logout()async {
  final p=await SharedPreferences.getInstance();await p.remove('waffra_profile');
  if(mounted)setState((){profile=null;showLogin=true;locked=false;});
 }
 Future<void> setPin(String? value)async {
  final p=await SharedPreferences.getInstance();
  if(value==null){await p.remove('waffra_pin_sha256');if(mounted)setState((){pinHash=null;locked=false;});}
  else{final hash=sha256.convert(utf8.encode(value)).toString();await p.setString('waffra_pin_sha256',hash);if(mounted)setState((){pinHash=hash;locked=false;});}
 }
 Future<void> theme()async {
  final v=!dark,p=await SharedPreferences.getInstance();
  await p.setBool('waffra_dark_mode',v);if(mounted)setState(()=>dark=v);
 }
 @override Widget build(BuildContext context)=>MaterialApp(
  debugShowCheckedModeBanner:false,title:'وفرة | Waffra',locale:const Locale('ar','SA'),
  builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child??const SizedBox.shrink()),
  theme:ThemeData(useMaterial3:true,colorSchemeSeed:emerald,scaffoldBackgroundColor:sand,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.all(const IconThemeData(color:Colors.white))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),textTheme:GoogleFonts.tajawalTextTheme()),
  darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:emerald,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.all(const IconThemeData(color:Colors.white))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),textTheme:GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme)),
  themeMode:dark?ThemeMode.dark:ThemeMode.light,
  home:Directionality(textDirection:TextDirection.rtl,child:
   loading?const Scaffold(body:Center(child:CircularProgressIndicator())):
   locked?PinLockScreen(pinHash:pinHash!,onUnlock:()=>setState(()=>locked=false)):
   !onboarded?IntroScreen(onStart:quickStart,onLogin:intro):
   profile==null||showLogin?LoginScreen(onSave:saveUser):
   HomeScreen(profile:profile!,dark:dark,onTheme:theme,onLogout:logout,onProfile:saveUser,onSetPin:setPin,pinEnabled:pinHash!=null)));
}
class PinLockScreen extends StatefulWidget {
 final String pinHash;final VoidCallback onUnlock;
 const PinLockScreen({super.key,required this.pinHash,required this.onUnlock});
 @override State<PinLockScreen> createState()=>_PinLockScreenState();
}
class _PinLockScreenState extends State<PinLockScreen> {
 final pinController=TextEditingController();
 bool busy=false,biometricAvailable=false,checking=true,showPin=false;
 String error='';
 @override void initState(){super.initState();checkBiometrics();}
 Future<void> checkBiometrics()async {
  final available=await WaffraBiometrics.isAvailable();
  if(mounted)setState((){biometricAvailable=available;checking=false;});
 }
 Future<void> biometric()async {
  if(busy)return;
  if(!biometricAvailable){
   await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('البصمة غير متاحة'),
    content:const Text('تأكد من تسجيل بصمتك في إعدادات الهاتف، وبعدها افتح التطبيق مرة أخرى. يمكنك الدخول برمز PIN الآن.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('حسنًا'))]));
   return;
  }
  setState(()=>busy=true);
  // Android displays its own system biometric prompt, positioned by the OS.
  final success=await WaffraBiometrics.unlock();
  if(!mounted)return;
  setState(()=>busy=false);
  if(success){widget.onUnlock();}
  else{setState(()=>error='تعذّر التحقق بالبصمة. حاول مجددًا أو استخدم رمز PIN.');}
 }
 void verifyPin(){
  if(sha256.convert(utf8.encode(pinController.text.trim())).toString()==widget.pinHash){
   widget.onUnlock();
  }else{setState((){error='رمز PIN غير صحيح';pinController.clear();});}
 }
 @override void dispose(){pinController.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:forest,
  body:Stack(fit:StackFit.expand,children:[
   Image.asset('assets/waffra_lock_new.png',fit:BoxFit.cover),
   SafeArea(child:Center(child:
   SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:26,vertical:20),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     SizedBox(height:MediaQuery.of(context).size.height*.42),
     SizedBox(width:double.infinity,height:55,child:FilledButton.icon(
      onPressed:busy||checking?null:biometric,
      style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
      icon:const Icon(Icons.fingerprint,size:29),
      label:Text(checking?'جاري فحص البصمة...':'الدخول بالبصمة',
       style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)))),
     const SizedBox(height:14),
     SizedBox(width:double.infinity,height:53,child:OutlinedButton.icon(
      onPressed:busy?null:()=>setState((){showPin=!showPin;error='';}),
      style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
       side:const BorderSide(color:Colors.white70)),
      icon:const Icon(Icons.lock_outline),
      label:const Text('الدخول برمز PIN',style:TextStyle(fontSize:16)))),
     if(showPin)...[
      const SizedBox(height:18),
      TextField(controller:pinController,autofocus:true,obscureText:true,
       keyboardType:TextInputType.number,maxLength:8,textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.white,fontSize:20),
       decoration:const InputDecoration(labelText:'أدخل رمز PIN',
        labelStyle:TextStyle(color:Colors.white),counterStyle:TextStyle(color:Colors.white70),
        enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white70)),
        focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white))),
       onSubmitted:(_)=>verifyPin()),
      const SizedBox(height:8),
      SizedBox(width:double.infinity,child:FilledButton(
       onPressed:verifyPin,child:const Text('فتح التطبيق'))),
     ],
     if(error.isNotEmpty)...[
      const SizedBox(height:12),
      Text(error,textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.orangeAccent)),
     ],
    ]))))]));
}
class IntroScreen extends StatefulWidget {
 final Future<void> Function() onStart,onLogin;
 const IntroScreen({super.key,required this.onStart,required this.onLogin});
 @override State<IntroScreen> createState()=>_IntroScreenState();
}
class _IntroScreenState extends State<IntroScreen> {
 bool busy=false;
 Future<void> proceed(bool login)async {
  if(busy)return;setState(()=>busy=true);
  try{await(login?widget.onLogin():widget.onStart());}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:forest,
  body:Directionality(textDirection:TextDirection.rtl,child:Stack(fit:StackFit.expand,children:[
   Column(children:[
    Expanded(flex:82,child:SizedBox(width:double.infinity,child:Image.asset(
     'assets/waffra_welcome_integrated.png',fit:BoxFit.fill))),
    const Expanded(flex:18,child:ColoredBox(color:forest)),
   ]),
   SafeArea(child:Column(children:[
    const Spacer(),
    Padding(padding:const EdgeInsets.fromLTRB(24,0,24,20),child:Column(children:[
     SizedBox(width:double.infinity,height:54,child:FilledButton(
      onPressed:busy?null:()=>proceed(false),
      style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
      child:const Text('ابدأ الآن',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)))),
     const SizedBox(height:12),
     SizedBox(width:double.infinity,height:52,child:OutlinedButton(
      onPressed:busy?null:()=>proceed(true),
      style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white70)),
      child:const Text('لديك حساب؟ قم بتسجيل الدخول',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)))),
     const SizedBox(height:15),
     const Text('🔒 بياناتك المالية محفوظة على جهازك',
      style:TextStyle(color:Colors.white70,fontSize:12)),
    ])),
   ])),
  ])));
}

class LoginScreen extends StatefulWidget {
 final Future<void> Function(Person) onSave;
 const LoginScreen({super.key,required this.onSave});
 @override State<LoginScreen> createState()=>_LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
 String? provider;
 @override Widget build(BuildContext context)=>provider!=null?
  ProfileForm(provider:provider!,onSave:widget.onSave,onBack:()=>setState(()=>provider=null)):
  Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(
   padding:const EdgeInsets.all(28),child:Column(children:[
    const CircleAvatar(radius:54,backgroundColor:forest,child:Icon(Icons.account_balance_wallet,color:Colors.white,size:58)),
    const SizedBox(height:20),const Text('وفرة',style:TextStyle(fontSize:42,color:emerald,fontWeight:FontWeight.w900)),
    const SizedBox(height:12),const Text('هلا بك! جاهز ترتّب فلوسك؟',style:TextStyle(fontSize:19)),
    const SizedBox(height:30),
    SizedBox(width:double.infinity,height:52,child:OutlinedButton.icon(
     onPressed:()=>setState(()=>provider='Google'),icon:const Icon(Icons.g_mobiledata,size:32),
     label:const Text('المتابعة باستخدام Google'))),
    const SizedBox(height:12),
    SizedBox(width:double.infinity,height:52,child:FilledButton.icon(
     onPressed:()=>setState(()=>provider='Apple'),icon:const Icon(Icons.apple),
     label:const Text('المتابعة باستخدام Apple'))),
    const SizedBox(height:20),
    const Text('بياناتك محفوظة على جهازك. المتابعة هنا لإنشاء ملف شخصي محلي، وليست مصادقة فعلية مع Google أو Apple.',
     textAlign:TextAlign.center,style:TextStyle(color:Colors.grey,fontSize:12)),
   ])))));
}
class ProfileForm extends StatefulWidget {
 final String provider;final Person? initial;
 final Future<void> Function(Person) onSave;final VoidCallback? onBack;
 const ProfileForm({super.key,required this.provider,required this.onSave,this.initial,this.onBack});
 @override State<ProfileForm> createState()=>_ProfileFormState();
}
class _ProfileFormState extends State<ProfileForm> {
 late final TextEditingController name,email;
 late String gender,avatar;late DateTime birthday;bool busy=false;
 @override void initState(){super.initState();
  name=TextEditingController(text:widget.initial?.name??'');
  email=TextEditingController(text:widget.initial?.email??'');
  gender=widget.initial?.gender??'ذكر';avatar=widget.initial?.avatar??'person';
  birthday=widget.initial?.birthday??DateTime(2000);
 }
 @override void dispose(){name.dispose();email.dispose();super.dispose();}
 Future<void> save()async {
  if(name.text.trim().isEmpty||!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())){
   snack(context,'تأكد من الاسم والبريد الإلكتروني');return;
  }
  setState(()=>busy=true);
  await widget.onSave(Person(name:name.text.trim(),email:email.text.trim(),
   provider:widget.provider,gender:gender,avatar:avatar,birthday:birthday));
  if(!mounted)return;setState(()=>busy=false);
  if(widget.initial!=null)Navigator.pop(context);
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.initial==null?'كمّل بياناتك':'تعديل الحساب'),
   leading:widget.onBack==null?null:IconButton(onPressed:widget.onBack,icon:const Icon(Icons.arrow_back))),
  body:ListView(padding:const EdgeInsets.all(22),children:[
   Center(child:saudiAvatar(gender,radius:48)),
   const SizedBox(height:10),
   Wrap(alignment:WrapAlignment.center,spacing:12,children:['ذكر','أنثى']
    .map((a)=>ChoiceChip(label:Row(mainAxisSize:MainAxisSize.min,children:[saudiAvatar(a,radius:20),const SizedBox(width:6),Text(a)]),selected:gender==a,onSelected:(_)=>setState((){gender=a;avatar=a=='ذكر'?'male':'female';}))).toList()),
   const SizedBox(height:16),
   TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك',border:OutlineInputBorder())),
   const SizedBox(height:12),
   TextField(controller:email,keyboardType:TextInputType.emailAddress,
    decoration:const InputDecoration(labelText:'بريدك الإلكتروني',border:OutlineInputBorder())),
   const SizedBox(height:12),
   DropdownButtonFormField<String>(initialValue:gender,
    decoration:const InputDecoration(labelText:'الجنس',border:OutlineInputBorder()),
    items:['ذكر','أنثى','غير محدد'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
    onChanged:(v){if(v!=null)setState((){gender=v;avatar=v=='أنثى'?'female':'male';});}),
   const SizedBox(height:12),
   OutlinedButton.icon(onPressed:()async {
    final d=await showDatePicker(context:context,initialDate:birthday,firstDate:DateTime(1900),lastDate:DateTime.now());
    if(d!=null)setState(()=>birthday=d);
   },icon:const Icon(Icons.calendar_month),label:Text('تاريخ الميلاد: ${dayText(birthday)}')),
   const SizedBox(height:20),
   FilledButton(onPressed:busy?null:save,child:const Text('حفظ البيانات')),
  ]));
}
void disposeLater(List<TextEditingController> controllers){
 Future<void>.delayed(const Duration(milliseconds:700),(){for(final c in controllers){c.dispose();}});
}
void snack(BuildContext context,String text){
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
}

class HomeScreen extends StatefulWidget {
 final Person profile;final bool dark,pinEnabled;
 final Future<void> Function(String?) onSetPin;
 final VoidCallback onTheme;
 final Future<void> Function() onLogout;
 final Future<void> Function(Person) onProfile;
 const HomeScreen({super.key,required this.profile,required this.dark,required this.pinEnabled,
  required this.onSetPin,required this.onTheme,required this.onLogout,required this.onProfile});
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
 final smsHashes=<String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 int tab=0,year=DateTime.now().year,month=DateTime.now().month;
 String search='',typeFilter='الكل',categoryFilter='الكل',period='شهري';
 bool ready=false;
 @override void initState(){super.initState();load();}
 Future<void> load()async {
  final p=await SharedPreferences.getInstance();
  try{final raw=p.getString('entries');if(raw!=null)entries.addAll((jsonDecode(raw) as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('entries: $e');}
  try{final raw=p.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(jsonDecode(raw) as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('categories: $e');categories.addAll(defaultCategories());}
  try{final raw=p.getString('waffra_goals_v24');if(raw!=null)goals.addAll((jsonDecode(raw) as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('goals: $e');}
  try{final raw=p.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((jsonDecode(raw) as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('recurring: $e');}
  smsHashes.addAll(p.getStringList('waffra_sms_hashes_v1')??const []);
  if(categories.isEmpty)categories.addAll(defaultCategories());
  for(final e in entries){
   if(!categories.any((c)=>c.name==e.category&&c.income==e.income)){
    categories.add(BudgetCategory(id:newId(),name:e.category,icon:'category',color:colors[7],income:e.income));
   }
  }
  if(!mounted)return;setState(()=>ready=true);await applyRecurring();
 }
 Future<void> persist()async {
  final p=await SharedPreferences.getInstance();
  await Future.wait([
   p.setString('entries',jsonEncode(entries.map((e)=>e.toJson()).toList())),
   p.setString('waffra_categories_v24',jsonEncode(categories.map((e)=>e.toJson()).toList())),
   p.setString('waffra_goals_v24',jsonEncode(goals.map((e)=>e.toJson()).toList())),
   p.setString('waffra_recurring_v24',jsonEncode(recurring.map((e)=>e.toJson()).toList()))
  ]);
 }
 Future<void> applyRecurring()async {
  final now=DateTime.now();bool changed=false;
  for(final r in recurring){
   final d=r.day.clamp(1,DateTime(now.year,now.month+1,0).day);
   final due=DateTime(now.year,now.month,d);
   if(due.isAfter(now))continue;
   final id='rec_${r.id}_${now.year}_${now.month}';
   if(entries.any((e)=>e.id==id))continue;
   entries.add(MoneyEntry(id:id,title:r.title,category:r.category,amount:r.amount,income:r.income,date:due));
   changed=true;
  }
  if(changed){if(mounted)setState((){});await persist();}
 }
 double sum(Iterable<MoneyEntry> list,bool income)=>
  list.where((e)=>e.income==income).fold(0.0,(v,e)=>v+e.amount);
 BudgetCategory categoryFor(String name,bool income) {
  for(final c in categories){if(c.name==name&&c.income==income)return c;}
  return BudgetCategory(id:'fallback',name:name,icon:'category',color:colors[7],income:income);
 }
 List<BudgetCategory> forType(bool income)=>categories.where((c)=>c.income==income).toList();
 Future<bool?> confirm(String title,String body)=>showDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:Text(body),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد'))]));
Future<void> bulkSmsSheet()async {
 final pasted=TextEditingController();
 final description=TextEditingController();
 final amount=TextEditingController();
 var messages=<String>[];
 var index=0;
 var income=false;
 var category='أخرى';
 var parsed=false;
 var reviewing=false;
 Timer? pasteTimer;
 var busy=false;
 var savedCount=0;
 bool sheetActive=true;
 void disposeLater(){
  pasteTimer?.cancel();
  Future<void>.delayed(const Duration(milliseconds:500),(){
   pasted.dispose();description.dispose();amount.dispose();
  });
 }
 Future<void> prepare(int i,StateSetter update)async {
  final result=BankParser.parse(messages[i]);
  update((){
   index=i;income=result.income;
   category=categories.any((c)=>c.income==income&&c.name==result.category)?result.category:
    (forType(income).isNotEmpty?forType(income).first.name:'أخرى');
   description.text='${result.title} — ${messages[i].replaceAll(RegExp(r'\s+'),' ').trim()}';
   amount.text=result.amount==null?'':formatMoney(result.amount!);
  });
 }
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
  builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
   final available=forType(income);
   final total=messages.fold<double>(0,(sum,s)=>sum+(BankParser.parse(s).amount??0));
   return Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(ctx).viewInsets.bottom+24),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Text('إضافة رسائل بنكية',style:Theme.of(ctx).textTheme.titleLarge),
     const SizedBox(height:12),
     if(!reviewing)...[
      TextField(controller:pasted,minLines:5,maxLines:9,onChanged:(text){
       pasteTimer?.cancel();
       if(!sheetActive||!ctx.mounted)return;
       update((){parsed=false;messages=[];});
      },decoration:const InputDecoration(labelText:'الصق رسالة أو عدة رسائل بنكية',
       hintText:'الصق الرسائل كاملة، كل رسالة بتاريخها',border:OutlineInputBorder())),
      const SizedBox(height:12),
      FilledButton.icon(
       icon:const Icon(Icons.add_circle_outline),
       onPressed:(){
        FocusScope.of(ctx).unfocus();
        pasteTimer?.cancel();
        final raw=pasted.text.trim();
        if(raw.isEmpty){snack(ctx,'الصق رسالة بنكية أولاً');return;}
        final found=splitBankMessages(raw);
        if(found.isEmpty){snack(ctx,'لم يتم العثور على معاملات. راجع نص الرسالة');return;}
        update((){messages=found;parsed=true;});
       },
       label:const Text('تحليل الرسائل وإضافتها')),
      if(parsed)...[
       const SizedBox(height:10),
       Text(messages.length==1?'تم استخراج معاملة واحدة بنجاح':
        messages.length==2?'تم استخراج معاملتين بنجاح':
        'تم استخراج ${messages.length} معاملات بنجاح',
        style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
       const SizedBox(height:8),
       FilledButton.icon(icon:const Icon(Icons.check_circle_outline),
        onPressed:(){
         if(messages.isEmpty)return;
         update(()=>reviewing=true);
         prepare(0,update);
        },label:const Text('تأكيد والانتقال لإضافة المعاملات')),
      ],
      TextButton.icon(onPressed:(){
       pasteTimer?.cancel();pasted.clear();
       update((){parsed=false;messages=[];});
      },icon:const Icon(Icons.delete_outline),label:const Text('حذف النص بالكامل')),
     ]else...[
      TextButton.icon(onPressed:busy?null:(){
       update((){reviewing=false;parsed=false;messages=[];index=0;pasted.clear();description.clear();amount.clear();});
      },icon:const Icon(Icons.delete_outline),label:const Text('حذف النص بالكامل ولصق رسائل جديدة')),
      Text('الرسالة ${index+1} من ${messages.length} — إجمالي مبالغ الرسائل: ${cash(total)}',style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      Text('تم حفظ $savedCount من ${messages.length} رسائل. راجع كل رسالة وحدد قسمها قبل الحفظ.'),
      const SizedBox(height:12),
      InputDecorator(decoration:const InputDecoration(labelText:'نص الرسالة الحالية',border:OutlineInputBorder()),
       child:SelectableText(messages[index])),
      const SizedBox(height:12),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:Text('دخل')),
       ButtonSegment(value:false,label:Text('مصروف'))],selected:{income},onSelectionChanged:(v)=>update((){
        income=v.first;category=forType(income).isNotEmpty?forType(income).first.name:'أخرى';
       })),
      const SizedBox(height:12),
      TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'وصف الرسالة',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       decoration:const InputDecoration(labelText:'مبلغ هذه الرسالة بالريال',border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$index-$income'),initialValue:available.any((c)=>c.name==category)?category:(available.isNotEmpty?available.first.name:null),
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:Text(c.name))).toList(),
       decoration:const InputDecoration(labelText:'قسم هذه الرسالة',border:OutlineInputBorder()),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      const SizedBox(height:12),
      FilledButton(onPressed:busy?null:()async{
       final n=amountOf(amount.text);
       if(n==null||description.text.trim().isEmpty){snack(ctx,'راجع وصف الرسالة والمبلغ');return;}
       final hash=bankSmsHash(messages[index]);
       if(smsHashes.contains(hash)){
        final yes=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
         title:const Text('⚠️ رسالة مكررة'),content:const Text('هذي الرسالة سبق حفظها. ودّك تضيفها مرة ثانية؟'),
         actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('إضافة على أي حال'))]));
        if(yes!=true||!ctx.mounted)return;
       }
       update(()=>busy=true);
       final now=DateTime.now();
       final previous=sum(entries.where((e)=>!e.income&&e.category==category&&e.date.year==now.year&&e.date.month==now.month),false);
       final entry=MoneyEntry(id:newId(),title:description.text.trim(),category:category,amount:n,income:income,date:now);
       setState(()=>entries.insert(0,entry));
       smsHashes.add(hash);
       await persist();
       final prefs=await SharedPreferences.getInstance();
       await prefs.setStringList('waffra_sms_hashes_v1',smsHashes.toList());
       if(!ctx.mounted)return;
       await budgetAlert(entry,previous);
       if(!ctx.mounted)return;
       savedCount++;
       if(index+1>=messages.length){Navigator.pop(ctx);if(mounted)snack(context,'تم حفظ $savedCount عملية بنجاح');}
       else{await prepare(index+1,update);update(()=>busy=false);}
      },child:Text(index+1==messages.length?'إضافة المعاملة وحفظها':'إضافة المعاملة وحفظها ثم التالي')),
      if(index+1<messages.length)TextButton(onPressed:busy?null:()=>prepare(index+1,update),child:const Text('تخطي هذه الرسالة')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:busy?null:(){
       update((){reviewing=false;parsed=false;messages=[];index=0;savedCount=0;pasted.clear();description.clear();amount.clear();});
      },icon:const Icon(Icons.delete_forever_outlined),label:const Text('حذف النص بالكامل وإضافة رسائل أخرى')),
     ],
    ])));
  }));
 sheetActive=false;disposeLater();
}

 Future<void> entrySheet({MoneyEntry? initial,bool sms=false})async {
  final title=TextEditingController(text:initial?.title??'');
  final value=TextEditingController(text:initial==null?'':formatMoney(initial.amount));
  final message=TextEditingController();
  bool income=initial?.income??false,analyzing=false,hasParsed=false;
  String category=initial?.category??'أخرى';
  DateTime date=initial?.date??DateTime.now();
  String? suggestion,pendingHash,receiptPath=initial?.receiptPath;
  Timer? debounce;
  final result=await showModalBottomSheet<MoneyEntry>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,update){
    void parseNow(String text) {
     debounce?.cancel();
     if(text.trim().isEmpty){update((){hasParsed=false;analyzing=false;suggestion=null;});return;}
     update(()=>analyzing=true);
     debounce=Timer(const Duration(milliseconds:300),(){
      if(!sheetContext.mounted)return;
      final p=BankParser.parse(text);
      update((){
       income=p.income;
       category=p.suggestedCategory!=null&&categories.any((c)=>c.income==p.income&&c.name==p.suggestedCategory)
        ?p.suggestedCategory!:p.category;
       title.text=p.title;value.text=p.amount==null?'':formatMoney(p.amount!);
       suggestion=p.suggestedCategory!=null&&!categories.any((c)=>c.income==p.income&&c.name==p.suggestedCategory)
        ?p.suggestedCategory:null;
       hasParsed=true;analyzing=false;
      });
     });
    }
    final available=forType(income);
    final chosen=available.any((c)=>c.name==category)?category:(available.isEmpty?null:available.first.name);
    return Padding(padding:EdgeInsets.fromLTRB(18,10,18,MediaQuery.of(sheetContext).viewInsets.bottom+20),
     child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(initial!=null?'تعديل العملية':sms?'إضافة رسالة بنكية':'إضافة عملية',
       style:Theme.of(sheetContext).textTheme.titleLarge),
      const SizedBox(height:12),
      if(sms)...[
       TextField(controller:message,minLines:3,maxLines:6,onChanged:parseNow,
        decoration:const InputDecoration(labelText:'الصق الرسالة البنكية هنا',
         hintText:'أول ما تلصقها نحلّلها تلقائيًا',border:OutlineInputBorder())),
       const SizedBox(height:8),
       if(analyzing)const LinearProgressIndicator(),
       if(hasParsed)Text(value.text.isEmpty?'ما قدرنا نحدد المبلغ. اكتبه يدويًا.':
        'حلّلنا الرسالة. راجع التفاصيل قبل الحفظ.',style:const TextStyle(color:emerald)),
       const SizedBox(height:12),
      ],
      SegmentedButton<bool>(
       segments:const [ButtonSegment(value:true,label:Text('دخل')),
        ButtonSegment(value:false,label:Text('مصروف'))],
       selected:{income},onSelectionChanged:(v)=>update((){
        income=v.first;category=forType(income).isNotEmpty?forType(income).first.name:'أخرى';suggestion=null;
       })),
      const SizedBox(height:12),
      TextField(controller:title,decoration:const InputDecoration(labelText:'وصف العملية',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       decoration:const InputDecoration(labelText:'المبلغ بالريال',border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$income-$chosen'),initialValue:chosen,
       decoration:const InputDecoration(labelText:'القسم',border:OutlineInputBorder()),
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:Text(c.name))).toList(),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      if(suggestion!=null)TextButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income,suggested:suggestion);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update((){category=c.name;suggestion=null;});
       }
      },icon:const Icon(Icons.add),label:Text('إضافة قسم $suggestion')),
      OutlinedButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update(()=>category=c.name);
       }
      },icon:const Icon(Icons.add),label:const Text('قسم جديد')),
      OutlinedButton.icon(onPressed:()async {
       final d=await showDatePicker(context:sheetContext,initialDate:date,
        firstDate:DateTime(2000),lastDate:DateTime.now());
       if(d!=null)update(()=>date=d);
      },icon:const Icon(Icons.calendar_month),label:Text(dayText(date))),
      const SizedBox(height:12),
      Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final file=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:80);
        if(file!=null){final path=await saveReceipt(file);if(sheetContext.mounted)update(()=>receiptPath=path);}
       },icon:const Icon(Icons.camera_alt_outlined),label:const Text('تصوير فاتورة'))),
       const SizedBox(width:8),
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80);
        if(file!=null){final path=await saveReceipt(file);if(sheetContext.mounted)update(()=>receiptPath=path);}
       },icon:const Icon(Icons.attach_file),label:const Text('إرفاق صورة'))),
      ]),
      if(receiptPath!=null)ListTile(
       title:Text(receiptPath!.split('/').last.replaceFirst(RegExp(r'^\d+__'),'')),leading:const Icon(Icons.image,color:emerald),
       trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>update(()=>receiptPath=null)),
       onTap:()=>showReceipt(receiptPath!)),
      const SizedBox(height:12),
      FilledButton(onPressed:analyzing?null:()async {
       final n=amountOf(value.text);
       if(title.text.trim().isEmpty||n==null){snack(context,'تأكد من الوصف والمبلغ');return;}
       if(sms){
        if(message.text.trim().isEmpty){snack(context,'الصق الرسالة البنكية أولًا');return;}
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){
         final proceed=await showDialog<bool>(context:sheetContext,builder:(dialogContext)=>AlertDialog(
          title:const Text('⚠️ الرسالة مكررة'),
          content:const Text('هذي الرسالة البنكية أضفتها قبل كذا. ودّك تضيفها مرة ثانية؟'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('إلغاء')),
           FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('إضافة على أي حال'))]));
         if(proceed!=true||!sheetContext.mounted)return;
        }
        pendingHash=h;
       }
       Navigator.pop(sheetContext,MoneyEntry(id:initial?.id??newId(),title:title.text.trim(),
        category:category,amount:n,income:income,date:date,receiptPath:receiptPath));
      },child:const Text('تأكيد وحفظ العملية')),
     ])));
   }));
  debounce?.cancel();disposeLater([title,value,message]);
  if(result==null||!mounted)return;
  if(initial==null&&!sms&&entries.any((e)=>
    e.income==result.income&&e.amount==result.amount&&
    e.title.trim().toLowerCase()==result.title.trim().toLowerCase()&&
    e.category==result.category&&e.date.year==result.date.year&&
    e.date.month==result.date.month&&e.date.day==result.date.day)){
   final proceed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('⚠️ عملية مكررة'),
    content:Text('يبدو إنك أضفت نفس ${result.income?'الدخل':'المصروف'} من قبل. ودّك تضيفه مرة ثانية؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إضافة على أي حال'))]));
   if(proceed!=true||!mounted)return;
  }
  final previousSpent=sum(entries.where((e)=>!e.income&&e.id!=result.id&&
   e.category==result.category&&e.date.year==result.date.year&&e.date.month==result.date.month),false);
  setState((){
   final i=entries.indexWhere((e)=>e.id==result.id);
   if(i>=0)entries[i]=result;else entries.insert(0,result);
  });
  await persist();
  if(pendingHash!=null){
   smsHashes.add(pendingHash!);
   final p=await SharedPreferences.getInstance();
   await p.setStringList('waffra_sms_hashes_v1',smsHashes.toList());
  }
  if(mounted)await budgetAlert(result,previousSpent);
 }
 Future<String> saveReceipt(XFile picked)async {
  final directory=Directory('${(await getApplicationDocumentsDirectory()).path}/receipts');
  if(!await directory.exists())await directory.create(recursive:true);
  final ext=picked.path.toLowerCase().endsWith('.png')?'png':'jpg';
  final original=picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.\u0600-\u06FF ]'),'_');
  final target='${directory.path}/${newId()}__$original';
  await File(picked.path).copy(target);
  return target;
 }
 Future<void> showReceipt(String path)async {
  if(!await File(path).exists()){
   if(mounted)snack(context,'ما لقينا الصورة على الجهاز');return;
  }
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(ctx)=>Dialog(child:Column(mainAxisSize:MainAxisSize.min,children:[
   SizedBox(height:MediaQuery.of(ctx).size.height*.65,width:MediaQuery.of(ctx).size.width*.85,
    child:InteractiveViewer(child:Image.file(File(path),fit:BoxFit.contain))),
   TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),
  ])));
 }
 Future<void> budgetAlert(MoneyEntry entry,double previousSpent)async {
  if(entry.income)return;
  final c=categoryFor(entry.category,false);
  if(c.budget<=0)return;
  final threshold=c.budget*c.alertPercent/100;
  final spent=sum(entries.where((e)=>!e.income&&e.category==entry.category&&
   e.date.year==entry.date.year&&e.date.month==entry.date.month),false);
  if(previousSpent>=threshold||spent<threshold||!mounted)return;
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('⚠️ ميزانية القسم أوشكت على الانتهاء'),
   content:Text('وصل صرف قسم «${c.name}» إلى ${formatMoney(spent/c.budget*100)}٪ من الميزانية. صرفت ${cash(spent)} من ${cash(c.budget)}، وحد التنبيه اللي اخترته ${c.alertPercent}٪.'),
   actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('حسنًا'))]));
 }
 String expensePieSvg(Map<String,double> totals){
  final values=totals.values.where((v)=>v>0).toList();
  final total=values.fold<double>(0,(a,b)=>a+b);
  const colors=['#006B5B','#E8AF47','#F08B64','#4D98A3','#9075B8','#9EBF70'];
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">');
  if(total==0)return '${out}</svg>';
  var angle=-pi/2;
  for(var i=0;i<values.length;i++){
   final sweep=2*pi*values[i]/total;
   final points=<String>['100,100'];
   final steps=max(2,(sweep*50).ceil());
   for(var j=0;j<=steps;j++){
    final a=angle+sweep*j/steps;
    points.add('${(100+88*cos(a)).toStringAsFixed(2)},${(100+88*sin(a)).toStringAsFixed(2)}');
   }
   out.write('<polygon points="${points.join(' ')}" fill="${colors[i%colors.length]}" stroke="white" stroke-width="1"/>');
   angle+=sweep;
  }
  out.write('</svg>');
  return out.toString();
 }
 Future<void> exportEntriesPdf(List<MoneyEntry> items,String title,{bool analytics=false})async {
  if(items.isEmpty){
   if(mounted)snack(context,analytics
    ?'لا يمكن تصدير تقرير التحليلات. أضف عملية دخل أو مصروف أولاً.'
    :'لا يمكن تصدير التقرير. يجب إضافة عملية دخل أو مصروف أولاً.');
   return;
  }
  try{
   final font=await PdfGoogleFonts.tajawalRegular();
   final bold=await PdfGoogleFonts.tajawalBold();
   final templateBytes=(await rootBundle.load('assets/waffra_report_template.png')).buffer.asUint8List();
   final template=img.decodeImage(templateBytes);
   if(template==null)throw StateError('تعذر قراءة صورة التقرير');
   final headerArt=pw.MemoryImage(Uint8List.fromList(img.encodePng(img.copyCrop(template,
    x:0,y:0,width:template.width,height:(template.height*0.54).round()))));
   final footerArt=pw.MemoryImage(Uint8List.fromList(img.encodePng(img.copyCrop(template,
    x:0,y:(template.height*0.75).round(),width:template.width,
    height:template.height-(template.height*0.75).round()))));
   final doc=pw.Document();
   final totalIncome=sum(items,true),totalExpenses=sum(items,false);
   final categoryTotals=<String,double>{};
   for(final e in items.where((e)=>!e.income)){categoryTotals[e.category]=(categoryTotals[e.category]??0)+e.amount;}
   pw.Widget summary(String label,double value,PdfColor bg)=>pw.Expanded(child:pw.Container(
    padding:const pw.EdgeInsets.all(10),decoration:pw.BoxDecoration(color:bg,borderRadius:pw.BorderRadius.circular(7)),
    child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
     pw.Text(label,style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.teal900)),
     pw.SizedBox(height:5),pw.Text('${formatMoney(value)} SAR',style:pw.TextStyle(font:bold,fontSize:15,color:PdfColors.teal900)),
    ])));
   doc.addPage(pw.MultiPage(
    pageTheme:pw.PageTheme(
     pageFormat:PdfPageFormat.a4,
     margin:const pw.EdgeInsets.fromLTRB(26,225,26,112),
     buildBackground:(ctx)=>pw.FullPage(ignoreMargins:true,child:pw.Stack(children:[
      pw.Positioned(top:0,left:0,right:0,child:pw.SizedBox(height:210,child:pw.Image(headerArt,fit:pw.BoxFit.fill))),
      pw.Positioned(top:28,right:12,child:pw.SizedBox(width:245,height:94,
       child:pw.Container(padding:const pw.EdgeInsets.all(10),
        child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.end,children:[
         pw.Text(analytics?'تقرير التحليلات':'تقرير الدخل والمصروفات',
          style:pw.TextStyle(font:bold,fontSize:18,color:PdfColors.white)),
         pw.Text(title,style:pw.TextStyle(font:font,fontSize:10,color:PdfColors.white)),
        ])))) ,
      pw.Positioned(bottom:0,left:0,right:0,child:pw.SizedBox(height:95,child:pw.Image(footerArt,fit:pw.BoxFit.fill))),
      pw.Positioned(bottom:20,right:12,child:pw.SizedBox(width:115,height:22,
       child:pw.Container(alignment:pw.Alignment.center,
        child:pw.Text(dayText(DateTime.now()),style:pw.TextStyle(font:font,fontSize:10,color:PdfColors.white))))) ,
     ])),
     theme:pw.ThemeData.withFont(base:font,bold:bold),
     textDirection:pw.TextDirection.rtl,
    ),
    footer:(ctx)=>pw.Align(alignment:pw.Alignment.centerRight,
      child:pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.teal900))),
    build:(ctx)=>[
     pw.Row(children:[summary('إجمالي الدخل',totalIncome,PdfColors.green50),pw.SizedBox(width:8),
      summary('إجمالي المصروفات',totalExpenses,PdfColors.red50),pw.SizedBox(width:8),
      summary('الصافي',totalIncome-totalExpenses,PdfColors.amber50)]),
     pw.SizedBox(height:16),
     if(analytics)...[
      pw.Text('الدخل والمصروفات حسب الفترة',style:pw.TextStyle(font:bold,fontSize:13,color:PdfColors.teal900)),
      pw.SizedBox(height:8),
      ...List.generate(title.contains('سنوي')?12:5,(i){
       final group=items.where((e)=>title.contains('سنوي')?e.date.month==i+1:((e.date.day-1)~/7)==i).toList();
       final inc=sum(group,true),exp=sum(group,false);
       final maxValue=[totalIncome,totalExpenses,1.0].reduce((a,b)=>a>b?a:b);
       pw.Widget bar(double value,PdfColor color)=>pw.Expanded(child:pw.Container(
        height:9,alignment:pw.Alignment.centerLeft,child:pw.Row(children:[
         pw.Expanded(flex:((value/maxValue*100).round()).clamp(1,100),
          child:pw.Container(height:9,color:color)),
         pw.Expanded(flex:(100-((value/maxValue*100).round()).clamp(1,100)).clamp(1,100),
          child:pw.SizedBox(height:9)),
        ])));
       return pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:4),
        child:pw.Row(children:[
         pw.SizedBox(width:42,child:pw.Text(title.contains('سنوي')?'${i+1}':'أ${i+1}',style:pw.TextStyle(font:font,fontSize:9))),
         pw.Expanded(child:pw.Column(children:[
          pw.Row(children:[pw.SizedBox(width:35,child:pw.Text('دخل',style:pw.TextStyle(font:font,fontSize:8))),bar(inc,PdfColors.teal),pw.SizedBox(width:48,child:pw.Text(formatMoney(inc),style:pw.TextStyle(font:font,fontSize:8)))]),
          pw.SizedBox(height:3),
          pw.Row(children:[pw.SizedBox(width:35,child:pw.Text('صرف',style:pw.TextStyle(font:font,fontSize:8))),bar(exp,PdfColors.deepOrange),pw.SizedBox(width:48,child:pw.Text(formatMoney(exp),style:pw.TextStyle(font:font,fontSize:8)))]),
         ])),
        ]));
      }),
      pw.SizedBox(height:12),
      pw.Text('جدول الدخل والمصروفات حسب الفترة',style:pw.TextStyle(font:bold,fontSize:11,color:PdfColors.teal900)),
      pw.SizedBox(height:6),
      pw.TableHelper.fromTextArray(
       headers:['الفترة','الدخل (ريال)','المصروفات (ريال)','الصافي (ريال)'],
       data:List.generate(title.contains('سنوي')?12:5,(i){
        final group=items.where((e)=>title.contains('سنوي')?e.date.month==i+1:((e.date.day-1)~/7)==i).toList();
        final inc=sum(group,true),exp=sum(group,false);
        return [title.contains('سنوي')?'شهر ${i+1}':'أسبوع ${i+1}',formatMoney(inc),formatMoney(exp),formatMoney(inc-exp)];
       }),
       headerDecoration:const pw.BoxDecoration(color:PdfColors.teal800),
       headerStyle:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.white),
       cellStyle:pw.TextStyle(font:font,fontSize:8),
       cellAlignment:pw.Alignment.center,cellPadding:const pw.EdgeInsets.all(5)),
      pw.SizedBox(height:12),
     ],
     pw.Text('توزيع المصروفات حسب الفئات',style:pw.TextStyle(font:bold,fontSize:13,color:PdfColors.teal900)),
     if(analytics&&totalExpenses>0)...[
      pw.SizedBox(height:10),
      pw.Center(child:pw.SvgImage(svg:expensePieSvg(categoryTotals),width:170,height:170)),
     ],
     pw.SizedBox(height:8),
     if(analytics)pw.TableHelper.fromTextArray(
      headers:['الفئة','المبلغ (ريال)','النسبة من المصروفات'],
      data:(categoryTotals.entries.toList()..sort((a,b)=>b.value.compareTo(a.value)))
       .map((e)=>[e.key,formatMoney(e.value),
        totalExpenses>0?'${(e.value/totalExpenses*100).toStringAsFixed(1)}%':'0%']).toList(),
      headerDecoration:const pw.BoxDecoration(color:PdfColors.teal800),
      headerStyle:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.white),
      cellStyle:pw.TextStyle(font:font,fontSize:8),
      cellAlignment:pw.Alignment.centerRight,cellPadding:const pw.EdgeInsets.all(5)),
     if(!analytics)...((categoryTotals.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).map((e)=>pw.Padding(
      padding:const pw.EdgeInsets.symmetric(vertical:3),child:pw.Row(children:[
       pw.Expanded(child:pw.Text(e.key,style:pw.TextStyle(font:font,fontSize:10))),
       pw.Text('${formatMoney(e.value)} SAR',style:pw.TextStyle(font:bold,fontSize:10))])))),
     pw.SizedBox(height:14),
     if(!analytics)pw.Text('تفاصيل العمليات',style:pw.TextStyle(font:bold,fontSize:13,color:PdfColors.teal900)),
     if(!analytics)pw.SizedBox(height:8),
     if(!analytics)pw.TableHelper.fromTextArray(headers:['التاريخ','النوع','القسم','الوصف','المبلغ (ريال)'],
      data:items.map((e)=>[dayText(e.date),e.income?'دخل':'مصروف',e.category,e.title,formatMoney(e.amount)]).toList(),
      headerDecoration:const pw.BoxDecoration(color:PdfColors.teal800),
      headerStyle:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.white),
      cellStyle:pw.TextStyle(font:font,fontSize:8),cellAlignment:pw.Alignment.centerRight,
      cellPadding:const pw.EdgeInsets.all(6)),
    ]));
   final bytes=await doc.save();
   // Android print dialog can be unavailable on some devices; share the PDF as fallback.
   await Printing.sharePdf(bytes:bytes,filename:'waffra_report.pdf');
  }catch(e,st){debugPrint('PDF export error: $e\n$st');if(mounted)snack(context,'تعذّر إنشاء PDF: $e');}
 }
 Future<void> deleteEntry(MoneyEntry e)async {
  final yes=await confirm('حذف العملية','ودّك تحذف «${e.title}»؟');
  if(yes!=true||!mounted)return;
  setState(()=>entries.removeWhere((x)=>x.id==e.id));await persist();
 }
 Widget stat(String label,double value,IconData icon,Color color)=>Expanded(
  child:Card(child:Padding(padding:const EdgeInsets.all(12),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:color),const SizedBox(height:8),Text(label),const SizedBox(height:6),
    FittedBox(child:RiyalAmount(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
   ]))));
 Widget tile(MoneyEntry e){
  final c=categoryFor(e.category,e.income);
  return Card(child:ListTile(
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
    child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:Text(e.title),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    Text('${e.category} • ${dayText(e.date)}'),
    if(e.receiptPath!=null)InkWell(onTap:()=>showReceipt(e.receiptPath!),
     child:const Padding(padding:EdgeInsets.only(top:4),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.attach_file,size:15,color:emerald),Text('عرض الفاتورة',style:TextStyle(color:emerald))]))),
   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    RiyalAmount(e.amount,prefix:e.income?'+':'-',style:TextStyle(fontWeight:FontWeight.bold,color:e.income?emerald:null)),
    PopupMenuButton<String>(onSelected:(v){
     if(v=='edit')entrySheet(initial:e);else deleteEntry(e);
    },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),
     PopupMenuItem(value:'delete',child:Text('حذف'))]),
   ])));
 }
 String get greeting {
  final name=widget.profile.name.trim();
  if(name=='يا غالي'||name.isEmpty)return 'يا هلا وغلا 👋';
  final female=widget.profile.gender=='أنثى'||widget.profile.gender.toLowerCase()=='female';
  return '${female?'يا هلا وغلا ونورتي':'يا هلا وغلا ونورت'} يا $name 👋';
 }
 Widget dashboard(){
  final inc=sum(entries,true),exp=sum(entries,false);
  final visible=entries.where((e){
   final q=search.trim().toLowerCase();
   return(e.title.toLowerCase().contains(q)||e.category.toLowerCase().contains(q))&&
    (typeFilter=='الكل'||(typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income))&&
    (categoryFilter=='الكل'||categoryFilter==e.category);
  }).toList()..sort((a,b)=>b.date.compareTo(a.date));
  final filterCats=<String>{'الكل',...entries.where((e)=>typeFilter=='الكل'||
   (typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income)).map((e)=>e.category)}.toList();
  final selected=filterCats.contains(categoryFilter)?categoryFilter:'الكل';
  return ListView(padding:const EdgeInsets.all(16),children:[
   Text(greeting,style:Theme.of(context).textTheme.titleLarge),
   const SizedBox(height:12),
   Container(padding:const EdgeInsets.all(24),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[forest,emerald]),borderRadius:BorderRadius.circular(24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('رصيدك الحالي',style:TextStyle(color:Colors.white70)),const SizedBox(height:10),
     RiyalAmount(inc-exp,style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),
     const SizedBox(height:8),
     const Text('كل ريال تحسب له حساب',style:TextStyle(color:Colors.white70)),
    ])),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,emerald),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   const SizedBox(height:10),
   OutlinedButton.icon(onPressed:bulkSmsSheet,icon:const Icon(Icons.content_paste),label:const Text('الصق رسالة بنكية')),
   const SizedBox(height:12),
   Text('عملياتك المالية',style:Theme.of(context).textTheme.titleLarge),
   const SizedBox(height:12),
   TextField(onChanged:(v)=>setState(()=>search=v),
    decoration:const InputDecoration(labelText:'دوّر على عملية',prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
   const SizedBox(height:10),
   Wrap(spacing:8,children:['الكل','الدخل','المصروفات'].map((x)=>ChoiceChip(
    label:Text(x),selected:typeFilter==x,
    onSelected:(_)=>setState((){typeFilter=x;categoryFilter='الكل';}))).toList()),
   DropdownButtonFormField<String>(key:ValueKey('$typeFilter-$selected'),initialValue:selected,
    decoration:const InputDecoration(labelText:'تصفية حسب القسم'),
    items:filterCats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
    onChanged:(x)=>setState(()=>categoryFilter=x??'الكل')),
   const SizedBox(height:10),
   OutlinedButton.icon(onPressed:()=>exportEntriesPdf(visible,'تقرير عمليات وفرة'),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('تصدير النتائج إلى PDF')),
   const SizedBox(height:8),
   Text('عدد العمليات: ${visible.length}'),
   if(visible.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('ما عندك عمليات مطابقة'))),
   ...visible.map(tile),const SizedBox(height:90),
  ]);
 }
 List<MoneyEntry> get analysisEntries=>entries.where((e)=>e.date.year==year&&
  (period=='سنوي'||e.date.month==month)).toList();
 Widget analytics(){
  final data=analysisEntries,inc=sum(data,true),exp=sum(data,false);
  final years=<int>{DateTime.now().year,year,...entries.map((e)=>e.date.year)}.toList()..sort((a,b)=>b.compareTo(a));
  final points=period=='شهري'?List.generate(5,(i){
   final v=data.where((e)=>(e.date.day-1)~/7==i);
   return ChartPoint('أ${i+1}',sum(v,true),sum(v,false));
  }):List.generate(12,(i){
   final v=data.where((e)=>e.date.month==i+1);
   return ChartPoint('${i+1}',sum(v,true),sum(v,false));
  });
  final breakdown=<String,double>{};
  for(final e in data.where((e)=>!e.income)){breakdown[e.category]=(breakdown[e.category]??0)+e.amount;}
  return ListView(padding:const EdgeInsets.all(16),children:[
   Text('تحليلاتك المالية',style:Theme.of(context).textTheme.titleLarge),
   const SizedBox(height:12),
   SegmentedButton<String>(segments:const [ButtonSegment(value:'شهري',label:Text('شهري')),
    ButtonSegment(value:'سنوي',label:Text('سنوي'))],
    selected:{period},onSelectionChanged:(v)=>setState(()=>period=v.first)),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:DropdownButtonFormField<int>(initialValue:year,
     decoration:const InputDecoration(labelText:'السنة'),
     items:years.map((x)=>DropdownMenuItem(value:x,child:Text('$x'))).toList(),
     onChanged:(v){if(v!=null)setState(()=>year=v);})),
    if(period=='شهري')Expanded(child:DropdownButtonFormField<int>(initialValue:month,
     decoration:const InputDecoration(labelText:'الشهر'),
     items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:Text('شهر ${i+1}'))),
     onChanged:(v){if(v!=null)setState(()=>month=v);})),
   ]),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,emerald),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
    const Text('الدخل مقابل المصروفات',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:16),FinanceChart(points:points),
   ]))),
   const SizedBox(height:16),
   OutlinedButton.icon(onPressed:()=>exportEntriesPdf(data,'تحليلات وفرة - $period ${period=='شهري'?'$month/':''}$year',analytics:true),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('تصدير التحليلات إلى PDF')),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const Text('الدخل والمصروفات - أعمدة',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    SizedBox(height:180,child:BarChart(BarChartData(
     alignment:BarChartAlignment.spaceAround,
     barTouchData:BarTouchData(enabled:true),
     titlesData:const FlTitlesData(topTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
      rightTitles:AxisTitles(sideTitles:SideTitles(showTitles:false))),
     barGroups:List.generate(points.length,(i)=>BarChartGroupData(x:i,barRods:[
      BarChartRodData(toY:points[i].income,color:emerald,width:10),
      BarChartRodData(toY:points[i].expense,color:Colors.deepOrange,width:10),
     ])),
    ))),
   ]))),
   if(breakdown.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const Text('توزيع المصروفات - دائري',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    SizedBox(height:210,child:PieChart(PieChartData(centerSpaceRadius:32,sections:breakdown.entries.map((e){
     final c=categoryFor(e.key,false);
     return PieChartSectionData(value:e.value,color:Color(c.color),radius:70,
      title:'${(e.value/exp*100).toStringAsFixed(0)}٪',titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold));
    }).toList()))),
   ]))),
   const SizedBox(height:16),
   Text('توزيع مصروفاتك',style:Theme.of(context).textTheme.titleMedium),
   ...breakdown.entries.map((x){
    final c=categoryFor(x.key,false);
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
     Row(children:[Icon(categoryIcon(c.icon),color:Color(c.color)),const SizedBox(width:8),
      Expanded(child:Text(x.key)),RiyalAmount(x.value)]),
     const SizedBox(height:10),
     LinearProgressIndicator(value:exp==0?0:x.value/exp,color:Color(c.color),minHeight:8,borderRadius:BorderRadius.circular(8)),
    ])));
   }),
   if(breakdown.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('ما فيه مصروفات في هالفترة')),
   const SizedBox(height:80),
  ]);
 }

 Future<BudgetCategory?> categoryDialog({BudgetCategory? initial,bool income=false,String? suggested})async {
  final name=TextEditingController(text:initial?.name??suggested??'');
  final budget=TextEditingController(text:initial==null||initial.budget==0?'':formatMoney(initial.budget));
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];int alertPercent=initial?.alertPercent??80;
  final result=await showDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:Text(initial==null?'قسم جديد':'تعديل القسم'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,decoration:const InputDecoration(labelText:'اسم القسم')),
     const SizedBox(height:12),const Text('اختر أيقونة'),
     Wrap(spacing:5,children:iconNames.map((x)=>IconButton(
      style:IconButton.styleFrom(backgroundColor:icon==x?emerald.withValues(alpha:.2):null),
      onPressed:()=>update(()=>icon=x),icon:Icon(categoryIcon(x),color:icon==x?emerald:null))).toList()),
     const Text('اختر لون'),
     Wrap(spacing:7,children:colors.map((x)=>InkWell(
      onTap:()=>update(()=>color=x),
      child:CircleAvatar(radius:15,backgroundColor:Color(x),
       child:color==x?const Icon(Icons.check,color:Colors.white,size:17):null))).toList()),
     if(!(initial?.income??income))...[
      TextField(controller:budget,onChanged:(_)=>update((){}),
       keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'ميزانية شهرية (اختياري)')),
      const SizedBox(height:10),
      DropdownButtonFormField<int>(initialValue:alertPercent,
       decoration:const InputDecoration(labelText:'ودّك ننبهك عند كم ٪ من الميزانية؟'),
       items:[50,60,70,75,80,85,90,95,100].map((v)=>DropdownMenuItem(value:v,child:Text('$v٪'))).toList(),
       onChanged:(v){if(v!=null)update(()=>alertPercent=v);}),
      if(amountOf(budget.text)!=null)Padding(padding:const EdgeInsets.only(top:8),
       child:Text('بننبهك عند صرف ${cash(amountOf(budget.text)!*alertPercent/100)} من ميزانية ${cash(amountOf(budget.text)!)}')),
     ],
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
     FilledButton(onPressed:(){
      final n=name.text.trim();if(n.isEmpty)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:n,icon:icon,color:color,
       income:initial?.income??income,budget:budget.text.trim().isEmpty?0:(amountOf(budget.text)??0),alertPercent:alertPercent));
     },child:const Text('حفظ')),
    ])));
  disposeLater([name,budget]);return result;
 }
 Future<void> addCategory({bool income=false})async {
  final c=await categoryDialog(income:income);
  if(c==null||!mounted)return;
  if(categories.any((x)=>x.income==c.income&&x.name.trim()==c.name.trim())){
   snack(context,'القسم موجود بالفعل');return;
  }
  setState(()=>categories.add(c));await persist();
 }
 Future<void> updateCategory(BudgetCategory c)async {
  final v=await categoryDialog(initial:c);
  if(v==null||!mounted)return;
  if(categories.any((x)=>x.id!=c.id&&x.income==c.income&&x.name==v.name)){
   snack(context,'اسم القسم مستخدم');return;
  }
  setState((){
   final i=categories.indexWhere((x)=>x.id==c.id);
   if(i>=0)categories[i]=v;
   for(var j=0;j<entries.length;j++){
    final e=entries[j];
    if(e.category==c.name&&e.income==c.income){
     entries[j]=MoneyEntry(id:e.id,title:e.title,category:v.name,amount:e.amount,income:e.income,date:e.date,receiptPath:e.receiptPath);
    }
   }
   for(var j=0;j<recurring.length;j++){
    final r=recurring[j];
    if(r.category==c.name&&r.income==c.income){
     recurring[j]=RecurringBill(id:r.id,title:r.title,category:v.name,amount:r.amount,income:r.income,day:r.day);
    }
   }
  });
  await persist();
 }
 Future<void> deleteCategory(BudgetCategory c)async {
  if(entries.any((e)=>e.category==c.name&&e.income==c.income)||
    recurring.any((e)=>e.category==c.name&&e.income==c.income)){
   snack(context,'ما تقدر تحذف قسم مرتبط بعمليات أو مصاريف متكررة');return;
  }
  setState(()=>categories.removeWhere((e)=>e.id==c.id));await persist();
 }
 Widget categoriesPage(){
  final now=DateTime.now();
  final current=entries.where((e)=>!e.income&&e.date.year==now.year&&e.date.month==now.month);
  return ListView(padding:const EdgeInsets.all(16),children:[
   Text('أقسامك وميزانياتك',style:Theme.of(context).textTheme.titleLarge),
   const Text('حدّد ميزانية شهرية لكل قسم وتابع صرفك'),
   const SizedBox(height:12),
   FilledButton.icon(onPressed:()=>addCategory(),icon:const Icon(Icons.add),label:const Text('إضافة قسم مصروفات')),
   OutlinedButton.icon(onPressed:()=>addCategory(income:true),icon:const Icon(Icons.add),label:const Text('إضافة قسم دخل')),
   const SizedBox(height:12),
   ...categories.map((c){
    final spent=sum(current.where((e)=>e.category==c.name),false);
    return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
     ListTile(
      leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
       child:Icon(categoryIcon(c.icon),color:Color(c.color))),
      title:Text(c.name),
      subtitle:Text(c.income?'دخل':c.budget>0?'الميزانية: ${cash(c.budget)} • تنبيه عند ${c.alertPercent}٪':'بدون ميزانية محددة'),
      trailing:PopupMenuButton<String>(onSelected:(v){
       if(v=='edit')updateCategory(c);else deleteCategory(c);
      },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),
       PopupMenuItem(value:'delete',child:Text('حذف'))])),
     if(!c.income&&c.budget>0)...[
      LinearProgressIndicator(value:(spent/c.budget).clamp(0.0,1.0),minHeight:8,
       color:spent>c.budget?Colors.red:Color(c.color),borderRadius:BorderRadius.circular(8)),
      const SizedBox(height:5),
      Text('صرفت ${cash(spent)} من ${cash(c.budget)}',
       style:TextStyle(color:spent>c.budget?Colors.red:null)),
     ],
    ])));
   }),
   const SizedBox(height:80),
  ]);
 }
 Future<void> goalDialog()async {
  final name=TextEditingController(),target=TextEditingController();
  final g=await showDialog<SavingGoal>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('إضافة هدف ادخار'),scrollable:true,
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,textInputAction:TextInputAction.next,
     decoration:const InputDecoration(labelText:'اسم الهدف',hintText:'سيارة، سفر، منزل، أو مبلغ ادخار')),
    const SizedBox(height:12),
    TextField(controller:target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
     decoration:const InputDecoration(labelText:'المبلغ المستهدف بالريال',hintText:'مثال: 25000')),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     final n=amountOf(target.text);
     if(name.text.trim().isEmpty||n==null){
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('اكتب اسم الهدف ومبلغًا صحيحًا أكبر من صفر')));
      return;
     }
     Navigator.pop(ctx,SavingGoal(id:newId(),name:name.text.trim(),target:n,saved:0));
    },child:const Text('إضافة الهدف')),
   ]));
  disposeLater([name,target]);
  if(g!=null&&mounted){
   setState(()=>goals.add(g));await persist();
   if(mounted)snack(context,'تمت إضافة الهدف بنجاح');
  }
 }
 Future<void> fundGoal(SavingGoal g)async {
  final amount=TextEditingController();
  final n=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
   title:Text('إضافة ادخار لـ ${g.name}'),
   content:TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    decoration:const InputDecoration(labelText:'المبلغ المدّخر')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     final v=amountOf(amount.text);if(v!=null)Navigator.pop(ctx,v);
    },child:const Text('إضافة')),
   ]));
  disposeLater([amount]);
  if(n!=null&&mounted){
   final achieved=g.saved<g.target&&g.saved+n>=g.target;
   setState((){
    final i=goals.indexWhere((x)=>x.id==g.id);
    if(i>=0)goals[i]=g.copy(saved:g.saved+n);
   });
   await persist();
   if(achieved&&mounted){
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:const Text('🎉 مبروك!'),
     content:Text('تم تحقيق هدف الادخار «${g.name}» بنجاح!'),
     actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('رائع'))]));
   }
  }
 }
 IconData goalIcon(String name){
  final x=name.toLowerCase();
  if(RegExp(r'سيار|عرب|car').hasMatch(x))return Icons.directions_car;
  if(RegExp(r'بيت|منزل|شقة|home').hasMatch(x))return Icons.home;
  if(RegExp(r'سفر|رحل|عمرة|حج|travel').hasMatch(x))return Icons.flight_takeoff;
  if(RegExp(r'زواج|عرس|فرح').hasMatch(x))return Icons.favorite;
  if(RegExp(r'دراس|تعليم|جامعة|school').hasMatch(x))return Icons.school;
  if(RegExp(r'جوال|هاتف|موبايل').hasMatch(x))return Icons.smartphone;
  if(RegExp(r'مشروع|تجارة').hasMatch(x))return Icons.storefront;
  return Icons.account_balance_wallet;
 }
 Widget goalsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  Text('أهداف الادخار',style:Theme.of(context).textTheme.titleLarge),
  const SizedBox(height:8),
  const Text('خلّ حلمك هدف وامش له خطوة بخطوة'),
  const SizedBox(height:12),
  FilledButton.icon(onPressed:goalDialog,icon:const Icon(Icons.add),label:const Text('هدف جديد')),
  const SizedBox(height:12),
  ...goals.map((g)=>Card(child:Padding(padding:const EdgeInsets.all(14),
   child:Column(children:[
    Row(children:[
     Icon(goalIcon(g.name),color:emerald),const SizedBox(width:8),
     Expanded(child:Text(g.name,style:const TextStyle(fontWeight:FontWeight.bold))),
     PopupMenuButton<String>(onSelected:(v)async {
      if(v=='delete'){setState(()=>goals.removeWhere((x)=>x.id==g.id));await persist();}
     },itemBuilder:(_)=>const [PopupMenuItem(value:'delete',child:Text('حذف الهدف'))]),
    ]),
    const SizedBox(height:10),
    LinearProgressIndicator(value:(g.saved/g.target).clamp(0.0,1.0),
     minHeight:10,borderRadius:BorderRadius.circular(10)),
    const SizedBox(height:8),
    Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:6,
     children:[RiyalAmount(g.saved),const Text('من'),RiyalAmount(g.target)]),
    if(g.saved>=g.target)
     const Text('🎉 مبروك! تم تحقيق الهدف',
      style:TextStyle(fontWeight:FontWeight.bold,color:emerald))
    else Text('المتبقي للهدف: ${cash((g.target-g.saved).clamp(0.0,double.infinity))}',
     style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
    TextButton.icon(onPressed:()=>fundGoal(g),icon:const Icon(Icons.add),label:const Text('أضف مبلغ مدّخر')),
   ])))),
  if(goals.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('ما أضفت أي هدف ادخار للحين')),
  const SizedBox(height:90),
 ]);
 Future<void> recurringDialog()async {
  final title=TextEditingController(),amount=TextEditingController(),day=TextEditingController(text:'1');
  bool income=false;String category=forType(false).first.name;
  final r=await showDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forType(income);
    final selected=options.any((x)=>x.name==category)?category:options.first.name;
    return AlertDialog(title:const Text('عملية شهرية متكررة'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'الوصف')),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       decoration:const InputDecoration(labelText:'المبلغ')),
      DropdownButtonFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:Text('دخل')),
        DropdownMenuItem(value:false,child:Text('مصروف'))],
       onChanged:(v){if(v!=null)update((){income=v;category=forType(v).first.name;});}),
      DropdownButtonFormField<String>(key:ValueKey('$income-$selected'),initialValue:selected,
       items:options.map((c)=>DropdownMenuItem(value:c.name,child:Text(c.name))).toList(),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      TextField(controller:day,keyboardType:TextInputType.number,
       decoration:const InputDecoration(labelText:'يوم الشهر (1 - 31)')),
     ])),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
      FilledButton(onPressed:(){
       final n=amountOf(amount.text),d=int.tryParse(digits(day.text));
       if(title.text.trim().isNotEmpty&&n!=null&&d!=null&&d>=1&&d<=31){
        Navigator.pop(ctx,RecurringBill(id:newId(),title:title.text.trim(),category:category,
         amount:n,income:income,day:d));
       }
      },child:const Text('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState(()=>recurring.add(r));await persist();await applyRecurring();
  }
 }
 Widget recurringPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  Text('العمليات المتكررة',style:Theme.of(context).textTheme.titleLarge),
  const SizedBox(height:8),
  const Text('نسجّل العملية المستحقة مرة وحدة لكل شهر عند فتح التطبيق.'),
  const SizedBox(height:12),
  FilledButton.icon(onPressed:recurringDialog,icon:const Icon(Icons.add),label:const Text('عملية متكررة جديدة')),
  const SizedBox(height:12),
  ...recurring.map((r)=>Card(child:ListTile(
   leading:Icon(r.income?Icons.south_west:Icons.event_repeat,color:emerald),
   title:Text(r.title),subtitle:Text('${r.category} • يوم ${r.day} من كل شهر'),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    RiyalAmount(r.amount),
    IconButton(onPressed:()async {
     final ok=await confirm('حذف التكرار','تبي توقف تكرار ${r.title}؟ العمليات المسجّلة بتبقى محفوظة.');
     if(ok==true&&mounted){setState(()=>recurring.removeWhere((x)=>x.id==r.id));await persist();}
    },icon:const Icon(Icons.delete_outline)),
   ])))),
  if(recurring.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('ما عندك عمليات متكررة')),
  const SizedBox(height:90),
 ]);
 String exportBackup()=>const JsonEncoder.withIndent('  ').convert({
  'format':'waffra-backup','version':24,'exportedAt':DateTime.now().toIso8601String(),
  'entries':entries.map((e)=>e.toJson()).toList(),
  'categories':categories.map((e)=>e.toJson()).toList(),
  'goals':goals.map((e)=>e.toJson()).toList(),
  'recurring':recurring.map((e)=>e.toJson()).toList(),
  'profile':widget.profile.toJson(),
 });
 Future<void> backupDialog()async {
  final input=TextEditingController();
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('نسخ احتياطي واستعادة'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('انسخ بياناتك واحفظها في مكان آمن. للاستعادة، الصق نسخة JSON. الاستعادة تستبدل بيانات العمليات والأقسام والأهداف والتكرار الحالية.'),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:()async {
     await Clipboard.setData(ClipboardData(text:exportBackup()));
     if(ctx.mounted)snack(ctx,'تم نسخ البيانات، احفظها في مكان آمن');
    },icon:const Icon(Icons.copy),label:const Text('نسخ النسخة الاحتياطية')),
    const SizedBox(height:12),
    TextField(controller:input,minLines:4,maxLines:7,
     decoration:const InputDecoration(labelText:'الصق نسخة JSON للاستعادة',border:OutlineInputBorder())),
   ])),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),
    FilledButton(onPressed:()async {
     try{
      final raw=jsonDecode(input.text);
      if(raw is! Map||raw['format']!='waffra-backup'||raw['entries'] is! List||
        raw['categories'] is! List||raw['goals'] is! List||raw['recurring'] is! List){
       throw const FormatException('Invalid backup');
      }
      final newEntries=(raw['entries'] as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))).toList();
      final newCategories=(raw['categories'] as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))).toList();
      final newGoals=(raw['goals'] as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))).toList();
      final newRecurring=(raw['recurring'] as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))).toList();
      if(newCategories.isEmpty)throw const FormatException('Empty categories');
      if(!mounted)return;
      final ok=await confirm('تأكيد الاستعادة','ودّك تستبدل البيانات الحالية بالنسخة الملصوقة؟');
      if(ok!=true||!mounted)return;
      setState((){
       entries..clear()..addAll(newEntries);
       categories..clear()..addAll(newCategories);
       goals..clear()..addAll(newGoals);
       recurring..clear()..addAll(newRecurring);
      });
      await persist();
      if(ctx.mounted)Navigator.pop(ctx);
      if(mounted)snack(context,'تمت استعادة البيانات بنجاح');
     }catch(e){
      if(ctx.mounted)snack(ctx,'النسخة غير صالحة، تأكد من النص كامل');
     }
    },child:const Text('استعادة')),
   ]));
  disposeLater([input]);
 }
 Future<void> configurePin()async {
  final c=TextEditingController();
  final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(widget.pinEnabled?'إلغاء رمز القفل':'إنشاء رمز قفل'),
   content:TextField(controller:c,keyboardType:TextInputType.number,obscureText:true,maxLength:8,
    decoration:InputDecoration(labelText:widget.pinEnabled?'أدخل الرمز الحالي':'رمز من 4 إلى 8 أرقام')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     final value=c.text.trim();
     if(!RegExp(r'^\d{4,8}$').hasMatch(value)){
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('اكتب 4 إلى 8 أرقام')));
      return;
     }
     Navigator.pop(ctx,value);
    },child:const Text('تأكيد')),
   ]));
  disposeLater([c]);
  if(result==null||!mounted)return;
  final prefs=await SharedPreferences.getInstance();
  if(widget.pinEnabled){
   final saved=prefs.getString('waffra_pin_sha256');
   if(sha256.convert(utf8.encode(result)).toString()!=saved){
    snack(context,'رمز القفل غير صحيح');return;
   }
   await widget.onSetPin(null);if(mounted)snack(context,'تم إلغاء القفل');
  }else{
   await widget.onSetPin(result);if(mounted)snack(context,'تم تفعيل قفل التطبيق');
  }
 }
 Widget profilePage()=>ListView(padding:const EdgeInsets.all(18),children:[
  const SizedBox(height:10),
  Center(child:saudiAvatar(widget.profile.gender,radius:46)),
  const SizedBox(height:12),
  Text(widget.profile.name,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
  Text(widget.profile.email,textAlign:TextAlign.center),
  const SizedBox(height:16),
  Card(child:Column(children:[
   ListTile(leading:const Icon(Icons.people),title:const Text('الجنس'),subtitle:Text(widget.profile.gender)),
   ListTile(leading:const Icon(Icons.cake),title:const Text('تاريخ الميلاد'),subtitle:Text(dayText(widget.profile.birthday))),
   ListTile(leading:const Icon(Icons.login),title:const Text('طريقة إنشاء الملف الشخصي'),subtitle:Text(widget.profile.provider)),
  ])),
  const SizedBox(height:12),
  OutlinedButton.icon(onPressed:()async {
   await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ProfileForm(
    provider:widget.profile.provider,initial:widget.profile,onSave:widget.onProfile)));
  },icon:const Icon(Icons.edit),label:const Text('تعديل حسابي')),
  OutlinedButton.icon(onPressed:configurePin,
   icon:Icon(widget.pinEnabled?Icons.lock:Icons.lock_open),
   label:Text(widget.pinEnabled?'إلغاء قفل التطبيق':'تفعيل قفل التطبيق برمز PIN')),
  OutlinedButton.icon(onPressed:()=>Navigator.push<void>(context,
   MaterialPageRoute(builder:(_)=>CurrencyConverterPage(lastIncomeAmount:entries.where((e)=>e.income).isEmpty?null:entries.where((e)=>e.income).reduce((a,b)=>a.date.isAfter(b.date)?a:b).amount))),
   icon:const Icon(Icons.currency_exchange),label:const Text('تحويل العملات')),
  OutlinedButton.icon(onPressed:widget.onTheme,
   icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode),label:const Text('تغيير المظهر')),
  OutlinedButton.icon(onPressed:backupDialog,icon:const Icon(Icons.backup_outlined),
   label:const Text('النسخ الاحتياطي والاستعادة')),
  if(widget.profile.provider=='محلي')FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.login),
   label:const Text('تسجيل الدخول')),
  if(widget.profile.provider!='محلي')FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),
   label:const Text('تسجيل الخروج')),
  const SizedBox(height:16),
  const Text('بياناتك محفوظة على جهازك. احفظ نسخة احتياطية قبل تغيير الجوال أو حذف التطبيق. ما فيه ربط بالحسابات البنكية.',
   textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
 ]);
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('وفرة | Waffra',style:TextStyle(fontWeight:FontWeight.bold)),
   actions:[
    IconButton(onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode)),
    Padding(padding:const EdgeInsets.only(left:12),
     child:InkWell(onTap:()=>setState(()=>tab=5),borderRadius:BorderRadius.circular(30),child:saudiAvatar(widget.profile.gender))),
   ]),
  body:!ready?const Center(child:CircularProgressIndicator()):
   IndexedStack(index:tab,children:[dashboard(),analytics(),categoriesPage(),goalsPage(),recurringPage(),profilePage()]),
  floatingActionButton:tab==0?FloatingActionButton.extended(
   onPressed:()=>entrySheet(),icon:const Icon(Icons.add),label:const Text('أضف عملية')):null,
  bottomNavigationBar:NavigationBar(height:74,
   labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
   selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
   destinations:const [
    NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.bar_chart_outlined),label:'التحليلات'),
    NavigationDestination(icon:Icon(Icons.category_outlined),label:'الأقسام'),
    NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'الادخار'),
    NavigationDestination(icon:Icon(Icons.repeat),label:'المتكررة'),
    NavigationDestination(icon:Icon(Icons.person_outline),label:'حسابي'),
   ]));
}
class ChartPoint {
 final String label;final double income,expense;
 ChartPoint(this.label,this.income,this.expense);
}
class FinanceChart extends StatelessWidget {
 final List<ChartPoint> points;
 const FinanceChart({super.key,required this.points});
 @override Widget build(BuildContext context){
  double max=1;
  for(final p in points){if(p.income>max)max=p.income;if(p.expense>max)max=p.expense;}
  return Column(children:[
   const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
    Icon(Icons.square,color:emerald,size:15),Text(' دخل  '),
    Icon(Icons.square,color:Colors.deepOrange,size:15),Text(' مصروفات'),
   ]),
   const SizedBox(height:15),
   SizedBox(height:190,child:Row(crossAxisAlignment:CrossAxisAlignment.end,
    children:points.map((p)=>Expanded(child:Column(children:[
     Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
      Expanded(child:FractionallySizedBox(alignment:Alignment.bottomCenter,
       heightFactor:(p.income/max).clamp(.015,1.0),
       child:Container(margin:const EdgeInsets.symmetric(horizontal:1),
        decoration:const BoxDecoration(color:emerald,borderRadius:BorderRadius.vertical(top:Radius.circular(5)))))),
      Expanded(child:FractionallySizedBox(alignment:Alignment.bottomCenter,
       heightFactor:(p.expense/max).clamp(.015,1.0),
       child:Container(margin:const EdgeInsets.symmetric(horizontal:1),
        decoration:const BoxDecoration(color:Colors.deepOrange,borderRadius:BorderRadius.vertical(top:Radius.circular(5)))))),
     ])),
     const SizedBox(height:7),Text(p.label,style:const TextStyle(fontSize:10)),
    ]))).toList())),
  ]);
 }
}
