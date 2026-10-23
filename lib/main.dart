import 'package:flutter_svg/flutter_svg.dart';
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
import 'waffra_financial_tools.dart';
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
import 'waffra_google_auth.dart';
import 'waffra_category_catalog.dart';
import 'waffra_goal_catalog.dart';
import 'waffra_pdf_reader.dart';
import 'waffra_footer.dart';
import 'waffra_messages.dart';
import 'waffra_recurring_policy.dart';
import 'waffra_secure_backup.dart';
import 'waffra_home_widget.dart';
part 'waffra_categories_page.part.dart';
part 'waffra_smart_analysis.part.dart';
part 'waffra_recurring_trash.part.dart';
part 'waffra_deleted_item_card.part.dart';
part 'waffra_widget_capture.part.dart';

Future<void> main()async {
 WidgetsFlutterBinding.ensureInitialized();
 // Flutter engine started by the circular Android widget, not the normal app.
 if(WidgetsBinding.instance.platformDispatcher.defaultRouteName=='/waffra-widget'){
  runApp(const WaffraWidgetCaptureApp());
  return;
 }
 await initializeWaffraMessages();
 await initializeWaffraHomeWidget();
 runApp(const WaffraApp());
}
// Waffra visual identity / Saudi government-grade accessible emerald palette.
// Visual-only constants: do not change financial data, flows, or persistence keys.
const emerald=Color(0xFF0C7957), forest=Color(0xFF073F31),
 sand=Color(0xFFF4FAF7), gold=Color(0xFFD8BA78);
const waffraMint=Color(0xFFEAF5EE),
 waffraIncomeBackground=Color(0xFFB2D5C2),
 waffraExpenseBackground=Color(0xFFFCECE8),
 waffraInk=Color(0xFF183B33);
/// Accessible 1.2px emerald outline for both Waffra dialog themes.
BorderSide waffraDialogOutline(Brightness brightness)=>BorderSide(
 color:brightness==Brightness.dark?const Color(0xFF74D8A9):const Color(0xFF0C7957),
 width:1.2,
);

Color waffraIncomeTone(BuildContext context)=>Theme.of(context).brightness==Brightness.dark?const Color(0xFF6CE0AB):const Color(0xFF075C40);
final ValueNotifier<int> waffraReturnHome=ValueNotifier<int>(0);
final ValueNotifier<String> waffraAnimationLevel=ValueNotifier<String>('balanced');
Duration waffraMotion(int milliseconds){
 if(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations)return Duration.zero;
 final factor=switch(waffraAnimationLevel.value){
  'full'=>1.35,'reduced'=>0.45,'off'=>0.0,_=>1.0,
 };
 return Duration(milliseconds:(milliseconds*factor).round());
}
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
/// Preserve older single-receipt records while supporting multiple images.
List<String> waffraReceiptPaths(String? value){
 if(value==null||value.trim().isEmpty)return [];
 if(value.startsWith('[')){
  try{return (jsonDecode(value) as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList();}
  catch(_){}
 }
 return [value];
}
String? waffraEncodeReceipts(List<String> paths)=>
 paths.isEmpty?null:(paths.length==1?paths.first:jsonEncode(paths));

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
 final String id,name,icon,parentId;
 final int color;final bool income;final double budget;final int alertPercent;
 BudgetCategory({required this.id,required this.name,required this.icon,required this.color,required this.income,this.parentId='',this.budget=0,this.alertPercent=80});
 bool get isSubcategory=>parentId.isNotEmpty;
 String get displayName=>isSubcategory?name.split(' / ').last:name;
 BudgetCategory copy({String? name,String? icon,int? color,double? budget,int? alertPercent,String? parentId})=>BudgetCategory(id:id,name:name??this.name,icon:icon??this.icon,color:color??this.color,income:income,parentId:parentId??this.parentId,budget:budget??this.budget,alertPercent:alertPercent??this.alertPercent);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'icon':icon,'color':color,'income':income,'parentId':parentId,'budget':budget,'alertPercent':alertPercent};
 factory BudgetCategory.fromJson(Map<String,dynamic> j)=>BudgetCategory(id:'${j['id']??newId()}',name:'${j['name']??'أخرى'}',icon:'${j['icon']??'category'}',color:(j['color'] as num?)?.toInt()??0xFF087A54,income:j['income']==true,parentId:'${j['parentId']??''}',budget:(j['budget'] as num?)?.toDouble()??0,alertPercent:(j['alertPercent'] as num?)?.toInt()??80);
}
/// Manual transactions must target an active child category, never a heading.
List<BudgetCategory> waffraManualCategoryParents(
 Iterable<BudgetCategory> values,bool income)=>
 values.where((c)=>c.income==income&&!c.isSubcategory).toList();

List<BudgetCategory> waffraManualCategoryChildren(
 Iterable<BudgetCategory> values,bool income,String? parentId)=>
 parentId==null?<BudgetCategory>[]:
 values.where((c)=>c.income==income&&c.isSubcategory&&c.parentId==parentId).toList();

bool waffraCanAssignManualCategory(Iterable<BudgetCategory> values,
 bool income,String? parentId,String category){
 if(parentId==null)return false;
 return values.any((c)=>c.income==income&&!c.isSubcategory&&c.id==parentId)&&
  values.any((c)=>c.income==income&&c.isSubcategory&&
   c.parentId==parentId&&c.name==category);
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
 final DateTime startAt;
 RecurringBill({required this.id,required this.title,required this.category,required this.amount,required this.income,required this.day,this.active=true,DateTime? startAt}):startAt=startAt??DateTime.now();
 RecurringBill copy({bool? active,int? day,DateTime? startAt})=>RecurringBill(id:id,title:title,category:category,amount:amount,income:income,day:day??this.day,active:active??this.active,startAt:startAt??this.startAt);
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'income':income,'day':day,'active':active,'startAt':startAt.toIso8601String()};
 factory RecurringBill.fromJson(Map<String,dynamic> j)=>RecurringBill(id:'${j['id']??newId()}',
  title:'${j['title']??''}',category:'${j['category']??'أخرى'}',
  amount:(j['amount'] as num).toDouble(),income:j['income']==true,
  day:(j['day'] as num?)?.toInt()??1,active:j['active']!=false,
  startAt:DateTime.tryParse('${j['startAt']??''}')??DateTime.now());
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
  case 'coffee':return Icons.local_cafe;
  case 'groceries':return Icons.local_grocery_store;
  case 'family':return Icons.family_restroom;
  case 'baby':return Icons.child_care;
  case 'entertainment':return Icons.theaters;
  case 'subscriptions':return Icons.subscriptions;
  case 'sadaqat':return Icons.volunteer_activism;
  case 'charity':return Icons.favorite;
  case 'zakat':return Icons.mosque;
  case 'pets':return Icons.pets;
  case 'insurance':return Icons.verified_user;
  case 'business':return Icons.business_center;
  case 'government':return Icons.account_balance;
  case 'bank':return Icons.account_balance_wallet;
  case 'wedding':return Icons.celebration;
  case 'tools':return Icons.handyman;
  case 'device':return Icons.devices;
  case 'freelance':return Icons.laptop_mac;
  case 'gaming':return Icons.sports_esports;
  case 'tax':return Icons.request_quote;
  case 'investment':return Icons.show_chart;
  case 'pension':return Icons.elderly;
  case 'agriculture':return Icons.agriculture;
  default:return Icons.category;
 }
}
IconData avatarIcon(String s)=>s=='male'?Icons.face:s=='female'?Icons.face_3:s=='smile'?Icons.sentiment_very_satisfied:Icons.person;
Widget saudiAvatar(String gender,{double radius=25})=>CircleAvatar(radius:radius,backgroundColor:const Color(0xFFE5F1E9),backgroundImage:AssetImage(gender=='أنثى'||gender=='female'?'assets/avatar_saudi_female.png':'assets/avatar_saudi_male.png'));
Widget waffraAvatar(String gender,String avatar,{double radius=25}) {
 if(avatar.startsWith('https://'))return CircleAvatar(radius:radius,backgroundColor:const Color(0xFFE5F1E9),backgroundImage:NetworkImage(avatar));
 final file=avatar.startsWith('file:')?File(avatar.substring(5)):null;
 if(file!=null&&file.existsSync()){
  return CircleAvatar(radius:radius,backgroundColor:const Color(0xFFE5F1E9),
   backgroundImage:FileImage(file));
 }
 return saudiAvatar(gender,radius:radius);
}

const colors=[0xFF087A54,0xFFED7045,0xFF3867D6,0xFF9C56B8,0xFFDF9C24,0xFF008C9E,0xFFDA5079,0xFF687B42];
List<BudgetCategory> defaultCategories()=>[
 for(final group in waffraCategoryCatalog)...[
  BudgetCategory(id:group.id,name:group.name,icon:group.icon,color:colors[group.colorIndex],income:group.income),
  for(var i=0;i<group.subcategories.length;i++)
   BudgetCategory(id:'${group.id}_sub_$i',name:'${group.name} / ${group.subcategories[i]}',
    icon:group.icon,color:colors[group.colorIndex],income:group.income,parentId:group.id),
 ],
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

/// Consistent frosted backdrop for all app dialogs.
Future<T?> showWaffraDialog<T>({
 required BuildContext context,
 required WidgetBuilder builder,
 bool barrierDismissible=true,
 Color? barrierColor,
 bool useRootNavigator=true,
 RouteSettings? routeSettings,
 Offset? anchorPoint,
})=>showDialog<T>(
 context:context,
 barrierDismissible:barrierDismissible,
 barrierColor:barrierColor??Colors.black.withValues(alpha:.28),
 useRootNavigator:useRootNavigator,
 routeSettings:routeSettings,
 anchorPoint:anchorPoint,
 builder:(dialogContext)=>BackdropFilter(
  filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7),
  child:builder(dialogContext)),
);

String get waffraRequiredFieldMessage => waffraIsEnglish?'This field is required':'هذا الحقل مطلوب';
String? waffraTextFieldError(String? raw,{int maxLength=100}) {
 final issue=WaffraValidators.requiredText(raw,maxLength:maxLength);
 if(issue=='required')return waffraRequiredFieldMessage;
 if(issue=='too_long')return waffraIsEnglish?'Maximum '+maxLength.toString()+' characters':'الحد الأقصى '+maxLength.toString()+' حرف';
 return null;
}
String? waffraAmountFieldError(String? raw,{bool required=true}) {
 final issue=WaffraValidators.positiveAmount(raw,required:required);
 if(issue=='required')return waffraRequiredFieldMessage;
 if(issue!=null)return waffraIsEnglish?'Enter an amount greater than zero':'أدخل مبلغًا صحيحًا أكبر من صفر';
 return null;
}
String? waffraMobileFieldError(String? raw) {
 if((raw??'').trim().isEmpty)return waffraRequiredFieldMessage;
 return WaffraValidators.mobileNumber(raw)==null?null:(waffraIsEnglish?'Mobile number must start with 05 and contain 10 digits':'رقم الجوال يجب أن يبدأ بـ 05 ويتكون من 10 أرقام');
}
String? waffraPasswordFieldError(String? raw) {
 if((raw??'').isEmpty)return waffraRequiredFieldMessage;
 return RegExp(r'^(?=.*[A-Za-z])(?=.*[0-9]).{8,}$').hasMatch(raw!)?null:(waffraIsEnglish?'Use at least 8 characters with letters and numbers':'كلمة المرور يجب أن تكون 8 خانات على الأقل وتشمل أحرفًا وأرقامًا');
}
String? waffraConfirmPasswordFieldError(String? raw,String password) {
 if((raw??'').isEmpty)return waffraRequiredFieldMessage;
 return raw==password?null:(waffraIsEnglish?'Passwords do not match':'كلمتا المرور غير متطابقتين');
}
String? waffraDayFieldError(String? raw) {
 if((raw??'').trim().isEmpty)return waffraRequiredFieldMessage;
 return WaffraValidators.dayOfMonth(raw)==null?null:(waffraIsEnglish?'Enter a day between 1 and 31':'أدخل يومًا صحيحًا من 1 إلى 31');
}
String? waffraPinFieldError(String? raw,{bool existing=false}) {
 if((raw??'').isEmpty)return waffraRequiredFieldMessage;
 final pattern=existing?RegExp(r'^[0-9]{4,8}$'):RegExp(r'^[0-9]{4}$');
 return pattern.hasMatch(raw!)?null:(waffraIsEnglish?(existing?'PIN must contain 4 to 8 digits':'PIN must contain exactly 4 digits'):(existing?'أدخل من 4 إلى 8 أرقام':'أدخل أربعة أرقام بالضبط'));
}

class WaffraApp extends StatefulWidget {
 const WaffraApp({super.key});
 @override State<WaffraApp> createState()=>_WaffraAppState();
}
class _WaffraAppState extends State<WaffraApp> with WidgetsBindingObserver {
 bool loading=true,onboarded=false,dark=false,locked=false,showLogin=false;
 String appearance='system';
 bool introDone=false;
 String language='ar';
 String? pinHash;Person? profile;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();launchIntro();}
 Future<void> launchIntro()async{
  // Show the approved cinematic launch for three seconds on each cold start.
  await Future<void>.delayed(const Duration(milliseconds:3000));
  if(mounted)setState(()=>introDone=true);
 }
 DateTime? _backgroundAt;
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden){_backgroundAt=DateTime.now();}
  // Returning from Android notification permission must not change the active tab.
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
   hideWaffraAmounts.value=p.getBool('waffra_hide_amounts')??false;
   language=p.getString('waffra_language')=='en'?'en':'ar';
   final animation=p.getString('waffra_animation_level');
   waffraAnimationLevel.value={'full','balanced','reduced','off'}.contains(animation)?animation!:'balanced';
   waffraLanguage.value=language;
   allowWaffraScreenshots.value=screenshotsAllowed;
   if(Platform.isAndroid){
    try{await _privacyChannel.invokeMethod<void>('setScreenshotsAllowed',screenshotsAllowed).timeout(const Duration(seconds:3));}
    catch(e){debugPrint('Privacy initialization failed: $e');}
   }
   if(!mounted)return;
   setState((){
    onboarded=p.getBool('waffra_onboarding_completed')??false;
    appearance=p.getString('waffra_appearance_mode_v1')??(p.containsKey('waffra_dark_mode')?(p.getBool('waffra_dark_mode')==true?'dark':'light'):'system');
    if(!{'light','dark','system'}.contains(appearance))appearance='system';
    dark=appearance=='dark'||(appearance=='system'&&WidgetsBinding.instance.platformDispatcher.platformBrightness==Brightness.dark);
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
  await p.setString('waffra_last_login_method',u.provider.toLowerCase().contains('google')?'Google':u.provider.toLowerCase().contains('apple')?'Apple':u.phone.trim().isNotEmpty?'Phone':'Local');
  if(u.email.trim().isNotEmpty)await p.setString('waffra_last_login_email',u.email.trim());
  if(u.phone.trim().isNotEmpty)await p.setString('waffra_last_login_phone',u.phone.trim());
  if(mounted)setState((){profile=u;showLogin=false;});
 }
 Future<void> logout()async {
  final p=await SharedPreferences.getInstance();await p.remove('waffra_profile');
  await p.setBool('waffra_signed_out_explicitly',true);
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
 Future<void> theme()async => setAppearance(appearance=='dark'?'light':'dark');
 Future<void> setAppearance(String mode)async {
  if(!{'light','dark','system'}.contains(mode))return;
  if(mounted)setState((){appearance=mode;
   dark=mode=='dark'||(mode=='system'&&WidgetsBinding.instance.platformDispatcher.platformBrightness==Brightness.dark);});
  final p=await SharedPreferences.getInstance();
  await p.setString('waffra_appearance_mode_v1',mode);
  await p.setBool('waffra_dark_mode',dark);
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
    child:AnimatedSwitcher(duration:waffraMotion(240),switchInCurve:Curves.easeOutCubic,
     transitionBuilder:(w,a)=>FadeTransition(opacity:a,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0.11,0),end:Offset.zero).animate(a),child:w)),
     child:KeyedSubtree(key:ValueKey(language),child:child??const SizedBox.shrink())))),

  theme:ThemeData(
   useMaterial3:true,
   colorScheme:ColorScheme.fromSeed(seedColor:forest,brightness:Brightness.light).copyWith(
    primary:forest,onPrimary:Colors.white,
    secondary:emerald,surface:Colors.white,onSurface:waffraInk),
   scaffoldBackgroundColor:sand,
   canvasColor:sand,
   cardColor:Colors.white,
   fontFamily:'Tajawal',
   textTheme:ThemeData.light().textTheme.apply(fontFamily:'Tajawal',bodyColor:waffraInk,displayColor:waffraInk),
   primaryTextTheme:ThemeData.light().primaryTextTheme.apply(fontFamily:'Tajawal'),
   appBarTheme:const AppBarTheme(
    backgroundColor:forest,foregroundColor:Colors.white,
    elevation:0,scrolledUnderElevation:0,centerTitle:false,
    titleTextStyle:TextStyle(fontFamily:'Tajawal',fontSize:21,
     fontWeight:FontWeight.bold,color:Colors.white)),
   cardTheme:CardThemeData(
    color:Colors.white,elevation:0,clipBehavior:Clip.antiAlias,
    margin:const EdgeInsets.symmetric(vertical:5),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),
     side:const BorderSide(color:Color(0xFFE0EDE6),width:.9))),
   navigationBarTheme:NavigationBarThemeData(
    backgroundColor:forest,elevation:4,height:78,
    surfaceTintColor:forest,indicatorColor:const Color(0xFF207B59),
    labelTextStyle:WidgetStateProperty.resolveWith((states)=>TextStyle(
     color:states.contains(WidgetState.selected)?Colors.white:const Color(0xFFD1E6DC),
     fontFamily:'Tajawal',fontSize:10.5,
     fontWeight:states.contains(WidgetState.selected)?FontWeight.bold:FontWeight.w500)),
    iconTheme:WidgetStateProperty.resolveWith((states)=>IconThemeData(
     color:states.contains(WidgetState.selected)?Colors.white:const Color(0xFFD1E6DC),size:24))),
   iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(
    side:const BorderSide(color:Color(0xFF0C7957),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
    minimumSize:const Size(36,36),alignment:Alignment.center)),
   filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
    backgroundColor:forest,foregroundColor:Colors.white,
    minimumSize:const Size(0,46),alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF0C7957),width:1.2),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
    foregroundColor:forest,alignment:Alignment.center,side:const BorderSide(color:Color(0xFF0C7957),width:1.2),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
    foregroundColor:forest,alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF0C7957),width:1.1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))),
   inputDecorationTheme:InputDecorationTheme(
    filled:true,fillColor:Colors.white,
    contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:13),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFFCFE3D7))),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:emerald,width:1.7)),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
    labelStyle:const TextStyle(color:forest),hintStyle:const TextStyle(color:Color(0xFF7B9084))),
   chipTheme:ChipThemeData(
    backgroundColor:Colors.white,selectedColor:waffraMint,
    side:const BorderSide(color:Color(0xFFD5E8DD)),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    labelStyle:const TextStyle(fontFamily:'Tajawal',color:forest)),
   dialogTheme:DialogThemeData(
    backgroundColor:Colors.white,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
     side:waffraDialogOutline(Brightness.light))),
   bottomSheetTheme:BottomSheetThemeData(
    backgroundColor:Colors.white,modalBackgroundColor:Colors.white,
    showDragHandle:true,dragHandleColor:const Color(0xFFB5D9C6),
    shape:RoundedRectangleBorder(
     borderRadius:const BorderRadius.vertical(top:Radius.circular(27)),
     side:waffraDialogOutline(Brightness.light))),
   popupMenuTheme:PopupMenuThemeData(
    color:Colors.white,elevation:7,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
   listTileTheme:const ListTileThemeData(
    iconColor:forest,textColor:waffraInk,
    contentPadding:EdgeInsets.symmetric(horizontal:15,vertical:2)),
   floatingActionButtonTheme:const FloatingActionButtonThemeData(
    backgroundColor:forest,foregroundColor:Colors.white),
   dividerTheme:const DividerThemeData(color:Color(0xFFE1EDE6),thickness:.8),
  ),
  darkTheme:ThemeData(
   useMaterial3:true,
   brightness:Brightness.dark,
   colorScheme:ColorScheme.fromSeed(seedColor:emerald,brightness:Brightness.dark).copyWith(
    primary:const Color(0xFF74DCAB),onPrimary:forest,
    secondary:const Color(0xFF8AE0B3),surface:const Color(0xFF191D1B),
    onSurface:Colors.white),
   scaffoldBackgroundColor:const Color(0xFF080A09),
   canvasColor:const Color(0xFF080A09),
   cardColor:const Color(0xFF191D1B),
   fontFamily:'Tajawal',
   textTheme:ThemeData.dark().textTheme.apply(fontFamily:'Tajawal'),
   primaryTextTheme:ThemeData.dark().primaryTextTheme.apply(fontFamily:'Tajawal'),
   appBarTheme:const AppBarTheme(
    backgroundColor:forest,foregroundColor:Colors.white,
    elevation:0,scrolledUnderElevation:0,
    titleTextStyle:TextStyle(fontFamily:'Tajawal',fontSize:21,
     fontWeight:FontWeight.bold,color:Colors.white)),
   cardTheme:CardThemeData(
    color:const Color(0xFF191D1B),elevation:0,clipBehavior:Clip.antiAlias,
    margin:const EdgeInsets.symmetric(vertical:5),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),
     side:const BorderSide(color:Color(0xFF343E36)))),
   navigationBarTheme:NavigationBarThemeData(
    backgroundColor:forest,height:78,
    indicatorColor:const Color(0xFF207B59),
    labelTextStyle:WidgetStateProperty.resolveWith((states)=>TextStyle(
     color:states.contains(WidgetState.selected)?Colors.white:const Color(0xFFC0D5C9),
     fontFamily:'Tajawal',fontSize:10.5,
     fontWeight:states.contains(WidgetState.selected)?FontWeight.bold:FontWeight.w500)),
    iconTheme:WidgetStateProperty.resolveWith((states)=>IconThemeData(
     color:states.contains(WidgetState.selected)?Colors.white:const Color(0xFFBDD7C8),size:24))),
   iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(
    side:const BorderSide(color:Color(0xFF74DCAB),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
    minimumSize:const Size(36,36),alignment:Alignment.center)),
   filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
    backgroundColor:const Color(0xFF166E4F),foregroundColor:Colors.white,alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF74DCAB),width:1.1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
    foregroundColor:Colors.white,alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF74DCAB)),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
    foregroundColor:Colors.white,alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF74DCAB)),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))),
   inputDecorationTheme:InputDecorationTheme(
    filled:true,fillColor:const Color(0xFF202522),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFF4A6052))),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFF8EDDB5),width:1.6)),
    labelStyle:const TextStyle(color:Color(0xFFE6FFF0)),
    hintStyle:const TextStyle(color:Color(0xFFAACBBC))),
   chipTheme:ChipThemeData(
    backgroundColor:const Color(0xFF1B241F),selectedColor:const Color(0xFF28533C),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    labelStyle:const TextStyle(color:Colors.white)),
   dialogTheme:DialogThemeData(
    backgroundColor:const Color(0xFF191D1B),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
     side:waffraDialogOutline(Brightness.dark))),
   bottomSheetTheme:BottomSheetThemeData(
    backgroundColor:const Color(0xFF191D1B),
    modalBackgroundColor:const Color(0xFF191D1B),
    shape:RoundedRectangleBorder(
     borderRadius:const BorderRadius.vertical(top:Radius.circular(27)),
     side:waffraDialogOutline(Brightness.dark))),
   popupMenuTheme:PopupMenuThemeData(
    color:const Color(0xFF202522),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
   listTileTheme:const ListTileThemeData(iconColor:Colors.white,textColor:Colors.white),
   floatingActionButtonTheme:const FloatingActionButtonThemeData(
    backgroundColor:forest,foregroundColor:Colors.white),
   dividerTheme:const DividerThemeData(color:Color(0xFF394039),thickness:.8),
  ),
  themeMode:appearance=='system'?ThemeMode.system:(appearance=='dark'?ThemeMode.dark:ThemeMode.light),
  themeAnimationDuration:waffraMotion(250),
  themeAnimationCurve:Curves.easeInOutCubic,
  home:Builder(builder:(rootContext)=>PopScope(canPop:false,onPopInvokedWithResult:(didPop,result)async {
   if(didPop||!mounted)return;
   final exit=await showWaffraDialog<bool>(context:rootContext,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Exit Waffra?':'تبي تطلع من وفرة؟'),
    content:WaffraText(waffraIsEnglish?'Do you want to exit the app?':'متأكد تبي تطلع من التطبيق؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:WaffraText(waffraIsEnglish?'No':'لا')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:WaffraText(waffraIsEnglish?'Yes':'نعم'))]));
   if(exit==true)SystemNavigator.pop();
  },child:Directionality(textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,child:
   (loading||!introDone)?const WaffraLaunchIntro():
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
   profile==null||showLogin?LoginScreen(onSave:saveUser):
   HomeScreen(key:ValueKey(language),profile:profile!,
     dark:appearance=='dark'||(appearance=='system'&&MediaQuery.platformBrightnessOf(rootContext)==Brightness.dark),
     appearance:appearance,onAppearance:setAppearance,onTheme:theme,onLanguage:setLanguage,onLogout:logout,onProfile:saveUser,onSetPin:setPin,pinEnabled:pinHash!=null)))));
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
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
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

 Widget _padButton(String label,{IconData? icon,required VoidCallback onPressed}){
  final fingerprint=icon==Icons.fingerprint;
  final compact=MediaQuery.sizeOf(context).height<750;
  final size=compact?54.0:60.0;
  return Semantics(button:true,label:fingerprint?
    (waffraIsEnglish?'Unlock with fingerprint':'فتح بالبصمة'):label,
   child:Material(
    color:fingerprint?const Color(0xFFF1FBF5):const Color(0xFF0A6249),
    shape:CircleBorder(side:BorderSide(
     color:fingerprint?Colors.white:const Color(0xFF69BD94),width:1.15)),
    child:InkWell(customBorder:const CircleBorder(),onTap:busy?null:onPressed,
     child:SizedBox(width:size,height:size,child:Center(child:icon!=null?
      Icon(icon,color:fingerprint?forest:Colors.white,size:compact?22.0:24.0):
      Text(label,style:TextStyle(color:Colors.white,
       fontWeight:FontWeight.bold,fontSize:compact?22.0:24.0)))))));
 }
 void _keyDigit(String digit){
  if(pinController.text.length>=4||busy)return;
  pinController.text+=digit;
  setState((){error='';});
  if(pinController.text.length==4)verifyPin();
 }
 @override Widget build(BuildContext context){
  final compact=MediaQuery.sizeOf(context).height<750;
  return Scaffold(
   backgroundColor:const Color(0xFF003B2E),
   resizeToAvoidBottomInset:false,
   body:Stack(fit:StackFit.expand,children:[
    const DecoratedBox(decoration:BoxDecoration(
     gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF003528),Color(0xFF07573F),Color(0xFF002E23)]))),
    Positioned(top:-155,right:-140,
     child:Container(width:290,height:290,decoration:BoxDecoration(
      shape:BoxShape.circle,
      border:Border.all(color:const Color(0xFF26A176).withValues(alpha:.18),width:46)))),
    Positioned(bottom:-175,left:-100,
     child:Container(width:315,height:315,decoration:BoxDecoration(
      shape:BoxShape.circle,
      color:const Color(0xFF14906B).withValues(alpha:.18)))),
    SafeArea(child:Center(child:SingleChildScrollView(
     padding:const EdgeInsets.fromLTRB(24,15,24,22),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      CustomPaint(size:Size(compact?65.0:78.0,compact?76.0:90.0),
       painter:_WaffraSplashLogoPainter()),
      const SizedBox(height:5),
      Text('Waffra',style:TextStyle(color:Colors.white,
       fontSize:compact?30.0:35.0,fontWeight:FontWeight.bold,height:1.05)),
      const WaffraText('وفرة',style:TextStyle(color:Colors.white,
       fontSize:22,fontWeight:FontWeight.bold,height:1.05)),
      SizedBox(height:compact?23:32),
      WaffraText(waffraIsEnglish?'Welcome back':'مرحبًا بك مجددًا',
       textAlign:TextAlign.center,
       style:TextStyle(color:Colors.white,fontSize:compact?23.0:27.0,
        fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      WaffraText(waffraIsEnglish?'Enter your PIN to unlock Waffra':
       'أدخل رمز القفل لفتح وفرة',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Color(0xFFCFEBDF),fontSize:14)),
      SizedBox(height:compact?13:18),
      Row(mainAxisAlignment:MainAxisAlignment.center,
       children:List.generate(4,(i)=>Container(
        width:12,height:12,margin:const EdgeInsets.symmetric(horizontal:9),
        decoration:BoxDecoration(
         shape:BoxShape.circle,
         color:i<pinController.text.length?Colors.white:Colors.transparent,
         border:Border.all(color:Colors.white,width:1.4))))),
      SizedBox(height:compact?17:24),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('1',onPressed:()=>_keyDigit('1')),
       _padButton('2',onPressed:()=>_keyDigit('2')),
       _padButton('3',onPressed:()=>_keyDigit('3')),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('4',onPressed:()=>_keyDigit('4')),
       _padButton('5',onPressed:()=>_keyDigit('5')),
       _padButton('6',onPressed:()=>_keyDigit('6')),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('7',onPressed:()=>_keyDigit('7')),
       _padButton('8',onPressed:()=>_keyDigit('8')),
       _padButton('9',onPressed:()=>_keyDigit('9')),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('',icon:Icons.fingerprint,onPressed:biometric),
       _padButton('0',onPressed:()=>_keyDigit('0')),
       _padButton('',icon:Icons.backspace_outlined,onPressed:(){
        if(pinController.text.isNotEmpty){
         pinController.text=pinController.text.substring(0,pinController.text.length-1);
         setState(()=>error='');
        }
       }),
      ]),
      if(error.isNotEmpty)Padding(
       padding:const EdgeInsets.only(top:15),
       child:Container(
        width:double.infinity,
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
        decoration:BoxDecoration(color:const Color(0xFF713132),
         borderRadius:BorderRadius.circular(13),
         border:Border.all(color:const Color(0xFFDA807A).withValues(alpha:.6))),
        child:WaffraText(error,textAlign:TextAlign.center,
         style:const TextStyle(color:Color(0xFFFFEAE7),
          fontSize:12,fontWeight:FontWeight.bold)))),
      if(busy)const Padding(padding:EdgeInsets.only(top:12),
       child:SizedBox(width:23,height:23,
        child:CircularProgressIndicator(color:Colors.white,strokeWidth:2.3))),
     ]),
    ))),
   ]),
  );
 }
}

const String _waffraGoogleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.25 5.48-4.76 7.18l7.73 6C44.42 38.03 46.98 31.89 46.98 24.55z"/>
<path fill="#FBBC05" d="M10.53 28.59A14.4 14.4 0 0 1 9.75 24c0-1.59.27-3.13.76-4.59l-7.98-6.2A23.9 23.9 0 0 0 0 24c0 3.87.93 7.52 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.92-2.13 15.91-5.8l-7.73-6c-2.15 1.45-4.92 2.3-8.18 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class WaffraLaunchIntro extends StatefulWidget {
 const WaffraLaunchIntro({super.key});
 @override State<WaffraLaunchIntro> createState()=>_WaffraLaunchIntroState();
}
class _WaffraLaunchIntroState extends State<WaffraLaunchIntro> with SingleTickerProviderStateMixin {
 late final AnimationController controller;
 @override void initState(){
  super.initState();
  controller=AnimationController(vsync:this,duration:const Duration(milliseconds:2850))..forward();
 }
 @override void dispose(){controller.dispose();super.dispose();}
 double reveal(double t,double start,double end)=>((t-start)/(end-start)).clamp(0.0,1.0);
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFF003C2E),
  body:AnimatedBuilder(animation:controller,builder:(ctx,_){
   final t=controller.value;
   final iconProgress=Curves.easeOutBack.transform(reveal(t,.02,.28));
   final nameProgress=Curves.easeOutCubic.transform(reveal(t,.26,.48));
   final sloganProgress=Curves.easeOutCubic.transform(reveal(t,.44,.70));
   final fadeOut=1-reveal(t,.92,1.0);
   return Stack(children:[
    const Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
     gradient:RadialGradient(colors:[Color(0xFF075B43),Color(0xFF003C2E)],radius:1.2)))),
    Center(child:Opacity(opacity:fadeOut,child:Column(mainAxisSize:MainAxisSize.min,children:[
     SizedBox(width:230,height:230,child:Stack(alignment:Alignment.center,children:[
      ...List.generate(3,(i){
       final wave=((t*1.45+i/3)%1.0);
       return Transform.scale(scale:.45+wave*.9,child:Opacity(
        opacity:(1-wave)*.22,child:Container(width:210,height:210,
         decoration:BoxDecoration(shape:BoxShape.circle,
          border:Border.all(color:const Color(0xFF8CF2C0),width:1.4)))));
      }),
      Opacity(opacity:reveal(t,0,.15),child:Transform.scale(
       scale:.55+.45*iconProgress,
       child:CustomPaint(size:const Size(112,135),painter:_WaffraSplashLogoPainter()))),
     ])),
     Opacity(opacity:reveal(t,.26,.48),child:Transform.translate(
      offset:Offset(0,14*(1-nameProgress)),child:Column(children:[
       const Text('Waffra',style:TextStyle(color:Colors.white,fontSize:42,fontWeight:FontWeight.bold,height:1.05)),
       const Text('وفرة',style:TextStyle(color:Colors.white,fontSize:31,fontWeight:FontWeight.bold,height:1.1)),
      ]))),
     const SizedBox(height:15),
     Opacity(opacity:reveal(t,.44,.70),child:Transform.translate(
      offset:Offset(0,10*(1-sloganProgress)),child:Padding(
       padding:const EdgeInsets.symmetric(horizontal:16),
       child:Text(waffraIsEnglish?'Waffra.. shows you where your money goes':
        'وفرة.. يعلّمك وين فلوسك تروح',textAlign:TextAlign.center,
        style:const TextStyle(color:Color(0xFFE8FFF0),fontSize:18,fontWeight:FontWeight.w600))))),
    ]))),
   ]);
  }),
 );
}
/// White Waffra leaf emblem drawn directly on the emerald splash.
/// No raster app-icon background, border or square can appear.
class _WaffraSplashLogoPainter extends CustomPainter {
 @override void paint(Canvas canvas,Size size){
  final paint=Paint()..color=Colors.white..style=PaintingStyle.fill;
  final w=size.width,h=size.height;
  Path leaf(List<Offset> points){
   final p=Path()..moveTo(points[0].dx*w,points[0].dy*h);
   p.cubicTo(points[1].dx*w,points[1].dy*h,points[2].dx*w,points[2].dy*h,points[3].dx*w,points[3].dy*h);
   p.cubicTo(points[4].dx*w,points[4].dy*h,points[5].dx*w,points[5].dy*h,points[0].dx*w,points[0].dy*h);
   return p..close();
  }
  canvas.drawPath(leaf([const Offset(.50,.05),const Offset(.18,.30),const Offset(.28,.47),const Offset(.50,.54),const Offset(.72,.46),const Offset(.83,.30)]),paint);
  canvas.drawPath(leaf([const Offset(.41,.94),const Offset(.18,.76),const Offset(.04,.55),const Offset(.15,.39),const Offset(.29,.51),const Offset(.41,.58)]),paint);
  canvas.drawPath(leaf([const Offset(.59,.94),const Offset(.82,.76),const Offset(.96,.55),const Offset(.85,.39),const Offset(.71,.51),const Offset(.59,.58)]),paint);
 }
 @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
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
  'إدارة أموالك\nبكل سهولة',
  'سجّل معاملاتك\nبسهولة',
  'افهم نمط\nإنفاقك',
  'حقق أهدافك\nالمالية',
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
    precacheImage(AssetImage('assets/waffra_onboarding_clean_0'+i.toString()+'.png'),context);
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
  final label=index==3?(waffraIsEnglish?'Start now':'ابدأ الآن'):
   (waffraIsEnglish?'Next':'التالي');
  final topSafe=MediaQuery.paddingOf(context).top;
  final bottomSafe=MediaQuery.paddingOf(context).bottom;
  return Stack(fit:StackFit.expand,children:[
   // Full-bleed artwork on all four pages: no inset image, frame or side margins.
   // cover preserves the artwork's aspect ratio and only trims the outer edges.
   Positioned.fill(child:Image.asset(
    'assets/waffra_onboarding_clean_0${index+1}.png',
    fit:BoxFit.cover,alignment:Alignment.center,
    filterQuality:FilterQuality.high,
    errorBuilder:(ctx,error,stack)=>const ColoredBox(color:forest))),
   // Soft scrims keep the Flutter controls legible without enclosing the image.
   Positioned(top:0,left:0,right:0,height:topSafe+92,
    child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(
     gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[forest.withValues(alpha:.82),forest.withValues(alpha:0)]))))),
   Positioned(bottom:0,left:0,right:0,height:bottomSafe+170,
    child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(
     gradient:LinearGradient(begin:Alignment.bottomCenter,end:Alignment.topCenter,
      colors:[forest.withValues(alpha:.96),forest.withValues(alpha:0)]))))),
   Positioned(top:topSafe+8,left:16,right:16,child:Row(children:[
    TextButton(onPressed:finish,style:TextButton.styleFrom(foregroundColor:Colors.white),
     child:WaffraText(waffraIsEnglish?'Skip':'تخطي',
      style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
    const Spacer(),
    Directionality(textDirection:TextDirection.ltr,
     child:WaffraText('${index+1} / 4',
      style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.bold))),
   ])),
   Positioned(left:18,right:18,bottom:bottomSafe+16,child:Column(
    mainAxisSize:MainAxisSize.min,children:[
     Row(mainAxisAlignment:MainAxisAlignment.center,
      children:List.generate(4,(i)=>AnimatedContainer(
       duration:const Duration(milliseconds:190),width:i==current?23:8,height:8,
       margin:const EdgeInsets.symmetric(horizontal:4),
       decoration:BoxDecoration(borderRadius:BorderRadius.circular(9),
        color:i==current?Colors.white:const Color(0xFF75AF95))))),
     const SizedBox(height:15),
     Row(children:[
      if(index>0)...[
       OutlinedButton.icon(onPressed:()=>controller.previousPage(
        duration:const Duration(milliseconds:260),curve:Curves.easeInOutCubic),
        style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
         side:const BorderSide(color:Colors.white70),
         padding:const EdgeInsets.symmetric(horizontal:13,vertical:13)),
        icon:const Icon(Icons.arrow_back_rounded,size:18),
        label:WaffraText(waffraIsEnglish?'Back':'السابق')),
       const SizedBox(width:10),
      ],
      Expanded(child:SizedBox(height:51,child:FilledButton.icon(
       onPressed:next,
       style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
       icon:const Icon(Icons.arrow_forward_rounded),
       label:WaffraText(label,style:const TextStyle(
        color:forest,fontSize:17,fontWeight:FontWeight.bold))))),
     ]),
    ])),
  ]);
 });
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:forest,
  body:PageView.builder(
   controller:controller,allowImplicitScrolling:true,
   itemCount:4,
   onPageChanged:(nextIndex)=>setState(()=>current=nextIndex),
   itemBuilder:(context,index)=>slide(index),
  ),
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
     'assets/waffra_splash_approved_exact.png',fit:BoxFit.cover))),
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
 bool signInMode=false,showSignInPassword=false,signingIn=false,signInAttempted=false;
 String? signInAuthError;
 bool returnAfterLogout=false;String lastMethod='Local',lastEmail='',lastPhone='';
 final signInPhone=TextEditingController(),signInPassword=TextEditingController();
 @override void initState(){super.initState();_loadRegistered();}
 Future<void> _loadRegistered()async{
  final prefs=await SharedPreferences.getInstance();
  final signedOut=prefs.getBool('waffra_signed_out_explicitly')??false;
  if(mounted)setState((){
   returnAfterLogout=signedOut;
   lastMethod=prefs.getString('waffra_last_login_method')??'Local';
   lastEmail=prefs.getString('waffra_last_login_email')??'';
   lastPhone=prefs.getString('waffra_last_login_phone')??'';
  });
  final raw=prefs.getString('waffra_registered_profile');
  if(raw==null)return;
  try{final u=Person.fromJson(Map<String,dynamic>.from(jsonDecode(raw)));if(mounted)setState((){registered=u;signInMode=!signedOut;signInPhone.text=u.phone;});}catch(_){ }
 }
 @override void dispose(){signInPhone.dispose();signInPassword.dispose();super.dispose();}
 Future<void> _signIn()async{
  if(signingIn)return;
  setState(()=>signInAttempted=true);
  if(waffraMobileFieldError(signInPhone.text)!=null||signInPassword.text.isEmpty)return;
  setState(()=>signingIn=true);
  try{
   final p=await SharedPreferences.getInstance();
   final salt=p.getString('waffra_local_password_salt');
   final expected=p.getString('waffra_local_password_hash');
   final account=registered;
   if(account==null||salt==null||expected==null||signInPhone.text.trim()!=account.phone||
     sha256.convert(utf8.encode('$salt:${signInPassword.text}')).toString()!=expected){
    if(mounted)setState(()=>signInAuthError=waffraIsEnglish?'Incorrect phone number or password':'رقم الجوال أو كلمة المرور غير صحيحة');return;
   }
   await widget.onSave(account);
  }finally{if(mounted)setState(()=>signingIn=false);}
 }

 String get maskedLastPhone{
  if(lastPhone.length<6)return lastPhone;
  return '${lastPhone.substring(0,2)}••••${lastPhone.substring(lastPhone.length-4)}';
 }
 Future<void> continueLastLogin()async{
  if(lastMethod=='Google'){
   if(socialBusy)return;
   setState(()=>socialBusy=true);
   try{
    final result=await WaffraGoogleAuth.signIn();
    final user=result.user;
    if(user==null)throw StateError('Google sign-in cancelled');
    if(lastEmail.isNotEmpty&&user.email?.toLowerCase()!=lastEmail.toLowerCase()){
     if(mounted)snack(context,waffraIsEnglish?'Choose your previous Google account':'اختار حساب جوجل المستخدم سابقًا');
     return;
    }
    await widget.onSave(Person(name:user.displayName??'',email:user.email??'',
     phone:user.phoneNumber??'',provider:'Google',gender:'',avatar:user.photoURL??'person',birthday:DateTime(2000)));
   }catch(e){
    if(mounted)snack(context,waffraIsEnglish?'Google sign-in failed. Please try again.':'تعذر تسجيل الدخول بجوجل. حاول مرة أخرى.');
   }finally{if(mounted)setState(()=>socialBusy=false);}
  }else if(lastMethod=='Phone'){
   if(registered!=null){setState(()=>signInMode=true);}
   else{setState(()=>provider='Phone');}
  }else if(lastMethod=='Apple'){
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Apple sign-in':'تسجيل الدخول باستخدام Apple'),
    content:WaffraText(waffraIsEnglish?'Apple sign-in is not configured yet.':'تسجيل الدخول باستخدام Apple غير مفعّل حاليًا.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
  }else{
   if(registered!=null)setState(()=>signInMode=true);
   else setState(()=>returnAfterLogout=false);
  }
 }
 Widget recentLoginCard(){
  final google=lastMethod=='Google',apple=lastMethod=='Apple',phone=lastMethod=='Phone';
  final method=google?'Google':apple?'Apple':phone?(waffraIsEnglish?'Phone number':'رقم الجوال'):(waffraIsEnglish?'Local account':'حساب محلي');
  final detail=google||apple?lastEmail:phone?maskedLastPhone:'';
  return Container(
   padding:const EdgeInsets.all(15),
   decoration:BoxDecoration(color:const Color(0xFFE8F5EE),borderRadius:BorderRadius.circular(23)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    WaffraText(waffraIsEnglish?'Last signed in using':'آخر تسجيل دخول كان عبر',
     textAlign:TextAlign.center,style:const TextStyle(color:forest,fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    Container(padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
     child:Row(children:[
      if(google)SvgPicture.string(_waffraGoogleLogo,width:29,height:29)
      else Icon(apple?Icons.apple:phone?Icons.phone_android:Icons.person_outline,color:forest,size:29),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(method,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:forest)),
       if(detail.isNotEmpty)Text(detail,maxLines:1,overflow:TextOverflow.ellipsis,
        textDirection:TextDirection.ltr,style:const TextStyle(fontSize:12,color:Colors.black54)),
      ])),
      const Icon(Icons.chevron_left,color:forest),
     ])),
    const SizedBox(height:12),
    FilledButton(onPressed:socialBusy?null:continueLastLogin,
     style:FilledButton.styleFrom(backgroundColor:forest,foregroundColor:Colors.white),
     child:WaffraText(waffraIsEnglish?'Continue with $method':'المتابعة باستخدام $method')),
   ]));
 }
 bool socialBusy=false;
 Widget _socialBorder(BuildContext sheet,String id,Widget icon,{required String label})=>Material(
  color:const Color(0xFFFEFDF8),borderRadius:BorderRadius.circular(18),child:InkWell(
  borderRadius:BorderRadius.circular(18),onTap:()=>Navigator.pop(sheet,id),
  child:Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:19,vertical:19),
   decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),
    border:Border.all(color:forest,width:1.5)),
   child:Row(children:[icon,const SizedBox(width:16),Expanded(child:WaffraText(label,
    style:const TextStyle(color:Color(0xFF10191A),fontSize:17,fontWeight:FontWeight.bold))),
    const SizedBox(width:8),const Icon(Icons.chevron_left_rounded,color:forest,size:29)]))));
 Future<void> chooseRegistration()async {
  final choice=await showModalBottomSheet<String>(context:context,showDragHandle:true,
   backgroundColor:const Color(0xFFFEFDF8),
   shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(30))),
   builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,14,20,28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    WaffraText(waffraIsEnglish?'Create account':'إنشاء حساب',style:const TextStyle(fontSize:29,fontWeight:FontWeight.bold,color:Color(0xFF10191A))),
    const SizedBox(height:15),
    _socialBorder(ctx,'Google',SvgPicture.string(_waffraGoogleLogo,width:32,height:32),label:waffraIsEnglish?'Continue with Google':'المتابعة باستخدام Google'),
    const SizedBox(height:12),
    _socialBorder(ctx,'Apple',const Icon(Icons.apple,size:34,color:Color(0xFF111111)),label:waffraIsEnglish?'Continue with Apple':'المتابعة باستخدام Apple'),
    const SizedBox(height:12),
    _socialBorder(ctx,'Phone',const Icon(Icons.phone_android,color:forest),label:waffraIsEnglish?'Register with phone number':'التسجيل برقم الجوال'),
    const SizedBox(height:8),
   ]))));
  if(!mounted||choice==null)return;
  if(choice=='Phone'){setState(()=>provider='Phone');return;}
  if(choice=='Google'){
   if(socialBusy)return;
   setState(()=>socialBusy=true);
   try{
    final result=await WaffraGoogleAuth.signIn();
    final user=result.user;
    if(user==null)throw StateError('Google did not return an account');
    await widget.onSave(Person(name:user.displayName??'',email:user.email??'',
     phone:user.phoneNumber??'',provider:'Google',gender:'',avatar:user.photoURL??'person',birthday:DateTime(2000)));
     if(!mounted)return;
     await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ProfileForm(provider:'Google',initial:Person(name:user.displayName??'',email:user.email??'',phone:user.phoneNumber??'',provider:'Google',gender:'',avatar:user.photoURL??'person',birthday:DateTime(2000)),onSave:widget.onSave)));
   }catch(e){
    if(mounted){
      final message=e.toString().toLowerCase();
      final offline=e is SocketException||message.contains('network-request-failed')||message.contains('network_error')||message.contains('network error')||message.contains('unable to resolve host')||message.contains('failed host lookup')||message.contains('no internet')||message.contains('connection refused')||message.contains('socketexception');
      final cancelled=message.contains('canceled')||message.contains('cancelled');
      snack(context,offline?(waffraIsEnglish?'No internet connection. Check your connection and try again.':'تعذر الاتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.'):
       cancelled?(waffraIsEnglish?'Google sign-in was cancelled.':'تم إلغاء تسجيل الدخول بجوجل.'):
       (waffraIsEnglish?'Could not sign in with Google. Please try again.':'تعذر تسجيل الدخول بجوجل. حاول مرة أخرى.'));
     }
    debugPrint('Waffra Google sign-in: $e');
   }finally{if(mounted)setState(()=>socialBusy=false);}
   return;
  }
  await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Sign-in not configured':'تسجيل الدخول غير مفعّل'),
   content:WaffraText(waffraIsEnglish?'Secure $choice sign-in needs authentication setup. No account was created.':'تسجيل الدخول الآمن باستخدام $choice يحتاج إعداد خدمة المصادقة. لم يتم إنشاء حساب.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
 }
 Future<void> demoSocial(String selected)async {
  if(socialBusy)return;
  setState(()=>socialBusy=true);
  try {
   await widget.onSave(Person(name:'',email:'',phone:'',provider:'Local $selected demo',gender:'',avatar:'person',birthday:DateTime(2000)));
   if(!mounted)return;
   snackSuccess(context,waffraIsEnglish?'Local demo profile opened — not authenticated with $selected':'تم الدخول للملف المحلي التجريبي بنجاح — لم تتم المصادقة مع $selected');
  }finally{if(mounted)setState(()=>socialBusy=false);}
 }

 @override Widget build(BuildContext context){
  if(provider!=null)return ProfileForm(provider:provider!,onSave:widget.onSave,
   onBack:()=>setState(()=>provider=null));
  final hasExisting=registered!=null;
  return Scaffold(backgroundColor:forest,resizeToAvoidBottomInset:false,
   body:Stack(fit:StackFit.expand,children:[
    Image.asset('assets/waffra_login_approved_exact.png',fit:BoxFit.cover,
     filterQuality:FilterQuality.high),
    Align(alignment:Alignment.bottomCenter,child:SafeArea(
     top:false,child:SingleChildScrollView(
      padding:EdgeInsets.fromLTRB(18,14,18,MediaQuery.of(context).viewInsets.bottom+18),
      child:Container(
       padding:const EdgeInsets.all(17),
       decoration:BoxDecoration(color:forest.withValues(alpha:.96),
        border:Border.all(color:Colors.white.withValues(alpha:.30)),
        borderRadius:BorderRadius.circular(24)),
       child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(returnAfterLogout&&!signInMode)...[
         WaffraText(waffraIsEnglish?'Welcome back':'مرحبًا بك مجددًا',
          textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),
         const SizedBox(height:5),
         WaffraText(waffraIsEnglish?'Sign in to continue':'سجل دخولك للمتابعة',
          textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:14)),
         const SizedBox(height:15),
         recentLoginCard(),
         const SizedBox(height:12),
         TextButton(onPressed:()=>setState(()=>returnAfterLogout=false),
          child:WaffraText(waffraIsEnglish?'Other sign-in options':'خيارات تسجيل دخول أخرى',
           style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        ]else if(signInMode&&hasExisting)...[
         WaffraText(waffraIsEnglish?'Sign in to Waffra':'تسجيل الدخول إلى وفرة',
          textAlign:TextAlign.center,
          style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.white)),
         const SizedBox(height:12),
         WaffraText(waffraIsEnglish?'Phone number':'رقم الجوال',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:6),
         TextField(controller:signInPhone,keyboardType:TextInputType.phone,
          onChanged:(_)=>setState(()=>signInAuthError=null),
          style:const TextStyle(color:forest),textDirection:TextDirection.ltr,
          decoration:InputDecoration(hintText:waffraIsEnglish?'Phone number':'05xxxxxxxx',hintStyle:const TextStyle(color:Colors.black38),
           filled:true,fillColor:Colors.white,
           errorText:signInAttempted?waffraMobileFieldError(signInPhone.text):null,errorMaxLines:2,
           border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
         const SizedBox(height:10),
         WaffraText(waffraIsEnglish?'Password':'كلمة المرور',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:6),
         TextField(controller:signInPassword,obscureText:!showSignInPassword,
          onChanged:(_)=>setState(()=>signInAuthError=null),
          onSubmitted:(_)=>_signIn(),style:const TextStyle(color:forest),
          decoration:InputDecoration(hintText:waffraIsEnglish?'Enter password':'أدخل كلمة المرور',hintStyle:const TextStyle(color:Colors.black38),
           filled:true,fillColor:Colors.white,
           errorText:signInAttempted?(signInPassword.text.isEmpty?waffraRequiredFieldMessage:signInAuthError):null,errorMaxLines:2,
           border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)),
           suffixIcon:IconButton(onPressed:()=>setState(()=>showSignInPassword=!showSignInPassword),
            icon:Icon(showSignInPassword?Icons.visibility_off:Icons.visibility)))),
         const SizedBox(height:13),
         FilledButton(onPressed:signingIn?null:_signIn,
          style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
          child:WaffraText(signingIn?
           (waffraIsEnglish?'Signing in...':'جارٍ تسجيل الدخول'):
           (waffraIsEnglish?'Sign in':'تسجيل الدخول'))),
         TextButton(onPressed:()=>setState(()=>signInMode=false),
          child:WaffraText(waffraIsEnglish?'Other options':'خيارات أخرى',
           style:const TextStyle(color:Colors.white))),
        ]else...[
         WaffraText(waffraIsEnglish?'Welcome to Waffra':'مرحباً بك في وفرة',
          style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.bold),
          textAlign:TextAlign.center),
         const SizedBox(height:12),
         FilledButton.icon(onPressed:signingIn?null:()async{
          if(signingIn)return;
          setState(()=>signingIn=true);
          try{
           await widget.onSave(Person(name:'',email:'',phone:'',provider:'محلي',
            gender:'',avatar:'person',birthday:DateTime(2000)));
          }finally{if(mounted)setState(()=>signingIn=false);}
         },style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
          icon:const Icon(Icons.arrow_forward),
          label:WaffraText(waffraIsEnglish?'Start now — no sign in':'ابدأ الآن بدون تسجيل دخول')),
         const SizedBox(height:8),
         OutlinedButton.icon(onPressed:chooseRegistration,
          style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
           side:const BorderSide(color:Colors.white70)),
          icon:const Icon(Icons.person_add_alt_1_outlined),
          label:WaffraText(waffraIsEnglish?'Create account':'إنشاء حساب')),
         if(hasExisting)TextButton(onPressed:()=>setState(()=>signInMode=true),
          child:WaffraText(waffraIsEnglish?'Already have an account? Sign in':
           'عندك حساب بالفعل؟ تسجيل الدخول',
           style:const TextStyle(color:Colors.white))),
        ],
       ])),
      ),
     )),
   ]));
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
  final png=await showWaffraDialog<Uint8List>(context:context,builder:(ctx)=>AlertDialog(
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
  if(waffraTextFieldError(name.text)!=null||waffraMobileFieldError(phone.text)!=null)return;
  if(widget.initial==null&&(
   waffraPasswordFieldError(password.text)!=null||
   waffraConfirmPasswordFieldError(confirmPassword.text,password.text)!=null))return;
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
   if(widget.initial!=null&&Navigator.of(context).canPop())Navigator.pop(context);
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
   if(widget.provider=='Google'&&(widget.initial?.gender.isEmpty??true))Card(color:emerald.withValues(alpha:.08),child:Padding(padding:const EdgeInsets.all(14),child:WaffraText(waffraIsEnglish?'Complete your profile: mobile number and gender are required.':'تبقّى بعض البيانات لاستكمال ملفك الشخصي: رقم الجوال والجنس حقول إجبارية.'))),
    Wrap(alignment:WrapAlignment.center,spacing:12,children:['ذكر','أنثى']
    .map((a)=>ChoiceChip(label:Row(mainAxisSize:MainAxisSize.min,children:[saudiAvatar(a,radius:20),const SizedBox(width:6),WaffraText(waffraIsEnglish?(a=='ذكر'?'Male':'Female'):a)]),selected:gender==a,onSelected:(_)=>setState((){gender=a;if(!avatar.startsWith('https://'))avatar=a=='ذكر'?'male':'female';}))).toList()),
   const SizedBox(height:16),
   TextField(controller:name,onChanged:(_)=>setState((){}),decoration:InputDecoration(
     labelText:waffraIsEnglish?'Name *':'اسمك *',
     errorText:profileAttempted?waffraTextFieldError(name.text):null,
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
    decoration:InputDecoration(labelText:waffraIsEnglish?'Mobile number starting with 05 *':'رقم الجوال يبدأ بـ 05 *',
     hintText:'05XXXXXXXX',
     errorText:profileAttempted?waffraMobileFieldError(phone.text):null,
     border:const OutlineInputBorder())),
   if(widget.initial==null) ...[
    const SizedBox(height:12),
    TextField(controller:password,obscureText:!showPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showPassword?'Hide password':'Show password'):(showPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showPassword=!showPassword)),labelText:waffraIsEnglish?'Password *':'كلمة المرور *',
     errorText:profileAttempted?waffraPasswordFieldError(password.text):null,errorMaxLines:3,
     errorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red)),
     focusedErrorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red,width:2)),
     helperText:waffraIsEnglish?'At least 8 characters, including letters and numbers':'8 خانات على الأقل، تشمل أحرفًا وأرقامًا',
     enabledBorder:passwordBorder(),focusedBorder:passwordBorder(focused:true))),
    const SizedBox(height:12),
    TextField(controller:confirmPassword,obscureText:!showConfirmPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showConfirmPassword?'Hide password':'Show password'):(showConfirmPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showConfirmPassword?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showConfirmPassword=!showConfirmPassword)),labelText:waffraIsEnglish?'Confirm password *':'تأكيد كلمة المرور *',
     errorText:profileAttempted?waffraConfirmPasswordFieldError(confirmPassword.text,password.text):null,errorMaxLines:3,
     errorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red)),
     focusedErrorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red,width:2)),
     enabledBorder:passwordBorder(),focusedBorder:passwordBorder(focused:true))),
    if(comparingPasswords&&matchingPasswords)Padding(padding:const EdgeInsets.only(top:8),
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
    decoration:InputDecoration(labelText:waffraIsEnglish?'Gender':'الجنس',
      errorText:profileAttempted&&gender.isEmpty?waffraRequiredFieldMessage:null,
      border:const OutlineInputBorder()),
    items:['ذكر','أنثى'].map((x)=>DropdownMenuItem(value:x,child:WaffraText(waffraIsEnglish?(x=='ذكر'?'Male':'Female'):x))).toList(),
    onChanged:(v){if(v!=null)setState((){gender=v;if(!avatar.startsWith('https://'))avatar=v=='أنثى'?'female':'male';});}),
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
// All transient notices use the same footer-anchored surface throughout the app.
// Required-field validation remains inline using InputDecoration.errorText.
void snack(BuildContext context,String text,{
 bool isError=true,
 String? actionLabel,
 VoidCallback? onAction,
 Duration duration=const Duration(seconds:5),
}){
 if(!context.mounted)return;
 final messenger=ScaffoldMessenger.of(context);
 messenger.hideCurrentMaterialBanner();
 messenger.hideCurrentSnackBar();
 final dark=Theme.of(context).brightness==Brightness.dark;
 final background=isError
  ?(dark?const Color(0xFF4A2429):const Color(0xFFFFE1E2))
  :(dark?const Color(0xFF163F31):const Color(0xFFE6F5EB));
 final foreground=isError
  ?(dark?const Color(0xFFFFDEE0):const Color(0xFF9D1D25))
  :(dark?const Color(0xFFB5F2D4):const Color(0xFF07563B));
 final outline=isError?const Color(0xFFE67B81):const Color(0xFF0C7957);
 messenger.showSnackBar(SnackBar(
  behavior:SnackBarBehavior.floating,
  margin:const EdgeInsets.fromLTRB(82,0,12,16),
  duration:duration,
  backgroundColor:background,
  elevation:5,
  padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
  shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(18),
   side:BorderSide(color:outline,width:1.2)),
  content:Row(children:[
   Icon(isError?Icons.error_rounded:Icons.check_circle_rounded,color:foreground,size:25),
   const SizedBox(width:9),
   Expanded(child:WaffraText(text,maxLines:4,
    style:TextStyle(color:foreground,fontSize:14,fontWeight:FontWeight.w700))),
   if(onAction!=null)TextButton(
    onPressed:(){messenger.hideCurrentSnackBar();onAction();},
    child:WaffraText(actionLabel??(waffraIsEnglish?'Undo':'تراجع'),
     style:TextStyle(color:foreground,fontWeight:FontWeight.bold))),
   IconButton(
    tooltip:waffraIsEnglish?'Close':'إغلاق',
    icon:Icon(Icons.close_rounded,color:foreground,size:22),
    visualDensity:VisualDensity.compact,
    padding:EdgeInsets.zero,
    constraints:const BoxConstraints(minWidth:32,minHeight:32),
    onPressed:()=>messenger.hideCurrentSnackBar()),
  ]),
 ));
}
void snackSuccess(BuildContext context,String text)=>snack(context,text,isError:false);

/* Waffra concept-2 section header. A shared visual component only:
   each existing page retains its interactions, state, and data. */
class WaffraPageHero extends StatelessWidget {
 final String title,subtitle;
 final IconData icon;
 final Key? titleKey;
 const WaffraPageHero({super.key,required this.title,required this.subtitle,
  required this.icon,this.titleKey});
 @override Widget build(BuildContext context)=>Padding(
  padding:const EdgeInsets.fromLTRB(0,0,0,7),
  child:ClipRRect(borderRadius:BorderRadius.circular(23),
   child:Container(
    decoration:const BoxDecoration(gradient:LinearGradient(
     begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,
     colors:[Color(0xFF073F31),Color(0xFF0C6B4C)])),
    child:Stack(children:[
     PositionedDirectional(top:-49,end:-37,child:Container(
      width:140,height:140,decoration:BoxDecoration(
       shape:BoxShape.circle,color:Colors.white.withValues(alpha:.065)))),
     PositionedDirectional(bottom:-78,start:-51,child:Container(
      width:163,height:163,decoration:BoxDecoration(
       shape:BoxShape.circle,
       border:Border.all(color:Colors.white.withValues(alpha:.085),width:25)))),
     Padding(padding:const EdgeInsets.fromLTRB(18,18,18,19),
      child:Row(children:[
       Container(width:43,height:43,
        decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),
         borderRadius:BorderRadius.circular(14)),
        child:Icon(icon,color:Colors.white,size:24)),
       const SizedBox(width:13),
       Expanded(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,
        children:[
         WaffraText(title,key:titleKey,maxLines:2,
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:19)),
         const SizedBox(height:4),
         WaffraText(subtitle,maxLines:3,
          style:const TextStyle(color:Color(0xFFDAF1E6),fontSize:12,height:1.35)),
        ])),
      ])),
    ]),
   )),
 );
}
/// Preserves full bank-SMS text while presenting Arabic transaction
/// details in an explicitly right-to-left, consistently aligned dialog.
class WaffraTransactionDetailsDialog extends StatelessWidget {
 final MoneyEntry entry;
 final VoidCallback onClose;
 final VoidCallback? onViewReceipt;
 const WaffraTransactionDetailsDialog({
  super.key,required this.entry,required this.onClose,this.onViewReceipt,
 });
 @override Widget build(BuildContext context){
  final rtl=!waffraIsEnglish;
  final dark=Theme.of(context).brightness==Brightness.dark;
  final accent=entry.income?const Color(0xFF087A54):const Color(0xFFB94838);
  final lightTone=entry.income?const Color(0xFFE4F4EB):const Color(0xFFFCECE8);
  final darkTone=entry.income?const Color(0xFF244C3A):const Color(0xFF49302C);
  final muted=Theme.of(context).colorScheme.onSurface.withValues(alpha:.73);
  return Directionality(
   textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
   child:AlertDialog(
    title:Row(children:[
     Icon(Icons.receipt_long_outlined,color:dark?const Color(0xFF74D8A9):emerald),
     const SizedBox(width:9),
     Expanded(child:WaffraText(waffraIsEnglish?'Transaction details':'تفاصيل المعاملة',
      textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
      textAlign:TextAlign.start,
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20))),
    ]),
    content:ConstrainedBox(
     constraints:const BoxConstraints(maxWidth:440),
     child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
       WaffraText(waffraIsEnglish?'Transaction description':'وصف المعاملة',
        textAlign:TextAlign.start,style:TextStyle(fontSize:12,color:muted)),
       const SizedBox(height:7),
       Container(
        width:double.infinity,
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
        decoration:BoxDecoration(
         color:dark?const Color(0xFF252A27):const Color(0xFFF1F8F3),
         borderRadius:BorderRadius.circular(14),
         border:Border.all(color:dark?const Color(0xFF3B5444):const Color(0xFFD5E8DC))),
        child:WaffraText(entry.title,
         textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
         textAlign:TextAlign.start,
         softWrap:true,
         style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,height:1.5)),
       ),
       const SizedBox(height:15),
       Row(children:[
        Icon(Icons.category_outlined,color:dark?const Color(0xFF74D8A9):emerald,size:20),
        const SizedBox(width:8),
        Expanded(child:WaffraText(waffraTr(entry.category),
         textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
         textAlign:TextAlign.start,
         style:const TextStyle(fontWeight:FontWeight.bold))),
       ]),
       const SizedBox(height:13),
       Row(children:[
        Icon(Icons.calendar_today_outlined,color:dark?const Color(0xFF74D8A9):emerald,size:19),
        const SizedBox(width:8),
        Expanded(child:WaffraText(dayText(entry.date),
         textAlign:TextAlign.start,
         textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
         style:TextStyle(color:muted,fontSize:13))),
       ]),
       const SizedBox(height:15),
       Container(
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
        decoration:BoxDecoration(color:dark?darkTone:lightTone,
         borderRadius:BorderRadius.circular(15)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         WaffraText(entry.income?
          (waffraIsEnglish?'Income':'الدخل'):
          (waffraIsEnglish?'Expense':'المصروف'),
          style:TextStyle(fontSize:12,fontWeight:FontWeight.bold,
           color:dark?Colors.white:accent)),
         const SizedBox(height:5),
         Align(alignment:AlignmentDirectional.centerStart,
          child:WaffraCurrencyAmount(
           entry.income?entry.amount:-entry.amount,
           fontSize:22,color:dark?Colors.white:accent)),
        ]),
       ),
       if(onViewReceipt!=null)...[
        const SizedBox(height:10),
        Align(alignment:AlignmentDirectional.centerStart,
         child:TextButton.icon(
          onPressed:onViewReceipt,
          icon:const Icon(Icons.photo_library_outlined),
          label:WaffraText(waffraIsEnglish?'View attachments':'عرض المرفقات'))),
       ],
      ],
     )),
    ),
    actions:[TextButton(onPressed:onClose,
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   ),
  );
 }
}
class HomeScreen extends StatefulWidget {
 final Person profile;final bool dark,pinEnabled;final String appearance;
 final Future<void> Function(String) onAppearance;
 final Future<void> Function(String?) onSetPin;
 final VoidCallback onTheme;
 final Future<void> Function(String) onLanguage;
 final Future<void> Function() onLogout;
 final Future<void> Function(Person) onProfile;
 const HomeScreen({super.key,required this.profile,required this.dark,required this.pinEnabled,
  required this.onSetPin,required this.onTheme,required this.onLanguage,required this.onLogout,required this.onProfile,
   required this.appearance,required this.onAppearance});
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
 @override double get maxExtent=>86;
 @override Widget build(BuildContext context,double shrinkOffset,bool overlapsContent){
  final progress=(shrinkOffset/(maxExtent-minExtent)).clamp(0.0,1.0);
  final dark=Theme.of(context).brightness==Brightness.dark;
  final mainColor=dark?Colors.white:forest;
  return Container(
   key:focusKey,
   color:Theme.of(context).scaffoldBackgroundColor,
   padding:const EdgeInsets.fromLTRB(14,0,14,5),
   child:Container(
    padding:EdgeInsets.symmetric(horizontal:15,vertical:5-2*progress),
    decoration:BoxDecoration(
     color:Theme.of(context).cardColor,
     border:Border.all(color:dark?const Color(0xFF303C34):const Color(0xFFDCEBE2)),
     boxShadow:dark?null:[BoxShadow(color:forest.withValues(alpha:.045),
      blurRadius:12,offset:const Offset(0,3))],
     borderRadius:BorderRadius.circular(19-3*progress)),
    child:Row(children:[
     Expanded(child:Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
       WaffraText(english?'Current balance':'رصيدك الحالي',
        style:TextStyle(fontSize:12-1*progress,color:dark?Colors.white70:forest,
         fontWeight:FontWeight.w600)),
       const SizedBox(height:1),
       FittedBox(fit:BoxFit.scaleDown,alignment:AlignmentDirectional.centerStart,
        child:WaffraCurrencyAmount(balance,fontSize:23-3*progress,color:mainColor)),
      ])),
     ValueListenableBuilder<bool>(valueListenable:hideWaffraAmounts,
      builder:(ctx,hidden,_)=>IconButton(
       tooltip:hidden?(english?'Show amounts':'إظهار المبالغ'):
        (english?'Hide amounts':'إخفاء المبالغ'),
       onPressed:()async{
        final conceal=!hidden;
        hideWaffraAmounts.value=conceal;
        final p=await SharedPreferences.getInstance();
        await p.setBool('waffra_hide_amounts',conceal);
        await refreshWaffraHomeWidget(
         balance:conceal?'***':formatWaffraMoney(balance),
         negative:balance<0,hidden:conceal,
         currency:english?'SAR':'ريال');
       },
       visualDensity:VisualDensity.compact,
       icon:Icon(hidden?Icons.visibility_off_outlined:Icons.visibility_outlined,
        color:mainColor,size:22))),
    ]),
   ),
  );
 }
 @override bool shouldRebuild(covariant WaffraBalanceHeader oldDelegate)=>true;
}
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
 final smsHashes=<String>{};
 final expandedCategoryIds=<String>{};
 final learnedMerchantCategories=<String,String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 final challenges=<SavingChallenge>[];
 // Soft-deleted categories are retained on-device for up to 30 days.
 final deletedCategories=<Map<String,dynamic>>[];
 final deletedGoals=<Map<String,dynamic>>[];
 final deletedRecurring=<Map<String,dynamic>>[];
 final recurringPostponed=<String,String>{};
 bool _dueDialogShowing=false;
 double monthlyBudget=0;
 bool monthlyBudgetEnabled=false;
 DateTimeRange? transactionsDateRange;
 double? minTransactionAmount,maxTransactionAmount;
 int tab=0,year=DateTime.now().year,month=DateTime.now().month;
 bool goalsOpened=false;
 bool _smsSheetOpen=false;
 String? _lastWidgetRevision;
 AppLifecycleListener? _widgetReloadListener;
 double _swipeTravel=0;
 bool _headerCompact=false;
 final ScrollController _dashboardScrollController=ScrollController();
 void _handleDashboardScroll(){
  if(!mounted||tab!=0||goalsOpened||!_dashboardScrollController.hasClients)return;
  final compact=_dashboardScrollController.offset>96;
  if(compact==_headerCompact)return;
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(mounted&&tab==0&&compact!=_headerCompact)setState(()=>_headerCompact=compact);
  });
 }
 late final AnimationController _tourGlow;
 Future<void> setAnimationLevel(String next)async {
  if(!{'full','balanced','reduced','off'}.contains(next))return;
  waffraAnimationLevel.value=next;
  _tourGlow.duration=waffraMotion(1150);
  if(tourActive){_tourGlow.stop();if(next!='off')_tourGlow.repeat(reverse:true);}
  if(mounted)setState((){});
  final p=await SharedPreferences.getInstance();
  await p.setString('waffra_animation_level',next);
 }
 String search='',typeFilter='الكل',categoryFilter='الكل',period='شهري';
 String categorySearch='',categoryDisplay='all',categoryTypeFilter='all',goalDisplay='all',recurringDisplay='all';
  String? forecastCategory;
  int forecastReduction=20;
 bool recurringRemindersEnabled=false;
 bool ready=false;
 String? lastBackupGeneratedAt;
 int? lastBackupBytes;
 bool protectRecentApps=true;
 String? _accountOpenSection;
 String accountSearch='';
 final _tourKeys=List<GlobalKey>.generate(7,(_)=>GlobalKey());
 bool tourActive=false;
 bool tourTargetReady=false;
 int tourStep=0;
 static const tourTabs=<int>[0,0,0,1,2,3,0,4];
 static const tourTargetKeys=<int>[-1,0,1,2,6,4,3,5];
 bool addFabExpanded=false;
 bool showAllTransactions=false,showTransactionFilters=false,showTransactionSearch=false;
 @override void initState(){super.initState();_dashboardScrollController.addListener(_handleDashboardScroll);_tourGlow=AnimationController(vsync:this,duration:waffraMotion(1150));waffraReturnHome.addListener(_returnToHome);waffraIncomingSms.addListener(_receiveSharedSms);waffraWidgetAction.addListener(_receiveWidgetAction);_widgetReloadListener=AppLifecycleListener(onResume:()=>unawaited(_syncWidgetTransactions()));load();}
 void _returnToHome(){if(mounted)setState((){tab=0;goalsOpened=false;addFabExpanded=false;});}
 void _receiveWidgetAction(){
  if(!mounted||!ready||waffraWidgetAction.value!='add')return;
  waffraWidgetAction.value=null;
  setState((){tab=0;goalsOpened=false;addFabExpanded=false;});
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(entrySheet());});
 }
 void _receiveSharedSms(){
  if(!mounted||!ready||_smsSheetOpen)return;
  final text=waffraIncomingSms.value;
  if(text==null||text.trim().isEmpty)return;
  waffraIncomingSms.value=null;
  setState((){tab=0;goalsOpened=false;addFabExpanded=false;});
  WidgetsBinding.instance.addPostFrameCallback((_) {
   if(mounted)unawaited(bulkSmsSheet(initialText:text));
  });
 }
 @override void dispose(){_dashboardScrollController.dispose();_tourGlow.dispose();waffraReturnHome.removeListener(_returnToHome);waffraIncomingSms.removeListener(_receiveSharedSms);waffraWidgetAction.removeListener(_receiveWidgetAction);_widgetReloadListener?.dispose();super.dispose();}
 Future<void> _syncWidgetTransactions()async{
  if(!mounted||!ready)return;
  try{
   final p=await SharedPreferences.getInstance();
   await p.reload();
   final revision=p.getString('waffra_widget_last_save_v1');
   if(revision==null||revision==_lastWidgetRevision)return;
   final raw=p.getString('entries');
   if(raw==null)return;
   final loaded=(jsonDecode(raw) as List)
    .map((item)=>MoneyEntry.fromJson(Map<String,dynamic>.from(item as Map))).toList();
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(loaded);
    _lastWidgetRevision=revision;
   });
   unawaited(_refreshWidget());
  }catch(e){debugPrint('Widget ledger sync failed: $e');}
 }
 Future<void> load()async {
  final p=await SharedPreferences.getInstance();
  _lastWidgetRevision=p.getString('waffra_widget_last_save_v1');
  try{final raw=p.getString('entries');if(raw!=null)entries.addAll((jsonDecode(raw) as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('entries: $e');}
  try{final raw=p.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(jsonDecode(raw) as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('categories: $e');categories.addAll(defaultCategories());}
  try{final raw=p.getString('waffra_goals_v24');if(raw!=null)goals.addAll((jsonDecode(raw) as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('goals: $e');}
  try{final raw=p.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((jsonDecode(raw) as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){debugPrint('recurring: $e');}
  try{final raw=p.getString('waffra_challenges_v1');if(raw!=null)challenges.addAll((jsonDecode(raw) as List).map((e)=>SavingChallenge.fromJson(Map<String,dynamic>.from(e))));}catch(e){debugPrint('challenges: $e');}
  try{
   final raw=p.getString('waffra_deleted_categories_v1');
   if(raw!=null)deletedCategories.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));
  }catch(e){debugPrint('Deleted categories: $e');}
  try{final raw=p.getString('waffra_deleted_goals_v1');if(raw!=null)deletedGoals.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){debugPrint('Deleted goals: $e');}
  try{final raw=p.getString('waffra_deleted_recurring_v1');if(raw!=null)deletedRecurring.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){debugPrint('Deleted recurring: $e');}
  try{final raw=p.getString('waffra_recurring_postponed_v1');if(raw!=null)recurringPostponed.addAll((jsonDecode(raw) as Map).map((k,v)=>MapEntry(k.toString(),v.toString())));}catch(e){debugPrint('Postponements: $e');}
  deletedGoals.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
  deletedRecurring.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
  final trashBefore=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  // Install catalog once without overwriting custom categories, saved budgets or trash.
  if(!(p.getBool('waffra_category_catalog_v2_installed')??false)){
   final discarded=<String>{};
   for(final item in deletedCategories){
    final data=item['category'];
    if(data is Map){
     discarded.add('${data['income']==true}|${data['name']}');
     discarded.add('id|${data['id']}');
    }
   }
   for(final suggestion in defaultCategories()){
    if(discarded.contains('${suggestion.income}|${suggestion.name}')||
       discarded.contains('id|${suggestion.id}'))continue;
    if(categories.any((existing)=>existing.id==suggestion.id||
      (existing.income==suggestion.income&&existing.name==suggestion.name)))continue;
    categories.add(suggestion);
   }
   await p.setString('waffra_categories_v24',jsonEncode(categories.map((e)=>e.toJson()).toList()));
   await p.setBool('waffra_category_catalog_v2_installed',true);
  }
  // Incremental catalog update: retain existing user budgets, names and deletions.
  // A subcategory is only added when its main category is present.
  if(!(p.getBool('waffra_category_catalog_v3_installed')??false)){
   final deletedIds=<String>{};
   final deletedNames=<String>{};
   for(final record in deletedCategories){
    final raw=record['category'];
    if(raw is Map){
     deletedIds.add('${raw['id']}');
     deletedNames.add('${raw['income']==true}|${raw['name']}');
    }
   }
   var catalogChanged=false;
   for(final suggestion in defaultCategories()){
    if(deletedIds.contains(suggestion.id)||
     deletedNames.contains('${suggestion.income}|${suggestion.name}'))continue;
    if(categories.any((c)=>c.id==suggestion.id||
     (c.income==suggestion.income&&c.name==suggestion.name)))continue;
    if(suggestion.isSubcategory&&
     !categories.any((c)=>c.id==suggestion.parentId))continue;
    categories.add(suggestion);
    catalogChanged=true;
   }
   if(catalogChanged){
    await p.setString('waffra_categories_v24',
     jsonEncode(categories.map((e)=>e.toJson()).toList()));
   }
   await p.setBool('waffra_category_catalog_v3_installed',true);
  }
  smsHashes.addAll(p.getStringList('waffra_sms_hashes_v1')??const []);
  monthlyBudget=p.getDouble('waffra_monthly_budget_v1')??0;
  monthlyBudgetEnabled=p.getBool('waffra_monthly_budget_enabled_v1')??(monthlyBudget>0);
  recurringRemindersEnabled=p.getBool('waffra_recurring_reminders_enabled_v1')??false;
  lastBackupGeneratedAt=p.getString('waffra_backup_last_exported_v1');
  lastBackupBytes=p.getInt('waffra_backup_last_size_v1');
  protectRecentApps=p.getBool('waffra_protect_recents_v1')??true;
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
  if(!mounted)return;setState(()=>ready=true);_receiveSharedSms();_receiveWidgetAction();unawaited(_refreshWidget());
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(applyRecurring());});
  if(recurringRemindersEnabled)unawaited(syncRecurringReminders());
  if(trashBefore!=deletedCategories.length)await persist();
  if(!(p.getBool('waffra_in_app_tour_seen_v2')??false)&&mounted){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted){setState((){tourActive=true;tourStep=0;tab=0;goalsOpened=false;addFabExpanded=false;tourTargetReady=false;});if(waffraAnimationLevel.value!='off')_tourGlow.repeat(reverse:true);scheduleTourFocus();}
   });
  }
 }
 Future<void> _refreshWidget()async{
  final now=DateTime.now();
  final income=entries.where((e)=>e.income).fold<int>(0,(sum,e)=>sum+WaffraRecurringPolicy.toHalalas(e.amount));
  final expense=entries.where((e)=>!e.income).fold<int>(0,(sum,e)=>sum+WaffraRecurringPolicy.toHalalas(e.amount));
  final thisMonth=entries.where((e)=>!e.income&&e.date.year==now.year&&e.date.month==now.month)
   .fold<int>(0,(sum,e)=>sum+WaffraRecurringPolicy.toHalalas(e.amount));
  await refreshWaffraHomeWidget(
   balance:hideWaffraAmounts.value?'***':formatWaffraMoney((income-expense)/100),
   negative:income-expense<0,
   hidden:hideWaffraAmounts.value,
   currency:waffraIsEnglish?'SAR':'ريال');
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
   p.setString('waffra_deleted_goals_v1',jsonEncode(deletedGoals)),
   p.setString('waffra_deleted_recurring_v1',jsonEncode(deletedRecurring)),
   p.setString('waffra_recurring_postponed_v1',jsonEncode(recurringPostponed)),
   p.setDouble('waffra_monthly_budget_v1',monthlyBudget),
   p.setBool('waffra_monthly_budget_enabled_v1',monthlyBudgetEnabled),
   p.setString('waffra_learned_merchants_v1',jsonEncode(learnedMerchantCategories))
  ]);
  unawaited(_refreshWidget());
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

 // No recurring schedule may post money without a user's explicit confirmation.
 Future<void> applyRecurring()async {
  if(!mounted||!ready||_dueDialogShowing)return;
  final today=DateTime.now();
  for(final r in recurring){
   if(!r.active)continue;
   final due=WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
   final id=WaffraRecurringPolicy.entryId(r.id,due);
   final postponed=DateTime.tryParse(recurringPostponed[id]??'');
   if(!WaffraRecurringPolicy.isOutstanding(
       due:due,today:today,startAt:r.startAt,
       alreadyPaid:entries.any((e)=>e.id==id),postponedUntil:postponed))continue;
   _dueDialogShowing=true;
   try{
    final action=await showWaffraDialog<String>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Recurring payment due':'عملية متكررة مستحقة'),
     content:WaffraText(waffraIsEnglish?
      '${r.title} • ${cash(r.amount)}\\nDue: ${dayText(postponed??due)}\\nWas this paid, or would you like to postpone?':
      '${r.title} • ${cash(r.amount)}\\nالاستحقاق: ${dayText(postponed??due)}\\nهل تم الدفع أم تريد تأجيل الاستحقاق؟'),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,'later'),
       child:WaffraText(waffraIsEnglish?'Not now':'ليس الآن')),
      OutlinedButton(onPressed:()=>Navigator.pop(ctx,'postpone'),
       child:WaffraText(waffraIsEnglish?'Postpone':'تأجيل')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,'paid'),
       child:WaffraText(waffraIsEnglish?'Paid':'تم الدفع')),
     ]));
    if(!mounted)return;
    if(action=='paid'){
     if(!entries.any((e)=>e.id==id)){
      setState(()=>entries.insert(0,MoneyEntry(id:id,title:r.title,category:r.category,amount:r.amount,income:r.income,date:DateTime.now())));
     }
     recurringPostponed.remove(id);await persist();
    }else if(action=='postpone'){
     final selected=await showDatePicker(context:context,initialDate:today.add(const Duration(days:1)),
      firstDate:DateTime(today.year,today.month,today.day).add(const Duration(days:1)),
      lastDate:DateTime(today.year+3,12,31));
     if(selected!=null){recurringPostponed[id]=selected.toIso8601String();await persist();}
    }else{return;}
   }finally{_dueDialogShowing=false;}
  }
 }
 double sum(Iterable<MoneyEntry> list,bool income)=>
  list.where((e)=>e.income==income).fold<int>(0,(v,e)=>v+WaffraRecurringPolicy.toHalalas(e.amount))/100;
 BudgetCategory categoryFor(String name,bool income) {
  for(final c in categories){if(c.name==name&&c.income==income)return c;}
  return BudgetCategory(id:'fallback',name:name,icon:'category',color:colors[7],income:income);
 }
 List<BudgetCategory> forType(bool income)=>categories.where((c)=>c.income==income).toList();
 Future<bool?> confirm(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const WaffraText('تأكيد'))]));
 Future<bool?> confirmDeletion(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(title),content:WaffraText(body),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx,false),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),
     onPressed:()=>Navigator.pop(ctx,true),
     child:WaffraText(waffraIsEnglish?'Confirm delete':'تأكيد الحذف')),
   ]));
Future<void> bulkSmsSheet({String? initialText})async {
 if(_smsSheetOpen)return;
 _smsSheetOpen=true;
 final pasted=TextEditingController(text:initialText??'');
 final description=TextEditingController();
 final amount=TextEditingController();
 var messages=<String>[];
 var index=0;
 var income=false;
 var category='أخرى';
 var parsed=false;
 var reviewing=false,reviewAttempted=false,pasteAttempted=false;
 Timer? pasteTimer;
 var busy=false;
 var analyzingPaste=false;
 var savedCount=0;
 var statusMessage='';
 var rejectedMessages=<String>[];
 String? noTransactionWarning(String text){
  final parts=splitBankMessages(text.trim());
  if(text.trim().isEmpty||parts.isEmpty)return null;
  final hasTransaction=parts.any((message){
   final result=BankParser.parse(message);
   return result.amount!=null&&result.amount!>0;
  });
  return hasTransaction?null:(waffraIsEnglish
   ?'This message contains no financial transactions. Edit the text and it will be analyzed again automatically.'
   :'هذه الرسالة لا تحتوي على أي معاملات مالية. يمكنك تعديلها وسيتم تحليلها تلقائيًا مرة أخرى.');
 }

 bool sheetActive=true;
 Future<void> saveParsedMessages(BuildContext ctx,StateSetter update)async {
  if(busy)return;
  final found=splitBankMessages(pasted.text.trim());
  if(found.isEmpty){update(()=>statusMessage=waffraIsEnglish?'No financial transactions found. Edit the message and retry.':'هذه الرسالة لا تحتوي على أي معاملات مالية. عدّلها لإعادة التحليل تلقائيًا.');return;}
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
   final addRepeated=await showWaffraDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
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
  if(valid.isEmpty){update(() {statusMessage=waffraIsEnglish?'This message contains no financial transactions. Edit it to analyze again automatically.':'هذه الرسالة لا تحتوي على أي معاملات مالية. عدّل النص ليتم تحليله تلقائيًا مرة أخرى.';rejectedMessages=invalid.map((i)=>found[i]).toList();});return;}
  final incomes=valid.where((i)=>results[i].income).toList();
  final expenses=valid.where((i)=>!results[i].income).toList();
  final incomeTotal=incomes.fold<double>(0,(v,i)=>v+results[i].amount!);
  final expenseTotal=expenses.fold<double>(0,(v,i)=>v+results[i].amount!);
  final accepted=await showWaffraDialog<bool>(
   context:ctx,barrierColor:Colors.black.withValues(alpha:.25),
   builder:(dialogCtx)=>BackdropFilter(
    filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7),
    child:AlertDialog(
     title:WaffraText(waffraIsEnglish?'Confirm transactions':'تأكيد إضافة المعاملات'),
     content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(waffraIsEnglish?
       'Detected ${valid.length} transactions from bank messages:':
       'تم اكتشاف ${valid.length} معاملة من الرسائل البنكية:'),
      const SizedBox(height:16),
      Container(padding:const EdgeInsets.all(13),
       decoration:BoxDecoration(color:const Color(0xFFEAF7EF),borderRadius:BorderRadius.circular(15)),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        WaffraText(waffraIsEnglish?'Income transactions':'معاملات دخل',
         style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF075B43))),
        WaffraText(waffraIsEnglish?
         '${incomes.length} transactions — SAR ${incomeTotal.toStringAsFixed(2)}':
         '${incomes.length} معاملة — ${incomeTotal.toStringAsFixed(2)} ر.س',
         style:const TextStyle(color:Color(0xFF075B43))),
       ])),
      const SizedBox(height:10),
      Container(padding:const EdgeInsets.all(13),
       decoration:BoxDecoration(color:const Color(0xFFFFF0E9),borderRadius:BorderRadius.circular(15)),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        WaffraText(waffraIsEnglish?'Expense transactions':'معاملات مصروفات',
         style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF9A4328))),
        WaffraText(waffraIsEnglish?
         '${expenses.length} transactions — SAR ${expenseTotal.toStringAsFixed(2)}':
         '${expenses.length} معاملة — ${expenseTotal.toStringAsFixed(2)} ر.س',
         style:const TextStyle(color:Color(0xFF9A4328))),
       ])),
      if(invalid.isNotEmpty)...[
       const SizedBox(height:12),
       WaffraText(waffraIsEnglish?
        '${invalid.length} messages could not be analyzed.':
        'تعذر تحليل ${invalid.length} رسالة.',
        style:const TextStyle(color:Colors.deepOrange)),
      ],
      const SizedBox(height:12),
      WaffraText(waffraIsEnglish?
       'Confirm adding the detected transactions?':
       'هل تريد تأكيد إضافة المعاملات المكتشفة؟'),
     ]),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(dialogCtx,false),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:()=>Navigator.pop(dialogCtx,true),
       child:WaffraText(waffraIsEnglish?'Confirm and add':'تأكيد وإضافة المعاملات')),
     ],
    )));
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
   if(mounted)await showWaffraDialog<void>(context:context,builder:(dialogCtx)=>AlertDialog(
    title:Column(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.check_circle_rounded,color:Color(0xFF16805E),size:54),
     const SizedBox(height:16),
     WaffraText(waffraIsEnglish?'Transactions added successfully':'تمت إضافة المعاملات بنجاح',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:22)),
    ]),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText(waffraIsEnglish?
      'Saved ${additions.length} transactions':'تم حفظ ${additions.length} معاملة',
      textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w600)),
     const SizedBox(height:14),
     Container(padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:const Color(0xFFE6F4EA),borderRadius:BorderRadius.circular(14)),
      child:Row(children:[
       const Icon(Icons.trending_up,color:Color(0xFF087B56)),
       const SizedBox(width:10),
       Expanded(child:WaffraText(waffraIsEnglish?'Income':'الدخل',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF087B56)))),
       WaffraText('${incomes.length} • ${incomeTotal.toStringAsFixed(2)}',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF087B56))),
      ])),
     const SizedBox(height:9),
     Container(padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:const Color(0xFFFCECE8),borderRadius:BorderRadius.circular(14)),
      child:Row(children:[
       const Icon(Icons.trending_down,color:Color(0xFFD65A45)),
       const SizedBox(width:10),
       Expanded(child:WaffraText(waffraIsEnglish?'Expenses':'المصروفات',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFFD65A45)))),
       WaffraText('${expenses.length} • ${expenseTotal.toStringAsFixed(2)}',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFFD65A45))),
      ])),
     if(invalid.isNotEmpty)...[
      const SizedBox(height:12),
      WaffraText(waffraIsEnglish?
       'Could not analyze ${invalid.length} transactions':
       'تعذر تحليل ${invalid.length} معاملة',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.deepOrange)),
     ],
    ]),
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
   reviewAttempted=false;index=i;income=result.income;
   category=categories.any((c)=>c.income==income&&c.name==result.category)?result.category:
    (forType(income).isNotEmpty?forType(income).first.name:'أخرى');
   description.text='${result.title} — ${messages[i].replaceAll(RegExp(r'\s+'),' ').trim()}';
   amount.text=result.amount==null?'':formatWaffraMoney(result.amount!);
  });
 }
 BuildContext? activeSmsContext;
 StateSetter? activeSmsUpdate;
 bool awaitingMessagesApp=false;
 bool initialParsed=false;
 void analyzeSharedText(String text){
  final ctx=activeSmsContext,update=activeSmsUpdate;
  if(!sheetActive||ctx==null||!ctx.mounted||update==null||text.trim().isEmpty)return;
  final input=text.trim();
  pasted.text=input;
  pasteTimer?.cancel();
  update((){analyzingPaste=true;parsed=false;messages=[];statusMessage='';});
  pasteTimer=Timer(const Duration(milliseconds:600),(){
   if(!sheetActive||!ctx.mounted||pasted.text.trim()!=input)return;
   update((){
    messages=splitBankMessages(input);
    parsed=true;
    analyzingPaste=false;
    statusMessage=noTransactionWarning(input)??'';
   });
   if(statusMessage.isEmpty&&messages.isNotEmpty)saveParsedMessages(ctx,update);
  });
 }
 void onSharedDuringSheet(){
  final input=waffraIncomingSms.value;
  if(input==null||input.trim().isEmpty)return;
  waffraIncomingSms.value=null;
  awaitingMessagesApp=false;
  analyzeSharedText(input);
 }
 final smsLifecycle=AppLifecycleListener(onResume:(){
  if(!awaitingMessagesApp||!sheetActive)return;
  awaitingMessagesApp=false;
  Future<void>(()async{
   final data=await Clipboard.getData(Clipboard.kTextPlain);
   final value=data?.text?.trim();
   if(sheetActive&&value!=null&&value.isNotEmpty&&value!=pasted.text.trim()){
    analyzeSharedText(value);
   }
  });
 });
 waffraIncomingSms.addListener(onSharedDuringSheet);
 await showGeneralDialog<void>(context:context,barrierDismissible:true,barrierLabel:'Close',
  barrierColor:Colors.black.withValues(alpha:.45),
  pageBuilder:(dialogContext,animation,secondaryAnimation)=>BackdropFilter(
   filter:ui.ImageFilter.blur(sigmaX:9,sigmaY:9),
   child:Align(alignment:Alignment.bottomCenter,child:Material(
    color:Theme.of(dialogContext).scaffoldBackgroundColor,
    borderRadius:const BorderRadius.vertical(top:Radius.circular(28)),
    clipBehavior:Clip.antiAlias,
    child:SafeArea(top:false,child:StatefulBuilder(builder:(ctx,update){
   activeSmsContext=ctx;
   activeSmsUpdate=update;
   if(!initialParsed&&initialText!=null&&initialText.trim().isNotEmpty){
    initialParsed=true;
    WidgetsBinding.instance.addPostFrameCallback((_){
     if(ctx.mounted&&sheetActive)analyzeSharedText(initialText);
    });
   }
   final available=forType(income);
   final total=messages.fold<double>(0,(sum,s)=>sum+(BankParser.parse(s).amount??0));
   return Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(ctx).viewInsets.bottom+24),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Row(children:[Expanded(child:WaffraText(waffraIsEnglish?'Add bank message':'إضافة رسالة بنكية',style:Theme.of(ctx).textTheme.titleLarge)),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close_rounded))]),
     WaffraText(waffraIsEnglish?'Paste messages to analyze them automatically.':'الصق رسائلك البنكية ليتم تحليلها وتصنيفها تلقائيًا.'),
     const SizedBox(height:12),
     if(!reviewing)...[
      TextField(controller:pasted,minLines:5,maxLines:9,onChanged:(text){
       pasteTimer?.cancel();
       if(!sheetActive||!ctx.mounted)return;
       update((){parsed=false;analyzingPaste=text.trim().isNotEmpty;messages=[];statusMessage='';});
       if(text.trim().isNotEmpty){
        pasteTimer=Timer(const Duration(milliseconds:650),(){
         if(sheetActive&&ctx.mounted&&pasted.text.trim()==text.trim()){
          update((){messages=splitBankMessages(pasted.text.trim());parsed=true;analyzingPaste=false;statusMessage=noTransactionWarning(pasted.text)??'';});
          if(statusMessage.isEmpty&&messages.isNotEmpty)saveParsedMessages(ctx,update);
         }
        });
       }
      },decoration:InputDecoration(labelText:waffraIsEnglish?'Bank SMS *':'الرسالة البنكية *',
       errorText:statusMessage.isNotEmpty?statusMessage:(pasteAttempted&&pasted.text.trim().isEmpty?waffraRequiredFieldMessage:null),errorMaxLines:3,
       hintText:waffraIsEnglish?'Paste your bank message here. We’ll analyze it automatically.':'الصق رسالتك البنكية هنا، وبنحلّلها لك تلقائيًا.',hintStyle:const TextStyle(fontSize:13,color:Color(0xFF888F8A)),
       suffixIcon:pasted.text.isNotEmpty?IconButton(tooltip:waffraIsEnglish?'Clear text':'مسح النص',icon:const Icon(Icons.clear_rounded,color:Colors.redAccent),onPressed:(){pasteTimer?.cancel();pasted.clear();update((){parsed=false;analyzingPaste=false;messages=[];statusMessage='';});}):null,
       border:OutlineInputBorder(borderRadius:BorderRadius.circular(18)))),
      const SizedBox(height:12),
     SizedBox(width:double.infinity,child:OutlinedButton.icon(icon:const Icon(Icons.content_paste),
       onPressed:busy?null:()async {
        final data=await Clipboard.getData(Clipboard.kTextPlain);
        if(!ctx.mounted)return;
        final text=data?.text?.trim()??'';
        if(text.isEmpty){update((){pasteAttempted=true;statusMessage=waffraRequiredFieldMessage;});return;}
        pasted.text=text;
        pasteTimer?.cancel();
        update((){analyzingPaste=true;messages=[];parsed=false;statusMessage='';});
        pasteTimer=Timer(const Duration(milliseconds:650),(){
         if(!sheetActive||!ctx.mounted)return;
         update((){messages=splitBankMessages(text);parsed=true;analyzingPaste=false;statusMessage=noTransactionWarning(text)??'';});
         if(statusMessage.isEmpty&&messages.isNotEmpty)saveParsedMessages(ctx,update);
        });
       },label:WaffraText(waffraIsEnglish?'Paste copied SMS':'لصق آخر رسالة نسختها',maxLines:1,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
      const SizedBox(height:8),
      SizedBox(width:double.infinity,child:OutlinedButton.icon(
       icon:const Icon(Icons.message_outlined),
       onPressed:busy?null:()async{
        awaitingMessagesApp=true;
        final launched=await openWaffraMessagesApp();
        if(!launched&&ctx.mounted){
         awaitingMessagesApp=false;
         update(()=>statusMessage=waffraIsEnglish
          ?'Could not open Messages. Copy a message and paste it here instead.'
          :'تعذر فتح تطبيق الرسائل. انسخ الرسالة والصقها هنا بدلًا من ذلك.');
        }
       },
       label:WaffraText(waffraIsEnglish?'Open phone messages':'فتح رسائل الهاتف'),
      )),
      if(analyzingPaste)...[const SizedBox(height:12),const LinearProgressIndicator(),const SizedBox(height:6),WaffraText(waffraIsEnglish?'Analyzing your bank messages now…':'يتم الآن تحليل الرسائل البنكية واستخراج المعاملات…')],
      
      if(rejectedMessages.isNotEmpty)...[
       const SizedBox(height:8),
       WaffraText(waffraIsEnglish?'Unrecognized messages — edit and retry':'رسائل لم يتم تحليلها — راجعها وأعد المحاولة',style:const TextStyle(fontWeight:FontWeight.bold)),
       ...rejectedMessages.asMap().entries.map((item)=>Card(child:ListTile(
        title:WaffraText(waffraIsEnglish?'Message ${item.key+1}':'رسالة ${item.key+1}'),
        subtitle:SelectableText(item.value,maxLines:4),
        trailing:IconButton(icon:const Icon(Icons.edit_outlined),tooltip:waffraIsEnglish?'Review manually':'مراجعة يدويًا',onPressed:(){
         Navigator.pop(ctx);
         entrySheet(sms:true,initialSms:item.value);
        })))),
      ],
     if(parsed&&statusMessage.isEmpty)...[
      const SizedBox(height:10),
      Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
       decoration:BoxDecoration(color:Theme.of(ctx).brightness==Brightness.dark?const Color(0xFF123E32):const Color(0xFFE8F6EF),
        border:Border.all(color:emerald.withValues(alpha:.25)),borderRadius:BorderRadius.circular(16)),
       child:Row(children:[const Icon(Icons.check_circle_outline,color:emerald,size:19),const SizedBox(width:8),
        Expanded(child:WaffraText(waffraIsEnglish?'Detected ${messages.length} transactions':'تم اكتشاف ${messages.length} معاملة',
         style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)))])),
     ],
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
      TextField(controller:description,maxLines:2,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'وصف الرسالة *',errorText:reviewAttempted?waffraTextFieldError(description.text):null,border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'مبلغ هذه الرسالة بالريال *',errorText:reviewAttempted?waffraAmountFieldError(amount.text):null,border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$index-$income'),initialValue:available.any((c)=>c.name==category)?category:(available.isNotEmpty?available.first.name:null),
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       decoration:InputDecoration(labelText:waffraTr('قسم هذه الرسالة'),border:OutlineInputBorder()),
       onChanged:(v){if(v!=null)update(()=>category=v);}),
      const SizedBox(height:12),
      FilledButton(onPressed:busy?null:()async{
       final n=amountOf(amount.text);
       update(()=>reviewAttempted=true);
        if(waffraTextFieldError(description.text)!=null||waffraAmountFieldError(amount.text)!=null||n==null)return;
       final hash=bankSmsHash(messages[index]);
       if(smsHashes.contains(hash)){
        final yes=await showWaffraDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
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
       if(index+1>=messages.length){Navigator.pop(ctx);if(mounted)snackSuccess(context,'تم حفظ $savedCount عملية بنجاح');}
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
  }))))));
 sheetActive=false;
 smsLifecycle.dispose();
 waffraIncomingSms.removeListener(onSharedDuringSheet);
 _smsSheetOpen=false;
 disposeLater();
 _receiveSharedSms();
}

 Future<void> entrySheet({MoneyEntry? initial,bool sms=false,String? initialSms})async {
  final title=TextEditingController(text:initial?.title??'');
  final value=TextEditingController(text:initial==null?'':formatWaffraMoney(initial.amount));
  final message=TextEditingController(text:initialSms??'');
  bool income=initial?.income??false,analyzing=false,hasParsed=initialSms!=null;
  String category=initial?.category??'أخرى';
  String? selectedParentId;
  if(!sms){
   // Only leaf categories can be assigned to manually entered transactions.
   final matchingLeaf=categories.where((c)=>c.income==income&&
    c.isSubcategory&&c.name==category).toList();
   if(matchingLeaf.isNotEmpty&&categories.any((c)=>!c.isSubcategory&&
      c.income==income&&c.id==matchingLeaf.first.parentId)){
    selectedParentId=matchingLeaf.first.parentId;
   }else{
    category='';
   }
  }
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
    final mainCategories=waffraManualCategoryParents(available,income);
    final selectedMain=mainCategories.where((c)=>c.id==selectedParentId).toList();
    final subcategories=waffraManualCategoryChildren(available,income,selectedParentId);
    final selectedSub=subcategories.where((c)=>c.name==category).toList();
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
         errorText:attempted&&message.text.trim().isEmpty?waffraRequiredFieldMessage:null,
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
        income=v.first;
        selectedParentId=null;
        category=sms?(forType(income).isNotEmpty?forType(income).first.name:'أخرى'):'';
        suggestion=null;
       })),
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),minLines:1,maxLines:5,
       decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'وصف العملية *',
        errorText:attempted&&title.text.trim().isEmpty?waffraRequiredFieldMessage:null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(value.text):null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      if(sms)
       InkWell(onTap:()async{
        final picked=await chooseTransactionCategory(sheetContext,available,chosen??'');
        if(picked!=null&&sheetContext.mounted)update(()=>category=picked);
       },child:InputDecorator(decoration:InputDecoration(labelText:waffraTr('القسم'),
        border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.search_rounded)),
        child:WaffraText(chosen??'',maxLines:2)))
      else ...[
       InkWell(onTap:()async{
        final picked=await chooseTransactionCategory(sheetContext,mainCategories,
         selectedMain.isEmpty?'':selectedMain.first.name);
        if(picked==null||!sheetContext.mounted)return;
        final found=mainCategories.where((c)=>c.name==picked).toList();
        if(found.isEmpty)return;
        update((){
         if(selectedParentId!=found.first.id){selectedParentId=found.first.id;category='';}
        });
       },child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Main category *':'القسم الرئيسي *',
        errorText:attempted&&selectedMain.isEmpty?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.arrow_drop_down_rounded)),
        child:WaffraText(selectedMain.isEmpty?
         (waffraIsEnglish?'Choose a main category':'اختر القسم الرئيسي'):
         selectedMain.first.displayName,maxLines:2))),
       const SizedBox(height:10),
       InkWell(onTap:selectedMain.isEmpty||subcategories.isEmpty?null:()async{
        final picked=await chooseTransactionCategory(sheetContext,subcategories,
         selectedSub.isEmpty?'':selectedSub.first.name,leafLabels:true);
        if(picked!=null&&sheetContext.mounted)update(()=>category=picked);
       },child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Subcategory *':'القسم الفرعي *',
        enabled:selectedMain.isNotEmpty,
        errorText:attempted&&selectedSub.isEmpty?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.arrow_drop_down_rounded)),
        child:WaffraText(selectedSub.isEmpty?
         (waffraIsEnglish?'Choose a subcategory':'اختر القسم الفرعي'):
         selectedSub.first.displayName,maxLines:2))),
       if(selectedMain.isNotEmpty&&subcategories.isEmpty)
        Padding(padding:const EdgeInsets.only(top:7),child:WaffraText(
         waffraIsEnglish?'No subcategories yet. Add one below first.':
         'لا توجد أقسام فرعية هنا، أضف قسمًا فرعيًا أولًا.',
         style:const TextStyle(color:Colors.redAccent,fontSize:12))),
      ],
      if(sms&&suggestion!=null)TextButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income,suggested:suggestion);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update((){category=c.name;suggestion=null;});
       }
      },icon:const Icon(Icons.add),label:WaffraText('إضافة قسم $suggestion')),
      if(sms)OutlinedButton.icon(onPressed:()async {
       final c=await categoryDialog(income:income);
       if(c!=null&&mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));await persist();
        }
        update(()=>category=c.name);
       }
      },icon:const Icon(Icons.add),label:const WaffraText('قسم جديد'))
      else if(selectedMain.isNotEmpty)OutlinedButton.icon(onPressed:()async {
       final mainId=selectedMain.first.id;
       final c=await categoryDialog(income:income,parentId:mainId);
       if(c!=null&&mounted&&sheetContext.mounted){
        if(!categories.any((x)=>x.name==c.name&&x.income==c.income)){
         setState(()=>categories.add(c));
         await persist();
        }
        if(sheetContext.mounted)update(()=>category=c.name);
       }
      },icon:const Icon(Icons.add),
       label:WaffraText(waffraIsEnglish?'New subcategory':'قسم فرعي جديد')),
      OutlinedButton.icon(onPressed:()async {
       final d=await showDatePicker(context:sheetContext,initialDate:date,
        firstDate:DateTime(2000),lastDate:DateTime.now());
       if(d!=null)update(()=>date=d);
      },icon:const Icon(Icons.calendar_month),label:WaffraText(dayText(date))),
      const SizedBox(height:12),
      Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final file=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:80);
        if(file!=null){final path=await saveReceipt(file);if(sheetContext.mounted)update(()=>receiptPath=waffraEncodeReceipts([...waffraReceiptPaths(receiptPath),path]));}
       },icon:const Icon(Icons.camera_alt_outlined),label:const WaffraText('تصوير فاتورة'))),
       const SizedBox(width:8),
       Expanded(child:OutlinedButton.icon(onPressed:()async{
        final files=await ImagePicker().pickMultiImage(imageQuality:80);
        if(files.isNotEmpty){final paths=<String>[...waffraReceiptPaths(receiptPath)];
         for(final file in files){paths.add(await saveReceipt(file));}
         if(sheetContext.mounted)update(()=>receiptPath=waffraEncodeReceipts(paths));}
       },icon:const Icon(Icons.attach_file),label:const WaffraText('إرفاق صورة'))),
      ]),
      if(waffraReceiptPaths(receiptPath).isNotEmpty)...[
       for(final path in waffraReceiptPaths(receiptPath))
        ListTile(dense:true,
         title:WaffraText(path.split('/').last.replaceFirst(RegExp(r'^\\d+__'),'')),
         leading:const Icon(Icons.image,color:emerald),
         trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>update((){
          receiptPath=waffraEncodeReceipts([...waffraReceiptPaths(receiptPath)]..remove(path));
         })),
         onTap:()=>showReceipt(receiptPath!,initialIndex:waffraReceiptPaths(receiptPath).indexOf(path))),
      ],
      const SizedBox(height:12),
      FilledButton(onPressed:analyzing?null:()async {
       update(()=>attempted=true);
       final n=amountOf(value.text);
       if(title.text.trim().isEmpty||waffraAmountFieldError(value.text)!=null||n==null)return;
       if(!sms&&!waffraCanAssignManualCategory(categories,
        income,selectedParentId,category))return;
       if(sms){
        if(message.text.trim().isEmpty)return;
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){
         final proceed=await showWaffraDialog<bool>(context:sheetContext,builder:(dialogContext)=>AlertDialog(
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
   final proceed=await showWaffraDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
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
  if(initial!=null&&mounted){
   snack(context,waffraIsEnglish?'Transaction updated':'تم تعديل المعاملة',
    isError:false,duration:const Duration(seconds:5),
    actionLabel:waffraIsEnglish?'Undo':'تراجع',
    onAction:()async{
     if(!mounted)return;
     final index=entries.indexWhere((e)=>e.id==initial.id);
     if(index<0)return;
     setState(()=>entries[index]=initial);
     await persist();
    });
  }
 }
 Future<String?> chooseTransactionCategory(BuildContext ctx,List<BudgetCategory> options,String selected,{bool leafLabels=false})async{
  var query='';
  return showWaffraDialog<String>(context:ctx,builder:(dialogCtx)=>StatefulBuilder(builder:(dialogCtx,refresh){
   final filtered=options.where((item)=>(leafLabels?item.displayName:item.name).toLowerCase().contains(query.trim().toLowerCase())).toList();
   return AlertDialog(title:WaffraText(waffraIsEnglish?'Search categories':'بحث في الأقسام'),
    content:SizedBox(width:360,height:min(420.0,MediaQuery.sizeOf(dialogCtx).height*.55),child:Column(children:[
     TextField(autofocus:true,onChanged:(v)=>refresh(()=>query=v),
      decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:waffraIsEnglish?'Search…':'اكتب اسم القسم',border:const OutlineInputBorder())),
     const SizedBox(height:9),
     Expanded(child:ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){
      final item=filtered[i];return ListTile(selected:selected==item.name,
       leading:Icon(categoryIcon(item.icon),color:Color(item.color)),
       title:WaffraText(leafLabels?item.displayName:item.name,maxLines:3),onTap:()=>Navigator.pop(dialogCtx,item.name));
     })),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogCtx),child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
  }));
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
 Future<void> showReceipt(String encoded,{int initialIndex=0})async {
  final paths=waffraReceiptPaths(encoded);
  final available=<String>[];
  for(final path in paths){if(await File(path).exists())available.add(path);}
  if(available.isEmpty){if(mounted)snack(context,waffraIsEnglish?'Images not found on this device':'ما لقينا الصور على الجهاز');return;}
  if(!mounted)return;
  final controller=PageController(initialPage:initialIndex.clamp(0,available.length-1));
  int current=initialIndex.clamp(0,available.length-1);
  try{
   await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final isDark=Theme.of(ctx).brightness==Brightness.dark;
    final accent=isDark?const Color(0xFF74D8A9):emerald;
    final surface=isDark?const Color(0xFF102A23):const Color(0xFF073F31);
    final count='${current+1} / ${available.length}';
    return Dialog(
     backgroundColor:Colors.transparent,elevation:0,
     insetPadding:const EdgeInsets.symmetric(horizontal:22,vertical:45),
     child:Container(
      constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*.74),
      decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(24),
       border:Border.all(color:accent.withValues(alpha:.85),width:1.2)),
      clipBehavior:Clip.antiAlias,
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       SizedBox(height:54,child:Stack(alignment:Alignment.center,children:[
        PositionedDirectional(end:7,child:IconButton(
         tooltip:waffraIsEnglish?'Close':'إغلاق',
         onPressed:()=>Navigator.pop(ctx),
         icon:const Icon(Icons.close_rounded,color:Colors.white))),
       ])),
       Flexible(child:Container(color:Colors.black,
        child:PageView.builder(controller:controller,itemCount:available.length,
         onPageChanged:(index)=>update(()=>current=index),
         itemBuilder:(ctx,index)=>InteractiveViewer(
          minScale:.8,maxScale:5,
          child:Center(child:Image.file(File(available[index]),fit:BoxFit.contain)))))),
       SizedBox(height:58,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(
         tooltip:waffraIsEnglish?'Previous image':'الصورة السابقة',
         onPressed:current>0?()=>controller.previousPage(
          duration:waffraMotion(220),curve:Curves.easeInOut):null,
         icon:Icon(Icons.chevron_left_rounded,color:current>0?Colors.white:Colors.white38)),
        Text(count,textDirection:TextDirection.ltr,
         style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.bold)),
        IconButton(
         tooltip:waffraIsEnglish?'Next image':'الصورة التالية',
         onPressed:current<available.length-1?()=>controller.nextPage(
          duration:const Duration(milliseconds:220),curve:Curves.easeInOut):null,
         icon:Icon(Icons.chevron_right_rounded,
          color:current<available.length-1?Colors.white:Colors.white38)),
       ])),
      ])));
   }));
  }finally{controller.dispose();}
 }
 Future<void> budgetAlert(MoneyEntry entry,double previousSpent)async {
  if(entry.income)return;
  final category=categoryFor(entry.category,false);
  if(category.budget<=0)return;
  final spent=sum(entries.where((e)=>!e.income&&e.category==entry.category&&
   e.date.year==entry.date.year&&e.date.month==entry.date.month),false);
  final stages=<int>{category.alertPercent,100}.toList()..sort();
  int? crossed;
  for(final stage in stages){
   if(previousSpent<category.budget*stage/100&&spent>=category.budget*stage/100)crossed=stage;
  }
  if(crossed==null||!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
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
  bool exportDialogOpen=false;
  final exportNavigator=Navigator.of(context,rootNavigator:true);
  try{
   exportDialogOpen=true;
   unawaited(showWaffraDialog<void>(context:context,useRootNavigator:true,barrierDismissible:false,
    barrierColor:Colors.black.withValues(alpha:.22),
    builder:(dialogContext)=>PopScope(canPop:false,child:BackdropFilter(
     filter:ui.ImageFilter.blur(sigmaX:9,sigmaY:9),
     child:Center(child:Material(color:Colors.transparent,child:Container(
      width:MediaQuery.of(dialogContext).size.width*.82,
      padding:const EdgeInsets.all(28),
      decoration:BoxDecoration(color:Theme.of(dialogContext).cardColor,
       borderRadius:BorderRadius.circular(26),
       border:Border.fromBorderSide(waffraDialogOutline(Theme.of(dialogContext).brightness))),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       const SizedBox(height:8),
       const Icon(Icons.picture_as_pdf_rounded,size:63,color:emerald),
       const SizedBox(height:18),
       const SizedBox(width:48,height:48,child:CircularProgressIndicator(strokeWidth:4.5,color:emerald)),
       const SizedBox(height:22),
       WaffraText(waffraIsEnglish?'Exporting PDF report...':'يتم الآن تصدير التقرير إلى PDF',
        textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
       const SizedBox(height:9),
       WaffraText(waffraIsEnglish?'Please wait while your report is prepared.':
        'يرجى الانتظار أثناء تجهيز التقرير.',textAlign:TextAlign.center),
      ]),
     )))),
    )));
   await Future<void>.delayed(const Duration(milliseconds:350));
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
       columnWidths:{0:const pw.FixedColumnWidth(34),1:const pw.FixedColumnWidth(85),
        2:const pw.FixedColumnWidth(61),3:const pw.FixedColumnWidth(90),
        4:const pw.FlexColumnWidth(3),5:const pw.FixedColumnWidth(83)},
       children:[
        pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
         children:(english?['No.','Date','Type','Category','Description','Amount (SAR)']:
          ['رقم المعاملة','التاريخ','النوع','القسم','الوصف','المبلغ (ريال)'])
          .map((h)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
           child:pw.Text(h,textAlign:pw.TextAlign.center,style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.white)))).toList()),
        ...ordered.asMap().entries.map((row){
         final e=row.value,art=descriptions[row.key];
         return pw.TableRow(
         decoration:pw.BoxDecoration(color:PdfColor.fromInt(e.income?waffraIncomeBackground.toARGB32():waffraExpenseBackground.toARGB32())),
         children:[
          pdfCell('${row.key+1}',center:true),
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
   if(exportDialogOpen&&exportNavigator.mounted){exportNavigator.pop();exportDialogOpen=false;}
   if(!mounted)return;
   final fileName=analytics?'waffra_analytics.pdf':'waffra_income_expenses.pdf';
   await showWaffraDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),
     side:waffraDialogOutline(Theme.of(dialogContext).brightness)),
    title:Column(children:[
     const Icon(Icons.check_circle_rounded,color:emerald,size:58),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'Report ready':'تم تجهيز التقرير بنجاح',
      textAlign:TextAlign.center),
    ]),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.picture_as_pdf,color:Colors.red,size:38),
     const SizedBox(height:8),
     WaffraText(analytics?(waffraIsEnglish?'Analytics report':'تقرير التحليلات'):
      (waffraIsEnglish?'Income and expenses report':'تقرير الدخل والمصروفات'),
      textAlign:TextAlign.center),
     const SizedBox(height:4),
     WaffraText('${(bytes.length/1024).toStringAsFixed(1)} KB',
      textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),
    ]),
    actionsAlignment:MainAxisAlignment.center,
    actions:[
     SizedBox(width:double.infinity,child:FilledButton.icon(
      onPressed:(){
       Navigator.of(dialogContext).pop();
       Navigator.of(context).push(MaterialPageRoute(builder:(_)=>
        WaffraPdfReader(bytes:bytes,fileName:fileName,english:waffraIsEnglish)));
      },
      icon:const Icon(Icons.visibility_outlined),
      label:WaffraText(waffraIsEnglish?'Open report':'فتح التقرير'))),
     SizedBox(width:double.infinity,child:OutlinedButton.icon(
      onPressed:()async{
       Navigator.of(dialogContext).pop();
       await Printing.sharePdf(bytes:bytes,filename:fileName);
      },
      icon:const Icon(Icons.share_outlined),
      label:WaffraText(waffraIsEnglish?'Share report':'مشاركة التقرير'))),
    ],
   ));
  }catch(e,st){
   debugPrint('PDF export error: $e\n$st');
   if(exportDialogOpen&&exportNavigator.mounted){exportNavigator.pop();exportDialogOpen=false;}
   if(mounted)snack(context,waffraIsEnglish?'Could not export the PDF report. Please try again.':'تعذر تصدير تقرير PDF. حاول مرة أخرى.');
  }
 }
 Future<void> deleteEntry(MoneyEntry e)async {
  final yes=await confirmDeletion(waffraIsEnglish?'Delete transaction':'حذف العملية',
   waffraIsEnglish?'Delete «'+e.title+'»? You can undo for 6 seconds after deletion.':'هل تريد حذف المعاملة «'+e.title+'»؟ يمكنك التراجع خلال 6 ثوانٍ بعد الحذف.');
  if(yes!=true||!mounted)return;
  setState(()=>entries.removeWhere((x)=>x.id==e.id));
  await persist();
  if(!mounted)return;
  snack(context,waffraIsEnglish?'Transaction deleted':'تم حذف العملية',
   isError:false,duration:const Duration(seconds:5),
   actionLabel:waffraIsEnglish?'Undo':'تراجع',
   onAction:()async{
    if(!mounted||entries.any((x)=>x.id==e.id))return;
    setState(()=>entries.insert(0,e));
    await persist();
   });
 }
 Widget stat(String label,double value,IconData icon,Color color)=>Expanded(
  child:Card(child:Padding(padding:const EdgeInsets.all(12),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:color),const SizedBox(height:8),WaffraText(label),const SizedBox(height:6),
    FittedBox(child:RiyalAmount(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
   ]))));
 Future<void> transactionActions(MoneyEntry entry)async {
  final hasReceipt=waffraReceiptPaths(entry.receiptPath).isNotEmpty;
  final action=await showWaffraDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   insetPadding:const EdgeInsets.symmetric(horizontal:26,vertical:24),
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
   title:WaffraText(entry.title,maxLines:2,
    style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
   content:SizedBox(width:340,child:Column(mainAxisSize:MainAxisSize.min,children:[
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
     crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.55,
     children:[
      _transactionActionTile(ctx,'open',Icons.open_in_new_rounded,
       waffraIsEnglish?'View details':'عرض التفاصيل',emerald),
      _transactionActionTile(ctx,'edit',Icons.edit_outlined,
       waffraIsEnglish?'Edit':'تعديل',emerald),
      _transactionActionTile(ctx,'delete',Icons.delete_outline_rounded,
       waffraIsEnglish?'Delete':'حذف',Colors.red),
      _transactionActionTile(ctx,'cancel',Icons.close_rounded,
       waffraIsEnglish?'Cancel':'إلغاء',Theme.of(ctx).colorScheme.onSurface),
     ]),
    if(hasReceipt)...[
     const SizedBox(height:10),
     SizedBox(width:double.infinity,child:OutlinedButton.icon(
      onPressed:()=>Navigator.pop(ctx,'receipt'),
      icon:const Icon(Icons.photo_library_outlined),
      label:WaffraText(waffraIsEnglish?'View attached images':'عرض الصور المرفقة'))),
    ],
   ])),
  ));
  if(!mounted)return;
  switch(action){
   case 'receipt':if(hasReceipt)await showReceipt(entry.receiptPath!);break;
   case 'open':await transactionDetails(entry);break;
   case 'edit':await entrySheet(initial:entry);break;
   case 'delete':await deleteEntry(entry);break;
  }
 }
 Widget _transactionActionTile(BuildContext dialogContext,String value,
  IconData icon,String label,Color color)=>Material(
   color:color.withValues(alpha:.08),
   borderRadius:BorderRadius.circular(16),
   child:InkWell(
    borderRadius:BorderRadius.circular(16),
    onTap:()=>Navigator.pop(dialogContext,value),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:10),
     child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:color,size:24),
      const SizedBox(height:6),
      Flexible(child:WaffraText(label,maxLines:2,textAlign:TextAlign.center,
       style:TextStyle(color:color,fontWeight:FontWeight.w600,fontSize:13))),
     ])),
   ),
  );
 Future<void> transactionDetails(MoneyEntry entry)async {
  await showWaffraDialog<void>(
   context:context,
   builder:(ctx)=>WaffraTransactionDetailsDialog(
    entry:entry,
    onClose:()=>Navigator.pop(ctx),
    onViewReceipt:waffraReceiptPaths(entry.receiptPath).isNotEmpty
      ?(){Navigator.pop(ctx);showReceipt(entry.receiptPath!);}
      :null,
   ),
  );
 }

 Widget tile(MoneyEntry e){
  final c=categoryFor(e.category,e.income);
  final attachmentCount=waffraReceiptPaths(e.receiptPath).length;
  return Card(color:e.income?waffraIncomeBackground:waffraExpenseBackground,
   child:Stack(children:[
    Padding(padding:EdgeInsets.only(top:attachmentCount>0?20:0),child:ListTile(
   textColor:waffraInk,iconColor:forest,
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
    child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:WaffraText(e.title,style:const TextStyle(color:waffraInk,fontWeight:FontWeight.w600)),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(color:waffraInk)),

   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    Column(mainAxisSize:MainAxisSize.min,children:[
     Text('${e.income?'+':'-'}${cash(e.amount)}',style:TextStyle(fontFamily:'Tajawal',fontSize:18,fontWeight:FontWeight.w800,color:e.income?const Color(0xFF075C40):waffraInk)),
     WaffraText(waffraIsEnglish?'SAR':'ريال',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:e.income?const Color(0xFF075C40):waffraInk)),
    ]),
    IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
     onPressed:()=>transactionActions(e),icon:const Icon(Icons.more_vert,color:forest)),
   ]))),
   if(attachmentCount>0)PositionedDirectional(top:0,end:0,child:Semantics(
    label:waffraIsEnglish?'$attachmentCount attachments':'عدد المرفقات $attachmentCount',
    button:true,child:InkWell(onTap:()=>showReceipt(e.receiptPath!),
     borderRadius:BorderRadius.circular(13),
     child:Container(padding:const EdgeInsetsDirectional.fromSTEB(9,4,10,4),
      decoration:const BoxDecoration(color:forest,
       borderRadius:BorderRadiusDirectional.only(topEnd:Radius.circular(19),bottomStart:Radius.circular(13))),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.attach_file_rounded,color:Colors.white,size:15),
       const SizedBox(width:3),
       Text('$attachmentCount',style:const TextStyle(fontFamily:'Tajawal',fontSize:13,color:Colors.white,fontWeight:FontWeight.bold)),
      ]))))),
   ]));
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
   if(mounted)snackSuccess(context,waffraIsEnglish?'All transactions deleted':'تم حذف جميع المعاملات');
  }catch(e){
   if(mounted){setState((){entries.addAll(backup);smsHashes.addAll(hashBackup);});snack(context,waffraIsEnglish?'Delete failed':'فشل حذف المعاملات');}
  }
 }
 Future<void> editMonthlyBudget()async {
  final amount=TextEditingController(text:monthlyBudget>0?monthlyBudget.toStringAsFixed(0):'');
  bool enabled=monthlyBudgetEnabled;
  String? validation;
  try{
   final next=await showWaffraDialog<({bool enabled,double amount})>(
    context:context,builder:(ctx)=>BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7),child:StatefulBuilder(builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Monthly budget':'الميزانية الشهرية'),
     content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      SwitchListTile.adaptive(
       contentPadding:EdgeInsets.zero,
       title:WaffraText(waffraIsEnglish?'Enable monthly budget':'تفعيل الميزانية الشهرية',
        style:const TextStyle(fontWeight:FontWeight.bold)),
       value:enabled,activeTrackColor:emerald,
       onChanged:(value)=>update((){enabled=value;validation=null;}),
      ),
      const SizedBox(height:8),
      WaffraText(enabled?
       (waffraIsEnglish?'Set the amount allocated for monthly spending.':'حدد المبلغ الذي ترغب في تخصيصه لمصروفاتك الشهرية.'):
       (waffraIsEnglish?'Monthly spending limit tracking is paused.':'تم إيقاف متابعة حد المصروفات الشهرية.')),
      const SizedBox(height:16),
      TextField(controller:amount,enabled:enabled,autofocus:false,
       onChanged:(_){if(validation!=null)update(()=>validation=null);},
       style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Theme.of(ctx).colorScheme.onSurface),
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Spending limit (SAR) *':'حد المصروفات بالريال *',
        hintText:waffraIsEnglish?'Example: 3000':'مثال: 3000',
        errorText:validation,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
        filled:true,fillColor:Theme.of(ctx).brightness==Brightness.dark?
         const Color(0xFF1E3A31):Colors.white)),
     ]),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:(){
       final v=double.tryParse(amount.text.trim().replaceAll(',',''));
       if(enabled&&(v==null||!v.isFinite||v<=0)){
        update(()=>validation=waffraAmountFieldError(amount.text));
        return;
       }
       Navigator.pop(ctx,(enabled:enabled,amount:enabled?v!:monthlyBudget));
      },child:WaffraText(waffraIsEnglish?'Save':'حفظ')),
     ],
    ))));
   if(next!=null&&mounted){
    setState((){monthlyBudgetEnabled=next.enabled;monthlyBudget=next.amount;});
    await persist();
    if(mounted)snackSuccess(context,waffraIsEnglish?'Monthly budget settings saved':'تم حفظ إعدادات الميزانية الشهرية');
   }
  }finally{disposeLater([amount]);}
 }
 Future<void> editTransactionFilters()async {
  final min=TextEditingController(text:minTransactionAmount?.toStringAsFixed(2)??'');
  final max=TextEditingController(text:maxTransactionAmount?.toStringAsFixed(2)??'');
  String? minError,maxError;
  DateTimeRange? chosen=transactionsDateRange;
  try{
   await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(
    builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Advanced filters':'فلترة بالتاريخ والمبلغ'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:min,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>minError=null),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Minimum amount':'أقل مبلغ',
        errorText:minError,
        border:const OutlineInputBorder())),
      const SizedBox(height:10),
      TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>maxError=null),
       inputFormatters:[const WaffraAmountFormatter()],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Maximum amount':'أعلى مبلغ',
        errorText:maxError,
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
        update((){
         minError=min.text.trim().isNotEmpty&&(lo==null||!lo.isFinite||lo<0)?(waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا'):null;
         maxError=max.text.trim().isNotEmpty&&(hi==null||!hi.isFinite||hi<0)?(waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا'):null;
         if(lo!=null&&hi!=null&&lo>hi)maxError=waffraIsEnglish?'Maximum must not be less than minimum':'الحد الأعلى يجب ألا يقل عن الحد الأدنى';
        });
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
  final used=monthlyBudgetEnabled&&monthlyBudget>0?(spent/monthlyBudget).clamp(0.0,1.0):0.0;
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
    if(monthlyBudgetEnabled&&monthlyBudget>0)...[
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
      Expanded(child:_budgetFigure(spent>monthlyBudget?(waffraIsEnglish?'Over budget':'التجاوز'):(waffraIsEnglish?'Remaining':'المتبقي'),
       (monthlyBudget-spent).abs())), 
     ]),
     if(spent>=monthlyBudget*.8)Padding(
      padding:const EdgeInsets.only(top:10),
      child:WaffraText(waffraIsEnglish?
       (spent>monthlyBudget?'Monthly budget exceeded by ${cash(spent-monthlyBudget)}.':spent==monthlyBudget?'Monthly budget fully used.':'80% of budget used.'):
       (spent>monthlyBudget?'تجاوزت الميزانية الشهرية بمبلغ ${cash(spent-monthlyBudget)}.':spent==monthlyBudget?'استهلكت الميزانية الشهرية بالكامل.':'استهلكت 80٪ من الميزانية.'),
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
      monthlyBudgetEnabled&&monthlyBudget>0?cash(daily):(waffraIsEnglish?'Set a budget':'حدد ميزانية'),
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
  if(items.isEmpty){
   if(!mounted)return;
   await showWaffraDialog<void>(context:context,builder:(ctx){
    final dark=Theme.of(ctx).brightness==Brightness.dark;
    final accent=income?emerald:const Color(0xFFE57373);
    return AlertDialog(
     backgroundColor:dark?const Color(0xFF171D1B):const Color(0xFFF9FDFB),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
     contentPadding:const EdgeInsets.fromLTRB(22,25,22,10),
     content:Column(mainAxisSize:MainAxisSize.min,children:[
      CircleAvatar(radius:32,backgroundColor:accent.withValues(alpha:.12),
       child:Icon(income?Icons.account_balance_wallet_outlined:Icons.wallet_outlined,
        color:accent,size:32)),
      const SizedBox(height:16),
      WaffraText(waffraIsEnglish?'No transactions yet':'لا توجد معاملات حالية',
       textAlign:TextAlign.center,
       style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      WaffraText(income?
       (waffraIsEnglish?'No income transactions recorded yet. You can add a new income transaction.':'لا توجد عمليات دخل مسجلة حاليًا. يمكنك إضافة معاملة دخل جديدة.'):
       (waffraIsEnglish?'No expense transactions recorded yet. You can add a new expense transaction.':'لا توجد عمليات مصروف مسجلة حاليًا. يمكنك إضافة معاملة مصروف جديدة.'),
       textAlign:TextAlign.center),
      const SizedBox(height:18),
      SizedBox(width:double.infinity,child:FilledButton(
       onPressed:()=>Navigator.pop(ctx),
       child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))),
     ]),
    );
   });
   return;
  }
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   useSafeArea:true,builder:(ctx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.58,minChildSize:.32,maxChildSize:.90,
    builder:(ctx,scroll)=>Column(children:[
     Padding(padding:const EdgeInsets.fromLTRB(18,4,18,12),
      child:Row(children:[
       Icon(income?Icons.trending_up:Icons.trending_down,
        color:income?waffraIncomeTone(context):Colors.deepOrange),
       const SizedBox(width:9),
       Expanded(child:WaffraText(income?
        (waffraIsEnglish?'Income transactions':'عمليات الدخل'):
        (waffraIsEnglish?'Expense transactions':'عمليات المصروفات'),
        style:Theme.of(ctx).textTheme.titleLarge)),
       IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close)),
      ])),
     if(items.isNotEmpty)...[
      Container(
       margin:const EdgeInsets.symmetric(horizontal:16),
       padding:const EdgeInsets.all(16),width:double.infinity,
       decoration:BoxDecoration(color:(income?emerald:Colors.deepOrange).withValues(alpha:.10),
        borderRadius:BorderRadius.circular(18)),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
         WaffraText(waffraIsEnglish?'Number of transactions':'عدد العمليات'),
         WaffraText(waffraIsEnglish?'${items.length} transactions':'${items.length} عملية',
          style:const TextStyle(fontWeight:FontWeight.bold)),
        ]),
        const Divider(height:22),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
         WaffraText(income?(waffraIsEnglish?'Total income':'إجمالي الدخل'):
          (waffraIsEnglish?'Total expenses':'إجمالي المصروفات')),
         Flexible(child:WaffraText(cash(sum(items,income)),
          textAlign:TextAlign.end,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        ]),
       ])),
      const SizedBox(height:10),
     ],
     Expanded(child:items.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(income?Icons.account_balance_wallet_outlined:Icons.receipt_long_outlined,
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
         style:TextStyle(fontWeight:FontWeight.bold,color:income?waffraIncomeTone(context):Colors.deepOrange)));
      })),
    ])));
 }
 Widget _dashboardShortcut(String title,IconData icon,VoidCallback onTap){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Expanded(child:Material(
   color:Theme.of(context).cardColor,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
    side:BorderSide(color:dark?const Color(0xFF354B3E):const Color(0xFFDCEAE1))),
   child:InkWell(
    onTap:onTap,borderRadius:BorderRadius.circular(18),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:12),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:34,height:34,
       decoration:BoxDecoration(color:dark?const Color(0xFF214E37):waffraMint,
        borderRadius:BorderRadius.circular(12)),
       child:Icon(icon,color:dark?const Color(0xFFA2E4C1):forest,size:21)),
      const SizedBox(height:6),
      WaffraText(title,maxLines:2,textAlign:TextAlign.center,
       style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
     ])),
   ),
  ));
 }
 Widget homeSummaryCard(String label,double value,IconData symbol,Color color,Color tint)=>
  Expanded(child:InkWell(
   onTap:()=>showSummaryTransactions(label=='الدخل'||label=='Income'),
   borderRadius:BorderRadius.circular(19),
   child:Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),
    decoration:BoxDecoration(
     color:Theme.of(context).brightness==Brightness.dark?
      (label=='الدخل'||label=='Income'?const Color(0xFF244C3A):const Color(0xFF49302C)):tint,
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
  final valueColor=entry.income?waffraIncomeTone(context):Colors.deepOrange;
  final darkMode=Theme.of(context).brightness==Brightness.dark;
  final attachmentCount=waffraReceiptPaths(entry.receiptPath).length;
  final rowColor=entry.income?(darkMode?const Color(0xFF244C3A):const Color(0xFFB2D5C2)):
   (darkMode?const Color(0xFF49302C):const Color(0xFFFCECE8));
  return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Container(
   decoration:BoxDecoration(color:rowColor,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:forest.withValues(alpha:darkMode ? 0.18 : 0.08))),
   clipBehavior:Clip.antiAlias,
   child:Stack(children:[
    Padding(padding:EdgeInsetsDirectional.only(top:attachmentCount>0?18:0),
     child:Padding(padding:const EdgeInsets.symmetric(horizontal:11,vertical:12),child:Row(children:[
    CircleAvatar(radius:18,
     backgroundColor:Color(cat.color).withValues(alpha:0.13),
     child:Icon(categoryIcon(cat.icon),size:19,color:Color(cat.color))),
    const SizedBox(width:8),
    Expanded(child:InkWell(onTap:()=>transactionDetails(entry),
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
    IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
     onPressed:()=>transactionActions(entry),icon:const Icon(Icons.more_vert,size:18)),
    ]))),
    if(attachmentCount>0)PositionedDirectional(top:0,end:0,child:Semantics(
     label:waffraIsEnglish?'$attachmentCount attachments':'عدد المرفقات $attachmentCount',
     button:true,child:InkWell(onTap:()=>showReceipt(entry.receiptPath!),
      borderRadius:BorderRadius.circular(12),
      child:Container(padding:const EdgeInsetsDirectional.fromSTEB(8,4,9,4),
       decoration:const BoxDecoration(color:forest,
        borderRadius:BorderRadiusDirectional.only(topEnd:Radius.circular(17),bottomStart:Radius.circular(12))),
       child:Row(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.attach_file_rounded,color:Colors.white,size:14),
        const SizedBox(width:3),
        Text('$attachmentCount',style:const TextStyle(fontFamily:'Tajawal',fontSize:12,color:Colors.white,fontWeight:FontWeight.bold)),
       ]))))),
   ])));
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
     controller:_dashboardScrollController,
     physics:const AlwaysScrollableScrollPhysics(),
     slivers:[
      SliverToBoxAdapter(child:Padding(
       padding:const EdgeInsets.fromLTRB(14,14,14,4),
       child:WaffraPageHero(
        title:greeting,
        subtitle:waffraIsEnglish?'Your finances at a glance':
         'تابع رصيدك ومعاملاتك وخططك المالية بسهولة.',
        icon:Icons.spa_outlined))),
      // Not pinned: the shrinking balance scrolls away without covering data.
      SliverPersistentHeader(
       pinned:false,
       delegate:WaffraBalanceHeader(balance:inc-exp,english:waffraIsEnglish,focusKey:_tourKeys[0])),
      SliverPadding(padding:const EdgeInsets.fromLTRB(14,10,14,96),
       sliver:SliverToBoxAdapter(child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(children:[
          homeSummaryCard(waffraIsEnglish?'Income':'الدخل',
           inc,Icons.south_west,waffraIncomeTone(context),const Color(0xFFB2D5C2)),
          const SizedBox(width:9),
          homeSummaryCard(waffraIsEnglish?'Expenses':'المصروفات',
           exp,Icons.north_east,const Color(0xFFB94838),waffraExpenseBackground),
         ]),
         const SizedBox(height:15),
          smartAnalysisEntryCard(),
          const SizedBox(height:15),
         WaffraText(waffraIsEnglish?'Quick actions':'إجراءات سريعة',
          style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
         const SizedBox(height:8),
         Row(children:[
          _dashboardShortcut(waffraIsEnglish?'Export report':'تصدير تقرير',
           Icons.analytics_outlined,()=>exportEntriesPdf(entries,'تقرير عمليات وفرة')),
          const SizedBox(width:8),
          _dashboardShortcut(waffraIsEnglish?'Financial calendar':'التقويم المالي',
           Icons.calendar_month_outlined,openFinancialCalendar),

         ]),
         const SizedBox(height:13),
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
           const SizedBox(height:9),
           Row(children:[
            Expanded(child:Container(
             padding:const EdgeInsets.all(12),
             decoration:BoxDecoration(
              color:Theme.of(context).brightness==Brightness.dark?
               const Color(0xFF244C3A):const Color(0xFFE4F4EB),
              borderRadius:BorderRadius.circular(15)),
             child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              WaffraText(waffraIsEnglish?'Income':'الدخل',
               style:TextStyle(color:Theme.of(context).brightness==Brightness.dark?const Color(0xFFA8E8C7):const Color(0xFF075B43),fontWeight:FontWeight.bold)),
              const SizedBox(height:5),
              FittedBox(fit:BoxFit.scaleDown,child:WaffraCurrencyAmount(
               sum(visible.where((e)=>e.income),true),fontSize:18,
               color:Theme.of(context).brightness==Brightness.dark?const Color(0xFFA8E8C7):const Color(0xFF075B43))),
             ]))),
            const SizedBox(width:9),
            Expanded(child:Container(
             padding:const EdgeInsets.all(12),
             decoration:BoxDecoration(
              color:Theme.of(context).brightness==Brightness.dark?
               const Color(0xFF49302C):const Color(0xFFFCECE8),
              borderRadius:BorderRadius.circular(15)),
             child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              WaffraText(waffraIsEnglish?'Expenses':'المصروفات',
               style:TextStyle(color:Theme.of(context).brightness==Brightness.dark?const Color(0xFFFFBAB0):const Color(0xFFB34E3C),fontWeight:FontWeight.bold)),
              const SizedBox(height:5),
              FittedBox(fit:BoxFit.scaleDown,child:WaffraCurrencyAmount(
               sum(visible.where((e)=>!e.income),false),fontSize:18,
               color:Theme.of(context).brightness==Brightness.dark?const Color(0xFFFFBAB0):const Color(0xFFB34E3C))),
             ]))),
           ]),
           const SizedBox(height:10),
           Row(children:['الكل','الدخل','المصروفات'].map((choice)=>
            Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),
             child:ChoiceChip(
              label:Center(child:WaffraText(waffraIsEnglish?
               (choice=='الكل'?'All':choice=='الدخل'?'Income':'Expenses'):choice,
               style:TextStyle(fontSize:12,color:typeFilter==choice?Colors.white:null))),
              selected:typeFilter==choice,
              selectedColor:emerald,
              showCheckmark:false,
              onSelected:(_)=>setState((){
               typeFilter=choice;categoryFilter='الكل';
              }),
             )))).toList()),
           const SizedBox(height:7),
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

 Widget nextMonthForecast(){
  final now=DateTime.now();
  final months=List.generate(3,(i)=>DateTime(now.year,now.month-i));
  final used=months.where((m)=>entries.any((e)=>e.date.year==m.year&&e.date.month==m.month)).toList();
  final history=entries.where((e)=>used.any((m)=>m.year==e.date.year&&m.month==e.date.month)).toList();
  final divisor=max(1,used.length);
  final nextIncome=sum(history,true)/divisor,nextExpenses=sum(history,false)/divisor;
  final current=entries.where((e)=>e.date.year==now.year&&e.date.month==now.month).toList();
  final thisIncome=sum(current,true),thisExpenses=sum(current,false);
  final next=DateTime(now.year,now.month+1);
  final categoryAmounts=<String,double>{};
  for(final e in history.where((e)=>!e.income)){
   categoryAmounts[e.category]=(categoryAmounts[e.category]??0)+e.amount/divisor;
  }
  final ranked=categoryAmounts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final top=ranked.take(5).toList();
  final chosen=top.any((e)=>e.key==forecastCategory)?forecastCategory:(top.isEmpty?null:top.first.key);
  final saving=(categoryAmounts[chosen]??0)*forecastReduction/100;
  String compare(double future,double previous){
   if(previous<=0)return waffraIsEnglish?'Not enough data':'بيانات المقارنة غير كافية';
   final p=(future-previous)/previous*100;
   return '${p>=0?'+':''}${p.toStringAsFixed(1)}%';
  }
  Widget tile(String label,double amount,Color color,IconData icon,String delta)=>Expanded(
   child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
    borderRadius:BorderRadius.circular(17),border:Border.all(color:color.withValues(alpha:.6)),
    color:color.withValues(alpha:.10)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Icon(icon,color:color),const SizedBox(height:7),
     WaffraText(label,style:const TextStyle(fontSize:12)),
     FittedBox(fit:BoxFit.scaleDown,child:WaffraText(cash(amount),
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),
     WaffraText(delta,style:const TextStyle(fontSize:11)),
    ])));
  return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
   child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[const Icon(Icons.auto_awesome,color:emerald),
     const SizedBox(width:8),Expanded(child:WaffraText(waffraIsEnglish?
      'Your smart financial forecast':'توقعاتك المالية الذكية',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)))]),
    const SizedBox(height:6),
    WaffraText(waffraIsEnglish?'Next month: ${next.month}/${next.year}':'الشهر القادم: ${next.month}/${next.year}',
     style:const TextStyle(fontSize:12)),
    const SizedBox(height:12),
    Row(children:[
     tile(waffraIsEnglish?'Expected income':'الدخل المتوقع',nextIncome,emerald,Icons.south_west,compare(nextIncome,thisIncome)),
     const SizedBox(width:8),
     tile(waffraIsEnglish?'Expected expenses':'المصروفات المتوقعة',nextExpenses,Colors.deepOrange,Icons.north_east,compare(nextExpenses,thisExpenses)),
    ]),
    const SizedBox(height:10),
    Row(children:[const Icon(Icons.account_balance_wallet_outlined,color:emerald),
     const SizedBox(width:8),Expanded(child:WaffraText(waffraIsEnglish?'Expected balance':'الرصيد المتوقع')),
     WaffraText(cash(sum(entries,true)-sum(entries,false)+nextIncome-nextExpenses),
      style:const TextStyle(fontWeight:FontWeight.bold))]),
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Current month vs forecast':'مقارنة الشهر الحالي بالشهر القادم',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    FinanceChart(points:[
     ChartPoint(waffraIsEnglish?'Current':'الحالي',thisIncome,thisExpenses),
     ChartPoint(waffraIsEnglish?'Forecast':'المتوقع',nextIncome,nextExpenses),
    ]),
    const SizedBox(height:14),
    WaffraText(waffraIsEnglish?'Forecast by category':'توقعات المصروفات حسب الأقسام',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    if(top.isEmpty)Padding(padding:const EdgeInsets.all(12),
     child:WaffraText(waffraIsEnglish?'Record transactions to see forecasts.':'سجل معاملات لعرض التوقعات.')),
    ...top.map((item)=>Padding(padding:const EdgeInsets.only(top:8),child:Row(children:[
     Expanded(child:WaffraText(item.key)),WaffraText(cash(item.value)),
     const SizedBox(width:8),WaffraText(nextExpenses>0?
      '${(item.value/nextExpenses*100).toStringAsFixed(0)}%':'0%',
      style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
    ]))),
    if(chosen!=null)...[
     const SizedBox(height:15),
     Row(children:[const Icon(Icons.tune,color:emerald),const SizedBox(width:8),
      WaffraText(waffraIsEnglish?'What if?':'ماذا لو؟',
       style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))]),
     DropdownButtonFormField<String>(initialValue:chosen,
      decoration:InputDecoration(labelText:waffraIsEnglish?'Reduce category expenses':'تقليل مصروفات قسم'),
      items:top.map((e)=>DropdownMenuItem(value:e.key,child:WaffraText(e.key))).toList(),
      onChanged:(v)=>setState((){forecastCategory=v;forecastReduction=20;})),
     Row(children:[Expanded(child:Slider(value:forecastReduction.toDouble(),min:0,max:50,divisions:10,
      onChanged:(v)=>setState(()=>forecastReduction=v.round()))),WaffraText('${forecastReduction}%')]),
     WaffraText(waffraIsEnglish?'Adjusted expenses: ${cash(nextExpenses-saving)} • Save ${cash(saving)}':
      'المصروفات بعد التخفيض: ${cash(nextExpenses-saving)} • التوفير ${cash(saving)}',
      style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
    ],
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Estimates use up to 3 months of locally recorded transactions. Actual results may differ.':
     'تقديرات من معاملات آخر 3 أشهر المسجلة محليًا، وقد تختلف النتائج الفعلية.',
     style:const TextStyle(fontSize:11)),
   ])));
 }


 Future<void> showAiAnalysis()async {
  final now=DateTime.now();
  final recent=entries.where((e)=>e.date.isAfter(now.subtract(const Duration(days:90)))&&!e.date.isAfter(now)).toList();
  // A clear next step is more helpful than displaying empty charts.
  if(recent.isEmpty){
   if(!mounted)return;
   final add=await showWaffraDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:Row(children:[
     const Icon(Icons.insights_rounded,color:emerald,size:25),
     const SizedBox(width:8),
     Expanded(child:WaffraText(
      waffraIsEnglish?'No transactions to analyze yet':'لا توجد معاملات لتحليلها بعد',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
    ]),
    content:WaffraText(waffraIsEnglish?
     'Add an income or expense transaction first, then Waffra can show you your financial insights.':
     'أضف أول عملية دخل أو مصروف، وبعدها تقدر تشوف تحليلك المالي وتتابع مصروفاتك بوضوح.',
     textAlign:TextAlign.start),
    actions:[
     TextButton(onPressed:()=>Navigator.of(ctx).pop(false),
      child:WaffraText(waffraIsEnglish?'Later':'لاحقًا')),
     FilledButton.icon(onPressed:()=>Navigator.of(ctx).pop(true),
      icon:const Icon(Icons.add_circle_outline),
      label:WaffraText(waffraIsEnglish?'Add transaction':'إضافة معاملة')),
    ],
   ));
   if(add==true&&mounted)await entrySheet();
   return;
  }
  final income=sum(recent,true),spending=sum(recent,false);
  final hasEnoughData=recent.length>=3&&income>0;
  final ratio=income>0?(income-spending)/income:0.0;
  final score=hasEnoughData?((ratio+1)*50).clamp(0.0,100.0).round():null;
  final biggest=<String,double>{};
  for(final e in recent.where((e)=>!e.income)){
   biggest[e.category]=(biggest[e.category]??0)+e.amount;
  }
  final top=biggest.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final monthStart=DateTime(now.year,now.month);
  final priorStart=DateTime(now.year,now.month-1);
  final currentExpense=sum(entries.where((e)=>!e.income&&!e.date.isBefore(monthStart)&&!e.date.isAfter(now)),false);
  final priorExpense=sum(entries.where((e)=>!e.income&&!e.date.isBefore(priorStart)&&e.date.isBefore(monthStart)),false);
  final hasPrior=entries.any((e)=>!e.date.isBefore(priorStart)&&e.date.isBefore(monthStart));
  final thisMonthCount=entries.where((e)=>!e.date.isBefore(monthStart)&&!e.date.isAfter(now)).length;
  final monthDays=DateTime(now.year,now.month+1,0).day;
  final upcoming=recurring.where((r)=>r.active&&!r.income&&r.day>now.day&&r.day<=monthDays).fold<double>(0,(v,r)=>v+r.amount);
  final forecast=now.day>=5&&thisMonthCount>=3?(currentExpense/now.day*monthDays+upcoming):null;
  final weeklySpend=List<double>.generate(4,(i){
   final from=now.subtract(Duration(days:(4-i)*7));
   final to=now.subtract(Duration(days:(3-i)*7));
   return sum(recent.where((e)=>!e.income&&!e.date.isBefore(from)&&e.date.isBefore(to)),false);
  });
  if(!mounted)return;
  // Blur the underlying screen while the animated analysis indicator runs.
  // Keep the loader visible long enough to convey progress; calculations are local.
  if(!mounted)return;
  await showWaffraDialog<void>(
   context:context,barrierDismissible:false,barrierColor:Colors.transparent,
   builder:(ctx){
    Future<void>.delayed(waffraMotion(1500),(){if(ctx.mounted)Navigator.of(ctx).pop();});
    return BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:9,sigmaY:9),
     child:Center(child:Material(color:Colors.transparent,child:Container(
      width:MediaQuery.of(ctx).size.width*.83,
      padding:const EdgeInsets.symmetric(horizontal:24,vertical:36),
      decoration:BoxDecoration(color:Theme.of(ctx).cardColor,
       borderRadius:BorderRadius.circular(28),
       border:Border.fromBorderSide(waffraDialogOutline(Theme.of(ctx).brightness))),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       SizedBox(width:104,height:104,child:Stack(alignment:Alignment.center,children:[
        const SizedBox.expand(child:CircularProgressIndicator(strokeWidth:8,color:emerald,
         backgroundColor:Color(0xFFD9F1E5))),
        const Icon(Icons.bar_chart_rounded,color:emerald,size:44),
       ])),
       const SizedBox(height:22),
       WaffraText(waffraIsEnglish?'Analyzing your finances...':'يتم الآن تحليل بياناتك المالية',
        style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
       const SizedBox(height:10),
       WaffraText(waffraIsEnglish?'Reviewing the last 90 days of transactions':
        'جاري مراجعة معاملات آخر 90 يوم...',textAlign:TextAlign.center),
      ]),
     ))));
   },
  );
  if(!mounted)return;
  await showGeneralDialog<void>(
   context:context,
   barrierDismissible:true,
   barrierLabel:waffraIsEnglish?'Close analysis':'إغلاق التحليل',
   barrierColor:Colors.black.withValues(alpha:.24),
   transitionDuration:waffraMotion(300),
   transitionBuilder:(ctx,animation,secondary,child)=>BackdropFilter(
    filter:ui.ImageFilter.blur(sigmaX:7*animation.value,sigmaY:7*animation.value),
    child:SlideTransition(
     position:Tween<Offset>(begin:const Offset(0,1),end:Offset.zero)
      .animate(CurvedAnimation(parent:animation,curve:Curves.easeOutCubic)),
     child:child)),
   pageBuilder:(ctx,animation,secondary){

   final deficit=spending-income;
   final accent=score==null?Colors.grey:score<45?Colors.red:score<70?Colors.orange:emerald;
   final periods=List.generate(3,(i){
    final from=now.subtract(Duration(days:(3-i)*30));
    final to=now.subtract(Duration(days:(2-i)*30));
    final items=recent.where((e)=>!e.date.isBefore(from)&&e.date.isBefore(to));
    return (sum(items,true),sum(items,false));
   });
   final highest=periods.fold<double>(1,(v,p)=>max(v,max(p.$1,p.$2)));
   return Align(alignment:Alignment.bottomCenter,child:FractionallySizedBox(
    heightFactor:.90,
    child:Material(
     color:Theme.of(ctx).scaffoldBackgroundColor,
     clipBehavior:Clip.antiAlias,
     shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
     child:SafeArea(top:false,child:Column(children:[
      const SizedBox(height:12),
      Center(child:Container(width:48,height:5,decoration:BoxDecoration(
       color:emerald.withValues(alpha:.28),borderRadius:BorderRadius.circular(12)))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),child:Row(children:[
       Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(
        color:emerald.withValues(alpha:.1),borderRadius:BorderRadius.circular(14)),
        child:const Icon(Icons.insights_rounded,color:emerald)),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'Financial insights':'التحليل المالي التفصيلي',
         style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        WaffraText(waffraIsEnglish?'Your last 90 days at a glance':'نظرة شاملة على آخر 90 يوم',
         style:const TextStyle(fontSize:12)),
       ])),
       IconButton(tooltip:waffraIsEnglish?'Close':'إغلاق',icon:const Icon(Icons.close_rounded),
        onPressed:()=>Navigator.of(ctx).pop()),
      ])),
      const Divider(height:1),
      Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
     Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
      color:Theme.of(ctx).cardColor,
      border:Border.all(color:emerald.withValues(alpha:.18)),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:14,offset:const Offset(0,5))],
      borderRadius:BorderRadius.circular(22)),
      child:Column(children:[
       WaffraText(waffraIsEnglish?'Income & expense balance indicator':'مؤشر توازن الدخل والمصروفات',
        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17),textAlign:TextAlign.center),
       const SizedBox(height:12),
       WaffraText(score==null?'— / 100':'$score / 100',
        style:TextStyle(color:accent,fontWeight:FontWeight.bold,fontSize:34)),
       const SizedBox(height:10),
       LinearProgressIndicator(value:(score??0)/100,minHeight:9,color:accent,
        borderRadius:BorderRadius.circular(10)),
       const SizedBox(height:10),
       WaffraText(score==null?(waffraIsEnglish?'Not enough data':'البيانات غير كافية'):
        deficit>0?(waffraIsEnglish?'Expenses exceed income. Review your spending.':
         'مصروفاتك أعلى من دخلك. راجع مصروفاتك لإعادة التوازن.'):
        (waffraIsEnglish?'Keep tracking your spending to maintain balance.':
         'واصل متابعة مصروفاتك للحفاظ على التوازن.'),
        textAlign:TextAlign.center),
       const SizedBox(height:6),
       WaffraText(waffraIsEnglish?'Indicative cash-flow measure, not a credit score.':
        'مؤشر إرشادي مبني على العمليات المسجلة، وليس تصنيفًا ائتمانيًا.',
        style:const TextStyle(fontSize:11),textAlign:TextAlign.center),
      ])),
     const SizedBox(height:22),
     WaffraText(waffraIsEnglish?'Last 90 days':'ملخص آخر 90 يوم',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     Wrap(spacing:8,runSpacing:8,children:[
      _analysisStat(waffraIsEnglish?'Income':'الدخل',income,emerald),
      _analysisStat(waffraIsEnglish?'Expenses':'المصروفات',spending,Colors.deepOrange),
      _analysisStat(deficit>0?(waffraIsEnglish?'Deficit':'العجز'):(waffraIsEnglish?'Surplus':'الفائض'),
       deficit.abs(),deficit>0?Colors.red:emerald),
     ]),
     const SizedBox(height:24),
     Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraText(waffraIsEnglish?'Compared with last month':'مقارنة بالشهر السابق',
        style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
       const SizedBox(height:8),
       WaffraText(!hasPrior?
        (waffraIsEnglish?'Not enough previous-month data for comparison.':'لا توجد بيانات كافية للشهر السابق للمقارنة.'):
        priorExpense==0?(waffraIsEnglish?'No expenses last month.':'لم يتم تسجيل مصروفات في الشهر السابق.'):
        (waffraIsEnglish?'Expenses ${currentExpense<=priorExpense?'decreased':'increased'} by ${((currentExpense-priorExpense).abs()/priorExpense*100).toStringAsFixed(1)}%.':
         'المصروفات ${currentExpense<=priorExpense?'انخفضت':'ارتفعت'} بنسبة ${((currentExpense-priorExpense).abs()/priorExpense*100).toStringAsFixed(1)}%.')),
       const SizedBox(height:12),
       WaffraText(waffraIsEnglish?'Estimated month-end spending':'توقع المصروفات بنهاية الشهر',
        style:const TextStyle(fontWeight:FontWeight.bold)),
       WaffraText(forecast==null?
        (waffraIsEnglish?'At least three transactions and five elapsed days are needed.':'يلزم تسجيل ثلاث معاملات ومرور خمسة أيام على الأقل من الشهر.'):
        (waffraIsEnglish?'Approximately ${cash(forecast)} at the current pace.':
         'حوالي ${cash(forecast)} إذا استمر معدل الإنفاق الحالي.')),
       WaffraText(waffraIsEnglish?'Estimate from recorded transactions and upcoming recurring expenses, not a guarantee.':
        'تقدير مبني على معاملاتك والعمليات المتكررة القادمة، وليس مبلغًا مؤكدًا.',
        style:const TextStyle(fontSize:11)),
      ]))),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Income vs expenses':'اتجاه الدخل والمصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     ...List.generate(3,(i)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Row(children:[
       SizedBox(width:65,child:WaffraText(waffraIsEnglish?'Period ${i+1}':'فترة ${i+1}')),
       Expanded(child:Column(children:[
        LinearProgressIndicator(value:periods[i].$1/highest,minHeight:10,color:emerald,
         backgroundColor:emerald.withValues(alpha:.08)),
        const SizedBox(height:5),
        LinearProgressIndicator(value:periods[i].$2/highest,minHeight:10,color:Colors.deepOrange,
         backgroundColor:Colors.deepOrange.withValues(alpha:.08)),
       ])),
      ]))),
     Row(children:[
      const Icon(Icons.circle,color:emerald,size:12),const SizedBox(width:5),
      WaffraText(waffraIsEnglish?'Income':'الدخل'),
      const SizedBox(width:15),const Icon(Icons.circle,color:Colors.deepOrange,size:12),
      const SizedBox(width:5),WaffraText(waffraIsEnglish?'Expenses':'المصروفات'),
     ]),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Weekly spending trend':'اتجاه المصروفات الأسبوعية',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:8),
     Card(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(height:170,
      child:LineChart(LineChartData(minY:0,
       gridData:const FlGridData(show:true,drawVerticalLine:false),
       titlesData:const FlTitlesData(show:false),borderData:FlBorderData(show:false),
       lineBarsData:[LineChartBarData(
        spots:List.generate(weeklySpend.length,(i)=>FlSpot(i.toDouble(),weeklySpend[i])),
        isCurved:true,color:emerald,barWidth:3,dotData:const FlDotData(show:true),
        belowBarData:BarAreaData(show:true,color:emerald.withValues(alpha:.10))),
       ]))))),
     const SizedBox(height:10),
     WaffraText(waffraIsEnglish?'Four weeks from oldest to newest.':'آخر أربعة أسابيع من الأقدم للأحدث.',style:const TextStyle(fontSize:12)),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Top spending categories':'أعلى أقسام المصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:10),
     if(top.isEmpty)WaffraText(waffraIsEnglish?'No expenses recorded.':'لا توجد مصروفات مسجلة.'),
     ...top.take(5).map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[Expanded(child:WaffraText(waffraTr(e.key))),
        WaffraText(cash(e.value),style:const TextStyle(fontWeight:FontWeight.bold))]),
       const SizedBox(height:5),
       LinearProgressIndicator(value:spending>0?e.value/spending:0,minHeight:7,
        color:Colors.deepOrange,borderRadius:BorderRadius.circular(8)),
      ]))),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Spending distribution chart':'الرسم البياني لتوزيع المصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     if(top.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),
      child:SizedBox(height:240,child:PieChart(PieChartData(
       centerSpaceRadius:40,
       sections:top.map((e){
        final c=categoryFor(e.key,false);
        return PieChartSectionData(value:e.value,color:Color(c.color),radius:77,
         title:'${(e.value/spending*100).toStringAsFixed(0)}%',
         titleStyle:const TextStyle(fontSize:12,color:Colors.white,fontWeight:FontWeight.bold));
       }).toList(),
      ))))),
     const SizedBox(height:16),
     OutlinedButton.icon(
      onPressed:recent.isEmpty?null:()=>exportEntriesPdf(recent,
       waffraIsEnglish?'Waffra analytics - Last 90 days':'تحليلات وفرة - آخر 90 يوم',
       analytics:true),
      icon:const Icon(Icons.picture_as_pdf_outlined),
      label:WaffraText(waffraIsEnglish?'Export analytics PDF':'تصدير التحليلات إلى PDF')),
     const SizedBox(height:24),
     ExpansionTile(leading:const Icon(Icons.info_outline,color:emerald),
      title:WaffraText(waffraIsEnglish?'Why this result?':'ليه النتيجة دي؟'),
      children:[Padding(padding:const EdgeInsets.all(14),
       child:WaffraText(waffraIsEnglish?
        'Based on ${recent.length} recorded transactions in 90 days. Income: ${cash(income)}, expenses: ${cash(spending)}. The score is indicative and is omitted when data is insufficient.':
        'اعتمدنا على ${recent.length} معاملة من آخر 90 يومًا. الدخل ${cash(income)} والمصروفات ${cash(spending)}. المؤشر إرشادي ولا يظهر بدون بيانات كافية.'))]),
     const SizedBox(height:20),
     WaffraText(waffraIsEnglish?'Tips for you':'نصائح مخصصة لك',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:10),
     ListTile(leading:const Icon(Icons.lightbulb_outline,color:emerald),
      title:WaffraText(deficit>0?
       (waffraIsEnglish?'Reduce optional spending to close the gap.':'قلّل المصروفات الاختيارية لتقليل العجز.'):
       (waffraIsEnglish?'Keep your expenses below your income.':'حافظ على مصروفات أقل من دخلك.'))),
     if(top.isNotEmpty)ListTile(leading:const Icon(Icons.category_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'Reduce spending on ${waffraTr(top.first.key)} by 15% to save roughly ${cash(top.first.value*.15)} over this period.':
       'تقليل مصروفات «${waffraTr(top.first.key)}» بنسبة 15% قد يوفر حوالي ${cash(top.first.value*.15)} خلال فترة التحليل.')),
     if(goals.isNotEmpty&&income>spending)ListTile(
      leading:const Icon(Icons.savings_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'You could allocate part of your surplus to ${goals.first.name}; nothing is moved automatically.':
       'ممكن تخصص جزءًا من الفائض لهدف «${goals.first.name}»، ولن نضيف أي مبالغ تلقائيًا.')),
     ListTile(leading:const Icon(Icons.track_changes_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Set monthly budgets for your categories.':
       'حدد ميزانية شهرية لكل قسم للتحكم في الإنفاق.')),
     const SizedBox(height:24),
    ])),
    ]))),
   ));
  });
 }
 Widget _analysisStat(String label,double value,Color color)=>Container(
  width:MediaQuery.of(context).size.width/3-18,
  padding:const EdgeInsets.symmetric(horizontal:7,vertical:15),
  decoration:BoxDecoration(color:color.withValues(alpha:.09),borderRadius:BorderRadius.circular(15)),
  child:Column(children:[
   WaffraText(label,style:const TextStyle(fontSize:12),textAlign:TextAlign.center),
   const SizedBox(height:7),
   FittedBox(fit:BoxFit.scaleDown,child:WaffraText(cash(value),
    style:TextStyle(color:color,fontWeight:FontWeight.bold,fontSize:15))),
  ]),
 );
 Widget analytics(){
  final data=analysisEntries,inc=sum(data,true),exp=sum(data,false);
  final years=<int>{DateTime.now().year,year,...entries.map((e)=>e.date.year)}.toList()..sort((a,b)=>b.compareTo(a));
  final points=period=='شهري'?List.generate(5,(i){
   final v=data.where((e)=>(e.date.day-1)~/7==i);
   return ChartPoint(waffraIsEnglish?'Week ${i+1}':'الأسبوع ${i+1}',sum(v,true),sum(v,false));
  }):List.generate(12,(i){
   final v=data.where((e)=>e.date.month==i+1);
   return ChartPoint(waffraIsEnglish?'Month ${i+1}':'شهر ${i+1}',sum(v,true),sum(v,false));
  });
  final breakdown=<String,double>{};
  for(final e in data.where((e)=>!e.income)){breakdown[e.category]=(breakdown[e.category]??0)+e.amount;}
  return ListView(padding:const EdgeInsets.all(16),children:[
   Row(children:[
    Expanded(child:WaffraText(waffraIsEnglish?'Your financial analytics':'تحليلاتك المالية',style:Theme.of(context).textTheme.titleLarge)),
   ]),
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
   nextMonthForecast(),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,waffraIncomeTone(context)),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
    const WaffraText('الدخل مقابل المصروفات',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:16),FinanceChart(points:points),
   ]))),
   const SizedBox(height:16),
   OutlinedButton.icon(onPressed:()=>exportEntriesPdf(data,'تحليلات وفرة - $period ${period=='شهري'?'$month/':''}$year',analytics:true),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const WaffraText('تصدير التحليلات إلى PDF')),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(16),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText(waffraIsEnglish?'Horizontal income and expense comparison':
      'مقارنة الدخل والمصروفات بأشرطة أفقية',
      style:const TextStyle(fontWeight:FontWeight.bold)),
     const SizedBox(height:6),
     WaffraText(waffraIsEnglish?'Bar length = amount in SAR.':
      'طول الشريط يوضح المبلغ بالريال.',
      style:const TextStyle(fontSize:11)),
     const SizedBox(height:13),
     Row(children:[
      Expanded(child:WaffraText(waffraIsEnglish?'Income':'الدخل')),
      WaffraText(cash(inc),style:TextStyle(fontWeight:FontWeight.bold,color:waffraIncomeTone(context))),
     ]),
     const SizedBox(height:6),
     LinearProgressIndicator(value:(inc/max(1.0,max(inc,exp))).clamp(0.0,1.0),
      minHeight:15,borderRadius:BorderRadius.circular(8),color:waffraIncomeTone(context)),
     const SizedBox(height:14),
     Row(children:[
      Expanded(child:WaffraText(waffraIsEnglish?'Expenses':'المصروفات')),
      WaffraText(cash(exp),style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.deepOrange)),
     ]),
     const SizedBox(height:6),
     LinearProgressIndicator(value:(exp/max(1.0,max(inc,exp))).clamp(0.0,1.0),
      minHeight:15,borderRadius:BorderRadius.circular(8),color:Colors.deepOrange),
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

 Future<BudgetCategory?> categoryDialog({BudgetCategory? initial,bool income=false,String? suggested,String parentId=''})async {
  final name=TextEditingController(text:initial?.displayName??suggested??'');
  final effectiveParentId=initial?.parentId??parentId;
  String fullName(){
   final text=name.text.trim();
   if(effectiveParentId.isEmpty)return text;
   final parent=categories.where((c)=>c.id==effectiveParentId).toList();
   return parent.isEmpty?text:'${parent.first.name} / $text';
  }
  final budget=TextEditingController(text:initial==null||initial.budget==0?'':formatWaffraMoney(initial.budget));
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];int alertPercent=initial?.alertPercent??80;
  bool attempted=false;
  final result=await showWaffraDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(initial!=null?'تعديل القسم':effectiveParentId.isNotEmpty?'قسم فرعي جديد':'قسم جديد'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Category name *':'اسم القسم *',
      errorText:attempted?(
       WaffraValidators.requiredText(name.text)!=null?waffraTextFieldError(name.text):
       WaffraValidators.uniqueCategory(fullName(),categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null?(waffraIsEnglish?'Category already exists':'اسم القسم مستخدم بالفعل'):null):null)),
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
       errorText:attempted?waffraAmountFieldError(budget.text,required:false):null)),
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
      if(WaffraValidators.requiredText(n)!=null || WaffraValidators.uniqueCategory(fullName(),
       categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null ||
       WaffraValidators.positiveAmount(budget.text,required:false)!=null)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:fullName(),icon:icon,color:color,
       income:initial?.income??income,parentId:effectiveParentId,budget:budget.text.trim().isEmpty?0:(amountOf(budget.text)??0),alertPercent:alertPercent));
     },child:const WaffraText('حفظ')),
    ])));
  disposeLater([name,budget]);return result;
 }
 Future<void> chooseCategoryLevel({required bool income})async{
  final parents=categories.where((c)=>!c.isSubcategory&&c.income==income).toList();
  final choice=await showWaffraDialog<String>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(income
     ?(waffraIsEnglish?'Add income category':'إضافة قسم دخل')
     :(waffraIsEnglish?'Add expense category':'إضافة قسم مصروفات')),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     ListTile(leading:const Icon(Icons.create_new_folder_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'New main category':'إضافة قسم رئيسي'),
      onTap:()=>Navigator.pop(ctx,'main')),
     ListTile(leading:const Icon(Icons.account_tree_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'New subcategory':'إضافة قسم فرعي'),
      onTap:()=>Navigator.pop(ctx,'sub')),
    ]),
   ));
  if(!mounted||choice==null)return;
  if(choice=='main'){await addCategory(income:income);return;}
  if(parents.isEmpty){
   snack(context,waffraIsEnglish?'Create a main category first':'يجب إضافة قسم رئيسي أولًا');
   return;
  }
  final parentId=await showWaffraDialog<String>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose main category':'اختر القسم الرئيسي'),
    content:SizedBox(width:double.maxFinite,height:min(360.0,MediaQuery.sizeOf(ctx).height*.48),
     child:ListView.builder(itemCount:parents.length,itemBuilder:(ctx,index){
      final parent=parents[index];
      return ListTile(
       leading:Icon(categoryIcon(parent.icon),color:Color(parent.color)),
       title:WaffraText(parent.name),
       onTap:()=>Navigator.pop(ctx,parent.id));
     })),
   ));
  if(!mounted||parentId==null)return;
  await addCategory(income:income,parentId:parentId);
 }
 Future<void> addCategory({bool income=false,String parentId=''})async {
  final c=await categoryDialog(income:income,parentId:parentId);
  if(c==null||!mounted)return;
  if(categories.any((x)=>x.income==c.income&&x.name.trim()==c.name.trim())){
   snack(context,'القسم موجود بالفعل');return;
  }
  setState(()=>categories.add(c));await persist();
 }
 Future<void> updateCategory(BudgetCategory c)async {
  final revised=await categoryDialog(initial:c);
  if(revised==null||!mounted)return;
  if(categories.any((x)=>x.id!=c.id&&x.income==c.income&&x.name==revised.name))return;
  final renames=<String,String>{c.name:revised.name};
  if(!c.isSubcategory&&c.name!=revised.name){
   for(final child in categories.where((x)=>x.parentId==c.id)){
    renames[child.name]='${revised.name} / ${child.displayName}';
   }
  }
  setState((){
   final i=categories.indexWhere((x)=>x.id==c.id);
   if(i>=0)categories[i]=revised;
   for(var j=0;j<categories.length;j++){
    final child=categories[j];
    if(child.parentId==c.id&&renames.containsKey(child.name)){
     categories[j]=child.copy(name:renames[child.name]);
    }
   }
   for(var j=0;j<entries.length;j++){
    final old=entries[j];
    final renamed=renames[old.category];
    if(renamed!=null&&old.income==c.income){
     entries[j]=MoneyEntry(id:old.id,title:old.title,category:renamed,
      amount:old.amount,income:old.income,date:old.date,receiptPath:old.receiptPath);
    }
   }
   for(var j=0;j<recurring.length;j++){
    final old=recurring[j];
    final renamed=renames[old.category];
    if(renamed!=null&&old.income==c.income){
     recurring[j]=RecurringBill(id:old.id,title:old.title,category:renamed,
      amount:old.amount,income:old.income,day:old.day,active:old.active);
    }
   }
  });
  await persist();
 }
 Future<void> deleteCategory(BudgetCategory c)async {
  final children=categories.where((item)=>item.parentId==c.id).toList();
  if(children.isNotEmpty){
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Delete subcategories first':'احذف الأقسام الفرعية أولاً'),
    content:WaffraText(waffraIsEnglish?'This category has ${children.length} subcategories. Delete or move them first to protect your categorization.':'القسم يحتوي على ${children.length} قسم فرعي. احذف الأقسام الفرعية أولاً للحفاظ على تصنيف المعاملات.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   return;
  }
  final linkedEntries=entries.where((e)=>e.category==c.name&&e.income==c.income).length;
  final linkedRecurring=recurring.where((e)=>e.category==c.name&&e.income==c.income).length;
  if(linkedEntries>0||linkedRecurring>0){
   if(!mounted)return;
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
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
      Navigator.pop(ctx);setState((){tab=3;goalsOpened=false;addFabExpanded=false;});
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
  if(mounted)snackSuccess(context,waffraIsEnglish?'Category moved to Recently Deleted for 30 days':'تم نقل القسم للمحذوفات لمدة 30 يومًا');
 }
 Future<void> showCategoryTrash()async {
  final before=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  if(before!=deletedCategories.length)await persist();
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(dialogCtx)=>StatefulBuilder(
   builder:(dialogCtx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Recently deleted categories':'الأقسام المحذوفة'),
    content:SizedBox(width:double.maxFinite,height:waffraDeletedListHeight(dialogCtx,deletedCategories.length),
     child:deletedCategories.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted categories':'لا توجد أقسام محذوفة'))
      :ListView(children:deletedCategories.map((item){
        final original=BudgetCategory.fromJson(Map<String,dynamic>.from(item['category'] as Map));
        final deletedAt=DateTime.parse(item['deletedAt'] as String);
        final daysLeft=max(0,(deletedAt.add(const Duration(days:30))
         .difference(DateTime.now()).inHours/24).ceil());
        return waffraDeletedItemCard(
         context:dialogCtx,
         icon:categoryIcon(original.icon),
         iconColor:Color(original.color),
         title:original.name,
         subtitle:waffraIsEnglish
          ?'${original.income?'Income':'Expense'} • $daysLeft days remaining'
          :'${original.income?'دخل':'مصروفات'} • متبقي $daysLeft يوم',
         onRestore:()async{
             if(categories.any((c)=>c.name==original.name&&c.income==original.income)){
              snack(dialogCtx,waffraIsEnglish?'A category with this name already exists':'يوجد قسم نشط بنفس الاسم بالفعل');return;
             }
             BudgetCategory? restoreParent;
             if(original.isSubcategory&&
              !categories.any((c)=>c.id==original.parentId)){
              final deletedParent=deletedCategories.where((record){
               final raw=record['category'];
               return raw is Map&&raw['id']==original.parentId;
              }).toList();
              if(deletedParent.isEmpty){
               snack(dialogCtx,waffraIsEnglish
                ?'Restore the main category first. It is no longer in Recently Deleted.'
                :'يجب استرجاع القسم الرئيسي أولًا؛ لأنه غير موجود في الأقسام المحذوفة.');
               return;
              }
              restoreParent=BudgetCategory.fromJson(
               Map<String,dynamic>.from(deletedParent.first['category'] as Map));
              if(categories.any((c)=>c.income==restoreParent!.income&&c.name==restoreParent.name)){
               snack(dialogCtx,waffraIsEnglish
                ?'Cannot restore the parent: another category has the same name.'
                :'لا يمكن استرجاع القسم الرئيسي لوجود قسم آخر بنفس الاسم.');
               return;
              }
              final approved=await showWaffraDialog<bool>(context:dialogCtx,
               builder:(confirmCtx)=>AlertDialog(
                title:WaffraText(waffraIsEnglish?'Restore main category too?':'استرجاع القسم الرئيسي أيضًا؟'),
                content:WaffraText(waffraIsEnglish
                 ?'Restoring this subcategory also restores its deleted main category «${restoreParent!.name}». Both budgets will reset to zero. Continue?'
                 :'استرجاع هذا القسم الفرعي سيؤدي أيضًا إلى استرجاع القسم الرئيسي «${restoreParent!.name}». ستعود الميزانيات بقيمة صفر. هل تريد المتابعة؟'),
                actions:[
                 TextButton(onPressed:()=>Navigator.pop(confirmCtx,false),
                  child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
                 FilledButton(onPressed:()=>Navigator.pop(confirmCtx,true),
                  child:WaffraText(waffraIsEnglish?'Restore both':'استرجاع الاثنين')),
                ]));
              if(approved!=true||!dialogCtx.mounted)return;
             }
             final restored=original.copy(budget:0);
             setState((){
              if(restoreParent!=null){
               categories.add(restoreParent!.copy(budget:0));
               deletedCategories.removeWhere((record){
                final raw=record['category'];
                return raw is Map&&raw['id']==restoreParent!.id;
               });
              }
              categories.add(restored);
              deletedCategories.remove(item);
             });
             await persist();
             if(!dialogCtx.mounted)return;
             Navigator.pop(dialogCtx);
             if(mounted)snackSuccess(context,waffraIsEnglish
              ?'Category restored with a zero budget. Past linked transactions remain in the financial history unchanged.'
              :'تم استرجاع القسم بميزانية صفر، وجميع المعاملات القديمة المرتبطة به محفوظة في السجل المالي دون تغيير.');
            },
         onDeleteForever:()async{
             final yes=await confirmDeletion(
              waffraIsEnglish?'Permanently delete category?':'حذف القسم نهائيًا',
              waffraIsEnglish?'Delete «${original.name}» forever? You cannot restore it.'
               :'هل تريد حذف القسم «${original.name}» نهائيًا؟ لا يمكن استرجاعه بعد ذلك.');
             if(yes==true&&mounted){
              setState(()=>deletedCategories.remove(item));
              refresh((){});
              await persist();
             }
            },
        );
       }).toList())),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogCtx),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
 Widget categoriesPage()=>categoriesPageV2();
 Widget _recurringBenefit(String label,IconData icon)=>Container(
  padding:const EdgeInsets.symmetric(horizontal:6,vertical:14),
  decoration:BoxDecoration(color:emerald.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   Icon(icon,color:emerald,size:25),const SizedBox(height:9),
   WaffraText(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
  ]));
 Widget _summaryBox(String heading,String number,IconData icon,Color color)=>Container(
  padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(
   color:Theme.of(context).cardColor,
   borderRadius:BorderRadius.circular(18),
   border:Border.all(color:color.withValues(alpha:.16))),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[Icon(icon,color:color,size:20),const SizedBox(width:7),
    Expanded(child:WaffraText(heading,style:const TextStyle(fontSize:12)))]),
   const SizedBox(height:8),
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
  if(!mounted){name.dispose();target.dispose();return;}
  final customGoals=prefs.getStringList('waffra_custom_goals_v1')??<String>[];
  final defaults=waffraDefaultGoalNames(waffraIsEnglish);
  final allDefaultNames={
   ...waffraDefaultGoalNames(false).map(waffraNormalizeGoal),
   ...waffraDefaultGoalNames(true).map(waffraNormalizeGoal),
  };
  final suggested=<String>[];
  final seen=<String>{};
  for(final entry in [...defaults,...customGoals]){
   final key=waffraNormalizeGoal(entry);
   if(key.isNotEmpty&&seen.add(key))suggested.add(entry.trim());
  }
  const otherGoal='__other_goal__';
  String selectedGoal='';
  bool attempted=false;
  String? validateGoalName(){
   final issue=waffraGoalNameIssue(name.text,goals.map((g)=>g.name));
   if(issue=='required'||issue=='too_long')return waffraTextFieldError(name.text);
   if(issue=='duplicate')return waffraIsEnglish?'A goal with this name already exists':'يوجد هدف بنفس الاسم بالفعل';
   if(selectedGoal==otherGoal&&suggested.any(
    (v)=>waffraNormalizeGoal(v)==waffraNormalizeGoal(name.text))){
    return waffraIsEnglish?'Already suggested. Please choose it from the list.':'هذا الهدف ضمن الاقتراحات. اختره من القائمة.';
   }
   return null;
  }
  final g=await showWaffraDialog<SavingGoal>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,updateGoal)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Add savings goal':'إضافة هدف ادخار'),
    scrollable:true,
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     InkWell(
      borderRadius:BorderRadius.circular(14),
      onTap:()async{
       final picked=await showWaffraDialog<String>(context:ctx,
        builder:(pickCtx){
         String query='';
         return StatefulBuilder(builder:(pickCtx,refresh){
          final search=waffraNormalizeGoal(query);
          final matches=suggested.where(
           (item)=>search.isEmpty||waffraNormalizeGoal(item).contains(search)).toList();
          return AlertDialog(
           title:WaffraText(waffraIsEnglish?'Choose savings goal':'اختر هدف الادخار'),
           content:SizedBox(
            width:double.maxFinite,
            height:min(450.0,MediaQuery.sizeOf(pickCtx).height*.60),
            child:Column(children:[
             TextField(autofocus:true,onChanged:(value)=>refresh(()=>query=value),
              decoration:InputDecoration(
               prefixIcon:const Icon(Icons.search_rounded),
               hintText:waffraIsEnglish?'Search among suggested goals…':'ابحث بين الأهداف المقترحة…',
               border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))),
             const SizedBox(height:8),
             ListTile(
              dense:true,
              leading:const Icon(Icons.add_circle_outline_rounded,color:emerald),
              title:WaffraText(waffraIsEnglish?'Other goal (custom name)':'هدف آخر (اسم مخصص)'),
              onTap:()=>Navigator.pop(pickCtx,otherGoal)),
             const Divider(height:10),
             Expanded(child:matches.isEmpty
              ?Center(child:WaffraText(waffraIsEnglish?'No matching goals':'لا توجد أهداف مطابقة'))
              :ListView.builder(itemCount:matches.length,itemBuilder:(pickCtx,index)=>
               ListTile(
                dense:true,
                title:WaffraText(matches[index],maxLines:2),
                onTap:()=>Navigator.pop(pickCtx,matches[index])))),
            ]),
           ),
          );
         });
        });
       if(picked!=null&&ctx.mounted)updateGoal((){
        selectedGoal=picked;
        name.text=picked==otherGoal?'':picked;
       });
      },
      child:InputDecorator(
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Savings goal *':'اختر هدف الادخار *',
        errorText:attempted&&selectedGoal.isEmpty?waffraRequiredFieldMessage:
         attempted&&selectedGoal!=otherGoal?validateGoalName():null,
        errorMaxLines:2,
        suffixIcon:const Icon(Icons.search_rounded),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
       child:Row(children:[
        Expanded(child:WaffraText(
         selectedGoal==otherGoal?(waffraIsEnglish?'Other goal':'هدف آخر'):
         selectedGoal.isEmpty?(waffraIsEnglish?'Select a goal':'اختر هدفًا'):selectedGoal,
         maxLines:2,
         style:TextStyle(fontSize:14,color:selectedGoal.isEmpty?Theme.of(ctx).hintColor:null))),
        const Icon(Icons.arrow_drop_down_rounded,size:20),
       ]),
      ),
     ),
     if(selectedGoal==otherGoal)...[
      const SizedBox(height:12),
      TextField(controller:name,textInputAction:TextInputAction.next,
       maxLength:100,onChanged:(_)=>updateGoal((){}),
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Other goal name *':'اسم الهدف الآخر *',
        hintText:waffraIsEnglish?'e.g. Home renovation':'مثال: تجديد المنزل',
        errorText:attempted?validateGoalName():null,
        errorMaxLines:2,
        border:const OutlineInputBorder())),
     ],
     const SizedBox(height:12),
     TextField(controller:target,
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter()],
      onChanged:(_)=>updateGoal((){}),
      decoration:InputDecoration(
       labelText:waffraIsEnglish?'Target amount *':'المبلغ المستهدف *',
       hintText:waffraIsEnglish?'e.g. 25000':'مثال: 25000',
       errorText:attempted?waffraAmountFieldError(target.text):null,
       border:const OutlineInputBorder())),
    ]),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:(){
      updateGoal(()=>attempted=true);
      final n=amountOf(target.text);
      if(selectedGoal.isEmpty||validateGoalName()!=null||
       WaffraValidators.positiveAmount(target.text)!=null||n==null)return;
      Navigator.pop(ctx,SavingGoal(id:newId(),name:name.text.trim(),target:n,saved:0));
     },child:WaffraText(waffraIsEnglish?'Add goal':'إضافة الهدف')),
    ],
   )));
  disposeLater([name,target]);
  if(g!=null&&mounted){
   if(selectedGoal==otherGoal){
    final key=waffraNormalizeGoal(g.name);
    if(!allDefaultNames.contains(key)&&!customGoals.any((entry)=>waffraNormalizeGoal(entry)==key)){
     await prefs.setStringList('waffra_custom_goals_v1',[...customGoals,g.name]);
    }
   }
   if(!mounted)return;
   setState(()=>goals.add(g));await persist();
   if(mounted)snackSuccess(context,
    waffraIsEnglish?'Savings goal added successfully':'تمت إضافة الهدف بنجاح');
  }
 }
 Future<void> fundGoal(SavingGoal g)async {
  final amount=TextEditingController();
  bool attempted=false;
  final n=await showWaffraDialog<double>(
   context:context,builder:(dialogCtx)=>StatefulBuilder(
    builder:(dialogCtx,update){
     final theme=Theme.of(dialogCtx);
     final dark=theme.brightness==Brightness.dark;
     final accent=dark?const Color(0xFF82E2B4):emerald;
     final currentProgress=g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0);
     void addQuickAmount(double increment){
      final current=amountOf(amount.text)??0;
      amount.text=formatWaffraMoney(current+increment);
      amount.selection=TextSelection.collapsed(offset:amount.text.length);
      update((){});
     }
     return AlertDialog(
      title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Add savings':'إضافة ادخار',
        style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
       const SizedBox(height:3),
       WaffraText(waffraIsEnglish?'To ${g.name}':'إلى هدف ${g.name}',
        maxLines:2,style:TextStyle(fontSize:14,color:theme.hintColor)),
      ]),
      content:SingleChildScrollView(child:Column(
       mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,
       children:[
        Container(
         padding:const EdgeInsets.symmetric(horizontal:13,vertical:14),
         decoration:BoxDecoration(
          color:accent.withValues(alpha:dark ? 0.12 : 0.06),
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color:accent.withValues(alpha:.14))),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
           CircleAvatar(radius:20,backgroundColor:accent.withValues(alpha:.15),
            child:Icon(goalIcon(g.name),color:accent,size:21)),
           const SizedBox(width:9),
           Expanded(child:WaffraText(g.name,maxLines:2,
            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14))),
          ]),
          const SizedBox(height:9),
          WaffraText(waffraIsEnglish
           ?'${formatWaffraMoney(g.saved)} of ${formatWaffraMoney(g.target)} SAR'
           :'${formatWaffraMoney(g.saved)} من ${formatWaffraMoney(g.target)} ريال',
           textAlign:TextAlign.center,style:const TextStyle(fontSize:13)),
          const SizedBox(height:9),
          LinearProgressIndicator(value:currentProgress,minHeight:8,
           color:accent,backgroundColor:accent.withValues(alpha:.14),
           borderRadius:BorderRadius.circular(12)),
          const SizedBox(height:7),
          WaffraText('${(currentProgress*100).round()}%',
           textAlign:TextAlign.start,
           style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:accent)),
         ])),
        const SizedBox(height:17),
        WaffraText(waffraIsEnglish?'Amount to add *':'المبلغ المراد إضافته *',
         style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
        const SizedBox(height:8),
        TextField(
         controller:amount,
         keyboardType:const TextInputType.numberWithOptions(decimal:true),
         inputFormatters:[const WaffraAmountFormatter()],
         onChanged:(_)=>update((){}),
         decoration:InputDecoration(
          hintText:'0.00',
          suffixText:waffraIsEnglish?'SAR':'ريال',
          errorText:attempted?waffraAmountFieldError(amount.text):null,
          errorMaxLines:2,
          enabledBorder:OutlineInputBorder(
           borderRadius:BorderRadius.circular(15),
           borderSide:BorderSide(color:accent,width:1.5)),
          focusedBorder:OutlineInputBorder(
           borderRadius:BorderRadius.circular(15),
           borderSide:BorderSide(color:accent,width:2)),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
         )),
        const SizedBox(height:10),
        Row(children:[
         for(final quick in [500.0,1000.0,2000.0])...[
          Expanded(child:TextButton(
           style:TextButton.styleFrom(
            backgroundColor:accent.withValues(alpha:.08),
            padding:const EdgeInsets.symmetric(vertical:10,horizontal:2),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
           onPressed:()=>addQuickAmount(quick),
           child:WaffraText('+${quick.toInt()}',
            style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:accent)))),
          if(quick!=2000.0)const SizedBox(width:7),
         ],
        ]),
        const SizedBox(height:13),
        Container(
         padding:const EdgeInsets.all(11),
         decoration:BoxDecoration(color:accent.withValues(alpha:.09),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          Icon(Icons.info_outline_rounded,size:19,color:accent),
          const SizedBox(width:8),
          Expanded(child:WaffraText(waffraIsEnglish
           ?'Savings are added to this goal only. Past transactions stay unchanged.'
           :'سيتم إضافة المبلغ إلى هذا الهدف فقط، ولن يؤثر على معاملاتك السابقة.',
           style:const TextStyle(fontSize:12))),
         ])),
       ],
      )),
      actionsPadding:const EdgeInsets.fromLTRB(16,0,16,16),
      actions:[SizedBox(width:double.infinity,
       child:Column(children:[
        SizedBox(width:double.infinity,child:FilledButton(
         onPressed:(){
          update(()=>attempted=true);
          if(waffraAmountFieldError(amount.text)!=null)return;
          final value=amountOf(amount.text);
          if(value==null||value<=0)return;
          Navigator.pop(dialogCtx,value);
         },
         child:WaffraText(waffraIsEnglish?'Add amount':'إضافة'))),
        const SizedBox(height:7),
        SizedBox(width:double.infinity,child:OutlinedButton(
         onPressed:()=>Navigator.pop(dialogCtx),
         child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))),
       ]))],
     );
    },
   ),
  );
  disposeLater([amount]);
  if(n!=null&&mounted){
   final achieved=g.saved<g.target&&g.saved+n>=g.target;
   setState((){
    final i=goals.indexWhere((x)=>x.id==g.id);
    if(i>=0)goals[i]=g.copy(saved:g.saved+n);
   });
   await persist();
   if(achieved&&mounted){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'🎉 Goal achieved!':'🎉 مبروك!'),
     content:WaffraText(waffraIsEnglish
      ?'You achieved your savings goal “${g.name}”!'
      :'تم تحقيق هدف الادخار «${g.name}» بنجاح!'),
     actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),
      child:WaffraText(waffraIsEnglish?'Great':'رائع'))]));
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
  final challenge=await showWaffraDialog<SavingChallenge>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'New savings challenge':'تحدي ادخار جديد'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Challenge name *':'اسم التحدي *',
      errorText:attempted?waffraTextFieldError(name.text):null)),
     const SizedBox(height:12),
     TextField(controller:amount,onChanged:(_)=>update((){}),
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter()],decoration:InputDecoration(
       labelText:waffraIsEnglish?'Daily amount *':'الادخار اليومي *',
       errorText:attempted?waffraAmountFieldError(amount.text):null)),
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
            'هل أنت متأكد من حذف هذا التحدي؟ سيتم حذف التحدي نهائيًا، ولن تتمكن من استعادته لاحقًا.');
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

 Widget savingsBenefit(String name,IconData icon){
  final color=Theme.of(context).brightness==Brightness.dark?
   const Color(0xFF72DCAC):emerald;
  return Expanded(child:Container(
   padding:const EdgeInsets.symmetric(vertical:13,horizontal:5),
   decoration:BoxDecoration(color:color.withValues(alpha:.10),
    border:Border.all(color:color.withValues(alpha:.18)),borderRadius:BorderRadius.circular(18)),
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,color:color,size:23),const SizedBox(height:10),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
     Flexible(child:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(name,
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)))),
    ]),
   ]),
  ));
 }
 String waffraGoalDeleteWarning(String name,bool linked,bool english)=>english
  ?'Move “$name” to Deleted Goals for 30 days. ${linked?'This goal has saved amounts or linked transactions; financial history will stay untouched.':''} Restored goals restart with zero saved balance.'
  :'نقل «$name» إلى الأهداف المحذوفة لمدة 30 يومًا. ${linked?'هذا الهدف مرتبط بمبالغ ادخار أو معاملات مالية؛ ستبقى المعاملات محفوظة.':''} عند الاسترجاع يبدأ رصيد الادخار من صفر.';
 Future<void> deletedGoalsDialog()async{
  final before=deletedGoals.length;
  deletedGoals.removeWhere((item){
   final date=DateTime.tryParse('${item['deletedAt']??''}');
   return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));
  });
  if(before!=deletedGoals.length)await persist();
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>
   StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Deleted goals':'الأهداف المحذوفة'),
    content:SizedBox(width:double.maxFinite,
     height:waffraDeletedListHeight(ctx,deletedGoals.length),
     child:deletedGoals.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted goals':'لا توجد أهداف محذوفة'))
      :ListView(children:deletedGoals.map((item){
       final goal=SavingGoal.fromJson(Map<String,dynamic>.from(item['goal'] as Map));
       final deletedAt=DateTime.tryParse('${item['deletedAt']??''}')??DateTime.now();
       final left=max(0,(deletedAt.add(const Duration(days:30))
        .difference(DateTime.now()).inHours/24).ceil());
       return waffraDeletedItemCard(
        context:ctx,
        icon:goalIcon(goal.name),
        iconColor:emerald,
        title:goal.name,
        subtitle:waffraIsEnglish?'Savings goal • $left days remaining':
         'هدف ادخاري • متبقي $left يوم',
        onRestore:()async{
         if(goals.any((g)=>g.id==goal.id||g.name==goal.name)){
          snack(ctx,waffraIsEnglish?'Goal already exists':'الهدف موجود بالفعل');
          return;
         }
         setState((){
          goals.add(goal.copy(saved:0));
          deletedGoals.remove(item);
         });
         await persist();
         if(!ctx.mounted)return;
         Navigator.pop(ctx);
         if(mounted)snackSuccess(context,waffraIsEnglish
          ?'Goal restored with zero savings. All previous linked transactions remain in your financial history.'
          :'تم استرجاع الهدف بمدخرات صفر. جميع المعاملات القديمة المرتبطة به محفوظة في السجل المالي.');
        },
        onDeleteForever:()async{
         final yes=await confirmDeletion(
          waffraIsEnglish?'Permanently delete goal?':'حذف الهدف نهائيًا',
          waffraIsEnglish
           ?'Delete “${goal.name}” forever? It cannot be restored. Past financial transactions remain untouched.'
           :'هل تريد حذف الهدف «${goal.name}» نهائيًا؟ لن يمكن استرجاعه، وستظل المعاملات المالية القديمة محفوظة.');
         if(yes!=true||!mounted)return;
         setState(()=>deletedGoals.remove(item));
         await persist();
         if(ctx.mounted)refresh((){});
        },
       );
      }).toList())),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
 Widget goalsPage(){
  final target=goals.fold<double>(0,(v,g)=>v+g.target);
  final saved=goals.fold<double>(0,(v,g)=>v+g.saved);
  final pct=target==0?0.0:(saved/target).clamp(0.0,1.0);
  final filtered=goals.where((g)=>goalDisplay=='all'||
   (goalDisplay=='done'?g.saved>=g.target:g.saved<g.target)).toList();
  return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'Savings goals':'أهداف الادخار',
    subtitle:waffraIsEnglish?'Plan your future and follow every milestone':
     'حوّل أحلامك إلى أهداف وتابع تقدّمك خطوة بخطوة.',
    icon:Icons.flag_outlined,titleKey:_tourKeys[6]),
   const SizedBox(height:13),
   if(goals.isNotEmpty)...[
    Row(children:[
     Expanded(child:_summaryBox(waffraIsEnglish?'Total target':'إجمالي المستهدف',cash(target),Icons.flag_outlined,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Saved':'إجمالي المدخرات',cash(saved),Icons.account_balance_wallet_outlined,emerald)),
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
   SizedBox(width:double.infinity,child:OutlinedButton.icon(
    onPressed:deletedGoalsDialog,
    style:OutlinedButton.styleFrom(
     side:BorderSide(color:Theme.of(context).colorScheme.primary,width:1.4),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),
     padding:const EdgeInsets.symmetric(horizontal:12,vertical:13)),
    icon:const Icon(Icons.delete_outline,size:20),
    label:WaffraText(waffraIsEnglish?'Deleted savings goals (${deletedGoals.length})':'الأهداف المحذوفة (${deletedGoals.length})',
     style:const TextStyle(fontWeight:FontWeight.bold)))),
   const SizedBox(height:14),
   WaffraText(waffraIsEnglish?'Current goals: ${goals.length}':'عدد الأهداف الحالية: ${goals.length}',
    style:const TextStyle(fontWeight:FontWeight.bold)),
   const SizedBox(height:12),
   // Add via the shared physical-left +.
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
     color:Theme.of(context).cardColor,
     elevation:0,
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),
      side:const BorderSide(color:Color(0xFFCFDFD5),width:1)),
     child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
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
         final linked=g.saved>0||entries.any((e)=>e.category==g.name);
         final yes=await confirmDeletion(waffraIsEnglish?'Delete savings goal?':'حذف هدف الادخار',
          waffraGoalDeleteWarning(g.name,linked,waffraIsEnglish));
         if(yes==true&&mounted){setState((){deletedGoals.add({'goal':g.toJson(),'deletedAt':DateTime.now().toIso8601String()});goals.removeWhere((x)=>x.id==g.id);});await persist();}
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
   if(goals.isEmpty)Padding(padding:const EdgeInsets.only(top:18,bottom:14),
    child:Column(children:[
     Container(width:105,height:105,decoration:BoxDecoration(
      color:emerald.withValues(alpha:.10),borderRadius:BorderRadius.circular(54)),
      child:const Icon(Icons.account_balance_wallet_outlined,size:55,color:emerald)),
     const SizedBox(height:13),
     WaffraText(waffraIsEnglish?'No savings goals yet':'ما أضفت أي هدف ادخاري بعد',
      style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
     const SizedBox(height:10),
     WaffraText(waffraIsEnglish?'Set your first savings goal and track your progress':
      'ابدأ أول هدف ادخاري لك وحدد المبلغ المستهدف وتابع تقدّمك خطوة بخطوة.',
      textAlign:TextAlign.center),
     const SizedBox(height:22),
     Row(children:[
      savingsBenefit(waffraIsEnglish?'Plan ahead':'خطط لمستقبلك',Icons.wallet_outlined),
      const SizedBox(width:8),
      savingsBenefit(waffraIsEnglish?'Stay motivated':'حقق أهدافك',Icons.track_changes_outlined),
      const SizedBox(width:8),
      savingsBenefit(waffraIsEnglish?'Track progress':'تابع تقدمك',Icons.bar_chart_outlined),
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
  DateTime startAt=DateTime.now();
  final r=await showWaffraDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forType(income);
    final selected=options.any((x)=>x.name==category)?category:options.first.name;
    return AlertDialog(title:const WaffraText('عملية شهرية متكررة'),
     content:SizedBox(width:340,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'الوصف *',
       errorText:attempted?waffraTextFieldError(title.text):null)),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter()],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(amount.text):null)),
      const SizedBox(height:12),
      DropdownButtonFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:(v){if(v!=null)update((){income=v;category=forType(v).first.name;});}),
      const SizedBox(height:12),
      InkWell(
       borderRadius:BorderRadius.circular(14),
       onTap:()async{
        final picked=await showWaffraDialog<String>(context:ctx,
         builder:(searchCtx){
          String query='';
          return StatefulBuilder(builder:(searchCtx,refresh){
           final filtered=options.where((c)=>
            c.name.toLowerCase().contains(query.trim().toLowerCase())).toList();
           return AlertDialog(
            title:WaffraText(waffraIsEnglish?'Search categories':'البحث عن قسم'),
            content:SizedBox(
             width:double.maxFinite,
             height:min(430.0,MediaQuery.sizeOf(searchCtx).height*.58),
             child:Column(children:[
              TextField(
               autofocus:true,
               onChanged:(value)=>refresh(()=>query=value),
               decoration:InputDecoration(
                prefixIcon:const Icon(Icons.search_rounded),
                hintText:waffraIsEnglish?'Type a category name…':'اكتب اسم القسم للبحث…',
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
              ),
              const SizedBox(height:10),
              Expanded(child:filtered.isEmpty
               ?Center(child:WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'))
               :ListView.builder(
                itemCount:filtered.length,
                itemBuilder:(searchCtx,index){
                 final option=filtered[index];
                 return ListTile(
                  dense:true,
                  selected:option.name==selected,
                  leading:Icon(categoryIcon(option.icon),color:Color(option.color),size:21),
                  title:WaffraText(option.name,maxLines:3),
                  onTap:()=>Navigator.pop(searchCtx,option.name));
                })),
             ]),
            ),
           );
          });
         });
        if(picked!=null&&ctx.mounted)update(()=>category=picked);
       },
       child:InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Category *':'القسم *',
         suffixIcon:const Icon(Icons.search_rounded),
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
         contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:15)),
        child:Row(children:[
         Expanded(child:WaffraText(selected,maxLines:2,
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600))),
         const SizedBox(width:8),
         const Icon(Icons.arrow_drop_down_rounded,size:20),
        ]),
       ),
      ),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:()async{
       final picked=await showDatePicker(context:ctx,initialDate:startAt,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime(DateTime.now().year+5));
       if(picked!=null)update((){startAt=picked;day.text=picked.day.toString();});
      },icon:const Icon(Icons.calendar_month_outlined),label:WaffraText(waffraIsEnglish?'First due: ${dayText(startAt)}':'أول استحقاق: ${dayText(startAt)}')),
      const SizedBox(height:8),
      TextField(controller:day,keyboardType:TextInputType.number,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Day of month *':'يوم الشهر *',helperText:waffraIsEnglish?'1–31':'من 1 إلى 31',
       errorText:attempted?waffraDayFieldError(day.text):null)),
     ]))),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:(){
       final n=amountOf(amount.text),d=int.tryParse(digits(day.text));update(()=>attempted=true);
       if(WaffraValidators.requiredText(title.text)==null&&WaffraValidators.positiveAmount(amount.text)==null&&WaffraValidators.dayOfMonth(day.text)==null&&n!=null&&d!=null){
        Navigator.pop(ctx,RecurringBill(id:newId(),title:title.text.trim(),category:category,
         amount:n,income:income,day:d,startAt:startAt));
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
  return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'Recurring transactions':'العمليات المتكررة',
    subtitle:waffraIsEnglish?'Track recurring payments and due dates':
     'نظّم عملياتك الشهرية ومواعيد استحقاقها بسهولة.',
    icon:Icons.event_repeat_rounded,titleKey:_tourKeys[4]),
   const SizedBox(height:9),
   SizedBox(width:double.infinity,child:OutlinedButton.icon(
    onPressed:deletedRecurringDialog,
    style:OutlinedButton.styleFrom(
     side:BorderSide(color:Theme.of(context).colorScheme.primary,width:1.4),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),
     padding:const EdgeInsets.symmetric(horizontal:12,vertical:13)),
    icon:const Icon(Icons.delete_outline,size:20),
    label:WaffraText(waffraIsEnglish?'Deleted recurring transactions (${deletedRecurring.length})':'العمليات المتكررة المحذوفة (${deletedRecurring.length})',
     style:const TextStyle(fontWeight:FontWeight.bold)))),
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
   WaffraText(waffraIsEnglish?'Recurring items: ${recurring.length}':'عدد العمليات المتكررة: ${recurring.length}',style:const TextStyle(fontWeight:FontWeight.bold)),
   const SizedBox(height:9),
   OutlinedButton.icon(onPressed:showWaffraFinancialCalendar,icon:const Icon(Icons.calendar_month),label:WaffraText(waffraIsEnglish?'Financial calendar':'التقويم المالي')),
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
   // Add via the shared physical-left +.
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
    return Card(elevation:0,margin:const EdgeInsets.only(bottom:11),
     color:Theme.of(context).brightness==Brightness.dark?Theme.of(context).cardColor:
      (r.income?const Color(0xFFEAF6EF):const Color(0xFFFFF0ED)),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(21),
      side:BorderSide(color:r.income?const Color(0xFFBBDCC9):const Color(0xFFF3DCD7))),
     child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),child:Row(children:[
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
       if(enabled){
        final chosen=await showDatePicker(context:context,initialDate:DateTime.now().add(const Duration(days:1)),
         firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+5));
        if(chosen==null||!mounted)return;
        setState(()=>recurring[index]=r.copy(active:true,startAt:chosen,day:chosen.day));
       }else{
        setState(()=>recurring[index]=r.copy(active:false));
       }
       await persist();
       if(enabled)await applyRecurring();
       await syncRecurringReminders();
      }),
      PopupMenuButton<String>(onSelected:(v)async {
       if(v!='delete')return;
       final hasHistory=entries.any((e)=>e.id.startsWith('rec_${r.id}_'));
       final ok=await confirmDeletion(waffraIsEnglish?'Delete recurring transaction?':'حذف العملية المتكررة',
        waffraRecurringDeleteWarning(r.title,hasHistory,waffraIsEnglish));
       if(ok==true&&mounted){
        setState((){
         deletedRecurring.add({'recurring':r.toJson(),'deletedAt':DateTime.now().toIso8601String()});
         recurring.removeWhere((e)=>e.id==r.id);
         recurringPostponed.removeWhere((key,value)=>key.startsWith('rec_${r.id}_'));
        });
        await persist();await syncRecurringReminders();
       }
      },itemBuilder:(_)=>[
       PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف'))]),
     ])));
   }),
   if(recurring.isEmpty)Padding(padding:const EdgeInsets.only(top:18),
    child:Column(children:[
     Container(width:105,height:105,decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(54),color:emerald.withValues(alpha:.10)),
      child:const Icon(Icons.event_repeat_rounded,size:56,color:emerald)),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'No recurring transactions yet':'ما عندك عمليات متكررة',
      style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'Add a recurring transaction to organize monthly finances':
      'أضف عملية متكررة لتنظيم مصروفاتك الشهرية ومتابعتها بسهولة.',
      textAlign:TextAlign.center),
     const SizedBox(height:19),
     // Add via the shared physical-left +.
   const SizedBox(height:22),
     Row(children:[
      Expanded(child:_recurringBenefit(waffraIsEnglish?'Save time':'توفير الوقت',Icons.bolt)),
      const SizedBox(width:8),
      Expanded(child:_recurringBenefit(waffraIsEnglish?'Stay organized':'تنظيم أفضل',Icons.analytics)),
      const SizedBox(width:8),
      Expanded(child:_recurringBenefit(waffraIsEnglish?'Due reminders':'تذكير بالمواعيد',Icons.notifications_none)),
     ]),
    ])),
   if(recurring.isNotEmpty&&shown.isEmpty)Padding(padding:const EdgeInsets.all(32),
    child:WaffraText(waffraIsEnglish?'No items match this filter':'لا توجد عمليات في هذا التصنيف',
     textAlign:TextAlign.center)),
   const SizedBox(height:20),
  ]);
 }
 Future<void> showWaffraFinancialCalendar()async{
  DateTime selected=DateTime.now();
  await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
   final monthEvents=recurring.where((r)=>r.active&&
    !WaffraRecurringPolicy.dueDate(selected.year,selected.month,r.day).isBefore(DateTime(r.startAt.year,r.startAt.month,r.startAt.day))).toList();
   return AlertDialog(title:WaffraText(waffraIsEnglish?'Financial calendar':'التقويم المالي'),
    content:SizedBox(width:380,height:min(460.0,MediaQuery.sizeOf(ctx).height*.6),child:Column(children:[
     CalendarDatePicker(initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100),
      onDateChanged:(date)=>refresh(()=>selected=date)),
     const Divider(),
     Expanded(child:ListView(children:monthEvents.map((r){
      final due=WaffraRecurringPolicy.dueDate(selected.year,selected.month,r.day);
      final id=WaffraRecurringPolicy.entryId(r.id,due);
      final paid=entries.any((e)=>e.id==id);
      final postponed=DateTime.tryParse(recurringPostponed[id]??'');
      return ListTile(dense:true,leading:Icon(paid?Icons.check_circle:Icons.schedule,color:paid?emerald:Colors.orange),
       title:WaffraText(r.title),subtitle:WaffraText('${dayText(postponed??due)} • ${paid?(waffraIsEnglish?'Paid':'مدفوعة'):(waffraIsEnglish?'Pending':'معلقة')}'),trailing:WaffraText(cash(r.amount)));
     }).toList()))])),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
  }));
 }
 String exportBackup()=>const JsonEncoder.withIndent('  ').convert({
  'format':'waffra-backup','version':24,'exportedAt':DateTime.now().toIso8601String(),
  'entries':entries.map((e)=>e.toJson()).toList(),
  'categories':categories.map((e)=>e.toJson()).toList(),
  'goals':goals.map((e)=>e.toJson()).toList(),
  'recurring':recurring.map((e)=>e.toJson()).toList(),
  'challenges':challenges.map((e)=>e.toJson()).toList(),
  'deletedCategories':deletedCategories,
  'deletedGoals':deletedGoals,
  'deletedRecurring':deletedRecurring,
  'recurringPostponed':recurringPostponed,
  'monthlyBudget':monthlyBudget,
  'monthlyBudgetEnabled':monthlyBudgetEnabled,
  'learnedMerchants':learnedMerchantCategories,
  'profile':widget.profile.toJson(),
 });
 Future<bool> _authorizeSensitiveAction(String operation)async{
  if(!await WaffraBiometrics.isAvailable()){
   if(mounted)await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Fingerprint required':'بصمة الجهاز مطلوبة'),
    content:WaffraText(waffraIsEnglish?'Enroll a fingerprint in your device settings before $operation. Waffra does not bypass biometric verification with an app PIN.':'يجب تسجيل بصمة على هاتفك أولاً لحماية هذه العملية. لن يسمح وفرة باستخدام رمز التطبيق بدلاً منها.'),
    actions:[OutlinedButton(onPressed:()=>Navigator.pop(ctx),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   return false;
  }
  final allowed=await WaffraBiometrics.unlock();
  if(!allowed&&mounted)snack(context,waffraIsEnglish?'Biometric verification required to continue':'يلزم التحقق ببصمة الجهاز للمتابعة');
  return allowed;
 }
 Future<void> _setRecentAppProtection(bool enabled)async{
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_protect_recents_v1',enabled);
  if(mounted)setState(()=>protectRecentApps=enabled);
  if(Platform.isAndroid){
   try{await _privacyChannel.invokeMethod<void>('setProtectRecents',enabled);}
   on PlatformException catch(e){debugPrint('Recents privacy: $e');}
  }
 }
 Future<void> backupDialog()async {
  if(!await _authorizeSensitiveAction('backing up or restoring data')||!mounted)return;
  final input=TextEditingController(),secret=TextEditingController();
  var attempted=false;String? backupError;bool legacyRestorePassword=false;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
   title:const WaffraText('نسخ احتياطي واستعادة'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    WaffraText(waffraIsEnglish?'Your backup is protected with a password and AES-256 encryption. Keep your password safe; it cannot be recovered.':'نسختك الاحتياطية مشفّرة بكلمة مرور وتشفير AES-256. احتفظ بكلمة المرور؛ لا يمكن استعادتها إذا فُقدت.'),
    const SizedBox(height:10),
    TextField(controller:secret,obscureText:true,
     inputFormatters:legacyRestorePassword?const <TextInputFormatter>[]:
      <TextInputFormatter>[
       FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
       LengthLimitingTextInputFormatter(8),
      ],
     onChanged:(_)=>update(()=>backupError=null),
     decoration:InputDecoration(
      labelText:legacyRestorePassword?
       (waffraIsEnglish?'Existing backup password *':'كلمة مرور النسخة القديمة *'):
       (waffraIsEnglish?'Backup password (exactly 8 letters/digits) *':'كلمة مرور النسخة (8 خانات أحرف وأرقام) *'),
      errorText:backupError,errorMaxLines:3,
      border:const OutlineInputBorder())),
    // Existing archives may have longer passwords; preserve their restore path.
    SwitchListTile.adaptive(
     contentPadding:EdgeInsets.zero,
     title:WaffraText(waffraIsEnglish?
      'Restore an older backup password':'استعادة نسخة قديمة بكلمة مرور أطول',
      style:const TextStyle(fontSize:12)),
     value:legacyRestorePassword,
     onChanged:(value)=>update((){
      legacyRestorePassword=value;secret.clear();backupError=null;
     })),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:()async {
     if(!WaffraSecureBackup.isValidNewPassword(secret.text)){
      update(()=>backupError=waffraIsEnglish?'Exactly 8 letters and digits, including one of each.':'كلمة المرور 8 خانات بالضبط من أحرف وأرقام، وبها حرف ورقم على الأقل.');return;
     }
     try{
      final encrypted=await WaffraSecureBackup.encryptUserBackup(exportBackup(),secret.text);
      await Clipboard.setData(ClipboardData(text:encrypted));
      final generatedAt=DateTime.now().toIso8601String();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('waffra_backup_last_exported_v1',generatedAt);
      await prefs.setInt('waffra_backup_last_size_v1',utf8.encode(encrypted).length);
      if(mounted)setState((){lastBackupGeneratedAt=generatedAt;lastBackupBytes=utf8.encode(encrypted).length;});
      if(ctx.mounted)snackSuccess(ctx,waffraIsEnglish?'Encrypted backup copied; keep it and its password safe':'تم نسخ النسخة المشفّرة، احتفظ بها وكلمة مرورها في مكان آمن');
     }catch(error){if(ctx.mounted)update(()=>backupError=error.toString());}
    },icon:const Icon(Icons.lock_outline),label:WaffraText(waffraIsEnglish?'Copy encrypted backup':'نسخ النسخة المشفّرة')),
    // Password error shown inline under the input.
    const SizedBox(height:12),
    TextField(controller:input,minLines:4,maxLines:7,onChanged:(_)=>update(()=>backupError=null),
     decoration:InputDecoration(labelText:waffraIsEnglish?'Backup JSON *':'الصق نسخة JSON للاستعادة *',
      errorText:attempted?(input.text.trim().isEmpty?waffraRequiredFieldMessage:backupError):null,
      errorMaxLines:3,border:OutlineInputBorder())),
   ])),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const WaffraText('إغلاق')),
    FilledButton(onPressed:()async {
     update(()=>attempted=true);
     if(input.text.trim().isEmpty)return;
     try{
      final raw=jsonDecode(await WaffraSecureBackup.decrypt(input.text.trim(),secret.text));
      if(raw is! Map||raw['format']!='waffra-backup'||raw['entries'] is! List||
        raw['categories'] is! List||raw['goals'] is! List||raw['recurring'] is! List){
       throw const FormatException('Invalid backup');
      }
      final newEntries=(raw['entries'] as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))).toList();
      final newCategories=(raw['categories'] as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))).toList();
      final newGoals=(raw['goals'] as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))).toList();
      final newRecurring=(raw['recurring'] as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))).toList();
      final newChallenges=raw['challenges'] is List?(raw['challenges'] as List).map((x)=>SavingChallenge.fromJson(Map<String,dynamic>.from(x))).toList():<SavingChallenge>[];
      final newDeletedRecurring=raw['deletedRecurring'] is List?(raw['deletedRecurring'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      final newDeletedGoals=raw['deletedGoals'] is List?(raw['deletedGoals'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      final newPostponed=raw['recurringPostponed'] is Map?(raw['recurringPostponed'] as Map).map((k,v)=>MapEntry(k.toString(),v.toString())):<String,String>{};
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
      if(!await _authorizeSensitiveAction('restoring data')||!mounted)return;
      setState((){
       entries..clear()..addAll(newEntries);
       categories..clear()..addAll(newCategories);
       goals..clear()..addAll(newGoals);
       recurring..clear()..addAll(newRecurring);
       challenges..clear()..addAll(newChallenges);
       deletedCategories..clear()..addAll(newTrash);
       deletedGoals..clear()..addAll(newDeletedGoals);
       deletedRecurring..clear()..addAll(newDeletedRecurring);
       recurringPostponed..clear()..addAll(newPostponed);
       monthlyBudget=restoredBudget;
       monthlyBudgetEnabled=raw['monthlyBudgetEnabled'] is bool?(raw['monthlyBudgetEnabled'] as bool):(restoredBudget>0);
       learnedMerchantCategories..clear()..addAll(restoredRules);
      });
      await persist();
      await syncRecurringReminders();
      if(ctx.mounted)Navigator.pop(ctx);
      if(mounted)snackSuccess(context,'تمت استعادة البيانات بنجاح');
     }catch(e){
      if(ctx.mounted)update(()=>backupError=waffraIsEnglish?'Invalid backup. Check the entire JSON text.':'النسخة غير صالحة، تأكد من النص كامل');
     }
    },child:const WaffraText('استعادة')),
   ])));
  disposeLater([input,secret]);
 }
 // System credentials are never saved in plain text. A new PIN must be
 // entered twice; keep support for checking older 4-8-digit PINs on disable.
 Future<String?> _askForPin({
  required String title,required String fieldLabel,bool existing=false,
   bool Function(String)? verify,String? verifyError,
 })async{
  final input=TextEditingController();
  var attempted=false;String? fieldError;
  try{
   return await showWaffraDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,update)=>Theme(data:Theme.of(dialogContext).copyWith(brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:emerald,brightness:Brightness.dark)),child:AlertDialog(
    backgroundColor:forest,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
     side:waffraDialogOutline(Brightness.dark)),
    title:Column(mainAxisSize:MainAxisSize.min,children:[
     const CircleAvatar(radius:26,backgroundColor:emerald,child:Icon(Icons.lock_outline,color:Colors.white,size:28)),
     const SizedBox(height:12),WaffraText(title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))]),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText(fieldLabel,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),
     const SizedBox(height:12),
     TextField(
     controller:input,autofocus:true,onChanged:(_)=>update(()=>fieldError=null),
     textDirection:TextDirection.ltr,textAlign:TextAlign.center,
     keyboardType:TextInputType.number,
     inputFormatters:[FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(existing?8:4)],
     obscureText:true,
     decoration:InputDecoration(hintText:'••••',hintStyle:const TextStyle(color:Colors.white54),
      helperText:existing?(waffraIsEnglish?'4 to 8 digits':'من 4 إلى 8 أرقام'):(waffraIsEnglish?'4 digits':'أربعة أرقام'),
      errorText:fieldError??(attempted?waffraPinFieldError(input.text,existing:existing):null),errorMaxLines:3,
      border:const OutlineInputBorder())),
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialogContext),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:(){
      final code=input.text.trim();
      update(()=>attempted=true);
      if(waffraPinFieldError(code,existing:existing)!=null)return;
      if(verify!=null&&!verify(code)){
       update(()=>fieldError=verifyError??(waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح'));
       return;
      }
      Navigator.pop(dialogContext,code);
     },child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد')),
    ],
   ))));
  }finally{disposeLater([input]);}
 }
 Future<void> configurePin()async {
  if(widget.pinEnabled){
   final prefs=await SharedPreferences.getInstance();
   final hash=prefs.getString('waffra_pin_sha256');
   final oldPin=await _askForPin(
    title:waffraIsEnglish?'Disable app lock':'إلغاء رمز القفل',
    fieldLabel:waffraIsEnglish?'Current PIN':'أدخل الرمز الحالي',
    existing:true,verify:(code)=>sha256.convert(utf8.encode(code)).toString()==hash,
    verifyError:waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح');
   if(oldPin==null||!mounted)return;
   await widget.onSetPin(null);
   if(mounted)snackSuccess(context,waffraIsEnglish?'App lock disabled':'تم إلغاء القفل');
   return;
  }
  final firstPin=await _askForPin(
   title:waffraIsEnglish?'Create a new PIN':'إنشاء رمز قفل',
   fieldLabel:waffraIsEnglish?'New 4-digit PIN':'رمز PIN من 4 أرقام');
  if(firstPin==null||!mounted)return;
  while(mounted){
   final repeated=await _askForPin(
    title:waffraIsEnglish?'Confirm your PIN':'أعد إدخال رمز PIN للتأكيد',
    fieldLabel:waffraIsEnglish?'Repeat PIN':'أعد إدخال الرمز',
    verify:(code)=>code==firstPin,
    verifyError:waffraIsEnglish?'PINs do not match':'رمزا PIN غير متطابقين');
   if(repeated==null||!mounted)return;
   if(firstPin==repeated){
    // The existing onSetPin stores only SHA-256 of the confirmed PIN.
    await widget.onSetPin(firstPin);
    if(mounted)snackSuccess(context,waffraIsEnglish?'App lock enabled':'تم تفعيل قفل التطبيق');
    return;
   }
  }
 }
 void scheduleTourFocus(){
  WidgetsBinding.instance.addPostFrameCallback((_)async {
   if(!mounted||!tourActive)return;
   final focus=tourTargetKeys[tourStep]<0?null:_tourKeys[tourTargetKeys[tourStep]].currentContext;
   if(focus!=null){
    try{await Scrollable.ensureVisible(focus,
     duration:waffraMotion(250),alignment:.16,
     curve:Curves.easeOutCubic);}catch(e){debugPrint('Tour focus: $e');}
   }
   await Future<void>.delayed(waffraMotion(200));
   if(mounted&&tourActive)setState(()=>tourTargetReady=tourStep==0||focus!=null);
  });
 }
 Future<void> completeTour()async {
  _tourGlow.stop();
  if(mounted)setState((){tourActive=false;tourTargetReady=false;addFabExpanded=false;tab=0;goalsOpened=false;});
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_in_app_tour_seen_v2',true);
 }
 void beginTour(){
  setState((){tourStep=0;tourActive=true;tourTargetReady=false;tab=0;goalsOpened=false;addFabExpanded=false;});
  if(waffraAnimationLevel.value!='off')_tourGlow.repeat(reverse:true);
  scheduleTourFocus();
 }
 void advanceTour(){
  if(tourStep>=tourTabs.length-1){completeTour();return;}
  setState((){tourStep++;tab=tourTabs[tourStep];tourTargetReady=false;addFabExpanded=false;});
  scheduleTourFocus();
 }
 void previousTour(){
  if(tourStep<=0)return;
  setState((){tourStep--;tab=tourTabs[tourStep];tourTargetReady=false;addFabExpanded=false;});
  scheduleTourFocus();
 }
 Widget tourOverlay()=>LayoutBuilder(builder:(overlayCtx,area){
  const ar=['مرحبًا بك في وفرة','الرئيسية والرصيد','إضافة المعاملات','الأقسام','الأهداف الادخارية','العمليات المتكررة','التحليل المالي الذكي','حسابي وإعداداتي'];
  const en=['Welcome to Waffra','Home & balance','Add transactions','Categories','Savings goals','Recurring items','Smart analysis','Account & settings'];
  const arHelp=['ابدأ بدون تسجيل، واحتفظ ببياناتك على هاتفك.','الرصيد والدخل والمصروفات في مكان واحد.','أضف عملية أو الصق رسالة بنكية للتحليل.','نظّم الأقسام الرئيسية والفرعية.','خطط لأهداف الادخار وتابع التقدم.','نظّم الاستحقاقات الشهرية والمتكررة.','اطلع على التوصيات والرسوم والتوقعات.','تحكم بالمظهر واللغة والأمان وأعد الجولة عند الحاجة.'];
  const enHelp=['Start as a guest and keep data on your phone.','See balance, income and expenses.','Add a transaction or paste a bank message.','Organize categories and budgets.','Create savings goals and follow progress.','Plan recurring payments and due dates.','Explore advice, charts and forecasts.','Change appearance, language, privacy and replay this tour.'];
  final element=tourTargetKeys[tourStep]<0?null:_tourKeys[tourTargetKeys[tourStep]].currentContext?.findRenderObject();
  final layer=overlayCtx.findRenderObject();
  Rect target=tourStep==0?Rect.fromLTWH(-40,-40,1,1):
   Rect.fromLTWH(16,12,area.maxWidth-32,65);
  if(element is RenderBox&&layer is RenderBox&&element.hasSize){
   final offset=element.localToGlobal(Offset.zero)-layer.localToGlobal(Offset.zero);
   target=Rect.fromLTWH(offset.dx,offset.dy,element.size.width,element.size.height).inflate(5);
   target=Rect.fromLTRB(
    target.left.clamp(4.0,area.maxWidth-4).toDouble(),
    target.top.clamp(4.0,area.maxHeight-4).toDouble(),
    target.right.clamp(4.0,area.maxWidth-4).toDouble(),
    target.bottom.clamp(4.0,area.maxHeight-4).toDouble());
  }
  // Headings use intrinsic text bounds rather than a full-width row.
  // Other tour steps retain their actual button/icon target.
  final headingFocus=tourStep==3||tourStep==5;
  final headingText=tourStep==3?(waffraIsEnglish?'Categories & budgets':'أقسامك وميزانياتك'):(waffraIsEnglish?en[tourStep]:ar[tourStep]);
  if(headingFocus){
   final style=Theme.of(context).textTheme.titleLarge??const TextStyle(fontSize:23);
   final painter=TextPainter(text:TextSpan(text:headingText,style:style.copyWith(fontWeight:FontWeight.bold)),
    textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,maxLines:1)..layout(maxWidth:area.maxWidth-40);
   final desiredWidth=(painter.width+30).clamp(90.0,area.maxWidth-24).toDouble();
   final right=waffraIsEnglish?target.left+desiredWidth:target.right;
   target=Rect.fromLTWH((right-desiredWidth).clamp(8.0,area.maxWidth-desiredWidth-8).toDouble(),
    target.top,desiredWidth,target.height);
  }
  final width=min(340.0,area.maxWidth-24);
   final popupHeight=tourStep==0?min(250.0,max(160.0,area.maxHeight*.46)):
    min(225.0,max(130.0,area.maxHeight*.56));
   final spaceBelow=area.maxHeight-target.bottom-12;
   final spaceAbove=target.top-12;
   final below=spaceBelow>=popupHeight||(spaceBelow>=spaceAbove&&spaceAbove<popupHeight);
   final suggestedTop=tourStep==0?(area.maxHeight-popupHeight)*.44:
    (below?target.bottom+12:target.top-popupHeight-12);
   final top=suggestedTop.clamp(12.0,max(12.0,area.maxHeight-popupHeight-12)).toDouble();
   final suggestedLeft=tourStep==0?(area.maxWidth-width)/2:target.center.dx-width/2;
   final left=suggestedLeft.clamp(12.0,max(12.0,area.maxWidth-width-12)).toDouble();
  return Stack(children:[
   Positioned.fill(child:AnimatedBuilder(animation:_tourGlow,
    builder:(ctx,_)=>CustomPaint(painter:WaffraTourShade(target,glow:_tourGlow.value)))),
   if(headingFocus)Positioned.fromRect(rect:target,child:IgnorePointer(child:
    AnimatedBuilder(animation:_tourGlow,builder:(ctx,_){
     final zoom=waffraAnimationLevel.value=='off'?1.0:1.0+.09*_tourGlow.value;
     return Center(child:Transform.scale(scale:zoom,child:Container(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
      decoration:BoxDecoration(color:const Color(0xFFF7FFF9),
       borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF7EDAB0),width:1.4),
       boxShadow:[BoxShadow(color:const Color(0xFF66DDA3).withValues(alpha:.24+.20*_tourGlow.value),
        blurRadius:15+10*_tourGlow.value)]),
      child:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(headingText,
       style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:forest))))));
    }))),
   AnimatedPositioned(
    duration:waffraMotion(250),
    curve:Curves.easeInOutCubic,top:top,left:left,width:width,
    child:Material(elevation:12,color:Theme.of(context).cardColor,
     borderRadius:BorderRadius.circular(18),
     child:ConstrainedBox(constraints:BoxConstraints(maxHeight:popupHeight),
      child:SingleChildScrollView(padding:const EdgeInsets.all(12),child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[
        const Icon(Icons.lightbulb_outline,color:emerald,size:18),
        const SizedBox(width:5),
        Expanded(child:AnimatedSwitcher(duration:waffraMotion(250),
         transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,
          child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,.18),end:Offset.zero).animate(animation),child:child)),
         child:WaffraText(waffraIsEnglish?en[tourStep]:ar[tourStep],key:ValueKey(tourStep),
          style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)))),
        WaffraText('${tourStep+1}/${tourTabs.length}',style:const TextStyle(color:emerald,fontSize:11)),
       ]),
       const SizedBox(height:6),
       WaffraText(waffraIsEnglish?enHelp[tourStep]:arHelp[tourStep],
        style:const TextStyle(fontSize:12)),
       const SizedBox(height:8),
       Wrap(alignment:WrapAlignment.spaceBetween,spacing:5,runSpacing:6,children:[
        TextButton(onPressed:completeTour,child:WaffraText(waffraIsEnglish?'Skip':'تخطي')),
        if(tourStep>0)TextButton(onPressed:previousTour,
         child:WaffraText(waffraIsEnglish?'Back':'السابق')),
        FilledButton(onPressed:advanceTour,
         child:WaffraText(tourStep==tourTabs.length-1?
          (waffraIsEnglish?'Finish':'إنهاء'):(waffraIsEnglish?'Next':'التالي'))),
       ]),
      ])))),
   ),
  ]);
 });
 Future<void> changePin()async {
  if(!widget.pinEnabled)return;
  final p=await SharedPreferences.getInstance();
  final hash=p.getString('waffra_pin_sha256');
  final previous=await _askForPin(title:waffraIsEnglish?'Current PIN':'رمز القفل الحالي',
   fieldLabel:waffraIsEnglish?'Enter PIN':'أدخل رمز القفل',existing:true,
   verify:(code)=>sha256.convert(utf8.encode(code)).toString()==hash,
   verifyError:waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح');
  if(previous==null||!mounted)return;
  final next=await _askForPin(title:waffraIsEnglish?'New PIN':'رمز جديد',
   fieldLabel:waffraIsEnglish?'4 digits':'أربعة أرقام');
  if(next==null||!mounted)return;
  final again=await _askForPin(title:waffraIsEnglish?'Confirm PIN':'تأكيد الرمز',
   fieldLabel:waffraIsEnglish?'Repeat PIN':'أعد إدخال الرمز',
   verify:(code)=>code==next,
   verifyError:waffraIsEnglish?'PINs do not match':'الرمزان غير متطابقين');
  if(again==null||!mounted)return;
  await widget.onSetPin(next);
  if(mounted)snackSuccess(context,waffraIsEnglish?'PIN changed':'تم تغيير الرمز بنجاح');
 }
 Future<void> eraseFinancialData()async {
  if(!await _authorizeSensitiveAction('deleting financial data')||!mounted)return;
  final ok=await confirmDeletion(
   waffraIsEnglish?'Permanently delete financial data?':'حذف البيانات المالية نهائيًا',
   waffraIsEnglish?'This deletes transactions, categories, budgets, goals and recurring schedules. It cannot be undone. Your profile and app settings stay.':
    'سيتم حذف المعاملات والأقسام والميزانيات والأهداف والجدولة المتكررة نهائيًا. لا يمكن التراجع. سيبقى الملف الشخصي وإعدادات التطبيق.');
  if(ok!=true||!mounted)return;
  setState((){
   entries.clear();categories..clear()..addAll(defaultCategories());
   goals.clear();challenges.clear();recurring.clear();deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();recurringPostponed.clear();smsHashes.clear();
   learnedMerchantCategories.clear();monthlyBudget=0;monthlyBudgetEnabled=false;
  });
  final p=await SharedPreferences.getInstance();
  await p.remove('waffra_sms_hashes_v1');await persist();
  if(mounted)snackSuccess(context,waffraIsEnglish?'Financial data deleted':'تم حذف البيانات المالية');
 }
 Widget _accountTile(String label,String subtitle,IconData icon,{VoidCallback? onTap,Widget? trailing,Color tint=emerald})=>
  ListTile(
   leading:CircleAvatar(backgroundColor:tint.withValues(alpha:.12),child:Icon(icon,color:tint,size:21)),
   title:WaffraText(label,style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),
   trailing:trailing??(onTap==null?null:const Icon(Icons.chevron_left)),onTap:onTap);
 Widget _accountSection(String heading,IconData icon,List<Widget> children) {
  final q=accountSearch.trim().toLowerCase();
  if(q.isNotEmpty&&_accountOpenSection!=heading)return const SizedBox.shrink();
  final opened=_accountOpenSection==heading;
  final dim=Theme.of(context).brightness==Brightness.dark;
  return Card(margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(20),
   side:BorderSide(color:dim?const Color(0xFF456855):const Color(0xFFDCEAE1))),
   child:Column(children:[
    InkWell(onTap:()=>setState(()=>_accountOpenSection=opened?null:heading),
     borderRadius:BorderRadius.circular(20),
     child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[
      CircleAvatar(radius:20,backgroundColor:emerald.withValues(alpha:.12),child:Icon(icon,color:emerald,size:21)),
      const SizedBox(width:10),Expanded(child:WaffraText(heading,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
      AnimatedRotation(turns:opened?0.5:0.0,duration:waffraMotion(200),child:const Icon(Icons.keyboard_arrow_down_rounded)),
     ]))),
    AnimatedSize(duration:waffraMotion(220),curve:Curves.easeInOutCubic,
     child:opened?Column(children:[
      const Divider(height:1),for(var i=0;i<children.length;i++)...[
       children[i],if(i<children.length-1)const Divider(height:1,indent:14,endIndent:14),
      ],
     ]):const SizedBox(width:double.infinity,height:0)),
   ]));
 }
 List<WaffraCalendarItem> get financialCalendarItems=>[
  ...entries.map((e)=>WaffraCalendarItem(e.date,e.title,e.amount,e.income)),
  ...recurring.where((r)=>r.active).map((r)=>WaffraCalendarItem(
   DateTime(DateTime.now().year,DateTime.now().month,r.day.clamp(1,28).toInt()),
   r.title,r.amount,r.income,scheduled:true)),
 ];
 void openFinancialCalendar()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraFinancialCalendar(items:financialCalendarItems,english:waffraIsEnglish)));
 void openSubscriptionInsights()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraSubscriptionScreen(items:financialCalendarItems,english:waffraIsEnglish)));
 Widget profilePage(){
  final p=widget.profile;
  final provider=p.provider.toLowerCase().trim();
  final isGuest=(provider=='محلي'||provider=='local'||provider=='guest')&&
   p.email.trim().isEmpty&&p.phone.trim().isEmpty;
  void edit(){Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>ProfileForm(provider:p.provider,initial:p,onSave:widget.onProfile)));}
  return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'My account':'حسابي',
    subtitle:waffraIsEnglish?'Your profile, preferences and security':
     'بياناتك وإعداداتك وخصوصيتك في مكان واحد.',
    icon:Icons.person_outline_rounded),
   Container(padding:const EdgeInsets.fromLTRB(16,17,16,17),
    decoration:BoxDecoration(
     color:Theme.of(context).cardColor,
     borderRadius:BorderRadius.circular(22),
     border:Border.all(color:Theme.of(context).brightness==Brightness.dark?
      const Color(0xFF375C4A):const Color(0xFFDCEBE2))),
    child:Column(children:[
     InkWell(onTap:edit,child:Stack(alignment:Alignment.bottomRight,children:[
      waffraAvatar(p.gender,p.avatar,radius:42),
      const CircleAvatar(radius:14,backgroundColor:forest,
       child:Icon(Icons.camera_alt,size:16,color:Colors.white)),
     ])),
     const SizedBox(height:12),
     WaffraText(p.name.trim().isEmpty?(waffraIsEnglish?'My account':'حسابي'):p.name,
      textAlign:TextAlign.center,
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     if(p.email.trim().isNotEmpty)...[
      const SizedBox(height:5),
      WaffraText(p.email,textAlign:TextAlign.center),
     ],
     const SizedBox(height:15),
   OutlinedButton.icon(onPressed:edit,icon:const Icon(Icons.edit_outlined),
    label:WaffraText(waffraIsEnglish?'Edit profile':'تعديل حسابي')),
    ])),
   const SizedBox(height:13),
   TextField(key:const Key('waffra-account-settings-search'),onChanged:(value){
    final q=value.trim().toLowerCase();
    final groups=<String,String>{
     waffraIsEnglish?'App settings':'إعدادات التطبيق':'language theme appearance system dark light المظهر اللغة الحركة animation',
     waffraIsEnglish?'Security & privacy':'الأمان والخصوصية':'privacy biometric fingerprint حماية بصمة قفل إخفاء PIN screenshots المعاينة',
     waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات':'backup restore delete نسخ احتياطي استعادة حذف بيانات',
     waffraIsEnglish?'Financial tools':'الأدوات المالية':'calendar subscriptions currency tools التقويم الاشتراكات الأدوات المالية',
     waffraIsEnglish?'Help & about':'المساعدة وعن وفرة':'tour help about وفرة الجولة المساعدة',
    };
    String? match;
    if(q.isNotEmpty){for(final item in groups.entries){if(('${item.key} ${item.value}').toLowerCase().contains(q)){match=item.key;break;}}}
    setState((){accountSearch=q;_accountOpenSection=match;});
   },decoration:InputDecoration(prefixIcon:const Icon(Icons.search,color:emerald),
    hintText:waffraIsEnglish?'Find a setting':'ابحث داخل إعدادات حسابي')),
   const SizedBox(height:12),
   _accountSection(waffraIsEnglish?'App settings':'إعدادات التطبيق',Icons.settings_outlined,[
    ListTile(
     leading:const CircleAvatar(child:Icon(Icons.auto_awesome_outlined,color:emerald)),
     title:WaffraText(waffraIsEnglish?'Animations & effects':'الحركة والتأثيرات',style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:WaffraText(waffraIsEnglish?'Choose motion intensity':'اختر مستوى الحركة في التطبيق'),
     trailing:DropdownButton<String>(value:waffraAnimationLevel.value,underline:const SizedBox.shrink(),
      onChanged:(v){if(v!=null)setAnimationLevel(v);},items:[
       DropdownMenuItem(value:'full',child:WaffraText(waffraIsEnglish?'Full':'كاملة')),
       DropdownMenuItem(value:'balanced',child:WaffraText(waffraIsEnglish?'Balanced':'متوازنة')),
       DropdownMenuItem(value:'reduced',child:WaffraText(waffraIsEnglish?'Reduced':'خفيفة')),
       DropdownMenuItem(value:'off',child:WaffraText(waffraIsEnglish?'Off':'بدون حركة')),
      ])),
    _accountTile(waffraIsEnglish?'App language':'لغة التطبيق',
     waffraIsEnglish?'English':'العربية',Icons.language,
     trailing:SegmentedButton<String>(segments:const [
      ButtonSegment(value:'ar',label:Text('AR')),ButtonSegment(value:'en',label:Text('EN')),
     ],selected:{waffraLanguage.value},showSelectedIcon:false,
     onSelectionChanged:(v)async{setState(()=>tab=0);await widget.onLanguage(v.first);})),
    ListTile(leading:const Icon(Icons.palette_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Appearance':'المظهر'),
     subtitle:WaffraText(widget.appearance=='system'?(waffraIsEnglish?'System default':'حسب إعدادات الجهاز'):
      widget.appearance=='dark'?(waffraIsEnglish?'Dark':'داكن'):(waffraIsEnglish?'Light':'فاتح')),
     trailing:DropdownButton<String>(value:widget.appearance,underline:const SizedBox.shrink(),
      onChanged:(value){if(value!=null)widget.onAppearance(value);},
      items:[
       DropdownMenuItem(value:'system',child:WaffraText(waffraIsEnglish?'System default':'حسب الجهاز')),
       DropdownMenuItem(value:'light',child:WaffraText(waffraIsEnglish?'Light':'فاتح')),
       DropdownMenuItem(value:'dark',child:WaffraText(waffraIsEnglish?'Dark':'داكن')),
      ])),
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
    SwitchListTile(secondary:const Icon(Icons.preview_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Protect Recent Apps preview':'حماية معاينة التطبيقات الأخيرة'),
     value:protectRecentApps,onChanged:_setRecentAppProtection),
    ValueListenableBuilder<bool>(valueListenable:allowWaffraScreenshots,
     builder:(context,allowed,_)=>SwitchListTile(
      secondary:const Icon(Icons.screenshot_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Allow screenshots':'السماح بلقطات الشاشة'),
      subtitle:WaffraText(allowed?(waffraIsEnglish?'Allowed':'مسموح'):(waffraIsEnglish?'Blocked':'ممنوع')),
      value:allowed,onChanged:(v)async{await setWaffraScreenshotsAllowed(v);if(mounted)setState((){});}))
   ]),
   _accountSection(waffraIsEnglish?'Financial tools':'الأدوات المالية',Icons.account_balance_wallet_outlined,[
    _accountTile(waffraIsEnglish?'Financial calendar':'التقويم المالي',
     waffraIsEnglish?'Transactions and recurring dates':'المعاملات ومواعيد العمليات المتكررة',
     Icons.calendar_month_outlined,onTap:openFinancialCalendar),
    _accountTile(waffraIsEnglish?'Subscription insights':'كشف الاشتراكات',
     waffraIsEnglish?'Recurring costs and possible subscriptions':'المدفوعات الدورية والاشتراكات المحتملة',
     Icons.subscriptions_outlined,onTap:openSubscriptionInsights),
   ]),
   _accountSection(waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات',Icons.cloud_outlined,[
    _accountTile(waffraIsEnglish?'Encrypted backup & restore':'النسخ الاحتياطي المشفر والاستعادة',
     lastBackupGeneratedAt==null?(waffraIsEnglish?'No encrypted backup generated yet':'لم يتم إنشاء نسخة مشفرة بعد'):
      (waffraIsEnglish?'Last encrypted copy: ':'آخر نسخة مشفرة: ')+dayText(DateTime.tryParse(lastBackupGeneratedAt!)?.toLocal()??DateTime.now())+
       ' • ${((lastBackupBytes??0)/1024).toStringAsFixed(1)} KB',
     Icons.backup_outlined,onTap:backupDialog),
    _accountTile(waffraIsEnglish?'Delete financial data':'حذف البيانات المالية',
     waffraIsEnglish?'Fingerprint verification and final confirmation required':'يتطلب البصمة وتأكيد الحذف النهائي',
     Icons.delete_forever,tint:Colors.red,onTap:eraseFinancialData),
   ]),
   _accountSection(waffraIsEnglish?'Help & about':'المساعدة وعن وفرة',Icons.help_outline_rounded,[
    _accountTile(waffraIsEnglish?'Replay app tour':'إعادة الجولة التعريفية',
     waffraIsEnglish?'Learn Waffra features':'تعرف على خصائص وفرة',
     Icons.help_outline,onTap:beginTour),
    _accountTile(waffraIsEnglish?'About Waffra':'عن وفرة',
     waffraIsEnglish?'On-device financial management':'إدارة مالية تحفظ بياناتك محليًا',
     Icons.info_outline,onTap:()=>showAboutDialog(context:context,applicationName:'وفرة | Waffra',
      children:[WaffraText(waffraIsEnglish?'No bank account integration. Your data stays on your device.':
       'لا يوجد ربط بالحسابات البنكية؛ بياناتك محفوظة على جهازك.')]))
   ]),
   const SizedBox(height:15),
   OutlinedButton.icon(style:OutlinedButton.styleFrom(
    foregroundColor:(isGuest)?emerald:Colors.red,
    side:BorderSide(color:(isGuest)?emerald:Colors.red)),
    onPressed:()async{
     if(isGuest){await widget.onLogout();return;}
     final ok=await confirm(waffraIsEnglish?'Sign out?':'تسجيل الخروج',
      waffraIsEnglish?'Your financial data stays on this device.':'ستبقى بياناتك المالية محفوظة على الجهاز.');
     if(ok==true&&mounted)await widget.onLogout();
    },
    icon:Icon((isGuest)?Icons.login:Icons.logout),
    label:WaffraText((isGuest)?
     (waffraIsEnglish?'Sign in':'تسجيل الدخول'):(waffraIsEnglish?'Sign out':'تسجيل الخروج'))),
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
  color:Theme.of(context).brightness==Brightness.dark?const Color(0xFF087A54):Colors.white,
  elevation:7,shadowColor:Colors.black12,
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(25),side:BorderSide(color:Theme.of(context).brightness==Brightness.dark?const Color(0xFF89E0BB):forest,width:1.2)),
  child:InkWell(
   onTap:onTap,
   borderRadius:BorderRadius.circular(25),
   child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     Icon(icon,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest,size:21),
     const SizedBox(width:10),
     WaffraText(label,style:TextStyle(
      fontSize:15,fontWeight:FontWeight.bold,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest)),
    ]))));
 Widget currentTab(){
  switch(tab){
   case 0:return goalsOpened?goalsPage():dashboard();
   case 1:return categoriesPage();
   case 2:return goalsPage();
   case 3:return recurringPage();
   default:return profilePage();
  }
 }
 void _swipeBetweenSections(DragEndDetails details){
  if(!ready||goalsOpened||tourActive)return;
  final velocity=details.primaryVelocity??0;
  final dx=_swipeTravel.abs()>50?_swipeTravel:velocity/10;
  if(dx.abs()<65)return;
  final forward=waffraIsEnglish?dx>0:dx<0;
  final target=(tab+(forward?1:-1)).clamp(0,4);
  if(target!=tab)unawaited(selectFooter(target));
 }
 Future<void> selectFooter(int target)async {
  if(target<0||target>=WaffraFooterNavigation.itemCount)return;
  if(mounted)setState((){tab=target;goalsOpened=false;addFabExpanded=false;_headerCompact=false;});
 }
 @override Widget build(BuildContext context)=>Stack(children:[Scaffold(
  appBar:AppBar(
   toolbarHeight:_headerCompact?52:64,
   flexibleSpace:const ColoredBox(color:forest),
   leading:goalsOpened?IconButton(tooltip:waffraIsEnglish?'Back to home':'العودة للرئيسية',
    icon:const Icon(Icons.arrow_back),onPressed:()=>setState(()=>goalsOpened=false)):null,
   titleSpacing:12,
   title:Row(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.spa_rounded,color:Colors.white,size:26),
    const SizedBox(width:7),
    Flexible(child:WaffraText(waffraIsEnglish?'Waffra':'وفرة',
     maxLines:1,style:TextStyle(color:Colors.white,
      fontWeight:FontWeight.bold,fontSize:_headerCompact?19:22))),
   ]),
   actions:[
    Tooltip(message:waffraIsEnglish?'Switch to Arabic':'Switch to English',
     child:TextButton(
      onPressed:()=>widget.onLanguage(waffraIsEnglish?'ar':'en'),
      style:TextButton.styleFrom(
       foregroundColor:Colors.white,minimumSize:const Size(43,37),
       padding:const EdgeInsets.symmetric(horizontal:8),
       backgroundColor:Colors.white.withValues(alpha:.11),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
      child:Text(waffraIsEnglish?'AR':'EN',
       style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))),
    const SizedBox(width:7),
    SizedBox(width:45,height:kToolbarHeight,
     child:Center(child:InkWell(
      onTap:()=>setState((){
       addFabExpanded=false;goalsOpened=false;tab=4;
      }),
      borderRadius:BorderRadius.circular(30),
      child:waffraAvatar(widget.profile.gender,widget.profile.avatar,radius:18)))),
    const SizedBox(width:7),
   ]),
  // Instant content swap avoids building/animating the previous heavy tab
  // alongside the next one (the recurring -> savings navigation hitch).
  body:!ready?const Center(child:CircularProgressIndicator()):
   GestureDetector(
    behavior:HitTestBehavior.translucent,
    onHorizontalDragStart:(_)=>_swipeTravel=0,
    onHorizontalDragUpdate:(details)=>_swipeTravel+=details.delta.dx,
    onHorizontalDragEnd:_swipeBetweenSections,
    child:ValueListenableBuilder<bool>(
     valueListenable:hideWaffraAmounts,
     builder:(context,hidden,_)=>TweenAnimationBuilder<double>(
      key:ValueKey('waffra-page-$tab'),tween:Tween<double>(begin:0,end:1),
      duration:waffraMotion(240),curve:Curves.easeOutCubic,
      builder:(ctx,progress,child)=>Opacity(opacity:progress,
       child:Transform.translate(offset:Offset((1-progress)*(waffraIsEnglish?16:-16),0),child:child)),
      child:currentTab()))),
  // Keep the add menu and its original actions above five destinations.
  floatingActionButtonLocation:const WaffraPhysicalLeftFab(),
  floatingActionButton:!ready||tab==4?null:Directionality(
   textDirection:TextDirection.ltr,child:Column(
   mainAxisSize:MainAxisSize.min,
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    AnimatedSize(duration:const Duration(milliseconds:210),
     curve:Curves.easeOutCubic,
     alignment:Alignment.bottomLeft,
     child:addFabExpanded&&(tab==0||tab==1)&&!goalsOpened?Padding(
      padding:const EdgeInsets.only(bottom:9),
      child:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(tab==0&&!goalsOpened)...[
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
          onTap:(){setState(()=>addFabExpanded=false);chooseCategoryLevel(income:true);}),
         const SizedBox(height:7),
         _addMenuOption(icon:Icons.trending_down,
          label:waffraIsEnglish?'Expense category':'إضافة قسم مصروفات',
          onTap:(){setState(()=>addFabExpanded=false);chooseCategoryLevel(income:false);}),
        ],
       ])):const SizedBox.shrink()),
    Material(
     color:forest,elevation:7,
     shadowColor:Colors.black26,
     shape:const CircleBorder(),
     child:InkWell(
      customBorder:const CircleBorder(),
      onTap:(){
       if(goalsOpened||tab==2){goalDialog();return;}
       if(tab==3){recurringDialog();return;}
       setState(()=>addFabExpanded=!addFabExpanded);
      },
      child:SizedBox(key:_tourKeys[1],width:58,height:58,
       child:AnimatedRotation(
        duration:const Duration(milliseconds:210),
        turns:addFabExpanded?0.125:0,
        child:Icon(addFabExpanded?Icons.close:Icons.add,
         color:Colors.white,size:28))),
     )),
   ])),
  bottomNavigationBar:WaffraFooterNavigation(
   selectedIndex:tab,
   english:waffraIsEnglish,
   onSelected:(selected)=>unawaited(selectFooter(selected)),
   profileSpotlightKey:_tourKeys[5],
  )),
  if(tourActive&&tourTargetReady)Positioned.fill(child:tourOverlay()),
  ]);
}
/// Positions the expandable plus menu physically on the left in RTL
/// and LTR, independent of Scaffold's locale-sensitive start/end anchors.
/// A coach-mark scrim with a transparent focus over the current page.
class WaffraTourShade extends CustomPainter {
 final Rect focus;
 final double glow;
 const WaffraTourShade(this.focus,{this.glow=0});
 @override void paint(Canvas canvas,Size size){
  final border=RRect.fromRectAndRadius(focus,const Radius.circular(20));
  final shade=Path()..fillType=PathFillType.evenOdd
   ..addRect(Offset.zero & size)..addRRect(border);
  canvas.drawPath(shade,Paint()..color=Colors.black.withValues(alpha:.61));
  canvas.drawRRect(border,Paint()..color=const Color(0xFF65E5AD).withValues(alpha:.15+.30*glow)
   ..style=PaintingStyle.stroke..strokeWidth=7+5*glow..maskFilter=const MaskFilter.blur(BlurStyle.normal,7));
  canvas.drawRRect(border,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2+glow);
 }
 @override bool shouldRepaint(covariant WaffraTourShade old)=>old.focus!=focus||old.glow!=glow;
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
  var maximum=1.0;
  for(final p in points){
   maximum=max(maximum,max(p.income,p.expense));
  }
  final step=max(1.0,(maximum/4).ceilToDouble());
  final textColor=Theme.of(context).colorScheme.onSurface;
  final chartWidth=max(MediaQuery.sizeOf(context).width-95.0,points.length*70.0);
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(mainAxisAlignment:MainAxisAlignment.center,children:[
    Icon(Icons.square,color:waffraIncomeTone(context),size:15),
    WaffraText(waffraIsEnglish?' Income  ':' دخل  '),
    const Icon(Icons.square,color:Colors.deepOrange,size:15),
    WaffraText(waffraIsEnglish?' Expenses':' مصروفات'),
   ]),
   const SizedBox(height:5),
   WaffraText(waffraIsEnglish?'Y-axis: amount (SAR)  •  X-axis: time period':
    'المحور الرأسي: المبلغ (ريال)  •  المحور الأفقي: الفترة الزمنية',
    textAlign:TextAlign.center,style:const TextStyle(fontSize:10)),
   const SizedBox(height:13),
   SingleChildScrollView(scrollDirection:Axis.horizontal,
    child:SizedBox(width:chartWidth,height:240,child:BarChart(BarChartData(
     alignment:BarChartAlignment.spaceAround,
     minY:0,maxY:step*4.5,
     gridData:FlGridData(show:true,drawVerticalLine:false,horizontalInterval:step),
     borderData:FlBorderData(show:true,border:Border(
      left:BorderSide(color:textColor.withValues(alpha:.4)),
      bottom:BorderSide(color:textColor.withValues(alpha:.4)))),
     barTouchData:BarTouchData(enabled:true),
     titlesData:FlTitlesData(
      topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
      rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
      leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,
       reservedSize:46,interval:step,
       getTitlesWidget:(value,meta)=>Padding(
        padding:const EdgeInsets.only(right:4),
        child:Text(value.toStringAsFixed(0),style:TextStyle(color:textColor,fontSize:10))))),
      bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,
       reservedSize:40,
       getTitlesWidget:(value,meta){
        final i=value.toInt();
        if(i<0||i>=points.length||i.toDouble()!=value)return const SizedBox.shrink();
        return Padding(padding:const EdgeInsets.only(top:9),
         child:Text(points[i].label,style:TextStyle(color:textColor,fontSize:10),
          textAlign:TextAlign.center,maxLines:2));
       })),
     ),
     barGroups:List.generate(points.length,(i)=>BarChartGroupData(x:i,
      barsSpace:3,barRods:[
       BarChartRodData(toY:points[i].income,color:waffraIncomeTone(context),width:13,
        borderRadius:const BorderRadius.vertical(top:Radius.circular(5))),
       BarChartRodData(toY:points[i].expense,color:Colors.deepOrange,width:13,
        borderRadius:const BorderRadius.vertical(top:Radius.circular(5))),
      ])),
    )))),
  ]);
 }
}
