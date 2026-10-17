import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_welcome_background.dart';

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
 MoneyEntry({required this.id,required this.title,required this.category,required this.amount,required this.income,required this.date});
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'income':income,'date':date.toIso8601String()};
 factory MoneyEntry.fromJson(Map<String,dynamic> j)=>MoneyEntry(id:'${j['id']??newId()}',title:'${j['title']??''}',category:'${j['category']??'أخرى'}',amount:(j['amount'] as num).toDouble(),income:j['income']==true,date:DateTime.tryParse('${j['date']}')??DateTime.now());
}
class Person {
 final String name,email,provider,gender,avatar;final DateTime birthday;
 Person({required this.name,required this.email,required this.provider,required this.gender,required this.avatar,required this.birthday});
 Map<String,dynamic> toJson()=>{'name':name,'email':email,'provider':provider,'gender':gender,'avatar':avatar,'birthday':birthday.toIso8601String()};
 factory Person.fromJson(Map<String,dynamic> j)=>Person(name:'${j['name']??''}',email:'${j['email']??''}',provider:'${j['provider']??'محلي'}',gender:'${j['gender']??'غير محدد'}',avatar:'${j['avatar']??'person'}',birthday:DateTime.tryParse('${j['birthday']}')??DateTime(2000));
}
class BudgetCategory {
 final String id,name,icon;final int color;final bool income;final double budget;
 BudgetCategory({required this.id,required this.name,required this.icon,required this.color,required this.income,this.budget=0});
 BudgetCategory copy({String? name,String? icon,int? color,double? budget})=>BudgetCategory(id:id,name:name??this.name,icon:icon??this.icon,color:color??this.color,income:income,budget:budget??this.budget);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'icon':icon,'color':color,'income':income,'budget':budget};
 factory BudgetCategory.fromJson(Map<String,dynamic> j)=>BudgetCategory(id:'${j['id']??newId()}',name:'${j['name']??'أخرى'}',icon:'${j['icon']??'category'}',color:(j['color'] as num?)?.toInt()??0xFF087A54,income:j['income']==true,budget:(j['budget'] as num?)?.toDouble()??0);
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
  if(mounted)setState(()=>profile=null);
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
  theme:ThemeData(useMaterial3:true,colorSchemeSeed:emerald,scaffoldBackgroundColor:sand,textTheme:GoogleFonts.tajawalTextTheme()),
  darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:emerald,textTheme:GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme)),
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
 final c=TextEditingController();String error='';bool busy=false,biometricAvailable=false;
 @override void initState(){super.initState();checkBiometrics();}
 Future<void> checkBiometrics()async {
  final available=await WaffraBiometrics.isAvailable();
  if(mounted)setState(()=>biometricAvailable=available);
 }
 Future<void> biometric()async {
  if(busy)return;setState(()=>busy=true);
  final ok=await WaffraBiometrics.unlock();
  if(!mounted)return;setState(()=>busy=false);
  if(ok)widget.onUnlock();
 }
 @override void dispose(){c.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:forest,
  body:WaffraWelcomeBackground(child:SafeArea(child:Padding(
   padding:const EdgeInsets.symmetric(horizontal:28,vertical:24),
   child:Column(children:[
    const Spacer(flex:2),
    Image.asset('assets/waffra_app_icon.png',width:145,height:145,fit:BoxFit.contain),
    const Spacer(flex:3),
    const Text('فتح وفرة',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),
    TextField(controller:c,keyboardType:TextInputType.number,obscureText:true,maxLength:8,
     textAlign:TextAlign.center,style:const TextStyle(color:Colors.white),
     decoration:const InputDecoration(labelText:'رمز القفل',labelStyle:TextStyle(color:Colors.white),
      enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white70)),
      focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white)))),
    if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.orangeAccent)),
    const SizedBox(height:8),
    SizedBox(width:double.infinity,child:FilledButton(onPressed:(){
     if(sha256.convert(utf8.encode(c.text.trim())).toString()==widget.pinHash){widget.onUnlock();}
     else{setState((){error='الرمز غير صحيح';c.clear();});}
    },child:const Text('فتح التطبيق'))),
    if(biometricAvailable)IconButton(onPressed:busy?null:biometric,
      icon:const Icon(Icons.fingerprint,size:43,color:Colors.white),tooltip:'فتح بالبصمة'),
    const SizedBox(height:18),
   ])))));
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
  body:WaffraWelcomeBackground(child:SafeArea(child:Padding(
   padding:const EdgeInsets.fromLTRB(24,32,24,20),child:Column(children:[
    const Spacer(flex:2),
    Image.asset('assets/waffra_app_icon.png',width:180,height:180,fit:BoxFit.contain),
    const SizedBox(height:20),
    const Text('فلوسك وين تروح؟\nوفرة يعلّمك.',textAlign:TextAlign.center,
     style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800)),
    const Spacer(flex:5),
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
    const Text('بياناتك المالية محفوظة على جهازك',style:TextStyle(color:Colors.white70,fontSize:12)),
   ])))));
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
    const Text('تسجيل الدخول تجريبي، وما فيه ربط فعلي مع Google أو Apple.',
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
   Center(child:CircleAvatar(radius:48,backgroundColor:emerald,child:Icon(avatarIcon(avatar),color:Colors.white,size:54))),
   const SizedBox(height:10),
   Wrap(alignment:WrapAlignment.center,spacing:8,children:['person','male','female','smile']
    .map((a)=>ChoiceChip(label:Icon(avatarIcon(a)),selected:avatar==a,onSelected:(_)=>setState(()=>avatar=a))).toList()),
   const SizedBox(height:16),
   TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك',border:OutlineInputBorder())),
   const SizedBox(height:12),
   TextField(controller:email,keyboardType:TextInputType.emailAddress,
    decoration:const InputDecoration(labelText:'بريدك الإلكتروني',border:OutlineInputBorder())),
   const SizedBox(height:12),
   DropdownButtonFormField<String>(initialValue:gender,
    decoration:const InputDecoration(labelText:'الجنس',border:OutlineInputBorder()),
    items:['ذكر','أنثى','غير محدد'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
    onChanged:(v){if(v!=null)setState(()=>gender=v);}),
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
 Future<void> entrySheet({MoneyEntry? initial,bool sms=false})async {
  final title=TextEditingController(text:initial?.title??'');
  final value=TextEditingController(text:initial==null?'':formatMoney(initial.amount));
  final message=TextEditingController();
  bool income=initial?.income??false,analyzing=false,hasParsed=false;
  String category=initial?.category??'أخرى';
  DateTime date=initial?.date??DateTime.now();
  String? suggestion,pendingHash;
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
       segments:const [ButtonSegment(value:false,label:Text('مصروف')),
        ButtonSegment(value:true,label:Text('دخل'))],
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
      FilledButton(onPressed:analyzing?null:(){
       final n=amountOf(value.text);
       if(title.text.trim().isEmpty||n==null){snack(context,'تأكد من الوصف والمبلغ');return;}
       if(sms){
        if(message.text.trim().isEmpty){snack(context,'الصق الرسالة البنكية أولًا');return;}
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){snack(context,'هذه الرسالة البنكية أُضيفت من قبل');return;}
        pendingHash=h;
       }
       Navigator.pop(sheetContext,MoneyEntry(id:initial?.id??newId(),title:title.text.trim(),
        category:category,amount:n,income:income,date:date));
      },child:const Text('تأكيد وحفظ العملية')),
     ])));
   }));
  debounce?.cancel();disposeLater([title,value,message]);
  if(result==null||!mounted)return;
  if(initial==null&&!result.income&&entries.any((e)=>
    !e.income&&e.amount==result.amount&&e.date.year==result.date.year&&
    e.date.month==result.date.month&&e.date.day==result.date.day)){
   final proceed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('تنبيه: مبلغ مكرر'),
    content:Text('يبدو أنك سجلت مبلغ ${cash(result.amount)} من قبل في نفس اليوم. هل تريد إضافته مرة أخرى؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إضافة على أي حال'))]));
   if(proceed!=true||!mounted)return;
  }
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
 }
 Future<void> deleteEntry(MoneyEntry e)async {
  final yes=await confirm('حذف العملية','متأكد ودّك تحذف «${e.title}»؟');
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
   title:Text(e.title),subtitle:Text('${e.category} • ${dayText(e.date)}'),
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
   OutlinedButton.icon(onPressed:()=>entrySheet(sms:true),icon:const Icon(Icons.content_paste),label:const Text('الصق رسالة بنكية')),
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
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];
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
     if(!(initial?.income??income))TextField(controller:budget,
      keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'ميزانية شهرية (اختياري)')),
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
     FilledButton(onPressed:(){
      final n=name.text.trim();if(n.isEmpty)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:n,icon:icon,color:color,
       income:initial?.income??income,budget:budget.text.trim().isEmpty?0:(amountOf(budget.text)??0)));
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
     entries[j]=MoneyEntry(id:e.id,title:e.title,category:v.name,amount:e.amount,income:e.income,date:e.date);
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
      subtitle:Text(c.income?'دخل':c.budget>0?'الميزانية: ${cash(c.budget)}':'بدون ميزانية محددة'),
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
  return Icons.savings;
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
    Text('المتبقي للهدف: ${cash((g.target-g.saved).clamp(0.0,double.infinity))}',
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
       items:const [DropdownMenuItem(value:false,child:Text('مصروف')),
        DropdownMenuItem(value:true,child:Text('دخل'))],
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
      final ok=await confirm('تأكيد الاستعادة','بتستبدل البيانات الحالية بالنسخة الملصوقة. متأكد؟');
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
  Center(child:CircleAvatar(radius:46,backgroundColor:emerald,
   child:Icon(avatarIcon(widget.profile.avatar),color:Colors.white,size:55))),
  const SizedBox(height:12),
  Text(widget.profile.name,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
  Text(widget.profile.email,textAlign:TextAlign.center),
  const SizedBox(height:16),
  Card(child:Column(children:[
   ListTile(leading:const Icon(Icons.people),title:const Text('الجنس'),subtitle:Text(widget.profile.gender)),
   ListTile(leading:const Icon(Icons.cake),title:const Text('تاريخ الميلاد'),subtitle:Text(dayText(widget.profile.birthday))),
   ListTile(leading:const Icon(Icons.login),title:const Text('طريقة الدخول التجريبية'),subtitle:Text(widget.profile.provider)),
  ])),
  const SizedBox(height:12),
  OutlinedButton.icon(onPressed:()async {
   await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ProfileForm(
    provider:widget.profile.provider,initial:widget.profile,onSave:widget.onProfile)));
  },icon:const Icon(Icons.edit),label:const Text('تعديل حسابي')),
  OutlinedButton.icon(onPressed:configurePin,
   icon:Icon(widget.pinEnabled?Icons.lock:Icons.lock_open),
   label:Text(widget.pinEnabled?'إلغاء قفل التطبيق':'تفعيل قفل التطبيق برمز PIN')),
  OutlinedButton.icon(onPressed:widget.onTheme,
   icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode),label:const Text('تغيير المظهر')),
  OutlinedButton.icon(onPressed:backupDialog,icon:const Icon(Icons.backup_outlined),
   label:const Text('النسخ الاحتياطي والاستعادة')),
  FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),
   label:const Text('تسجيل خروج تجريبي')),
  const SizedBox(height:16),
  const Text('بياناتك محفوظة على جهازك. احفظ نسخة احتياطية قبل تغيير الجوال أو حذف التطبيق. ما فيه ربط بنكي أو تسجيل دخول حقيقي.',
   textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
 ]);
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('وفرة | Waffra',style:TextStyle(fontWeight:FontWeight.bold)),
   actions:[
    IconButton(onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode)),
    Padding(padding:const EdgeInsets.only(left:12),
     child:CircleAvatar(backgroundColor:emerald,
      child:Icon(avatarIcon(widget.profile.avatar),color:Colors.white))),
   ]),
  body:!ready?const Center(child:CircularProgressIndicator()):
   IndexedStack(index:tab,children:[dashboard(),analytics(),categoriesPage(),goalsPage(),recurringPage(),profilePage()]),
  floatingActionButton:tab==0?FloatingActionButton.extended(
   onPressed:()=>entrySheet(),icon:const Icon(Icons.add),label:const Text('أضف عملية')):null,
  bottomNavigationBar:NavigationBar(height:74,
   labelBehavior:NavigationDestinationLabelBehavior.onlyShowSelected,
   selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
   destinations:const [
    NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.bar_chart_outlined),label:'التحليلات'),
    NavigationDestination(icon:Icon(Icons.category_outlined),label:'الأقسام'),
    NavigationDestination(icon:Icon(Icons.savings_outlined),label:'الادخار'),
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
