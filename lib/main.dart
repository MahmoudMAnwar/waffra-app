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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_welcome_background.dart';
import 'currency_converter.dart';
import 'waffra_i18n.dart';
import 'waffra_pdf_text.dart';

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
  if(hideWaffraAmounts.value)return '••••';
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
  return ValueListenableBuilder<bool>(
   valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Row(mainAxisSize:MainAxisSize.min,textDirection:TextDirection.ltr,children:[
    WaffraText(hidden?'••••':'$prefix${formatMoney(amount)}',style:effective),
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
 factory Person.fromJson(Map<String,dynamic> j)=>Person(name:'${j['name']??''}',email:'${j['email']??''}',provider:'${j['provider']??'محلي'}',gender:'${j['gender']??'غير محدد'}',avatar:'${j['avatar']??'person'}',phone:'${j['phone']??(j['provider']=='Phone'?j['email']??'':'')}',birthday:DateTime.tryParse('${j['birthday']}')??DateTime(2000));
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
  final u=profile??Person(name:'',email:'',provider:'محلي',gender:'غير محدد',avatar:'person',birthday:DateTime(2000));
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
    child:AnimatedSwitcher(duration:const Duration(milliseconds:800),switchInCurve:Curves.easeOutCubic,
     transitionBuilder:(w,a)=>FadeTransition(opacity:a,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0.11,0),end:Offset.zero).animate(a),child:w)),
     child:KeyedSubtree(key:ValueKey(language),child:child??const SizedBox.shrink())))),
  theme:ThemeData(useMaterial3:true,colorSchemeSeed:emerald,scaffoldBackgroundColor:sand,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.resolveWith((states)=>IconThemeData(color:states.contains(WidgetState.selected)?forest:Colors.white,size:27))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),fontFamily:'Tajawal',textTheme:ThemeData.light().textTheme.apply(fontFamily:'Tajawal'),primaryTextTheme:ThemeData.light().primaryTextTheme.apply(fontFamily:'Tajawal')),
  darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:emerald,appBarTheme:const AppBarTheme(backgroundColor:forest,foregroundColor:Colors.white),navigationBarTheme:NavigationBarThemeData(backgroundColor:forest,labelTextStyle:WidgetStateProperty.all(const TextStyle(color:Colors.white,fontSize:11)),iconTheme:WidgetStateProperty.all(const IconThemeData(color:Colors.white))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:forest,foregroundColor:Colors.white),fontFamily:'Tajawal',textTheme:ThemeData.dark().textTheme.apply(fontFamily:'Tajawal'),primaryTextTheme:ThemeData.dark().primaryTextTheme.apply(fontFamily:'Tajawal')),
  themeMode:dark?ThemeMode.dark:ThemeMode.light,
  themeAnimationDuration:const Duration(milliseconds:750),
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
   !onboarded?WaffraOnboarding(onFinish:()=>setState(()=>onboarded=true)):
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
 int failedPinAttempts=0;
 DateTime? pinCooldownUntil;
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
    title:const WaffraText('البصمة غير متاحة'),
    content:const WaffraText('تأكد من تسجيل بصمتك في إعدادات الهاتف، وبعدها افتح التطبيق مرة أخرى. يمكنك الدخول برمز PIN الآن.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('حسنًا'))]));
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
   if(error.isNotEmpty)Positioned(left:20,right:20,bottom:c.maxHeight*0.16,
    child:Container(padding:const EdgeInsets.all(10),color:forest,
     child:WaffraText(error,textAlign:TextAlign.center,
      style:const TextStyle(color:Colors.white,fontSize:15)))),
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
  if(current==3){finish();return;}
  controller.nextPage(duration:const Duration(milliseconds:430),curve:Curves.easeInOutCubic);
 }
 @override void dispose(){controller.dispose();super.dispose();}
 // Crop only the illustration region from the original approved design.
 // Headlines, progress markers and buttons are real responsive Flutter UI,
 // avoiding the impossible "cover without cropping or stretching" tradeoff.
 Widget illustration(int index)=>LayoutBuilder(builder:(context,box){
  const cropTop=310.0,cropHeight=580.0;
  final scale=min(box.maxWidth/sourceWidth[index],box.maxHeight/cropHeight);
  final imageWidth=sourceWidth[index]*scale;
  final imageHeight=979.0*scale;
  return ClipRect(child:Stack(fit:StackFit.expand,children:[
   // A subtle edge-to-edge wash of the artwork fills the hero backdrop.
   Opacity(opacity:0.11,child:Image.asset(
    'assets/onboarding_0'+(index+1).toString()+'.png',
    fit:BoxFit.cover,filterQuality:FilterQuality.high)),
   Positioned(
    left:(box.maxWidth-imageWidth)/2,
    top:(box.maxHeight-cropHeight*scale)/2-cropTop*scale,
    width:imageWidth,height:imageHeight,
    child:Image.asset('assets/onboarding_0'+(index+1).toString()+'.png',
     fit:BoxFit.fill,filterQuality:FilterQuality.high)),
  ]));
 });
 Widget slide(int index)=>LayoutBuilder(builder:(context,limits){
  final compact=limits.maxHeight<680;
  final titleSize=compact?25.0:29.0;
  final subtitleSize=compact?14.0:16.0;
  final pageName=waffraIsEnglish?titleEn[index]:titleAr[index];
  final pageDesc=waffraIsEnglish?subtitleEn[index]:subtitleAr[index];
  return Padding(
   padding:const EdgeInsets.symmetric(horizontal:14),
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
    SizedBox(height:compact?5:16),
    WaffraText(pageName,textAlign:TextAlign.center,
     style:TextStyle(color:forest,fontWeight:FontWeight.w800,
      fontSize:titleSize,height:1.23)),
    SizedBox(height:compact?8:13),
    WaffraText(pageDesc,textAlign:TextAlign.center,
     style:TextStyle(color:const Color(0xFF5B5B60),
      fontSize:subtitleSize,height:1.35)),
    const SizedBox(height:8),
    Expanded(child:illustration(index)),
    const SizedBox(height:8),
    Directionality(textDirection:TextDirection.ltr,child:Row(
     mainAxisAlignment:MainAxisAlignment.center,
     children:List.generate(4,(i)=>AnimatedContainer(
      duration:const Duration(milliseconds:250),
      width:i==current?12:9,height:i==current?12:9,
      margin:const EdgeInsets.symmetric(horizontal:5),
      decoration:BoxDecoration(shape:BoxShape.circle,
       color:i==current?forest:const Color(0xFFD0DAD0))))),
    const SizedBox(height:14),
    SizedBox(width:double.infinity,height:55,child:FilledButton(
     onPressed:next,style:FilledButton.styleFrom(
      backgroundColor:forest,foregroundColor:Colors.white,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))),
     child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.arrow_back_rounded,size:23),
      const SizedBox(width:17),
      WaffraText(index==3
       ?(waffraIsEnglish?'Start with Waffra':'ابدأ رحلتك مع وفرة')
       :(waffraIsEnglish?'Next':'التالي'),
       style:const TextStyle(color:Colors.white,fontSize:19,
        fontWeight:FontWeight.bold)),
     ]))),
    const SizedBox(height:12),
   ]),
  );
 });
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFFFAF9F1),
  body:SafeArea(child:PageView(
   controller:controller,onPageChanged:(nextIndex)=>setState(()=>current=nextIndex),
   children:List.generate(4,slide),
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
   await widget.onSave(Person(name:'',email:'',phone:'',provider:'Local $selected demo',gender:'غير محدد',avatar:'person',birthday:DateTime(2000)));
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
 late String gender,avatar;late DateTime birthday;bool busy=false;
 @override void initState(){super.initState();
  name=TextEditingController(text:widget.initial?.name??'');
  email=TextEditingController(text:widget.initial?.email??'');
  confirmEmail=TextEditingController();
  phone=TextEditingController(text:widget.initial?.phone??'');
  password=TextEditingController();confirmPassword=TextEditingController();
  gender=widget.initial?.gender??'ذكر';avatar=widget.initial?.avatar??'person';
  birthday=widget.initial?.birthday??DateTime(2000);
 }
 @override void dispose(){name.dispose();email.dispose();confirmEmail.dispose();phone.dispose();password.dispose();confirmPassword.dispose();super.dispose();}
 Future<void> save()async {
  final validEmail=RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());
  final validPhone=RegExp(r'^05[0-9]{8}$').hasMatch(phone.text.trim());
  if(name.text.trim().isEmpty||(!validPhone && phone.text.trim().isNotEmpty)){
   snack(context,waffraIsEnglish?'Enter a name, valid email and Saudi phone number':'أدخل الاسم والبريد الصحيح ورقم جوال يبدأ بـ 05 من 10 أرقام');return;
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
   Center(child:saudiAvatar(gender,radius:48)),
   const SizedBox(height:10),
   Wrap(alignment:WrapAlignment.center,spacing:12,children:['ذكر','أنثى']
    .map((a)=>ChoiceChip(label:Row(mainAxisSize:MainAxisSize.min,children:[saudiAvatar(a,radius:20),const SizedBox(width:6),WaffraText(waffraIsEnglish?(a=='ذكر'?'Male':'Female'):a)]),selected:gender==a,onSelected:(_)=>setState((){gender=a;avatar=a=='ذكر'?'male':'female';}))).toList()),
   const SizedBox(height:16),
   TextField(controller:name,decoration:InputDecoration(labelText:waffraTr('اسمك'),border:OutlineInputBorder())),
   const SizedBox(height:12),
   if(widget.initial!=null&&email.text.trim().isNotEmpty) ...[
    TextField(controller:email,readOnly:true,keyboardType:TextInputType.emailAddress,
     decoration:InputDecoration(labelText:waffraIsEnglish?'Registered email':'البريد الإلكتروني المسجل',
      filled:true,fillColor:Colors.grey.withValues(alpha:0.15),border:const OutlineInputBorder())),
    const SizedBox(height:12),
   ],
   TextField(controller:phone,keyboardType:TextInputType.phone,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(10)],
    decoration:InputDecoration(labelText:waffraIsEnglish?'Mobile number':'رقم الجوال',hintText:'05XXXXXXXX',
     helperText:waffraIsEnglish?'10 digits starting with 05':'رقم سعودي من 10 أرقام يبدأ بـ 05',border:const OutlineInputBorder())),
   if(widget.initial==null) ...[
    const SizedBox(height:12),
    TextField(controller:password,obscureText:!showPassword,decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showPassword?'Hide password':'Show password'):(showPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showPassword=!showPassword)),labelText:waffraIsEnglish?'Password':'كلمة المرور',
     helperText:waffraIsEnglish?'At least 8 characters, including letters and numbers':'8 خانات على الأقل، تشمل أحرفًا وأرقامًا',border:const OutlineInputBorder())),
    const SizedBox(height:12),
    TextField(controller:confirmPassword,obscureText:!showConfirmPassword,decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showConfirmPassword?'Hide password':'Show password'):(showConfirmPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showConfirmPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showConfirmPassword=!showConfirmPassword)),labelText:waffraIsEnglish?'Confirm password':'تأكيد كلمة المرور',border:const OutlineInputBorder())),
   ],
   const SizedBox(height:12),
   DropdownButtonFormField<String>(initialValue:gender,
    decoration:InputDecoration(labelText:waffraTr('الجنس'),border:OutlineInputBorder()),
    items:['ذكر','أنثى','غير محدد'].map((x)=>DropdownMenuItem(value:x,child:WaffraText(waffraIsEnglish?(x=='ذكر'?'Male':x=='أنثى'?'Female':'Not specified'):x))).toList(),
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
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:WaffraText(text)));
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
class _HomeScreenState extends State<HomeScreen> {
 final smsHashes=<String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 int tab=0,year=DateTime.now().year,month=DateTime.now().month;
 String search='',typeFilter='الكل',categoryFilter='الكل',period='شهري';
 bool ready=false;
 @override void initState(){super.initState();waffraReturnHome.addListener(_returnToHome);load();}
 void _returnToHome(){if(mounted&&tab!=0)setState(()=>tab=0);}
 @override void dispose(){waffraReturnHome.removeListener(_returnToHome);super.dispose();}
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
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const WaffraText('تأكيد'))]));
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
   final hash=bankSmsHash(found[i]);
   if(smsHashes.contains(hash)||!seen.add(hash)){duplicates.add(i);continue;}
   if(results[i].amount==null||results[i].amount!<=0){invalid.add(i);continue;}
   valid.add(i);
  }
  if(valid.isEmpty){update(()=>statusMessage=waffraIsEnglish?'No new valid transactions were detected.':'لم يتم اكتشاف معاملات جديدة صالحة للإضافة.');return;}
  final incomes=valid.where((i)=>results[i].income).toList();
  final expenses=valid.where((i)=>!results[i].income).toList();
  final incomeTotal=incomes.fold<double>(0,(v,i)=>v+results[i].amount!);
  final expenseTotal=expenses.fold<double>(0,(v,i)=>v+results[i].amount!);
  final accepted=await showDialog<bool>(context:ctx,builder:(dialogCtx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Confirm transactions':'تأكيد إضافة المعاملات'),
   content:WaffraText(waffraIsEnglish
    ?'Detected ${valid.length} transactions: ${incomes.length} income (SAR ${incomeTotal.toStringAsFixed(2)}) and ${expenses.length} expenses (SAR ${expenseTotal.toStringAsFixed(2)}). ${invalid.length} unrecognized, ${duplicates.length} duplicates. Add the valid transactions?'
    :'تم اكتشاف ${valid.length} معاملات: ${incomes.length} دخل (${incomeTotal.toStringAsFixed(2)} ر.س) و${expenses.length} مصروفات (${expenseTotal.toStringAsFixed(2)} ر.س). تعذر تحليل ${invalid.length}، والمكرر ${duplicates.length}. هل تريد تأكيد الإضافة؟'),
   actions:[TextButton(onPressed:()=>Navigator.pop(dialogCtx,false),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(onPressed:()=>Navigator.pop(dialogCtx,true),child:WaffraText(waffraIsEnglish?'Confirm and add':'تأكيد وإضافة المعاملات'))]));
  if(accepted!=true||!ctx.mounted)return;
  update(()=>busy=true);
  final additions=<MoneyEntry>[];
  final newHashes=<String>{};
  for(final i in valid){
   final result=results[i];
   final cat=categories.any((c)=>c.income==result.income&&c.name==result.category)
    ?result.category:(forType(result.income).isNotEmpty?forType(result.income).first.name:'أخرى');
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
    content:const SizedBox(height:8),
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
   amount.text=result.amount==null?'':formatMoney(result.amount!);
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
      if(parsed&&statusMessage.isEmpty)...[
       const SizedBox(height:10),
       WaffraText(waffraIsEnglish?'Detected ${messages.length} transactions':'تم اكتشاف ${messages.length} معاملة',
        style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
       const SizedBox(height:8),
       FilledButton.icon(icon:const Icon(Icons.check_circle_outline),
        onPressed:busy?null:()=>saveParsedMessages(ctx,update),
        label:WaffraText(busy?'جارٍ الحفظ...':'تأكيد وحفظ المعاملات')),
      ],
      TextButton.icon(onPressed:(){
       pasteTimer?.cancel();pasted.clear();
       update((){parsed=false;messages=[];});
      },icon:const Icon(Icons.delete_outline),label:const WaffraText('حذف النص بالكامل')),
     ]else...[
      TextButton.icon(onPressed:busy?null:(){
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
      OutlinedButton.icon(onPressed:busy?null:(){
       update((){reviewing=false;parsed=false;messages=[];index=0;savedCount=0;pasted.clear();description.clear();amount.clear();});
      },icon:const Icon(Icons.delete_forever_outlined),label:const WaffraText('حذف النص بالكامل وإضافة رسائل أخرى')),
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
      WaffraText(initial!=null?'تعديل العملية':sms?'إضافة رسالة بنكية':'إضافة عملية',
       style:Theme.of(sheetContext).textTheme.titleLarge),
      const SizedBox(height:12),
      if(sms)...[
       TextField(controller:message,minLines:3,maxLines:6,onChanged:parseNow,
        decoration:InputDecoration(labelText:waffraTr('الصق الرسالة البنكية هنا'),
         hintText:waffraTr('أول ما تلصقها نحلّلها تلقائيًا'),border:OutlineInputBorder())),
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
      TextField(controller:title,decoration:InputDecoration(labelText:waffraTr('وصف العملية'),border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       decoration:InputDecoration(labelText:waffraTr('المبلغ بالريال'),border:OutlineInputBorder())),
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
       final n=amountOf(value.text);
       if(title.text.trim().isEmpty||n==null){snack(context,'تأكد من الوصف والمبلغ');return;}
       if(sms){
        if(message.text.trim().isEmpty){snack(context,'الصق الرسالة البنكية أولًا');return;}
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
  final c=categoryFor(entry.category,false);
  if(c.budget<=0)return;
  final threshold=c.budget*c.alertPercent/100;
  final spent=sum(entries.where((e)=>!e.income&&e.category==entry.category&&
   e.date.year==entry.date.year&&e.date.month==entry.date.month),false);
  if(previousSpent>=threshold||spent<threshold||!mounted)return;
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const WaffraText('⚠️ ميزانية القسم أوشكت على الانتهاء'),
   content:WaffraText('وصل صرف قسم «${c.name}» إلى ${formatMoney(spent/c.budget*100)}٪ من الميزانية. صرفت ${cash(spent)} من ${cash(c.budget)}، وحد التنبيه اللي اخترته ${c.alertPercent}٪.'),
   actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('حسنًا'))]));
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
    painter.layout(maxWidth:logicalWidth*scale);
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    painter.paint(canvas,Offset.zero);
    final picture=recorder.endRecording();
    final raster=await picture.toImage(
     (logicalWidth*scale).ceil(),max(1,painter.height.ceil()));
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
          pw.Padding(padding:const pw.EdgeInsets.symmetric(horizontal:6,vertical:7),
           child:pw.Image(art.$1,width:460,height:art.$2,fit:pw.BoxFit.contain)),
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
  final yes=await confirm('حذف العملية','ودّك تحذف «${e.title}»؟');
  if(yes!=true||!mounted)return;
  setState(()=>entries.removeWhere((x)=>x.id==e.id));await persist();
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
  final confirmed=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Delete all transactions?':'حذف كل المعاملات؟'),
   content:WaffraText(waffraIsEnglish?'All transactions will be permanently deleted. This cannot be undone.':'سيتم حذف جميع معاملاتك نهائيًا، ولا يمكن التراجع عن هذا الإجراء.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),onPressed:()=>Navigator.pop(dialogContext,true),child:WaffraText(waffraIsEnglish?'Delete all':'حذف الكل')),
   ],
  ));
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
  return RefreshIndicator(
   onRefresh:()async{
    if(mounted)setState((){});
    await Future<void>.delayed(const Duration(milliseconds:250));
   },
   child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),children:[
   WaffraText(greeting,style:Theme.of(context).textTheme.titleLarge),
   const SizedBox(height:12),
   TweenAnimationBuilder<double>(tween:Tween<double>(begin:0,end:1),duration:const Duration(milliseconds:1100),curve:Curves.easeOutCubic,
    builder:(context,progress,child)=>Opacity(opacity:progress,child:Transform.scale(scale:0.84+0.16*progress,child:child)),
    child:Container(padding:const EdgeInsets.all(24),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[forest,emerald]),borderRadius:BorderRadius.circular(24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const WaffraText('رصيدك الحالي',style:TextStyle(color:Colors.white70)),const SizedBox(height:10),
     TweenAnimationBuilder<double>(
      tween:Tween<double>(begin:0,end:inc-exp),
      duration:const Duration(milliseconds:850),
      curve:Curves.easeOutCubic,
      builder:(context,value,child)=>RiyalAmount(value,style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),
     ),
     const SizedBox(height:8),
     const WaffraText('كل ريال تحسب له حساب',style:TextStyle(color:Colors.white70)),
    ]))),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,emerald),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   const SizedBox(height:10),
   OutlinedButton.icon(onPressed:bulkSmsSheet,icon:const Icon(Icons.content_paste),label:const WaffraText('الصق رسالة بنكية')),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:Container(
     padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
     decoration:BoxDecoration(border:Border.all(color:forest.withValues(alpha:0.55),width:1.3),borderRadius:BorderRadius.circular(14)),
     child:WaffraText('عملياتك المالية',style:Theme.of(context).textTheme.titleLarge))),
    OutlinedButton.icon(onPressed:entries.isEmpty?null:confirmDeleteAllEntries,
     style:OutlinedButton.styleFrom(side:const BorderSide(color:Colors.red,width:1.4),foregroundColor:Colors.red),
     icon:const Icon(Icons.delete_outline,color:Colors.red),
     label:WaffraText(waffraIsEnglish?'Delete all':'حذف كل المعاملات',style:const TextStyle(color:Colors.red))),
   ]),
   const SizedBox(height:12),
   TextField(onChanged:(v)=>setState(()=>search=v),
    decoration:InputDecoration(labelText:waffraTr('دوّر على عملية'),prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
   const SizedBox(height:10),
   Wrap(spacing:8,children:['الكل','الدخل','المصروفات'].map((x)=>ChoiceChip(
    label:WaffraText(x),selected:typeFilter==x,
    onSelected:(_)=>setState((){typeFilter=x;categoryFilter='الكل';}))).toList()),
   DropdownButtonFormField<String>(key:ValueKey('$typeFilter-$selected'),initialValue:selected,
    decoration:InputDecoration(labelText:waffraTr('تصفية حسب القسم')),
    items:filterCats.map((x)=>DropdownMenuItem(value:x,child:WaffraText(x))).toList(),
    onChanged:(x)=>setState(()=>categoryFilter=x??'الكل')),
   const SizedBox(height:10),
   OutlinedButton.icon(onPressed:()=>exportEntriesPdf(visible,'تقرير عمليات وفرة'),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const WaffraText('تصدير النتائج إلى PDF')),
   const SizedBox(height:8),
   WaffraText('عدد العمليات: ${visible.length}'),
   if(visible.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Center(child:WaffraText('ما عندك عمليات مطابقة'))),
   ...visible.map(tile),const SizedBox(height:90),
  ]));
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
   WaffraText('تحليلاتك المالية',style:Theme.of(context).textTheme.titleLarge),
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
  final budget=TextEditingController(text:initial==null||initial.budget==0?'':formatMoney(initial.budget));
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];int alertPercent=initial?.alertPercent??80;
  final result=await showDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(initial==null?'قسم جديد':'تعديل القسم'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,decoration:InputDecoration(labelText:waffraTr('اسم القسم'))),
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
       keyboardType:TextInputType.number,decoration:InputDecoration(labelText:waffraTr('ميزانية شهرية (اختياري)'))),
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
      final n=name.text.trim();if(n.isEmpty)return;
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
   WaffraText('أقسامك وميزانياتك',style:Theme.of(context).textTheme.titleLarge),
   const WaffraText('حدّد ميزانية شهرية لكل قسم وتابع صرفك'),
   const SizedBox(height:12),
   FilledButton.icon(onPressed:()=>addCategory(),icon:const Icon(Icons.add),label:const WaffraText('إضافة قسم مصروفات')),
   OutlinedButton.icon(onPressed:()=>addCategory(income:true),icon:const Icon(Icons.add),label:const WaffraText('إضافة قسم دخل')),
   const SizedBox(height:12),
   ...categories.map((c){
    final spent=sum(current.where((e)=>e.category==c.name),false);
    return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
     ListTile(
      leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
       child:Icon(categoryIcon(c.icon),color:Color(c.color))),
      title:WaffraText(c.name),
      subtitle:WaffraText(c.income?'دخل':c.budget>0?'الميزانية: ${cash(c.budget)} • تنبيه عند ${c.alertPercent}٪':'بدون ميزانية محددة'),
      trailing:PopupMenuButton<String>(onSelected:(v){
       if(v=='edit')updateCategory(c);else deleteCategory(c);
      },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:WaffraText('تعديل')),
       PopupMenuItem(value:'delete',child:WaffraText('حذف'))])),
     if(!c.income&&c.budget>0)...[
      LinearProgressIndicator(value:(spent/c.budget).clamp(0.0,1.0),minHeight:8,
       color:spent>c.budget?Colors.red:Color(c.color),borderRadius:BorderRadius.circular(8)),
      const SizedBox(height:5),
      WaffraText('صرفت ${cash(spent)} من ${cash(c.budget)}',
       style:TextStyle(color:spent>c.budget?Colors.red:null)),
     ],
    ])));
   }),
   const SizedBox(height:80),
  ]);
 }
 Future<void> goalDialog()async {
  final name=TextEditingController(),target=TextEditingController();
  final prefs=await SharedPreferences.getInstance();
  final customGoals=prefs.getStringList('waffra_custom_goals_v1')??<String>[];
  final suggested=['سيارة','منزل','سفر','زواج','صندوق الطوارئ','تعليم','حج أو عمرة','مشروع خاص',...customGoals];
  String selectedGoal='';
  final g=await showDialog<SavingGoal>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,updateGoal)=>AlertDialog(
   title:const WaffraText('إضافة هدف ادخار'),scrollable:true,
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(isExpanded:true,decoration:InputDecoration(labelText:waffraTr('اختر هدف الادخار')),
     items:[...suggested,'هدف آخر'].map((v)=>DropdownMenuItem(value:v,child:WaffraText(v))).toList(),
     onChanged:(v){if(v==null)return;updateGoal(()=>selectedGoal=v);name.text=v=='هدف آخر'?'':v;}),
    if(selectedGoal=='هدف آخر')...[
     const SizedBox(height:12),
     TextField(controller:name,textInputAction:TextInputAction.next,
      decoration:InputDecoration(labelText:waffraTr('اسم الهدف'),hintText:waffraTr('مثال: تجديد المنزل'))),
    ],
    const SizedBox(height:12),
    TextField(controller:target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
     decoration:InputDecoration(labelText:waffraTr('المبلغ المستهدف بالريال'),hintText:waffraTr('مثال: 25000'))),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
    FilledButton(onPressed:(){
     final n=amountOf(target.text);
     if(name.text.trim().isEmpty||n==null){
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:WaffraText('اكتب اسم الهدف ومبلغًا صحيحًا أكبر من صفر')));
      return;
     }
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
  final n=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText('إضافة ادخار لـ ${g.name}'),
   content:TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    decoration:InputDecoration(labelText:waffraTr('المبلغ المدّخر'))),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
    FilledButton(onPressed:(){
     final v=amountOf(amount.text);if(v!=null)Navigator.pop(ctx,v);
    },child:const WaffraText('إضافة')),
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
 Widget goalsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  WaffraText('أهداف الادخار',style:Theme.of(context).textTheme.titleLarge),
  const SizedBox(height:8),
  const WaffraText('خلّ حلمك هدف وامش له خطوة بخطوة'),
  const SizedBox(height:12),
  FilledButton.icon(onPressed:goalDialog,icon:const Icon(Icons.add),label:const WaffraText('هدف جديد')),
  const SizedBox(height:12),
  ...goals.map((g)=>Card(child:Padding(padding:const EdgeInsets.all(14),
   child:Column(children:[
    Row(children:[
     Icon(goalIcon(g.name),color:emerald),const SizedBox(width:8),
     Expanded(child:WaffraText(g.name,style:const TextStyle(fontWeight:FontWeight.bold))),
     PopupMenuButton<String>(onSelected:(v)async {
      if(v=='delete'){setState(()=>goals.removeWhere((x)=>x.id==g.id));await persist();}
     },itemBuilder:(_)=>const [PopupMenuItem(value:'delete',child:WaffraText('حذف الهدف'))]),
    ]),
    const SizedBox(height:10),
    LinearProgressIndicator(value:(g.saved/g.target).clamp(0.0,1.0),
     minHeight:10,borderRadius:BorderRadius.circular(10)),
    const SizedBox(height:8),
    Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:6,
     children:[RiyalAmount(g.saved),const WaffraText('من'),RiyalAmount(g.target)]),
    if(g.saved>=g.target)
     const WaffraText('🎉 مبروك! تم تحقيق الهدف',
      style:TextStyle(fontWeight:FontWeight.bold,color:emerald))
    else WaffraText('المتبقي للهدف: ${cash((g.target-g.saved).clamp(0.0,double.infinity))}',
     style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
    TextButton.icon(onPressed:()=>fundGoal(g),icon:const Icon(Icons.add),label:const WaffraText('أضف مبلغ مدّخر')),
   ])))),
  if(goals.isEmpty) SizedBox(height:MediaQuery.sizeOf(context).height*0.48,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
   Icon(Icons.account_balance_wallet_outlined,size:78,color:emerald.withValues(alpha:0.55)),
   const SizedBox(height:18),
   WaffraText('ما أضفت أي هدف ادخار للحين',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium),
   const SizedBox(height:8),
   const WaffraText('ابدأ بإضافة أول هدف ادخار لك',textAlign:TextAlign.center),
  ]))),
  const SizedBox(height:90),
 ]);
 Future<void> recurringDialog()async {
  final title=TextEditingController(),amount=TextEditingController(),day=TextEditingController(text:'1');
  bool income=false;String category=forType(false).first.name;
  final r=await showDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forType(income);
    final selected=options.any((x)=>x.name==category)?category:options.first.name;
    return AlertDialog(title:const WaffraText('عملية شهرية متكررة'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:title,decoration:InputDecoration(labelText:waffraTr('الوصف'))),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       decoration:InputDecoration(labelText:waffraTr('المبلغ'))),
      DropdownButtonFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:(v){if(v!=null)update((){income=v;category=forType(v).first.name;});}),
      DropdownButtonFormField<String>(key:ValueKey('$income-$selected'),initialValue:selected,
       items:options.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      TextField(controller:day,keyboardType:TextInputType.number,
       decoration:InputDecoration(labelText:waffraTr('يوم الشهر (1 - 31)'))),
     ])),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:(){
       final n=amountOf(amount.text),d=int.tryParse(digits(day.text));
       if(title.text.trim().isNotEmpty&&n!=null&&d!=null&&d>=1&&d<=31){
        Navigator.pop(ctx,RecurringBill(id:newId(),title:title.text.trim(),category:category,
         amount:n,income:income,day:d));
       }
      },child:const WaffraText('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState(()=>recurring.add(r));await persist();await applyRecurring();
  }
 }
 Widget recurringPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  WaffraText('العمليات المتكررة',style:Theme.of(context).textTheme.titleLarge),
  const SizedBox(height:8),
  const WaffraText('نسجّل العملية المستحقة مرة وحدة لكل شهر عند فتح التطبيق.'),
  const SizedBox(height:12),
  FilledButton.icon(onPressed:recurringDialog,icon:const Icon(Icons.add),label:const WaffraText('عملية متكررة جديدة')),
  const SizedBox(height:12),
  ...recurring.map((r)=>Card(child:ListTile(
   leading:Icon(r.income?Icons.south_west:Icons.event_repeat,color:emerald),
   title:WaffraText(r.title),subtitle:WaffraText('${r.category} • يوم ${r.day} من كل شهر'),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    RiyalAmount(r.amount),
    IconButton(onPressed:()async {
     final ok=await confirm('حذف التكرار','تبي توقف تكرار ${r.title}؟ العمليات المسجّلة بتبقى محفوظة.');
     if(ok==true&&mounted){setState(()=>recurring.removeWhere((x)=>x.id==r.id));await persist();}
    },icon:const Icon(Icons.delete_outline)),
   ])))),
  if(recurring.isEmpty) SizedBox(height:MediaQuery.sizeOf(context).height*0.48,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
   Icon(Icons.repeat,size:78,color:emerald.withValues(alpha:0.55)),
   const SizedBox(height:18),
   WaffraText('ما عندك عمليات متكررة',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium),
   const SizedBox(height:8),
   const WaffraText('أضف عملية متكررة لتنظيم مصروفاتك الشهرية',textAlign:TextAlign.center),
  ]))),
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
    },child:const WaffraText('استعادة')),
   ]));
  disposeLater([input]);
 }
 Future<void> configurePin()async {
  final c=TextEditingController();
  final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(widget.pinEnabled?'إلغاء رمز القفل':'إنشاء رمز قفل'),
   content:TextField(controller:c,keyboardType:TextInputType.number,obscureText:true,maxLength:8,
    decoration:InputDecoration(labelText:widget.pinEnabled?'أدخل الرمز الحالي':'رمز من 4 إلى 8 أرقام')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
    FilledButton(onPressed:(){
     final value=c.text.trim();
     if(!RegExp(r'^\d{4,8}$').hasMatch(value)){
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:WaffraText('اكتب 4 إلى 8 أرقام')));
      return;
     }
     Navigator.pop(ctx,value);
    },child:const WaffraText('تأكيد')),
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
  if(widget.profile.name.trim().isNotEmpty&&widget.profile.name!='يا غالي') WaffraText(widget.profile.name,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
  WaffraText(widget.profile.email,textAlign:TextAlign.center),
  const SizedBox(height:16),
  Card(child:Column(children:[
   ListTile(leading:const Icon(Icons.people),title:const WaffraText('الجنس'),subtitle:WaffraText(waffraIsEnglish?({'غير محدد':'Not specified','ذكر':'Male','أنثى':'Female'}[widget.profile.gender]??widget.profile.gender):widget.profile.gender)),
   ListTile(leading:const Icon(Icons.cake),title:const WaffraText('تاريخ الميلاد'),subtitle:WaffraText(dayText(widget.profile.birthday))),
   ListTile(leading:const Icon(Icons.login),title:const WaffraText('طريقة إنشاء الملف الشخصي'),subtitle:WaffraText(waffraIsEnglish?({'محلي':'Local','جوجل':'Google','آبل':'Apple'}[widget.profile.provider]??widget.profile.provider):widget.profile.provider)),
  ])),
  const SizedBox(height:12),
  OutlinedButton.icon(onPressed:()async {
   await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ProfileForm(
    provider:widget.profile.provider,initial:widget.profile,onSave:widget.onProfile)));
  },icon:const Icon(Icons.edit),label:const WaffraText('تعديل حسابي')),
  const SizedBox(height:14),
  const WaffraText('إعدادات التطبيق',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  Card(child:ListTile(
   leading:const Icon(Icons.language),
   title:const WaffraText('لغة التطبيق'),
   subtitle:WaffraText(waffraIsEnglish?'English':'العربية'),
   trailing:SegmentedButton<String>(
    segments:const [
     ButtonSegment(value:'ar',label:WaffraText('AR')),
     ButtonSegment(value:'en',label:WaffraText('EN')),
    ],
    selected:{waffraLanguage.value},
    onSelectionChanged:(v)async{setState(()=>tab=0);await widget.onLanguage(v.first);},
    showSelectedIcon:false,
   ),
  )),
  const SizedBox(height:14),
  const WaffraText('الأمان والخصوصية',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  Card(child:Column(children:[
   ListTile(onTap:configurePin,leading:Icon(widget.pinEnabled?Icons.lock:Icons.lock_open),
    title:const WaffraText('قفل التطبيق برمز PIN'),
    subtitle:WaffraText(widget.pinEnabled?'مفعّل — اضغط لإلغاء القفل':'غير مفعّل — اضغط للتفعيل'),
    trailing:const Icon(Icons.chevron_left)),
   const Divider(height:1),
   ValueListenableBuilder<bool>(valueListenable:allowWaffraScreenshots,
    builder:(context,allowed,_)=>SwitchListTile(
     secondary:Icon(allowed?Icons.screenshot:Icons.shield_outlined),
     title:const WaffraText('السماح بلقطات الشاشة'),
     subtitle:WaffraText(allowed?'مسموح — يمكن تصوير محتوى التطبيق':'ممنوع — حماية بياناتك مفعّلة'),
     value:allowed,onChanged:(v)async{
      await setWaffraScreenshotsAllowed(v);
      if(mounted)snack(context,v?'تم السماح بلقطات الشاشة':'تم منع لقطات الشاشة لحماية بياناتك');
     })),
  ])),
  OutlinedButton.icon(onPressed:()=>Navigator.push<void>(context,
   MaterialPageRoute(builder:(_)=>CurrencyConverterPage(lastIncomeAmount:entries.where((e)=>e.income).isEmpty?null:entries.where((e)=>e.income).reduce((a,b)=>a.date.isAfter(b.date)?a:b).amount))),
   icon:const Icon(Icons.currency_exchange),label:const WaffraText('تحويل العملات')),
  OutlinedButton.icon(onPressed:widget.onTheme,
   icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode),label:const WaffraText('تغيير المظهر')),
  OutlinedButton.icon(onPressed:backupDialog,icon:const Icon(Icons.backup_outlined),
   label:const WaffraText('النسخ الاحتياطي والاستعادة')),
  if(widget.profile.provider=='محلي')FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.login),
   label:const WaffraText('تسجيل الدخول')),
  if(widget.profile.provider!='محلي')FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),
   label:const WaffraText('تسجيل الخروج')),
  const SizedBox(height:16),
  const WaffraText('بياناتك محفوظة على جهازك. احفظ نسخة احتياطية قبل تغيير الجوال أو حذف التطبيق. ما فيه ربط بالحسابات البنكية.',
   textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
 ]);
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const WaffraText('وفرة | Waffra',style:TextStyle(fontWeight:FontWeight.bold)),
   actions:[
    TextButton(
     onPressed:()async{
      final next=waffraIsEnglish?'ar':'en';
      setState(()=>tab=0);
      await widget.onLanguage(next);
     },
     style:TextButton.styleFrom(foregroundColor:Colors.white),
     child:Text(waffraIsEnglish?'AR':'EN',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
    ),
    ValueListenableBuilder<bool>(
     valueListenable:hideWaffraAmounts,
     builder:(context,hidden,_)=>IconButton(
      tooltip:hidden?'إظهار المبالغ':'إخفاء المبالغ',
      onPressed:()=>hideWaffraAmounts.value=!hidden,
      icon:Icon(hidden?Icons.visibility_off_outlined:Icons.visibility_outlined))),

    IconButton(onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode)),
    Padding(padding:const EdgeInsets.only(left:12),
     child:InkWell(onTap:()=>setState(()=>tab=5),borderRadius:BorderRadius.circular(30),child:saudiAvatar(widget.profile.gender))),
   ]),
  body:!ready?const Center(child:CircularProgressIndicator()):
   AnimatedSwitcher(duration:const Duration(milliseconds:430),reverseDuration:const Duration(milliseconds:250),
    transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,child:SlideTransition(
     position:Tween<Offset>(begin:const Offset(0.035,0),end:Offset.zero).animate(CurvedAnimation(parent:animation,curve:Curves.easeOutCubic)),child:child)),
    child:KeyedSubtree(key:ValueKey(tab),child:[dashboard(),analytics(),categoriesPage(),goalsPage(),recurringPage(),profilePage()][tab])),
  floatingActionButton:tab==0?FloatingActionButton.extended(
   onPressed:()=>entrySheet(),icon:const Icon(Icons.add),label:const WaffraText('أضف عملية')):null,
  bottomNavigationBar:NavigationBar(height:74,indicatorColor:const Color(0xFFCFE9D9),
   labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
   selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
   destinations:[
    NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:waffraTr('الرئيسية')),
    NavigationDestination(icon:const Icon(Icons.bar_chart_outlined),label:waffraTr('التحليلات')),
    NavigationDestination(icon:const Icon(Icons.category_outlined),label:waffraTr('الأقسام')),
    NavigationDestination(icon:const Icon(Icons.account_balance_wallet_outlined),label:waffraTr('الادخار')),
    NavigationDestination(icon:const Icon(Icons.repeat),label:waffraTr('المتكررة')),
    NavigationDestination(icon:const Icon(Icons.person_outline),label:waffraTr('حسابي')),
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
