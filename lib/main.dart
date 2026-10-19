import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_amount_formatter.dart';
import 'waffra_validators.dart';
import 'waffra_financial_insights.dart';
import 'waffra_reminders.dart';
import 'waffra_welcome_background.dart';
import 'currency_converter.dart';
import 'waffra_i18n.dart';
import 'waffra_pdf_text.dart';
import 'waffra_merchant_rules.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const WaffraApp()); }
const emerald=Color(0xFF087A54), forest=Color(0xFF064D3B), sand=Color(0xFFF8F6EF), gold=Color(0xFFD8BA78);
final ValueNotifier<int> waffraReturnHome=ValueNotifier<int>(0);
final ValueNotifier<bool> hideWaffraAmounts=ValueNotifier<bool>(false);
final ValueNotifier<bool> allowWaffraScreenshots=ValueNotifier<bool>(true);
const MethodChannel _privacyChannel=MethodChannel('waffra/privacy');
Future<void> setWaffraScreenshotsAllowed(bool allowed)async {
 await SharedPreferences.getInstance().then((p)=>p.setBool('waffra_allow_screenshots',allowed));
 allowWaffraScreenshots.value=allowed;
 if(Platform.isAndroid){
  try{await _privacyChannel.invokeMethod<void>('setScreenshotsAllowed',allowed);}
  on PlatformException catch(e){debugPrint('Screenshot setting failed: $e');}
 }
}
String formatMoney(num value) {
 if(hideWaffraAmounts.value)return '***';
 return formatWaffraMoney(value);
}
String cash(num value)=>hideWaffraAmounts.value?'***':'${formatMoney(value)} ﷼';
String dayText(DateTime d)=>'${d.day}/${d.month}/${d.year}';
String digits(String s) {
  const a='٠١٢٣٤٥٦٧٨٩',p='۰۱۲۳۴۵۶۷۸۹';
  return s.replaceAllMapped(RegExp('[٠-٩۰-۹]'),(m){final c=m.group(0)!;final i=a.indexOf(c);return '${i>=0?i:p.indexOf(c)}';});
}
double? amountOf(String s) {
  var v=digits(s).replaceAll(' ','').replaceAll('٫','.').replaceAll('٬',',');
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
  return ValueListenableBuilder<bool>(
   valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Row(mainAxisSize:MainAxisSize.min,textDirection:TextDirection.ltr,children:[
    WaffraText(hidden?'***':'$prefix${formatMoney(amount)}',style:effective),
    if(!hidden)...[
     const SizedBox(width:4),
     Image.asset('assets/Saudi_Riyal_Symbol-1.png',width:size*.9,height:size*.9,
      color:color,colorBlendMode:BlendMode.srcIn,
      errorBuilder:(_,__,___)=>WaffraText('﷼',style:effective)),
    ],
   ]));
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
 final String name,email,provider,gender,avatar,phone;final DateTime birthday;
 Person({required this.name,required this.email,required this.provider,required this.gender,required this.avatar,required this.birthday,this.phone=''});
 Map<String,dynamic> toJson()=>{'name':name,'email':email,'provider':provider,'gender':gender,'avatar':avatar,'phone':phone,'birthday':birthday.toIso8601String()};
 factory Person.fromJson(Map<String,dynamic> j)=>Person(name:'${j['name']??''}',email:'${j['email']??''}',provider:'${j['provider']??'محلي'}',gender:['ذكر','أنثى'].contains(j['gender'])?'${j['gender']}':'',avatar:'${j['avatar']??'person'}',phone:'${j['phone']??(j['provider']=='Phone'?j['email']??'':'')}',birthday:DateTime.tryParse('${j['birthday']}')??DateTime(2000));
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
class SavingChallenge {
 final String id,title;final double dailyAmount;
 final int days,completedDays;final DateTime? lastDone;
 SavingChallenge({required this.id,required this.title,required this.dailyAmount,
  required this.days,this.completedDays=0,this.lastDone});
 bool canComplete(DateTime now)=>completedDays<days&&(lastDone==null||
  lastDone!.year!=now.year||lastDone!.month!=now.month||lastDone!.day!=now.day);
 SavingChallenge complete({DateTime? at}){
  final now=at??DateTime.now();
  if(!canComplete(now))return this;
  return SavingChallenge(id:id,title:title,dailyAmount:dailyAmount,
   days:days,completedDays:completedDays+1,lastDone:now);
 }
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'dailyAmount':dailyAmount,
  'days':days,'completedDays':completedDays,'lastDone':lastDone?.toIso8601String()};
 factory SavingChallenge.fromJson(Map<String,dynamic> json)=>SavingChallenge(
  id:'${json['id']??newId()}',title:'${json['title']??''}',
  dailyAmount:(json['dailyAmount'] as num?)?.toDouble()??0,
  days:(json['days'] as num?)?.toInt()??30,
  completedDays:(json['completedDays'] as num?)?.toInt()??0,
  lastDone:DateTime.tryParse('${json['lastDone']}'));
}
class RecurringBill {
 final String id,title,category;final double amount;final bool income;final int day;final bool active;
 RecurringBill({required this.id,required this.title,required this.category,required this.amount,required this.income,required this.day,this.active=true});
 RecurringBill copy({bool? active})=>RecurringBill(id:id,title:title,category:category,amount:amount,income:income,day:day,active:active??this.active);
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'income':income,'day':day,'active':active};
 factory RecurringBill.fromJson(Map<String,dynamic> j)=>RecurringBill(id:'${j['id']??newId()}',
  title:'${j['title']??''}',category:'${j['category']??'أخرى'}',
  amount:(j['amount'] as num).toDouble(),income:j['income']==true,
  day:(j['day'] as num?)?.toInt()??1,active:j['active']!=false);
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
Widget waffraAvatar(String gender,String avatar,{double radius=25}) {
 final file=avatar.startsWith('file:')?File(avatar.substring(5)):null;
 if(file!=null&&file.existsSync()){
  return CircleAvatar(radius:radius,backgroundColor:const Color(0xFFE5F1E9),
   backgroundImage:FileImage(file));
 }
 return saudiAvatar(gender,radius:radius);
}

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
  // Saudi SMS can write currency before or after the amount, with no space:
  // "84.72SR", "SR 84.72", "84.72ر.س", "بـ84.72SR".
  const n=r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';
  const currency=r'(?:SAR|SR|ر\.?\s*س\.?|ريال(?:\s*سعودي)?|﷼|⃁)';
  final patterns=[
   RegExp('$n\\s*$currency',caseSensitive:false),
   RegExp('$currency\\s*[:：-]?\\s*$n',caseSensitive:false),
   RegExp('(?:المبلغ|مبلغ|بقيمة|بمبلغ|amount|amt)\\s*[:：-]?\\s*$n',caseSensitive:false),
  ];
  double? value;
  for(final p in patterns){
   final m=p.firstMatch(s);
   if(m==null)continue;
   value=amountOf(m.group(1)??'');
   if(value!=null)break;
  }
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
DateTime? bankSmsDate(String raw) {
 final normalized=digits(raw).replaceAll('‏','').replaceAll('‎','');
 final match=RegExp(r'(\\d{1,2})[/-](\\d{1,2})[/-](\\d{2,4})\\s+(\\d{1,2}):(\\d{2})').firstMatch(normalized);
 if(match==null)return null;
 final day=int.tryParse(match.group(1)!),month=int.tryParse(match.group(2)!);
 var year=int.tryParse(match.group(3)!);
 final hour=int.tryParse(match.group(4)!),minute=int.tryParse(match.group(5)!);
 if(day==null||month==null||year==null||hour==null||minute==null)return null;
 if(year<100)year+=2000;
 if(month<1||month>12||day<1||day>31||hour>23||minute>59)return null;
 final date=DateTime(year,month,day,hour,minute);
 return date.year==year&&date.month==month&&date.day==day?date:null;
}
String bankSmsHash(String raw)=>sha256.convert(utf8.encode(digits(raw).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
List<String> splitBankMessages(String raw){
 final clean=raw.replaceAll('\r\n','\n').replaceAll('\u200f','').replaceAll('\u200e','').trim();
 if(clean.isEmpty)return [];
 // Bank SMS messages often start with a transaction heading, even without dates.
 final heading=RegExp(r'^\s*(?:شراء(?:\s+PoS)?|حوال[ةه]|تحويل|إيداع|ايداع|راتب|سحب|دفع|نقاط بيع|POS|Purchase|Debit|Credit)(?=\s|$|[:：])',caseSensitive:false,multiLine:true);
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
 final dateLine=RegExp(r'^\s*[0-9٠-٩]{1,2}[/\-][0-9٠-٩]{1,2}[/\-][0-9٠-٩]{2,4}\s+[0-9٠-٩]{1,2}:[0-9٠-٩]{2}\s*',multiLine:true);
 final dates=dateLine.allMatches(clean).toList();
 if(dates.length>1){
  final result=<String>[];var start=0;
  for(final d in dates){final part=clean.substring(start,d.end).trim();if(part.isNotEmpty)result.add(part);start=d.end;}
  final rest=clean.substring(start).trim();if(rest.isNotEmpty)result.add(rest);
  return result;
 }
 // Blank lines often appear within one SMS; do not split them into invalid fragments.
 return [clean];
}

class WaffraApp extends StatefulWidget {
 const WaffraApp({super.key});
 @override State<WaffraApp> createState()=>_WaffraAppState();
}
class _WaffraAppState extends State<WaffraApp> with WidgetsBindingObserver {
 bool loading=true,onboarded=false,dark=false,locked=false,showLogin=false;
 String language='ar';
 String? pinHash;Person? profile;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
 DateTime? _backgroundAt;
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden){_backgroundAt=DateTime.now();}
  if(state==AppLifecycleState.resumed&&_backgroundAt!=null){
   waffraReturnHome.value++;
  }
  if(state==AppLifecycleState.resumed&&pinHash!=null&&!locked&&_backgroundAt!=null){
   final away=DateTime.now().difference(_backgroundAt!);
   _backgroundAt=null;
   if(away>=const Duration(seconds:30)&&mounted)setState(()=>locked=true);
  }
 }
 @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
 String? startupError;
 Future<void> load()async {
  try {
   final p=await SharedPreferences.getInstance().timeout(const Duration(seconds:15));
   Person? u;
   try{final raw=p.getString('waffra_profile');if(raw!=null)u=Person.fromJson(Map<String,dynamic>.from(jsonDecode(raw)));}catch(e){debugPrint('Profile loading: $e');}
   // Screenshot settings are best-effort and must never block application startup.
   if(p.getBool('waffra_screenshot_default_v2')!=true){
    try {
     await p.setBool('waffra_allow_screenshots',true).timeout(const Duration(seconds:3));
     await p.setBool('waffra_screenshot_default_v2',true).timeout(const Duration(seconds:3));
    }catch(e){debugPrint('Screenshot migration: $e');}
   }
   final screenshotsAllowed=p.getBool('waffra_allow_screenshots')??true;
   language=p.getString('waffra_language')=='en'?'en':'ar';
   waffraLanguage.value=language;
   allowWaffraScreenshots.value=screenshotsAllowed;
   if(Platform.isAndroid){
    try{await _privacyChannel.invokeMethod<void>('setScreenshotsAllowed',screenshotsAllowed).timeout(const Duration(seconds:3));}
    catch(e){debugPrint('Privacy initialization failed: $e');}
   }
   if(!mounted)return;
   setState((){
    onboarded=p.getBool('waffra_onboarding_completed')??false;
    dark=p.getBool('waffra_dark_mode')??false;
    profile=u;pinHash=p.getString('waffra_pin_sha256');
    locked=pinHash!=null;startupError=null;loading=false;
   });
  }catch(e){
   debugPrint('Waffra startup failed: $e');
   if(mounted)setState((){startupError=e.toString();loading=false;});
  }
 }
 Future<void> quickStart()async {
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_onboarding_completed',true);
  final u=profile??Person(name:'',email:'',provider:'محلي',gender:'',avatar:'person',birthday:DateTime(2000));
  await saveUser(u);
  if(mounted)setState((){onboarded=true;showLogin=false;});
 }
 Future<void> intro()async {
  final p=await SharedPreferences.getInstance();await p.setBool('waffra_onboarding_completed',true);
  if(mounted)setState((){onboarded=true;showLogin=true;});
 }
 Future<void> saveUser(Person u)async {
  final p=await SharedPreferences.getInstance();await p.setString('waffra_profile',jsonEncode(u.toJson()));
  if(u.phone.trim().isNotEmpty)await p.setString('waffra_registered_profile',jsonEncode(u.toJson()));
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
 Future<void> setLanguage(String next)async {
  if((next!='ar'&&next!='en')||next==language)return;
  final p=await SharedPreferences.getInstance();
  await p.setString('waffra_language',next);
  waffraLanguage.value=next;
  if(mounted)setState(()=>language=next);
 }
 Future<void> theme()async {
  final v=!dark,p=await SharedPreferences.getInstance();
  await p.setBool('waffra_dark_mode',v);if(mounted)setState(()=>dark=v);
 }
 @override Widget build(BuildContext context)=>MaterialApp(
  debugShowCheckedModeBanner:false,title:'وفرة | Waffra',locale:Locale(language,language=='ar'?'SA':'US'),
  supportedLocales:const [Locale('ar','SA'),Locale('en','US')],
  localizationsDelegates:const [
   GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,
   GlobalCupertinoLocalizations.delegate,
  ],
  builder:(context,child)=>ValueListenableBuilder<bool>(
   valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Directionality(
    textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
    child:AnimatedSwitcher(duration:const Duration(milliseconds:240),switchInCurve:Curves.easeOutCubic,
     transitionBuilder:(w,a)=>FadeTransition(opacity:a,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0.11,0),end:Offset.zero).animate(a),child:w)),
     child:KeyedSubtree(key:ValueKey(language),child:child??const SizedBox.shrink())))),
  theme:ThemeData(useMaterial3:true,colorSchemeSeed:emerald,scaffoldBackgroundColor:sand,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.resolveWith((states)=>IconThemeData(color:states.contains(WidgetState.selected)?forest:Colors.white,size:27))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),fontFamily:'Tajawal',textTheme:ThemeData.light().textTheme.apply(fontFamily:'Tajawal'),primaryTextTheme:ThemeData.light().primaryTextTheme.apply(fontFamily:'Tajawal')),
  darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:emerald,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.all(const IconThemeData(color:Colors.white))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),fontFamily:'Tajawal',textTheme:ThemeData.dark().textTheme.apply(fontFamily:'Tajawal'),primaryTextTheme:ThemeData.dark().primaryTextTheme.apply(fontFamily:'Tajawal')),
  themeMode:dark?ThemeMode.dark:ThemeMode.light,
  themeAnimationDuration:const Duration(milliseconds:260),
  themeAnimationCurve:Curves.easeInOutCubic,
  home:Builder(builder:(rootContext)=>PopScope(canPop:false,onPopInvokedWithResult:(didPop,result)async {
   if(didPop||!mounted)return;
   final exit=await showDialog<bool>(context:rootContext,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Exit Waffra?':'تبي تطلع من وفرة؟'),
    content:WaffraText(waffraIsEnglish?'Do you want to exit the app?':'متأكد تبي تطلع من التطبيق؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:WaffraText(waffraIsEnglish?'No':'لا')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:WaffraText(waffraIsEnglish?'Yes':'نعم'))]));
   if(exit==true)SystemNavigator.pop();
  },child:Directionality(textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,child:
   loading?const Scaffold(body:Center(child:CircularProgressIndicator())):
   startupError!=null?Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.error_outline,size:48,color:Colors.red),
    const SizedBox(height:12),
    const WaffraText('تعذر تشغيل وفرة. لم يتم حذف بياناتك.'),
    const SizedBox(height:12),
    SelectableText(startupError??'Unknown startup error',textDirection:TextDirection.ltr,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),
    const SizedBox(height:12),
    OutlinedButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:startupError??'Unknown startup error')),
     icon:const Icon(Icons.copy),label:const WaffraText('نسخ تفاصيل الخطأ')),
    const SizedBox(height:8),
    FilledButton(onPressed:(){setState((){loading=true;startupError=null;});load();},child:const WaffraText('إعادة المحاولة')),
   ])))):
   locked?PinLockScreen(pinHash:pinHash!,onUnlock:()=>setState(()=>locked=false)):
   !onboarded?WaffraOnboarding(onFinish:quickStart):
   profile==null||showLogin?LoginScreen(onSave:saveUser):
   HomeScreen(key:ValueKey(language),profile:profile!,dark:dark,onTheme:theme,onLanguage:setLanguage,onLogout:logout,onProfile:saveUser,onSetPin:setPin,pinEnabled:pinHash!=null)))));
}
class PinLockScreen extends StatefulWidget {
 final String pinHash;final VoidCallback onUnlock;
 const PinLockScreen({super.key,required this.pinHash,required this.onUnlock});
 @override State<PinLockScreen> createState()=>_PinLockScreenState();
}
class _PinLockScreenState extends State<PinLockScreen> {
 final pinController=TextEditingController();
 bool busy=false,biometricAvailable=false,checking=true,showPin=false;
 bool autoBiometricStarted=false;
 int failedPinAttempts=0;
 DateTime? pinCooldownUntil;
 String error='';
 @override void initState(){super.initState();checkBiometrics();}
 Future<void> checkBiometrics()async {
  final available=await WaffraBiometrics.isAvailable();
  if(!mounted)return;
  setState((){biometricAvailable=available;checking=false;});
  // Show the OS's actual Face ID / fingerprint dialog once on opening
  // the lock page, only if enrolled biometrics are available.
  if(available&&!autoBiometricStarted){
   autoBiometricStarted=true;
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted)biometric();
   });
  }
 }
 Future<void> biometric()async {
  if(busy)return;
  if(!biometricAvailable){
   await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:const WaffraText('البصمة غير متاحة'),
    content:const WaffraText('تأكد من تسجيل بصمتك في إعدادات الهاتف، وبعدها افتح التطبيق مرة أخرى. يمكنك الدخول برمز PIN الآن.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('حسنًا'))]));
   return;
  }
  setState((){busy=true;error='';});
  // Android displays its own system biometric prompt, positioned by the OS.
  final success=await WaffraBiometrics.unlock();
  if(!mounted)return;
  setState(()=>busy=false);
  if(success){widget.onUnlock();}
  else{setState(()=>error='تعذّر التحقق بالبصمة. حاول مجددًا أو استخدم رمز PIN.');}
 }
 void verifyPin(){
  if(pinCooldownUntil!=null&&DateTime.now().isBefore(pinCooldownUntil!)){
   setState(()=>error=waffraIsEnglish?'Too many attempts. Try again in a minute.':'محاولات كثيرة، جرّب بعد دقيقة.');return;
  }
  if(sha256.convert(utf8.encode(pinController.text.trim())).toString()==widget.pinHash){
   failedPinAttempts=0;pinCooldownUntil=null;widget.onUnlock();
  }else{
   failedPinAttempts++;
   if(failedPinAttempts>=5){failedPinAttempts=0;pinCooldownUntil=DateTime.now().add(const Duration(minutes:1));}
   setState((){error=pinCooldownUntil!=null?'محاولات كثيرة، جرّب بعد دقيقة.':'رمز PIN غير صحيح';pinController.clear();});
  }
 }
 @override void dispose(){pinController.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:forest,
  body:LayoutBuilder(builder:(context,c)=>Stack(fit:StackFit.expand,children:[
   Image.asset('assets/app_lock.png',fit:BoxFit.fill,filterQuality:FilterQuality.high),
   // Exact source-art locations: four circles in app_lock.png (852x1846)
   // centered at x=305,386,468,550 and y=774. Image and dots share the
   // same Stack rect, so placement is device-size and language independent.
   ...List.generate(4,(i){
    if(i>=pinController.text.length)return const SizedBox.shrink();
    const xCenters=<double>[305/852,386/852,468/852,550/852];
    const yCenter=774/1846;
    final diameter=c.maxWidth*0.019;
    return Positioned(
     left:c.maxWidth*xCenters[i]-diameter/2,
     top:c.maxHeight*yCenter-diameter/2,
     width:diameter,height:diameter,
     child:IgnorePointer(child:DecoratedBox(
      decoration:const BoxDecoration(shape:BoxShape.circle,color:Colors.white))),
    );
   }),
   // Keep the approved full-screen keypad artwork: transparent touch targets
   // make the pictured digits functional without drawing a second keypad.
   ...List.generate(12,(index){
    final row=index~/3,col=index%3;
    final digit=row==3?(col==1?'0':''): '${row*3+col+1}';
    return Positioned(
     left:c.maxWidth*(0.15+col*0.235),top:c.maxHeight*(0.445+row*0.088),
     width:c.maxWidth*0.23,height:c.maxHeight*0.078,
     child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:(){
      if(row==3&&col==0){biometric();return;}
      if(row==3&&col==2){if(pinController.text.isNotEmpty)pinController.text=pinController.text.substring(0,pinController.text.length-1);setState((){});return;}
      if(pinController.text.length<8){pinController.text+=digit;setState((){});}
      if(pinController.text.length==4)verifyPin();
     },child:const ColoredBox(color:Colors.transparent)));
   }),
   // The printed face-recognition label is also a real action.
   Positioned(left:c.maxWidth*0.25,top:c.maxHeight*0.80,
    width:c.maxWidth*0.50,height:c.maxHeight*0.095,
    child:Semantics(button:true,
     label:waffraIsEnglish?'Use face or fingerprint':'استخدام بصمة الوجه أو الإصبع',
     child:GestureDetector(onTap:biometric,behavior:HitTestBehavior.opaque,
      child:const ColoredBox(color:Colors.transparent)))),
   if(error.isNotEmpty)Positioned(left:20,right:20,top:c.maxHeight*0.797,
    child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
     decoration:BoxDecoration(color:forest.withValues(alpha:.92),borderRadius:BorderRadius.circular(12)),
     child:WaffraText(error,textAlign:TextAlign.center,
      style:const TextStyle(color:Colors.white,fontSize:15)))),
   if(busy)Positioned.fill(child:ColoredBox(
    color:const Color(0x9900221A),
    child:Center(child:Container(
     constraints:const BoxConstraints(maxWidth:300),
     padding:const EdgeInsets.symmetric(vertical:25,horizontal:22),
     decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(20),
      border:Border.all(color:Colors.white30)),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      const CircularProgressIndicator(color:Colors.white),
      const SizedBox(height:18),
      WaffraText(waffraIsEnglish?'Verifying your identity...':'جارٍ التحقق من هويتك...',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:17)),
     ]))))),
  ])),
 );
}
class WaffraOnboarding extends StatefulWidget {
 final VoidCallback onFinish;
 const WaffraOnboarding({super.key,required this.onFinish});
 @override State<WaffraOnboarding> createState()=>_WaffraOnboardingState();
}
class _WaffraOnboardingState extends State<WaffraOnboarding> {
 final controller=PageController();
 int current=0;
 bool nextPressed=false;
 static const sourceWidth=<double>[360,363,362,363];
 static const titleAr=<String>[
  'كل معاملاتك\nفي مكان واحد',
  'الصق رسالتك..\nوالباقي علينا',
  'تحليلات بسيطة\nلقرارات أذكى',
  'حقق أهدافك\nخطوة بخطوة',
 ];
 static const subtitleAr=<String>[
  'تابع دخلك ومصروفاتك بسهولة\nوشوف رصيدك الحالي دائمًا.',
  'انسخ رسائلك البنكية والصقها في وفرة،\nونساعدك تصنّف معاملاتك تلقائيًا.',
  'اكتشف عادات صرفك من خلال\nرسوم بيانية وتقارير واضحة وسهلة الفهم.',
  'سواء تدخر لمنزل، سيارة، سفر أو أي هدف آخر.\nحدد هدفك وتابع تقدمك بكل سهولة.',
 ];
 static const titleEn=<String>[
  'All your transactions\nin one place',
  'Paste your messages,\nwe handle the rest',
  'Simple analytics,\nsmarter decisions',
  'Reach your goals\nstep by step',
 ];
 static const subtitleEn=<String>[
  'Track income, expenses and your balance, all in one place.',
  'Paste your bank messages and let Waffra categorize your transactions.',
  'Understand spending habits with clear charts and financial reports.',
  'Set your savings goals and follow your progress with ease.',
 ];
 Future<void> finish()async{
  final prefs=await SharedPreferences.getInstance();
  await prefs.setBool('waffra_onboarding_completed',true);
  if(mounted)widget.onFinish();
 }
 void next(){
  HapticFeedback.selectionClick();
  if(current==3){finish();return;}
  controller.nextPage(duration:const Duration(milliseconds:265),curve:Curves.easeInOutCubic);
 }
 @override void initState(){
  super.initState();
  // Decode the four lightweight artwork assets up front rather than during
  // the first swipe; prevents a first-transition decode hitch.
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(!mounted)return;
   for(var i=1;i<=4;i++){
    precacheImage(AssetImage('assets/onboarding_0'+i.toString()+'.png'),context);
   }
  });
 }
 @override void dispose(){controller.dispose();super.dispose();}
 // Crop only the illustration region from the original approved design.
 // Headlines, progress markers and buttons are real responsive Flutter UI,
 // avoiding the impossible "cover without cropping or stretching" tradeoff.
 // Responsive hero: maximize available width while preserving artwork proportions.
 // Keep its important central content visible and never distort the illustration.
 Widget illustration(int index)=>LayoutBuilder(builder:(context,box){
  // Artwork's embedded captions, buttons and pagination are not included
  // in this hero crop. Those are separate, accessible Flutter controls.
  const cropTop=315.0,cropHeight=555.0;
  final artworkWidth=sourceWidth[index];
  final widthScale=box.maxWidth/artworkWidth;
  final heightScale=box.maxHeight/cropHeight;
  // Fill most of the hero area, allowing only a very small horizontal crop.
  final scale=min(widthScale*1.025,heightScale);
  final imageWidth=artworkWidth*scale;
  final imageHeight=979.0*scale;
  return ClipRect(child:Stack(fit:StackFit.expand,children:[
   const Positioned.fill(child:ColoredBox(color:Color(0xFFFAF9F1))),
   Positioned(
    left:(box.maxWidth-imageWidth)/2,
    top:(box.maxHeight-cropHeight*scale)/2-cropTop*scale,
    width:imageWidth,height:imageHeight,
    child:RepaintBoundary(child:Image.asset(
     'assets/onboarding_0'+(index+1).toString()+'.png',
     fit:BoxFit.fill,filterQuality:FilterQuality.high))),
  ]));
 });
 Widget slide(int index)=>LayoutBuilder(builder:(context,limits){
  final compact=limits.maxHeight<680;
  final titleSize=compact?24.0:28.0;
  final subtitleSize=compact?14.0:15.5;
  final pageName=waffraIsEnglish?titleEn[index]:titleAr[index];
  final pageDesc=waffraIsEnglish?subtitleEn[index]:subtitleAr[index];
  return Padding(
   padding:const EdgeInsets.symmetric(horizontal:10),
   child:Column(children:[
    const SizedBox(height:10),
    Directionality(textDirection:TextDirection.ltr,child:Row(
     mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      TextButton(onPressed:finish,
       child:WaffraText(waffraIsEnglish?'Skip':'تخطي',
        style:const TextStyle(color:forest,fontSize:16))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:7),
       child:WaffraText((index+1).toString()+' / 4',
        style:const TextStyle(color:forest,fontSize:17))),
     ])),
    SizedBox(height:compact?4:9),
    WaffraText(pageName,textAlign:TextAlign.center,
     style:TextStyle(color:forest,fontWeight:FontWeight.w800,
      fontSize:titleSize,height:1.23)),
    SizedBox(height:compact?6:9),
    WaffraText(pageDesc,textAlign:TextAlign.center,
     style:TextStyle(color:const Color(0xFF5B5B60),
      fontSize:subtitleSize,height:1.35)),
    const SizedBox(height:3),
    Expanded(child:illustration(index)),
    // This is the only visible pagination row. Baked-in artwork dots are
    // excluded by the hero crop above, so there can be no duplicate.
    Directionality(textDirection:TextDirection.ltr,child:Row(
     mainAxisAlignment:MainAxisAlignment.center,
     children:List.generate(4,(i)=>AnimatedContainer(
      duration:const Duration(milliseconds:170),curve:Curves.easeOut,
      width:i==current?19:8,height:8,
      margin:const EdgeInsets.symmetric(horizontal:4),
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),
       color:i==current?forest:const Color(0xFFD0DAD0)))))),
    const SizedBox(height:9),
    Listener(
     onPointerDown:(_)=>setState(()=>nextPressed=true),
     onPointerUp:(_)=>setState(()=>nextPressed=false),
     onPointerCancel:(_)=>setState(()=>nextPressed=false),
     child:AnimatedScale(
      scale:nextPressed?0.96:1,
      duration:const Duration(milliseconds:120),
      curve:Curves.easeOutCubic,
      child:SizedBox(width:double.infinity,height:55,child:FilledButton(
     onPressed:next,style:FilledButton.styleFrom(
      backgroundColor:nextPressed?const Color(0xFF033A2B):forest,foregroundColor:Colors.white,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))),
     child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.arrow_back_rounded,size:23),
      const SizedBox(width:17),
      Flexible(child:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(index==3
       ?(waffraIsEnglish?'Start with Waffra':'ابدأ رحلتك مع وفرة')
       :(waffraIsEnglish?'Next':'التالي'),
       maxLines:1,softWrap:false,
       style:const TextStyle(color:Colors.white,fontSize:19,
        fontWeight:FontWeight.bold)))),
     ]))))),
    const SizedBox(height:12),
   ]),
  );
 });
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFFFAF9F1),
  body:SafeArea(child:PageView.builder(
   controller:controller,allowImplicitScrolling:true,
   itemCount:4,
   onPageChanged:(nextIndex)=>setState(()=>current=nextIndex),
   itemBuilder:(context,index)=>slide(index),
  )),
 );
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
  body:Directionality(textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,child:Stack(fit:StackFit.expand,children:[
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
      child:const WaffraText('ابدأ الآن',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)))),
     const SizedBox(height:12),
     SizedBox(width:double.infinity,height:52,child:OutlinedButton(
      onPressed:busy?null:()=>proceed(true),
      style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white70)),
      child:const WaffraText('لديك حساب؟ قم بتسجيل الدخول',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)))),
     const SizedBox(height:15),
     const WaffraText('🔒 بياناتك المالية محفوظة على جهازك',
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
 Person? registered;
 bool signInMode=false,showSignInPassword=false,signingIn=false;
 final signInPhone=TextEditingController(),signInPassword=TextEditingController();
 @override void initState(){super.initState();_loadRegistered();}
 Future<void> _loadRegistered()async{
  final prefs=await SharedPreferences.getInstance();
  final raw=prefs.getString('waffra_registered_profile');
  if(raw==null)return;
  try{final u=Person.fromJson(Map<String,dynamic>.from(jsonDecode(raw)));if(mounted)setState((){registered=u;signInMode=true;signInPhone.text=u.phone;});}catch(_){ }
 }
 @override void dispose(){signInPhone.dispose();signInPassword.dispose();super.dispose();}
 Future<void> _signIn()async{
  if(signingIn)return;
  setState(()=>signingIn=true);
  try{
   final p=await SharedPreferences.getInstance();
   final salt=p.getString('waffra_local_password_salt');
   final expected=p.getString('waffra_local_password_hash');
   final account=registered;
   if(account==null||salt==null||expected==null||signInPhone.text.trim()!=account.phone||
     sha256.convert(utf8.encode('$salt:${signInPassword.text}')).toString()!=expected){
    if(mounted)snack(context,waffraIsEnglish?'Incorrect phone number or password':'رقم الجوال أو كلمة المرور غير صحيحة');return;
   }
   await widget.onSave(account);
  }finally{if(mounted)setState(()=>signingIn=false);}
 }

 bool socialBusy=false;
 Future<void> demoSocial(String selected)async {
  if(socialBusy)return;
  setState(()=>socialBusy=true);
  try {
   await widget.onSave(Person(name:'',email:'',phone:'',provider:'Local $selected demo',gender:'',avatar:'person',birthday:DateTime(2000)));
   if(!mounted)return;
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(waffraIsEnglish?'Local demo profile opened — not authenticated with $selected':'تم الدخول للملف المحلي التجريبي بنجاح — لم تتم المصادقة مع $selected')));
  }finally{if(mounted)setState(()=>socialBusy=false);}
 }
 @override Widget build(BuildContext context){
  if(provider!=null)return ProfileForm(provider:provider!,onSave:widget.onSave,onBack:()=>setState(()=>provider=null));
  return Scaffold(resizeToAvoidBottomInset:false,backgroundColor:forest,body:LayoutBuilder(builder:(context,c){
   final h=c.maxHeight,w=c.maxWidth;
   Widget hit(double top,double height,VoidCallback callback)=>Positioned(
    left:w*0.08,right:w*0.08,top:h*top,height:h*height,
    child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:callback,
     child:const ColoredBox(color:Colors.transparent)));
   if(signInMode&&registered!=null)return Stack(fit:StackFit.expand,children:[
    Image.asset('assets/signin.png',fit:BoxFit.cover,filterQuality:FilterQuality.high),
    Positioned(left:w*0.13,right:w*0.13,top:h*0.425,height:h*0.052,
     child:TextField(controller:signInPhone,keyboardType:TextInputType.phone,
      textAlign:TextAlign.center,style:const TextStyle(color:forest,fontSize:17),
      decoration:const InputDecoration(filled:true,fillColor:Colors.white,
       isDense:true,contentPadding:EdgeInsets.all(9),border:InputBorder.none))),
    Positioned(left:w*0.13,right:w*0.13,top:h*0.503,height:h*0.052,
     child:TextField(controller:signInPassword,onSubmitted:(_)=>_signIn(),obscureText:!showSignInPassword,
      textAlign:TextAlign.center,style:const TextStyle(color:forest,fontSize:17),
      decoration:InputDecoration(filled:true,fillColor:Colors.white,isDense:true,
       contentPadding:const EdgeInsets.all(9),border:InputBorder.none,
       suffixIcon:IconButton(onPressed:()=>setState(()=>showSignInPassword=!showSignInPassword),
        icon:Icon(showSignInPassword?Icons.visibility_off:Icons.visibility))))),
    hit(0.57,0.075,()=>_signIn()),
    hit(0.78,0.055,()=>setState(()=>signInMode=false)),
   ]);
   return Stack(fit:StackFit.expand,children:[
    Image.asset('assets/welcome_login.png',fit:BoxFit.cover,filterQuality:FilterQuality.high),
    hit(0.495,0.067,()=>demoSocial('Google')),
    hit(0.574,0.067,()=>demoSocial('Apple')),
    hit(0.651,0.072,()=>setState(()=>provider='Phone')),
   ]);
  }));
 }
}
class ProfileForm extends StatefulWidget {
 final String provider;final Person? initial;
 final Future<void> Function(Person) onSave;final VoidCallback? onBack;
 const ProfileForm({super.key,required this.provider,required this.onSave,this.initial,this.onBack});
 @override State<ProfileForm> createState()=>_ProfileFormState();
}
class _ProfileFormState extends State<ProfileForm> {
 late final TextEditingController name,email,confirmEmail,phone,password,confirmPassword;
 bool showPassword=false,showConfirmPassword=false;
  bool profileAttempted=false;
 bool get comparingPasswords=>password.text.isNotEmpty&&confirmPassword.text.isNotEmpty;
 bool get matchingPasswords=>comparingPasswords&&password.text==confirmPassword.text;
 OutlineInputBorder passwordBorder({bool focused=false}){
  final c=!comparingPasswords?Colors.grey:(matchingPasswords?emerald:Colors.red);
  return OutlineInputBorder(borderSide:BorderSide(color:c,width:focused?2:1.4));
 }
 late String gender,avatar;late DateTime birthday;bool busy=false;
 @override void initState(){super.initState();
  name=TextEditingController(text:widget.initial?.name??'');
  email=TextEditingController(text:widget.initial?.email??'');
  confirmEmail=TextEditingController();
  phone=TextEditingController(text:widget.initial?.phone??'');
  password=TextEditingController();confirmPassword=TextEditingController();
  gender=widget.initial==null?'':(['ذكر','أنثى'].contains(widget.initial?.gender)?widget.initial!.gender:'');avatar=widget.initial?.avatar??'person';
  birthday=widget.initial?.birthday??DateTime(2000);
 }
 @override void dispose(){name.dispose();email.dispose();confirmEmail.dispose();phone.dispose();password.dispose();confirmPassword.dispose();super.dispose();}
 Future<void> editAvatar()async {
  final choice=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    ListTile(leading:const Icon(Icons.photo_library_outlined),title:WaffraText(waffraIsEnglish?'Choose from gallery':'اختيار صورة من المعرض'),onTap:()=>Navigator.pop(ctx,'gallery')),
    ListTile(leading:const Icon(Icons.restore),title:WaffraText(waffraIsEnglish?'Restore default avatar':'استعادة الصورة الافتراضية'),onTap:()=>Navigator.pop(ctx,'default')),
   ])));
  if(choice==null||!mounted)return;
  if(choice=='default'){setState(()=>avatar=gender=='أنثى'?'female':'male');return;}
  final selected=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:92);
  if(selected==null||!mounted)return;
  final cropKey=GlobalKey();
  final png=await showDialog<Uint8List>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Crop profile photo':'قص صورة الملف الشخصي'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    RepaintBoundary(key:cropKey,child:ClipOval(child:SizedBox(width:230,height:230,
     child:InteractiveViewer(minScale:1,maxScale:5,child:
      Image.file(File(selected.path),fit:BoxFit.cover))))),
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Pinch to zoom and drag to position':'كبّر الصورة وحرّكها داخل الدائرة'),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(onPressed:()async{
     try{
      final boundary=cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null)return;
      final frame=await boundary.toImage(pixelRatio:2);
      final data=await frame.toByteData(format:ui.ImageByteFormat.png);
      if(ctx.mounted&&data!=null)Navigator.pop(ctx,data.buffer.asUint8List());
     }catch(e){debugPrint('Avatar crop: $e');}
    },child:WaffraText(waffraIsEnglish?'Save photo':'حفظ الصورة')),
   ]));
  if(png==null||!mounted)return;
  try{
   final dir=Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
   if(!await dir.exists())await dir.create(recursive:true);
   final file=File('${dir.path}/avatar_${newId()}.png');
   await file.writeAsBytes(png,flush:true);
   if(mounted)setState(()=>avatar='file:${file.path}');
  }catch(e){if(mounted)snack(context,waffraIsEnglish?'Could not save photo':'تعذر حفظ الصورة');}
 }
 Future<void> save()async {
  setState(()=>profileAttempted=true);
  if(gender.isEmpty)return;
  final validEmail=RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());
  final validPhone=RegExp(r'^05[0-9]{8}$').hasMatch(phone.text.trim());
  if(WaffraValidators.requiredText(name.text)!=null||(!validPhone && phone.text.trim().isNotEmpty)){
   snack(context,waffraIsEnglish?'Enter a name and valid mobile number starting with 05':'أدخل الاسم ورقم جوال يبدأ بـ 05 من 10 أرقام');return;
  }
  if(widget.initial==null){
   if(!validPhone){snack(context,waffraIsEnglish?'Enter a 10-digit mobile number starting with 05':'أدخل رقم الجوال من 10 أرقام يبدأ بـ 05');return;}
   if(!RegExp(r'^(?=.*[A-Za-z])(?=.*[0-9]).{8,}$').hasMatch(password.text)||password.text!=confirmPassword.text){
    snack(context,waffraIsEnglish?'Password must be at least 8 characters, include letters and numbers, and match the confirmation.':'كلمة المرور يجب أن تكون 8 خانات على الأقل وتشمل أحرفًا وأرقامًا وتتطابق في الحقلين');return;
   }
  }
  setState(()=>busy=true);
  try {
   if(widget.initial==null){
    final p=await SharedPreferences.getInstance();
    final salt=List<int>.generate(16,(_)=>Random.secure().nextInt(256));
    final saltHex=base64Encode(salt);
    await p.setString('waffra_local_password_salt',saltHex);
    await p.setString('waffra_local_password_hash',sha256.convert(utf8.encode('$saltHex:${password.text}')).toString());
   }
   await widget.onSave(Person(name:name.text.trim(),email:widget.initial?.email??'',
    phone:phone.text.trim(),provider:widget.provider,gender:gender,avatar:avatar,birthday:birthday));
   if(!mounted)return;
   if(widget.initial!=null)Navigator.pop(context);
  }catch(e){if(mounted)snack(context,'تعذر حفظ البيانات: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:WaffraText(widget.initial==null?'كمّل بياناتك':'تعديل الحساب'),
   leading:widget.onBack==null?null:IconButton(onPressed:widget.onBack,icon:const Icon(Icons.arrow_back))),
  body:ListView(padding:const EdgeInsets.all(22),children:[
   Center(child:Stack(alignment:Alignment.bottomRight,children:[
    waffraAvatar(gender,avatar,radius:48),
    Material(color:forest,shape:const CircleBorder(),child:IconButton(
     tooltip:waffraIsEnglish?'Edit profile photo':'تعديل الصورة',
     icon:const Icon(Icons.camera_alt,color:Colors.white,size:19),
     onPressed:editAvatar)),
   ])),
   const SizedBox(height:10),
   Wrap(alignment:WrapAlignment.center,spacing:12,children:['ذكر','أنثى']
    .map((a)=>ChoiceChip(label:Row(mainAxisSize:MainAxisSize.min,children:[saudiAvatar(a,radius:20),const SizedBox(width:6),WaffraText(waffraIsEnglish?(a=='ذكر'?'Male':'Female'):a)]),selected:gender==a,onSelected:(_)=>setState((){gender=a;avatar=a=='ذكر'?'male':'female';}))).toList()),
   const SizedBox(height:16),
   TextField(controller:name,onChanged:(_)=>setState((){}),decoration:InputDecoration(
     labelText:waffraIsEnglish?'Name *':'اسمك *',
     errorText:profileAttempted&&WaffraValidators.requiredText(name.text)!=null?
      (waffraIsEnglish?'Name is required':'الاسم حقل إجباري'):null,
     border:const OutlineInputBorder())),
   const SizedBox(height:12),
   if(widget.initial!=null&&email.text.trim().isNotEmpty) ...[
    TextField(controller:email,readOnly:true,keyboardType:TextInputType.emailAddress,
     decoration:InputDecoration(labelText:waffraIsEnglish?'Registered email':'البريد الإلكتروني المسجل',
      filled:true,fillColor:Colors.grey.withValues(alpha:0.15),border:const OutlineInputBorder())),
    const SizedBox(height:12),
   ],
   TextField(controller:phone,keyboardType:TextInputType.phone,
    onChanged:(_)=>setState((){}),
    inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(10)],
    decoration:InputDecoration(labelText:waffraIsEnglish?'Mobile number starting with 05 *':'رقم جوال يبدأ بـ 05 *',
     hintText:'05XXXXXXXX',
     errorText:profileAttempted&&((widget.initial==null||phone.text.trim().isNotEmpty)&&WaffraValidators.mobileNumber(phone.text)!=null)?
      (waffraIsEnglish?'Enter a valid mobile number starting with 05':'رقم الجوال يجب أن يبدأ بـ 05 ويتكون من 10 أرقام'):null,
     border:const OutlineInputBorder())),
   if(widget.initial==null) ...[
    const SizedBox(height:12),
    TextField(controller:password,obscureText:!showPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showPassword?'Hide password':'Show password'):(showPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showPassword=!showPassword)),labelText:waffraIsEnglish?'Password':'كلمة المرور',
     helperText:waffraIsEnglish?'At least 8 characters, including letters and numbers':'8 خانات على الأقل، تشمل أحرفًا وأرقامًا',
     enabledBorder:passwordBorder(),focusedBorder:passwordBorder(focused:true))),
    const SizedBox(height:12),
    TextField(controller:confirmPassword,obscureText:!showConfirmPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showConfirmPassword?'Hide password':'Show password'):(showConfirmPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showConfirmPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showConfirmPassword=!showConfirmPassword)),labelText:waffraIsEnglish?'Confirm password':'تأكيد كلمة المرور',
     enabledBorder:passwordBorder(),focusedBorder:passwordBorder(focused:true))),
    if(comparingPasswords)Padding(padding:const EdgeInsets.only(top:8),
     child:Row(children:[
      Icon(matchingPasswords?Icons.check_circle_outline:Icons.error_outline,
       color:matchingPasswords?emerald:Colors.red,size:18),
      const SizedBox(width:6),
      WaffraText(matchingPasswords
       ?(waffraIsEnglish?'Passwords match':'كلمتا المرور متطابقتان')
       :(waffraIsEnglish?'Passwords do not match':'كلمتا المرور غير متطابقتين'),
       style:TextStyle(fontWeight:FontWeight.w600,color:matchingPasswords?emerald:Colors.red)),
     ])),
   ],
   const SizedBox(height:12),
   DropdownButtonFormField<String>(initialValue:['ذكر','أنثى'].contains(gender)?gender:null,
    decoration:InputDecoration(labelText:waffraIsEnglish?'Gender *':'الجنس *',
      errorText:profileAttempted&&gender.isEmpty?(waffraIsEnglish?'Select gender':'الجنس حقل إجباري'):null,
      border:const OutlineInputBorder()),
    items:['ذكر','أنثى'].map((x)=>DropdownMenuItem(value:x,child:WaffraText(waffraIsEnglish?(x=='ذكر'?'Male':'Female'):x))).toList(),
    onChanged:(v){if(v!=null)setState((){gender=v;avatar=v=='أنثى'?'female':'male';});}),
   const SizedBox(height:12),
   OutlinedButton.icon(onPressed:()async {
    final d=await showDatePicker(context:context,initialDate:birthday,firstDate:DateTime(1900),lastDate:DateTime.now());
    if(d!=null)setState(()=>birthday=d);
   },icon:const Icon(Icons.calendar_month),label:WaffraText('${waffraIsEnglish?'Date of birth':'تاريخ الميلاد'}: ${dayText(birthday)}')),
   const SizedBox(height:20),
   FilledButton(onPressed:busy?null:save,child:WaffraText(waffraIsEnglish?'Save profile':'حفظ البيانات')),
  ]));
}
void disposeLater(List<TextEditingController> controllers){
 Future<void>.delayed(const Duration(milliseconds:700),(){for(final c in controllers){c.dispose();}});
}
void snack(BuildContext context,String text){
 final messenger=ScaffoldMessenger.of(context);
 messenger.hideCurrentSnackBar();
 messenger.showSnackBar(SnackBar(behavior:SnackBarBehavior.floating,
  margin:const EdgeInsets.fromLTRB(16,8,16,92),
  content:WaffraText(text,maxLines:4),duration:const Duration(seconds:3)));
}

class HomeScreen extends StatefulWidget {
 final Person profile;final bool dark,pinEnabled;
 final Future<void> Function(String?) onSetPin;
 final VoidCallback onTheme;
 final Future<void> Function(String) onLanguage;
 final Future<void> Function() onLogout;
 final Future<void> Function(Person) onProfile;
 const HomeScreen({super.key,required this.profile,required this.dark,required this.pinEnabled,
  required this.onSetPin,required this.onTheme,required this.onLanguage,required this.onLogout,required this.onProfile});
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
// Scroll-linked, pinned balance summary. Shrinks with the user's gesture;
// does not count up money on every tab revisit.
// Consistent Tajawal currency label on the approved dashboard.
// The home cards use the WORD ريال, not a bank/SAR currency icon.
class WaffraCurrencyAmount extends StatelessWidget {
 final double amount;
 final double fontSize;
 final Color? color;
 final FontWeight weight;
 const WaffraCurrencyAmount(this.amount,{
  super.key,this.fontSize=20,this.color,this.weight=FontWeight.w700});
 @override Widget build(BuildContext context)=>
  ValueListenableBuilder<bool>(valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Directionality(
    textDirection:TextDirection.ltr,
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     WaffraText(hidden?'***':formatMoney(amount),
      style:TextStyle(fontFamily:'Tajawal',fontSize:fontSize,
       fontWeight:weight,color:color)),
     if(!hidden)...[
      const SizedBox(width:5),
      WaffraText(waffraIsEnglish?'SAR':'ريال',
       style:TextStyle(fontFamily:'Tajawal',fontSize:fontSize*.63,
        fontWeight:FontWeight.w600,color:color)),
     ]
    ])));
}
// Collapse the balance as the user scrolls, then let it scroll AWAY
// with the rest of the home page. It is intentionally not pinned.
class WaffraBalanceHeader extends SliverPersistentHeaderDelegate {
 final double balance;
 final bool english;
 final GlobalKey? focusKey;
 const WaffraBalanceHeader({required this.balance,required this.english,this.focusKey});
 @override double get minExtent=>70;
 @override double get maxExtent=>155;
 @override Widget build(BuildContext context,double shrinkOffset,bool overlapsContent){
  final progress=(shrinkOffset/(maxExtent-minExtent)).clamp(0.0,1.0);
  return Container(
   key:focusKey,
   color:Theme.of(context).scaffoldBackgroundColor,
   padding:const EdgeInsets.fromLTRB(14,0,14,5),
   child:Container(
    padding:EdgeInsets.symmetric(horizontal:18,vertical:6-2*progress),
    decoration:BoxDecoration(
     gradient:const LinearGradient(colors:[forest,emerald],
      begin:AlignmentDirectional.centerStart,end:AlignmentDirectional.centerEnd),
     borderRadius:BorderRadius.circular(24-9*progress)),
    child:Column(
     mainAxisAlignment:MainAxisAlignment.center,
     crossAxisAlignment:CrossAxisAlignment.start,
     children:[
      WaffraText(english?'Current balance':'رصيدك الحالي',
       style:TextStyle(fontSize:15-2*progress,color:Colors.white70,
        fontWeight:FontWeight.w600)),
      SizedBox(height:4-2*progress),
      Align(alignment:AlignmentDirectional.centerStart,
       child:FittedBox(fit:BoxFit.scaleDown,
        child:WaffraCurrencyAmount(balance,
         fontSize:29-7*progress,color:Colors.white))),
      if(progress<1)SizedBox(height:25*(1-progress),
       child:ClipRect(child:Opacity(opacity:1-progress,
        child:Align(alignment:AlignmentDirectional.centerStart,
         child:WaffraText(english?'Every riyal counts':'كل ريال تحسب له حساب',
          style:const TextStyle(fontSize:13,color:Colors.white70)))))),
     ],
    )),
  );
 }
 @override bool shouldRebuild(covariant WaffraBalanceHeader oldDelegate)=>
  balance!=oldDelegate.balance||english!=oldDelegate.english;
}
class _HomeScreenState extends State<HomeScreen> {
 final smsHashes=<String>{};
 final learnedMerchantCategories=<String,String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 final challenges=<SavingChallenge>[];
 // Soft-deleted categories are retained on-device for up to 30 days.
 final deletedCategories=<Map<String,dynamic>>[];
 double monthlyBudget=0;
 DateTimeRange? transactionsDateRange;
 double? minTransactionAmount,maxTransactionAmount;
 int tab=0,year=DateTime.now().year,month=DateTime.now().month;
 String search='',typeFilter='الكل',categoryFilter='الكل',period='شهري';
 String categorySearch='',categoryDisplay='all',goalDisplay='all',recurringDisplay='all';
 bool recurringRemindersEnabled=false;
 bool ready=false;
 final _tourKeys=List<GlobalKey>.generate(6,(_)=>GlobalKey());
 bool tourActive=false;
 int tourStep=0;
 static const tourTabs=<int>[0,0,2,3,4,1];
 bool addFabExpanded=false;
 bool showAllTransactions=false,showTransactionFilters=false,showTransactionSearch=false;
 @override void initState(){super.initState();waffraReturnHome.addListener(_returnToHome);load();}
 void _returnToHome(){if(mounted)setState((){tab=0;addFabExpanded=false;});}
 @override void dispose(){waffraReturnHome.removeListener(_returnToHome);super.dispose();}
 Future<void> load()async {
  final p=await SharedPreferences.getInstance();
  try{final raw=p.getString('entries');if(raw!=null)entries.addAll((jsonDecode(raw) as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('entries: $e');}
  try{final raw=p.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(jsonDecode(raw) as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('categories: $e');categories.addAll(defaultCategories());}
  try{final raw=p.getString('waffra_goals_v24');if(raw!=null)goals.addAll((jsonDecode(raw) as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('goals: $e');}
  try{final raw=p.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((jsonDecode(raw) as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('recurring: $e');}
  try{final raw=p.getString('waffra_challenges_v1');if(raw!=null)challenges.addAll((jsonDecode(raw) as List).map((e)=>SavingChallenge.fromJson(Map<String,dynamic>.from(e))));}catch(e){debugPrint('challenges: $e');}
  try{
   final raw=p.getString('waffra_deleted_categories_v1');
   if(raw!=null)deletedCategories.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));
  }catch(e){debugPrint('Deleted categories: $e');}
  final trashBefore=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  smsHashes.addAll(p.getStringList('waffra_sms_hashes_v1')??const []);
  monthlyBudget=p.getDouble('waffra_monthly_budget_v1')??0;
  recurringRemindersEnabled=p.getBool('waffra_recurring_reminders_enabled_v1')??false;
  try{
   final rawRules=p.getString('waffra_learned_merchants_v1');
   if(rawRules!=null){
    final data=jsonDecode(rawRules);
    if(data is Map){
     learnedMerchantCategories.addAll(data.map((key,value)=>MapEntry(key.toString(),value.toString())));
    }
   }
  }catch(e){debugPrint('Learning rules: $e');}
  if(categories.isEmpty)categories.addAll(defaultCategories());
  for(final e in entries){
   if(!categories.any((c)=>c.name==e.category&&c.income==e.income)){
    categories.add(BudgetCategory(id:newId(),name:e.category,icon:'category',color:colors[7],income:e.income));
   }
  }
  if(!mounted)return;setState(()=>ready=true);await applyRecurring();
  if(recurringRemindersEnabled)unawaited(syncRecurringReminders());
  if(trashBefore!=deletedCategories.length)await persist();
  if(!(p.getBool('waffra_in_app_tour_seen_v1')??false)&&mounted){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted)setState((){tourActive=true;tourStep=0;tab=0;addFabExpanded=false;});
   });
  }
 }
 Future<void> persist()async {
  final p=await SharedPreferences.getInstance();
  await Future.wait([
   p.setString('entries',jsonEncode(entries.map((e)=>e.toJson()).toList())),
   p.setString('waffra_categories_v24',jsonEncode(categories.map((e)=>e.toJson()).toList())),
   p.setString('waffra_goals_v24',jsonEncode(goals.map((e)=>e.toJson()).toList())),
   p.setString('waffra_recurring_v24',jsonEncode(recurring.map((e)=>e.toJson()).toList())),
   p.setString('waffra_challenges_v1',jsonEncode(challenges.map((e)=>e.toJson()).toList())),
   p.setString('waffra_deleted_categories_v1',jsonEncode(deletedCategories)),
   p.setDouble('waffra_monthly_budget_v1',monthlyBudget),
   p.setString('waffra_learned_merchants_v1',jsonEncode(learnedMerchantCategories))
  ]);
 }

 Future<void> syncRecurringReminders()async {
  if(!recurringRemindersEnabled)return;
  try {
   await WaffraReminders.schedule(
    recurring.where((r)=>r.active).map((r)=>
     WaffraReminder(id:r.id,title:r.title,day:r.day)).toList(),
    english:waffraIsEnglish);
  }catch(e){debugPrint('Reminder scheduling failed: $e');}
 }
 Future<void> toggleRecurringReminders(bool enabled)async {
  if(enabled){
   try {
    final granted=await WaffraReminders.requestPermission();
    if(!granted){
     if(mounted)snack(context,waffraIsEnglish?
      'Allow notifications in Android settings to enable reminders.':
      'يرجى السماح بالإشعارات في إعدادات أندرويد لتفعيل التذكيرات.');
     return;
    }
   }catch(e){
    if(mounted)snack(context,waffraIsEnglish?'Could not activate reminders.':'تعذر تفعيل التذكيرات.');
    return;
   }
  }
  final prefs=await SharedPreferences.getInstance();
  await prefs.setBool('waffra_recurring_reminders_enabled_v1',enabled);
  if(!mounted)return;
  setState(()=>recurringRemindersEnabled=enabled);
  try {
   if(enabled)await syncRecurringReminders();
   else await WaffraReminders.clear();
  }catch(e){debugPrint('Reminder toggle failed: $e');}
 }

 Future<void> applyRecurring()async {
  final now=DateTime.now();bool changed=false;
  for(final r in recurring){
   if(!r.active)continue;
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
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const WaffraText('تأكيد'))]));
 Future<bool?> confirmDeletion(String title,String body)=>showDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(title),content:WaffraText(body),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx,false),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),
     onPressed:()=>Navigator.pop(ctx,true),
     child:WaffraText(waffraIsEnglish?'Confirm delete':'تأكيد الحذف')),
   ]));
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
 var statusMessage='';
 var rejectedMessages=<String>[];
 bool sheetActive=true;
 Future<void> saveParsedMessages(BuildContext ctx,StateSetter update)async {
  if(busy)return;
  final found=splitBankMessages(pasted.text.trim());
  if(found.isEmpty)return;
  if(found.length>100){update(()=>statusMessage=waffraIsEnglish?'Maximum 100 transactions per paste.':'الحد الأقصى 100 معاملة في كل عملية لصق.');return;}
  final results=found.map(BankParser.parse).toList();
  final valid=<int>[],invalid=<int>[],duplicates=<int>[];
  final seen=<String>{};
  for(var i=0;i<found.length;i++){
   if(results[i].amount==null||results[i].amount!<=0){invalid.add(i);continue;}
   final hash=bankSmsHash(found[i]);
   if(smsHashes.contains(hash)||!seen.add(hash)){duplicates.add(i);continue;}
   valid.add(i);
  }
  if(duplicates.isNotEmpty){
   final addRepeated=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Duplicate transactions detected':'تم اكتشاف معاملات مكررة'),
    content:WaffraText(waffraIsEnglish
     ?'${duplicates.length} transaction(s) may already exist or repeat within this paste. Add them anyway, along with the new valid transactions?'
     :'تم اكتشاف ${duplicates.length} معاملة مكررة، إما مسجلة سابقًا أو مكررة داخل الرسائل الملصوقة. هل تريد إضافتها على أي حال مع المعاملات الجديدة؟'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(d,false),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:()=>Navigator.pop(d,true),child:WaffraText(waffraIsEnglish?'Add anyway':'إضافة على أي حال')),
    ]));
   if(addRepeated!=true||!ctx.mounted)return;
   valid.addAll(duplicates);
   valid.sort();
  }
  if(valid.isEmpty){update(() {statusMessage=waffraIsEnglish?'No valid transactions were detected. Review the unrecognized messages below.':'لم يتم اكتشاف معاملات صالحة. راجع الرسائل غير المعروفة أدناه.';rejectedMessages=invalid.map((i)=>found[i]).toList();});return;}
  final incomes=valid.where((i)=>results[i].income).toList();
  final expenses=valid.where((i)=>!results[i].income).toList();
  final incomeTotal=incomes.fold<double>(0,(v,i)=>v+results[i].amount!);
  final expenseTotal=expenses.fold<double>(0,(v,i)=>v+results[i].amount!);
  final accepted=await showDialog<bool>(context:ctx,builder:(dialogCtx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Confirm transactions':'تأكيد إضافة المعاملات'),
   content:WaffraText(waffraIsEnglish
    ?'Detected ${valid.length} transactions: ${incomes.length} income (SAR ${incomeTotal.toStringAsFixed(2)}) and ${expenses.length} expenses (SAR ${expenseTotal.toStringAsFixed(2)}). ${invalid.length} unrecognized. Add these transactions?'
    :'تم اكتشاف ${valid.length} معاملات: ${incomes.length} دخل (${incomeTotal.toStringAsFixed(2)} ر.س) و${expenses.length} مصروفات (${expenseTotal.toStringAsFixed(2)} ر.س). تعذر تحليل ${invalid.length}. هل تريد تأكيد الإضافة؟'),
   actions:[TextButton(onPressed:()=>Navigator.pop(dialogCtx,false),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(onPressed:()=>Navigator.pop(dialogCtx,true),child:WaffraText(waffraIsEnglish?'Confirm and add':'تأكيد وإضافة المعاملات'))]));
  if(accepted!=true||!ctx.mounted)return;
  update(() {busy=true;rejectedMessages=invalid.map((i)=>found[i]).toList();});
  final additions=<MoneyEntry>[];
  final newHashes=<String>{};
  for(final i in valid){
   final result=results[i];
   final merchant=waffraMerchantKey(found[i]);
   final learned=merchant==null?null:learnedMerchantCategories[merchant];
   final proposed=learned??result.category;
   final cat=categories.any((c)=>c.income==result.income&&c.name==proposed)
    ?proposed:(forType(result.income).isNotEmpty?forType(result.income).first.name:'أخرى');
   additions.add(MoneyEntry(id:newId(),title:'${result.title} — ${found[i].replaceAll(RegExp(r'\\s+'),' ').trim()}',
    category:cat,amount:result.amount!,income:result.income,date:bankSmsDate(found[i])??DateTime.now()));
   newHashes.add(bankSmsHash(found[i]));
  }
  try{
   setState(()=>entries.insertAll(0,additions));
   await persist();
   final prefs=await SharedPreferences.getInstance();
   final updatedHashes={...smsHashes,...newHashes};
   await prefs.setStringList('waffra_sms_hashes_v1',updatedHashes.toList());
   smsHashes.addAll(newHashes);
   if(!ctx.mounted)return;
   Navigator.pop(ctx);
   if(mounted)await showDialog<void>(context:context,builder:(dialogCtx)=>AlertDialog(
    title:Column(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.check_circle_rounded,color:Color(0xFF16805E),size:54),
     const SizedBox(height:16),
     WaffraText(waffraIsEnglish?'Transactions added successfully':'تمت إضافة المعاملات بنجاح',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:22)),
    ]),
    content:WaffraText(waffraIsEnglish
     ?'Saved: ${additions.length} • Income: ${incomes.length} • Expenses: ${expenses.length} • Not added: ${invalid.length}'
     :'تم الحفظ: ${additions.length} • دخل: ${incomes.length} • مصروفات: ${expenses.length} • لم تُضف: ${invalid.length}',textAlign:TextAlign.center),
    actionsAlignment:MainAxisAlignment.center,
    actionsPadding:const EdgeInsets.fromLTRB(24,0,24,18),
    actions:[SizedBox(width:180,child:FilledButton(onPressed:()=>Navigator.pop(dialogCtx),child:WaffraText(waffraIsEnglish?'Done':'تم')))]));
  }catch(e){
   setState(()=>entries.removeWhere((entry)=>additions.any((a)=>a.id==entry.id)));
   if(ctx.mounted){update(()=>busy=false);snack(ctx,waffraIsEnglish?'Failed to save transactions':'فشل حفظ المعاملات');}
  }
 }

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
   amount.text=result.amount==null?'':formatWaffraMoney(result.amount!);
  });
 }
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
  builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
   final available=forType(income);
   final total=messages.fold<double>(0,(sum,s)=>sum+(BankParser.parse(s).amount??0));
   return Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(ctx).viewInsets.bottom+24),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText('إضافة رسائل بنكية',style:Theme.of(ctx).textTheme.titleLarge),
     const SizedBox(height:12),
     if(!reviewing)...[
      TextField(controller:pasted,minLines:5,maxLines:9,onChanged:(text){
       pasteTimer?.cancel();
       if(!sheetActive||!ctx.mounted)return;
       update((){parsed=false;messages=[];statusMessage='';});
       if(text.trim().isNotEmpty){
        pasteTimer=Timer(const Duration(milliseconds:650),(){
         if(sheetActive&&ctx.mounted&&pasted.text.trim()==text.trim()){
          update((){messages=splitBankMessages(pasted.text.trim());parsed=true;});
         }
        });
       }
      },decoration:InputDecoration(labelText:waffraTr('الصق رسالة أو عدة رسائل بنكية'),
       hintText:waffraIsEnglish?'Paste your bank messages here. We will analyze them automatically.':'الصق رسالتك البنكية هنا، وخلّ الباقي علينا! بنحلّلها لك تلقائيًا ونرتّب مصروفاتك ودخلك.',border:OutlineInputBorder())),
      const SizedBox(height:12),
      OutlinedButton.icon(icon:const Icon(Icons.content_paste),
       onPressed:busy?null:()async {
        final data=await Clipboard.getData(Clipboard.kTextPlain);
        if(!ctx.mounted)return;
        final text=data?.text?.trim()??'';
        if(text.isEmpty){snack(ctx,waffraIsEnglish?'Clipboard is empty':'ما فيه رسالة منسوخة حاليًا');return;}
        pasted.text=text;
        pasteTimer?.cancel();
        update((){messages=splitBankMessages(text);parsed=true;statusMessage='';});
       },label:WaffraText(waffraIsEnglish?'Paste last copied message':'لصق آخر رسالة نسختها')),
      if(statusMessage.isNotEmpty)...[
       const SizedBox(height:8),
       WaffraText(statusMessage,style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w600)),
      ],
      if(rejectedMessages.isNotEmpty)...[
       const SizedBox(height:8),
       WaffraText(waffraIsEnglish?'Unrecognized messages — edit and retry':'رسائل لم يتم تحليلها — راجعها وأعد المحاولة',style:const TextStyle(fontWeight:FontWeight.bold)),
       ...rejectedMessages.asMap().entries.map((item)=>Card(child:ListTile(
        title:WaffraText(waffraIsEnglish?'Message ${item.key+1}':'رسالة ${item.key+1}'),
        subtitle:SelectableText(item.value,maxLines:4),
        trailing:IconButton(icon:const Icon(Icons.edit_outlined),tooltip:waffraIsEnglish?'Review manually':'مراجعة يدويًا',onPressed:(){
         Navigator.pop(ctx);
         entrySheet(sms:true,initialSms:item.value);
        }))),
      ],
      if(parsed&&statusMessage.isEmpty)...[
       const SizedBox(height:10),
       WaffraText(waffraIsEnglish?'Detected ${messages.length} transactions':'تم اكتشاف ${messages.length} معاملة',
        style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
       const SizedBox(height:8),
       FilledButton.icon(icon:const Icon(Icons.check_circle_outline),
        onPressed:busy?null:()=>saveParsedMessages(ctx,update),
        label:WaffraText(busy?'جارٍ الحفظ...':'تأكيد وحفظ المعاملات')),
      ],
      TextButton.icon(onPressed:()async{
       final yes=await confirmDeletion(
        waffraIsEnglish?'Clear pasted messages?':'حذف النص بالكامل',
        waffraIsEnglish?'Clear all pasted text? Unsaved messages will be lost.':'هل تريد حذف النص الملصوق بالكامل؟ ستفقد الرسائل غير المحفوظة.');
       if(yes!=true||!ctx.mounted)return;
       pasteTimer?.cancel();pasted.clear();
       update((){parsed=false;messages=[];});
      },icon:const Icon(Icons.delete_outline),label:const WaffraText('حذف النص بالكامل')),
     ]else...[
      TextButton.icon(onPressed:busy?null:()async{
       final yes=await confirmDeletion(
        waffraIsEnglish?'Clear pasted messages?':'حذف الرسائل الملصوقة',
        waffraIsEnglish?'Discard the unsaved pasted text and start again?':'هل تريد حذف الرسائل غير المحفوظة والبدء من جديد؟');
       if(yes!=true||!ctx.mounted)return;
       update((){reviewing=false;parsed=false;messages=[];index=0;pasted.clear();description.clear();amount.clear();});
      },icon:const Icon(Icons.delete_outline),label:const WaffraText('حذف النص بالكامل ولصق رسائل جديدة')),
      WaffraText(waffraIsEnglish?'Transaction ${index+1} of ${messages.length} — Total: ${cash(total)}':'المعاملة ${index+1} من ${messages.length} — إجمالي المبالغ: ${cash(total)}',style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      WaffraText(waffraIsEnglish?'Saved $savedCount of ${messages.length} transactions. Review and categorize each transaction before saving.':'تم حفظ $savedCount من ${messages.length} معاملات. راجع كل معاملة وحدد قسمها قبل الحفظ.'),
      const SizedBox(height:12),
      InputDecorator(decoration:InputDecoration(labelText:waffraTr('نص الرسالة الحالية'),border:OutlineInputBorder()),
       child:SelectableText(messages[index])),
      const SizedBox(height:12),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:WaffraText('دخل')),
       ButtonSegment(value:false,label:WaffraText('مصروف'))],selected:{income},onSelectionChanged:(v)=>update((){
        income=v.first;category=forType(income).isNotEmpty?forType(income).first.name:'أخرى';
       })),
      const SizedBox(height:12),
      TextField(controller:description,maxLines:2,decoration:InputDecoration(labelText:waffraTr('وصف الرسالة'),border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(labelText:waffraTr('مبلغ هذه الرسالة بالريال'),border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$index-$income'),initialValue:available.any((c)=>c.name==category)?category:(available.isNotEmpty?available.first.name:null),
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       decoration:InputDecoration(labelText:waffraTr('قسم هذه الرسالة'),border:OutlineInputBorder()),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      const SizedBox(height:12),
      FilledButton(onPressed:busy?null:()async{
       final n=amountOf(amount.text);
       if(n==null||description.text.trim().isEmpty){snack(ctx,'راجع وصف الرسالة والمبلغ');return;}
       final hash=bankSmsHash(messages[index]);
       if(smsHashes.contains(hash)){
        final yes=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
         title:const WaffraText('⚠️ رسالة مكررة'),content:const WaffraText('هذي الرسالة سبق حفظها. ودّك تضيفها مرة ثانية؟'),
         actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const WaffraText('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),child:const WaffraText('إضافة على أي حال'))]));
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
      },child:WaffraText(index+1==messages.length?'إضافة المعاملة وحفظها':'إضافة المعاملة وحفظها ثم التالي')),
      if(index+1<messages.length)TextButton(onPressed:busy?null:()=>prepare(index+1,update),child:const WaffraText('تخطي هذه الرسالة')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:busy?null:()async{
       final yes=await confirmDeletion(
        waffraIsEnglish?'Clear pasted messages?':'حذف الرسائل الملصوقة',
        waffraIsEnglish?'Discard all unsaved pasted text? Saved transactions will remain.':'هل تريد حذف النص غير المحفوظ؟ المعاملات المحفوظة ستظل موجودة.');
       if(yes!=true||!ctx.mounted)return;
       update((){reviewing=false;parsed=false;messages=[];index=0;savedCount=0;pasted.clear();description.clear();amount.clear();});
      },icon:const Icon(Icons.delete_forever_outlined),label:const WaffraText('حذف النص بالكامل وإضافة رسائل أخرى')),
     ],
    ])));
  }));
 sheetActive=false;disposeLater();
}

 Future<void> entrySheet({MoneyEntry? initial,bool sms=false,String? initialSms})async {
  final title=TextEditingController(text:initial?.title??'');
  final value=TextEditingController(text:initial==null?'':formatWaffraMoney(initial.amount));
  final message=TextEditingController(text:initialSms??'');
  bool income=initial?.income??false,analyzing=false,hasParsed=initialSms!=null;
  String category=initial?.category??'أخرى';
  DateTime date=initial?.date??DateTime.now();
   String? suggestion,pendingHash,receiptPath=initial?.receiptPath;
   bool attempted=false;
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
      final merchant=waffraMerchantKey(text);
      final learned=merchant==null?null:learnedMerchantCategories[merchant];
      update((){
       income=p.income;
       category=learned!=null&&categories.any((c)=>c.income==p.income&&c.name==learned)
        ?learned:p.suggestedCategory!=null&&categories.any((c)=>c.income==p.income&&c.name==p.suggestedCategory)
        ?p.suggestedCategory!:p.category;
       title.text=p.title;value.text=p.amount==null?'':formatWaffraMoney(p.amount!);
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
      WaffraText(initial!=null?'تعديل العملية':sms?'إضافة رسالة بنكية':'إضافة عملية',
       style:Theme.of(sheetContext).textTheme.titleLarge),
      const SizedBox(height:12),
      if(sms)...[
       TextField(controller:message,minLines:3,maxLines:6,
        onChanged:(v){parseNow(v);update((){});},
        decoration:InputDecoration(labelText:waffraIsEnglish?'Bank SMS *':'الرسالة البنكية *',
         hintText:waffraTr('أول ما تلصقها نحلّلها تلقائيًا'),
         errorText:attempted&&message.text.trim().isEmpty?
          (waffraIsEnglish?'Bank message is required':'الرسالة البنكية حقل إجباري'):null,
         border:OutlineInputBorder())),
       const SizedBox(height:8),
       if(analyzing)const LinearProgressIndicator(),
       if(hasParsed)WaffraText(value.text.isEmpty?'ما قدرنا نحدد المبلغ. اكتبه يدويًا.':
        'حلّلنا الرسالة. راجع التفاصيل قبل الحفظ.',style:const TextStyle(color:emerald)),
       const SizedBox(height:12),
      ],
      SegmentedButton<bool>(
       segments:const [ButtonSegment(value:true,label:WaffraText('دخل')),
        ButtonSegment(value:false,label:WaffraText('مصروف'))],
       selected:{income},onSelectionChanged:(v)=>update((){
        income=v.first;category=forType(income).isNotEmpty?forType(income).first.name:'أخرى';suggestion=null;
       })),
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'وصف العملية *',
        errorText:attempted&&WaffraValidators.requiredText(title.text)!=null?
         (waffraIsEnglish?'Description is required':'وصف العملية حقل إجباري'):null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted&&WaffraValidators.positiveAmount(value.text)!=null?
         (waffraIsEnglish?'Enter an amount greater than zero':'المبلغ حقل إجباري ويجب أن يكون أكبر من صفر'):null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$income-$chosen'),initialValue:chosen,
       decoration:InputDecoration(labelText:waffraTr('القسم'),border:OutlineInputBorder()),
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      if(suggestion!=null)TextButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income,suggested:suggestion);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update((){category=c.name;suggestion=null;});
       }
      },icon:const Icon(Icons.add),label:WaffraText('إضافة قسم $suggestion')),
      OutlinedButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update(()=>category=c.name);
       }
      },icon:const Icon(Icons.add),label:const WaffraText('قسم جديد')),
      OutlinedButton.icon(onPressed:()async {
       final d=await showDatePicker(context:sheetContext,initialDate:date,
        firstDate:DateTime(2000),lastDate:DateTime.now());
       if(d!=null)update(()=>date=d);
      },icon:const Icon(Icons.calendar_month),label:WaffraText(dayText(date))),
      const SizedBox(height:12),
      Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final file=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:80);
        if(file!=null){final path=await saveReceipt(file);if(sheetContext.mounted)update(()=>receiptPath=path);}
       },icon:const Icon(Icons.camera_alt_outlined),label:const WaffraText('تصوير فاتورة'))),
       const SizedBox(width:8),
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80);
        if(file!=null){final path=await saveReceipt(file);if(sheetContext.mounted)update(()=>receiptPath=path);}
       },icon:const Icon(Icons.attach_file),label:const WaffraText('إرفاق صورة'))),
      ]),
      if(receiptPath!=null)ListTile(
       title:WaffraText(receiptPath!.split('/').last.replaceFirst(RegExp(r'^\d+__'),'')),leading:const Icon(Icons.image,color:emerald),
       trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>update(()=>receiptPath=null)),
       onTap:()=>showReceipt(receiptPath!)),
      const SizedBox(height:12),
      FilledButton(onPressed:analyzing?null:()async {
       update(()=>attempted=true);
       final n=amountOf(value.text);
       if(WaffraValidators.requiredText(title.text)!=null||n==null)return;
       if(sms){
        if(message.text.trim().isEmpty)return;
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){
         final proceed=await showDialog<bool>(context:sheetContext,builder:(dialogContext)=>AlertDialog(
          title:const WaffraText('⚠️ الرسالة مكررة'),
          content:const WaffraText('هذي الرسالة البنكية أضفتها قبل كذا. ودّك تضيفها مرة ثانية؟'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const WaffraText('إلغاء')),
           FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const WaffraText('إضافة على أي حال'))]));
         if(proceed!=true||!sheetContext.mounted)return;
        }
        pendingHash=h;
       }
       Navigator.pop(sheetContext,MoneyEntry(id:initial?.id??newId(),title:title.text.trim(),
        category:category,amount:n,income:income,date:date,receiptPath:receiptPath));
      },child:const WaffraText('تأكيد وحفظ العملية')),
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
    title:const WaffraText('⚠️ عملية مكررة'),
    content:WaffraText('يبدو إنك أضفت نفس ${result.income?'الدخل':'المصروف'} من قبل. ودّك تضيفه مرة ثانية؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const WaffraText('إلغاء')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const WaffraText('إضافة على أي حال'))]));
   if(proceed!=true||!mounted)return;
  }
  final previousSpent=sum(entries.where((e)=>!e.income&&e.id!=result.id&&
   e.category==result.category&&e.date.year==result.date.year&&e.date.month==result.date.month),false);
  setState((){
   final i=entries.indexWhere((e)=>e.id==result.id);
   if(i>=0)entries[i]=result;else entries.insert(0,result);
   // Learn only explicit corrections made by the user, not assumptions
   // generated by bank message parsing.
   if(initial!=null&&initial.category!=result.category){
    final merchant=waffraMerchantKey(initial.title);
    if(merchant!=null)learnedMerchantCategories[merchant]=result.category;
   }
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
   TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إغلاق')),
  ])));
 }
 Future<void> budgetAlert(MoneyEntry entry,double previousSpent)async {
  if(entry.income)return;
  final category=categoryFor(entry.category,false);
  if(category.budget<=0)return;
  final spent=sum(entries.where((e)=>!e.income&&e.category==entry.category&&
   e.date.year==entry.date.year&&e.date.month==entry.date.month),false);
  final stages=<int>{50,80,100,category.alertPercent}.toList()..sort();
  int? crossed;
  for(final stage in stages){
   if(previousSpent<category.budget*stage/100&&spent>=category.budget*stage/100)crossed=stage;
  }
  if(crossed==null||!mounted)return;
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Budget alert':'⚠️ تنبيه ميزانية القسم'),
   content:WaffraText(waffraIsEnglish?
    '${category.name} has reached ${(spent/category.budget*100).round()}% of the budget (crossed $crossed%). Spent ${cash(spent)} out of ${cash(category.budget)}.':
    'وصل صرف قسم «${category.name}» إلى ${(spent/category.budget*100).round()}٪ من الميزانية (تجاوز حد $crossed٪). صرفت ${cash(spent)} من ${cash(category.budget)}.'),
   actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),
    child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
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
    ?(waffraIsEnglish?'Cannot export the analytics report. Add an income or expense transaction first.':'لا يمكن تصدير تقرير التحليلات. أضف عملية دخل أو مصروف أولاً.')
    :(waffraIsEnglish?'Cannot export the report. Add an income or expense transaction first.':'لا يمكن تصدير التقرير. يجب إضافة عملية دخل أو مصروف أولاً.'));
   return;
  }
  try{
   // Embed a full Arabic Unicode fallback; Tajawal stays the primary typeface.
   final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
   final bold=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
   final english=waffraIsEnglish;
   final exportedAt=DateTime.now();
   final oldest=items.map((e)=>e.date).reduce((a,b)=>a.isBefore(b)?a:b);
   final newest=items.map((e)=>e.date).reduce((a,b)=>a.isAfter(b)?a:b);
   // Keep stored descriptions unchanged; sanitize only the exported PDF copy.
   String pdfClean(String input)=>sanitizeWaffraPdfText(input);
      String fmt(num number){
    final n=number.toDouble();
    if(n==n.roundToDouble())return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
   }
   // Keep the approved two-page PDF as the canonical, bundled design asset.
   // The generated export below still supplies live financial values.
   // Rasterize the branded PDF template once, then draw it as the
   // background of every exported report page. Financial data stays dynamic.
   final templateData=await rootBundle.load('assets/Waffra_Riyadh_Report_Template.pdf');
   if(templateData.lengthInBytes==0)throw StateError('Waffra PDF template is empty');
   pw.MemoryImage? reportBackground;
   await for(final raster in Printing.raster(
     templateData.buffer.asUint8List(),pages:[0],dpi:120)){
    reportBackground=pw.MemoryImage(await raster.toPng());
    break;
   }
   if(reportBackground==null)throw StateError('Unable to render Waffra PDF template');
   final brandedBackground=reportBackground;
   final doc=pw.Document();
   final totalIncome=sum(items,true),totalExpenses=sum(items,false);
   final categoryTotals=<String,double>{};
   for(final e in items.where((e)=>!e.income)){categoryTotals[e.category]=(categoryTotals[e.category]??0)+e.amount;}
   pw.Widget summary(String label,double value,PdfColor bg)=>pw.Expanded(child:pw.Container(
    padding:const pw.EdgeInsets.all(10),decoration:pw.BoxDecoration(color:bg,borderRadius:pw.BorderRadius.circular(7)),
    child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
     pw.Text(waffraTr(label),style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.teal900)),
     pw.SizedBox(height:5),pw.Text('${fmt(value)} SAR',style:pw.TextStyle(font:bold,fontSize:15,color:PdfColors.teal900)),
    ])));
   // Explicit script direction prevents mixed Arabic/Latin SMS text from
   // overlapping or reversing adjacent numbers in the PDF viewer.
   pw.Widget pdfCell(String raw,{bool rtl=false,bool center=false})=>
    pw.Padding(padding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:7),
     child:pw.Text(pdfClean(raw),
      textDirection:rtl?pw.TextDirection.rtl:pw.TextDirection.ltr,
      textAlign:center?pw.TextAlign.center:(rtl?pw.TextAlign.right:pw.TextAlign.left),
      style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.black)));
   // Split SMS into readable script-specific lines. Long mixed Arabic/Latin
   // descriptions must wrap inside the description column, never overflow.
   // Flutter/Skia shapes mixed Arabic, English and numbers reliably.
   // The pdf package can create unsupported-glyph boxes for these same runs.
   // Rasterize ONLY the transaction description text at 2x resolution with
   // the app's Tajawal font, leaving dates, categories and amounts as PDF text.
   Future<(pw.MemoryImage,double)> pdfDescriptionArtwork(String raw)async {
    const scale=2.0,logicalWidth=460.0;
    final description=pdfClean(raw);
    final painter=TextPainter(
     text:TextSpan(text:description.isEmpty?'—':description,
      style:const TextStyle(fontFamily:'Tajawal',fontSize:18,
       height:1.38,color:Colors.black)),
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     textAlign:english?TextAlign.left:TextAlign.right,
     maxLines:8,ellipsis:'...',
    );
    // TextPainter otherwise shrinks to its longest run, so TextAlign.right
    // has no spare horizontal space to align against. Force the whole
    // raster canvas width (including mixed Arabic/Latin bank SMS).
    painter.layout(minWidth:logicalWidth,maxWidth:logicalWidth);
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    canvas.scale(scale,scale);
    painter.paint(canvas,Offset.zero);
    final picture=recorder.endRecording();
    final raster=await picture.toImage(
     (logicalWidth*scale).ceil(),max(1,(painter.height*scale).ceil()));
    final bytes=await raster.toByteData(format:ui.ImageByteFormat.png);
    final height=max(12.0,painter.height/scale);
    painter.dispose();
    raster.dispose();
    picture.dispose();
    if(bytes==null)throw StateError('Unable to rasterize bank SMS description');
    return (pw.MemoryImage(bytes.buffer.asUint8List()),height);
   }
   // The approved branded template remains unchanged; only its content layout is improved.
   final pageTheme=pw.PageTheme(
    pageFormat:const PdfPageFormat(900,600),
    margin:const pw.EdgeInsets.fromLTRB(36,115,36,90),
    buildBackground:(ctx)=>pw.FullPage(ignoreMargins:true,
     child:pw.Image(brandedBackground,fit:pw.BoxFit.fill)),
    theme:pw.ThemeData.withFont(base:font,bold:bold),
    textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
   );
   pw.Widget heading(String ar,String en)=>pw.Padding(
    padding:const pw.EdgeInsets.only(bottom:10),
    child:pw.Text(english?en:ar,style:pw.TextStyle(font:bold,fontSize:15,color:PdfColors.teal900)));
   if(!analytics){
    final ordered=items.toList()..sort((a,b)=>b.date.compareTo(a.date));
    final descriptions=<(pw.MemoryImage,double)>[];
    for(final e in ordered){descriptions.add(await pdfDescriptionArtwork(e.title));}
    doc.addPage(pw.MultiPage(
     pageTheme:pageTheme,
     footer:(ctx)=>pw.Align(alignment:pw.Alignment.centerRight,
      child:pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.teal900))),
     build:(ctx)=>[
      heading('تقرير الدخل والمصروفات','Income & Expenses Report'),
      pw.Row(children:[summary('إجمالي الدخل',totalIncome,PdfColors.green50),pw.SizedBox(width:8),
       summary('إجمالي المصروفات',totalExpenses,PdfColors.red50),pw.SizedBox(width:8),
       summary('الصافي',totalIncome-totalExpenses,PdfColors.amber50)]),
      pw.SizedBox(height:14),
      heading('تفاصيل العمليات','Transactions'),
      pw.Table(
       border:pw.TableBorder.all(color:PdfColors.grey400,width:0.4),
       columnWidths:{0:const pw.FixedColumnWidth(90),1:const pw.FixedColumnWidth(65),
        2:const pw.FixedColumnWidth(95),3:const pw.FlexColumnWidth(3),
        4:const pw.FixedColumnWidth(85)},
       children:[
        pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
         children:(english?['Date','Type','Category','Description','Amount (SAR)']:
          ['التاريخ','النوع','القسم','الوصف','المبلغ (ريال)'])
          .map((h)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
           child:pw.Text(h,textAlign:pw.TextAlign.center,style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.white)))).toList()),
        ...ordered.asMap().entries.map((row){
         final e=row.value,art=descriptions[row.key];
         return pw.TableRow(
         decoration:pw.BoxDecoration(color:e.income?const PdfColor.fromInt(0xFFB2D5C2):const PdfColor.fromInt(0xFFF0F7F2)),
         children:[
          pdfCell(dayText(e.date),center:true),
          pdfCell(english?(e.income?'Income':'Expense'):(e.income?'دخل':'مصروف'),rtl:!english),
          pdfCell(waffraTr(e.category),rtl:!english),
          pw.Container(
           alignment:english?pw.Alignment.centerLeft:pw.Alignment.centerRight,
           padding:const pw.EdgeInsets.symmetric(horizontal:6,vertical:7),
           child:pw.Directionality(
            textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
            child:pw.Align(
             alignment:english?pw.Alignment.centerLeft:pw.Alignment.centerRight,
             child:pw.Image(art.$1,height:art.$2,fit:pw.BoxFit.scaleDown)))),
          pdfCell('${e.income?'+':'-'}${fmt(e.amount)}',center:true),
         ],
        );
        }),
       ],
      ),
     ]));
   }else{
    final yearly=title.contains('سنوي');
    final periods=yearly?12:5;
    final groups=List.generate(periods,(i)=>items.where((e)=>yearly?
     e.date.month==i+1:((e.date.day-1)~/7)==i).toList());
    final active=List.generate(periods,(i)=>i).where((i)=>groups[i].isNotEmpty).toList();
    final maxValue=groups.expand<double>((g)=>[sum(g,true),sum(g,false)]).fold<double>(1.0,(largest,value)=>max(largest,value));
    pw.Widget bar(double value,PdfColor color)=>pw.Expanded(child:pw.Row(children:[
     pw.Expanded(flex:max(1,(value/maxValue*100).round()),
      child:pw.Container(height:13,color:color)),
     pw.Expanded(flex:max(1,100-(value/maxValue*100).round()),
      child:pw.SizedBox(height:13)),
    ]));
    doc.addPage(pw.Page(pageTheme:pageTheme,build:(ctx)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
     heading('تقرير التحليلات المالية','Financial Analytics'),
     pw.Container(padding:const pw.EdgeInsets.all(12),decoration:pw.BoxDecoration(border:pw.Border.all(color:PdfColors.grey400,width:1),borderRadius:pw.BorderRadius.circular(9)),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
     heading('الدخل والمصروفات حسب الفترة','Income vs Expenses by Period'),
     ...active.map((i)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:7),
      child:pw.Row(children:[
       pw.SizedBox(width:65,child:pw.Text(yearly?'${i+1}':'${english?'Week':'أسبوع'} ${i+1}',
        style:pw.TextStyle(font:font,fontSize:10))),
       pw.Expanded(child:pw.Column(children:[
        pw.Row(children:[pw.SizedBox(width:48,child:pw.Text(english?'Income':'دخل',style:pw.TextStyle(font:font,fontSize:9))),
         bar(sum(groups[i],true),PdfColors.teal),pw.SizedBox(width:62,child:pw.Text(fmt(sum(groups[i],true)),style:pw.TextStyle(font:font,fontSize:9)))]),
        pw.SizedBox(height:5),
        pw.Row(children:[pw.SizedBox(width:48,child:pw.Text(english?'Expense':'مصروف',style:pw.TextStyle(font:font,fontSize:9))),
         bar(sum(groups[i],false),PdfColors.deepOrange),pw.SizedBox(width:62,child:pw.Text(fmt(sum(groups[i],false)),style:pw.TextStyle(font:font,fontSize:9)))]),
       ])),
      ]))),
     ])),
     if(totalExpenses>0)...[
      pw.SizedBox(height:12),
      pw.Container(padding:const pw.EdgeInsets.all(12),decoration:pw.BoxDecoration(border:pw.Border.all(color:PdfColors.grey400,width:1),borderRadius:pw.BorderRadius.circular(9)),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      heading('توزيع المصروفات حسب الفئات','Expenses by Category'),
      pw.Center(child:pw.SvgImage(svg:expensePieSvg(categoryTotals),width:150,height:150)),
      pw.SizedBox(height:10),
      ...((categoryTotals.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).take(7)
       .map((e)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:4),
        child:pw.Row(children:[
         pw.SizedBox(width:145,child:pw.Text(waffraTr(e.key),style:pw.TextStyle(font:font,fontSize:10))),
         pw.Expanded(child:pw.Row(children:[pw.Expanded(flex:max(1,(e.value/totalExpenses*100).round()),child:pw.Container(height:12,color:PdfColors.teal)),pw.Expanded(flex:max(1,100-(e.value/totalExpenses*100).round()),child:pw.SizedBox(height:12))])),
         pw.SizedBox(width:90,child:pw.Text('${(e.value/totalExpenses*100).toStringAsFixed(1)}%',
          style:pw.TextStyle(font:bold,fontSize:10))),
        ])))),
      ])),
     ],
    ])));
   }
   final bytes=await doc.save();
   // Android print dialog can be unavailable on some devices; share the PDF as fallback.
   await Printing.sharePdf(bytes:bytes,filename:'waffra_report.pdf');
  }catch(e,st){debugPrint('PDF export error: $e\n$st');if(mounted)snack(context,'تعذّر إنشاء PDF: $e');}
 }
 Future<void> deleteEntry(MoneyEntry e)async {
  final yes=await confirmDeletion(waffraIsEnglish?'Delete transaction':'حذف العملية',
   waffraIsEnglish?'Delete «'+e.title+'»? You can undo for 6 seconds after deletion.':'هل تريد حذف المعاملة «'+e.title+'»؟ يمكنك التراجع خلال 6 ثوانٍ بعد الحذف.');
  if(yes!=true||!mounted)return;
  setState(()=>entries.removeWhere((x)=>x.id==e.id));
  await persist();
  if(!mounted)return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
   duration:const Duration(seconds:6),
   content:WaffraText(waffraIsEnglish?'Transaction deleted':'تم حذف العملية'),
   action:SnackBarAction(
    label:waffraIsEnglish?'Undo':'تراجع',
    onPressed:()async{
     if(!mounted||entries.any((x)=>x.id==e.id))return;
     setState(()=>entries.insert(0,e));
     await persist();
    }),
  ));
 }
 Widget stat(String label,double value,IconData icon,Color color)=>Expanded(
  child:Card(child:Padding(padding:const EdgeInsets.all(12),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:color),const SizedBox(height:8),WaffraText(label),const SizedBox(height:6),
    FittedBox(child:RiyalAmount(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
   ]))));
 Widget tile(MoneyEntry e){
  final c=categoryFor(e.category,e.income);
  return Card(color:e.income?const Color(0xFFB2D5C2):const Color(0xFFF0F7F2),child:ListTile(
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
    child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:WaffraText(e.title),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    WaffraText('${e.category} • ${dayText(e.date)}'),
    if(e.receiptPath!=null)InkWell(onTap:()=>showReceipt(e.receiptPath!),
     child:const Padding(padding:EdgeInsets.only(top:4),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.attach_file,size:15,color:emerald),WaffraText('عرض الفاتورة',style:TextStyle(color:emerald))]))),
   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    Column(mainAxisSize:MainAxisSize.min,children:[
     Text('${e.income?'+':'-'}${cash(e.amount)}',style:TextStyle(fontFamily:'Tajawal',fontSize:18,fontWeight:FontWeight.w800,color:e.income?emerald:null)),
     WaffraText(waffraIsEnglish?'SAR':'ريال',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:e.income?emerald:null)),
    ]),
    PopupMenuButton<String>(onSelected:(v){
     if(v=='edit')entrySheet(initial:e);else deleteEntry(e);
    },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:WaffraText('تعديل')),
     PopupMenuItem(value:'delete',child:WaffraText('حذف'))]),
   ])));
 }
 String get greeting {
  final name=widget.profile.name.trim();
  if(name=='يا غالي'||name.isEmpty)return waffraTr('يا هلا وغلا 👋');
  if(waffraIsEnglish)return 'Welcome, $name 👋';
  final female=widget.profile.gender=='أنثى'||widget.profile.gender.toLowerCase()=='female';
  return '${female?'يا هلا وغلا ونورتي':'يا هلا وغلا ونورت'} يا $name 👋';
 }
 Future<void> confirmDeleteAllEntries() async {
  if(entries.isEmpty){snack(context,waffraIsEnglish?'No transactions to delete':'لا توجد معاملات لحذفها');return;}
  final confirmed=await confirmDeletion(
   waffraIsEnglish?'Delete all transactions?':'حذف كل المعاملات؟',
   waffraIsEnglish?'Delete all ${entries.length} recorded transactions permanently? This cannot be undone.':'سيتم حذف جميع المعاملات المسجلة وعددها ${entries.length} نهائيًا، ولا يمكن التراجع عن هذا الإجراء.');
  if(confirmed!=true||!mounted)return;
  final backup=List<MoneyEntry>.of(entries);
  final hashBackup=Set<String>.of(smsHashes);
  setState((){entries.clear();smsHashes.clear();});
  try {
   final prefs=await SharedPreferences.getInstance();
   final saved=await prefs.setString('entries','[]');
   final cleared=await prefs.setStringList('waffra_sms_hashes_v1',<String>[]);
   if(!saved||!cleared)throw StateError('Failed to persist deletion');
   if(mounted)snack(context,waffraIsEnglish?'All transactions deleted':'تم حذف جميع المعاملات');
  }catch(e){
   if(mounted){setState((){entries.addAll(backup);smsHashes.addAll(hashBackup);});snack(context,waffraIsEnglish?'Delete failed':'فشل حذف المعاملات');}
  }
 }
 Future<void> editMonthlyBudget()async {
  final amount=TextEditingController(text:monthlyBudget==0?'':monthlyBudget.toStringAsFixed(0));
  try{
   final next=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Monthly budget':'الميزانية الشهرية'),
    content:TextField(controller:amount,autofocus:true,
     keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Spending limit (SAR)':'حد المصروفات بالريال',
      helperText:waffraIsEnglish?'Enter 0 to disable':'أدخل 0 لإيقاف الميزانية',
      border:const OutlineInputBorder())),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:(){
      final v=double.tryParse(amount.text.trim().replaceAll(',',''));
      if(v==null||!v.isFinite||v<0){
       ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content:WaffraText(waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا')));
       return;
      }
      Navigator.pop(ctx,v);
     },child:WaffraText(waffraIsEnglish?'Save':'حفظ')),
    ]));
   if(next!=null&&mounted){setState(()=>monthlyBudget=next);await persist();}
  }finally{disposeLater([amount]);}
 }
 Future<void> editTransactionFilters()async {
  final min=TextEditingController(text:minTransactionAmount?.toStringAsFixed(2)??'');
  final max=TextEditingController(text:maxTransactionAmount?.toStringAsFixed(2)??'');
  DateTimeRange? chosen=transactionsDateRange;
  try{
   await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(
    builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Advanced filters':'فلترة بالتاريخ والمبلغ'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:min,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Minimum amount':'أقل مبلغ',
        border:const OutlineInputBorder())),
      const SizedBox(height:10),
      TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Maximum amount':'أعلى مبلغ',
        border:const OutlineInputBorder())),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:()async{
       final range=await showDateRangePicker(context:ctx,
        firstDate:DateTime(2000),lastDate:DateTime.now(),
        initialDateRange:chosen);
       if(range!=null)update(()=>chosen=range);
      },icon:const Icon(Icons.date_range),
       label:WaffraText(chosen==null
        ?(waffraIsEnglish?'Choose date range':'حدد فترة زمنية')
        :dayText(chosen!.start)+' - '+dayText(chosen!.end))),
     ])),
     actions:[
      TextButton(onPressed:(){
       setState((){
        transactionsDateRange=null;minTransactionAmount=null;maxTransactionAmount=null;
       });
       Navigator.pop(ctx);
      },child:WaffraText(waffraIsEnglish?'Clear':'مسح الفلاتر')),
      FilledButton(onPressed:(){
       final lo=min.text.trim().isEmpty?null:double.tryParse(min.text.trim());
       final hi=max.text.trim().isEmpty?null:double.tryParse(max.text.trim());
       if((min.text.trim().isNotEmpty&&lo==null)||
          (max.text.trim().isNotEmpty&&hi==null)||
          (lo!=null&&(!lo.isFinite||lo<0))||
          (hi!=null&&(!hi.isFinite||hi<0))||
          (lo!=null&&hi!=null&&lo>hi)){
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
         content:WaffraText(waffraIsEnglish?'Check amount limits':'تأكد من حدود المبلغ')));
        return;
       }
       setState((){
        transactionsDateRange=chosen;minTransactionAmount=lo;maxTransactionAmount=hi;
       });
       Navigator.pop(ctx);
      },child:WaffraText(waffraIsEnglish?'Apply':'تطبيق')),
     ])));
  }finally{disposeLater([min,max]);}
 }
 Widget monthlyBudgetCard(){
  final today=DateTime.now();
  final monthEntries=entries.where((e)=>e.date.year==today.year&&e.date.month==today.month);
  final spent=sum(monthEntries,false);
  final used=monthlyBudget>0?(spent/monthlyBudget).clamp(0.0,1.0):0.0;
  return Container(
   padding:const EdgeInsets.all(15),
   decoration:BoxDecoration(color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(20),
    border:Border.all(color:forest.withValues(alpha:0.10)),
    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),
     blurRadius:8,offset:const Offset(0,3))]),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.donut_large,color:emerald,size:23),
     const SizedBox(width:8),
     Expanded(child:WaffraText(waffraIsEnglish?'Monthly budget':'الميزانية الشهرية',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
     TextButton.icon(onPressed:editMonthlyBudget,
      icon:const Icon(Icons.edit_outlined,size:17),
      label:WaffraText(waffraIsEnglish?'Edit':'تحديد الميزانية')),
    ]),
    const SizedBox(height:7),
    if(monthlyBudget>0)...[
     WaffraText(waffraIsEnglish?
      'Used '+(used*100).toStringAsFixed(0)+'% of your budget':
      'تم إنفاق '+(used*100).toStringAsFixed(0)+'٪ من ميزانيتك',
      style:const TextStyle(fontSize:13)),
     const SizedBox(height:8),
     ClipRRect(borderRadius:BorderRadius.circular(12),
      child:LinearProgressIndicator(value:used,minHeight:9,
       backgroundColor:emerald.withValues(alpha:0.10),
       valueColor:AlwaysStoppedAnimation<Color>(
        spent>=monthlyBudget?Colors.deepOrange:emerald))),
     const SizedBox(height:14),
     Row(children:[
      Expanded(child:_budgetFigure(waffraIsEnglish?'Budget':'الميزانية',monthlyBudget)),
      Expanded(child:_budgetFigure(waffraIsEnglish?'Spent':'المصروف',spent)),
      Expanded(child:_budgetFigure(waffraIsEnglish?'Remaining':'المتبقي',
       max(0.0,monthlyBudget-spent))),
     ]),
     if(spent>=monthlyBudget*.8)Padding(
      padding:const EdgeInsets.only(top:10),
      child:WaffraText(waffraIsEnglish?
       (spent>=monthlyBudget?'Monthly budget reached.':'80% of budget used.'):
       (spent>=monthlyBudget?'وصلت لحد الميزانية الشهرية.':'استهلكت 80٪ من الميزانية.'),
       style:const TextStyle(color:Colors.deepOrange,fontSize:13))),
    ]else Padding(padding:const EdgeInsets.symmetric(vertical:7),
     child:WaffraText(waffraIsEnglish?
      'Set your monthly budget to track spending here.':
      'حدّد ميزانية شهرية عشان تتابع مصروفاتك والمتبقي منها.',
      style:const TextStyle(fontSize:14,color:Colors.grey))),
   ]));
 }
 Widget _budgetFigure(String label,double amount)=>Column(
  mainAxisSize:MainAxisSize.min,children:[
   WaffraText(label,textAlign:TextAlign.center,
    style:const TextStyle(color:Colors.grey,fontSize:12)),
   const SizedBox(height:5),
   FittedBox(fit:BoxFit.scaleDown,
    child:WaffraCurrencyAmount(amount,fontSize:16,color:emerald)),
  ]);
 Widget monthlySummaryCard(){
  final today=DateTime.now();
  final prev=DateTime(today.year,today.month-1,1);
  final current=entries.where((e)=>!e.income&&
   e.date.year==today.year&&e.date.month==today.month);
  final lastMonth=entries.where((e)=>!e.income&&
   e.date.year==prev.year&&e.date.month==prev.month);
  final spent=sum(current,false),prior=sum(lastMonth,false);
  final categoriesTotal=<String,double>{};
  for(final item in current){
   categoriesTotal[item.category]=(categoriesTotal[item.category]??0)+item.amount;
  }
  final ranked=categoriesTotal.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final top=ranked.isEmpty?null:ranked.first;
  final change=prior<=0?null:(spent-prior)/prior*100;
  return Container(
   padding:const EdgeInsets.all(15),
   decoration:BoxDecoration(color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(20),
    border:Border.all(color:forest.withValues(alpha:0.10))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.bar_chart_rounded,color:emerald),
     const SizedBox(width:8),
     Expanded(child:WaffraText(waffraIsEnglish?'Monthly summary':'ملخص الشهر',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
    ]),
    const SizedBox(height:10),
    if(top==null)WaffraText(waffraIsEnglish?
      'No expenses recorded this month.':
      'لا توجد مصروفات مسجلة لهذا الشهر.',
      style:const TextStyle(color:Colors.grey,fontSize:14))
    else Container(
     padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
     decoration:BoxDecoration(color:emerald.withValues(alpha:0.08),
      borderRadius:BorderRadius.circular(14)),
     child:Row(children:[
      const CircleAvatar(backgroundColor:Color(0xFFD8EDE0),
       child:Icon(Icons.pie_chart_outline,color:emerald)),
      const SizedBox(width:8),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Highest spending category':
        'أكثر قسم صرفت عليه',style:const TextStyle(fontSize:12)),
       WaffraText(waffraTr(top.key),maxLines:2,
        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
      ])),
      const SizedBox(width:4),
      FittedBox(fit:BoxFit.scaleDown,
       child:WaffraCurrencyAmount(top.value,fontSize:16,color:emerald)),
     ])),
    if(change!=null)Padding(padding:const EdgeInsets.only(top:9),
     child:WaffraText((waffraIsEnglish?'Spending ':'المصروفات ')+
      (change>=0?(waffraIsEnglish?'increased ':'زادت '):
       (waffraIsEnglish?'decreased ':'قلت '))+
      change.abs().toStringAsFixed(1)+'%'+
      (waffraIsEnglish?' vs last month':' عن الشهر الماضي'),
      style:const TextStyle(color:Colors.grey,fontSize:12))),
   ]));
 }
 Widget smartMoneyInsightsCard(){
  final now=DateTime.now();
  final monthExpenses=entries.where((e)=>!e.income&&e.date.year==now.year&&e.date.month==now.month);
  final spent=sum(monthExpenses,false);
  final variableSpent=sum(monthExpenses.where((e)=>!e.id.startsWith('rec_')),false);
  final remaining=DateTime(now.year,now.month+1,0).day-now.day;
  final pending=recurring.where((r)=>r.active&&r.day>now.day&&
   !entries.any((e)=>e.id=='rec_${r.id}_${now.year}_${now.month}'));
  final pendingIncome=pending.where((r)=>r.income).fold<double>(0,(v,r)=>v+r.amount);
  final pendingExpense=pending.where((r)=>!r.income).fold<double>(0,(v,r)=>v+r.amount);
  final balance=sum(entries,true)-sum(entries,false);
  final projection=WaffraFinancialInsights.projectedEndBalance(
   currentBalance:balance,variableExpensesSoFar:variableSpent,daysElapsed:now.day,
   daysInMonth:DateTime(now.year,now.month+1,0).day,
   pendingRecurringIncome:pendingIncome,pendingRecurringExpense:pendingExpense);
  final daily=WaffraFinancialInsights.dailyAllowance(
   monthlyBudget:monthlyBudget,spent:spent,daysRemaining:remaining+1);
  final prev=DateTime(now.year,now.month-1);
  final prevTotal=sum(entries.where((e)=>!e.income&&e.date.year==prev.year&&e.date.month==prev.month),false);
  final delta=WaffraFinancialInsights.comparisonPercent(spent,prevTotal);
  final warnings=categories.where((c)=>!c.income&&c.budget>0&&
   WaffraFinancialInsights.budgetAlertStage(
    sum(monthExpenses.where((e)=>e.category==c.name),false),c.budget)>=80).toList();
  return Card(
   elevation:1.0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(21)),
   child:Padding(padding:const EdgeInsets.all(15),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.auto_graph,color:emerald),const SizedBox(width:7),
     Expanded(child:WaffraText(waffraIsEnglish?'Your smart financial snapshot':'نظرتك المالية الذكية',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),
    ]),
    const SizedBox(height:12),
    Row(children:[
     Expanded(child:_summaryBox(waffraIsEnglish?'End-of-month estimate':'الرصيد المتوقع آخر الشهر',
      cash(projection),Icons.trending_up,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Daily spending limit':'الحد اليومي المقترح',
      monthlyBudget>0?cash(daily):(waffraIsEnglish?'Set a budget':'حدد ميزانية'),
      Icons.today_outlined,Colors.deepOrange)),
    ]),
    const SizedBox(height:9),
    if(delta!=null)WaffraText(waffraIsEnglish?
     'Monthly comparison: spending ${delta>=0?'up':'down'} ${delta.abs().toStringAsFixed(1)}%':
     'مقارنة بالشهر السابق: المصروفات ${delta>=0?'زادت':'قلت'} ${delta.abs().toStringAsFixed(1)}٪',
     style:const TextStyle(fontSize:12)),
    if(warnings.isNotEmpty)Padding(padding:const EdgeInsets.only(top:9),
     child:WaffraText(waffraIsEnglish?
      'Budget warning: ${warnings.map((c)=>c.name).join('، ')}':
      'تنبيه: اقتربت ميزانية ${warnings.map((c)=>c.name).join('، ')} من النفاد',
      style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold,fontSize:12))),
    const SizedBox(height:9),
    WaffraText(waffraIsEnglish?
     'Estimate based on recorded spending and upcoming recurring transactions, not a guaranteed balance.':
     'التوقع تقديري بناءً على الصرف المسجل والعمليات المتكررة القادمة، وليس رصيدًا مضمونًا.',
     style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
   ])));
 }
 Future<void> showSummaryTransactions(bool income)async {
  final items=entries.where((e)=>e.income==income).toList()
   ..sort((a,b)=>b.date.compareTo(a.date));
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   useSafeArea:true,builder:(ctx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.58,minChildSize:.32,maxChildSize:.90,
    builder:(ctx,scroll)=>Column(children:[
     Padding(padding:const EdgeInsets.fromLTRB(18,4,18,12),
      child:Row(children:[
       Icon(income?Icons.trending_up:Icons.trending_down,
        color:income?emerald:Colors.deepOrange),
       const SizedBox(width:9),
       Expanded(child:WaffraText(income?
        (waffraIsEnglish?'Income transactions':'عمليات الدخل'):
        (waffraIsEnglish?'Expense transactions':'عمليات المصروفات'),
        style:Theme.of(ctx).textTheme.titleLarge)),
       IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close)),
      ])),
     Container(
      margin:const EdgeInsets.symmetric(horizontal:16),
      padding:const EdgeInsets.all(16),
      width:double.infinity,
      decoration:BoxDecoration(color:(income?emerald:Colors.deepOrange).withValues(alpha:.10),
       borderRadius:BorderRadius.circular(18)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Total: ${items.length} transactions':
        'الإجمالي • ${items.length} عملية'),
       WaffraText(cash(sum(items,income)),
        style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      ])),
     const SizedBox(height:10),
     Expanded(child:items.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(income?Icons.savings_outlined:Icons.receipt_long_outlined,
       size:66,color:emerald.withValues(alpha:.6)),
      const SizedBox(height:10),
      WaffraText(waffraIsEnglish?'No transactions yet':'لا توجد عمليات حتى الآن'),
     ])):ListView.separated(controller:scroll,padding:const EdgeInsets.fromLTRB(16,4,16,24),
      itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),
      itemBuilder:(_,index){
       final e=items[index],cat=categoryFor(e.category,e.income);
       return ListTile(
        leading:CircleAvatar(backgroundColor:Color(cat.color).withValues(alpha:.13),
         child:Icon(categoryIcon(cat.icon),color:Color(cat.color))),
        title:WaffraText(e.title,maxLines:2,overflow:TextOverflow.ellipsis),
        subtitle:WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(fontSize:12)),
        trailing:WaffraText(cash(e.amount),
         style:TextStyle(fontWeight:FontWeight.bold,color:income?emerald:Colors.deepOrange)));
      })),
    ])));
 }
 Widget homeSummaryCard(String label,double value,IconData symbol,Color color,Color tint)=>
  Expanded(child:InkWell(
   onTap:()=>showSummaryTransactions(label=='الدخل'||label=='Income'),
   borderRadius:BorderRadius.circular(19),
   child:Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),
    decoration:BoxDecoration(
     color:Theme.of(context).brightness==Brightness.dark?Theme.of(context).cardColor:tint,
     borderRadius:BorderRadius.circular(19),
     border:Border.all(color:color.withValues(alpha:0.10)),
     boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),
      blurRadius:7,offset:const Offset(0,3))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Row(textDirection:TextDirection.rtl,children:[
      Expanded(child:WaffraText(label,textAlign:TextAlign.right,
       style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
      const SizedBox(width:6),
      CircleAvatar(backgroundColor:color.withValues(alpha:0.12),
       radius:19,child:Icon(symbol,color:color,size:21)),
     ]),
     const SizedBox(height:9),
     Align(alignment:Alignment.centerRight,
      child:FittedBox(fit:BoxFit.scaleDown,
       child:WaffraCurrencyAmount(value,fontSize:19))),
    ]))));
 Widget compactTransaction(MoneyEntry entry){
  final cat=categoryFor(entry.category,entry.income);
  final valueColor=entry.income?emerald:Colors.deepOrange;
  return Column(children:[
   Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
    CircleAvatar(radius:18,
     backgroundColor:Color(cat.color).withValues(alpha:0.13),
     child:Icon(categoryIcon(cat.icon),size:19,color:Color(cat.color))),
    const SizedBox(width:8),
    Expanded(child:InkWell(onTap:()=>entrySheet(initial:entry),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      WaffraText(entry.title,maxLines:1,
       style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
      const SizedBox(height:2),
      WaffraText(waffraTr(entry.category)+' • '+dayText(entry.date),
       maxLines:1,style:const TextStyle(fontSize:11,color:Colors.grey)),
     ]))),
    const SizedBox(width:5),
    ConstrainedBox(constraints:const BoxConstraints(maxWidth:119),
     child:FittedBox(fit:BoxFit.scaleDown,
      child:WaffraCurrencyAmount(entry.income?entry.amount:-entry.amount,
       fontSize:15,color:valueColor))),
    PopupMenuButton<String>(
     tooltip:waffraIsEnglish?'Transaction options':'خيارات العملية',
     onSelected:(action){
      if(action=='edit')entrySheet(initial:entry);
      if(action=='delete')deleteEntry(entry);
     },
     icon:const Icon(Icons.more_vert,size:18),
     itemBuilder:(ctx)=>[
      PopupMenuItem(value:'edit',
       child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
      PopupMenuItem(value:'delete',
       child:WaffraText(waffraIsEnglish?'Delete':'حذف',
        style:const TextStyle(color:Colors.red))),
     ]),
   ])),
   Divider(height:1,color:forest.withValues(alpha:0.09)),
  ]);
 }
 Widget dashboard(){
  final inc=sum(entries,true),exp=sum(entries,false);
  final visible=entries.where((e){
   final q=search.trim().toLowerCase();
   return(e.title.toLowerCase().contains(q)||e.category.toLowerCase().contains(q))&&
    (transactionsDateRange==null||(e.date.isAfter(transactionsDateRange!.start.subtract(const Duration(days:1)))&&e.date.isBefore(transactionsDateRange!.end.add(const Duration(days:1)))))&&
    (minTransactionAmount==null||e.amount>=minTransactionAmount!)&&
    (maxTransactionAmount==null||e.amount<=maxTransactionAmount!)&&
    (typeFilter=='الكل'||(typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income))&&
    (categoryFilter=='الكل'||categoryFilter==e.category);
  }).toList()..sort((a,b)=>b.date.compareTo(a.date));
  final filterCats=<String>{'الكل',...entries.where((e)=>typeFilter=='الكل'||
   (typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income)).map((e)=>e.category)}.toList();
  final selected=filterCats.contains(categoryFilter)?categoryFilter:'الكل';
  final shown=showAllTransactions?visible:visible.take(5).toList();
  return RefreshIndicator(
   onRefresh:()async{
    if(mounted)setState((){});
    await Future<void>.delayed(const Duration(milliseconds:150));
   },
   child:NotificationListener<ScrollStartNotification>(
    onNotification:(notification){
     if(addFabExpanded){
      WidgetsBinding.instance.addPostFrameCallback((_){
       if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
      });
     }
     return false;
    },
    child:CustomScrollView(
     physics:const AlwaysScrollableScrollPhysics(),
     slivers:[
      SliverToBoxAdapter(child:Padding(
       padding:const EdgeInsets.fromLTRB(15,12,15,10),
       child:WaffraText(greeting,
        style:Theme.of(context).textTheme.titleLarge))),
      // Not pinned: the shrinking balance scrolls away without covering data.
      SliverPersistentHeader(
       pinned:false,
       delegate:WaffraBalanceHeader(balance:inc-exp,english:waffraIsEnglish,focusKey:_tourKeys[0])),
      SliverPadding(padding:const EdgeInsets.fromLTRB(14,10,14,96),
       sliver:SliverToBoxAdapter(child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(children:[
          homeSummaryCard(waffraIsEnglish?'Income':'الدخل',
           inc,Icons.south_west,emerald,const Color(0xFFEFF8F3)),
          const SizedBox(width:9),
          homeSummaryCard(waffraIsEnglish?'Expenses':'المصروفات',
           exp,Icons.north_east,Colors.deepOrange,const Color(0xFFFDF4F2)),
         ]),
         const SizedBox(height:12),
         monthlyBudgetCard(),
         const SizedBox(height:12),
         monthlySummaryCard(),
         const SizedBox(height:12),
         smartMoneyInsightsCard(),
         const SizedBox(height:12),
         Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(
           color:Theme.of(context).cardColor,
           borderRadius:BorderRadius.circular(20),
           border:Border.all(color:forest.withValues(alpha:0.10))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Row(children:[
            const Icon(Icons.receipt_long_outlined,color:emerald),
            const SizedBox(width:7),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Your transactions':'عملياتك المالية',
             style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
            TextButton(onPressed:()=>setState((){
             showAllTransactions=!showAllTransactions;
             if(showAllTransactions){
              typeFilter='الكل';categoryFilter='الكل';search='';
              minTransactionAmount=null;maxTransactionAmount=null;
              transactionsDateRange=null;
             }
            }),child:WaffraText(showAllTransactions?
             (waffraIsEnglish?'Show less':'عرض أقل'):
             (waffraIsEnglish?'View all':'عرض الكل'))),
           ]),
           Divider(color:forest.withValues(alpha:0.10)),
           Row(children:[
            IconButton(
             tooltip:waffraIsEnglish?'Filter':'فلترة',
             onPressed:()=>setState(()=>showTransactionFilters=!showTransactionFilters),
             icon:Icon(showTransactionFilters?
              Icons.filter_alt:Icons.filter_alt_outlined,color:emerald)),
            IconButton(
             tooltip:waffraIsEnglish?'Search':'بحث',
             onPressed:()=>setState((){
              showTransactionSearch=!showTransactionSearch;
              if(!showTransactionSearch)search='';
             }),icon:const Icon(Icons.search)),
            if(showTransactionSearch)Expanded(child:TextField(
             onChanged:(v)=>setState(()=>search=v),
             decoration:InputDecoration(isDense:true,
              hintText:waffraIsEnglish?'Search':'ابحث عن عملية',
              border:const OutlineInputBorder()))),
            if(!showTransactionSearch)const Spacer(),
            PopupMenuButton<String>(
             tooltip:waffraIsEnglish?'More actions':'المزيد من الخيارات',
             icon:const Icon(Icons.more_vert),
             onSelected:(action){
              if(action=='delete-all')confirmDeleteAllEntries();
              if(action=='pdf')exportEntriesPdf(visible,'تقرير عمليات وفرة');
             },
             itemBuilder:(ctx)=>[
              PopupMenuItem(value:'pdf',child:Row(children:[
               const Icon(Icons.picture_as_pdf_outlined,color:emerald),
               const SizedBox(width:8),
               WaffraText(waffraIsEnglish?'Export PDF':'تصدير PDF'),
              ])),
              PopupMenuItem(value:'delete-all',enabled:entries.isNotEmpty,
               child:Row(children:[
                const Icon(Icons.delete_outline,color:Colors.red),
                const SizedBox(width:8),
                WaffraText(waffraIsEnglish?'Delete all transactions':'حذف كل المعاملات',
                 style:const TextStyle(color:Colors.red)),
               ])),
             ],
            ),
           ]),
           if(showTransactionFilters)...[
            const SizedBox(height:8),
            Wrap(spacing:6,runSpacing:6,
             children:['الكل','الدخل','المصروفات'].map((choice)=>ChoiceChip(
              selected:typeFilter==choice,
              label:WaffraText(waffraIsEnglish?
               (choice=='الكل'?'All':choice=='الدخل'?'Income':'Expenses'):choice),
              onSelected:(_)=>setState((){
               typeFilter=choice;categoryFilter='الكل';
              }))).toList()),
            DropdownButtonFormField<String>(
             key:ValueKey(typeFilter+'-'+selected),initialValue:selected,
             decoration:InputDecoration(labelText:waffraIsEnglish?
              'Category':'تصفية حسب القسم'),
             items:filterCats.map((value)=>DropdownMenuItem(
              value:value,child:WaffraText(waffraTr(value)))).toList(),
             onChanged:(value)=>setState(()=>categoryFilter=value??'الكل')),
            Align(alignment:AlignmentDirectional.centerStart,
             child:TextButton.icon(onPressed:editTransactionFilters,
              icon:const Icon(Icons.date_range),
              label:WaffraText(waffraIsEnglish?
               'Date and amount filters':'فلترة بالتاريخ والمبلغ'))),
           ],
           const SizedBox(height:6),
           if(visible.isEmpty)Padding(
            padding:const EdgeInsets.symmetric(vertical:26),
            child:Center(child:WaffraText(waffraIsEnglish?
             'No matching transactions':'ما عندك عمليات مطابقة'))),
           ...shown.map(compactTransaction),
           if(visible.isNotEmpty)Padding(
            padding:const EdgeInsets.only(top:7),
            child:Row(children:[
             WaffraText(waffraIsEnglish?'Transactions: '+visible.length.toString():
              'عدد العمليات: '+visible.length.toString(),
              style:const TextStyle(color:Colors.grey,fontSize:12)),
             const Spacer(),
             TextButton.icon(onPressed:()=>exportEntriesPdf(visible,'تقرير عمليات وفرة'),
              icon:const Icon(Icons.picture_as_pdf_outlined,size:18),
              label:WaffraText(waffraIsEnglish?'Export PDF':'تصدير PDF')),
            ])),
          ])),
        ]))),
     ],
    )));
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
   KeyedSubtree(key:_tourKeys[5],child:WaffraText('تحليلاتك المالية',style:Theme.of(context).textTheme.titleLarge)),
   const SizedBox(height:12),
   SegmentedButton<String>(segments:const [ButtonSegment(value:'شهري',label:WaffraText('شهري')),
    ButtonSegment(value:'سنوي',label:WaffraText('سنوي'))],
    selected:{period},onSelectionChanged:(v)=>setState(()=>period=v.first)),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:DropdownButtonFormField<int>(initialValue:year,
     decoration:InputDecoration(labelText:waffraTr('السنة')),
     items:years.map((x)=>DropdownMenuItem(value:x,child:WaffraText('$x'))).toList(),
     onChanged:(v){if(v!=null)setState(()=>year=v);})),
    if(period=='شهري')Expanded(child:DropdownButtonFormField<int>(initialValue:month,
     decoration:InputDecoration(labelText:waffraTr('الشهر')),
     items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:WaffraText('شهر ${i+1}'))),
     onChanged:(v){if(v!=null)setState(()=>month=v);})),
   ]),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,emerald),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
    const WaffraText('الدخل مقابل المصروفات',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:16),FinanceChart(points:points),
   ]))),
   const SizedBox(height:16),
   OutlinedButton.icon(onPressed:()=>exportEntriesPdf(data,'تحليلات وفرة - $period ${period=='شهري'?'$month/':''}$year',analytics:true),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const WaffraText('تصدير التحليلات إلى PDF')),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const WaffraText('الدخل والمصروفات - أعمدة',style:TextStyle(fontWeight:FontWeight.bold)),
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
    const WaffraText('توزيع المصروفات - دائري',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    SizedBox(height:210,child:PieChart(PieChartData(centerSpaceRadius:32,sections:breakdown.entries.map((e){
     final c=categoryFor(e.key,false);
     return PieChartSectionData(value:e.value,color:Color(c.color),radius:70,
      title:'${(e.value/exp*100).toStringAsFixed(0)}٪',titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold));
    }).toList()))),
   ]))),
   const SizedBox(height:16),
   WaffraText('توزيع مصروفاتك',style:Theme.of(context).textTheme.titleMedium),
   ...breakdown.entries.map((x){
    final c=categoryFor(x.key,false);
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
     Row(children:[Icon(categoryIcon(c.icon),color:Color(c.color)),const SizedBox(width:8),
      Expanded(child:WaffraText(x.key)),RiyalAmount(x.value)]),
     const SizedBox(height:10),
     LinearProgressIndicator(value:exp==0?0:x.value/exp,color:Color(c.color),minHeight:8,borderRadius:BorderRadius.circular(8)),
    ])));
   }),
   if(breakdown.isEmpty)const Padding(padding:EdgeInsets.all(20),child:WaffraText('ما فيه مصروفات في هالفترة')),
   const SizedBox(height:80),
  ]);
 }

 Future<BudgetCategory?> categoryDialog({BudgetCategory? initial,bool income=false,String? suggested})async {
  final name=TextEditingController(text:initial?.name??suggested??'');
  final budget=TextEditingController(text:initial==null||initial.budget==0?'':formatWaffraMoney(initial.budget));
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];int alertPercent=initial?.alertPercent??80;
  bool attempted=false;
  final result=await showDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(initial==null?'قسم جديد':'تعديل القسم'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Category name *':'اسم القسم *',
      errorText:attempted?(
       WaffraValidators.requiredText(name.text)!=null?(waffraIsEnglish?'Category name is required':'اسم القسم حقل إجباري'):
       WaffraValidators.uniqueCategory(name.text,categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null?(waffraIsEnglish?'Category already exists':'اسم القسم مستخدم بالفعل'):null):null)),
     const SizedBox(height:12),const WaffraText('اختر أيقونة'),
     Wrap(spacing:5,children:iconNames.map((x)=>IconButton(
      style:IconButton.styleFrom(backgroundColor:icon==x?emerald.withValues(alpha:.2):null),
      onPressed:()=>update(()=>icon=x),icon:Icon(categoryIcon(x),color:icon==x?emerald:null))).toList()),
     const WaffraText('اختر لون'),
     Wrap(spacing:7,children:colors.map((x)=>InkWell(
      onTap:()=>update(()=>color=x),
      child:CircleAvatar(radius:15,backgroundColor:Color(x),
       child:color==x?const Icon(Icons.check,color:Colors.white,size:17):null))).toList()),
     if(!(initial?.income??income))...[
      TextField(controller:budget,onChanged:(_)=>update((){}),
       keyboardType:const TextInputType.numberWithOptions(decimal:true),inputFormatters:[const WaffraAmountFormatter()],decoration:InputDecoration(labelText:waffraTr('ميزانية شهرية (اختياري)'),
       errorText:attempted&&WaffraValidators.positiveAmount(budget.text,required:false)!=null?
        (waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا أكبر من صفر'):null)),
      const SizedBox(height:10),
      DropdownButtonFormField<int>(initialValue:alertPercent,
       decoration:InputDecoration(labelText:waffraTr('ودّك ننبهك عند كم ٪ من الميزانية؟')),
       items:[50,60,70,75,80,85,90,95,100].map((v)=>DropdownMenuItem(value:v,child:WaffraText('$v٪'))).toList(),
       onChanged:(v){if(v!=null)update(()=>alertPercent=v);}),
      if(amountOf(budget.text)!=null)Padding(padding:const EdgeInsets.only(top:8),
       child:WaffraText('بننبهك عند صرف ${cash(amountOf(budget.text)!*alertPercent/100)} من ميزانية ${cash(amountOf(budget.text)!)}')),
     ],
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
     FilledButton(onPressed:(){
      final n=name.text.trim();update(()=>attempted=true);
      if(WaffraValidators.requiredText(n)!=null || WaffraValidators.uniqueCategory(n,
       categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null ||
       WaffraValidators.positiveAmount(budget.text,required:false)!=null)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:n,icon:icon,color:color,
       income:initial?.income??income,budget:budget.text.trim().isEmpty?0:(amountOf(budget.text)??0),alertPercent:alertPercent));
     },child:const WaffraText('حفظ')),
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
     recurring[j]=RecurringBill(id:r.id,title:r.title,category:v.name,amount:r.amount,income:r.income,day:r.day,active:r.active);
    }
   }
  });
  await persist();
 }
 Future<void> deleteCategory(BudgetCategory c)async {
  final linkedEntries=entries.where((e)=>e.category==c.name&&e.income==c.income).length;
  final linkedRecurring=recurring.where((e)=>e.category==c.name&&e.income==c.income).length;
  if(linkedEntries>0||linkedRecurring>0){
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Category cannot be deleted':'لا يمكن حذف القسم'),
    content:WaffraText(waffraIsEnglish
     ?'This category has $linkedEntries linked transaction(s) and $linkedRecurring recurring item(s). Delete these linked items first to protect your financial history.'
     :'هذا القسم مرتبط بعدد $linkedEntries معاملة مالية و$linkedRecurring عملية متكررة. يجب حذف العناصر المرتبطة أولًا قبل حذف القسم.'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('حسنًا')),
     if(linkedEntries>0)TextButton(onPressed:(){
      Navigator.pop(ctx);
      setState((){
       tab=0;addFabExpanded=false;showAllTransactions=true;
       showTransactionFilters=true;categoryFilter=c.name;
       typeFilter=c.income?'الدخل':'المصروفات';
       search='';transactionsDateRange=null;
       minTransactionAmount=null;maxTransactionAmount=null;
      });
     },child:WaffraText(waffraIsEnglish?'View transactions':'عرض المعاملات المرتبطة'))
     else TextButton(onPressed:(){
      Navigator.pop(ctx);setState((){tab=4;addFabExpanded=false;});
     },child:WaffraText(waffraIsEnglish?'View recurring':'عرض العمليات المتكررة')),
    ]));
   return;
  }
  final yes=await confirmDeletion(
   waffraIsEnglish?'Delete category?':'حذف القسم',
   waffraIsEnglish
    ?'Move «${c.name}» to Recently Deleted for 30 days? You can restore its name, icon and color, but its budget will reset to zero.'
    :'هل تريد نقل القسم «${c.name}» إلى المحذوفات لمدة 30 يومًا؟ عند استرجاعه سيعود بميزانية صفر.');
  if(yes!=true||!mounted)return;
  setState((){
   categories.removeWhere((e)=>e.id==c.id);
   deletedCategories.add({'category':c.toJson(),'deletedAt':DateTime.now().toIso8601String()});
  });
  await persist();
  if(mounted)snack(context,waffraIsEnglish?'Category moved to Recently Deleted for 30 days':'تم نقل القسم للمحذوفات لمدة 30 يومًا');
 }
 Future<void> showCategoryTrash()async {
  final before=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  if(before!=deletedCategories.length)await persist();
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(dialogCtx)=>StatefulBuilder(
   builder:(dialogCtx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Recently deleted categories':'الأقسام المحذوفة'),
    content:SizedBox(width:double.maxFinite,height:min(440.0,MediaQuery.sizeOf(dialogCtx).height*.5),
     child:deletedCategories.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted categories':'لا توجد أقسام محذوفة'))
      :ListView(children:deletedCategories.map((item){
        final original=BudgetCategory.fromJson(Map<String,dynamic>.from(item['category'] as Map));
        final deletedAt=DateTime.parse(item['deletedAt'] as String);
        final daysLeft=max(0,(deletedAt.add(const Duration(days:30))
         .difference(DateTime.now()).inHours/24).ceil());
        return Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(
         crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
           Icon(categoryIcon(original.icon),color:Color(original.color)),
           const SizedBox(width:8),
           Expanded(child:WaffraText(original.name,
            style:const TextStyle(fontWeight:FontWeight.bold))),
          ]),
          WaffraText(waffraIsEnglish
           ?'${original.income?'Income':'Expense'} • $daysLeft days remaining'
           :'${original.income?'دخل':'مصروفات'} • متبقي $daysLeft يوم',
           style:TextStyle(fontSize:12,color:daysLeft<=3?Colors.red:null)),
          Row(children:[
           TextButton.icon(icon:const Icon(Icons.restore),
            onPressed:()async{
             if(categories.any((c)=>c.name==original.name&&c.income==original.income)){
              snack(dialogCtx,waffraIsEnglish?'A category with this name already exists':'يوجد قسم نشط بنفس الاسم بالفعل');return;
             }
             final restored=original.copy(budget:0);
             setState((){
              categories.add(restored);
              deletedCategories.remove(item);
             });
             await persist();
             if(!dialogCtx.mounted)return;
             Navigator.pop(dialogCtx);
             if(mounted)snack(context,waffraIsEnglish
              ?'Category restored with zero balance and no budget. Add new transactions and a budget to use it.'
              :'تم استرجاع القسم بقيمة صفر وبدون ميزانية. سجّل عليه معاملات وميزانية جديدة.');
            },
            label:WaffraText(waffraIsEnglish?'Restore':'استرجاع')),
           const Spacer(),
           IconButton(tooltip:waffraIsEnglish?'Delete forever':'حذف نهائي',
            icon:const Icon(Icons.delete_forever_outlined,color:Colors.red),
            onPressed:()async{
             final yes=await confirmDeletion(
              waffraIsEnglish?'Permanently delete category?':'حذف القسم نهائيًا',
              waffraIsEnglish?'Delete «${original.name}» forever? You cannot restore it.'
               :'هل تريد حذف القسم «${original.name}» نهائيًا؟ لا يمكن استرجاعه بعد ذلك.');
             if(yes==true&&mounted){
              setState(()=>deletedCategories.remove(item));
              refresh((){});
              await persist();
             }
            }),
          ]),
         ])));
       }).toList())),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogCtx),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
 Widget categoriesPage(){
  final today=DateTime.now();
  final monthly=entries.where((e)=>!e.income&&e.date.year==today.year&&e.date.month==today.month);
  final spent=sum(monthly,false);
  final filtered=categories.where((c){
   if(categoryDisplay=='budget'&&c.budget<=0)return false;
   if(categoryDisplay=='none'&&c.budget>0)return false;
   return c.name.toLowerCase().contains(categorySearch.trim().toLowerCase());
  }).toList();
  Widget categoryCard(BudgetCategory c){
   final color=Color(c.color);
   final amount=sum(monthly.where((e)=>e.category==c.name),false);
   final hasBudget=!c.income&&c.budget>0;
   return Card(
    margin:const EdgeInsets.only(bottom:10),
    elevation:1.2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>updateCategory(c),
     child:Padding(padding:const EdgeInsets.all(13),child:Column(children:[
      Row(children:[
       CircleAvatar(radius:23,backgroundColor:color.withValues(alpha:.14),
        child:Icon(categoryIcon(c.icon),color:color)),
       const SizedBox(width:12),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(c.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        const SizedBox(height:3),
        WaffraText(c.income?(waffraIsEnglish?'Income category':'قسم دخل'):
         hasBudget?(waffraIsEnglish?'Budget: ${cash(c.budget)}':'الميزانية: ${cash(c.budget)}'):
         (waffraIsEnglish?'No budget set':'بدون ميزانية محددة'),
         style:TextStyle(fontSize:12,color:Theme.of(context).hintColor)),
       ])),
       PopupMenuButton<String>(tooltip:waffraIsEnglish?'Category options':'خيارات القسم',
        onSelected:(v){if(v=='edit')updateCategory(c);else if(v=='delete')deleteCategory(c);},
        itemBuilder:(_)=>[
         PopupMenuItem(value:'edit',child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
         PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف'))]),
      ]),
      if(hasBudget)...[
       const SizedBox(height:13),
       Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        WaffraText('${((amount/c.budget)*100).round()}%',style:TextStyle(color:color,fontWeight:FontWeight.bold)),
        WaffraText(waffraIsEnglish?'Spent ${cash(amount)} of ${cash(c.budget)}':'صرفت ${cash(amount)} من ${cash(c.budget)}',
         style:const TextStyle(fontSize:12))]),
       const SizedBox(height:7),
       LinearProgressIndicator(value:(amount/c.budget).clamp(0.0,1.0),minHeight:8,
        color:amount>c.budget?Colors.red:color,
        backgroundColor:color.withValues(alpha:.13),
        borderRadius:BorderRadius.circular(8)),
       const SizedBox(height:9),
       Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        WaffraText(waffraIsEnglish?'Remaining':'المتبقي',style:const TextStyle(fontSize:12)),
        WaffraText(cash(max(0,c.budget-amount)),
         style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:amount>c.budget?Colors.red:color)),
       ]),
      ],
     ]))));
  }
  return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,20),children:[
   Row(key:_tourKeys[2],children:[
    Expanded(child:WaffraText(waffraIsEnglish?'Categories & budgets':'أقسامك وميزانياتك',
     style:Theme.of(context).textTheme.titleLarge)),
    TextButton.icon(onPressed:showCategoryTrash,
     icon:const Icon(Icons.delete_outline,size:20),label:WaffraText(waffraIsEnglish?'Deleted':'الأقسام المحذوفة')),
   ]),
   WaffraText(waffraIsEnglish?'Organize spending and set budgets easily':'أضف أقسامًا جديدة لتنظيم دخلك ومصروفاتك بسهولة.',
    style:const TextStyle(fontSize:13)),
   const SizedBox(height:14),
   Row(children:[
    Expanded(child:_summaryBox(waffraIsEnglish?'Categories':'عدد الأقسام',
     categories.length.toString(),Icons.layers,emerald)),
    const SizedBox(width:10),
    Expanded(child:_summaryBox(waffraIsEnglish?'Monthly spending':'المصروف الشهري',
     cash(spent),Icons.trending_up,Colors.deepOrange)),
   ]),
   const SizedBox(height:15),
   Wrap(spacing:8,runSpacing:6,children:[
    _filterChip(waffraIsEnglish?'All':'الكل',categoryDisplay=='all',()=>setState(()=>categoryDisplay='all')),
    _filterChip(waffraIsEnglish?'Budgeted':'بميزانية',categoryDisplay=='budget',()=>setState(()=>categoryDisplay='budget')),
    _filterChip(waffraIsEnglish?'No budget':'بدون ميزانية',categoryDisplay=='none',()=>setState(()=>categoryDisplay='none')),
   ]),
   const SizedBox(height:12),
   TextField(onChanged:(v)=>setState(()=>categorySearch=v),
    decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
     hintText:waffraIsEnglish?'Search categories':'البحث عن قسم...',
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(30)),
     isDense:true)),
   const SizedBox(height:14),
   ...filtered.map(categoryCard),
   if(filtered.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:54),
    child:Column(children:[
     const Icon(Icons.search_off_rounded,size:54,color:emerald),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'),
    ])),
   const SizedBox(height:120),
  ]);
 }
 Widget _summaryBox(String heading,String number,IconData icon,Color color)=>Container(
  padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(color:color.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Icon(icon,color:color,size:21),const SizedBox(height:5),
   WaffraText(heading,style:const TextStyle(fontSize:12)),
   FittedBox(fit:BoxFit.scaleDown,alignment:AlignmentDirectional.centerStart,
    child:WaffraText(number,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
  ]));
 Widget _filterChip(String label,bool selected,VoidCallback onTap)=>
  ChoiceChip(label:WaffraText(label),selected:selected,onSelected:(_)=>onTap(),
   showCheckmark:false,selectedColor:forest,labelStyle:TextStyle(
    color:selected?Colors.white:null,fontWeight:selected?FontWeight.bold:FontWeight.normal));
 Future<void> goalDialog()async {
  final name=TextEditingController(),target=TextEditingController();
  final prefs=await SharedPreferences.getInstance();
  final customGoals=prefs.getStringList('waffra_custom_goals_v1')??<String>[];
  final suggested=['سيارة','منزل','سفر','زواج','صندوق الطوارئ','تعليم','حج أو عمرة','مشروع خاص',...customGoals];
  String selectedGoal='';bool attempted=false;
  final g=await showDialog<SavingGoal>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,updateGoal)=>AlertDialog(
   title:const WaffraText('إضافة هدف ادخار'),scrollable:true,
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(isExpanded:true,decoration:InputDecoration(labelText:waffraIsEnglish?'Savings goal *':'اختر هدف الادخار *',
      errorText:attempted&&selectedGoal.isEmpty?(waffraIsEnglish?'Goal is required':'الهدف حقل إجباري'):null),
     items:[...suggested,'هدف آخر'].map((v)=>DropdownMenuItem(value:v,child:WaffraText(v))).toList(),
     onChanged:(v){if(v==null)return;updateGoal(()=>selectedGoal=v);name.text=v=='هدف آخر'?'':v;}),
    if(selectedGoal=='هدف آخر')...[
     const SizedBox(height:12),
     TextField(controller:name,textInputAction:TextInputAction.next,onChanged:(_)=>updateGoal((){}),
      decoration:InputDecoration(labelText:waffraIsEnglish?'Goal name *':'اسم الهدف *',hintText:waffraTr('مثال: تجديد المنزل'),
       errorText:attempted&&WaffraValidators.requiredText(name.text)!=null?(waffraIsEnglish?'Goal name is required':'اسم الهدف حقل إجباري'):null)),
    ],
    const SizedBox(height:12),
    TextField(controller:target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>updateGoal((){}),
     decoration:InputDecoration(labelText:waffraIsEnglish?'Target amount *':'المبلغ المستهدف *',hintText:waffraTr('مثال: 25000'),
      errorText:attempted&&WaffraValidators.positiveAmount(target.text)!=null?(waffraIsEnglish?'Enter an amount greater than zero':'المبلغ حقل إجباري ويجب أن يكون أكبر من صفر'):null)),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
    FilledButton(onPressed:(){
     final n=amountOf(target.text);updateGoal(()=>attempted=true);
     if(WaffraValidators.requiredText(name.text)!=null||WaffraValidators.positiveAmount(target.text)!=null||selectedGoal.isEmpty||n==null)return;
     if((selectedGoal=='هدف آخر'||!suggested.contains(name.text.trim()))&&!customGoals.contains(name.text.trim())){
      prefs.setStringList('waffra_custom_goals_v1',[...customGoals,name.text.trim()]);
     }
     Navigator.pop(ctx,SavingGoal(id:newId(),name:name.text.trim(),target:n,saved:0));
    },child:const WaffraText('إضافة الهدف')),
   ])));
  disposeLater([name,target]);
  if(g!=null&&mounted){
   setState(()=>goals.add(g));await persist();
   if(mounted)snack(context,'تمت إضافة الهدف بنجاح');
  }
 }
 Future<void> fundGoal(SavingGoal g)async {
  final amount=TextEditingController();
  bool attempted=false;
  final n=await showDialog<double>(context:context,builder:(ctx)=>StatefulBuilder(
   builder:(ctx,update)=>AlertDialog(
   title:WaffraText('إضافة ادخار لـ ${g.name}'),
   content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    WaffraText(waffraIsEnglish?'Target: ${formatWaffraMoney(g.target)} SAR':'المبلغ المستهدف: ${formatWaffraMoney(g.target)} ريال'),
    WaffraText(waffraIsEnglish?'Already saved: ${formatWaffraMoney(g.saved)} SAR':'المدخر حاليًا: ${formatWaffraMoney(g.saved)} ريال'),
    const SizedBox(height:8),
    WaffraText(waffraIsEnglish
     ?'Remaining: ${formatWaffraMoney(max(0,g.target-g.saved))} SAR'
     :'المتبقي للهدف: ${formatWaffraMoney(max(0,g.target-g.saved))} ريال',
     style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
     inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
     decoration:InputDecoration(labelText:waffraIsEnglish?'Saved amount *':'المبلغ المدّخر *',
      errorText:attempted&&WaffraValidators.positiveAmount(amount.text)!=null?
       (waffraIsEnglish?'Amount must be positive':'المبلغ حقل إجباري ويجب أن يكون أكبر من صفر'):null,
      border:const OutlineInputBorder())),
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish
     ?'Remaining after adding: ${formatWaffraMoney(max(0,g.target-g.saved-(amountOf(amount.text)??0)))} SAR'
     :'المتبقي بعد الإضافة: ${formatWaffraMoney(max(0,g.target-g.saved-(amountOf(amount.text)??0)))} ريال',
     style:const TextStyle(color:emerald,fontWeight:FontWeight.w600)),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
    FilledButton(onPressed:(){
     update(()=>attempted=true);
     final v=amountOf(amount.text);if(v!=null)Navigator.pop(ctx,v);
    },child:const WaffraText('إضافة')),
   ])));
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
     title:const WaffraText('🎉 مبروك!'),
     content:WaffraText('تم تحقيق هدف الادخار «${g.name}» بنجاح!'),
     actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('رائع'))]));
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

 Future<void> createSavingChallenge()async {
  final name=TextEditingController(),amount=TextEditingController();
  var attempted=false,days=30;
  final challenge=await showDialog<SavingChallenge>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'New savings challenge':'تحدي ادخار جديد'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Challenge name *':'اسم التحدي *',
      errorText:attempted&&WaffraValidators.requiredText(name.text)!=null?
       (waffraIsEnglish?'Name is required':'اسم التحدي حقل إجباري'):null)),
     const SizedBox(height:12),
     TextField(controller:amount,onChanged:(_)=>update((){}),
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter()],decoration:InputDecoration(
       labelText:waffraIsEnglish?'Daily amount *':'الادخار اليومي *',
       errorText:attempted&&WaffraValidators.positiveAmount(amount.text)!=null?
        (waffraIsEnglish?'Enter a positive amount':'المبلغ حقل إجباري ويجب أن يكون أكبر من صفر'):null)),
     const SizedBox(height:12),
     DropdownButtonFormField<int>(initialValue:days,
      decoration:InputDecoration(labelText:waffraIsEnglish?'Duration *':'مدة التحدي *'),
      items:[7,14,30].map((n)=>DropdownMenuItem<int>(value:n,
       child:WaffraText(waffraIsEnglish?'$n days':'$n يوم'))).toList(),
      onChanged:(n){if(n!=null)update(()=>days=n);}),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?
      'This tracks your habit manually and never deducts money.':
      'التحدي لتتبّع عادتك يدويًا، ولن يخصم أو يحوّل أموالًا تلقائيًا.',
      style:const TextStyle(color:Colors.grey,fontSize:12)),
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:(){
      update(()=>attempted=true);
      if(WaffraValidators.requiredText(name.text)!=null||
       WaffraValidators.positiveAmount(amount.text)!=null)return;
      final value=amountOf(amount.text);
      if(value==null)return;
      Navigator.pop(ctx,SavingChallenge(id:newId(),title:name.text.trim(),
       dailyAmount:value,days:days));
     },child:WaffraText(waffraIsEnglish?'Save challenge':'إضافة التحدي')),
    ])));
  disposeLater([name,amount]);
  if(challenge==null||!mounted)return;
  setState(()=>challenges.add(challenge));
  await persist();
 }
 Widget savingsChallengesSection()=>Card(
  margin:const EdgeInsets.symmetric(vertical:12),elevation:1,
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
  child:ExpansionTile(
   initiallyExpanded:challenges.isNotEmpty,
   leading:const Icon(Icons.emoji_events_outlined,color:emerald),
   title:WaffraText(waffraIsEnglish?'Savings challenges':'تحديات الادخار',
    style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(waffraIsEnglish?'Build your saving habit':'حوّل التوفير إلى عادة يومية'),
   children:[
    if(challenges.isEmpty)Padding(padding:const EdgeInsets.all(14),
     child:WaffraText(waffraIsEnglish?'Try a daily savings challenge':
      'ابدأ تحديًا بسيطًا ووفّر مبلغًا كل يوم.',textAlign:TextAlign.center)),
    ...challenges.map((c){
     final completed=c.completedDays>=c.days,allowed=c.canComplete(DateTime.now());
     return Padding(padding:const EdgeInsets.fromLTRB(14,7,14,12),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[
        Expanded(child:WaffraText(c.title,style:const TextStyle(fontWeight:FontWeight.bold))),
        IconButton(icon:const Icon(Icons.delete_outline,size:20),
         tooltip:waffraIsEnglish?'Delete challenge':'حذف التحدي',
         onPressed:()async{
          final ok=await confirmDeletion(waffraIsEnglish?'Delete challenge?':'حذف التحدي',
           waffraIsEnglish?'Progress cannot be recovered.':
            'سيتم حذف التحدي وتقدمه نهائيًا، ولا يمكن استعادته.');
          if(ok==true&&mounted){
           setState(()=>challenges.removeWhere((x)=>x.id==c.id));await persist();
          }
         }),
       ]),
       WaffraText(waffraIsEnglish?
        'Daily: ${cash(c.dailyAmount)} • Target: ${cash(c.days*c.dailyAmount)}':
        'يوميًا: ${cash(c.dailyAmount)} • المستهدف: ${cash(c.days*c.dailyAmount)}',
        style:const TextStyle(fontSize:12)),
       const SizedBox(height:7),
       LinearProgressIndicator(value:(c.completedDays/c.days).clamp(0.0,1.0),
        minHeight:8,borderRadius:BorderRadius.circular(8)),
       const SizedBox(height:8),
       Row(children:[
        Expanded(child:WaffraText(waffraIsEnglish?
         '${c.completedDays} of ${c.days} days':
         '${c.completedDays} من ${c.days} يوم',
         style:const TextStyle(fontSize:12))),
        TextButton.icon(onPressed:allowed?()async{
          final i=challenges.indexWhere((x)=>x.id==c.id);
          if(i<0||!challenges[i].canComplete(DateTime.now()))return;
          setState(()=>challenges[i]=challenges[i].complete());
          await persist();
         }:null,icon:Icon(completed?Icons.check_circle_outline:Icons.check,size:18),
         label:WaffraText(completed?(waffraIsEnglish?'Complete':'مكتمل'):
          allowed?(waffraIsEnglish?'Saved today':'وفّرت اليوم'):
          (waffraIsEnglish?'Marked today':'تم اليوم'))),
       ]),
      ]));
    }),
    Padding(padding:const EdgeInsets.fromLTRB(14,0,14,14),
     child:OutlinedButton.icon(onPressed:createSavingChallenge,
      icon:const Icon(Icons.add),
      label:WaffraText(waffraIsEnglish?'New challenge':'تحدي جديد'))),
   ],
  ));

 Widget goalsPage(){
  final target=goals.fold<double>(0,(v,g)=>v+g.target);
  final saved=goals.fold<double>(0,(v,g)=>v+g.saved);
  final pct=target==0?0.0:(saved/target).clamp(0.0,1.0);
  final filtered=goals.where((g)=>goalDisplay=='all'||
   (goalDisplay=='done'?g.saved>=g.target:g.saved<g.target)).toList();
  return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,24),children:[
   KeyedSubtree(key:_tourKeys[3],child:WaffraText(waffraIsEnglish?'Savings goals':'أهداف الادخار',
    style:Theme.of(context).textTheme.titleLarge)),
   const SizedBox(height:6),
   WaffraText(waffraIsEnglish?'Turn your dreams into goals, one step at a time':
    'حوّل أحلامك إلى خطط واقعية وابدأ رحلتك نحو تحقيقها.',
    style:const TextStyle(fontSize:13)),
   const SizedBox(height:14),
   if(goals.isNotEmpty)...[
    Row(children:[
     Expanded(child:_summaryBox(waffraIsEnglish?'Total target':'إجمالي المستهدف',cash(target),Icons.flag_outlined,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Saved':'إجمالي المدخرات',cash(saved),Icons.savings_outlined,emerald)),
     const SizedBox(width:8),
     Expanded(child:Container(padding:const EdgeInsets.all(8),
      decoration:BoxDecoration(color:emerald.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
      child:Column(children:[
       SizedBox(width:48,height:48,child:Stack(alignment:Alignment.center,children:[
        CircularProgressIndicator(value:pct,strokeWidth:6,backgroundColor:emerald.withValues(alpha:.13)),
        WaffraText('${(pct*100).round()}%',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))])),
       const SizedBox(height:7),
       WaffraText(waffraIsEnglish?'Progress':'الإنجاز',style:const TextStyle(fontSize:11)),
      ]))),
    ]),
    const SizedBox(height:14),
   ],
   FilledButton.icon(onPressed:goalDialog,icon:const Icon(Icons.add),label:WaffraText(
    waffraIsEnglish?'New savings goal':'هدف جديد')),
   const SizedBox(height:14),
   if(goals.isNotEmpty)...[
    Wrap(spacing:7,runSpacing:6,children:[
     _filterChip(waffraIsEnglish?'All':'الكل',goalDisplay=='all',()=>setState(()=>goalDisplay='all')),
     _filterChip(waffraIsEnglish?'In progress':'قيد التنفيذ',goalDisplay=='active',()=>setState(()=>goalDisplay='active')),
     _filterChip(waffraIsEnglish?'Completed':'مكتملة',goalDisplay=='done',()=>setState(()=>goalDisplay='done')),
    ]),
    const SizedBox(height:10),
   ],
   ...filtered.map((g){
    final percent=(g.saved/g.target).clamp(0.0,1.0);
    final shade=goalIcon(g.name)==Icons.flight_takeoff?const Color(0xFF9C56B8):
     goalIcon(g.name)==Icons.directions_car?const Color(0xFF3867D6):emerald;
    return Card(
     margin:const EdgeInsets.only(bottom:11),
     elevation:1.2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
     child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Row(children:[
       CircleAvatar(radius:22,backgroundColor:shade.withValues(alpha:.14),
        child:Icon(goalIcon(g.name),color:shade)),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(g.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        WaffraText(waffraIsEnglish?'Target: ${cash(g.target)}':'المستهدف: ${cash(g.target)}',
         style:const TextStyle(fontSize:12)),
       ])),
       PopupMenuButton<String>(onSelected:(v)async {
        if(v=='delete'){
         final yes=await confirmDeletion(waffraIsEnglish?'Delete savings goal?':'حذف هدف الادخار',
          waffraIsEnglish?'This cannot be undone. Delete ${g.name}?':'هل تريد حذف «${g.name}» نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.');
         if(yes==true&&mounted){setState(()=>goals.removeWhere((x)=>x.id==g.id));await persist();}
        }
       },itemBuilder:(_)=>[PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete goal':'حذف الهدف'))]),
      ]),
      const SizedBox(height:11),
      Row(children:[
       WaffraText('${(percent*100).round()}%',style:TextStyle(fontWeight:FontWeight.bold,color:shade)),
       const SizedBox(width:10),
       Expanded(child:LinearProgressIndicator(value:percent,minHeight:9,
        color:shade,backgroundColor:shade.withValues(alpha:.12),
        borderRadius:BorderRadius.circular(9))),
      ]),
      const SizedBox(height:12),
      Row(children:[
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'Saved':'المدّخر',style:const TextStyle(fontSize:11)),
        WaffraText(cash(g.saved),style:const TextStyle(fontWeight:FontWeight.bold))])),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'Remaining':'المتبقي',style:const TextStyle(fontSize:11)),
        WaffraText(cash(max(0,g.target-g.saved)),style:const TextStyle(fontWeight:FontWeight.bold))])),
       if(g.saved<g.target)TextButton.icon(onPressed:()=>fundGoal(g),
        icon:const Icon(Icons.add,size:18),label:WaffraText(waffraIsEnglish?'Add amount':'إضافة مبلغ')),
      ]),
      if(g.saved>=g.target)WaffraText(waffraIsEnglish?'Goal achieved!':'🎉 تم تحقيق الهدف!',
       style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
     ])),
    );
   }),
   if(goals.isEmpty)Padding(padding:const EdgeInsets.only(top:35,bottom:18),
    child:Column(children:[
     Container(width:170,height:170,decoration:BoxDecoration(
      color:emerald.withValues(alpha:.08),borderRadius:BorderRadius.circular(90)),
      child:const Icon(Icons.savings_outlined,size:100,color:emerald)),
     const SizedBox(height:20),
     WaffraText(waffraIsEnglish?'No savings goals yet':'ما أضفت أي هدف ادخاري بعد',
      style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
     const SizedBox(height:10),
     WaffraText(waffraIsEnglish?'Set your first savings goal and track your progress':
      'ابدأ أول هدف ادخاري لك وحدد المبلغ المستهدف وتابع تقدّمك خطوة بخطوة.',
      textAlign:TextAlign.center),
     const SizedBox(height:22),
     OutlinedButton.icon(onPressed:goalDialog,icon:const Icon(Icons.add),
      label:WaffraText(waffraIsEnglish?'Add first goal':'إضافة أول هدف ادخاري')),
     const SizedBox(height:22),
     Row(children:[
      Expanded(child:_summaryBox(waffraIsEnglish?'Plan ahead':'خطط لمستقبلك','✓',Icons.wallet,emerald)),
      const SizedBox(width:8),
      Expanded(child:_summaryBox(waffraIsEnglish?'Stay motivated':'حقق أهدافك','✓',Icons.track_changes,emerald)),
      const SizedBox(width:8),
      Expanded(child:_summaryBox(waffraIsEnglish?'Track progress':'تابع تقدمك','✓',Icons.bar_chart,emerald)),
     ]),
    ])),
   if(goals.isNotEmpty&&filtered.isEmpty)Padding(padding:const EdgeInsets.all(34),
    child:WaffraText(waffraIsEnglish?'No goals in this filter':'لا توجد أهداف في هذا التصنيف',textAlign:TextAlign.center)),
   savingsChallengesSection(),
   const SizedBox(height:30),
  ]);
 }
 Future<void> recurringDialog()async {
  final title=TextEditingController(),amount=TextEditingController(),day=TextEditingController(text:'1');
  bool income=false;String category=forType(false).first.name;bool attempted=false;
  final r=await showDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forType(income);
    final selected=options.any((x)=>x.name==category)?category:options.first.name;
    return AlertDialog(title:const WaffraText('عملية شهرية متكررة'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:title,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'الوصف *',
       errorText:attempted&&WaffraValidators.requiredText(title.text)!=null?(waffraIsEnglish?'Description is required':'الوصف حقل إجباري'):null)),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted&&WaffraValidators.positiveAmount(amount.text)!=null?(waffraIsEnglish?'Enter an amount greater than zero':'المبلغ حقل إجباري ويجب أن يكون أكبر من صفر'):null)),
      DropdownButtonFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:(v){if(v!=null)update((){income=v;category=forType(v).first.name;});}),
      DropdownButtonFormField<String>(key:ValueKey('$income-$selected'),initialValue:selected,
       items:options.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      TextField(controller:day,keyboardType:TextInputType.number,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Day of month *':'يوم الشهر * (1 - 31)',
       errorText:attempted&&WaffraValidators.dayOfMonth(day.text)!=null?(waffraIsEnglish?'Choose a day from 1 to 31':'أدخل يومًا صحيحًا من 1 إلى 31'):null)),
     ])),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:(){
       final n=amountOf(amount.text),d=int.tryParse(digits(day.text));update(()=>attempted=true);
       if(WaffraValidators.requiredText(title.text)==null&&WaffraValidators.positiveAmount(amount.text)==null&&WaffraValidators.dayOfMonth(day.text)==null&&n!=null&&d!=null){
        Navigator.pop(ctx,RecurringBill(id:newId(),title:title.text.trim(),category:category,
         amount:n,income:income,day:d));
       }
      },child:const WaffraText('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState(()=>recurring.add(r));await persist();await applyRecurring();
   await syncRecurringReminders();
  }
 }
 DateTime nextRecurringDue(RecurringBill r) {
  final now=DateTime.now();
  DateTime due(int y,int m)=>DateTime(y,m,r.day.clamp(1,DateTime(y,m+1,0).day));
  final thisMonth=due(now.year,now.month);
  return thisMonth.isBefore(DateTime(now.year,now.month,now.day))
   ?due(now.year,now.month+1):thisMonth;
 }
 Widget recurringPage(){
  final active=recurring.where((r)=>r.active).toList();
  final monthly=active.where((r)=>!r.income).fold<double>(0,(v,r)=>v+r.amount);
  final shown=recurring.where((r)=>recurringDisplay=='all'||
   (recurringDisplay=='active'?r.active:!r.active)).toList();
  final upcoming=active.where((r){
   final days=nextRecurringDue(r).difference(DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day)).inDays;
   return days>=0&&days<=3;
  }).length;
  return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,24),children:[
   KeyedSubtree(key:_tourKeys[4],child:WaffraText(waffraIsEnglish?'Recurring transactions':'العمليات المتكررة',
    style:Theme.of(context).textTheme.titleLarge)),
   const SizedBox(height:6),
   WaffraText(waffraIsEnglish?'Due monthly transactions are recorded once when you open Waffra.':
    'نسجّل العملية المستحقة مرة واحدة لكل شهر عند فتح التطبيق.',
    style:const TextStyle(fontSize:13)),
   const SizedBox(height:9),
   SwitchListTile.adaptive(
    contentPadding:const EdgeInsets.symmetric(horizontal:5),
    title:WaffraText(waffraIsEnglish?'Remind me before due dates':'ذكرني قبل مواعيد الاستحقاق'),
    subtitle:WaffraText(waffraIsEnglish?
     'Optional Android alerts one day early at 9 AM (Riyadh time).':
     'إشعارات أندرويد اختيارية قبل الموعد بيوم الساعة 9 صباحًا بتوقيت الرياض.',
     style:const TextStyle(fontSize:12)),
    value:recurringRemindersEnabled,
    secondary:const Icon(Icons.notifications_active_outlined,color:emerald),
    onChanged:toggleRecurringReminders,
   ),
   const SizedBox(height:9),
   if(recurring.isNotEmpty)...[
    Row(children:[
     Expanded(child:_summaryBox(waffraIsEnglish?'Transactions':'عدد العمليات',
      recurring.length.toString(),Icons.calendar_month,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Monthly expenses':'المبلغ الشهري',
      cash(monthly),Icons.payments_outlined,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Active':'النشطة',
      '${active.length}/${recurring.length}',Icons.donut_large,emerald)),
    ]),
    if(upcoming>0)Padding(padding:const EdgeInsets.only(top:10),
     child:Card(color:Colors.amber.withValues(alpha:.13),child:ListTile(
      leading:const Icon(Icons.notifications_active_outlined,color:Colors.orange),
      title:WaffraText(waffraIsEnglish?'Upcoming obligations':'التزامات قريبة'),
      subtitle:WaffraText(waffraIsEnglish?'$upcoming due within 3 days':
       '$upcoming عملية مستحقة خلال 3 أيام'),
     ))),
    const SizedBox(height:12),
   ],
   FilledButton.icon(onPressed:recurringDialog,icon:const Icon(Icons.add),
    label:WaffraText(waffraIsEnglish?'New recurring transaction':'عملية متكررة جديدة')),
   const SizedBox(height:13),
   if(recurring.isNotEmpty)...[
    Wrap(spacing:8,runSpacing:6,children:[
     _filterChip(waffraIsEnglish?'All':'الكل',recurringDisplay=='all',()=>setState(()=>recurringDisplay='all')),
     _filterChip(waffraIsEnglish?'Active':'نشطة',recurringDisplay=='active',()=>setState(()=>recurringDisplay='active')),
     _filterChip(waffraIsEnglish?'Paused':'متوقفة',recurringDisplay=='paused',()=>setState(()=>recurringDisplay='paused')),
    ]),
    const SizedBox(height:11),
   ],
   ...shown.map((r){
    final color=Color(categoryFor(r.category,r.income).color);
    final when=nextRecurringDue(r);
    return Card(elevation:1.1,margin:const EdgeInsets.only(bottom:10),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(19)),
     child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),child:Row(children:[
      CircleAvatar(backgroundColor:color.withValues(alpha:.13),
       child:Icon(categoryIcon(categoryFor(r.category,r.income).icon),color:color)),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(r.title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
       WaffraText(cash(r.amount),style:const TextStyle(fontSize:14)),
       const SizedBox(height:3),
       WaffraText(r.active?
        (waffraIsEnglish?'Next due: ${dayText(when)}':'الاستحقاق القادم: ${dayText(when)}'):
        (waffraIsEnglish?'Paused':'متوقفة'),
        style:TextStyle(fontSize:11,color:r.active?Theme.of(context).hintColor:Colors.deepOrange)),
      ])),
      Switch(value:r.active,onChanged:(enabled)async {
       final index=recurring.indexWhere((item)=>item.id==r.id);
       if(index<0)return;
       setState(()=>recurring[index]=r.copy(active:enabled));
       await persist();
       if(enabled)await applyRecurring();
       await syncRecurringReminders();
      }),
      PopupMenuButton<String>(onSelected:(v)async {
       if(v!='delete')return;
       final ok=await confirmDeletion(waffraIsEnglish?'Delete recurring transaction?':'حذف العملية المتكررة',
        waffraIsEnglish?'The recurring schedule cannot be recovered. Previous transactions remain.':
         'هل تريد حذف جدولة العملية نهائيًا؟ ستبقى العمليات السابقة محفوظة ولا يمكن استعادة الجدولة.');
       if(ok==true&&mounted){setState(()=>recurring.removeWhere((e)=>e.id==r.id));await persist();await syncRecurringReminders();}
      },itemBuilder:(_)=>[
       PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف'))]),
     ])));
   }),
   if(recurring.isEmpty)Padding(padding:const EdgeInsets.only(top:34),
    child:Column(children:[
     Container(width:174,height:174,decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(88),color:emerald.withValues(alpha:.08)),
      child:const Icon(Icons.event_repeat_rounded,size:100,color:emerald)),
     const SizedBox(height:18),
     WaffraText(waffraIsEnglish?'No recurring transactions yet':'ما عندك عمليات متكررة',
      style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'Add a recurring transaction to organize monthly finances':
      'أضف عملية متكررة لتنظيم مصروفاتك الشهرية ومتابعتها بسهولة.',
      textAlign:TextAlign.center),
     const SizedBox(height:19),
     OutlinedButton.icon(onPressed:recurringDialog,icon:const Icon(Icons.add),
      label:WaffraText(waffraIsEnglish?'Add first recurring item':'إضافة أول عملية متكررة')),
     const SizedBox(height:22),
     Row(children:[
      Expanded(child:_summaryBox(waffraIsEnglish?'Save time':'توفير الوقت','✓',Icons.bolt,emerald)),
      const SizedBox(width:8),
      Expanded(child:_summaryBox(waffraIsEnglish?'Stay organized':'تنظيم أفضل','✓',Icons.analytics,emerald)),
      const SizedBox(width:8),
      Expanded(child:_summaryBox(waffraIsEnglish?'Due reminders':'تذكير بالمواعيد','✓',Icons.notifications_none,emerald)),
     ]),
    ])),
   if(recurring.isNotEmpty&&shown.isEmpty)Padding(padding:const EdgeInsets.all(32),
    child:WaffraText(waffraIsEnglish?'No items match this filter':'لا توجد عمليات في هذا التصنيف',
     textAlign:TextAlign.center)),
   const SizedBox(height:20),
  ]);
 }
 String exportBackup()=>const JsonEncoder.withIndent('  ').convert({
  'format':'waffra-backup','version':24,'exportedAt':DateTime.now().toIso8601String(),
  'entries':entries.map((e)=>e.toJson()).toList(),
  'categories':categories.map((e)=>e.toJson()).toList(),
  'goals':goals.map((e)=>e.toJson()).toList(),
  'recurring':recurring.map((e)=>e.toJson()).toList(),
  'challenges':challenges.map((e)=>e.toJson()).toList(),
  'deletedCategories':deletedCategories,
  'monthlyBudget':monthlyBudget,
  'learnedMerchants':learnedMerchantCategories,
  'profile':widget.profile.toJson(),
 });
 Future<void> backupDialog()async {
  final input=TextEditingController();
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const WaffraText('نسخ احتياطي واستعادة'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const WaffraText('انسخ بياناتك واحفظها في مكان آمن. للاستعادة، الصق نسخة JSON. الاستعادة تستبدل بيانات العمليات والأقسام والأهداف والتكرار الحالية.'),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:()async {
     await Clipboard.setData(ClipboardData(text:exportBackup()));
     if(ctx.mounted)snack(ctx,'تم نسخ البيانات، احفظها في مكان آمن');
    },icon:const Icon(Icons.copy),label:const WaffraText('نسخ النسخة الاحتياطية')),
    const SizedBox(height:12),
    TextField(controller:input,minLines:4,maxLines:7,
     decoration:InputDecoration(labelText:waffraTr('الصق نسخة JSON للاستعادة'),border:OutlineInputBorder())),
   ])),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إغلاق')),
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
      final newChallenges=raw['challenges'] is List?(raw['challenges'] as List).map((x)=>SavingChallenge.fromJson(Map<String,dynamic>.from(x))).toList():<SavingChallenge>[];
      final newTrash=raw['deletedCategories'] is List?
       (raw['deletedCategories'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      if(newCategories.isEmpty)throw const FormatException('Empty categories');
      final restoredBudget=raw['monthlyBudget'] is num?
       (raw['monthlyBudget'] as num).toDouble():monthlyBudget;
      final restoredRules=<String,String>{};
      if(raw['learnedMerchants'] is Map){
       final rules=raw['learnedMerchants'] as Map;
       restoredRules.addAll(rules.map((key,value)=>MapEntry(key.toString(),value.toString())));
      }
      if(!mounted)return;
      final ok=await confirm(
       waffraIsEnglish?'Confirm backup restore':'تأكيد الاستعادة',
       waffraIsEnglish?'This will replace all current transactions, categories, savings goals and recurring items with the backup. Make a backup of current data first. Continue?':'سيتم استبدال جميع المعاملات والأقسام وأهداف الادخار والعمليات المتكررة الحالية بمحتويات النسخة الاحتياطية. احفظ نسخة من بياناتك الحالية قبل المتابعة. هل تريد الاستمرار؟');
      if(ok!=true||!mounted)return;
      setState((){
       entries..clear()..addAll(newEntries);
       categories..clear()..addAll(newCategories);
       goals..clear()..addAll(newGoals);
       recurring..clear()..addAll(newRecurring);
       challenges..clear()..addAll(newChallenges);
       deletedCategories..clear()..addAll(newTrash);
       monthlyBudget=restoredBudget;
       learnedMerchantCategories..clear()..addAll(restoredRules);
      });
      await persist();
      await syncRecurringReminders();
      if(ctx.mounted)Navigator.pop(ctx);
      if(mounted)snack(context,'تمت استعادة البيانات بنجاح');
     }catch(e){
      if(ctx.mounted)snack(ctx,'النسخة غير صالحة، تأكد من النص كامل');
     }
    },child:const WaffraText('استعادة')),
   ]));
  disposeLater([input]);
 }
 // System credentials are never saved in plain text. A new PIN must be
 // entered twice; keep support for checking older 4-8-digit PINs on disable.
 Future<String?> _askForPin({
  required String title,required String fieldLabel,bool existing=false,
 })async{
  final input=TextEditingController();
  try{
   return await showDialog<String>(context:context,builder:(dialogContext)=>AlertDialog(
    title:WaffraText(title),
    content:TextField(
     controller:input,autofocus:true,
     textDirection:TextDirection.ltr,textAlign:TextAlign.center,
     keyboardType:TextInputType.number,
     inputFormatters:[FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(existing?8:4)],
     obscureText:true,
     decoration:InputDecoration(labelText:fieldLabel,
      helperText:existing?'4–8 digits / من 4 إلى 8 أرقام':'4 digits / أربعة أرقام',
      border:const OutlineInputBorder())),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialogContext),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:(){
      final code=input.text.trim();
      if(existing?RegExp(r'^\d{4,8}$').hasMatch(code):RegExp(r'^\d{4}$').hasMatch(code)){
       Navigator.pop(dialogContext,code);
      }else{
       ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
        content:WaffraText(waffraIsEnglish?
         (existing?'Enter 4 to 8 digits':'Enter exactly 4 digits'):
         (existing?'أدخل من 4 إلى 8 أرقام':'أدخل أربعة أرقام بالضبط'))));
      }
     },child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد')),
    ],
   ));
  }finally{disposeLater([input]);}
 }
 Future<void> configurePin()async {
  if(widget.pinEnabled){
   final oldPin=await _askForPin(
    title:waffraIsEnglish?'Disable app lock':'إلغاء رمز القفل',
    fieldLabel:waffraIsEnglish?'Current PIN':'أدخل الرمز الحالي',
    existing:true);
   if(oldPin==null||!mounted)return;
   final prefs=await SharedPreferences.getInstance();
   final hash=prefs.getString('waffra_pin_sha256');
   if(sha256.convert(utf8.encode(oldPin)).toString()!=hash){
    if(mounted)snack(context,waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح');
    return;
   }
   await widget.onSetPin(null);
   if(mounted)snack(context,waffraIsEnglish?'App lock disabled':'تم إلغاء القفل');
   return;
  }
  final firstPin=await _askForPin(
   title:waffraIsEnglish?'Create a new PIN':'إنشاء رمز قفل',
   fieldLabel:waffraIsEnglish?'New 4-digit PIN':'رمز PIN من 4 أرقام');
  if(firstPin==null||!mounted)return;
  while(mounted){
   final repeated=await _askForPin(
    title:waffraIsEnglish?'Confirm your PIN':'أعد إدخال رمز PIN للتأكيد',
    fieldLabel:waffraIsEnglish?'Repeat PIN':'أعد إدخال الرمز');
   if(repeated==null||!mounted)return;
   if(firstPin==repeated){
    // The existing onSetPin stores only SHA-256 of the confirmed PIN.
    await widget.onSetPin(firstPin);
    if(mounted)snack(context,waffraIsEnglish?'App lock enabled':'تم تفعيل قفل التطبيق');
    return;
   }
   if(mounted)snack(context,waffraIsEnglish?
    'PINs do not match. Re-enter the confirmation.':
    'رمزا PIN غير متطابقين. أعد إدخال رمز التأكيد.');
  }
 }
 Future<void> completeTour()async {
  if(mounted)setState((){tourActive=false;addFabExpanded=false;tab=0;});
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_in_app_tour_seen_v1',true);
 }
 void beginTour(){
  setState((){tourStep=0;tourActive=true;tab=0;addFabExpanded=false;});
 }
 void advanceTour(){
  if(tourStep>=tourTabs.length-1){completeTour();return;}
  setState((){tourStep++;tab=tourTabs[tourStep];addFabExpanded=false;});
 }
 void previousTour(){
  if(tourStep<=0)return;
  setState((){tourStep--;tab=tourTabs[tourStep];addFabExpanded=false;});
 }
 Widget tourOverlay()=>LayoutBuilder(builder:(overlayCtx,area){
  const ar=['الرصيد الحالي','إضافة المعاملات','الأقسام','أهداف الادخار','العمليات المتكررة','التحليلات'];
  const en=['Balance','Add transactions','Categories','Savings goals','Recurring items','Analytics'];
  const arHelp=['اعرف رصيدك ودخلك ومصروفاتك.','من زر + أضف عملية أو رسالة بنكية.','نظّم الأقسام وميزانياتها.','تابع أهدافك والمدخر والمتبقي.','نظّم التكرارات ومواعيد الاستحقاق.','تابع التقارير والرسوم البيانية.'];
  const enHelp=['Your balance, income and expenses.','Use + to add a transaction or SMS.','Manage your categories and budgets.','Track goals and remaining savings.','See and pause recurring transactions.','Explore your charts and reports.'];
  final element=_tourKeys[tourStep].currentContext?.findRenderObject();
  final layer=overlayCtx.findRenderObject();
  Rect target=Rect.fromLTWH(16,12,area.maxWidth-32,65);
  if(element is RenderBox&&layer is RenderBox&&element.hasSize){
   final offset=element.localToGlobal(Offset.zero)-layer.localToGlobal(Offset.zero);
   target=Rect.fromLTWH(offset.dx,offset.dy,element.size.width,element.size.height).inflate(5);
   target=Rect.fromLTRB(
    target.left.clamp(4.0,area.maxWidth-4).toDouble(),
    target.top.clamp(4.0,area.maxHeight-4).toDouble(),
    target.right.clamp(4.0,area.maxWidth-4).toDouble(),
    target.bottom.clamp(4.0,area.maxHeight-4).toDouble());
  }
  final width=min(300.0,area.maxWidth-24);
  const popupHeight=151.0;
  final below=target.bottom+popupHeight+14<area.maxHeight;
  final top=(below?target.bottom+10:target.top-popupHeight-10)
   .clamp(7.0,max(7.0,area.maxHeight-popupHeight-7)).toDouble();
  final left=(target.center.dx-width/2).clamp(12.0,max(12.0,area.maxWidth-width-12)).toDouble();
  return Stack(children:[
   Positioned.fill(child:TweenAnimationBuilder<Rect?>(
    tween:RectTween(end:target),duration:const Duration(milliseconds:300),
    builder:(ctx,rect,_)=>CustomPaint(painter:WaffraTourShade(rect??target)))),
   AnimatedPositioned(
    duration:const Duration(milliseconds:300),
    curve:Curves.easeOutCubic,top:top,left:left,width:width,
    child:Material(elevation:12,color:Theme.of(context).cardColor,
     borderRadius:BorderRadius.circular(18),
     child:Padding(padding:const EdgeInsets.all(12),child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[
        const Icon(Icons.lightbulb_outline,color:emerald,size:18),
        const SizedBox(width:5),
        Expanded(child:WaffraText(waffraIsEnglish?en[tourStep]:ar[tourStep],
         style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
        WaffraText('${tourStep+1}/6',style:const TextStyle(color:emerald,fontSize:11)),
       ]),
       const SizedBox(height:6),
       WaffraText(waffraIsEnglish?enHelp[tourStep]:arHelp[tourStep],maxLines:2,
        style:const TextStyle(fontSize:12)),
       const SizedBox(height:8),
       Row(children:[
        TextButton(onPressed:completeTour,child:WaffraText(waffraIsEnglish?'Skip':'تخطي')),
        const Spacer(),
        if(tourStep>0)TextButton(onPressed:previousTour,
         child:WaffraText(waffraIsEnglish?'Back':'السابق')),
        FilledButton(onPressed:advanceTour,
         child:WaffraText(tourStep==5?
          (waffraIsEnglish?'Finish':'إنهاء'):(waffraIsEnglish?'Next':'التالي'))),
       ]),
      ]))),
   ),
  ]);
 });
 Future<void> changePin()async {
  if(!widget.pinEnabled)return;
  final previous=await _askForPin(title:waffraIsEnglish?'Current PIN':'رمز القفل الحالي',
   fieldLabel:waffraIsEnglish?'Enter PIN':'أدخل رمز القفل',existing:true);
  if(previous==null||!mounted)return;
  final p=await SharedPreferences.getInstance();
  if(sha256.convert(utf8.encode(previous)).toString()!=p.getString('waffra_pin_sha256')){
   snack(context,waffraIsEnglish?'Wrong PIN':'رمز القفل غير صحيح');return;
  }
  final next=await _askForPin(title:waffraIsEnglish?'New PIN':'رمز جديد',
   fieldLabel:waffraIsEnglish?'4 digits':'أربعة أرقام');
  if(next==null||!mounted)return;
  final again=await _askForPin(title:waffraIsEnglish?'Confirm PIN':'تأكيد الرمز',
   fieldLabel:waffraIsEnglish?'Repeat PIN':'أعد إدخال الرمز');
  if(again==null||!mounted)return;
  if(again!=next){snack(context,waffraIsEnglish?'PINs do not match':'الرمزان غير متطابقين');return;}
  await widget.onSetPin(next);
  if(mounted)snack(context,waffraIsEnglish?'PIN changed':'تم تغيير الرمز بنجاح');
 }
 Future<void> eraseFinancialData()async {
  final ok=await confirmDeletion(
   waffraIsEnglish?'Permanently delete financial data?':'حذف البيانات المالية نهائيًا',
   waffraIsEnglish?'This deletes transactions, categories, budgets, goals and recurring schedules. It cannot be undone. Your profile and app settings stay.':
    'سيتم حذف المعاملات والأقسام والميزانيات والأهداف والجدولة المتكررة نهائيًا. لا يمكن التراجع. سيبقى الملف الشخصي وإعدادات التطبيق.');
  if(ok!=true||!mounted)return;
  setState((){
   entries.clear();categories..clear()..addAll(defaultCategories());
   goals.clear();challenges.clear();recurring.clear();deletedCategories.clear();smsHashes.clear();
   learnedMerchantCategories.clear();monthlyBudget=0;
  });
  final p=await SharedPreferences.getInstance();
  await p.remove('waffra_sms_hashes_v1');await persist();
  if(mounted)snack(context,waffraIsEnglish?'Financial data deleted':'تم حذف البيانات المالية');
 }
 Widget _accountTile(String label,String subtitle,IconData icon,{VoidCallback? onTap,Widget? trailing,Color tint=emerald})=>
  ListTile(
   leading:CircleAvatar(backgroundColor:tint.withValues(alpha:.12),child:Icon(icon,color:tint,size:21)),
   title:WaffraText(label,style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),
   trailing:trailing??(onTap==null?null:const Icon(Icons.chevron_left)),onTap:onTap);
 Widget _accountSection(String heading,IconData icon,List<Widget> children)=>Column(
  crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Padding(padding:const EdgeInsets.fromLTRB(4,12,4,7),
    child:Row(children:[Icon(icon,color:emerald),const SizedBox(width:7),
     Expanded(child:WaffraText(heading,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)))])),
   Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    child:Column(children:[
     for(var i=0;i<children.length;i++)...[
      children[i],if(i<children.length-1)const Divider(height:1,indent:14,endIndent:14),
     ],
    ])),
  ]);
 Widget profilePage(){
  final p=widget.profile;
  final local=p.provider=='محلي'||p.provider.startsWith('Local');
  final gender=p.gender=='ذكر'?(waffraIsEnglish?'Male':'ذكر'):
   p.gender=='أنثى'?(waffraIsEnglish?'Female':'أنثى'):
   (waffraIsEnglish?'Not specified':'غير محدد');
  void edit(){Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>ProfileForm(provider:p.provider,initial:p,onSave:widget.onProfile)));}
  return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,22),children:[
   Center(child:InkWell(onTap:edit,child:Stack(alignment:Alignment.bottomRight,children:[
    waffraAvatar(p.gender,p.avatar,radius:56),
    const CircleAvatar(radius:16,backgroundColor:forest,child:Icon(Icons.camera_alt,size:18,color:Colors.white)),
   ]))),
   const SizedBox(height:10),
   WaffraText(p.name.trim().isEmpty?(waffraIsEnglish?'My account':'حسابي'):p.name,
    textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
   if(p.email.trim().isNotEmpty)WaffraText(p.email,textAlign:TextAlign.center),
   const SizedBox(height:13),
   Row(children:[
    Expanded(child:_summaryBox(waffraIsEnglish?'Birthday':'تاريخ الميلاد',
     dayText(p.birthday),Icons.cake_outlined,emerald)),
    const SizedBox(width:6),
    Expanded(child:_summaryBox(waffraIsEnglish?'Gender':'الجنس',gender,Icons.people,emerald)),
    const SizedBox(width:6),
    Expanded(child:_summaryBox(waffraIsEnglish?'Account':'نوع الحساب',
     local?(waffraIsEnglish?'Local':'محلي'):p.provider,Icons.person,emerald)),
   ]),
   const SizedBox(height:11),
   OutlinedButton.icon(onPressed:edit,icon:const Icon(Icons.edit_outlined),
    label:WaffraText(waffraIsEnglish?'Edit profile':'تعديل حسابي')),
   _accountSection(waffraIsEnglish?'App settings':'إعدادات التطبيق',Icons.settings_outlined,[
    _accountTile(waffraIsEnglish?'App language':'لغة التطبيق',
     waffraIsEnglish?'English':'العربية',Icons.language,
     trailing:SegmentedButton<String>(segments:const [
      ButtonSegment(value:'ar',label:Text('AR')),ButtonSegment(value:'en',label:Text('EN')),
     ],selected:{waffraLanguage.value},showSelectedIcon:false,
     onSelectionChanged:(v)async{setState(()=>tab=0);await widget.onLanguage(v.first);})),
    SwitchListTile(secondary:Icon(widget.dark?Icons.dark_mode:Icons.light_mode,color:emerald),
     title:WaffraText(waffraIsEnglish?'Appearance':'المظهر'),
     subtitle:WaffraText(widget.dark?(waffraIsEnglish?'Dark':'داكن'):(waffraIsEnglish?'Light':'فاتح')),
     value:widget.dark,onChanged:(_)=>widget.onTheme()),
    _accountTile(waffraIsEnglish?'Currency converter':'تحويل العملات',
     waffraIsEnglish?'Saudi Riyal and other currencies':'الريال السعودي والعملات الأخرى',
     Icons.currency_exchange,onTap:()=>Navigator.push<void>(context,MaterialPageRoute(
      builder:(_)=>CurrencyConverterPage(lastIncomeAmount:null)))),
   ]),
   _accountSection(waffraIsEnglish?'Security & privacy':'الأمان والخصوصية',Icons.shield_outlined,[
    _accountTile(waffraIsEnglish?'PIN app lock':'قفل التطبيق برمز PIN',
     widget.pinEnabled?(waffraIsEnglish?'Enabled':'مفعّل'):(waffraIsEnglish?'Disabled':'غير مفعّل'),
     widget.pinEnabled?Icons.lock:Icons.lock_open,onTap:configurePin),
    if(widget.pinEnabled)_accountTile(waffraIsEnglish?'Change PIN':'تغيير رمز PIN',
     waffraIsEnglish?'Update your lock code':'تحديث رمز القفل',
     Icons.password_outlined,onTap:changePin),
    ValueListenableBuilder<bool>(valueListenable:allowWaffraScreenshots,
     builder:(context,allowed,_)=>SwitchListTile(
      secondary:const Icon(Icons.screenshot_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Allow screenshots':'السماح بلقطات الشاشة'),
      subtitle:WaffraText(allowed?(waffraIsEnglish?'Allowed':'مسموح'):(waffraIsEnglish?'Blocked':'ممنوع')),
      value:allowed,onChanged:(v)async{await setWaffraScreenshotsAllowed(v);if(mounted)setState((){});}))
   ]),
   _accountSection(waffraIsEnglish?'Data & utilities':'البيانات والأدوات',Icons.storage_outlined,[
    _accountTile(waffraIsEnglish?'Backup and restore':'النسخ الاحتياطي والاستعادة',
     waffraIsEnglish?'Keep your local data safe':'احفظ بياناتك واستعدها',
     Icons.backup_outlined,onTap:backupDialog),
    _accountTile(waffraIsEnglish?'Replay app tour':'إعادة الجولة التعريفية',
     waffraIsEnglish?'Learn Waffra features':'تعرف على خصائص وفرة',
     Icons.help_outline,onTap:beginTour),
    _accountTile(waffraIsEnglish?'Delete financial data':'حذف البيانات المالية',
     waffraIsEnglish?'Permanent and irreversible':'نهائي ولا يمكن التراجع عنه',
     Icons.delete_forever,tint:Colors.red,onTap:eraseFinancialData),
   ]),
   _accountSection(waffraIsEnglish?'About the app':'عن التطبيق',Icons.info_outline,[
    _accountTile(waffraIsEnglish?'About Waffra':'عن وفرة',
     waffraIsEnglish?'On-device financial management':'إدارة مالية تحفظ بياناتك محليًا',
     Icons.info_outline,onTap:()=>showAboutDialog(context:context,applicationName:'وفرة | Waffra',
      children:[WaffraText(waffraIsEnglish?'No bank account integration. Your data stays on your device.':
       'لا يوجد ربط بالحسابات البنكية؛ بياناتك محفوظة على جهازك.')]))
   ]),
   const SizedBox(height:15),
   OutlinedButton.icon(style:OutlinedButton.styleFrom(foregroundColor:Colors.red,
    side:const BorderSide(color:Colors.red)),
    onPressed:()async{
     final ok=await confirm(waffraIsEnglish?'Sign out?':'تسجيل الخروج',
      waffraIsEnglish?'Your data remains on this device.':'ستبقى بياناتك على هذا الجهاز.');
     if(ok==true&&mounted)await widget.onLogout();
    },
    icon:const Icon(Icons.logout),label:WaffraText(waffraIsEnglish?'Sign out':'تسجيل الخروج')),
   const SizedBox(height:13),
   WaffraText(waffraIsEnglish?
    'Your data stays on this device. Make a backup before changing phones or deleting the app.':
    'بياناتك محفوظة على جهازك. احفظ نسخة احتياطية قبل تغيير الجوال أو حذف التطبيق. ما فيه ربط بالحسابات البنكية.',
    textAlign:TextAlign.center,style:const TextStyle(fontSize:11)),
   const SizedBox(height:20),
  ]);
 }
// Build only the selected tab; constructing all six tabs on every frame
 // caused avoidable work and visible transition lag on Android.
 Widget _addMenuOption({
  required IconData icon,required String label,required VoidCallback onTap,
 })=>Material(
  color:Theme.of(context).cardColor,
  elevation:7,shadowColor:Colors.black12,
  borderRadius:BorderRadius.circular(25),
  child:InkWell(
   onTap:onTap,
   borderRadius:BorderRadius.circular(25),
   child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     Icon(icon,color:forest,size:21),
     const SizedBox(width:10),
     WaffraText(label,style:const TextStyle(
      fontSize:15,fontWeight:FontWeight.bold,color:forest)),
    ]))));
 Widget currentTab(){
  switch(tab){
   case 0:return dashboard();
   case 1:return analytics();
   case 2:return categoriesPage();
   case 3:return goalsPage();
   case 4:return recurringPage();
   default:return profilePage();
  }
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(
   titleSpacing:10,
   title:FittedBox(fit:BoxFit.scaleDown,
    alignment:AlignmentDirectional.centerStart,
    child:WaffraText(waffraIsEnglish?'Waffra':'Waffra | وفرة',
     style:const TextStyle(fontWeight:FontWeight.bold,fontSize:22))),
   actions:[
    SizedBox(width:42,height:kToolbarHeight,
     child:Center(child:TextButton(
      style:TextButton.styleFrom(
       padding:EdgeInsets.zero,foregroundColor:Colors.white,
       minimumSize:const Size(42,42),tapTargetSize:MaterialTapTargetSize.shrinkWrap),
      onPressed:()async{
       if(mounted)setState(()=>addFabExpanded=false);
       await widget.onLanguage(waffraIsEnglish?'ar':'en');
      },
      child:Text(waffraIsEnglish?'AR':'EN',
       style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15))))),
    SizedBox(width:42,height:kToolbarHeight,
     child:Center(child:ValueListenableBuilder<bool>(
      valueListenable:hideWaffraAmounts,
      builder:(ctx,hidden,_)=>IconButton(
       padding:EdgeInsets.zero,
       constraints:const BoxConstraints.tightFor(width:42,height:42),
       tooltip:hidden?(waffraIsEnglish?'Show amounts':'إظهار المبالغ'):
        (waffraIsEnglish?'Hide amounts':'إخفاء المبالغ'),
       onPressed:()=>hideWaffraAmounts.value=!hidden,
       icon:Icon(hidden?Icons.visibility_off_outlined:Icons.visibility_outlined))))),
    SizedBox(width:42,height:kToolbarHeight,
     child:Center(child:IconButton(
      padding:EdgeInsets.zero,
      constraints:const BoxConstraints.tightFor(width:42,height:42),
      tooltip:waffraIsEnglish?'Change appearance':'تغيير المظهر',
      onPressed:widget.onTheme,
      icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode)))),
    SizedBox(width:48,height:kToolbarHeight,
     child:Center(child:InkWell(
      onTap:()=>setState((){
       addFabExpanded=false;tab=5;
      }),
      borderRadius:BorderRadius.circular(30),
      child:waffraAvatar(widget.profile.gender,widget.profile.avatar,radius:19)))),
    const SizedBox(width:4),
   ]),
  // Instant content swap avoids building/animating the previous heavy tab
  // alongside the next one (the recurring -> savings navigation hitch).
  body:!ready?const Center(child:CircularProgressIndicator()):
   ValueListenableBuilder<bool>(
    valueListenable:hideWaffraAmounts,
    builder:(context,hidden,_)=>Stack(children:[
     Positioned.fill(child:currentTab()),
     if(tourActive)Positioned.fill(child:tourOverlay()),
    ])),
  // Floating plus starts collapsed at the physical bottom-left in both
  // languages. Expanded menu has two REAL actions, never a dummy label.
  floatingActionButtonLocation:const WaffraPhysicalLeftFab(),
  floatingActionButton:!ready||(tab!=0&&tab!=2)?null:Directionality(
   textDirection:TextDirection.ltr,child:Column(
   mainAxisSize:MainAxisSize.min,
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    AnimatedSize(duration:const Duration(milliseconds:210),
     curve:Curves.easeOutCubic,
     alignment:Alignment.bottomLeft,
     child:addFabExpanded?Padding(
      padding:const EdgeInsets.only(bottom:9),
      child:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(tab==0)...[
        _addMenuOption(
         icon:Icons.edit_note_rounded,
         label:waffraIsEnglish?'Manual transaction':'عملية يدوية',
         onTap:(){
          setState(()=>addFabExpanded=false);
          entrySheet();
         }),
        const SizedBox(height:7),
        _addMenuOption(
         icon:Icons.sms_outlined,
         label:waffraIsEnglish?'Bank message':'رسالة بنكية',
         onTap:(){
          setState(()=>addFabExpanded=false);
          bulkSmsSheet();
         }),
        ]else...[
         _addMenuOption(icon:Icons.trending_up,
          label:waffraIsEnglish?'Income category':'إضافة قسم دخل',
          onTap:(){setState(()=>addFabExpanded=false);addCategory(income:true);}),
         const SizedBox(height:7),
         _addMenuOption(icon:Icons.trending_down,
          label:waffraIsEnglish?'Expense category':'إضافة قسم مصروفات',
          onTap:(){setState(()=>addFabExpanded=false);addCategory();}),
        ],
       ])):const SizedBox.shrink()),
    Material(
     color:forest,elevation:7,
     shadowColor:Colors.black26,
     shape:const CircleBorder(),
     child:InkWell(
      customBorder:const CircleBorder(),
      onTap:()=>setState(()=>addFabExpanded=!addFabExpanded),
      child:SizedBox(key:_tourKeys[1],width:58,height:58,
       child:AnimatedRotation(
        duration:const Duration(milliseconds:210),
        turns:addFabExpanded?0.125:0,
        child:Icon(addFabExpanded?Icons.close:Icons.add,
         color:Colors.white,size:28))),
     )),
   ])),
  bottomNavigationBar:NavigationBar(height:74,indicatorColor:const Color(0xFFCFE9D9),
   labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
   selectedIndex:tab,onDestinationSelected:(v)=>setState((){
    tab=v;addFabExpanded=false;
   }),
   destinations:[
    NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:waffraTr('الرئيسية')),
    NavigationDestination(icon:const Icon(Icons.bar_chart_outlined),label:waffraTr('التحليلات')),
    NavigationDestination(icon:const Icon(Icons.category_outlined),label:waffraTr('الأقسام')),
    NavigationDestination(icon:const Icon(Icons.account_balance_wallet_outlined),label:waffraTr('الادخار')),
    NavigationDestination(icon:const Icon(Icons.repeat),label:waffraTr('المتكررة')),
    NavigationDestination(icon:const Icon(Icons.person_outline),label:waffraTr('حسابي')),
   ]));
}
/// Positions the expandable plus menu physically on the left in RTL
/// and LTR, independent of Scaffold's locale-sensitive start/end anchors.
/// A coach-mark scrim with a transparent focus over the current page.
class WaffraTourShade extends CustomPainter {
 final Rect focus;
 const WaffraTourShade(this.focus);
 @override void paint(Canvas canvas,Size size){
  final border=RRect.fromRectAndRadius(focus,const Radius.circular(20));
  final shade=Path()..fillType=PathFillType.evenOdd
   ..addRect(Offset.zero & size)..addRRect(border);
  canvas.drawPath(shade,Paint()..color=Colors.black.withValues(alpha:.61));
  canvas.drawRRect(border,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2);
 }
 @override bool shouldRepaint(covariant WaffraTourShade old)=>old.focus!=focus;
}
class WaffraPhysicalLeftFab extends FloatingActionButtonLocation {
 const WaffraPhysicalLeftFab();
 @override Offset getOffset(ScaffoldPrelayoutGeometry geometry){
  final bottom=geometry.contentBottom;
  return Offset(16+geometry.minInsets.left,
   max(16.0,bottom-geometry.floatingActionButtonSize.height-16));
 }
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
    Icon(Icons.square,color:emerald,size:15),WaffraText(' دخل  '),
    Icon(Icons.square,color:Colors.deepOrange,size:15),WaffraText(' مصروفات'),
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
     const SizedBox(height:7),WaffraText(p.label,style:const TextStyle(fontSize:10)),
    ]))).toList())),
  ]);
 }
}
