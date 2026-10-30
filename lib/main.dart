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
import 'package:flutter/foundation.dart';
import 'waffra_financial_tools.dart';
import 'waffra_smart_features.dart';
import 'waffra_tour_plan.dart';
import 'waffra_today_picker.dart';
import 'waffra_action_layout.dart';
import 'waffra_subtle_selection.dart';
import 'waffra_receipt_filename.dart';
import 'waffra_receipt_ocr.dart';
import 'waffra_receipt_ocr_parser.dart';
import 'waffra_bank_screenshot_parser.dart';
import 'waffra_ai_finance_brain.dart';
import 'waffra_ondevice_qwen.dart';
import 'waffra_ai_model_gate.dart';
import 'waffra_sms_intelligence.dart';
import 'waffra_sms_multicurrency_review.dart';
import 'waffra_back_navigation.dart';
import 'waffra_saudi_greetings.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_amount_formatter.dart';
import 'waffra_display_currency.dart';
import 'waffra_phone_country_codes.dart';
import 'waffra_google_phone_field.dart';
import 'waffra_country_first_run_page.dart';
import 'waffra_regional_copy.dart';
import 'waffra_search.dart';
import 'waffra_balance_art.dart';
import 'waffra_validators.dart';
import 'waffra_financial_insights.dart';
import 'waffra_reminders.dart';
import 'waffra_welcome_background.dart';
import 'currency_converter.dart';
import 'waffra_i18n.dart';
import 'waffra_riyal_symbol.dart';
import 'waffra_pdf_text.dart';
import 'waffra_merchant_rules.dart';
import 'waffra_google_auth.dart';
import 'waffra_account_deletion.dart';
import 'diagnostics/waffra_crashlytics_opt_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'waffra_category_catalog.dart';
import 'waffra_goal_catalog.dart';
import 'waffra_pdf_reader.dart';
import 'waffra_footer.dart';
import 'waffra_messages.dart';
import 'waffra_recurring_policy.dart';
import 'waffra_cross_source_duplicate_review.dart';
import 'waffra_secure_backup.dart';
import 'waffra_backup_files.dart';
import 'storage/waffra_legacy_write_queue.dart';
import 'storage/waffra_authoritative_widget_balance.dart';
import 'storage/waffra_live_legacy_finance_guard.dart';
import 'storage/waffra_production_finance_source_guard.dart';
import 'storage/waffra_legacy_finance_writer_coordinator.dart';
import 'storage/waffra_live_account_write_authority.dart';
import 'storage/waffra_legacy_widget_commit_journal.dart';
import 'storage/waffra_home_finance_persistence.dart';
import 'storage/waffra_verified_finance_authority.dart';
import 'storage/waffra_production_finance_authority_binding.dart';
import 'storage/waffra_fresh_finance_modules_repository.dart';
import 'storage/waffra_verified_module_ui_guard.dart';
import 'storage/waffra_runtime_finance_route_contract.dart';
import 'storage/waffra_verified_transaction_ui_guard.dart';
import 'storage/waffra_m155_category_plan.dart';
import 'storage/waffra_sms_partial_save_recovery.dart';
import 'storage/waffra_production_finance_routing_gate.dart';
import 'storage/waffra_verified_legacy_backup_restore.dart';
import 'waffra_home_widget.dart';
import 'waffra_pull_refresh_scroll_settle.dart';
import 'waffra_haptic_feedback.dart';
import 'waffra_smooth_confirmation.dart';
part 'waffra_categories_page.part.dart';
part 'waffra_smart_analysis.part.dart';
part 'waffra_recurring_trash.part.dart';
part 'waffra_deleted_item_card.part.dart';
part 'waffra_widget_capture.part.dart';

Future<Map<String,dynamic>> waffraDecodeBackupInIsolate(Map<String,String> request) async {
 final decoded=jsonDecode(await WaffraSecureBackup.decrypt(
  request['payload']!,request['password']!));
 if(decoded is! Map)throw const FormatException('Invalid backup document');
 return Map<String,dynamic>.from(decoded);
}

Future<String> waffraEncryptBackupInIsolate(Map<String,String> request) =>
 WaffraSecureBackup.encryptUserBackup(request['payload']!,request['password']!);

// CI compile-only preview is NOT a Firebase-registered Waffra Android build.
// Never imply that its Google sign-in can authenticate a production user.
const bool waffraCompileOnlyQaPreview =
 bool.fromEnvironment('WAFFRA_COMPILE_ONLY_PREVIEW',defaultValue:false);
String waffraGooglePreviewNotice(bool english)=>english
 ?'Google sign-in needs the signed Waffra build. Try guest mode in this preview.'
 :'دخول جوجل يتطلب نسخة وفرة الموقّعة. استخدم وضع الضيف للمعاينة.';

Future<void> main()async {
 WidgetsFlutterBinding.ensureInitialized();
 // Flutter engine started by the circular Android widget, not the normal app.
 if(WidgetsBinding.instance.platformDispatcher.defaultRouteName=='/waffra-widget'){
  runApp(const WaffraWidgetCaptureApp());
  return;
 }
 // Native Android manifest disables automatic crash collection on startup.
 try {
  if(Firebase.apps.isEmpty)await Firebase.initializeApp();
  await WaffraCrashlyticsOptIn.synchronize();
 }catch(_){
  debugPrint('Optional crash telemetry remains unavailable.');
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
String cash(num value)=>hideWaffraAmounts.value?'***':WaffraDisplayCurrency.money(value,english:waffraIsEnglish);
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
/// App-wide presentation currency changes only the unit caption, never its
/// numeric value. The currency-converter tool alone performs real FX.
/// Bank SMS parsing always uses the original unmodified amount.
double? amountOfDisplay(String text){
 final n=amountOf(text);
 return n==null?null:WaffraDisplayCurrency.toLedgerSar(n);
}
String formatWaffraEditAmount(num sar){
 final converted=WaffraDisplayCurrency.convert(sar);
 return converted==null?'':formatWaffraMoney(converted);
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
    WaffraText(hidden?'***':'$prefix${WaffraDisplayCurrency.amount(amount)}',style:effective),
    if(!hidden)...[
     const SizedBox(width:4),
     WaffraCurrencyMark(english:waffraIsEnglish,
      currencyCode:WaffraDisplayCurrency.country.code,
      arabicLabel:WaffraDisplayCurrency.country.symbolAr,
      size:size*.9,color:color),
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
 /// Internal merchant identifier is a merchant *name*, never a bank/card ID.
 final String notes,sourceType,merchantKey;
 MoneyEntry({required this.id,required this.title,required this.category,required this.amount,
  required this.income,required this.date,this.receiptPath,this.notes='',
  this.sourceType='manual',this.merchantKey=''});
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,
  'amount':amount,'income':income,'date':date.toIso8601String(),
  'receiptPath':receiptPath,'notes':notes,'sourceType':sourceType,
  'merchantKey':merchantKey};
 factory MoneyEntry.fromJson(Map<String,dynamic> j)=>MoneyEntry(
  id:'${j['id']??newId()}',title:'${j['title']??''}',
  category:'${j['category']??'أخرى'}',amount:(j['amount'] as num).toDouble(),
  income:j['income']==true,date:DateTime.tryParse('${j['date']}')??DateTime.now(),
  receiptPath:j['receiptPath']?.toString(),
  notes:'${j['notes']??''}',sourceType:'${j['sourceType']??'legacy'}',
  merchantKey:'${j['merchantKey']??''}');
 /// Category rename is metadata-only; protect SMS notes, source identity,
 /// merchant key, original timestamp and receipt references.
 MoneyEntry withCategory(String next)=>MoneyEntry(
  id:id,title:title,category:next,amount:amount,income:income,date:date,
  receiptPath:receiptPath,notes:notes,sourceType:sourceType,
  merchantKey:merchantKey);
}

/// Legacy messages may already have longer titles. Unchanged titles must
/// never block edits to an attachment, category or other unrelated field.
bool waffraTransactionTitleAllowed(String newTitle,{String? oldTitle}) {
 final trimmed=newTitle.trim();
 if(trimmed.isEmpty)return false;
 return trimmed.runes.length<=250||oldTitle!=null&&oldTitle==trimmed;
}
bool waffraTransactionNotesAllowed(String notes,{String? oldNotes}) =>
 notes.runes.length<=2000||oldNotes!=null&&oldNotes==notes;

class Person {
 final String name,email,provider,gender,avatar,phone;final DateTime birthday;
 Person({required this.name,required this.email,required this.provider,required this.gender,required this.avatar,required this.birthday,this.phone=''});
 Map<String,dynamic> toJson()=>{'name':name,'email':email,'provider':provider,'gender':gender,'avatar':avatar,'phone':phone,'birthday':birthday.toIso8601String()};
 factory Person.fromJson(Map<String,dynamic> j)=>Person(name:'${j['name']??''}',email:'${j['email']??''}',provider:'${j['provider']??'محلي'}',gender:['ذكر','أنثى'].contains(j['gender'])?'${j['gender']}':'',avatar:'${j['avatar']??'person'}',phone:'${j['phone']??(j['provider']=='Phone'?j['email']??'':'')}',birthday:DateTime.tryParse('${j['birthday']}')??DateTime(2000));
}
class BudgetCategory {
 final String id,name,icon,parentId,origin;
 final int color;final bool income;final double budget;final int alertPercent;
 BudgetCategory({required this.id,required this.name,required this.icon,required this.color,required this.income,this.parentId='',this.budget=0,this.alertPercent=80,this.origin='system'});
 bool get isUserAdded=>origin=='user';
 bool get isSubcategory=>parentId.isNotEmpty;
 String get displayName=>isSubcategory?name.split(' / ').last:name;
 BudgetCategory copy({String? name,String? icon,int? color,double? budget,int? alertPercent,String? parentId})=>BudgetCategory(id:id,name:name??this.name,icon:icon??this.icon,color:color??this.color,income:income,parentId:parentId??this.parentId,budget:budget??this.budget,alertPercent:alertPercent??this.alertPercent,origin:origin);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'icon':icon,'color':color,'income':income,'parentId':parentId,'budget':budget,'alertPercent':alertPercent,'origin':origin};
 factory BudgetCategory.fromJson(Map<String,dynamic> j)=>BudgetCategory(id:'${j['id']??newId()}',name:'${j['name']??'أخرى'}',icon:'${j['icon']??'category'}',color:(j['color'] as num?)?.toInt()??0xFF087A54,income:j['income']==true,parentId:'${j['parentId']??''}',budget:(j['budget'] as num?)?.toDouble()??0,alertPercent:(j['alertPercent'] as num?)?.toInt()??80,origin:j['origin']=='user'?'user':j['origin']=='detected'?'detected':'system');
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
 RecurringBill withCategory(String next)=>RecurringBill(
  id:id,title:title,category:next,amount:amount,income:income,day:day,
  active:active,startAt:startAt);
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
/// Fresh per-paste summary, independent of previous parsing results.
class WaffraSmsPasteSummary {
 const WaffraSmsPasteSummary(this.detected,this.fresh,this.duplicates,this.excluded);
 final int detected,fresh,duplicates,excluded;
}
WaffraSmsPasteSummary waffraSummarizeBankPaste(String raw,Set<String> savedHashes){
 final seen=<String>{};
 var detected=0,fresh=0,duplicates=0,excluded=0;
 for(final msg in splitBankMessages(raw.trim())){
  final result=BankParser.parse(msg);
  if(result.amount==null||result.amount!<=0){excluded++;continue;}
  detected++;
  final hash=bankSmsHash(msg);
  if(savedHashes.contains(hash)||!seen.add(hash)){duplicates++;continue;}
  fresh++;
 }
 return WaffraSmsPasteSummary(detected,fresh,duplicates,excluded);
}
class BankResult {
 final double? amount;final bool income;final String title,category;final String? suggestedCategory;
 final String? currencyCode;
 final double? mlConfidence;
 final bool requiresCurrencyReview;
 BankResult(this.amount,this.income,this.title,this.category,this.suggestedCategory,{
  this.currencyCode,this.mlConfidence,this.requiresCurrencyReview=false,
 });
}
/// Pure, batch-only parser used by compute() for larger SMS pastes.
/// Results and stored bank amounts are identical to the single-message path.
List<BankResult> waffraParseBankSmsBatchInIsolate(List<String> messages)=>
 messages.map(BankParser.parse).toList(growable:false);

class BankParser {
 static BankResult parse(String original) {
  final s=digits(original).replaceAll('\u200f','').replaceAll('\u200e','').replaceAll('\u00a0',' ');
  // English bank SMS types must be classified from their first line, not
  // from merchant names, remaining balance, or unrelated message body text.
  final header=s.trimLeft().split('\n').first.trim();
  const unconfirmed=r'(?:Online\s+Pre[-\s]?Auth(?:ori[sz]ation)?|Pre[-\s]?Authori[sz]ation|Authorization\s+Hold|Please\s+use\s+the\s+code|OTP|Verification\s+Code|Declined\s+Transaction|Transaction\s+Declined|Failed\s+Transaction|Transaction\s+Failed|Unsuccessful\s+Transaction)';
  final failedStatus=RegExp(r'^\s*(?:Transaction\s+)?Status\s*[:：]\s*(?:Pending|Declined|Failed|Rejected|Cancelled|Canceled)\b',caseSensitive:false,multiLine:true);
  if(RegExp('^$unconfirmed\\b',caseSensitive:false).hasMatch(header)||failedStatus.hasMatch(s)){
   return BankResult(null,false,'إشعار غير مؤكد','أخرى',null);
  }
  // Current finance records lack original currency and a verified FX
  // witness. Never auto-import a foreign-currency SMS as Saudi riyals.
  final discoveredCurrencies=WaffraSmsCurrencies.currenciesForMessage(s);
  if(WaffraSmsCurrencies.requiresReviewForSarLedger(s)){
    // Preserve direction while blocking foreign amount from SAR-only ledger.
    final credited=RegExp(
      r'\b(?:credited|received|incoming|deposited|refund)\b|'
      r'حوال[ةه].{0,25}وارد|تحويل.{0,25}وارد|إيداع|ايداع|راتب',
      caseSensitive:false).hasMatch(s);
    final debited=RegExp(
      r'\b(?:debited|outgoing|purchase|spent|withdrawn)\b|'
      r'حوال[ةه].{0,25}صادر|تحويل.{0,25}صادر|شراء|خصم|سحب',
      caseSensitive:false).hasMatch(s);
    final incoming=credited&&!debited;
    return BankResult(null,incoming,
      incoming?'حوالة واردة':'معاملة بعملة تحتاج مراجعة',
      incoming?'دخل آخر':'أخرى',null,
      currencyCode:discoveredCurrencies.length==1
       ?discoveredCurrencies.single:null,
      requiresCurrencyReview:true);
  }
  // Credit Transfer is incoming; Credit Card Purchase remains an expense.
  const credits=r'(?:Credit\s+Transfer|Credit\s+via\s+(?:(?:local|domestic|international|bank|internal)\s+)?transfer|Incoming\s+(?:Bank\s+)?Transfer|Transfer\s+Received|Transfer\s+In|Funds\s+Received|Money\s+Received|Account\s+Credited|Salary\s+(?:Credit|Deposit)|Cash\s+Deposit|Refund\s+(?:Received|Processed)|Refund|Reversal\s+Credit)';
  const debits=r'(?:Online\s+Purchase(?:\s+Card)?|Purchase\s+Card|Card\s+Purchase|Credit\s+Card\s+Purchase|POS\s+(?:Purchase|Transaction)|Debit\s+Transfer|Outgoing\s+Transfer|Transfer\s+(?:Sent|Out|To)|Money\s+Sent|Debit\s+Card\s+Purchase|Card\s+Payment|ATM\s+Withdrawal|Cash\s+Withdrawal|Bill\s+Payment|Direct\s+Debit|Payment\s+(?:Completed|Successful))';
  final englishIncoming=RegExp('^$credits\\b',caseSensitive:false).hasMatch(header);
  final englishOutgoing=RegExp('^$debits\\b',caseSensitive:false).hasMatch(header);
  final legacyIncoming=RegExp(r'حوال[ةه].{0,25}وارد|تحويل.{0,25}وارد|استلام.{0,25}حوال|credited|deposit|راتب|إيداع|ايداع',caseSensitive:false).hasMatch(s);
  final legacyOutgoing=RegExp(r'حوال[ةه].{0,25}صادر|تحويل.{0,25}صادر|شراء|نقاط\s*بيع|pos\b|مدى|سحب|خصم|دفع|فاتورة|purchase|debit\b',caseSensitive:false).hasMatch(s);
  // A trainable no-cost offline classifier covers previously unseen global
  // headings. Existing successful Saudi and English formats remain unchanged.
  // Currency mismatch never silently corrupts the SAR ledger.
  if(!englishIncoming&&!englishOutgoing&&!legacyIncoming&&!legacyOutgoing){
   final smart=WaffraSmsIntelligence.classify(s);
   if(smart.intent!=WaffraSmsIntent.uncertain){
    final receive=smart.intent==WaffraSmsIntent.incoming;
    return BankResult(smart.canAutoSuggestSar?smart.amount:null,receive,
     receive?'حوالة واردة':'معاملة مالية صادرة',
     receive?'دخل آخر':'تحويلات',null,
     currencyCode:smart.currency,
     mlConfidence:smart.confidence,
     requiresCurrencyReview:smart.requiresCurrencyReview);
   }
  }
  final income=englishIncoming||(legacyIncoming&&!englishOutgoing&&!legacyOutgoing);
  // Amount-only English notices lack evidence of direction: review, don't
  // fabricate a confirmed expense.
  if(!income&&!englishOutgoing&&!legacyOutgoing&&
     RegExp(r'^(?:Amount|Amt)\s*[:：]',caseSensitive:false).hasMatch(header)){
   return BankResult(null,false,'عملية تحتاج مراجعة','أخرى',null);
  }
  const n=r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';
  const currency=r'(?:SAR|SR|ر\.?\s*س\.?|ريال(?:\s*سعودي)?|﷼|⃁)';
  // Prefer the explicit transaction amount over remaining balance or fees.
  final patterns=[
   RegExp('(?:^|\\n)\\s*(?:Amount|Amt|المبلغ|مبلغ)\\s*[:：-]?\\s*$n\\s*$currency',caseSensitive:false,multiLine:true),
   RegExp('(?:^|\\n)\\s*(?:Amount|Amt|المبلغ|مبلغ)\\s*[:：-]?\\s*$currency\\s*$n',caseSensitive:false,multiLine:true),
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
  if(RegExp(r'راتب|salary',caseSensitive:false).hasMatch(header)){title='راتب';cat='راتب';}
  else if(income){
   title=RegExp(r'refund|reversal',caseSensitive:false).hasMatch(header)?'مبلغ وارد':'حوالة واردة';
  }
  else if(RegExp(r'شراء|pos\b|مدى|mada|purchase|card\s+payment',caseSensitive:false).hasMatch(header)){title='شراء نقاط بيع';cat='تسوّق';}
  else if(RegExp(r'حوال[ةه]|تحويل|debit\s+transfer|outgoing\s+transfer|transfer\s+(?:sent|out|to)',caseSensitive:false).hasMatch(header)){title='حوالة صادرة';cat='تحويلات';}
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
  // A recognized foreign-currency amount must never inherit the SAR ledger
  // unit. Preserve direction and title, but require a human-reviewed SAR
  // conversion before any writer is allowed to persist an amount.
  if(value==null){
   final global=WaffraSmsIntelligence.classify(s);
   if(global.requiresCurrencyReview){
    return BankResult(null,income,title,cat,suggestion,
     currencyCode:global.currency,mlConfidence:global.confidence,
     requiresCurrencyReview:true);
   }
  }
  return BankResult(value,income,title,cat,suggestion);
 }
}
DateTime? bankSmsDate(String raw) {
 final normalized=digits(raw).replaceAll('‏','').replaceAll('‎','');
 // English MADA and transfers use ISO YYYY-MM-DD, not legacy DD/MM/YY.
 final iso=RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})\b').firstMatch(normalized);
 if(iso!=null){
  final year=int.tryParse(iso.group(1)!),month=int.tryParse(iso.group(2)!),
   day=int.tryParse(iso.group(3)!),hour=int.tryParse(iso.group(4)!),
   minute=int.tryParse(iso.group(5)!);
  if(year==null||month==null||day==null||hour==null||minute==null||
   year<2000||year>2100||month<1||month>12||day<1||day>31||
   hour>23||minute>59)return null;
  final date=DateTime(year,month,day,hour,minute);
  return date.year==year&&date.month==month&&date.day==day?date:null;
 }
 final match=RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{1,4})\s+(\d{1,2}):(\d{2})').firstMatch(normalized);
 if(match==null)return null;
 final a=int.tryParse(match.group(1)!),b=int.tryParse(match.group(2)!),
  c=int.tryParse(match.group(3)!);
 final hour=int.tryParse(match.group(4)!),minute=int.tryParse(match.group(5)!);
 if(a==null||b==null||c==null||hour==null||minute==null)return null;
 final isTransfer=RegExp(r'حوال[ةه]|تحويل|transfer',caseSensitive:false).hasMatch(raw);
 final year=isTransfer?(a<100?2000+a:a):(c<100?2000+c:c);
 final month=b,day=isTransfer?c:a;
 if(year<2000||year>2100||month<1||month>12||day<1||day>31||
  hour>23||minute>59)return null;
 final date=DateTime(year,month,day,hour,minute);
 return date.year==year&&date.month==month&&date.day==day?date:null;
}
String bankSmsHash(String raw)=>sha256.convert(utf8.encode(digits(raw).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
List<String> splitBankMessages(String raw){
 final clean=raw.replaceAll('\r\n','\n').replaceAll('\u200f','').replaceAll('\u200e','').trim();
 if(clean.isEmpty)return [];
 // Bank SMS messages often start with a transaction heading, even without dates.
 // Separate all posted and unposted notices by header, without relying
 // on blank lines (which also occur *inside* one bank SMS).
 final heading=RegExp(
  r'^\s*(?:Online\s+Purchase(?:\s+Card)?|Online\s+Pre[-\s]?Auth|Pre[-\s]?Authori[sz]ation|Please\s+use\s+the\s+code|Verification\s+Code|OTP\b|Declined\s+Transaction|Transaction\s+Declined|Failed\s+Transaction|Transaction\s+Failed|Unsuccessful\s+Transaction|Incoming\s+Transfer|Outgoing\s+Transfer|Transfer\s+(?:Received|Sent|In|Out|To)|Funds\s+Received|Money\s+(?:Received|Sent)|Account\s+Credited|Salary\s+(?:Credit|Deposit)|Cash\s+Deposit|Refund|Reversal\s+Credit|ATM\s+Withdrawal|Cash\s+Withdrawal|Bill\s+Payment|Direct\s+Debit|Payment\s+(?:Completed|Successful)|Card\s+(?:Purchase|Payment)|Credit\s+Card\s+Purchase|POS|شراء(?:\s+PoS)?|حوال[ةه]|تحويل|إيداع|ايداع|راتب|سحب|دفع|نقاط بيع|Purchase|Debit|Credit)(?=\s|$|[:：])',
  caseSensitive:false,multiLine:true);
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

/// A gentle, single-stage entrance for the savings-goal dialog.
Future<T?> showWaffraSmoothDialog<T>({
 required BuildContext context,required WidgetBuilder builder,
})=>showGeneralDialog<T>(
 context:context,
 barrierDismissible:true,
 barrierLabel:MaterialLocalizations.of(context).modalBarrierDismissLabel,
 barrierColor:Colors.black.withValues(alpha:.28),
 transitionDuration:waffraMotion(320),
 pageBuilder:(dialogContext,_,__)=>BackdropFilter(
  filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7),
  child:builder(dialogContext)),
 transitionBuilder:(ctx,animation,secondaryAnimation,child){
  final curved=CurvedAnimation(parent:animation,
   curve:Curves.easeOutCubic,reverseCurve:Curves.easeInCubic);
  return FadeTransition(opacity:curved,child:ScaleTransition(
   scale:Tween<double>(begin:.975,end:1).animate(curved),
   child:child));
 },
);

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

// The amount is mandatory whether monthly-budget tracking is enabled or paused.
String? waffraMonthlyBudgetSaveError(String? raw)=>waffraAmountFieldError(raw);

const int waffraDashboardTransactionPreviewLimit=10;
bool waffraCanExpandDashboardTransactions(int filteredCount)=>
 filteredCount>waffraDashboardTransactionPreviewLimit;
int waffraDashboardTransactionDisplayCount(int filteredCount,{required bool expanded})=>
 (expanded&&waffraCanExpandDashboardTransactions(filteredCount))
  ?filteredCount:min(filteredCount,waffraDashboardTransactionPreviewLimit);
String? waffraMobileFieldError(String? raw) {
 if((raw??'').trim().isEmpty)return waffraRequiredFieldMessage;
 return WaffraValidators.mobileNumber(raw)==null?null:(waffraIsEnglish?'Mobile number must start with 05 and contain 10 digits':'رقم الجوال يجب أن يبدأ بـ 05 ويتكون من 10 أرقام');
}
/// Google profiles accept E.164 so Egyptian users can complete signup
/// before granting location; local Saudi phone login remains unchanged.
String? waffraGoogleProfilePhoneError(String? value){
 final raw=(value??'').trim();
 if(raw.isEmpty)return waffraRequiredFieldMessage;
 if(RegExp(r'^05[0-9]{8}$').hasMatch(raw)||
  RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(raw))return null;
 return waffraIsEnglish?
  'Enter 05xxxxxxxx or international number like +201234567890.':
  'أدخل 05xxxxxxxx أو رقمًا دوليًا مثل +201234567890.';
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
/// The one-time country explanation is only eligible after the Google
/// account finished required profile details, never during sign-in or guest.
bool waffraGoogleProfileReadyForCountrySetup(Person? user)=>
 user!=null&&user.provider.toLowerCase()=='google'&&
 user.email.trim().isNotEmpty&&user.name.trim().isNotEmpty&&
 user.phone.trim().isNotEmpty&&user.gender.trim().isNotEmpty;

/// Namespace consent separately for each Google account; do not store raw
/// emails, GPS coordinates or sensitive profile details in preferences.
String waffraCountrySetupKey(Person user){
 final fingerprint=sha256.convert(utf8.encode(
   user.email.trim().toLowerCase())).toString();
 return 'waffra_google_country_setup_v2_${fingerprint.substring(0,20)}';
}

class _WaffraAppState extends State<WaffraApp> with WidgetsBindingObserver {
 bool loading=true,onboarded=false,dark=false,locked=false,showLogin=false;
 bool googleFirstRunSetup=false;
 String appearance='light';
 bool introDone=false;
 int _greetingCycle=0;
 bool _greetingCycleInitialized=false;
 final WaffraDoubleBackExit _doubleBackExit=WaffraDoubleBackExit();
 String language='ar';
 String? pinHash;Person? profile;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);
  WaffraRegionalCopy.countryIso.addListener(_onRegionChanged);load();launchIntro();}
 void _onRegionChanged(){if(mounted)setState((){});}
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
 @override void dispose(){WaffraRegionalCopy.countryIso.removeListener(_onRegionChanged);
  WidgetsBinding.instance.removeObserver(this);super.dispose();}
 String? startupError;
 Future<void> load()async {
  try {
   final p=await SharedPreferences.getInstance().timeout(const Duration(seconds:15));
   await const WaffraProductionFinanceSourceGuard()
    .requireSafeLegacyStartup(preferences:p);
   await const WaffraLiveLegacyFinanceGuard().requireLegacySource(p);
   // Nonfinancial preference only. Rotate once per cold start; retries do not
   // advance the greeting again or bypass the finance source guard.
   if(!_greetingCycleInitialized){
    _greetingCycle=WaffraSaudiGreetings.nextIndex(p.getInt('waffra_greeting_cycle_v1'));
    _greetingCycleInitialized=true;
    try{await p.setInt('waffra_greeting_cycle_v1',_greetingCycle);}
    catch(e){debugPrint('Greeting preference persistence unavailable: $e');}
   }

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
   // Location only affects Arabic copy, independently from the display currency.
   await WaffraRegionalCopy.initialize(p);
   await WaffraDisplayCurrency.initialize();
   allowWaffraScreenshots.value=screenshotsAllowed;
   if(Platform.isAndroid){
    try{await _privacyChannel.invokeMethod<void>('setScreenshotsAllowed',screenshotsAllowed).timeout(const Duration(seconds:3));}
    catch(e){debugPrint('Privacy initialization failed: $e');}
   }
   if(!mounted)return;
   setState((){
    onboarded=p.getBool('waffra_onboarding_completed')??false;
    appearance=p.getString('waffra_appearance_mode_v1')??(p.containsKey('waffra_dark_mode')?(p.getBool('waffra_dark_mode')==true?'dark':'light'):'light');
    if(!{'light','dark','system'}.contains(appearance))appearance='light';
    dark=appearance=='dark'||(appearance=='system'&&WidgetsBinding.instance.platformDispatcher.platformBrightness==Brightness.dark);
    profile=u;
    googleFirstRunSetup=waffraGoogleProfileReadyForCountrySetup(u)&&
      !(p.getBool(waffraCountrySetupKey(u!))??false);
    pinHash=p.getString('waffra_pin_sha256');
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
 // The live account/profile writer must never bypass the same source lock
 // held by Home and the independent Android Widget finance engine.
 final WaffraLiveAccountWriteAuthority _accountWriteAuthority=
     const WaffraLiveAccountWriteAuthority();
 Future<void> saveUser(Person u)async {
  await _accountWriteAuthority.saveProfile(
   profileJson:jsonEncode(u.toJson()),
   registeredProfileJson:u.phone.trim().isNotEmpty?jsonEncode(u.toJson()):null,
   loginMethod:u.provider.toLowerCase().contains('google')?'Google':
    u.provider.toLowerCase().contains('apple')?'Apple':
    u.phone.trim().isNotEmpty?'Phone':'Local',
   email:u.email.trim().isNotEmpty?u.email.trim():null,
   phone:u.phone.trim().isNotEmpty?u.phone.trim():null,
  );
  final prefs=await SharedPreferences.getInstance();
  final needsGoogleSetup=waffraGoogleProfileReadyForCountrySetup(u)&&
    !(prefs.getBool(waffraCountrySetupKey(u))??false);
  if(mounted)setState((){
   profile=u;showLogin=false;googleFirstRunSetup=needsGoogleSetup;
  });
 }
 Future<void> setUiCountry(String? iso)async{
  await WaffraRegionalCopy.setCountry(iso);
 }
 Future<void> completeGoogleCountrySetup(String selectedCurrency)async{
  final account=profile;
  if(!waffraGoogleProfileReadyForCountrySetup(account))return;
  // One-time country onboarding never obtains notification access.
  // Recurring's explicit switch owns notification consent.
  await WaffraDisplayCurrency.setCurrency(selectedCurrency);
  final prefs=await SharedPreferences.getInstance();
  final complete=await prefs.setBool(waffraCountrySetupKey(account!),true);
  if(!complete)throw StateError('Could not save country setup completion.');
  if(mounted)setState(()=>googleFirstRunSetup=false);
 }
 Future<void> logout()async {
  // Drop any in-memory AI prompt context and cancel model download before
  // a new account can open its verified finance scope.
  try{await WaffraOnDeviceQwen.shared.dispose();}catch(_){}
  await _accountWriteAuthority.signOut();
  if(mounted)setState((){profile=null;showLogin=true;locked=false;googleFirstRunSetup=false;});
 }
 Future<void> setPin(String? value)async {
  final hash=value==null?null:sha256.convert(utf8.encode(value)).toString();
  await _accountWriteAuthority.replacePinVerifier(hash);
  if(mounted)setState((){
   pinHash=hash;
   locked=false;
  });
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
  debugShowCheckedModeBanner:false,title:'وفرة | Waffra',
  locale:language=='en'?const Locale('en','US'):
   WaffraRegionalCopy.arabicCountrySubtag.isEmpty?const Locale('ar'):
    Locale('ar',WaffraRegionalCopy.arabicCountrySubtag),
  supportedLocales:const [Locale('ar'),Locale('ar','SA'),Locale('ar','EG'),Locale('en','US')],
  localizationsDelegates:const [
   GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,
   GlobalCupertinoLocalizations.delegate,
  ],
  builder:(context,child)=>ValueListenableBuilder<bool>(
   valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Directionality(
    textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
    // Language is an immediate LTR/RTL layout change, never a
    // navigator replacement or whole-screen slide of the FAB.
    child:child??const SizedBox.shrink())),

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
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,alignment:Alignment.center,
    side:const BorderSide(color:Color(0xFF0C7957),width:1.2),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
    foregroundColor:forest,alignment:Alignment.center,
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,
    side:const BorderSide(color:Color(0xFFB8CDC1),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
    foregroundColor:forest,alignment:Alignment.center,
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,
    side:const BorderSide(color:Color(0xFFB8CDC1),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))),
   inputDecorationTheme:InputDecorationTheme(
    filled:true,fillColor:Colors.white,
    contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:13),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFFCFE3D7))),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:emerald,width:1.5)),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
    labelStyle:const TextStyle(color:forest),hintStyle:const TextStyle(color:Color(0xFF7B9084))),
   segmentedButtonTheme:WaffraSubtleSelection.segmented(Brightness.light),
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
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,
    side:const BorderSide(color:Color(0xFF74DCAB),width:1.1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
    foregroundColor:Colors.white,alignment:Alignment.center,
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,
    side:const BorderSide(color:Color(0xFF658475),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
   textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
    foregroundColor:Colors.white,alignment:Alignment.center,
    minimumSize:WaffraActionLayout.minimumSize,
    padding:WaffraActionLayout.contentPadding,
    side:const BorderSide(color:Color(0xFF658475),width:1),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))),
   inputDecorationTheme:InputDecorationTheme(
    filled:true,fillColor:const Color(0xFF202522),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFF4A6052))),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
     borderSide:const BorderSide(color:Color(0xFF8EDDB5),width:1.5)),
    labelStyle:const TextStyle(color:Color(0xFFE6FFF0)),
    hintStyle:const TextStyle(color:Color(0xFFAACBBC))),
   segmentedButtonTheme:WaffraSubtleSelection.segmented(Brightness.dark),
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
  home:Builder(builder:(rootContext)=>PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){
   if(didPop||!mounted)return;
   // Account and non-home tabs consume back before an exit press is armed.
   if(WaffraBackNavigation.onHomeBack?.call()??false){
    _doubleBackExit.reset();return;
   }
   if(_doubleBackExit.isExitPress(DateTime.now())){
    SystemNavigator.pop();return;
   }
   final message=WaffraRegionalCopy.exitHint(english:waffraIsEnglish);
   if(_waffraFooterHostCount>0){
    _waffraShowFooterNotice(WaffraNoticeData(text:message,
     kind:WaffraSnackKind.info,duration:const Duration(milliseconds:2400),
     requireDismissal:false));
   }else{
    snack(rootContext,message,isError:false,kind:WaffraSnackKind.info,
     duration:const Duration(milliseconds:2400));
   }
  },child:Directionality(textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,child:
   (loading||!introDone)?const WaffraLaunchIntro():
   startupError!=null?Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.error_outline,size:48,color:Colors.red),
    const SizedBox(height:12),
    WaffraText(WaffraRegionalCopy.appError(english:waffraIsEnglish)),
    const SizedBox(height:12),
    SelectableText(startupError??'Unknown startup error',textDirection:TextDirection.ltr,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),
    const SizedBox(height:12),
    OutlinedButton.icon(onPressed:WaffraHaptics.tap(()=>Clipboard.setData(ClipboardData(text:startupError??'Unknown startup error'))),
     icon:const Icon(Icons.copy),label:const WaffraText('نسخ تفاصيل الخطأ')),
    const SizedBox(height:8),
    FilledButton(onPressed:WaffraHaptics.tap((){setState((){loading=true;startupError=null;});load();}),child:const WaffraText('إعادة المحاولة')),
   ])))):
   locked?PinLockScreen(pinHash:pinHash!,onUnlock:()=>setState(()=>locked=false)):
   profile==null||showLogin?LoginScreen(onSave:saveUser):
   googleFirstRunSetup?WaffraCountryFirstRunPage(
     english:language=='en',onComplete:completeGoogleCountrySetup,
     onCountryConfirmed:setUiCountry):
   HomeScreen(key:ValueKey(language),profile:profile!,
     dark:appearance=='dark'||(appearance=='system'&&MediaQuery.platformBrightnessOf(rootContext)==Brightness.dark),
     appearance:appearance,onAppearance:setAppearance,onTheme:theme,onLanguage:setLanguage,onLogout:logout,onProfile:saveUser,onSetPin:setPin,pinEnabled:pinHash!=null,greetingIndex:_greetingCycle)))));
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
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('حسنًا'))]));
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
    child:InkWell(customBorder:const CircleBorder(),onTap:WaffraHaptics.tap(busy?null:onPressed),
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
       _padButton('1',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('1'))),
       _padButton('2',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('2'))),
       _padButton('3',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('3'))),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('4',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('4'))),
       _padButton('5',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('5'))),
       _padButton('6',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('6'))),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('7',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('7'))),
       _padButton('8',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('8'))),
       _padButton('9',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('9'))),
      ]),
      const SizedBox(height:8),
      Row(textDirection:TextDirection.ltr,mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
       _padButton('',icon:Icons.fingerprint,onPressed:WaffraHaptics.tapRequired(biometric)),
       _padButton('0',onPressed:WaffraHaptics.tapRequired(()=>_keyDigit('0'))),
       _padButton('',icon:Icons.backspace_outlined,onPressed:WaffraHaptics.tapRequired((){
        if(pinController.text.isNotEmpty){
         pinController.text=pinController.text.substring(0,pinController.text.length-1);
         setState(()=>error='');
        }
       })),
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
       child:Text(waffraIsEnglish?'Your money, made clear':
        'وفرة… فلوسك بوضوح',textAlign:TextAlign.center,
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
    TextButton(onPressed:WaffraHaptics.tap(finish),style:TextButton.styleFrom(foregroundColor:Colors.white),
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
       OutlinedButton.icon(onPressed:WaffraHaptics.tap(()=>controller.previousPage(
        duration:const Duration(milliseconds:260),curve:Curves.easeInOutCubic)),
        style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
         side:const BorderSide(color:Colors.white70),
         padding:const EdgeInsets.symmetric(horizontal:13,vertical:13)),
        icon:const Icon(Icons.arrow_back_rounded,size:18),
        label:WaffraText(waffraIsEnglish?'Back':'السابق')),
       const SizedBox(width:10),
      ],
      Expanded(child:SizedBox(height:51,child:FilledButton.icon(
       onPressed:WaffraHaptics.tap(next),
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
      onPressed:WaffraHaptics.tap(busy?null:()=>proceed(false)),
      style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
      child:const WaffraText('ابدأ الآن',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)))),
     const SizedBox(height:12),
     SizedBox(width:double.infinity,height:52,child:OutlinedButton(
      onPressed:WaffraHaptics.tap(busy?null:()=>proceed(true)),
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
   if(waffraCompileOnlyQaPreview){
    if(mounted)snack(context,waffraGooglePreviewNotice(waffraIsEnglish));
    return;
   }
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
    final existing=registered;
    final googleProfile=Person(name:user.displayName??'',email:user.email??'',
     phone:user.phoneNumber??'',provider:'Google',gender:'',
     avatar:user.photoURL??'person',birthday:DateTime(2000));
    if(existing!=null&&existing.provider.toLowerCase()=='google'&&
       existing.email.trim().toLowerCase()==(user.email??'').trim().toLowerCase()&&
       waffraGoogleProfileReadyForCountrySetup(existing)){
      // Retain completed local profile on a fresh Google re-authentication.
      await widget.onSave(existing);
    }else if(mounted){
      await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>
       ProfileForm(provider:'Google',initial:googleProfile,onSave:widget.onSave)));
    }
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
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
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
    FilledButton(onPressed:WaffraHaptics.tap(socialBusy?null:continueLastLogin),
     style:FilledButton.styleFrom(backgroundColor:forest,foregroundColor:Colors.white),
     child:WaffraText(waffraIsEnglish?'Continue with $method':'المتابعة باستخدام $method')),
   ]));
 }
 bool socialBusy=false;
 Widget _socialBorder(BuildContext sheet,String id,Widget icon,{required String label})=>Material(
  color:const Color(0xFFFEFDF8),borderRadius:BorderRadius.circular(18),child:InkWell(
  borderRadius:BorderRadius.circular(18),onTap:WaffraHaptics.tap(()=>Navigator.pop(sheet,id)),
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
   if(waffraCompileOnlyQaPreview){
    if(mounted)snack(context,waffraGooglePreviewNotice(waffraIsEnglish));
    return;
   }
   if(socialBusy)return;
   setState(()=>socialBusy=true);
   try{
    final result=await WaffraGoogleAuth.signIn();
    final user=result.user;
    if(user==null)throw StateError('Google did not return an account');
    // Do not save an incomplete Google profile and tear down LoginScreen
    // before the required phone/gender form is presented.
    if(!mounted)return;
    final firstGoogleProfile=Person(name:user.displayName??'',email:user.email??'',
     phone:user.phoneNumber??'',provider:'Google',gender:'',
     avatar:user.photoURL??'person',birthday:DateTime(2000));
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>
     ProfileForm(provider:'Google',initial:firstGoogleProfile,onSave:widget.onSave)));
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
   actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
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
         TextButton(onPressed:WaffraHaptics.tap(()=>setState(()=>returnAfterLogout=false)),
          child:WaffraText(waffraIsEnglish?'Other sign-in options':'خيارات تسجيل دخول أخرى',
           style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        ]else if(signInMode&&hasExisting)...[
         WaffraText(waffraIsEnglish?'Sign in to Waffra':'تسجيل الدخول إلى وفرة',
          textAlign:TextAlign.center,
          style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.white)),
         const SizedBox(height:12),
         WaffraText(waffraIsEnglish?'Phone number *':'رقم الجوال *',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:6),
         TextField(controller:signInPhone,keyboardType:TextInputType.phone,
          onChanged:(_)=>setState(()=>signInAuthError=null),
          style:const TextStyle(color:forest),textDirection:TextDirection.ltr,
          decoration:InputDecoration(hintText:waffraIsEnglish?'Phone number':'05xxxxxxxx',hintStyle:const TextStyle(color:Colors.black38),
           filled:true,fillColor:Colors.white,
           errorText:signInAttempted?waffraMobileFieldError(signInPhone.text):null,errorMaxLines:2,
           border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
         const SizedBox(height:10),
         WaffraText(waffraIsEnglish?'Password *':'كلمة المرور *',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:6),
         TextField(controller:signInPassword,obscureText:!showSignInPassword,
          onChanged:(_)=>setState(()=>signInAuthError=null),
          onSubmitted:(_)=>_signIn(),style:const TextStyle(color:forest),
          decoration:InputDecoration(hintText:waffraIsEnglish?'Enter password':'أدخل كلمة المرور',hintStyle:const TextStyle(color:Colors.black38),
           filled:true,fillColor:Colors.white,
           errorText:signInAttempted?(signInPassword.text.isEmpty?waffraRequiredFieldMessage:signInAuthError):null,errorMaxLines:2,
           border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)),
           suffixIcon:IconButton(onPressed:WaffraHaptics.tap(()=>setState(()=>showSignInPassword=!showSignInPassword)),
            icon:Icon(showSignInPassword?Icons.visibility_off:Icons.visibility)))),
         const SizedBox(height:13),
         FilledButton(onPressed:WaffraHaptics.tap(signingIn?null:_signIn),
          style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
          child:WaffraText(signingIn?
           (waffraIsEnglish?'Signing in...':'جارٍ تسجيل الدخول'):
           (waffraIsEnglish?'Sign in':'تسجيل الدخول'))),
         TextButton(onPressed:WaffraHaptics.tap(()=>setState(()=>signInMode=false)),
          child:WaffraText(waffraIsEnglish?'Other options':'خيارات أخرى',
           style:const TextStyle(color:Colors.white))),
        ]else...[
         WaffraText(waffraIsEnglish?'Welcome to Waffra':'مرحباً بك في وفرة',
          style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.bold),
          textAlign:TextAlign.center),
         const SizedBox(height:12),
         FilledButton.icon(onPressed:WaffraHaptics.tap(signingIn?null:()async{
          if(signingIn)return;
          setState(()=>signingIn=true);
          try{
           await widget.onSave(Person(name:'',email:'',phone:'',provider:'محلي',
            gender:'',avatar:'person',birthday:DateTime(2000)));
          }finally{if(mounted)setState(()=>signingIn=false);}
         }),style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
          icon:const Icon(Icons.arrow_forward),
          label:WaffraText(waffraIsEnglish?'Start now — no sign in':'ابدأ الآن بدون تسجيل دخول')),
         const SizedBox(height:8),
         OutlinedButton.icon(onPressed:WaffraHaptics.tap(chooseRegistration),
          style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
           side:const BorderSide(color:Colors.white70)),
          icon:const Icon(Icons.person_add_alt_1_outlined),
          label:WaffraText(waffraIsEnglish?'Create account':'إنشاء حساب')),
         if(hasExisting)TextButton(onPressed:WaffraHaptics.tap(()=>setState(()=>signInMode=true)),
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
  late WaffraPhoneCountry phoneCountry;
 @override void initState(){super.initState();
  name=TextEditingController(text:widget.initial?.name??'');
  email=TextEditingController(text:widget.initial?.email??'');
  confirmEmail=TextEditingController();
  final phoneSeed=WaffraInternationalPhone.fromStored(widget.initial?.phone);
   phoneCountry=phoneSeed.country;
   phone=TextEditingController(text:widget.provider=='Google'?phoneSeed.local:widget.initial?.phone??'');
  password=TextEditingController();confirmPassword=TextEditingController();
  gender=widget.initial==null?'':(['ذكر','أنثى'].contains(widget.initial?.gender)?widget.initial!.gender:'');avatar=widget.initial?.avatar??'person';
  birthday=widget.initial?.birthday??DateTime(2000);
 }
 @override void dispose(){name.dispose();email.dispose();confirmEmail.dispose();phone.dispose();password.dispose();confirmPassword.dispose();super.dispose();}
 Future<void> editAvatar()async {
  final choice=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    ListTile(leading:const Icon(Icons.photo_library_outlined),title:WaffraText(waffraIsEnglish?'Choose from gallery':'اختيار صورة من المعرض'),onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'gallery'))),
    ListTile(leading:const Icon(Icons.restore),title:WaffraText(waffraIsEnglish?'Restore default avatar':'استعادة الصورة الافتراضية'),onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'default'))),
   ])));
  if(choice==null||!mounted)return;
  if(choice=='default'){setState(()=>avatar=gender=='أنثى'?'female':'male');return;}
  // Android Photo Picker grants access only to selected media at tap time.
  // Do not request global photo or file permissions at app launch.
  XFile? selected;
  try{
   selected=await ImagePicker().pickImage(
    source:ImageSource.gallery,imageQuality:92);
  }catch(_){
   if(mounted)snack(context,waffraIsEnglish?
    'Unable to access photos. Check your photo selection permissions.':
    'تعذر اختيار الصورة. تأكد من صلاحية الوصول للصور المختارة.');
   return;
  }
  if(selected==null||!mounted)return;
  final cropKey=GlobalKey();
  final png=await showWaffraDialog<Uint8List>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Crop profile photo':'قص صورة الملف الشخصي'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    RepaintBoundary(key:cropKey,child:ClipOval(child:SizedBox(width:230,height:230,
     child:InteractiveViewer(minScale:1,maxScale:5,child:
      Image.file(File(selected!.path),fit:BoxFit.cover))))),
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Pinch to zoom and drag to position':'كبّر الصورة وحرّكها داخل الدائرة'),
   ]),
   actions:[
    TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(onPressed:WaffraHaptics.tap(()async{
     try{
      final boundary=cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null)return;
      final frame=await boundary.toImage(pixelRatio:2);
      final data=await frame.toByteData(format:ui.ImageByteFormat.png);
      if(ctx.mounted&&data!=null)Navigator.pop(ctx,data.buffer.asUint8List());
     }catch(e){debugPrint('Avatar crop: $e');}
    }),child:WaffraText(waffraIsEnglish?'Save photo':'حفظ الصورة')),
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
  if(waffraTextFieldError(name.text)!=null||
   (widget.provider=='Google'?WaffraInternationalPhone.error(phoneCountry,phone.text,
      english:waffraIsEnglish):waffraMobileFieldError(phone.text))!=null)return;
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
    phone:widget.provider=='Google'?WaffraInternationalPhone.e164(phoneCountry,phone.text)!:phone.text.trim(),
     provider:widget.provider,gender:gender,avatar:avatar,birthday:birthday));
   if(!mounted)return;
   if(widget.initial!=null&&Navigator.of(context).canPop())Navigator.pop(context);
  }catch(e){if(mounted)snack(context,'تعذر حفظ البيانات: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:WaffraText(widget.initial==null?'كمّل بياناتك':'تعديل الحساب'),
   leading:widget.onBack==null?null:IconButton(onPressed:WaffraHaptics.tap(widget.onBack),icon:const Icon(Icons.arrow_back))),
  body:ListView(padding:const EdgeInsets.all(22),children:[
   Center(child:Stack(alignment:Alignment.bottomRight,children:[
    waffraAvatar(gender,avatar,radius:48),
    Material(color:forest,shape:const CircleBorder(),child:IconButton(
     tooltip:waffraIsEnglish?'Edit profile photo':'تعديل الصورة',
     icon:const Icon(Icons.camera_alt,color:Colors.white,size:19),
     onPressed:WaffraHaptics.tap(editAvatar))),
   ])),
   const SizedBox(height:10),
   if(widget.provider=='Google'&&(widget.initial?.gender.isEmpty??true))Card(color:emerald.withValues(alpha:.08),child:Padding(padding:const EdgeInsets.all(14),child:WaffraText(waffraIsEnglish?'Complete your profile: mobile number and gender are required.':'تبقّى بعض البيانات لاستكمال ملفك الشخصي: رقم الجوال والجنس حقول إجبارية.'))),
    Wrap(alignment:WrapAlignment.center,spacing:12,children:['ذكر','أنثى']
    .map((a)=>ChoiceChip(label:Row(mainAxisSize:MainAxisSize.min,children:[saudiAvatar(a,radius:20),const SizedBox(width:6),WaffraText(waffraIsEnglish?(a=='ذكر'?'Male':'Female'):a)]),selected:gender==a,onSelected:WaffraHaptics.selection((_)=>setState((){gender=a;if(!avatar.startsWith('https://'))avatar=a=='ذكر'?'male':'female';})))).toList()),
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
   if(widget.provider=='Google')
    WaffraGooglePhoneField(
     controller:phone,country:phoneCountry,english:waffraIsEnglish,
     onCountryChanged:(chosen)=>setState(()=>phoneCountry=chosen),
     onChanged:(_)=>setState((){}),
     errorText:profileAttempted?WaffraInternationalPhone.error(
      phoneCountry,phone.text,english:waffraIsEnglish):null)
   else TextField(controller:phone,keyboardType:TextInputType.phone,
    onChanged:(_)=>setState((){}),
    inputFormatters:[FilteringTextInputFormatter.digitsOnly,
     LengthLimitingTextInputFormatter(10)],
    decoration:InputDecoration(
     labelText:waffraIsEnglish?'Mobile number starting with 05 *':'رقم الجوال يبدأ بـ 05 *',
     hintText:'05XXXXXXXX',
     errorText:profileAttempted?waffraMobileFieldError(phone.text):null,
     border:const OutlineInputBorder())),
   if(widget.initial==null) ...[
    const SizedBox(height:12),
    TextField(controller:password,obscureText:!showPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showPassword?'Hide password':'Show password'):(showPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility),onPressed:WaffraHaptics.tap(()=>setState(()=>showPassword=!showPassword))),labelText:waffraIsEnglish?'Password *':'كلمة المرور *',
     errorText:profileAttempted?waffraPasswordFieldError(password.text):null,errorMaxLines:3,
     errorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red)),
     focusedErrorBorder:const OutlineInputBorder(borderSide:BorderSide(color:Colors.red,width:2)),
     helperText:waffraIsEnglish?'At least 8 characters, including letters and numbers':'8 خانات على الأقل، تشمل أحرفًا وأرقامًا',
     enabledBorder:passwordBorder(),focusedBorder:passwordBorder(focused:true))),
    const SizedBox(height:12),
    TextField(controller:confirmPassword,obscureText:!showConfirmPassword,
     onChanged:(_)=>setState((){}),decoration:InputDecoration(
     suffixIcon:IconButton(tooltip:waffraIsEnglish?(showConfirmPassword?'Hide password':'Show password'):(showConfirmPassword?'إخفاء كلمة المرور':'إظهار كلمة المرور'),icon:Icon(showConfirmPassword?Icons.visibility_off:Icons.visibility),onPressed:WaffraHaptics.tap(()=>setState(()=>showConfirmPassword=!showConfirmPassword))),labelText:waffraIsEnglish?'Confirm password *':'تأكيد كلمة المرور *',
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
    decoration:InputDecoration(labelText:waffraIsEnglish?'Gender *':'الجنس *',
      errorText:profileAttempted&&gender.isEmpty?waffraRequiredFieldMessage:null,
      border:const OutlineInputBorder()),
    items:['ذكر','أنثى'].map((x)=>DropdownMenuItem(value:x,child:WaffraText(waffraIsEnglish?(x=='ذكر'?'Male':'Female'):x))).toList(),
    onChanged:WaffraHaptics.selection((v){if(v!=null)setState((){gender=v;if(!avatar.startsWith('https://'))avatar=v=='أنثى'?'female':'male';});})),
   const SizedBox(height:12),
   OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async {
    final d=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:birthday,firstDate:DateTime(1900),lastDate:DateTime.now());
    if(d!=null)setState(()=>birthday=d);
   }),icon:const Icon(Icons.calendar_month),label:WaffraText('${waffraIsEnglish?'Date of birth':'تاريخ الميلاد'}: ${dayText(birthday)}')),
   const SizedBox(height:20),
   FilledButton(onPressed:WaffraHaptics.tap(busy?null:save),child:WaffraText(waffraIsEnglish?'Save profile':'حفظ البيانات')),
  ]));
}
void disposeLater(List<TextEditingController> controllers){
 Future<void>.delayed(const Duration(milliseconds:700),(){for(final c in controllers){c.dispose();}});
}
// All transient notices use the same footer-anchored surface throughout the app.
// Required-field validation remains inline using InputDecoration.errorText.
enum WaffraSnackKind { success, error, warning, info }

/// A single notice contract for income, expenses, goals, categories,
/// recurring schedules, account settings and all other Waffra screens.
class WaffraNoticeData {
 const WaffraNoticeData({
  required this.text,required this.kind,required this.duration,
  required this.requireDismissal,this.actionLabel,this.onAction,
 });
 final String text;
 final WaffraSnackKind kind;
 final Duration duration;
 final bool requireDismissal;
 final String? actionLabel;
 final VoidCallback? onAction;
}

(Color,Color,Color,IconData) waffraNoticePalette(
 BuildContext context,WaffraSnackKind kind){
 final dark=Theme.of(context).brightness==Brightness.dark;
 switch(kind){
  case WaffraSnackKind.error:
   return (dark?const Color(0xFF4A2429):const Color(0xFFFFE1E2),
    dark?const Color(0xFFFFDEE0):const Color(0xFF9D1D25),
    const Color(0xFFE67B81),Icons.error_rounded);
  case WaffraSnackKind.warning:
   return (dark?const Color(0xFF473515):const Color(0xFFFFF8E5),
    dark?const Color(0xFFFFDE94):const Color(0xFF926100),
    const Color(0xFFB7791F),Icons.warning_rounded);
  case WaffraSnackKind.info:
   return (dark?const Color(0xFF153551):const Color(0xFFE8F1FE),
    dark?const Color(0xFFC3DDFF):const Color(0xFF235DB7),
    const Color(0xFF2B6CB0),Icons.info_rounded);
  case WaffraSnackKind.success:
   return (dark?const Color(0xFF163F31):const Color(0xFFE6F5EB),
    dark?const Color(0xFFB5F2D4):const Color(0xFF07563B),
    const Color(0xFF0C7957),Icons.check_circle_rounded);
 }
}

class WaffraNoticeContent extends StatelessWidget {
 const WaffraNoticeContent({
  super.key,required this.notice,required this.onDismiss,
 });
 final WaffraNoticeData notice;
 final VoidCallback onDismiss;
 @override Widget build(BuildContext context){
  final palette=waffraNoticePalette(context,notice.kind);
  return ConstrainedBox(constraints:const BoxConstraints(minHeight:38),
   child:Row(children:[
    Icon(palette.$4,color:palette.$2,size:19),
    const SizedBox(width:7),
    Expanded(child:Tooltip(message:notice.text,
     child:WaffraText(notice.text,maxLines:2,
      overflow:TextOverflow.ellipsis,style:TextStyle(
       color:palette.$2,fontSize:12,height:1.15,
       fontWeight:FontWeight.w700)))),
    if(notice.onAction!=null)TextButton(
     style:TextButton.styleFrom(
      padding:const EdgeInsets.symmetric(horizontal:4),
      minimumSize:const Size(36,30),
      tapTargetSize:MaterialTapTargetSize.shrinkWrap),
     onPressed:WaffraHaptics.tap((){
      onDismiss();
      notice.onAction?.call();
     }),
     child:WaffraText(notice.actionLabel??(waffraIsEnglish?'Undo':'تراجع'),
      maxLines:1,style:TextStyle(
       color:palette.$2,fontSize:12,fontWeight:FontWeight.bold))),
    IconButton(
     tooltip:waffraIsEnglish?'Close':'إغلاق',
     icon:Icon(Icons.close_rounded,color:palette.$2,size:19),
     visualDensity:VisualDensity.standard,padding:EdgeInsets.zero,
     constraints:const BoxConstraints(minWidth:48,minHeight:48),
     onPressed:WaffraHaptics.tap(onDismiss)),
   ]));
 }
}

final ValueNotifier<WaffraNoticeData?> _waffraFooterNotice=
 ValueNotifier<WaffraNoticeData?>(null);
Timer? _waffraFooterNoticeTimer;
int _waffraFooterNoticeGeneration=0;
int _waffraFooterHostCount=0;

void waffraDismissFooterNotice(){
 _waffraFooterNoticeGeneration++;
 _waffraFooterNoticeTimer?.cancel();
 _waffraFooterNoticeTimer=null;
 _waffraFooterNotice.value=null;
}
void _waffraShowFooterNotice(WaffraNoticeData notice){
 final generation=++_waffraFooterNoticeGeneration;
 _waffraFooterNoticeTimer?.cancel();
 _waffraFooterNotice.value=notice;
 if(!notice.requireDismissal){
  _waffraFooterNoticeTimer=Timer(notice.duration,(){
   if(generation==_waffraFooterNoticeGeneration){
    waffraDismissFooterNotice();
   }
  });
 }
}

/// This sits INSIDE bottomNavigationBar, directly above the navigation.
/// The financial list is laid out above it instead of being obscured.
class WaffraFooterNoticeHost extends StatefulWidget {
 const WaffraFooterNoticeHost({super.key,this.onNoticePresented,
  this.listenable,this.onDismiss});
 final VoidCallback? onNoticePresented;
 final ValueListenable<WaffraNoticeData?>? listenable;
 final VoidCallback? onDismiss;
 @override State<WaffraFooterNoticeHost> createState()=>
  _WaffraFooterNoticeHostState();
}
class _WaffraFooterNoticeHostState extends State<WaffraFooterNoticeHost> {
 late ValueListenable<WaffraNoticeData?> _source;
 @override void initState(){
  super.initState();
  _source=widget.listenable??_waffraFooterNotice;
  _waffraFooterHostCount++;
  _source.addListener(_onChanged);
 }
 void _onChanged(){
  if(mounted&&_source.value!=null){
   widget.onNoticePresented?.call();
  }
 }
 @override void didUpdateWidget(covariant WaffraFooterNoticeHost oldWidget){
  super.didUpdateWidget(oldWidget);
  final next=widget.listenable??_waffraFooterNotice;
  if(!identical(_source,next)){
   _source.removeListener(_onChanged);
   _source=next;
   _source.addListener(_onChanged);
  }
 }
 @override void dispose(){
  _source.removeListener(_onChanged);
  _waffraFooterHostCount--;
  if(_waffraFooterHostCount==0)waffraDismissFooterNotice();
  super.dispose();
 }
 @override Widget build(BuildContext context)=>
  ValueListenableBuilder<WaffraNoticeData?>(
   valueListenable:_source,
   builder:(ctx,notice,_)=>AnimatedSize(
    duration:waffraMotion(170),
    curve:Curves.easeOutCubic,
    alignment:Alignment.bottomCenter,
    child:notice==null?const SizedBox(width:double.infinity,height:0):
     Padding(
      padding:const EdgeInsets.only(top:4,bottom:8),
      child:Center(child:SizedBox(
       width:min(MediaQuery.sizeOf(ctx).width*0.87,440.0),
       child:Builder(builder:(panelContext){
        final palette=waffraNoticePalette(panelContext,notice.kind);
        return Material(
         color:palette.$1,elevation:2,
         shadowColor:Colors.black.withValues(alpha:0.13),
         clipBehavior:Clip.antiAlias,
         shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(14),
          side:BorderSide(color:palette.$3,width:1)),
         child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
          child:WaffraNoticeContent(
           notice:notice,onDismiss:widget.onDismiss??waffraDismissFooterNotice)),
        );
       }),
      )),
     ),
   ),
  );
}

/// The only public way to display transient system feedback.
void snack(BuildContext context,String text,{
 bool isError=true,
 WaffraSnackKind? kind,
 bool requireDismissal=false,
 String? actionLabel,
 VoidCallback? onAction,
 Duration duration=const Duration(seconds:5),
}){
 if(!context.mounted)return;
 final notice=WaffraNoticeData(
  text:text,kind:kind??(isError?WaffraSnackKind.error:WaffraSnackKind.success),
  duration:duration,requireDismissal:requireDismissal,
  actionLabel:actionLabel,onAction:onAction,
 );
 // Home-screen messages, including modal actions, always occupy a reserved
 // region directly above the navigation bar. They cannot overlap entries.
 final inHome=context.widget is HomeScreen||
  context.findAncestorWidgetOfExactType<HomeScreen>()!=null;
 final inHomeDialog=ModalRoute.of(context) is PopupRoute;
 if(_waffraFooterHostCount>0&&(inHome||inHomeDialog)){
  // Switching from a non-footer route must never leave two notices stacked.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  _waffraShowFooterNotice(notice);
  return;
 }
 // Login, setup and pushed profile routes have no Waffra footer. Reuse
 // the exact same content/colors with the bottom-aligned fallback Snackbar.
 final messenger=ScaffoldMessenger.maybeOf(context);
 if(messenger==null)return;
 messenger.hideCurrentMaterialBanner();
 messenger.hideCurrentSnackBar();
 final palette=waffraNoticePalette(context,notice.kind);
 messenger.showSnackBar(SnackBar(
  behavior:SnackBarBehavior.floating,
  margin:const EdgeInsets.only(left:12,right:12,bottom:8),
  duration:requireDismissal?const Duration(days:1):duration,
  backgroundColor:palette.$1,
  elevation:2,
  padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
  shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(14),
   side:BorderSide(color:palette.$3,width:1)),
  content:WaffraNoticeContent(
   notice:notice,onDismiss:()=>messenger.hideCurrentSnackBar()),
 ));
}
void snackSuccess(BuildContext context,String text)=>snack(context,text,isError:false);

/// Consistent outlined item count even when there are no records.
class WaffraOutlinedItemsCount extends StatelessWidget {
 const WaffraOutlinedItemsCount({super.key,required this.label,required this.count});
 final String label;final int count;
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
   decoration:BoxDecoration(
    color:dark?Theme.of(context).cardColor:const Color(0xFFF7FBF8),
    borderRadius:BorderRadius.circular(14),
    border:Border.all(color:dark?const Color(0xFF5E8A70):const Color(0xFFB4D1C3),width:1)),
   child:Row(children:[
    Expanded(child:FittedBox(fit:BoxFit.scaleDown,
      alignment:AlignmentDirectional.centerStart,
      child:WaffraText(label,maxLines:1,
       style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold)))),
    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:3),
     decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(12)),
     child:Text('$count',style:const TextStyle(color:Colors.white,
      fontFamily:'Tajawal',fontSize:14,fontWeight:FontWeight.bold))),
   ]));
 }
}

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
 /// A verified read-only SMS original from SQLCipher; never write to notes.
 final String? protectedOriginalSms;
 final VoidCallback onClose;
 final VoidCallback? onViewReceipt;
 const WaffraTransactionDetailsDialog({
  super.key,required this.entry,required this.onClose,this.onViewReceipt,
  this.protectedOriginalSms,
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
       // These are TWO independent fields. Editable user notes are persisted
       // on the ordinary transaction route; the original SMS is read from
       // the protected vault and is never substituted into entry.notes.
       if(entry.notes.trim().isNotEmpty)...[
        const SizedBox(height:15),
        WaffraText(waffraIsEnglish?'Notes':'الملاحظات',
         textAlign:TextAlign.start,style:TextStyle(fontSize:12,color:muted)),
        const SizedBox(height:7),
        Container(width:double.infinity,padding:const EdgeInsets.all(13),
         decoration:BoxDecoration(
          color:dark?const Color(0xFF252A27):const Color(0xFFF1F8F3),
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:dark?const Color(0xFF3B5444):const Color(0xFFD5E8DC))),
         child:entry.notes.isEmpty?WaffraText(
           waffraIsEnglish?'No notes added':'لا توجد ملاحظات',
           style:TextStyle(fontSize:13,color:muted)):
          SelectableText(entry.notes,
           key:const Key('waffra-transaction-personal-notes'),
           textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
           textAlign:TextAlign.start,
           style:const TextStyle(fontSize:14,height:1.5))),
       ],
       if(entry.sourceType=='sms')...[
        const SizedBox(height:15),
        Row(children:[
         Icon(Icons.lock_outline_rounded,size:17,
          color:dark?const Color(0xFF74D8A9):emerald),
         const SizedBox(width:6),
         Expanded(child:WaffraText(waffraIsEnglish?
           'Original bank message (encrypted)':'تفاصيل الرسالة البنكية الأصلية (مشفّرة)',
           textAlign:TextAlign.start,
           style:TextStyle(fontSize:12,color:muted,fontWeight:FontWeight.w700))),
        ]),
        const SizedBox(height:7),
        Container(width:double.infinity,padding:const EdgeInsets.all(13),
         decoration:BoxDecoration(
          color:dark?const Color(0xFF18372E):const Color(0xFFE9F5EF),
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:dark?const Color(0xFF3B7055):const Color(0xFFB8D9C7))),
         child:protectedOriginalSms==null||protectedOriginalSms!.isEmpty?
          WaffraText(waffraIsEnglish?
           'Original encrypted message is unavailable.':
           'الرسالة البنكية الأصلية غير متاحة من التخزين المشفّر.',
           textAlign:TextAlign.start,
           style:TextStyle(fontSize:12,color:muted)):
          SelectableText(protectedOriginalSms!,
           key:const Key('waffra-transaction-protected-bank-sms'),
           textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
           textAlign:TextAlign.start,
           style:const TextStyle(fontSize:14,height:1.5))),
       ],
       if(onViewReceipt!=null)...[
        const SizedBox(height:10),
        Align(alignment:AlignmentDirectional.centerStart,
         child:TextButton.icon(
          onPressed:WaffraHaptics.tap(onViewReceipt),
          icon:const Icon(Icons.photo_library_outlined),
          label:WaffraText(waffraIsEnglish?'View attachments':'عرض المرفقات'))),
       ],
      ],
     )),
    ),
    actions:[TextButton(onPressed:WaffraHaptics.tap(onClose),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   ),
  );
 }
}
class HomeScreen extends StatefulWidget {
 final Person profile;final bool dark,pinEnabled;final String appearance;
 final int greetingIndex;
 final Future<void> Function(String) onAppearance;
 final Future<void> Function(String?) onSetPin;
 final VoidCallback onTheme;
 final Future<void> Function(String) onLanguage;
 final Future<void> Function() onLogout;
 final Future<void> Function(Person) onProfile;
 const HomeScreen({super.key,required this.profile,required this.dark,required this.pinEnabled,
  required this.onSetPin,required this.onTheme,required this.onLanguage,required this.onLogout,required this.onProfile,
   required this.appearance,required this.onAppearance,
   required this.greetingIndex});
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
// Scroll-linked, pinned balance summary. Shrinks with the user's gesture;
// does not count up money on every tab revisit.
// Shared original Riyal artwork on Arabic dashboards; English uses SAR.
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
     WaffraText(hidden?'***':WaffraDisplayCurrency.amount(amount),
      style:TextStyle(fontFamily:'Tajawal',fontSize:fontSize,
       fontWeight:weight,color:color)),
     if(!hidden)...[
      const SizedBox(width:5),
      WaffraCurrencyMark(english:waffraIsEnglish,
       currencyCode:WaffraDisplayCurrency.country.code,
       arabicLabel:WaffraDisplayCurrency.country.symbolAr,
       size:fontSize*.78,color:color),
     ]
    ])));
}
// Collapse the balance as the user scrolls, then let it scroll AWAY
// with the rest of the home page. It is intentionally not pinned.
/// Home balance cover: approved dark-emerald plant-and-coins design.
/// Visual only: the value and hide toggle remain bound to verified Home data.
class WaffraBalanceHeader extends SliverPersistentHeaderDelegate {
 final double balance;
 final bool english;
 final GlobalKey? focusKey;
 final double? monthlyChangePercent;
 final Future<void> Function() refreshVerifiedWidgetBalance;
 const WaffraBalanceHeader({
  required this.balance,required this.english,this.focusKey,
  required this.refreshVerifiedWidgetBalance,this.monthlyChangePercent,
 });
 @override double get minExtent=>130;
 @override double get maxExtent=>148;
 @override Widget build(BuildContext context,double shrinkOffset,bool overlapsContent){
  final progress=(shrinkOffset/(maxExtent-minExtent)).clamp(0.0,1.0);
  final dark=Theme.of(context).brightness==Brightness.dark;
  final waveColor=Theme.of(context).scaffoldBackgroundColor;
  final compare=monthlyChangePercent;
  final validCompare=compare!=null&&compare.isFinite;
  final comparisonValue=validCompare?compare!:0.0;
  return Container(
   key:focusKey,
   color:waveColor,
   padding:const EdgeInsets.fromLTRB(14,0,14,4),
   child:Container(
    key:const Key('waffra-approved-emerald-balance-card'),
    decoration:BoxDecoration(
     borderRadius:BorderRadius.circular(23),
     gradient:const LinearGradient(
      begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF167F5A),Color(0xFF07533E),Color(0xFF00392F)],
      stops:[0,.54,1]),
     border:Border.all(color:const Color(0xFF73CF9A).withValues(alpha:.38)),
     boxShadow:[BoxShadow(color:const Color(0xFF063B2D).withValues(alpha:dark ? 0.25 : 0.17),
      blurRadius:15,offset:const Offset(0,5))]),
    child:ClipRRect(
     borderRadius:BorderRadius.circular(22),
     child:Stack(fit:StackFit.expand,children:[
      Positioned(
       left:-45,top:-84,width:205,height:175,
       child:DecoratedBox(decoration:BoxDecoration(
        border:Border.all(color:const Color(0xFF94EDBC).withValues(alpha:.11)),
        borderRadius:BorderRadius.circular(120)))),
      Positioned(right:-35,top:-95,width:185,height:175,
       child:DecoratedBox(decoration:BoxDecoration(
        color:const Color(0xFF4CCF92).withValues(alpha:.07),
        shape:BoxShape.circle))),
      Positioned(right:0,bottom:-6,width:145,height:137,
       child:IgnorePointer(child:const WaffraBalanceIllustration())),
      Positioned.fill(child:IgnorePointer(child:CustomPaint(
       painter:WaffraBalanceWavePainter(waveColor)))),
      Positioned(left:7,top:10,
       child:ValueListenableBuilder<bool>(
        valueListenable:hideWaffraAmounts,
        builder:(ctx,hidden,_)=>IconButton(
         key:const Key('waffra-balance-privacy-eye'),
         tooltip:hidden?(english?'Show amounts':'إظهار المبالغ'):
          (english?'Hide amounts':'إخفاء المبالغ'),
         onPressed:WaffraHaptics.tap(()async{
          final conceal=!hidden;
          hideWaffraAmounts.value=conceal;
          final prefs=await SharedPreferences.getInstance();
          await prefs.setBool('waffra_hide_amounts',conceal);
          // Keep the existing verified Widget-authority refresh.
          await refreshVerifiedWidgetBalance();
         }),
         icon:Icon(hidden?Icons.visibility_off_outlined:Icons.visibility_outlined,
          size:22,color:const Color(0xFFE2FBEF))))),
      Positioned(left:47,right:112,top:14,bottom:45,
       child:Column(mainAxisAlignment:MainAxisAlignment.start,
        crossAxisAlignment:CrossAxisAlignment.center,children:[
         WaffraText(english?'Total balance':'إجمالي رصيدك',
          maxLines:1,
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,
           color:Color(0xFFD7F1E5))),
         const SizedBox(height:3),
         Expanded(child:Center(child:FittedBox(
          alignment:Alignment.center,fit:BoxFit.scaleDown,
          child:WaffraCurrencyAmount(balance,fontSize:31-2*progress,
           color:Colors.white,weight:FontWeight.w800)))),
        ])),
      if(validCompare)Positioned(left:18,bottom:14,
       child:Column(crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisSize:MainAxisSize.min,children:[
         Container(
          key:const Key('waffra-balance-month-comparison'),
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
          decoration:BoxDecoration(
           color:(comparisonValue>=0?const Color(0xFF1BAC70):const Color(0xFFAA403C))
            .withValues(alpha:.92),
           borderRadius:BorderRadius.circular(17)),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
           Icon(comparisonValue>=0?Icons.trending_up_rounded:Icons.trending_down_rounded,
            size:13,color:Colors.white),
           const SizedBox(width:4),
           Text('${comparisonValue>=0?'+':''}${comparisonValue.toStringAsFixed(0)}%',
            style:const TextStyle(color:Colors.white,fontSize:12,
             fontWeight:FontWeight.w800)),
          ])),
         const SizedBox(height:3),
         Text(english?'Compared with last month':'مقارنة بالشهر الماضي',
          style:const TextStyle(fontFamily:'Tajawal',
           fontSize:10,color:Color(0xFFD3F2E0))),
        ])),
     ])),
   ),
  );
 }
 // The cover also depends on inherited light/dark theme and its background.
 // Preserve the old delegate's rebuild semantics on theme/locale changes.
 @override bool shouldRebuild(covariant WaffraBalanceHeader oldDelegate)=>true;
}
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
 // Stable callback identity ensures an old locale-specific Home disposal
 // cannot clear the replacement Home's back handler.
 late final bool Function() _registeredBackHandler=_consumeHomeBack;
 final WaffraLegacyWriteQueue _financialWriteQueue=WaffraLegacyWriteQueue();
 final WaffraHomeFinancePersistence _homeFinancePersistence=const WaffraHomeFinancePersistence();
 late WaffraVerifiedFinanceAuthority _financeAuthority=WaffraVerifiedFinanceAuthority(legacy:_homeFinancePersistence);
 WaffraProductionFinanceAuthorityBinding? _financeBinding;
 Future<void>? _financeBindingFuture;
 Future<void> _ensureFinanceBound()async{
  if(_financeBinding!=null)return;
  final pending=_financeBindingFuture??=_bindFinanceSource();
  try{await pending;}
  catch(_){if(identical(_financeBindingFuture,pending))_financeBindingFuture=null;rethrow;}
 }
 Future<void> _bindFinanceSource()async{
  final binding=await WaffraProductionFinanceAuthorityBinding.bind(
   legacy:_homeFinancePersistence,
   startupRoute:WaffraFinanceRoute.appStartup,
  );
  if(!mounted){await binding.close();throw StateError('Home startup was disposed.');}
  _financeBinding=binding;
  _financeAuthority=binding.authority;
 }

 WaffraFinanceAuthorityRead? _lastFinanceAuthorityRead;
 final smsHashes=<String>{};
 final expandedCategoryIds=<String>{};
 final learnedMerchantCategories=<String,String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 // One repaint-isolated saving indicator for every confirmed Home finance edit.
 final WaffraSmoothOperationController _saveProgress=WaffraSmoothOperationController();
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
 bool _bankSmsAiOpening=false,_receiptOcrAiOpening=false;
 String? _lastWidgetRevision;
 // Exact last finance ledger string seen or committed, including null vs [].
 // Detect partial widget saves even if the last-save marker never committed.
 String? _lastLedgerSavedRaw;
 AppLifecycleListener? _widgetReloadListener;
 double _swipeTravel=0;
 bool _headerCompact=false;
 final ScrollController _dashboardScrollController=ScrollController();
 final ScrollController _categoryScrollController=ScrollController();
 final ScrollController _goalsScrollController=ScrollController();
 final ScrollController _recurringScrollController=ScrollController();
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
 bool categoryMineOnly=false;
  String? forecastCategory;
  int forecastReduction=20;
 bool recurringRemindersEnabled=false;
 bool ready=false;
 String? _financeLoadFailure;
 String? lastBackupGeneratedAt;
 int? lastBackupBytes;
 bool protectRecentApps=true;
 String? _accountOpenSection;
 String accountSearch='';
 final _tourKeys=List<GlobalKey>.generate(7,(_)=>GlobalKey());
 bool tourActive=false;
 bool tourTargetReady=false;
 int tourStep=0;
 static const tourTabs=WaffraTourPlan.tabs;
 static const tourTargetKeys=WaffraTourPlan.targetKeys;
 bool addFabExpanded=false;
 bool quickActionsExpanded=false;
 bool _addActionOpening=false;
 bool _fabPressed=false;
 DateTime? _lastFabTapAt;
 Future<void> _launchAddAction(Future<void> Function() action,{bool fromMenu=false})async{
  if(_addActionOpening)return;
  _addActionOpening=true;
  if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
  try{
   // Allow the menu to finish collapsing before presenting a sheet.
   if(fromMenu)await Future<void>.delayed(waffraMotion(260));
   if(mounted)await action();
  }finally{_addActionOpening=false;}
 }
 bool _acceptFabTap(){
  final now=DateTime.now();
  if(_addActionOpening||(_lastFabTapAt!=null&&
   now.difference(_lastFabTapAt!)<const Duration(milliseconds:380)))return false;
  _lastFabTapAt=now;
  return true;
 }
 // Account settings open from the app bar instead of a footer destination.
 bool accountOpened=false;
 bool showAllTransactions=false,showTransactionFilters=false,showTransactionSearch=false;
 @override void initState(){super.initState();WaffraBackNavigation.onHomeBack=_registeredBackHandler;_dashboardScrollController.addListener(_handleDashboardScroll);_tourGlow=AnimationController(vsync:this,duration:waffraMotion(1150));waffraReturnHome.addListener(_returnToHome);waffraIncomingSms.addListener(_receiveSharedSms);waffraWidgetAction.addListener(_receiveWidgetAction);_widgetReloadListener=AppLifecycleListener(onResume:()=>unawaited(_syncWidgetTransactions()));unawaited(_loadFinanceSafely());}
 void _returnToHome(){if(mounted)setState((){tab=0;accountOpened=false;goalsOpened=false;addFabExpanded=false;});}
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
 Future<void> _loadFinanceSafely()async{
  if(!mounted)return;
  setState((){ready=false;_financeLoadFailure=null;});
  entries.clear();categories.clear();goals.clear();recurring.clear();challenges.clear();
  deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();
  recurringPostponed.clear();smsHashes.clear();learnedMerchantCategories.clear();
  try{
   await load();
  }catch(e){
   debugPrint('Financial startup integrity/recovery gate blocked access: $e');
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Could not verify your financial data. Nothing was deleted. Retry or restore a trusted backup.':
     'تعذر التحقق من بياناتك. لم يُحذف شيء. حاول مجددًا أو استعد نسخة موثوقة.';
   });
  }
 }
 Widget _financialRecoveryScreen()=>Center(child:Padding(
  padding:const EdgeInsets.all(24),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Icon(Icons.shield_outlined,size:50,color:emerald),
   const SizedBox(height:14),
   WaffraText(waffraIsEnglish?'Financial data protected':'بياناتك المالية محمية',
    textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
   const SizedBox(height:9),
   WaffraText(_financeLoadFailure??'',textAlign:TextAlign.center),
   const SizedBox(height:18),
   FilledButton.icon(
    onPressed:WaffraHaptics.tap(()=>unawaited(_loadFinanceSafely())),
    icon:const Icon(Icons.refresh),
    label:WaffraText(waffraIsEnglish?'Retry safely':'إعادة المحاولة بأمان')),
  ])));
 @override void dispose(){if(identical(WaffraBackNavigation.onHomeBack,_registeredBackHandler))WaffraBackNavigation.onHomeBack=null;_dashboardScrollController.dispose();_categoryScrollController.dispose();_goalsScrollController.dispose();_recurringScrollController.dispose();_tourGlow.dispose();waffraReturnHome.removeListener(_returnToHome);waffraIncomingSms.removeListener(_receiveSharedSms);waffraWidgetAction.removeListener(_receiveWidgetAction);_widgetReloadListener?.dispose();_saveProgress.dispose();final binding=_financeBinding;if(binding!=null)unawaited(_financialWriteQueue.drain().whenComplete(binding.close));super.dispose();}
 Future<void> _syncWidgetTransactions()async{
  if(!mounted||!ready)return;
  try{
   await _ensureFinanceBound();
   final loadedFinance=await _financeAuthority.load(route:WaffraFinanceRoute.dashboardRead);
   loadedFinance.finance.requireIntegrity();
   final revision=loadedFinance.widgetRevision;
   // A newer widget write invalidates the dashboard's previous baseline.
   // Never carry a pre-widget snapshot into another finance save.
   if(revision==null||revision==_lastWidgetRevision)return;
   final raw=loadedFinance.ledgerRaw;
   if(raw==null)return;
   final loaded=(jsonDecode(raw) as List)
    .map((item)=>MoneyEntry.fromJson(Map<String,dynamic>.from(item as Map))).toList();
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(loaded);
    _lastWidgetRevision=revision;
    _lastLedgerSavedRaw=raw;
    _lastFinanceAuthorityRead=loadedFinance;
   });
   unawaited(_refreshWidget());
  }catch(e){
   debugPrint('Widget ledger sync failed safely: $e');
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Financial data could not be verified after widget activity. Retry safely.':
     'تعذر التحقق من البيانات بعد إضافة عملية من الويدجت. أعد المحاولة بأمان.';
   });
  }
 }
 /// Refresh from the authoritative source, not an in-memory repaint.
 /// A failed integrity check never replaces user money with zeroes.
 // Visual-only M258: no finance writes or source-selection changes.
 Future<void> _refreshAndSettle(ScrollController controller,int originalTab)=>
  waffraRefreshAndRestoreScroll(
   refresh:_refreshFromVerifiedFinance,
   controller:controller,
   isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null&&
    tab==originalTab&&(originalTab!=0||!goalsOpened));

 Future<void> _refreshFromVerifiedFinance()async {
  if(!mounted||!ready)return;
  try {
   await _financialWriteQueue.drain();
   await _ensureFinanceBound();
   final current=await _financeAuthority.load(
    route:WaffraFinanceRoute.dashboardRead);
   final view=current.finance;
   view.requireIntegrity();
   final ledger=current.ledgerRaw;
   final catalog=view.getString('waffra_categories_v24');
   if(ledger==null||catalog==null) {
    throw StateError('Authoritative finance view is incomplete.');
   }
   List<T> readList<T>(String? raw,T Function(Map<String,dynamic>) make) {
    if(raw==null)return <T>[];
    final parsed=jsonDecode(raw);
    if(parsed is! List)throw const FormatException('Invalid finance list.');
    return parsed.map((e)=>make(Map<String,dynamic>.from(e as Map))).toList();
   }
   final nextEntries=readList<MoneyEntry>(ledger,MoneyEntry.fromJson);
   final nextCategories=readList<BudgetCategory>(catalog,BudgetCategory.fromJson);
   final nextGoals=readList<SavingGoal>(
    view.getString('waffra_goals_v24'),SavingGoal.fromJson);
   final nextRecurring=readList<RecurringBill>(
    view.getString('waffra_recurring_v24'),RecurringBill.fromJson);
   final nextChallenges=readList<SavingChallenge>(
    view.getString('waffra_challenges_v1'),SavingChallenge.fromJson);
   List<Map<String,dynamic>> readTrash(String key)=>readList<Map<String,dynamic>>(
    view.getString(key),(row)=>row);
   final nextCategoryTrash=readTrash('waffra_deleted_categories_v1');
   final nextGoalTrash=readTrash('waffra_deleted_goals_v1');
   final nextRecurringTrash=readTrash('waffra_deleted_recurring_v1');
   Map<String,String> readStringMap(String key) {
    final raw=view.getString(key);
    if(raw==null)return <String,String>{};
    return (jsonDecode(raw) as Map).map((k,v)=>
     MapEntry(k.toString(),v.toString()));
   }
   final nextPostponed=readStringMap('waffra_recurring_postponed_v1');
   final nextLearned=readStringMap('waffra_learned_merchants_v1');
   final nextHashes=view.getStringList('waffra_sms_hashes_v1')??<String>[];
   final nextBudget=view.getDouble('waffra_monthly_budget_v1')??0;
   final nextBudgetEnabled=view.getBool('waffra_monthly_budget_enabled_v1')
    ??(nextBudget>0);
   final nextReminders=view.getBool('waffra_recurring_reminders_enabled_v1')??false;
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(nextEntries);
    categories..clear()..addAll(nextCategories);
    goals..clear()..addAll(nextGoals);
    recurring..clear()..addAll(nextRecurring);
    challenges..clear()..addAll(nextChallenges);
    deletedCategories..clear()..addAll(nextCategoryTrash);
    deletedGoals..clear()..addAll(nextGoalTrash);
    deletedRecurring..clear()..addAll(nextRecurringTrash);
    recurringPostponed..clear()..addAll(nextPostponed);
    learnedMerchantCategories..clear()..addAll(nextLearned);
    smsHashes..clear()..addAll(nextHashes);
    monthlyBudget=nextBudget;
    monthlyBudgetEnabled=nextBudgetEnabled;
    recurringRemindersEnabled=nextReminders;
    _lastFinanceAuthorityRead=current;
    _lastLedgerSavedRaw=ledger;
    _lastWidgetRevision=current.widgetRevision;
   });
   unawaited(_refreshWidget());
  }catch(error) {
   debugPrint('Verified pull refresh failed closed: $error');
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Refreshed financial data could not be verified. Nothing was erased. Retry safely.':
     'تعذر التحقق من البيانات أثناء التحديث. لم تُحذف أي معاملات. أعد المحاولة بأمان.';
   });
  }
 }
 Future<void> load()async {
  await _ensureFinanceBound();
  final p=await SharedPreferences.getInstance();
  final loadedFinance=await _financeAuthority.load(route:WaffraFinanceRoute.dashboardRead);
  _lastFinanceAuthorityRead=loadedFinance;
  final financeView=loadedFinance.finance;
  financeView.requireIntegrity();
  final verifiedEncryptedStartup=
   loadedFinance.source==WaffraRuntimeFinanceBackend.verifiedEncrypted;
  if(verifiedEncryptedStartup&&
     financeView.getString('waffra_categories_v24')==null){
   throw StateError('Verified encrypted category source is incomplete.');
  }
  _lastWidgetRevision=loadedFinance.widgetRevision;
  _lastLedgerSavedRaw=loadedFinance.ledgerRaw;
  try{final raw=financeView.getString('entries');if(raw!=null)entries.addAll((jsonDecode(raw) as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved transactions cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(jsonDecode(raw) as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved categories cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_goals_v24');if(raw!=null)goals.addAll((jsonDecode(raw) as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((jsonDecode(raw) as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved recurring finance cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_challenges_v1');if(raw!=null)challenges.addAll((jsonDecode(raw) as List).map((e)=>SavingChallenge.fromJson(Map<String,dynamic>.from(e))));}catch(e){throw StateError('Saved challenges cannot be decoded safely: $e');}
  try{
   final raw=financeView.getString('waffra_deleted_categories_v1');
   if(raw!=null)deletedCategories.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));
  }catch(e){throw StateError('Deleted categories cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_goals_v1');if(raw!=null)deletedGoals.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_recurring_v1');if(raw!=null)deletedRecurring.addAll((jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted recurring cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_postponed_v1');if(raw!=null)recurringPostponed.addAll((jsonDecode(raw) as Map).map((k,v)=>MapEntry(k.toString(),v.toString())));}catch(e){throw StateError('Recurring postponements cannot be decoded safely: $e');}
  // The user's device clock cannot purge or hide encrypted SQL tombstones.
  // Deletion/expiry requires independently verified encrypted retention.
  final trashBefore=deletedCategories.length;
  if(!verifiedEncryptedStartup){
   deletedGoals.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
   deletedRecurring.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
   deletedCategories.removeWhere((item){
    final when=DateTime.tryParse('${item['deletedAt']??''}');
    return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
   });
  }
  // Install catalog once without overwriting custom categories, saved budgets or trash.
  if(!verifiedEncryptedStartup&&
      !(p.getBool('waffra_category_catalog_v2_installed')??false)){
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
   final committed=await _financeAuthority.installCategoryCatalog(
    version:2,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:true,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  // Incremental catalog update: retain existing user budgets, names and deletions.
  // A subcategory is only added when its main category is present.
  if(!verifiedEncryptedStartup&&
      !(p.getBool('waffra_category_catalog_v3_installed')??false)){
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
   final committed=await _financeAuthority.installCategoryCatalog(
    version:3,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:catalogChanged,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  // Catalog v4 installs only new leaves, preserving user budgets and trash.
  if(!verifiedEncryptedStartup&&
     !(p.getBool('waffra_category_catalog_v4_installed')??false)){
   final removedIds=<String>{},removedNames=<String>{};
   for(final record in deletedCategories){
    final data=record['category'];
    if(data is Map){
     removedIds.add('${data['id']}');
     removedNames.add('${data['income']==true}|${data['name']}');
    }
   }
   var changed=false;
   for(final suggestion in defaultCategories()){
    if(removedIds.contains(suggestion.id)||
       removedNames.contains('${suggestion.income}|${suggestion.name}'))continue;
    if(categories.any((c)=>c.id==suggestion.id||
      (c.income==suggestion.income&&c.name==suggestion.name)))continue;
    if(suggestion.isSubcategory&&!categories.any(
       (c)=>c.id==suggestion.parentId&&!c.isSubcategory))continue;
    categories.add(suggestion);changed=true;
   }
   final committed=await _financeAuthority.installCategoryCatalog(
    version:4,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:changed,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  smsHashes.addAll(financeView.getStringList('waffra_sms_hashes_v1')??const []);
  monthlyBudget=financeView.getDouble('waffra_monthly_budget_v1')??0;
  monthlyBudgetEnabled=financeView.getBool('waffra_monthly_budget_enabled_v1')??(monthlyBudget>0);
  recurringRemindersEnabled=financeView.getBool('waffra_recurring_reminders_enabled_v1')??false;
  lastBackupGeneratedAt=p.getString('waffra_backup_last_exported_v1');
  lastBackupBytes=p.getInt('waffra_backup_last_size_v1');
  protectRecentApps=p.getBool('waffra_protect_recents_v1')??true;
  try{
   final rawRules=financeView.getString('waffra_learned_merchants_v1');
   if(rawRules!=null){
    final data=jsonDecode(rawRules);
    if(data is Map){
     learnedMerchantCategories.addAll(data.map((key,value)=>MapEntry(key.toString(),value.toString())));
    }
   }
  }catch(e){throw StateError('Learned merchant rules cannot be decoded safely: $e');}
  if(!verifiedEncryptedStartup&&categories.isEmpty){
   categories.addAll(defaultCategories());
  }
  // Archived categories may still be referenced by historic entries.
  // Never synthesize phantom active categories in SQLCipher.
  if(!verifiedEncryptedStartup)for(final e in entries){
   if(!categories.any((c)=>c.name==e.category&&c.income==e.income)){
    categories.add(BudgetCategory(id:newId(),name:e.category,icon:'category',color:colors[7],income:e.income));
   }
  }
  if(!mounted)return;setState(()=>ready=true);_receiveSharedSms();_receiveWidgetAction();unawaited(_refreshWidget());
  // Home reloading an encrypted ledger must never silently post a due payment.
  if(!verifiedEncryptedStartup){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted)unawaited(applyRecurring());
   });
  }
  if(recurringRemindersEnabled)unawaited(syncRecurringReminders());
  // An explicit Google onboarding notification consent may be pending;
  // enable reminder scheduling only through the verified finance authority.
  // No reminder OS permission at startup; wait for explicit recurring toggle.
  if(!verifiedEncryptedStartup&&trashBefore!=deletedCategories.length){
   await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  }
  if(!(p.getBool('waffra_in_app_tour_seen_v2')??false)&&mounted){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted){setState((){tourActive=true;tourStep=0;tab=0;accountOpened=false;_headerCompact=false;goalsOpened=false;addFabExpanded=false;tourTargetReady=false;});if(waffraAnimationLevel.value!='off')_tourGlow.repeat(reverse:true);scheduleTourFocus();}
   });
  }
 }
 Future<void> _refreshWidget()async{
  if(!Platform.isAndroid)return;
  try{
   await _ensureFinanceBound();
   final verified=await _financeAuthority.load(
    route:WaffraFinanceRoute.widgetBalanceRefresh);
   verified.finance.requireIntegrity();
   final raw=verified.ledgerRaw;
   if(raw==null){
    throw StateError('Financial source returned no verified widget ledger.');
   }
   final net=WaffraAuthoritativeWidgetBalance.netHalalas(raw);
   await refreshWaffraHomeWidget(
    balance:hideWaffraAmounts.value?'***':WaffraDisplayCurrency.amount(net/100),
    negative:net<0,
    hidden:hideWaffraAmounts.value,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }catch(e){
   // An absent OS key, conflicting source witness, corrupt ledger or
   // interrupted cutover must NEVER display a stale in-memory balance.
   debugPrint('Verified widget balance refresh unavailable: $e');
   await refreshWaffraHomeWidget(
    balance:'***',negative:false,hidden:true,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }
 }
 Future<void> persist({
  WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit,
  bool userConfirmed = false,
 }) {
  // Freeze a snapshot BEFORE any await. Previously Future.wait launched
  // overlapping multi-key saves, so a slower old save could finish last.
  // This protects in-app ordering, not cross-process widget writes or a crash
  // in the middle of SharedPreferences' non-atomic multi-key update.
  final snapshot=<String,Object>{
   'entries':jsonEncode(entries.map((e)=>e.toJson()).toList()),
   'waffra_categories_v24':jsonEncode(categories.map((e)=>e.toJson()).toList()),
   'waffra_goals_v24':jsonEncode(goals.map((e)=>e.toJson()).toList()),
   'waffra_recurring_v24':jsonEncode(recurring.map((e)=>e.toJson()).toList()),
   'waffra_challenges_v1':jsonEncode(challenges.map((e)=>e.toJson()).toList()),
   'waffra_deleted_categories_v1':jsonEncode(deletedCategories),
   'waffra_deleted_goals_v1':jsonEncode(deletedGoals),
   'waffra_deleted_recurring_v1':jsonEncode(deletedRecurring),
   'waffra_recurring_postponed_v1':jsonEncode(recurringPostponed),
   'waffra_monthly_budget_v1':monthlyBudget,
   'waffra_monthly_budget_enabled_v1':monthlyBudgetEnabled,
   'waffra_learned_merchants_v1':jsonEncode(learnedMerchantCategories),
  };
  final baseline=_lastFinanceAuthorityRead;
  return _saveProgress.track<void>(
   'persist-financial-change',() {
   return _financialWriteQueue.submit(snapshot,(captured)async {
   if(baseline==null){
    throw StateError('Verified dashboard baseline is unavailable.');
   }
   // One source-aware write entry point for the entire Home finance capture.
   // Every individual category/goal/recurring editor funnels through here.
   // The selected SQLCipher source and witness are rechecked before writing.
   await _ensureFinanceBound();
   final committed=await _financeAuthority.saveCaptured(
    route:route,
    baseline:baseline,
    captured:captured,
    userConfirmed:userConfirmed,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }).then((_){unawaited(_refreshWidget());});
  });
 }

 /// Optimistic UI updates must never masquerade as committed finance.
 /// A failed verified writer may have left a newer authoritative state, so
 /// read it back rather than blindly restoring a stale in-memory snapshot.
 Future<bool> _persistModuleOrReload(
   WaffraFinanceRoute route,{required String operation})async{
  try{
   await persist(route:route);
   return true;
  }catch(error){
   debugPrint('Verified $operation write refused: $error');
   if(mounted)await _loadFinanceSafely();
   if(mounted)snack(context,waffraIsEnglish?
    'Changes were not confirmed. Financial records were reloaded safely.':
    'لم يتم تأكيد الحفظ. أعدنا تحميل بياناتك المالية بشكل آمن.');
   return false;
  }
 }

 Future<void> _persistSmsHashes(Set<String> hashesToSave)async {
  // Home and Widget now merge only SHA-256 fingerprints through the same
  // source selector. SQLCipher activation cannot fall back to preferences.
  await _ensureFinanceBound();
  final committed=await _financeAuthority.mergeSmsHashes(hashesToSave);
  _lastFinanceAuthorityRead=committed;
  _lastLedgerSavedRaw=committed.ledgerRaw;
  _lastWidgetRevision=committed.widgetRevision;
  smsHashes..clear()..addAll(
   committed.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
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
 Future<void> toggleRecurringReminders(bool enabled,
   {bool permissionAlreadyGranted=false})async {
  if(enabled){
   try {
    final granted=permissionAlreadyGranted?
     await WaffraReminders.alreadyPermitted():
     await WaffraReminders.requestPermission();
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
  await _ensureFinanceBound();
  final committed=await _financeAuthority.setRecurringReminderPreference(enabled);
  _lastFinanceAuthorityRead=committed;
  _lastLedgerSavedRaw=committed.ledgerRaw;
  _lastWidgetRevision=committed.widgetRevision;
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
    final action=await showWaffraDialog<String>(context:context,
     builder:(ctx)=>AlertDialog(
      title:Column(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.event_repeat_rounded,color:emerald,size:34),
       const SizedBox(height:8),
       WaffraText(waffraIsEnglish?'Recurring payment due':'عملية متكررة مستحقة',
        textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20)),
      ]),
      content:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraText(r.title,textAlign:TextAlign.center,
        style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)),
       const SizedBox(height:12),
       Directionality(textDirection:TextDirection.ltr,
        child:Center(child:WaffraText(cash(r.amount),
         style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)))),
       const SizedBox(height:12),
       Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        const Icon(Icons.calendar_today_outlined,size:17,color:emerald),
        const SizedBox(width:7),
        WaffraText(waffraIsEnglish?'Due: ':'تاريخ الاستحقاق: '),
        Directionality(textDirection:TextDirection.ltr,
         child:Text(dayText(postponed??due))),
       ]),
       const SizedBox(height:15),
       WaffraText(waffraIsEnglish?
        'Have you paid, or would you like to postpone?':
        'هل تم الدفع، أم ترغب في تأجيل الاستحقاق؟',
        textAlign:TextAlign.center),
      ]),
      actionsAlignment:MainAxisAlignment.center,
      actionsPadding:const EdgeInsets.fromLTRB(12,0,12,16),
      actions:[SizedBox(width:min(330.0,MediaQuery.sizeOf(ctx).width-80),
       child:Row(children:[
        Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'later')),
         child:WaffraText(waffraIsEnglish?'Not now':'ليس الآن',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
        const SizedBox(width:5),
        Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'postpone')),
         child:WaffraText(waffraIsEnglish?'Postpone':'تأجيل',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
        const SizedBox(width:5),
        Expanded(child:FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'paid')),
         child:WaffraText(waffraIsEnglish?'Paid':'تم الدفع',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
       ]))],
     ));
    if(!mounted)return;
    if(action=='paid'){
     if(!entries.any((e)=>e.id==id)){
      setState(()=>entries.insert(0,MoneyEntry(id:id,title:r.title,category:r.category,amount:r.amount,income:r.income,date:DateTime.now())));
     }
     recurringPostponed.remove(id);
     // 'Paid' is a human-confirmed choice; the SQL writer commits both
     // the deterministic payment and its postponement in one transaction.
     try {
      await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,
       userConfirmed:true);
     } catch(error) {
      // A lost acknowledgement may have committed. Reload the source;
      // never blindly replay a payment or retain a tentative UI entry.
      debugPrint('Recurring payment commit could not be confirmed: $error');
      if(mounted)await _loadFinanceSafely();
      if(mounted)snack(context,waffraIsEnglish?
       'Payment not confirmed. Records refreshed; check before retrying.':
       'لم يتم تأكيد الدفع. تم تحديث البيانات؛ تحقق منها قبل إعادة المحاولة.');
      return;
     }
    }else if(action=='postpone'){
     final selected=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:today.add(const Duration(days:1)),
      firstDate:DateTime(today.year,today.month,today.day).add(const Duration(days:1)),
      lastDate:DateTime(today.year+3,12,31));
     if(selected!=null){
      recurringPostponed[id]=selected.toIso8601String();
      if(!await _persistModuleOrReload(
       WaffraFinanceRoute.recurringPostingAndPostponement,
       operation:'recurring-postpone'))return;
     }
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
 // Manual entries may only select leaf categories; stored parent references
 // in older transactions remain unchanged until a user deliberately edits.
 List<BudgetCategory> forManualTransactionType(bool income)=>
  categories.where((c)=>c.income==income&&c.isSubcategory).toList();
 Future<bool?> confirm(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),child:const WaffraText('تأكيد'))]));
 Future<bool?> confirmDeletion(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(title),content:WaffraText(body),
   actions:[
    TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
     child:WaffraText(waffraIsEnglish?'Confirm delete':'تأكيد الحذف')),
   ]));
Future<bool> _requireBankSmsAi()=>
  WaffraAiModelGate.requireForFeature(context,
   english:waffraIsEnglish,featureAr:'تحليل الرسائل البنكية',
   featureEn:'bank message analysis');

 Future<bool> _requireReceiptOcrAi()=>
  WaffraAiModelGate.requireForFeature(context,
   english:waffraIsEnglish,featureAr:'تصوير الفواتير واستخراج البيانات من الصور',
   featureEn:'receipt and image OCR scanning');

 Future<void> bulkSmsSheet({String? initialText})async {
  // SMS parsing and review require on-device AI. Both Android share and
  // the Add menu enter here; refusal always keeps the sheet closed.
  if(_smsSheetOpen||_bankSmsAiOpening)return;
  _bankSmsAiOpening=true;
  bool allowed=false;
  try{allowed=await _requireBankSmsAi();}
  finally{_bankSmsAiOpening=false;}
  if(!allowed||!mounted||_smsSheetOpen)return;
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
 var pasteRevision=0;
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
  if(!hasTransaction&&parts.any((message)=>
    BankParser.parse(message).requiresCurrencyReview)){
   return waffraIsEnglish
    ?'Foreign currency detected. Review and manually convert to SAR before saving.'
    :'تم اكتشاف معاملة بعملة أجنبية. راجعها وحوّل المبلغ يدويًا إلى الريال قبل الحفظ.';
  }
  return hasTransaction?null:(waffraIsEnglish
   ?'No confirmed supported-SAR transaction found. Review and retry.'
   :'لم نجد معاملة مؤكدة بالريال يمكن حفظها تلقائيًا. راجع الرسالة وحاول مجددًا.');
 }

 bool sheetActive=true;
 Future<void> prepare(int i,StateSetter update)async {
  final result=BankParser.parse(messages[i]);
  update((){
   reviewAttempted=false;index=i;income=result.income;
   category=categories.any((c)=>c.income==income&&c.name==result.category)?result.category:
    (forType(income).isNotEmpty?forType(income).first.name:'أخرى');
   // M220: never paste the full bank SMS into the transaction TITLE.
   // The original text is shown only in the ephemeral review field; the
   // guarded legacy writer strips raw SMS notes until SQLCipher is certified.
   description.text=result.title;
   amount.text=result.amount==null?'':formatWaffraMoney(result.amount!);
  });
 }
 Future<void> saveParsedMessages(BuildContext ctx,StateSetter update)async {
  // If the model gets removed while this sheet is open, fail closed.
  if(!WaffraOnDeviceQwen.shared.isReady){
   update(()=>statusMessage=waffraIsEnglish
    ?'Bank-message analysis requires the downloaded AI model. Close and reopen to install it.'
    :'تحليل الرسائل البنكية يحتاج تنزيل نموذج الذكاء الاصطناعي. اقفل الميزة وافتحها لتنزيله.');
   return;
  }
  if(busy)return;
  final found=splitBankMessages(pasted.text.trim());
  if(found.isEmpty){update(()=>statusMessage=waffraIsEnglish?'No financial transactions found. Edit the message and retry.':'هذه الرسالة لا تحتوي على أي معاملات مالية. عدّلها لإعادة التحليل تلقائيًا.');return;}
  if(found.length>100){update(()=>statusMessage=waffraIsEnglish?'Maximum 100 transactions per paste.':'الحد الأقصى 100 معاملة في كل عملية لصق.');return;}
  final currencyBatch=WaffraSmsCurrencies.summarize(found);
  if(currencyBatch.needsCurrencyReview){
   // No partial automatic commit for a mixed-currency paste.
   update(()=>statusMessage=waffraIsEnglish
    ?'Currency review required: '+currencyBatch.summary+
      '. No transactions were saved. Separate SAR messages or review foreign transactions individually.'
    :'تحتاج العملات إلى مراجعة: '+currencyBatch.summary+
      '. لم يتم حفظ أي عملية. افصل رسائل الريال أو راجع العمليات الأجنبية يدويًا.');
   return;
  }
  // Batch parsing of 20-100 messages must not freeze Android animations
  // or block text/scroll interactions on the Flutter UI isolate.
  final results=found.length>=20
   ?await compute(waffraParseBankSmsBatchInIsolate,found)
   :found.map(BankParser.parse).toList(growable:false);
  if(!ctx.mounted)return;
  final valid=<int>[],invalid=<int>[],duplicates=<int>[];
  final preRejected=<int,WaffraSmsNotSavedReason>{};
  var allowRepeatedSms=false;
  final seen=<String>{};
  for(var i=0;i<found.length;i++){
   if(results[i].amount==null||results[i].amount!<=0){
    invalid.add(i);
    preRejected[i]=WaffraSmsNotSavedReason.amountUnrecognized;
    continue;
   }
   final hash=bankSmsHash(found[i]);
   if(smsHashes.contains(hash)||!seen.add(hash)){
    duplicates.add(i);
    preRejected[i]=WaffraSmsNotSavedReason.alreadySaved;
    continue;
   }
   valid.add(i);
  }
  if(duplicates.isNotEmpty){
   final choice=await showWaffraDialog<String>(context:ctx,builder:(d)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Duplicate transactions detected':'تم اكتشاف معاملات مكررة'),
    content:WaffraText(waffraIsEnglish
     ?'${duplicates.length} transaction(s) are duplicates. You can safely skip those and save the new ones, or explicitly approve adding the duplicates.'
     :'اكتُشفت ${duplicates.length} معاملة مكررة. تخطَّها أو أكّد إضافتها.'),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(d,'cancel')),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(d,'skip')),child:WaffraText(waffraIsEnglish?'Skip duplicates':'تخطي المكررة')),
     FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(d,'add')),child:WaffraText(waffraIsEnglish?'Add duplicates too':'إضافة المكررة أيضًا')),
    ]));
   if(!ctx.mounted||choice==null||choice=='cancel')return;
   if(choice=='add'){
    allowRepeatedSms=true;
    for(final i in duplicates)preRejected.remove(i);
    valid.addAll(duplicates);
    valid.sort();
   }
  }
  if(valid.isEmpty){update(() {statusMessage=waffraIsEnglish?'No new transactions can be saved. Review the messages below.':'لا توجد معاملات جديدة قابلة للحفظ. راجع الرسائل أدناه.';rejectedMessages=[for(final i in preRejected.keys)found[i]];});return;}
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
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,false)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,true)),
       child:WaffraText(waffraIsEnglish?'Confirm and add':'تأكيد وإضافة المعاملات')),
     ],
    )));
  if(accepted!=true||!ctx.mounted)return;
  update(() {busy=true;rejectedMessages=[];});
  // Paint the confirmation feedback before preparing a large SMS batch.
  await WidgetsBinding.instance.endOfFrame;
  if(!ctx.mounted)return;
  final additions=<MoneyEntry>[];
  final proposedSourceIndexes=<int>[];
  final proposed=<BudgetCategory>[];
  final proposedHashes=<String>[];
  for(final i in valid){
   final result=results[i];
   final raw=found[i];
   final existing=<WaffraM155Category>[
    for(final c in [...categories,...proposed])
     WaffraM155Category(id:c.id,name:c.name,income:c.income,parentId:c.parentId),
   ];
   final plan=WaffraM155CategoryPlan.propose(rawSms:raw,income:result.income,
    existing:existing,learned:learnedMerchantCategories);
   if(plan==null){
    preRejected[i]=WaffraSmsNotSavedReason.categoryUnresolved;
    continue;
   }
   if(plan.newCategoryRequired){
    final parentName=plan.categoryName.split(' / ').first;
    final roots=categories.where((c)=>c.income==result.income&&
      !c.isSubcategory&&c.name==parentName).toList();
    if(roots.length!=1){
     preRejected[i]=WaffraSmsNotSavedReason.categoryUnresolved;
     continue;
    }
    final parent=roots.single;
    proposed.add(BudgetCategory(id:newId(),name:plan.categoryName,
     parentId:parent.id,income:result.income,icon:parent.icon,
     color:parent.color));
   }
   final merchant=waffraMerchantName(raw,income:result.income);
   final title=merchant==null?result.title:result.title+' — '+merchant;
   additions.add(MoneyEntry(id:newId(),title:title,
    category:plan.categoryName,amount:result.amount!,income:result.income,
    date:bankSmsDate(raw)??DateTime.now(),notes:raw,sourceType:'sms',
    merchantKey:plan.merchantKey));
   proposedHashes.add(bankSmsHash(raw));
   proposedSourceIndexes.add(i);
  }
  if(additions.isEmpty){
   update((){
    busy=false;
    rejectedMessages=[for(final i in preRejected.keys)found[i]];
    statusMessage=waffraIsEnglish?
     'No transactions were saved. Review and correct the messages below.':
     'لم تُحفظ معاملات. راجع الرسائل أدناه وصحّح بياناتها.';
   });
   return;
  }
  try{
   // The dashboard and standalone Android widget now use the SAME locked,
   // crash-recoverable finance+SMS-hash journal on guarded legacy installs.
   // Never claim a save until the durable journal confirms the actual rows.
   final applied=await _saveProgress.track(
    'commit-confirmed-bank-sms',()=>_financeAuthority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
    records:additions.map((e)=>e.toJson()).toList(growable:false),
    hashes:proposedHashes,
    proposedCategories:proposed.map((c)=>c.toJson()).toList(),
    userConfirmed:true,
    allowDuplicateHashes:allowRepeatedSms,
   ));
   if(!mounted)return;
   final persisted=(jsonDecode(applied.current.ledgerRaw??'[]') as List)
    .map((e)=>MoneyEntry.fromJson(Map<String,dynamic>.from(e as Map)))
    .toList();
   final recovery=WaffraSmsPartialSaveRecovery.reconcile(
    discovered:found,
    rejectedBeforeCommit:preRejected,
    proposedSourceIndexes:proposedSourceIndexes,
    proposedIds:[for(final e in additions)e.id],
    persistedIds:{for(final e in persisted)e.id},
   );
   if(recovery.saved!=applied.saved){
    throw StateError('SMS finance journal does not match persisted transaction IDs.');
   }
   setState((){
    entries..clear()..addAll(persisted);
    if(proposed.isNotEmpty){
     final stored=applied.current.finance.getString('waffra_categories_v24');
     if(stored!=null){
      categories..clear()..addAll((jsonDecode(stored) as List)
       .map((e)=>BudgetCategory.fromJson(Map<String,dynamic>.from(e as Map))));
     }
    }
    smsHashes..clear()..addAll(
     applied.current.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
    _lastFinanceAuthorityRead=applied.current;
    _lastLedgerSavedRaw=applied.current.ledgerRaw;
    _lastWidgetRevision=applied.current.widgetRevision;
   });
   unawaited(_refreshWidget());
   if(!ctx.mounted)return;
   update((){
    busy=false;
    rejectedMessages=[for(final item in recovery.unsaved)item.message];
   });
   if(applied.saved==0){
    update(()=>statusMessage=waffraIsEnglish
     ?'No new transactions were saved. Review the unresolved messages below.'
     :'لم تُحفظ أي معاملات جديدة. راجع الرسائل المتبقية أدناه.');
    return;
   }
   if(!mounted)return;
   final reviewMissing=await showWaffraDialog<bool>(context:context,
    builder:(dialogCtx)=>AlertDialog(
    title:Column(mainAxisSize:MainAxisSize.min,children:[
     Icon(recovery.unsaved.isEmpty?Icons.check_circle_rounded:Icons.warning_amber_rounded,
      color:recovery.unsaved.isEmpty?const Color(0xFF16805E):const Color(0xFFB56A00),size:54),
     const SizedBox(height:16),
     WaffraText(recovery.unsaved.isEmpty
      ?(waffraIsEnglish?'Transactions added successfully':'تمت إضافة المعاملات بنجاح')
      :(waffraIsEnglish?'Some transactions need review':'تم حفظ جزء من المعاملات'),
      textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:22)),
    ]),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText(waffraIsEnglish?
      'Saved ${applied.saved} transactions':'تم حفظ ${applied.saved} معاملة',
      textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w600)),
     const SizedBox(height:14),
     Container(padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:const Color(0xFFE6F4EA),borderRadius:BorderRadius.circular(14)),
      child:Row(children:[
       const Icon(Icons.trending_up,color:Color(0xFF087B56)),
       const SizedBox(width:10),
       Expanded(child:WaffraText(waffraIsEnglish?'Income':'الدخل',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF087B56)))),
       WaffraText('${applied.income} • ${(applied.incomeMinor/100).toStringAsFixed(2)}',
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
       WaffraText('${applied.expenses} • ${(applied.expenseMinor/100).toStringAsFixed(2)}',
        style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFFD65A45))),
      ])),
     if(applied.originalSmsNotesOmittedOnLegacy)...[
      const SizedBox(height:10),
      WaffraText(waffraIsEnglish?
       'Original bank SMS text was NOT stored because encrypted storage is not active. Transaction details were saved.':
       'لم يُحفظ نص الرسالة البنكية الأصلي لأن التخزين المشفر غير مفعّل. تم حفظ بيانات المعاملة فقط.',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Color(0xFFAC5700))),
     ],
     if(recovery.unsaved.isNotEmpty)...[
      const SizedBox(height:12),
      WaffraText(waffraIsEnglish?
       'Not saved: ${recovery.unsaved.length} transactions':
       'لم تُحفظ ${recovery.unsaved.length} معاملة',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w700)),
      if(recovery.unsaved.any((e)=>e.reason==WaffraSmsNotSavedReason.amountUnrecognized))
       WaffraText(waffraIsEnglish
        ?'Cannot read amount: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.amountUnrecognized).length}'
        :'المبلغ غير واضح: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.amountUnrecognized).length}',
        textAlign:TextAlign.center),
      if(recovery.unsaved.any((e)=>e.reason==WaffraSmsNotSavedReason.categoryUnresolved))
       WaffraText(waffraIsEnglish
        ?'Category needs review: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.categoryUnresolved).length}'
        :'القسم يحتاج مراجعة: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.categoryUnresolved).length}',
        textAlign:TextAlign.center),
      if(recovery.unsaved.any((e)=>e.reason==WaffraSmsNotSavedReason.alreadySaved))
       WaffraText(waffraIsEnglish
        ?'Duplicate or excluded by writer: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.alreadySaved).length}'
        :'مكررة أو استبعدها الحفظ: ${recovery.unsaved.where((e)=>e.reason==WaffraSmsNotSavedReason.alreadySaved).length}',
        textAlign:TextAlign.center),
     ],
    ])),
    actionsAlignment:MainAxisAlignment.center,
    actionsPadding:const EdgeInsets.fromLTRB(24,0,24,18),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,false)),
      child:WaffraText(waffraIsEnglish?'Done':'تم')),
     if(recovery.unsaved.isNotEmpty)
      FilledButton.icon(icon:const Icon(Icons.edit_note_rounded),
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,true)),
       label:WaffraText(waffraIsEnglish
        ?'Review ${recovery.unsaved.length} unsaved'
        :'مراجعة ${recovery.unsaved.length} غير محفوظة')),
    ]));
   if(!ctx.mounted)return;
   if(reviewMissing==true&&recovery.unsaved.isNotEmpty){
    update((){
     messages=[for(final item in recovery.unsaved)item.message];
     reviewing=true;
     parsed=true;
     index=0;
     savedCount=0;
     rejectedMessages=[];
     statusMessage='';
    });
    await prepare(0,update);
   }else{
    Navigator.pop(ctx);
   }
  }catch(e){
   // A failed journal must be reconciled by the locked coordinator on next
   // read; never mutate the dashboard as if the save had succeeded.
   if(ctx.mounted){update(()=>busy=false);snack(ctx,waffraIsEnglish?'Saving could not be confirmed. Please retry safely.':'تعذر تأكيد الحفظ. أعد المحاولة بأمان.');}
  }
 }

 // AI runs automatically on paste/share; it never saves money.
 Future<void> analyzeBankSmsAutomatically(
    BuildContext ctx,StateSetter update,String input,int revision)async{
  if(!sheetActive||!ctx.mounted||pasteRevision!=revision||
     pasted.text.trim()!=input)return;
  final found=splitBankMessages(input);
  if(found.isEmpty||found.length>100){
   update((){
    analyzingPaste=false;parsed=true;messages=found;
    statusMessage=found.isEmpty?
     (waffraIsEnglish?'No bank messages found.':'لم نجد رسائل بنكية.'):
     (waffraIsEnglish?'Maximum 100 messages per paste.':
      'الحد الأقصى 100 رسالة لكل لصق.');
   });
   return;
  }
  final ai=await _reviewAiPastedBankMessages(ctx,input);
  if(!sheetActive||!ctx.mounted||pasteRevision!=revision||
     pasted.text.trim()!=input)return;
  var verified=ai!=null&&ai.error==null&&ai.count==found.length;
  if(verified){
   for(var i=0;i<found.length;i++){
    final draft=BankParser.parse(found[i]);
    final item=ai!.items[i];
    final evidence=WaffraSmsCurrencies.originalAmount(found[i]);
    final amount=item.amountText==null?null:
      WaffraReceiptOcrParser.amountFromText(item.amountText!);
    // Confirm that SAR amount is the transaction, not card ID or balance.
    // A disagreement never authorizes automatic finance confirmation.
    if(item.needsReview||item.currency!='SAR'||
       evidence==null||evidence.currency!='SAR'||
       !found[i].contains(item.quote)||
       draft.amount==null||amount==null||
       (evidence.amount-amount).abs()>0.00001||
       (draft.amount!-evidence.amount).abs()>0.00001||
       draft.income!=(item.direction==WaffraAiDirection.income)){
     verified=false;
     break;
    }
   }
  }
  update((){
   messages=found;parsed=true;analyzingPaste=false;
   statusMessage=noTransactionWarning(input)??'';
   if(statusMessage.isEmpty&&!verified){
    statusMessage=waffraIsEnglish?
     'AI could not verify every message. Review before saving.':
     'الذكاء لم يؤكد كل الرسائل. راجعها قبل الحفظ.';
   }
  });
  if(verified&&statusMessage.isEmpty){
   // Explicit confirmation and verified encrypted SMS writer remain mandatory.
   await saveParsedMessages(ctx,update);
  }
 }
 void scheduleBankSmsAnalysis(
     BuildContext ctx,StateSetter update,String input){
  pasteTimer?.cancel();
  final revision=++pasteRevision;
  update((){
   parsed=false;analyzingPaste=input.trim().isNotEmpty;
   messages=[];statusMessage='';reviewing=false;index=0;
  });
  if(input.trim().isEmpty)return;
  pasteTimer=Timer(const Duration(milliseconds:650),(){
   if(!sheetActive||!ctx.mounted||pasteRevision!=revision||
      pasted.text.trim()!=input.trim())return;
   unawaited(analyzeBankSmsAutomatically(ctx,update,input.trim(),revision));
  });
 }

 void disposeLater(){
  pasteTimer?.cancel();
  Future<void>.delayed(const Duration(milliseconds:500),(){
   pasted.dispose();description.dispose();amount.dispose();
  });
 }
 BuildContext? activeSmsContext;
 StateSetter? activeSmsUpdate;
 bool awaitingMessagesApp=false;
 bool initialParsed=false;
 void analyzeSharedText(String text){
  final ctx=activeSmsContext,update=activeSmsUpdate;
  if(!sheetActive||ctx==null||!ctx.mounted||update==null||text.trim().isEmpty)return;
  pasted.text=text.trim();
  scheduleBankSmsAnalysis(ctx,update,text.trim());
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
   if(sheetActive&&value!=null&&value.isNotEmpty){
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
   final pasteSummary=waffraSummarizeBankPaste(pasted.text,smsHashes);
   final currencyPreview=WaffraSmsCurrencies.summarize(messages);
   return Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(ctx).viewInsets.bottom+24),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Row(children:[Expanded(child:WaffraText(waffraIsEnglish?'Add bank message':'إضافة رسالة بنكية',style:Theme.of(ctx).textTheme.titleLarge)),IconButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),icon:const Icon(Icons.close_rounded))]),
     WaffraText(waffraIsEnglish?'Paste messages to analyze them automatically.':'الصق رسائلك البنكية ليتم تحليلها وتصنيفها تلقائيًا.'),
     const SizedBox(height:12),
     if(!reviewing)...[
      TextField(controller:pasted,minLines:5,maxLines:9,onChanged:(text){
       if(!sheetActive||!ctx.mounted)return;
       scheduleBankSmsAnalysis(ctx,update,text);
      },decoration:InputDecoration(labelText:waffraIsEnglish?'Bank SMS *':'الرسالة البنكية *',
       errorText:pasteAttempted&&pasted.text.trim().isEmpty?waffraRequiredFieldMessage:null,errorMaxLines:3,
       hintText:waffraIsEnglish?'Paste your bank message here. We’ll analyze it automatically.':'الصق رسالتك البنكية هنا، وبنحلّلها لك تلقائيًا.',hintStyle:const TextStyle(fontSize:13,color:Color(0xFF888F8A)),
       suffixIcon:pasted.text.isNotEmpty?IconButton(tooltip:waffraIsEnglish?'Clear text':'مسح النص',icon:const Icon(Icons.clear_rounded,color:Colors.redAccent),onPressed:WaffraHaptics.tap((){pasteTimer?.cancel();++pasteRevision;pasted.clear();update((){parsed=false;analyzingPaste=false;messages=[];statusMessage='';});})):null,
       border:OutlineInputBorder(borderRadius:BorderRadius.circular(18)))),
      const SizedBox(height:12),
     if(statusMessage.isNotEmpty&&pasted.text.trim().isNotEmpty)...[
      Container(
       key:const Key('waffra-sms-review-notice'),
       padding:const EdgeInsets.all(11),
       decoration:BoxDecoration(
        color:Theme.of(ctx).colorScheme.surfaceContainerHighest,
        borderRadius:BorderRadius.circular(12)),
       child:WaffraText(statusMessage,maxLines:5)),
      const SizedBox(height:8),
     ],
     LayoutBuilder(builder:(layoutContext,constraints){
      final stack=constraints.maxWidth<318||
       MediaQuery.textScalerOf(layoutContext).scale(14)>20;
      final pasteAction=OutlinedButton.icon(
       key:const Key('waffra-sms-paste-action'),
       icon:const Icon(Icons.content_paste,size:18),
       onPressed:WaffraHaptics.tap(busy?null:()async{
        final data=await Clipboard.getData(Clipboard.kTextPlain);
        if(!ctx.mounted)return;
        final text=data?.text?.trim()??'';
        if(text.isEmpty){
         update((){pasteAttempted=true;statusMessage=waffraRequiredFieldMessage;});
         return;
        }
        pasted.text=text;
        scheduleBankSmsAnalysis(ctx,update,text);
       }),
       label:WaffraText(stack?
        (waffraIsEnglish?'Paste copied SMS':'لصق آخر رسالة نسختها'):
        (waffraIsEnglish?'Paste SMS':'لصق رسالة'),
        maxLines:2,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
      );
      final messagesAction=OutlinedButton.icon(
       key:const Key('waffra-sms-open-messages-action'),
       icon:const Icon(Icons.message_outlined,size:18),
       onPressed:WaffraHaptics.tap(busy?null:()async{
        awaitingMessagesApp=true;
        final launched=await openWaffraMessagesApp();
        if(!launched&&ctx.mounted){
         awaitingMessagesApp=false;
         update(()=>statusMessage=waffraIsEnglish
          ?'Could not open Messages. Copy a message and paste it here instead.'
          :'تعذر فتح تطبيق الرسائل. انسخ الرسالة والصقها هنا بدلًا من ذلك.');
        }
       }),
       label:WaffraText(stack?
        (waffraIsEnglish?'Open phone messages':'فتح رسائل الهاتف'):
        (waffraIsEnglish?'Messages app':'فتح الرسائل'),
        maxLines:2,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
      );
      return stack?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       pasteAction,const SizedBox(height:8),messagesAction,
      ]):Row(children:[
       Expanded(child:pasteAction),const SizedBox(width:10),
       Expanded(child:messagesAction),
      ]);
     }),
      if(currencyPreview.needsCurrencyReview)...[
       const SizedBox(height:8),
       Container(
        key:const Key('m291-bank-sms-currency-warning'),
        padding:const EdgeInsets.all(11),
        decoration:BoxDecoration(
         color:Theme.of(ctx).colorScheme.errorContainer,
         borderRadius:BorderRadius.circular(14)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         WaffraText(currencyPreview.hasMixedCurrencies?
          (waffraIsEnglish?'Multiple currencies detected':'تم اكتشاف أكثر من عملة'):
          (waffraIsEnglish?'Foreign currency detected':'تم اكتشاف عملة أجنبية'),
          style:const TextStyle(fontWeight:FontWeight.bold)),
         WaffraText(currencyPreview.summary),
         if(messages.length==1&&WaffraSmsCurrencies.originalAmountPreview(messages.first)!=null)
          WaffraText((waffraIsEnglish?
           'Original transaction amount: ':'المبلغ الأصلي للعملية: ')+
           WaffraSmsCurrencies.originalAmountPreview(messages.first)!,
           style:const TextStyle(fontWeight:FontWeight.w700)),
         WaffraText(waffraIsEnglish?
          'Foreign currency needs verified conversion before saving as SAR. Balance is not a transaction.':
          'المبلغ الأجنبي لا يُحفظ كريال. راجع القيمة الأصلية وسعر الصرف أولاً؛ الرصيد ليس معاملة.'),
        ])),
      ],
      if(analyzingPaste)...[const SizedBox(height:12),const LinearProgressIndicator(),const SizedBox(height:6),WaffraText(waffraIsEnglish?'Analyzing bank messages with AI…':'جاري الآن تحليل الرسائل بالذكاء الاصطناعي…')],
      // Shared lightweight in-dialog progress while the batch is committed.
      if(busy)Padding(
       key:const Key('waffra-bank-sms-save-progress'),
       padding:const EdgeInsets.symmetric(vertical:12),
       child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        const SizedBox(width:20,height:20,
         child:CircularProgressIndicator(strokeWidth:2.5)),
        const SizedBox(width:10),
        WaffraText(waffraIsEnglish?'Saving confirmed transactions…':
         'جارٍ حفظ المعاملات المؤكدة…',
         style:const TextStyle(fontWeight:FontWeight.w700)),
       ])),
      
      if(rejectedMessages.isNotEmpty)...[
       const SizedBox(height:8),
       WaffraText(waffraIsEnglish?'Unrecognized messages — edit and retry':'رسائل لم يتم تحليلها — راجعها وأعد المحاولة',style:const TextStyle(fontWeight:FontWeight.bold)),
       ...rejectedMessages.asMap().entries.map((item)=>Card(child:ListTile(
        title:WaffraText(waffraIsEnglish?'Message ${item.key+1}':'رسالة ${item.key+1}'),
        subtitle:SelectableText(item.value,maxLines:4),
        trailing:IconButton(icon:const Icon(Icons.edit_outlined),tooltip:waffraIsEnglish?'Review manually':'مراجعة يدويًا',onPressed:WaffraHaptics.tap((){
         Navigator.pop(ctx);
         entrySheet(sms:true,initialSms:item.value);
        }))))),
      ],
     if(parsed&&messages.isNotEmpty&&statusMessage.isNotEmpty&&!reviewing)...[
       const SizedBox(height:10),
       FilledButton.icon(
        key:const Key('waffra-sms-review-unverified'),
        onPressed:busy?null:WaffraHaptics.tap(()async{
         update(()=>reviewing=true);
         await prepare(0,update);
        }),
        icon:const Icon(Icons.fact_check_outlined),
        label:WaffraText(waffraIsEnglish?
         'Review manually':'مراجعة الرسائل يدويًا')),
      ],
      if(parsed&&statusMessage.isEmpty)...[
      const SizedBox(height:10),
      Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
       decoration:BoxDecoration(color:Theme.of(ctx).brightness==Brightness.dark?const Color(0xFF123E32):const Color(0xFFE8F6EF),
        border:Border.all(color:emerald.withValues(alpha:.25)),borderRadius:BorderRadius.circular(16)),
       child:Row(children:[const Icon(Icons.check_circle_outline,color:emerald,size:19),const SizedBox(width:8),
        Expanded(child:WaffraText(waffraIsEnglish
         ?'Detected ${pasteSummary.detected} • New ${pasteSummary.fresh} • Duplicates ${pasteSummary.duplicates}'
         :'تم اكتشاف ${pasteSummary.detected} معاملة • الجديدة ${pasteSummary.fresh} • المكررة ${pasteSummary.duplicates}',
         maxLines:2,
         style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)))])),
     ],
     ]else...[
      TextButton.icon(onPressed:WaffraHaptics.tap(busy?null:()async{
       final yes=await confirmDeletion(
        waffraIsEnglish?'Clear pasted messages?':'حذف الرسائل الملصوقة',
        waffraIsEnglish?'Discard the unsaved pasted text and start again?':'هل تريد حذف الرسائل غير المحفوظة والبدء من جديد؟');
       if(yes!=true||!ctx.mounted)return;
       update((){reviewing=false;parsed=false;messages=[];index=0;pasted.clear();description.clear();amount.clear();});
      }),icon:const Icon(Icons.delete_outline),label:const WaffraText('حذف النص بالكامل ولصق رسائل جديدة')),
      WaffraText(waffraIsEnglish?'Transaction ${index+1} of ${messages.length} — Total: ${cash(total)}':'المعاملة ${index+1} من ${messages.length} — إجمالي المبالغ: ${cash(total)}',style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      WaffraText(waffraIsEnglish?'Saved $savedCount / ${messages.length}. Review remaining transactions before saving.':'تم حفظ $savedCount من ${messages.length} معاملات. راجع كل معاملة وحدد قسمها قبل الحفظ.'),
      const SizedBox(height:12),
      InputDecorator(decoration:InputDecoration(labelText:waffraTr('نص الرسالة الحالية'),border:OutlineInputBorder()),
       child:SelectableText(messages[index])),
      const SizedBox(height:12),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:WaffraText('دخل')),
       ButtonSegment(value:false,label:WaffraText('مصروف'))],selected:{income},onSelectionChanged:WaffraHaptics.selection((v)=>update((){
        income=v.first;category=forType(income).isNotEmpty?forType(income).first.name:'أخرى';
       }))),
      const SizedBox(height:12),
      TextField(controller:description,maxLines:2,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'وصف الرسالة *',errorText:reviewAttempted?waffraTextFieldError(description.text):null,border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'مبلغ هذه الرسالة بالريال *',errorText:reviewAttempted?waffraAmountFieldError(amount.text):null,border:OutlineInputBorder())),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey('$index-$income'),initialValue:available.any((c)=>c.name==category)?category:null,
       items:available.map((c)=>DropdownMenuItem(value:c.name,child:WaffraText(c.name))).toList(),
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Message category *':'قسم هذه الرسالة *',
        errorText:reviewAttempted&&WaffraValidators.requiredCategory(
         category,available.map((c)=>c.name))!=null?waffraRequiredFieldMessage:null,
        border:OutlineInputBorder()),
       onChanged:WaffraHaptics.selection((v){if(v!=null)update(()=>category=v);})),
      const SizedBox(height:12),
      FilledButton(onPressed:WaffraHaptics.tap(busy?null:()async{
       final n=amountOf(amount.text);
       update(()=>reviewAttempted=true);
        if(waffraTextFieldError(description.text)!=null||
        waffraAmountFieldError(amount.text)!=null||n==null||
        WaffraValidators.requiredCategory(category,available.map((c)=>c.name))!=null)return;
       final hash=bankSmsHash(messages[index]);
       var explicitlyApprovedDuplicate=false;
       if(smsHashes.contains(hash)){
        final yes=await showWaffraDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
         title:const WaffraText('⚠️ رسالة مكررة'),content:const WaffraText('هذي الرسالة سبق حفظها. ودّك تضيفها مرة ثانية؟'),
         actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(d,false)),child:const WaffraText('إلغاء')),
          FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(d,true)),child:const WaffraText('إضافة على أي حال'))]));
        if(yes!=true||!ctx.mounted)return;
        explicitlyApprovedDuplicate=true;
       }
       update(()=>busy=true);
       final now=DateTime.now();
       final previous=sum(entries.where((e)=>!e.income&&e.category==category&&e.date.year==now.year&&e.date.month==now.month),false);
       final entry=MoneyEntry(id:newId(),title:description.text.trim(),category:category,amount:n,income:income,date:now,notes:messages[index],sourceType:'sms');
       // A parsed SMS is not saved until both the transaction and its
       // fingerprint are crash-journaled under the SAME Home/Widget lock.
       // A stale dashboard must never overwrite a newer widget ledger.
       final committed=await _financeAuthority.commitConfirmedSms(
        route:WaffraFinanceRoute.bulkSmsConfirmedSave,
        records:[Map<String,Object?>.from(entry.toJson())],
        hashes:[hash],
        userConfirmed:true,
        allowDuplicateHashes:explicitlyApprovedDuplicate,
       );
       if(committed.saved!=1){
        if(ctx.mounted)update((){
         busy=false;
         statusMessage=waffraIsEnglish
          ?'This message was already saved. Review before trying again.'
          :'تم حفظ هذه الرسالة من قبل. راجعها قبل إعادة المحاولة.';
        });
        return;
       }
       final verified=(jsonDecode(committed.current.ledgerRaw??'[]') as List)
        .map((item)=>MoneyEntry.fromJson(
         Map<String,dynamic>.from(item as Map))).toList();
       if(!mounted)return;
       setState((){
        entries..clear()..addAll(verified);
        smsHashes..clear()..addAll(
         committed.current.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
        _lastFinanceAuthorityRead=committed.current;
        _lastLedgerSavedRaw=committed.current.ledgerRaw;
        _lastWidgetRevision=committed.current.widgetRevision;
       });
       unawaited(_refreshWidget());
       if(!ctx.mounted)return;
       await budgetAlert(entry,previous);
       if(!ctx.mounted)return;
       savedCount++;
       if(index+1>=messages.length){
        Navigator.pop(ctx);
        if(mounted)snackSuccess(context,committed.originalSmsNotesOmittedOnLegacy?
         (waffraIsEnglish?'Saved $savedCount transactions; original SMS text was not stored.':
          'تم حفظ $savedCount عملية دون نص الرسالة البنكية الأصلي.'):
         'تم حفظ $savedCount عملية بنجاح');
       }
       else{await prepare(index+1,update);update(()=>busy=false);}
      }),child:WaffraText(index+1==messages.length?'إضافة المعاملة وحفظها':'إضافة المعاملة وحفظها ثم التالي')),
      if(index+1<messages.length)TextButton(onPressed:WaffraHaptics.tap(busy?null:()=>prepare(index+1,update)),child:const WaffraText('تخطي هذه الرسالة')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:WaffraHaptics.tap(busy?null:()async{
       final yes=await confirmDeletion(
        waffraIsEnglish?'Clear pasted messages?':'حذف الرسائل الملصوقة',
        waffraIsEnglish?'Discard all unsaved pasted text? Saved transactions will remain.':'هل تريد حذف النص غير المحفوظ؟ المعاملات المحفوظة ستظل موجودة.');
       if(yes!=true||!ctx.mounted)return;
       update((){reviewing=false;parsed=false;messages=[];index=0;savedCount=0;pasted.clear();description.clear();amount.clear();});
      }),icon:const Icon(Icons.delete_forever_outlined),label:const WaffraText('حذف النص بالكامل وإضافة رسائل أخرى')),
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

 Future<bool> _canReviewOcrAsLedgerTransaction(String raw)async {
  if(!WaffraBankScreenshotParser.requiresForeignCurrencyReview(raw))return true;
  if(!mounted)return false;
  // A foreign OCR image has no verified FX provenance and must NEVER be
  // relabeled as SAR by allowing manual numeric input in an SAR-only sheet.
  final currencyCodes=WaffraSmsCurrencies.currenciesForMessage(raw);
  final label=currencyCodes.isEmpty?
   (waffraIsEnglish?'foreign currency':'عملة أجنبية'):
   currencyCodes.join(' / ');
  await showWaffraDialog<void>(context:context,builder:(dialog)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?
    'Foreign currency requires review':'عملية بعملة أجنبية تحتاج مراجعة'),
   content:WaffraText(waffraIsEnglish?
    'Detected $label. This amount cannot be saved as SAR without verified conversion. Review other SAR entries.':
    'تم اكتشاف $label. لا يمكن حفظ هذا المبلغ باعتباره ريالًا سعوديًا بدون تحويل موثوق. راجع بقية العمليات.'),
   actions:[FilledButton(
    onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog)),
    child:WaffraText(waffraIsEnglish?'Understood':'فهمت'))],
  ));
  return false;
 }

 /// Show visible, blocking feedback for local OCR/AI work. The overlay is
 /// always removed on success, cancellation and exceptions; the task cannot
 /// submit a finance write.
 Future<T> _withAiWorkProgress<T>(String arabic,String english,
     Future<T> Function() operation)async{
  if(!mounted)throw StateError('ai_screen_unmounted');
  final overlay=Overlay.of(context,rootOverlay:true);
  final cancellation=Completer<T>();
  var completed=false;
  void cancelAnalysis(){
   if(completed)return;
   completed=true;
   WaffraOnDeviceQwen.shared.cancelCurrentGeneration();
   cancellation.completeError(StateError('ai_analysis_cancelled'));
  }
  final item=OverlayEntry(builder:(progressContext)=>Positioned.fill(
   child:Material(
    color:Colors.black54,
    child:Center(child:Semantics(
     liveRegion:true,label:waffraIsEnglish?english:arabic,
     child:Card(child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:24,vertical:18),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       const CircularProgressIndicator(
        key:Key('waffra-ai-analysis-progress')),
       const SizedBox(height:16),
       WaffraText(waffraIsEnglish?english:arabic,
        textAlign:TextAlign.center),
       const SizedBox(height:10),
       TextButton(
        key:const Key('waffra-ai-analysis-cancel'),
        onPressed:cancelAnalysis,
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      ]))))))));
  overlay.insert(item);
  try{
   // Register the cancel future before the first frame delay, so a fast
   // user cancellation cannot produce an uncaught asynchronous error.
   final work=(()async{
    await Future<void>.delayed(const Duration(milliseconds:30));
    if(completed)throw StateError('ai_analysis_cancelled');
    return await operation();
   })();
   return await Future.any<T>([work,cancellation.future])
       .timeout(const Duration(seconds:60),onTimeout:(){
    WaffraOnDeviceQwen.shared.cancelCurrentGeneration();
    throw TimeoutException('waffra_ai_analysis_timeout');
   });
  }finally{
   completed=true;
   item.remove();
   item.dispose();
  }
 }

 Future<WaffraAiResult?> _reviewAiPastedBankMessages(
     BuildContext ctx,String source)async {
  if(!WaffraOnDeviceQwen.shared.isReady||source.trim().isEmpty)return null;
  try{
   return await _withAiWorkProgress(
    'جاري الآن تحليل الرسائل بالذكاء الاصطناعي…',
    'Analyzing bank messages with AI…',
    ()=>WaffraAiFinanceBrain.bankSms(source,
     generate:WaffraOnDeviceQwen.shared.textGenerator));
  }on TimeoutException{
   if(ctx.mounted)snack(ctx,waffraIsEnglish?
    'AI timed out. Review the original messages manually.':
    'انتهت مهلة التحليل. راجع الرسائل يدويًا.');
  }on StateError catch(error){
   if(error.message!='ai_analysis_cancelled'&&ctx.mounted){
    snack(ctx,waffraIsEnglish?'AI analysis unavailable.':'التحليل غير متاح.');
   }
  }
  return null;
 }

 /// Each image action remains a separate review row. This helper never
 /// commits a record and cannot post foreign-currency AI output as SAR.
 Future<bool> _reviewAiScannedTransactions(
     String sourceText,XFile image)async{
  if(!WaffraOnDeviceQwen.shared.isReady)return false;
  // Cancellation or native timeout must return to the guarded OCR review
  // path rather than escaping as an unhandled async error.
  WaffraAiResult result;
  try{
   result=await _withAiWorkProgress(
    'جاري تحليل بيانات الصورة بالذكاء الاصطناعي…',
    'Analyzing image text with on-device AI…',
    ()=>WaffraAiFinanceBrain.imageOcr(sourceText,
     generate:WaffraOnDeviceQwen.shared.textGenerator));
  }on TimeoutException{
   if(mounted)snack(context,waffraIsEnglish?
    'AI timed out. Review the extracted image transactions manually.':
    'انتهت مهلة تحليل الصورة. راجع العمليات المستخرجة يدويًا.');
   return false;
  }on StateError catch(error){
   if(error.message!='ai_analysis_cancelled'&&mounted){
    snack(context,waffraIsEnglish?
     'AI analysis was interrupted. Review the extracted transactions.':
     'توقف تحليل الذكاء. راجع العمليات المستخرجة.');
   }
   return false;
  }catch(_){
   if(mounted)snack(context,waffraIsEnglish?
    'AI analysis unavailable. Review the extracted transactions.':
    'تعذر تحليل الصورة بالذكاء. راجع العمليات المستخرجة.');
   return false;
  }
  if(!mounted)return false;
  if(result.error!=null||result.count==0){
   snack(context,waffraIsEnglish?
    'AI analysis could not confirm transactions. Check the OCR results.':
    'لم يتأكد تحليل الذكاء من العمليات. راجع نتائج قراءة الصورة.');
   return false;
  }
  final bankImage=WaffraBankScreenshotParser.looksLikeBankScreenshot(sourceText);
  if(bankImage&&
     !WaffraAiFinanceBrain.matchesVerifiedImageActions(sourceText,result)){
   if(mounted)snack(context,waffraIsEnglish?
    'AI results do not match the image. Verify each OCR transaction.':
    'نتائج الذكاء مش مطابقة للصورة. راجع كل عملية من النص المستخرج.');
   return false;
  }
  // Product lines from one shop receipt must not be counted as independent
  // finance transactions, even if a tiny model hallucinated separate actions.
  if(!bankImage&&result.count>1)return false;
  final selected=<int>{};
  final indices=await showWaffraDialog<List<int>>(context:context,
   builder:(dialog)=>StatefulBuilder(builder:(dialog,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?
     'AI detected '+result.count.toString()+' transactions':
     'AI اكتشف '+result.count.toString()+' معاملات'),
    content:SizedBox(width:420,child:SingleChildScrollView(child:
     Column(mainAxisSize:MainAxisSize.min,children:[
      WaffraText(waffraIsEnglish?
       'Review each proposed transaction. Unverified/foreign amounts '
       'cannot be saved as Saudi Riyals.':
       'راجع كل عملية. العمليات غير المؤكدة أو الأجنبية لا يمكن '
       'حفظها باعتبارها ريالًا سعوديًا.'),
      for(var i=0;i<result.items.length;i++)
       CheckboxListTile(
        value:selected.contains(i),
        onChanged:result.items[i].needsReview?null:(value)=>update((){
         if(value==true)selected.add(i);else selected.remove(i);
        }),
        title:WaffraText(
         (i+1).toString()+'. '+
         (result.items[i].amountText??'—')+' '+
         (result.items[i].currency??'?')+' • '+
         (result.items[i].direction==WaffraAiDirection.income?
          (waffraIsEnglish?'Income':'دخل'):
          (waffraIsEnglish?'Expense':'مصروف'))),
        subtitle:WaffraText(result.items[i].needsReview?
         (waffraIsEnglish?'Review required: ':'تحتاج مراجعة: ')+
          result.items[i].reason:
         (result.items[i].merchant??result.items[i].quote),
         maxLines:3),
       ),
     ]))),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:selected.isEmpty?null:()=>
       Navigator.pop(dialog,selected.toList()..sort()),
      child:WaffraText(waffraIsEnglish?'Review selected':'مراجعة المحدد')),
    ],
   )));
  if(indices==null||!mounted)return true;
  for(final index in indices){
   if(!mounted)return true;
   final item=result.items[index];
   if(item.needsReview||item.currency!='SAR')continue;
   final safeAmount=item.amountText==null?null:
      WaffraReceiptOcrParser.amountFromText(item.amountText!);
   await entrySheet(
    scannedReceipt:WaffraReceiptOcrFields(
     rawText:item.quote,
     merchant:item.merchant!=null&&item.quote.contains(item.merchant!)?
      item.merchant:null,
     amount:safeAmount),
    scannedIncome:item.direction==WaffraAiDirection.income,
    scannedImage:image);
  }
  return true;
 }

 Future<void> scanAndAddReceipt()async {
  // Restrict OCR before any camera/gallery permission or image processing.
  if(_receiptOcrAiOpening)return;
  _receiptOcrAiOpening=true;
  bool allowed=false;
  try{allowed=await _requireReceiptOcrAi();}
  finally{_receiptOcrAiOpening=false;}
  if(!allowed||!mounted)return;
  // Ask only for the exact camera/gallery access the user selected.
  final source=await showWaffraDialog<ImageSource>(context:context,builder:(dialog)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Add from receipt or image':'إضافة عملية من فاتورة أو صورة'),
   content:WaffraText(waffraIsEnglish?
    'Scan a receipt, transfer notice or bank screenshot. Review every amount and type before saving.':
    'صوّر فاتورة أو اختر إيصال تحويل أو صورة رسائل بنكية. راجع كل مبلغ ونوع عملية قبل الحفظ.'),
   actions:[
    TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
    OutlinedButton.icon(icon:const Icon(Icons.photo_library_outlined),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog,ImageSource.gallery)),
     label:WaffraText(waffraIsEnglish?'Gallery':'المعرض')),
    FilledButton.icon(icon:const Icon(Icons.camera_alt_outlined),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog,ImageSource.camera)),
     label:WaffraText(waffraIsEnglish?'Camera':'الكاميرا')),
   ]));
  if(source==null||!mounted)return;
  try{
   final picked=await ImagePicker().pickImage(source:source,imageQuality:95);
   if(picked==null||!mounted)return;
   final extracted=await _withAiWorkProgress(
    'جاري قراءة الصورة واستخراج بيانات المعاملات…',
    'Reading image and extracting transactions…',
    ()=>WaffraReceiptOcr.scan(picked.path));
   if(!mounted)return;
   // The on-device AI model is mandatory. Continue safeguarding currency
   // and amount reviews, never uploading the user image.
   if(!WaffraOnDeviceQwen.shared.isReady){
    if(mounted)snack(context,waffraIsEnglish?
     'OCR requires an active AI model. Reopen the scanner to download it.':
     'استخراج بيانات الصور يحتاج نموذج ذكاء اصطناعي فعّال. افتح الماسح لتنزيله.');
    return;
   }
   if(await _reviewAiScannedTransactions(extracted.rawText,picked))return;
   if(!mounted)return;
   final candidates=WaffraBankScreenshotParser.reviewItems(extracted.rawText);
   if(candidates.isEmpty){
    if(!await _canReviewOcrAsLedgerTransaction(extracted.rawText))return;
    // Do not reuse speculative OCR merchant/amount for an SMS screenshot.
    final suggestion=WaffraBankScreenshotParser.looksLikeBankScreenshot(extracted.rawText)?
     WaffraReceiptOcrFields(rawText:extracted.rawText):extracted;
    await entrySheet(scannedReceipt:suggestion,scannedImage:picked);
    return;
   }
   if(candidates.length==1){
    final one=candidates.single;
    if(!await _canReviewOcrAsLedgerTransaction(one.sourceText))return;
    await entrySheet(
     scannedReceipt:WaffraReceiptOcrFields(rawText:one.sourceText,
      merchant:one.merchant,amount:one.amount,date:one.date),
     scannedIncome:one.income,scannedImage:picked,
     scannedImagePosition:one.position,scannedImageTotal:candidates.length);
    return;
   }
   // One screenshot may have independent transactions. Require explicit user
   // selection, then full review of each via the existing finance entry gate.
   final chosen=<int>{for(var i=0;i<candidates.length;i++)i};
   final selected=await showWaffraDialog<List<int>>(context:context,
    builder:(dialog)=>StatefulBuilder(builder:(dialog,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Detected '+candidates.length.toString()+' transactions':'تم اكتشاف '+candidates.length.toString()+' عمليات'),
     content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
       WaffraText(waffraIsEnglish?
        'Review selected entries in image order. Enter unclear amounts manually; nothing is saved automatically.':
        'راجع العمليات بالترتيب. أدخل المبالغ غير الواضحة يدويًا؛ لا حفظ تلقائي.'),
       for(var i=0;i<candidates.length;i++)
        CheckboxListTile(
         value:chosen.contains(i),
         onChanged:WaffraHaptics.selection((value)=>update((){
          if(value==true){chosen.add(i);}else{chosen.remove(i);}
         })),
         title:WaffraText((waffraIsEnglish?'Transaction ':'العملية ')+(i+1).toString()+(waffraIsEnglish?' of ':' من ')+candidates.length.toString()+' — '+(candidates[i].amount==null?(waffraIsEnglish?'Amount unclear':'المبلغ غير واضح'):candidates[i].amount!.toStringAsFixed(2)+' SAR')),
         subtitle:WaffraText(candidates[i].merchant??(waffraIsEnglish?'Unconfirmed source':'اسم غير مؤكد')),
        ),
      ]))),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:chosen.isEmpty?null:WaffraHaptics.tap(
       ()=>Navigator.pop(dialog,chosen.toList()..sort())),
       child:WaffraText(waffraIsEnglish?'Review selected':'مراجعة المحدد')),
     ],
    )));
   if(selected==null||!mounted)return;
   for(final index in selected){
    if(!mounted)return;
    final candidate=candidates[index];
    if(!await _canReviewOcrAsLedgerTransaction(candidate.sourceText))continue;
    await entrySheet(
     scannedReceipt:WaffraReceiptOcrFields(rawText:candidate.sourceText,
      merchant:candidate.merchant,amount:candidate.amount,date:candidate.date),
     scannedIncome:candidate.income,scannedImage:picked,
     scannedImagePosition:candidate.position,scannedImageTotal:candidates.length);
   }
  }on TimeoutException catch(_){
   if(mounted)snack(context,waffraIsEnglish?
    'Analysis took too long. Try a smaller image or add manually.':
    'التحليل استغرق وقتًا طويلًا. جرّب صورة أصغر أو أضف يدويًا.');
  }on StateError catch(error){
   if(error.message=='ai_analysis_cancelled')return;
   if(mounted)snack(context,waffraIsEnglish?
    'Could not complete analysis. Try again or add manually.':
    'تعذر إكمال التحليل. حاول مجددًا أو أضف يدويًا.');
  }on WaffraReceiptOcrException catch(error){
   if(mounted)snack(context,waffraIsEnglish?
    'Image recognition is unavailable (${error.code}). You can add the transaction manually.':
    'تعذر التعرف على الصورة (${error.code}). يمكنك إضافة العملية يدويًا.');
  }catch(error){
   debugPrint('Receipt import review failed without a finance write: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Could not read this image. Try a clearer image or add manually.':
    'تعذر قراءة الصورة. جرّب صورة أوضح أو أضف العملية يدويًا.');
  }
 }

 Future<void> entrySheet({MoneyEntry? initial,bool sms=false,String? initialSms,
  WaffraReceiptOcrFields? scannedReceipt,XFile? scannedImage,bool? scannedIncome,
  int? scannedImagePosition,int? scannedImageTotal})async {
  // Manual entries and edits stay available; new SMS and OCR routes are gated.
  if(initial==null&&(sms||scannedReceipt!=null||scannedImage!=null)){
   final allowed=await (sms?_requireBankSmsAi():_requireReceiptOcrAi());
   if(!allowed||!mounted)return;
  }
  // Last defense: every OCR entry must verify the currency *inside* the
  // editor too, so future callers cannot bypass scanAndAddReceipt's gate.
  if(scannedReceipt!=null &&
      WaffraBankScreenshotParser.requiresForeignCurrencyReview(
          scannedReceipt.rawText)) {
    await _canReviewOcrAsLedgerTransaction(scannedReceipt.rawText);
    return;
  }
  final title=TextEditingController(text:initial?.title??scannedReceipt?.merchant??'');
  final notes=TextEditingController(text:initial?.notes??'');
  final value=TextEditingController(text:initial!=null?formatWaffraEditAmount(initial.amount):
   scannedReceipt?.amount!=null?formatWaffraEditAmount(scannedReceipt!.amount!):'');
  final message=TextEditingController(text:initialSms??'');
  bool income=initial?.income??scannedIncome??false,analyzing=false,hasParsed=initialSms!=null;
  bool submitTapped=false;
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
    final legacyParent=categories.where((c)=>c.income==income&&
     !c.isSubcategory&&c.name==category).toList();
    selectedParentId=legacyParent.isEmpty?null:legacyParent.first.id;
    category='';
   }
  }
  DateTime date=initial?.date??scannedReceipt?.date??DateTime.now();
   String? suggestion,pendingHash,receiptPath=initial?.receiptPath;
   final stagedReceiptCopies=<String>[];
   if(scannedImage!=null){
    try{
     final copy=await saveReceipt(scannedImage);
     stagedReceiptCopies.add(copy);
     receiptPath=waffraEncodeReceipts([...waffraReceiptPaths(receiptPath),copy]);
    }catch(error){
     debugPrint('Could not stage receipt before confirmed save: $error');
     if(mounted)snack(context,waffraIsEnglish?'Could not attach the image. Please retry.':
      'تعذر إرفاق الصورة، حاول مجددًا.');
     disposeLater([title,value,notes,message]);return;
    }
   }
   bool attempted=false;
   bool explicitlyApprovedSmsDuplicate=false;
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
    Widget dateAction()=>OutlinedButton.icon(
      key:const Key('waffra-entry-date-action'),
      onPressed:WaffraHaptics.tap(()async {
       final d=await waffraPickDateWithToday(english:waffraIsEnglish,
        context:sheetContext,initialDate:date,
        firstDate:DateTime(2000),lastDate:DateTime.now());
       if(d!=null&&sheetContext.mounted)update(()=>date=d);
      }),
      icon:const Icon(Icons.calendar_month,size:19),
      label:WaffraText(dayText(date),maxLines:1));
     return Padding(padding:EdgeInsets.fromLTRB(18,10,18,MediaQuery.of(sheetContext).viewInsets.bottom+20),
     child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(initial!=null?'تعديل العملية':sms?'إضافة رسالة بنكية':
        scannedReceipt!=null?(waffraIsEnglish?'Review image transaction':'مراجعة عملية من صورة'):'إضافة عملية',
       style:Theme.of(sheetContext).textTheme.titleLarge),
      if(scannedImagePosition!=null&&scannedImageTotal!=null)
       Padding(padding:const EdgeInsets.only(top:6),child:WaffraText(
        waffraIsEnglish?
         'Transaction $scannedImagePosition of $scannedImageTotal in image':
         'العملية $scannedImagePosition من $scannedImageTotal في الصورة',
        style:const TextStyle(fontWeight:FontWeight.w600,color:emerald))),
      const SizedBox(height:12),
      if(scannedReceipt!=null)...[
       WaffraText(waffraIsEnglish?
        'OCR suggestions are unverified. Confirm the income/expense type, amount, source and date before saving. The image is attached only after confirmation.':
        'بيانات الصورة مقترحات غير مؤكدة. راجع الدخل أو المصروف والمبلغ والاسم والتاريخ قبل الحفظ. الصورة تُرفق بعد التأكيد فقط.',
        style:const TextStyle(color:emerald,fontSize:12)),
       const SizedBox(height:12),
      ],
      if(sms)...[
       TextField(controller:message,minLines:3,maxLines:6,
        onChanged:(v){parseNow(v);update((){});},
        decoration:InputDecoration(labelText:waffraIsEnglish?'Bank SMS *':'الرسالة البنكية *',
         hintText:waffraTr('أول ما تلصقها نحلّلها تلقائيًا'),
         errorText:attempted&&message.text.trim().isEmpty?waffraRequiredFieldMessage:null,
         border:OutlineInputBorder())),
       const SizedBox(height:8),
       if(analyzing)const LinearProgressIndicator(),
       if(hasParsed)WaffraText(
        BankParser.parse(message.text).requiresCurrencyReview
         ?(waffraIsEnglish?
          'Foreign currency: check the original amount and enter a verified SAR value manually. No automatic FX conversion.':
          'عملة أجنبية: راجع المبلغ وأدخل قيمته المؤكدة بالريال يدويًا. لا يوجد تحويل تلقائي.')
         :value.text.isEmpty?
          (waffraIsEnglish?'Amount unclear: enter it manually.':'المبلغ غير واضح؛ أدخله يدويًا.')
         :(waffraIsEnglish?'Smart analysis suggested fields. Review before saving.':
          'التحليل الذكي اقترح بيانات. راجعها قبل الحفظ.'),
        style:const TextStyle(color:emerald)),
       const SizedBox(height:12),
      ],
      SegmentedButton<bool>(
       segments:const [ButtonSegment(value:true,label:WaffraText('دخل')),
        ButtonSegment(value:false,label:WaffraText('مصروف'))],
       selected:{income},onSelectionChanged:WaffraHaptics.selection((v)=>update((){
        income=v.first;
        selectedParentId=null;
        category=sms?(forType(income).isNotEmpty?forType(income).first.name:'أخرى'):'';
        suggestion=null;
       }))),
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),minLines:1,maxLines:5,
       decoration:InputDecoration(labelText:waffraIsEnglish?'Transaction name *':'اسم العملية *',
        errorText:attempted&&!waffraTransactionTitleAllowed(title.text,
         oldTitle:initial?.title)
         ?(title.text.trim().isEmpty?waffraRequiredFieldMessage:
           (waffraIsEnglish?'Maximum 250 characters for a new name.':
            'اسم العملية الجديد لا يزيد عن 250 حرفًا.')):null,
        border:OutlineInputBorder())),
      const SizedBox(height:10),
      if(!sms)...[
       TextField(controller:notes,onChanged:(_)=>update((){}),minLines:1,maxLines:4,
        decoration:InputDecoration(labelText:waffraIsEnglish?'Notes (optional)':'ملاحظات (اختياري)',
         errorText:attempted&&!waffraTransactionNotesAllowed(notes.text,oldNotes:initial?.notes)
          ?(waffraIsEnglish?'Notes cannot exceed 2,000 characters.':
            'الملاحظات لا تتجاوز 2000 حرف.'):null,
         border:const OutlineInputBorder())),
       const SizedBox(height:12),
      ]else ...[
       WaffraText(waffraIsEnglish?
        'The original bank message is stored separately from your notes.':
        'نص الرسالة البنكية الأصلية يُحفظ منفصلًا عن ملاحظاتك.',
        style:const TextStyle(fontSize:12,color:emerald)),
       const SizedBox(height:12),
      ],
      TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(value.text):null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      if(sms)
       InkWell(onTap:WaffraHaptics.tap(()async{
        final picked=await chooseTransactionCategory(sheetContext,available,chosen??'');
        if(picked!=null&&sheetContext.mounted)update(()=>category=picked);
       }),child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Category *':'القسم *',
        errorText:attempted&&WaffraValidators.requiredCategory(
         chosen,available.map((c)=>c.name))!=null?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.search_rounded)),
        child:WaffraText(chosen??(waffraIsEnglish?'Choose a category':'اختر قسمًا'),maxLines:2)))
      else ...[
       InkWell(onTap:WaffraHaptics.tap(()async{
        final picked=await chooseTransactionCategory(sheetContext,mainCategories,
         selectedMain.isEmpty?'':selectedMain.first.name);
        if(picked==null||!sheetContext.mounted)return;
        final found=mainCategories.where((c)=>c.name==picked).toList();
        if(found.isEmpty)return;
        update((){
         if(selectedParentId!=found.first.id){selectedParentId=found.first.id;category='';}
        });
       }),child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Main category *':'القسم الرئيسي *',
        errorText:attempted&&selectedMain.isEmpty?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.arrow_drop_down_rounded)),
        child:WaffraText(selectedMain.isEmpty?
         (waffraIsEnglish?'Choose a main category':'اختر القسم الرئيسي'):
         selectedMain.first.displayName,maxLines:2))),
       const SizedBox(height:10),
       InkWell(onTap:WaffraHaptics.tap(selectedMain.isEmpty||subcategories.isEmpty?null:()async{
        final picked=await chooseTransactionCategory(sheetContext,subcategories,
         selectedSub.isEmpty?'':selectedSub.first.name,leafLabels:true);
        if(picked!=null&&sheetContext.mounted)update(()=>category=picked);
       }),child:InputDecorator(decoration:InputDecoration(
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
      if(sms&&suggestion!=null)TextButton.icon(onPressed:WaffraHaptics.tap(()async {
       final c=await categoryDialog(income:income,suggested:suggestion);
       if(c!=null&&mounted&&sheetContext.mounted){
        if(WaffraValidators.uniqueCategory(c.name,
         categories.where((x)=>x.income==c.income).map((x)=>x.name))=='duplicate'){
         snack(sheetContext,waffraIsEnglish?'Category already exists':'القسم موجود بالفعل');
         return;
        }
        setState(()=>categories.add(c));
        if(!await _persistModuleOrReload(
         WaffraFinanceRoute.categoryCreateEditDeleteRestore,
         operation:'bank-category-suggestion'))return;
        if(sheetContext.mounted)update((){category=c.name;suggestion=null;});
       }
      }),icon:const Icon(Icons.add),label:WaffraText('إضافة قسم $suggestion')),
      if(sms)OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async {
       final c=await categoryDialog(income:income);
       if(c!=null&&mounted&&sheetContext.mounted){
        if(WaffraValidators.uniqueCategory(c.name,
         categories.where((x)=>x.income==c.income).map((x)=>x.name))=='duplicate'){
         snack(sheetContext,waffraIsEnglish?'Category already exists':'القسم موجود بالفعل');
         return;
        }
        setState(()=>categories.add(c));
        if(!await _persistModuleOrReload(
         WaffraFinanceRoute.categoryCreateEditDeleteRestore,
         operation:'bank-new-category'))return;
        if(sheetContext.mounted)update(()=>category=c.name);
       }
      }),icon:const Icon(Icons.add),label:const WaffraText('قسم جديد'))
      else if(selectedMain.isNotEmpty)LayoutBuilder(builder:(ctx,box){
        final newCategory=OutlinedButton.icon(
         key:const Key('waffra-entry-new-subcategory'),
         onPressed:WaffraHaptics.tap(()async {
          final mainId=selectedMain.first.id;
          final c=await categoryDialog(income:income,parentId:mainId);
          if(c!=null&&mounted&&sheetContext.mounted){
           if(WaffraValidators.uniqueCategory(c.name,
            categories.where((x)=>x.income==c.income).map((x)=>x.name))=='duplicate'){
            snack(sheetContext,waffraIsEnglish?'Category already exists':'القسم موجود بالفعل');
            return;
           }
           setState(()=>categories.add(c));
           if(!await _persistModuleOrReload(
            WaffraFinanceRoute.categoryCreateEditDeleteRestore,
            operation:'manual-new-subcategory'))return;
           if(sheetContext.mounted)update(()=>category=c.name);
          }

         }),icon:const Icon(Icons.add,size:19),
         label:WaffraText(waffraIsEnglish?'New subcategory':'قسم فرعي جديد',maxLines:1));
        final stacked=box.maxWidth<360||
         MediaQuery.textScalerOf(ctx).scale(14)>20;
        return Padding(padding:const EdgeInsets.only(top:12,bottom:12),
         child:stacked
          ?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            newCategory,const SizedBox(height:12),dateAction()])
          :Row(children:[
            Expanded(child:newCategory),const SizedBox(width:12),
            Expanded(child:dateAction())]));
       }),
       if(sms||selectedMain.isEmpty)Padding(
        padding:const EdgeInsets.symmetric(vertical:12),
        child:Align(alignment:AlignmentDirectional.centerStart,child:dateAction())),
       const SizedBox(height:12),
      Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
        // The native camera permission is requested only when this action
        // launches the OS camera; never request it during login or startup.
        try{
         final file=await ImagePicker().pickImage(
          source:ImageSource.camera,imageQuality:80);
         if(file==null)return;
         final path=await saveReceipt(file);
         stagedReceiptCopies.add(path);
         if(sheetContext.mounted)update(()=>receiptPath=waffraEncodeReceipts(
          [...waffraReceiptPaths(receiptPath),path]));
        }catch(_){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Camera unavailable or permission denied. Review camera access in Settings.':
          'تعذر فتح الكاميرا أو تم رفض الإذن. راجع إذن الكاميرا من إعدادات الهاتف.');
        }
       }),icon:const Icon(Icons.camera_alt_outlined),label:const WaffraText('تصوير فاتورة'))),
       const SizedBox(width:8),
       Expanded(child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
        // Use OS limited-photo access only after the user taps Attach.
        try{
         final files=await ImagePicker().pickMultiImage(imageQuality:80);
         if(files.isEmpty)return;
         final paths=<String>[...waffraReceiptPaths(receiptPath)];
         for(final file in files){
          final copied=await saveReceipt(file);
          stagedReceiptCopies.add(copied);paths.add(copied);
         }
         if(sheetContext.mounted)update(()=>
          receiptPath=waffraEncodeReceipts(paths));
        }catch(_){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Could not open photos. Please check photo selection access.':
          'تعذر اختيار الصور. راجع صلاحية الوصول للصور المختارة.');
        }
       }),icon:const Icon(Icons.attach_file),label:const WaffraText('إرفاق صورة'))),
      ]),
      Padding(padding:const EdgeInsets.only(top:5),
       child:WaffraText(waffraIsEnglish?
        'Camera and photo access is requested only when you choose to use it.':
        'نطلب صلاحية الكاميرا أو اختيار الصور وقت استخدامها فقط.',
        style:const TextStyle(fontSize:11,color:emerald))),
      if(waffraReceiptPaths(receiptPath).isNotEmpty)...[
       for(final path in waffraReceiptPaths(receiptPath))
        ListTile(dense:true,
         title:WaffraText(WaffraReceiptFilename.displayName(path),maxLines:2),
         leading:const Icon(Icons.image,color:emerald),
         trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(
           key:Key('waffra-attachment-rename-'+waffraReceiptPaths(receiptPath).indexOf(path).toString()),
           tooltip:waffraIsEnglish?'Rename attachment':'تعديل اسم المرفق',
           icon:const Icon(Icons.drive_file_rename_outline,color:emerald),
           onPressed:WaffraHaptics.tap(()async{
            final name=await _promptReceiptLabel(sheetContext,path);
            if(name==null||!sheetContext.mounted)return;
            try{
             final directory=Directory(
              '${(await getApplicationDocumentsDirectory()).path}/receipts');
             final renamed=await WaffraReceiptFilename.stageCopyWithName(
              sourcePath:path,appReceiptsDirectory:directory.path,
              proposedLabel:name);
             stagedReceiptCopies.add(renamed);
             if(!sheetContext.mounted)return;
             update((){
              final paths=waffraReceiptPaths(receiptPath);
              final index=paths.indexOf(path);
              if(index>=0)paths[index]=renamed;
              receiptPath=waffraEncodeReceipts(paths);
             });
            }catch(_){
             if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
              'Could not rename attachment. The original image is unchanged.':
              'تعذر تغيير اسم المرفق. الصورة الأصلية لم تتغير.');
            }
           })),
          IconButton(
           tooltip:waffraIsEnglish?'Remove attachment':'إزالة المرفق',
           icon:const Icon(Icons.close),
           onPressed:WaffraHaptics.tap(()=>update((){
            receiptPath=waffraEncodeReceipts([...waffraReceiptPaths(receiptPath)]..remove(path));
           }))),
         ]),
         onTap:WaffraHaptics.tap(()=>showReceipt(receiptPath!,initialIndex:waffraReceiptPaths(receiptPath).indexOf(path)))),
      ],
      const SizedBox(height:12),
      FilledButton(onPressed:WaffraHaptics.tap(analyzing||submitTapped?null:()async {
       if(submitTapped)return;
       update(()=>attempted=true);
       final n=sms?amountOf(value.text):amountOfDisplay(value.text);
       if(!waffraTransactionTitleAllowed(title.text,oldTitle:initial?.title)||
        (!sms&&!waffraTransactionNotesAllowed(notes.text,oldNotes:initial?.notes))||
        waffraAmountFieldError(value.text)!=null||n==null)return;
       if(!sms&&!waffraCanAssignManualCategory(categories,
        income,selectedParentId,category))return;
       if(sms){
        if(WaffraValidators.requiredCategory(
         chosen,available.map((c)=>c.name))!=null)return;
        if(message.text.trim().isEmpty)return;
        // The display-country setting cannot convert a bank SMS into SAR.
        // The durable finance record must never inherit an unverified
        // foreign amount from the manual SMS review screen.
        if(WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Foreign or unknown currency: no transaction was saved as SAR. Verify the source amount and FX first.':
          'عملة الرسالة أجنبية أو غير مؤكدة؛ لم نحفظ العملية بالريال. يلزم التحقق من المبلغ وسعر الصرف أولًا.');
         return;
        }
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){
         final proceed=await showWaffraDialog<bool>(context:sheetContext,builder:(dialogContext)=>AlertDialog(
          title:const WaffraText('⚠️ الرسالة مكررة'),
          content:const WaffraText('هذي الرسالة البنكية أضفتها قبل كذا. ودّك تضيفها مرة ثانية؟'),
          actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,false)),child:const WaffraText('إلغاء')),
           FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,true)),child:const WaffraText('إضافة على أي حال'))]));
         if(proceed!=true||!sheetContext.mounted)return;
         explicitlyApprovedSmsDuplicate=true;
        }
        pendingHash=h;
       }
       submitTapped=true; // Synchronous gate: rapid taps cannot post twice.
       Navigator.pop(sheetContext,MoneyEntry(id:initial?.id??newId(),
        title:title.text.trim(),notes:sms?message.text:notes.text,
        category:sms?chosen!:category,amount:n,
        income:income,date:date,receiptPath:receiptPath,
        sourceType:initial?.sourceType??(sms?'sms':scannedReceipt!=null?'receipt':'manual'),
        merchantKey:initial?.merchantKey??(sms?(waffraMerchantKey(message.text)??''):'')));
      }),child:const WaffraText('تأكيد وحفظ العملية')),
     ])));
   }));
  debounce?.cancel();disposeLater([title,value,notes,message]);
  if(result==null||!mounted){
   for(final copy in stagedReceiptCopies){
    try{final file=File(copy);if(await file.exists())await file.delete();}catch(_){}
   }
   return;
  }
  // Compare OCR, manual and SMS entries across source types before commit.
  // This is an advisory warning: same-day equal purchases are legitimate.
  if(initial==null&&entries.any((e)=>
    WaffraCrossSourceDuplicateReview.mightBeSame(
      candidateTitle:result.title,candidateCategory:result.category,
      candidateMerchantKey:result.merchantKey,
      candidateAmount:result.amount,candidateIncome:result.income,
      candidateDate:result.date,existingTitle:e.title,
      existingCategory:e.category,existingMerchantKey:e.merchantKey,
      existingAmount:e.amount,existingIncome:e.income,
      existingDate:e.date))){
   final proceed=await showWaffraDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'⚠️ Possible duplicate':'⚠️ عملية مكررة'),
    content:WaffraText(waffraIsEnglish?
     'A similar ${result.income?'income':'expense'} was recorded on the same day for the same amount. Add it again?':
     'يبدو إنك أضفت نفس ${result.income?'الدخل':'المصروف'} من قبل. ودّك تضيفه مرة ثانية؟'),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
      child:WaffraText(waffraIsEnglish?'Add anyway':'إضافة على أي حال'))]));
   if(proceed!=true||!mounted){
    // The duplicate was refused *before* any finance write. Remove only
    // image copies staged in this sheet; never the original user image.
    for(final copy in stagedReceiptCopies){
     try{final file=File(copy);if(await file.exists())await file.delete();}catch(_){}
    }
    return;
   }
   // The writer still verifies the bank SMS hash under the source lock.
   // Confirmation here only permits the user's explicitly reviewed overlap.
   if(pendingHash!=null)explicitlyApprovedSmsDuplicate=true;
  }
  final previousSpent=sum(entries.where((e)=>!e.income&&e.id!=result.id&&
   e.category==result.category&&e.date.year==result.date.year&&e.date.month==result.date.month),false);
  if(pendingHash!=null&&initial==null){
   try{
   // A single reviewed bank SMS must commit both its transaction and
   // fingerprint atomically under the same Home/Widget source and journal.
   // The writer independently checks duplicates again after taking the lock.
   final applied=await _saveProgress.track(
    'commit-confirmed-bank-sms',()=>_financeAuthority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
    records:[Map<String,Object?>.from(result.toJson())],
    hashes:[pendingHash!],
    userConfirmed:true,
    allowDuplicateHashes:explicitlyApprovedSmsDuplicate,
   ));
   if(applied.saved!=1){
    if(mounted)snack(context,waffraIsEnglish?
     'This bank transaction was already saved. Review before retrying.':
     'العملية البنكية محفوظة بالفعل. راجعها قبل المحاولة مجددًا.');
    return;
   }
   final verified=(jsonDecode(applied.current.ledgerRaw??'[]') as List)
    .map((item)=>MoneyEntry.fromJson(Map<String,dynamic>.from(item as Map)))
    .toList();
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(verified);
    smsHashes..clear()..addAll(
     applied.current.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
    _lastFinanceAuthorityRead=applied.current;
    _lastLedgerSavedRaw=applied.current.ledgerRaw;
    _lastWidgetRevision=applied.current.widgetRevision;
   });
   unawaited(_refreshWidget());
   if(applied.originalSmsNotesOmittedOnLegacy&&mounted){
    snack(context,waffraIsEnglish?
     'Transaction saved; original bank SMS text was NOT stored.':
     'تم حفظ بيانات العملية دون نص الرسالة البنكية الأصلي.',isError:false);
   }
   }catch(e){
    // One rejected source-authorized bank commit must never leave the
    // user looking at a success screen or an unhandled Flutter exception.
    if(mounted)snack(context,waffraIsEnglish?
     'Could not confirm bank transaction save. Review before retrying.':
     'تعذر تأكيد حفظ المعاملة البنكية. راجعها قبل إعادة المحاولة.');
    return;
   }
  }else{
   // Optimistic in-memory edits must roll back if durable save is rejected.
   // A spinner is NOT proof of a completed financial write.
   final previousEntries=List<MoneyEntry>.of(entries);
   final previousLearned=Map<String,String>.of(learnedMerchantCategories);
   setState((){
    final i=entries.indexWhere((e)=>e.id==result.id);
    if(i>=0)entries[i]=result;else entries.insert(0,result);
    // Learn only explicit corrections made by the user, not assumptions
    // generated by bank message parsing.
    if(initial!=null&&initial.category!=result.category){
     final merchant=initial.merchantKey.isNotEmpty?
      initial.merchantKey:waffraMerchantKey(initial.title,income:initial.income);
     if(merchant!=null&&merchant.isNotEmpty){
      learnedMerchantCategories[merchant]=result.category;
     }
    }
   });
   try{
    // No success message or persisted balance is claimed before the
    // source-aware writer has acknowledged the commit.
    await persist(route:initial==null
     ?WaffraFinanceRoute.manualTransactionSave
     :WaffraFinanceRoute.transactionEdit);
   }catch(e){
    if(mounted){
     setState((){
      entries..clear()..addAll(previousEntries);
      learnedMerchantCategories..clear()..addAll(previousLearned);
     });
     snack(context,waffraIsEnglish?
      'Could not save the transaction. Your previous data is unchanged.':
      'تعذر حفظ المعاملة. بياناتك السابقة لم تتغير.');
    }
    return;
   }
   if(pendingHash!=null){
    // Existing transaction edits still need independent receipt/SMS review.
    try{await _persistSmsHashes({pendingHash!});}
    catch(e){
     if(mounted)snack(context,waffraIsEnglish?
      'Transaction saved, but the SMS fingerprint needs verification.':
      'تم حفظ المعاملة، لكن بصمة الرسالة تحتاج مراجعة.');
     return;
    }
   }
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
     if(!await _persistModuleOrReload(
      WaffraFinanceRoute.transactionEdit,
      operation:'transaction-edit-undo'))return;
     if(mounted)snackSuccess(context,waffraIsEnglish?
      'Transaction change reverted':'تم التراجع عن تعديل المعاملة');
    });
  }
 }
 Future<String?> chooseTransactionCategory(BuildContext ctx,List<BudgetCategory> options,String selected,{bool leafLabels=false})async{
  var query='';
  return showWaffraDialog<String>(context:ctx,builder:(dialogCtx)=>StatefulBuilder(builder:(dialogCtx,refresh){
   final filtered=options.where((item){
    final label=leafLabels?item.displayName:item.name;
    return waffraSearchAny([label,waffraTr(label),waffraTr(item.name)],query);
   }).toList();
   return AlertDialog(title:WaffraText(waffraIsEnglish?'Search categories':'بحث في الأقسام'),
    content:SizedBox(width:360,height:min(420.0,MediaQuery.sizeOf(dialogCtx).height*.55),child:Column(children:[
     TextField(autofocus:true,onChanged:(v)=>refresh(()=>query=v),
      decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:waffraIsEnglish?'Search…':'اكتب اسم القسم',border:const OutlineInputBorder())),
     const SizedBox(height:9),
     Expanded(child:ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){
      final item=filtered[i];return ListTile(selected:selected==item.name,
       leading:Icon(categoryIcon(item.icon),color:Color(item.color)),
       title:WaffraText(waffraTr(leafLabels?item.displayName:item.name),maxLines:3),onTap:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,item.name)));
     })),
    ])),actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
  }));
 }
 Future<String?> _promptReceiptLabel(BuildContext context,String path)async {
  final name=TextEditingController(text:WaffraReceiptFilename.displayName(path));
  String? error;
  try{
   return await showWaffraDialog<String>(context:context,
    builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>
     AlertDialog(
      title:WaffraText(waffraIsEnglish?'Rename attachment':'تعديل اسم المرفق'),
      content:TextField(
       key:const Key('waffra-attachment-name-input'),
       controller:name,maxLength:WaffraReceiptFilename.maxLabelCharacters,
       autofocus:true,
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Attachment name *':'اسم المرفق *',
        errorText:error,border:const OutlineInputBorder()),
       onChanged:(_)=>setDialogState(()=>error=null)),
      actions:[
       TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext)),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
       FilledButton(onPressed:WaffraHaptics.tap((){
        final validation=WaffraReceiptFilename.validateLabel(name.text);
        if(validation!=null){
         setDialogState(()=>error=waffraIsEnglish?
          'Enter a valid name (1-80 characters, no slashes).':
          'اكتب اسمًا من 1 إلى 80 حرفًا بدون شرطات مسار.');
         return;
        }
        final normalized=WaffraReceiptFilename.normalizedLabel(name.text)!;
        Navigator.pop(dialogContext,
         normalized==WaffraReceiptFilename.displayName(path)?null:normalized);
       }),child:WaffraText(waffraIsEnglish?'Save name':'حفظ الاسم')),
      ],
     )));
  }finally{name.dispose();}
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
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
         icon:const Icon(Icons.close_rounded,color:Colors.white))),
       ])),
       Flexible(child:Container(color:Colors.black,
        child:PageView.builder(controller:controller,itemCount:available.length,
         onPageChanged:(index)=>update(()=>current=index),
         itemBuilder:(ctx,index)=>InteractiveViewer(
          minScale:.8,maxScale:5,
          child:Center(child:Image.file(File(available[index]),fit:BoxFit.contain)))))),
       Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        child:WaffraText(WaffraReceiptFilename.displayName(available[current]),
         maxLines:2,textAlign:TextAlign.center,
         style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w700))),
       SizedBox(height:58,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(
         tooltip:waffraIsEnglish?'Previous image':'الصورة السابقة',
         onPressed:WaffraHaptics.tap(current>0?()=>controller.previousPage(
          duration:waffraMotion(220),curve:Curves.easeInOut):null),
         icon:Icon(Icons.chevron_left_rounded,color:current>0?Colors.white:Colors.white38)),
        Text(count,textDirection:TextDirection.ltr,
         style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.bold)),
        IconButton(
         tooltip:waffraIsEnglish?'Next image':'الصورة التالية',
         onPressed:WaffraHaptics.tap(current<available.length-1?()=>controller.nextPage(
          duration:const Duration(milliseconds:220),curve:Curves.easeInOut):null),
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
    'صرف «${category.name}» ${(spent/category.budget*100).round()}٪ (حد التنبيه $crossed٪). ${cash(spent)} من ${cash(category.budget)}.'),
   actions:[FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
    child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
 }
 /// Draw the same category-colored donut shown on Smart Analysis.
 String expensePieSvg(Map<String,double> totals){
  final positive=totals.entries.where((e)=>e.value>0).toList();
  final total=positive.fold<double>(0,(n,e)=>n+e.value);
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="200" height="200" viewBox="0 0 200 200">');
  if(total<=0)return '$out</svg>';
  var angle=-pi/2;
  for(final category in positive){
   final sweep=2*pi*category.value/total;
   final points=<String>['100,100'];
   final steps=max(12,(sweep*70).ceil());
   for(var j=0;j<=steps;j++){
    final theta=angle+sweep*j/steps;
    points.add('${(100+87*cos(theta)).toStringAsFixed(2)},'
     '${(100+87*sin(theta)).toStringAsFixed(2)}');
   }
   final hex=(categoryFor(category.key,false).color&0xFFFFFF)
    .toRadixString(16).padLeft(6,'0');
   out.write('<polygon points="${points.join(' ')}" '
    'fill="#$hex" stroke="#FFFFFF" stroke-width=".8"/>');
   angle+=sweep;
  }
  out.write('<circle cx="100" cy="100" r="45" fill="#FFFFFF"/>');
  out.write('</svg>');
  return out.toString();
 }
 /// Same four weekly expense points and green curve as Flutter analysis.
 String weeklySpendSvg(List<double> amounts){
  final maximum=amounts.fold<double>(1,(a,b)=>max(a,b));
  final points=List.generate(amounts.length,(i)=>
   (32.0+i*168,117.0-94*amounts[i]/maximum));
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="600" height="150" viewBox="0 0 600 150">');
  for(var i=0;i<4;i++){
   final y=23+i*31;
   out.write('<line x1="30" x2="550" y1="$y" y2="$y" '
    'stroke="#E5EEEA" stroke-width="1"/>');
  }
  final path=StringBuffer();
  if(points.isNotEmpty){
   path.write('M ${points[0].$1.toStringAsFixed(1)} ${points[0].$2.toStringAsFixed(1)}');
   for(var i=1;i<points.length;i++){
    final prev=points[i-1],next=points[i],cx=(prev.$1+next.$1)/2;
    path.write(' C ${cx.toStringAsFixed(1)} ${prev.$2.toStringAsFixed(1)}'
     ' ${cx.toStringAsFixed(1)} ${next.$2.toStringAsFixed(1)}'
     ' ${next.$1.toStringAsFixed(1)} ${next.$2.toStringAsFixed(1)}');
   }
  }
  out.write('<path d="$path" fill="none" stroke="#0C7957" stroke-width="4"/>');
  for(final point in points){
   out.write('<circle cx="${point.$1.toStringAsFixed(1)}" '
    'cy="${point.$2.toStringAsFixed(1)}" r="5" '
    'fill="#0C7957" stroke="#FFFFFF" stroke-width="2"/>');
  }
  out.write('</svg>');
  return out.toString();
 }
 /// Five weekly or twelve monthly grouped bars match the Analytics tab.
 String pairedBarChartSvg(List<(double,double)> values){
  final maximum=values.fold<double>(1,(v,p)=>max(v,max(p.$1,p.$2)));
  final count=values.length,width=max(520,count*56);
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="$width" height="160" viewBox="0 0 $width 160">');
  for(var i=0;i<4;i++){
   final y=20+i*36;
   out.write('<line x1="20" x2="${width-12}" y1="$y" y2="$y" '
    'stroke="#E4EBE7" stroke-width="1"/>');
  }
  for(var i=0;i<count;i++){
   final center=33+(width-60)*(i+.5)/count;
   for(var j=0;j<2;j++){
    final amount=j==0?values[i].$1:values[i].$2;
    final height=(amount/maximum*117).clamp(0.0,117.0);
    final x=center+(j==0?-13:2);
    out.write('<rect x="${x.toStringAsFixed(1)}" '
     'y="${(138-height).toStringAsFixed(1)}" '
     'width="11" height="${height.toStringAsFixed(1)}" rx="3" '
     'fill="${j==0?'#075C40':'#FF5722'}"/>');
   }
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
   // Capture a single VERIFIED conversion for the entire PDF.
   // Never relabel stored SAR as EGP/USD when no exchange rate exists.
   final pdfQuote=WaffraDisplayCurrency.active.value;
   if(!pdfQuote.verified){
    throw StateError('Verified display FX rate required for PDF export.');
   }
   final pdfCurrency=pdfQuote.code;
   final pdfCurrencyAr=waffraCountry(pdfCurrency).symbolAr;
   // Embed the exact approved PNG, rather than using a PDF font glyph
   // that can become an unsupported square in generated reports.
   final pdfRiyalIcon=pw.MemoryImage(
    (await rootBundle.load(waffraRiyalAsset)).buffer.asUint8List());
   pw.Widget pdfCurrencyMark({double size=9,PdfColor color=PdfColors.teal900}) {
    if(!english&&pdfCurrency=='SAR')return pw.Image(pdfRiyalIcon,
     width:size,height:size,fit:pw.BoxFit.contain);
    return pw.Text(english?pdfCurrency:pdfCurrencyAr,
     style:pw.TextStyle(font:bold,fontSize:size*.8,color:color));
   }
   pw.Widget pdfMoney(String text,{double size=9,
      PdfColor color=PdfColors.teal900})=>pw.Row(
    mainAxisSize:pw.MainAxisSize.min,
    mainAxisAlignment:pw.MainAxisAlignment.center,children:[
     pw.Text(text,style:pw.TextStyle(font:bold,fontSize:size,color:color)),
     pw.SizedBox(width:3),pdfCurrencyMark(size:size,color:color),
    ]);
   pw.Widget pdfMoneyHeader(String header,{double size=9,
      PdfColor color=PdfColors.white}){
    if(english||pdfCurrency!='SAR')return pw.Text(header,
     textAlign:pw.TextAlign.center,
     style:pw.TextStyle(font:bold,fontSize:size,color:color));
    final label=header.replaceAll('($pdfCurrencyAr)','').trim();
    if(label==header)return pw.Text(header,
     textAlign:pw.TextAlign.center,
     style:pw.TextStyle(font:bold,fontSize:size,color:color));
    return pw.Row(mainAxisSize:pw.MainAxisSize.min,
     mainAxisAlignment:pw.MainAxisAlignment.center,children:[
      pw.Text(label,style:pw.TextStyle(font:bold,fontSize:size,color:color)),
      pw.SizedBox(width:3),pw.Container(
       padding:const pw.EdgeInsets.all(1),color:PdfColors.white,
       child:pdfCurrencyMark(size:size)),
     ]);
   }
   double pdfAmount(num sar){
    final result=pdfQuote.fromSar(sar);
    if(result==null||!result.isFinite){
     throw StateError('Unverified PDF currency conversion refused.');
    }
    return result;
   }
   final exportedAt=DateTime.now();
   final oldest=items.map((e)=>e.date).reduce((a,b)=>a.isBefore(b)?a:b);
   final newest=items.map((e)=>e.date).reduce((a,b)=>a.isAfter(b)?a:b);
   // Keep stored descriptions unchanged; sanitize only the exported PDF copy.
   String pdfClean(String input)=>sanitizeWaffraPdfText(input);
      String fmt(num number){
    final n=pdfAmount(number);
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
     pw.SizedBox(height:5),pdfMoney(fmt(value),size:15),
    ])));
   // Explicit script direction prevents mixed Arabic/Latin SMS text from
   // overlapping or reversing adjacent numbers in the PDF viewer.
   pw.Widget pdfCell(String raw,{bool rtl=false,bool center=false,
      bool monetary=false})=>
    pw.Padding(padding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:7),
     child:monetary?pdfMoney(pdfClean(raw),size:9,color:PdfColors.black):
     pw.Text(pdfClean(raw),
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
       columnWidths:english?
        {0:const pw.FixedColumnWidth(54),1:const pw.FixedColumnWidth(81),
         2:const pw.FixedColumnWidth(61),3:const pw.FixedColumnWidth(90),
         4:const pw.FlexColumnWidth(3),5:const pw.FixedColumnWidth(83)}:
        {0:const pw.FixedColumnWidth(83),1:const pw.FlexColumnWidth(3),
         2:const pw.FixedColumnWidth(90),3:const pw.FixedColumnWidth(61),
         4:const pw.FixedColumnWidth(81),5:const pw.FixedColumnWidth(54)},
       children:[
        pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
         children:(english?['No.','Date','Type','Category','Description','Amount ($pdfCurrency)']:
          ['المبلغ ($pdfCurrencyAr)','الوصف','القسم','النوع','التاريخ','رقم المعاملة'])
          .map((h)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
           child:pdfMoneyHeader(h,size:10))).toList()),
        ...ordered.asMap().entries.map((row){
         final e=row.value,art=descriptions[row.key];
         final orderedCells=<pw.Widget>[
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
          pdfCell('${e.income?'+':'-'}${fmt(e.amount)}',center:true,monetary:true),
         ];
         return pw.TableRow(
          decoration:pw.BoxDecoration(color:PdfColor.fromInt(e.income?
           waffraIncomeBackground.toARGB32():waffraExpenseBackground.toARGB32())),
          children:english?orderedCells:orderedCells.reversed.toList(),
         );
        }),
       ],
      ),
     ]));
   }else{
    // "Financial Analytics" and "Smart Analysis" now render the very
    // same chart datasets shown by their respective Flutter screens.
    final smart=title.contains('آخر 90 يوم')||title.contains('Last 90 days');
    final yearly=title.contains('سنوي');
    final smartData=smart?waffraSmartChartData(items,exportedAt):null;
    final buckets=smart?smartData!.periods:List<(double,double)>.generate(
     yearly?12:5,(i){
      final slice=items.where((e)=>yearly?
       e.date.month==i+1:((e.date.day-1)~/7)==i);
      return (sum(slice,true),sum(slice,false));
     });
    final maximum=buckets.fold<double>(1,(n,p)=>max(n,max(p.$1,p.$2)));
    final top=(categoryTotals.entries.toList()
     ..sort((a,b)=>b.value.compareTo(a.value))).take(5).toList();
    final chartSlices=Map<String,double>.fromEntries(top);
    pw.Widget legend()=>pw.Row(mainAxisAlignment:pw.MainAxisAlignment.center,
     children:[
      pw.Container(width:10,height:10,color:PdfColors.teal800),
      pw.SizedBox(width:5),
      pw.Text(english?'Income':'دخل',
       style:pw.TextStyle(font:font,fontSize:10)),
      pw.SizedBox(width:18),
      pw.Container(width:10,height:10,color:PdfColors.deepOrange),
      pw.SizedBox(width:5),
      pw.Text(english?'Expenses':'مصروفات',
       style:pw.TextStyle(font:font,fontSize:10)),
     ]);
    pw.Widget progressBar(double value,PdfColor color)=>pw.Expanded(
     child:pw.Row(children:[
      pw.Expanded(flex:max(1,(value/maximum*100).round()),
       child:pw.Container(height:12,color:color)),
      pw.Expanded(flex:max(1,100-(value/maximum*100).round()),
       child:pw.SizedBox(height:12)),
     ]));
    pw.Widget panel(String ar,String en,List<pw.Widget> widgets)=>pw.Container(
     margin:const pw.EdgeInsets.only(bottom:10),
     padding:const pw.EdgeInsets.all(12),
     decoration:pw.BoxDecoration(
      border:pw.Border.all(color:PdfColors.grey400,width:.6),
      borderRadius:pw.BorderRadius.circular(8)),
     child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,
      children:[heading(ar,en),...widgets]));
    // Source-value tables are populated from the same buckets as the charts.
    pw.Widget miniTable(List<String> labels,List<List<String>> rows){
     bool isMoneyColumn(String label)=>[
      'Income','Expenses','Amount','الدخل','المصروفات','المبلغ',
     ].any(label.contains);
     pw.Widget cell(String v,{bool header=false,bool monetary=false})=>pw.Padding(
      padding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:4),
      child:header?pdfMoneyHeader(v,size:8):
       monetary?pdfMoney(pdfClean(v),size:8):
       pw.Text(pdfClean(v),
        textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
        textAlign:pw.TextAlign.center,
        style:pw.TextStyle(font:font,fontSize:8,
         color:PdfColors.teal900)));
     return pw.Table(border:pw.TableBorder.all(color:PdfColors.grey300,width:.4),
      children:[
       pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
        children:(english?labels.asMap().entries:
           labels.asMap().entries.toList().reversed)
         .map((e)=>cell(e.value,header:true,
          monetary:isMoneyColumn(e.value))).toList()),
       ...rows.map((row)=>pw.TableRow(
        children:(english?row.asMap().entries:
           row.asMap().entries.toList().reversed).map((e)=>cell(e.value,
         monetary:isMoneyColumn(labels[e.key]))).toList())),
      ]);
    }
    pw.Widget dataTable(List<String> labels,List<List<String>> rows)=>
     rows.length<=6?miniTable(labels,rows):
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
       pw.Expanded(child:miniTable(labels,rows.take(6).toList())),
       pw.SizedBox(width:8),
       pw.Expanded(child:miniTable(labels,rows.skip(6).toList())),
      ]);
    final valueHeaders=english?
     ['Period','Income ($pdfCurrency)','Expenses ($pdfCurrency)']:
     ['الفترة','الدخل ($pdfCurrencyAr)','المصروفات ($pdfCurrencyAr)'];
    final periodValues=List<List<String>>.generate(buckets.length,(i)=>[
     (english?(yearly?'Month ':'Period '):(yearly?'شهر ':'فترة '))+(i+1).toString(),
     fmt(buckets[i].$1),fmt(buckets[i].$2),
    ]);
    final parts=<pw.Widget>[
     heading('تقرير الرسومات والتحليلات المالية','Financial Charts Report'),
     if(smart)...[
      panel('اتجاه الدخل والمصروفات - آخر 90 يوم',
       'Income vs Expenses - Last 90 Days',[
       ...List.generate(3,(i)=>pw.Padding(
        padding:const pw.EdgeInsets.symmetric(vertical:5),
        child:pw.Row(children:[
         pw.SizedBox(width:72,child:pw.Text(
          english?'Period ${i+1}':'فترة ${i+1}',
          style:pw.TextStyle(font:font,fontSize:10))),
         pw.Expanded(child:pw.Column(children:[
          pw.Row(children:[
           pw.SizedBox(width:40,child:pw.Text(english?'Income':'دخل',
            style:pw.TextStyle(font:font,fontSize:8))),
           progressBar(buckets[i].$1,PdfColors.teal800),
           pw.SizedBox(width:61,child:pdfMoney(fmt(buckets[i].$1),size:9))]),
          pw.SizedBox(height:4),
          pw.Row(children:[
           pw.SizedBox(width:40,child:pw.Text(english?'Expense':'مصروف',
            style:pw.TextStyle(font:font,fontSize:8))),
           progressBar(buckets[i].$2,PdfColors.deepOrange),
           pw.SizedBox(width:61,child:pdfMoney(fmt(buckets[i].$2),size:9))]),
         ])),
        ]))),
       pw.SizedBox(height:5),legend(),
       pw.SizedBox(height:8),dataTable(valueHeaders,periodValues),
      ]),
      panel('اتجاه المصروفات الأسبوعية','Weekly Spending Trend',[
       pw.Center(child:pw.SvgImage(
        svg:weeklySpendSvg(smartData!.weeklySpend.map(pdfAmount).toList()),width:620,height:130)),
       pw.Center(child:pw.Text(english?
        'Four weeks: oldest to newest':'أربعة أسابيع من الأقدم إلى الأحدث',
        style:pw.TextStyle(font:font,fontSize:10))),
       pw.SizedBox(height:8),
       dataTable(english?['Week','Expenses ($pdfCurrency)']:
        ['الأسبوع','المصروفات ($pdfCurrencyAr)'],
        List<List<String>>.generate(smartData.weeklySpend.length,(i)=>[
         (english?'Week ':'الأسبوع ')+(i+1).toString(),
         fmt(smartData.weeklySpend[i]),
        ])),
      ]),
     ]else...[
      panel(yearly?'الدخل والمصروفات حسب الشهر':'الدخل والمصروفات حسب الأسبوع',
       yearly?'Income vs Expenses by Month':'Income vs Expenses by Week',[
       pw.Center(child:pw.SvgImage(
        svg:pairedBarChartSvg(buckets.map((p)=>(pdfAmount(p.$1),pdfAmount(p.$2))).toList()),width:680,height:155)),
       pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceEvenly,
        children:List.generate(buckets.length,(i)=>pw.Expanded(
         child:pw.Text(
          english?(yearly?'M${i+1}':'W${i+1}'):
           (yearly?'ش${i+1}':'أ${i+1}'),
          textAlign:pw.TextAlign.center,
          style:pw.TextStyle(font:font,fontSize:9))))),
       pw.SizedBox(height:8),legend(),
       pw.SizedBox(height:8),dataTable(valueHeaders,periodValues),
      ]),
     ],
     if(top.isNotEmpty)panel(
      'توزيع المصروفات حسب الأقسام','Expenses by Category',[
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.center,children:[
       pw.SizedBox(width:190,height:160,
        child:pw.SvgImage(svg:expensePieSvg(chartSlices),width:160,height:160)),
       pw.SizedBox(width:20),
       pw.Expanded(child:pw.Column(
        crossAxisAlignment:pw.CrossAxisAlignment.stretch,
        children:top.map((entry){
         final color=PdfColor.fromInt(categoryFor(entry.key,false).color);
         return pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),
          child:pw.Row(children:[
           pw.Container(width:10,height:10,color:color),
           pw.SizedBox(width:6),
           pw.Expanded(child:pw.Text(pdfClean(waffraTr(entry.key)),
            maxLines:2,style:pw.TextStyle(font:font,fontSize:9))),
           pw.SizedBox(width:7),
           pw.Text('${(entry.value/totalExpenses*100).toStringAsFixed(1)}%',
            style:pw.TextStyle(font:bold,fontSize:9)),
          ]));
        }).toList())),
      ]),
       pw.SizedBox(height:8),
       dataTable(english?['Category','Amount ($pdfCurrency)','Share']:
        ['القسم','المبلغ ($pdfCurrencyAr)','النسبة'],
        top.map((e)=><String>[
         waffraTr(e.key),fmt(e.value),
         (e.value/totalExpenses*100).toStringAsFixed(1)+'%',
        ]).toList()),
     ]),
    ];
    // MultiPage split the chart header and artwork into separate pages,
    // displaying a framed but apparently empty chart on the previous page.
    // A chart, its caption and its populated source table are inseparable.
    final chartPanels=parts.skip(1).toList(growable:false);
    for(var i=0;i<chartPanels.length;i++){
     final index=i+1;
     doc.addPage(pw.Page(pageTheme:pageTheme,
      build:(ctx)=>pw.Column(
       crossAxisAlignment:pw.CrossAxisAlignment.stretch,
       children:[
        heading('تقرير الرسومات والتحليلات المالية','Financial Charts Report'),
        chartPanels[i],
        pw.Spacer(),
        pw.Align(alignment:pw.Alignment.centerRight,
         child:pw.Text(index.toString()+' / '+chartPanels.length.toString(),
          style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.teal900))),
       ],
      )));
    }
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
      onPressed:WaffraHaptics.tap((){
       Navigator.of(dialogContext).pop();
       Navigator.of(context).push(MaterialPageRoute(builder:(_)=>
        WaffraPdfReader(bytes:bytes,fileName:fileName,english:waffraIsEnglish)));
      }),
      icon:const Icon(Icons.visibility_outlined),
      label:WaffraText(waffraIsEnglish?'Open report':'فتح التقرير'))),
     Align(alignment:AlignmentDirectional.centerStart,child:OutlinedButton.icon(
      onPressed:WaffraHaptics.tap(()async{
       Navigator.of(dialogContext).pop();
       await Printing.sharePdf(bytes:bytes,filename:fileName);
      }),
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
 /// Only the independently selected SQLCipher source may use the encrypted
 /// 30-day trash. A successful delete/undo MUST be reread from the verified
 /// authority before any balance or transaction tile changes on screen.
 void _publishVerifiedTransactionLedger(WaffraFinanceAuthorityRead committed){
  if(committed.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
   throw StateError('Encrypted transaction UI received a legacy source.');
  }
  committed.finance.requireIntegrity();
  final loaded=WaffraVerifiedTransactionUiGuard.decodeLedger(committed.ledgerRaw)
   .map((json)=>MoneyEntry.fromJson(json)).toList(growable:false);
  final hashes=committed.finance.getStringList('waffra_sms_hashes_v1')??const <String>[];
  if(!mounted)return;
  setState((){
   entries..clear()..addAll(loaded);
   smsHashes..clear()..addAll(hashes);
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  });
  unawaited(_refreshWidget());
 }

 Future<void> _deleteVerifiedEntry(MoneyEntry entry)async {
  try {
   await _financialWriteQueue.drain();
   final baseline=await _financeAuthority.load(
    route:WaffraFinanceRoute.transactionDeleteAndUndo);
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
      baseline.encryptedWitness==null){
    throw StateError('Verified encrypted transaction source is missing.');
   }
   // Reject a stale tile, including an edited receipt reference or amount.
   WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
    ledgerRaw:baseline.ledgerRaw,selected:entry.toJson());
   // A changed receipt image does not increment the finance generation.
   // The screen must capture every actual BLOB digest BEFORE asking consent.
   final screen=await _financeAuthority.loadVerifiedReceiptScreen(
    route:WaffraFinanceRoute.receiptView,entryId:entry.id);
   if(screen.entryId!=entry.id||
      screen.generation!=baseline.encryptedWitness!.generation||
      screen.isInRecycleBin){
    throw StateError('Receipt and finance screen witnesses disagree.');
   }
   if(!mounted)return;
   final approved=await confirmDeletion(
    waffraIsEnglish?'Move transaction to recently deleted':
     'نقل المعاملة إلى المحذوفات',
    waffraIsEnglish?
     'Move «${entry.title}» and its attached invoices to encrypted Recently Deleted for 30 days?':
     'هل تريد نقل المعاملة «${entry.title}» وفواتيرها المشفرة إلى المحذوفات لمدة 30 يومًا؟');
   if(approved!=true||!mounted)return;
   await _financialWriteQueue.submit(<String,Object>{'id':entry.id},(_)async{
    final committed=await _financeAuthority.deleteVerifiedTransactionToRecycle(
     baseline:baseline,entryId:entry.id,
     expectedImageHashes:screen.imageSha256,
     userConfirmed:true,now:DateTime.now().toUtc());
    _publishVerifiedTransactionLedger(committed);
   });
   if(!mounted)return;
   snack(context,waffraIsEnglish?
    'Transaction saved in encrypted Recently Deleted for 30 days.':
    'تم نقل المعاملة إلى المحذوفات المشفرة لمدة 30 يومًا.',
    isError:false,duration:const Duration(seconds:6),
    actionLabel:waffraIsEnglish?'Undo':'تراجع',
    onAction:(){if(mounted)unawaited(_undoVerifiedDeletedEntry(entry.id));});
  }catch(error){
   debugPrint('Verified encrypted transaction delete refused: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Deletion could not be verified. Your saved financial data was not reset. Reload before retrying.':
     'تعذر التحقق من الحذف. لم يتم تصفير بياناتك المالية. أعد تحميل المعاملات قبل المحاولة.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _undoVerifiedDeletedEntry(String entryId)async {
  try {
   await _financialWriteQueue.submit(<String,Object>{'id':entryId},(_)async{
    // Reopen the CURRENT source instead of restoring over a stale Home or
    // Widget snapshot. The SQL recycle enforces its 30-day clock and IDs.
    final baseline=await _financeAuthority.load(
     route:WaffraFinanceRoute.transactionDeleteAndUndo);
    if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
     throw StateError('Encrypted undo source is not available.');
    }
    final committed=await _financeAuthority.restoreVerifiedDeletedTransaction(
     baseline:baseline,entryId:entryId,now:DateTime.now().toUtc());
    _publishVerifiedTransactionLedger(committed);
   });
   if(mounted)snackSuccess(context,waffraIsEnglish?
    'Transaction and invoices restored':'تم استرجاع المعاملة وفواتيرها');
  }catch(error){
   debugPrint('Encrypted transaction undo blocked safely: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Could not restore safely. Reload Recently Deleted and try again.':
     'تعذر الاسترجاع الآمن. أعد فتح المحذوفات وحاول مجددًا.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _showVerifiedDeletedTransactions()async {
  if(_lastFinanceAuthorityRead?.source!=
     WaffraRuntimeFinanceBackend.verifiedEncrypted)return;
  try {
   final deleted=await _financeAuthority.listVerifiedDeletedTransactions();
   if(!mounted)return;
   if(deleted.isEmpty){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Recently deleted transactions':
      'المعاملات المحذوفة'),
     content:WaffraText(waffraIsEnglish?
      'There are no encrypted transactions to restore.':
      'لا توجد معاملات مشفرة قابلة للاسترجاع.'),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
    return;
   }
   final selection=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Recently deleted (30 days)':
      'المعاملات المحذوفة (30 يومًا)'),
     content:SizedBox(width:360,
      height:min(360.0,deleted.length*82.0+16.0),
      child:ListView.builder(itemCount:deleted.length,
       itemBuilder:(ctx,index){
        final item=deleted.entries.elementAt(index);
        final expires=DateTime.fromMillisecondsSinceEpoch(
         item.value,isUtc:true).toLocal();
        return ListTile(
         leading:const Icon(Icons.restore,color:emerald),
         title:WaffraText(item.key,maxLines:1),
         subtitle:WaffraText(waffraIsEnglish?
          'Recover until ${dayText(expires)}':
          'الاسترجاع متاح حتى ${dayText(expires)}',maxLines:2),
         onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,item.key)));
       })),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))]));
   if(selection!=null&&mounted)await _undoVerifiedDeletedEntry(selection);
  }catch(error){
   debugPrint('Encrypted transaction trash cannot be verified: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Recently Deleted is unavailable until encrypted source verification succeeds.':
    'المحذوفات غير متاحة حتى ينجح التحقق من المصدر المشفر.');
  }
 }

 Future<void> deleteEntry(MoneyEntry e)async {
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _deleteVerifiedEntry(e);
   return;
  }
  final yes=await confirmDeletion(waffraIsEnglish?'Delete transaction':'حذف العملية',
   waffraIsEnglish?'Delete «'+e.title+'»? You can undo for 6 seconds after deletion.':'هل تريد حذف المعاملة «'+e.title+'»؟ يمكنك التراجع خلال 6 ثوانٍ بعد الحذف.');
  if(yes!=true||!mounted)return;
  // A tentative removal is never success until the source acknowledges it.
  setState(()=>entries.removeWhere((x)=>x.id==e.id));
  if(!await _persistModuleOrReload(
   WaffraFinanceRoute.transactionDeleteAndUndo,
   operation:'transaction-delete'))return;
  if(!mounted)return;
  snack(context,waffraIsEnglish?'Transaction deleted':'تم حذف العملية',
   isError:false,duration:const Duration(seconds:5),
   actionLabel:waffraIsEnglish?'Undo':'تراجع',
   onAction:()async{
    if(!mounted||entries.any((x)=>x.id==e.id))return;
    setState(()=>entries.insert(0,e));
    if(!await _persistModuleOrReload(
     WaffraFinanceRoute.transactionDeleteAndUndo,
     operation:'transaction-undo'))return;
    if(mounted)snackSuccess(context,waffraIsEnglish?
     'Transaction restored':'تم استرجاع المعاملة');
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
     Align(alignment:AlignmentDirectional.centerStart,child:OutlinedButton.icon(
      onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'receipt')),
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
    onTap:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,value)),
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
  // Only after confirming this ID is in the authoritative SMS ledger may
  // a full original message be loaded from its separate SQLCipher note vault.
  // The decrypted text remains in this dialog's memory, never preferences.
  String? originalBankSms;
  // Fetch on EVERY SMS detail open, including after user notes are edited.
  // The vault verifies the saved SMS ID and authorization independently.
  if(entry.sourceType=='sms'){
   try{
    originalBankSms=await _financeAuthority.readProtectedOriginalSms(entry.id);
   }catch(_){
    if(mounted)snack(context,waffraIsEnglish?
     'Encrypted bank message cannot be opened. Your transaction is unchanged.':
     'تعذر فتح الرسالة البنكية المشفّرة. بيانات المعاملة لم تتغير.');
    return;
   }
  }
  if(!mounted)return;
  await showWaffraDialog<void>(
   context:context,
   builder:(ctx)=>WaffraTransactionDetailsDialog(
    entry:entry,
    protectedOriginalSms:originalBankSms,
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
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:const EdgeInsets.only(top:0),child:ListTile(
   textColor:waffraInk,iconColor:forest,
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
    child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:WaffraText(e.title,style:const TextStyle(color:waffraInk,fontWeight:FontWeight.w600)),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(color:waffraInk)),

   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    Column(mainAxisSize:MainAxisSize.min,children:[
     Text('${e.income?'+':'-'}${cash(e.amount)}',style:TextStyle(fontFamily:'Tajawal',fontSize:18,fontWeight:FontWeight.w800,color:e.income?const Color(0xFF075C40):waffraInk)),
     WaffraText(WaffraDisplayCurrency.label(waffraIsEnglish),style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:e.income?const Color(0xFF075C40):waffraInk)),
    ]),
    IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
     onPressed:WaffraHaptics.tap(()=>transactionActions(e)),icon:const Icon(Icons.more_vert,color:forest)),
   ]))),
   if(attachmentCount>0)PositionedDirectional(top:0,start:0,child:Semantics(
    label:waffraIsEnglish?'$attachmentCount attachments':'عدد المرفقات $attachmentCount',
    button:true,child:InkWell(onTap:WaffraHaptics.tap(()=>showReceipt(e.receiptPath!)),
     child:WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)))),
   ]));
 }
 String get greeting=>WaffraSaudiGreetings.compose(
  name:widget.profile.name,gender:widget.profile.gender,
  english:waffraIsEnglish,greetingIndex:widget.greetingIndex,
  countryIso:WaffraRegionalCopy.countryIso.value);
 Future<void> confirmDeleteAllEntries() async {
  if(entries.isEmpty){snack(context,waffraIsEnglish?'No transactions to delete':'لا توجد معاملات لحذفها');return;}
  final confirmed=await confirmDeletion(
   waffraIsEnglish?'Delete all transactions?':'حذف كل المعاملات؟',
   waffraIsEnglish?'Delete all ${entries.length} recorded transactions permanently? This cannot be undone.':'سيُحذف ${entries.length} معاملة نهائيًا. لا يمكن التراجع.');
  if(confirmed!=true||!mounted)return;
  // Crash journal BOTH the ledger and duplicate hashes as one recoverable
  // intent. Do not clear in-memory finance until durable storage confirms it.
  final clear=<String,Object>{
   'entries':'[]',
   'waffra_sms_hashes_v1':<String>[],
  };
  try{
   final baseline=_lastFinanceAuthorityRead;
   await _financialWriteQueue.submit(clear,(captured)async{
    if(baseline==null)throw StateError('Finance source baseline unavailable.');
    final committed=await _financeAuthority.saveCaptured(
     route:WaffraFinanceRoute.deleteAllTransactions,
     baseline:baseline,captured:captured,userConfirmed:true,
    );
    _lastFinanceAuthorityRead=committed;
    _lastLedgerSavedRaw=committed.ledgerRaw;
    _lastWidgetRevision=committed.widgetRevision;
   });
   if(!mounted)return;
   setState((){entries.clear();smsHashes.clear();});
   unawaited(_refreshWidget());
   snackSuccess(context,waffraIsEnglish?'All transactions deleted':'تم حذف جميع المعاملات');
  }catch(e){
   debugPrint('Confirmed transaction deletion could not be verified: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be confirmed. Reload before retrying.':
    'تعذر تأكيد الحذف. أعد تحميل المعاملات قبل المحاولة مجددًا.');
  }
 }
 Future<void> editMonthlyBudget()async {
  final amount=TextEditingController(text:monthlyBudget>0?formatWaffraEditAmount(monthlyBudget):'');
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
       onChanged:WaffraHaptics.selection((value)=>update((){enabled=value;validation=null;})),
      ),
      const SizedBox(height:8),
      WaffraText(enabled?
       (waffraIsEnglish?'Set the amount allocated for monthly spending.':'حدد المبلغ الذي ترغب في تخصيصه لمصروفاتك الشهرية.'):
       (waffraIsEnglish?'Monthly spending limit tracking is paused.':'تم إيقاف متابعة حد المصروفات الشهرية.')),
      const SizedBox(height:16),
      TextField(controller:amount,autofocus:false,
       onChanged:(_){if(validation!=null)update(()=>validation=null);},
       style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Theme.of(ctx).colorScheme.onSurface),
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:(waffraIsEnglish?'Spending limit':'حد المصروفات')+' ('+WaffraDisplayCurrency.label(waffraIsEnglish)+') *',
        hintText:waffraIsEnglish?'Example: 3000':'مثال: 3000',
        errorText:validation,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
        filled:true,fillColor:Theme.of(ctx).brightness==Brightness.dark?
         const Color(0xFF1E3A31):Colors.white)),
     ]),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final v=amountOfDisplay(amount.text);
       final fieldError=waffraMonthlyBudgetSaveError(amount.text);
       if(fieldError!=null||v==null||!v.isFinite||v<=0){
        update(()=>validation=fieldError??(waffraIsEnglish?
         'Enter an amount greater than zero':'أدخل مبلغًا صحيحًا أكبر من صفر'));
        return;
       }
       Navigator.pop(ctx,(enabled:enabled,amount:v));
      }),child:WaffraText(waffraIsEnglish?'Save':'حفظ')),
     ],
    ))));
   if(next!=null&&mounted){
    setState((){monthlyBudgetEnabled=next.enabled;monthlyBudget=next.amount;});
    if(!await _persistModuleOrReload(
     WaffraFinanceRoute.challengeAndBudgetUpdate,
     operation:'monthly-budget-save'))return;
    if(mounted)snackSuccess(context,waffraIsEnglish?'Monthly budget settings saved':'تم حفظ إعدادات الميزانية الشهرية');
   }
  }finally{disposeLater([amount]);}
 }
 Future<void> editTransactionFilters()async {
  final min=TextEditingController(text:minTransactionAmount==null?'':formatWaffraEditAmount(minTransactionAmount!));
  final max=TextEditingController(text:maxTransactionAmount==null?'':formatWaffraEditAmount(maxTransactionAmount!));
  String? minError,maxError;
  DateTimeRange? chosen=transactionsDateRange;
  try{
   await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(
    builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Advanced filters':'فلترة بالتاريخ والمبلغ'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:min,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>minError=null),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Minimum amount':'أقل مبلغ',
        errorText:minError,
        border:const OutlineInputBorder())),
      const SizedBox(height:10),
      TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>maxError=null),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Maximum amount':'أعلى مبلغ',
        errorText:maxError,
        border:const OutlineInputBorder())),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
       final range=await showDateRangePicker(context:ctx,
        firstDate:DateTime(2000),lastDate:DateTime.now(),
        initialDateRange:chosen);
       if(range!=null)update(()=>chosen=range);
      }),icon:const Icon(Icons.date_range),
       label:WaffraText(chosen==null
        ?(waffraIsEnglish?'Choose date range':'حدد فترة زمنية')
        :dayText(chosen!.start)+' - '+dayText(chosen!.end))),
     ])),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap((){
       setState((){
        transactionsDateRange=null;minTransactionAmount=null;maxTransactionAmount=null;
       });
       Navigator.pop(ctx);
      }),child:WaffraText(waffraIsEnglish?'Clear':'مسح الفلاتر')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final lo=min.text.trim().isEmpty?null:amountOfDisplay(min.text.trim());
       final hi=max.text.trim().isEmpty?null:amountOfDisplay(max.text.trim());
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
      }),child:WaffraText(waffraIsEnglish?'Apply':'تطبيق')),
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
    LayoutBuilder(builder:(context,box){
     final compact=box.maxWidth<365||MediaQuery.textScalerOf(context).scale(16)>23;
     final budgetLabel=Row(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.donut_large,color:emerald,size:23),
      const SizedBox(width:7),
      Flexible(child:WaffraText(waffraIsEnglish?'Monthly budget':'الميزانية الشهرية',
       maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
     ]);
     final edit=TextButton.icon(
      key:const Key('waffra-month-budget-compact-edit'),
      style:TextButton.styleFrom(minimumSize:const Size(0,48),
       padding:const EdgeInsets.symmetric(horizontal:9,vertical:8),
       tapTargetSize:MaterialTapTargetSize.padded),
      onPressed:WaffraHaptics.tap(editMonthlyBudget),
      icon:const Icon(Icons.edit_outlined,size:17),
      label:WaffraText(waffraIsEnglish?'Edit':'تحديد الميزانية'));
     return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      budgetLabel,const SizedBox(height:6),
      Align(alignment:AlignmentDirectional.centerStart,child:edit),
     ]):Row(children:[Expanded(child:budgetLabel),edit]);
    }),
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
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
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
       IconButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),icon:const Icon(Icons.close)),
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
    onTap:WaffraHaptics.tap(onTap),borderRadius:BorderRadius.circular(18),
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
   onTap:WaffraHaptics.tap(()=>showSummaryTransactions(label=='الدخل'||label=='Income')),
   borderRadius:BorderRadius.circular(19),
   child:Container(
    padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
    decoration:BoxDecoration(
     color:Theme.of(context).brightness==Brightness.dark?
      (label=='الدخل'||label=='Income'?const Color(0xFF244C3A):const Color(0xFF49302C)):tint,
     borderRadius:BorderRadius.circular(19),
     border:Border.all(color:color.withValues(alpha:0.13)),
     boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),
      blurRadius:7,offset:const Offset(0,3))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Row(textDirection:TextDirection.rtl,children:[
      Expanded(child:WaffraText(label,textAlign:TextAlign.right,
       style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold))),
      const SizedBox(width:6),
      CircleAvatar(backgroundColor:color.withValues(alpha:0.12),
       radius:16,child:Icon(symbol,color:color,size:19)),
     ]),
     const SizedBox(height:5),
     Align(alignment:Alignment.centerRight,
      child:FittedBox(fit:BoxFit.scaleDown,
       child:WaffraCurrencyAmount(value,fontSize:17))),
    ]))));
 Widget compactTransaction(MoneyEntry entry){
  final cat=categoryFor(entry.category,entry.income);
  final valueColor=entry.income?waffraIncomeTone(context):Colors.deepOrange;
  final darkMode=Theme.of(context).brightness==Brightness.dark;
  final count=waffraReceiptPaths(entry.receiptPath).length;
  final rowColor=entry.income?(darkMode?const Color(0xFF244C3A):const Color(0xFFB2D5C2)):
   (darkMode?const Color(0xFF49302C):const Color(0xFFFCECE8));
  return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Container(
   decoration:BoxDecoration(color:rowColor,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:forest.withValues(alpha:darkMode ? 0.18 : 0.08))),
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:const EdgeInsets.fromLTRB(11,12,11,12),child:Row(children:[
     CircleAvatar(radius:18,
      backgroundColor:Color(cat.color).withValues(alpha:0.13),
      child:WaffraIllustration(topic:cat.icon,size:36)),
     const SizedBox(width:8),
     Expanded(child:InkWell(onTap:WaffraHaptics.tap(()=>transactionDetails(entry)),
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
      onPressed:WaffraHaptics.tap(()=>transactionActions(entry)),icon:const Icon(Icons.more_vert,size:18)),
    ])),
    if(count>0)PositionedDirectional(top:0,start:0,
     child:Semantics(label:waffraIsEnglish?'$count attachments':'عدد المرفقات $count',
      button:true,child:InkWell(
       onTap:WaffraHaptics.tap(()=>showReceipt(entry.receiptPath!)),
       child:WaffraReceiptCornerBadge(count:count,english:waffraIsEnglish)))),
   ])));
 }
 Widget dashboard(){
  final inc=sum(entries,true),exp=sum(entries,false);
  // Show the month comparison only when there are genuine prior-month
  // transactions and a positive comparison base. Never show a fake +12%.
  final nowBalanceDate=DateTime.now();
  final monthStart=DateTime(nowBalanceDate.year,nowBalanceDate.month);
  final priorMonthStart=DateTime(nowBalanceDate.year,nowBalanceDate.month-1);
  final hasPreviousMonthEntries=entries.any((e)=>
   !e.date.isBefore(priorMonthStart)&&e.date.isBefore(monthStart));
  final previousClosingBalance=entries.where((e)=>e.date.isBefore(monthStart))
   .fold<double>(0,(total,e)=>total+(e.income?e.amount:-e.amount));
  final monthChange=hasPreviousMonthEntries&&previousClosingBalance>0
   ?((inc-exp-previousClosingBalance)/previousClosingBalance)*100:null;
  final visible=entries.where((e){
   final q=search.trim();
   return(waffraSearchAny([e.title,e.category,waffraTr(e.category)],q))&&
    (transactionsDateRange==null||(e.date.isAfter(transactionsDateRange!.start.subtract(const Duration(days:1)))&&e.date.isBefore(transactionsDateRange!.end.add(const Duration(days:1)))))&&
    (minTransactionAmount==null||e.amount>=minTransactionAmount!)&&
    (maxTransactionAmount==null||e.amount<=maxTransactionAmount!)&&
    (typeFilter=='الكل'||(typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income))&&
    (categoryFilter=='الكل'||categoryFilter==e.category);
  }).toList()..sort((a,b)=>b.date.compareTo(a.date));
  final filterCats=<String>{'الكل',...entries.where((e)=>typeFilter=='الكل'||
   (typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income)).map((e)=>e.category)}.toList();
  final selected=filterCats.contains(categoryFilter)?categoryFilter:'الكل';
  final shown=visible.take(waffraDashboardTransactionDisplayCount(
   visible.length,expanded:showAllTransactions)).toList();
  return RefreshIndicator(
   onRefresh:()=>_refreshAndSettle(_dashboardScrollController,0),
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
     physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
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
       delegate:WaffraBalanceHeader(
         balance:inc-exp,english:waffraIsEnglish,focusKey:_tourKeys[0],
         monthlyChangePercent:monthChange,
         refreshVerifiedWidgetBalance:_refreshWidget)),
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
         const SizedBox(height:12),
         Container(
          decoration:BoxDecoration(
           color:Theme.of(context).cardColor,
           borderRadius:BorderRadius.circular(16),
           border:Border.all(color:Theme.of(context).brightness==Brightness.dark
            ?const Color(0xFF506A5A):const Color(0xFFD3E3D9))),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
           Semantics(button:true,toggled:quickActionsExpanded,
            child:InkWell(
             key:const Key('waffra-quick-actions-toggle'),
             borderRadius:BorderRadius.circular(16),
             onTap:WaffraHaptics.tap(
              ()=>setState(()=>quickActionsExpanded=!quickActionsExpanded)),
             child:Padding(
              padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
              child:Row(children:[
               const Icon(Icons.bolt_rounded,color:emerald,size:20),
               const SizedBox(width:7),
               Expanded(child:WaffraText(waffraIsEnglish?'Quick actions':'إجراءات سريعة',
                style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
               AnimatedRotation(
                turns:quickActionsExpanded ? 0.5 : 0.0,
                duration:waffraMotion(180),
                child:const Icon(Icons.keyboard_arrow_down_rounded,size:23)),
              ]))),
            ),
           AnimatedSize(
            duration:waffraMotion(200),alignment:Alignment.topCenter,
            curve:Curves.easeOutCubic,
            child:quickActionsExpanded
             ?Padding(padding:const EdgeInsets.fromLTRB(10,0,10,10),
               child:Row(children:[
                _dashboardShortcut(waffraIsEnglish?'Export report':'تصدير تقرير',
                 Icons.analytics_outlined,()=>exportEntriesPdf(entries,'تقرير عمليات وفرة')),
                const SizedBox(width:10),
                _dashboardShortcut(waffraIsEnglish?'Financial calendar':'التقويم المالي',
                 Icons.calendar_month_outlined,openFinancialCalendar),
               ]))
             :const SizedBox.shrink()),
          ])),
         const SizedBox(height:13),
         monthlyBudgetCard(),
         const SizedBox(height:12),
         monthlySummaryCard(),
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
            if(waffraCanExpandDashboardTransactions(visible.length))
             TextButton(
              key:const Key('waffra-dashboard-transactions-expand'),
              onPressed:WaffraHaptics.tap(
               ()=>setState(()=>showAllTransactions=!showAllTransactions)),
              child:WaffraText(showAllTransactions?
               (waffraIsEnglish?'Show less':'عرض أقل'):
               (waffraIsEnglish?'Show more':'عرض أكثر'))),
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
              onSelected:WaffraHaptics.selection((_)=>setState((){
               typeFilter=choice;categoryFilter='الكل';
              })),
             )))).toList()),
           const SizedBox(height:7),
           Divider(color:forest.withValues(alpha:0.10)),
           Row(children:[
            IconButton(
             tooltip:waffraIsEnglish?'Filter':'فلترة',
             onPressed:WaffraHaptics.tap(()=>setState(()=>showTransactionFilters=!showTransactionFilters)),
             icon:Icon(showTransactionFilters?
              Icons.filter_alt:Icons.filter_alt_outlined,color:emerald)),
            IconButton(
             tooltip:waffraIsEnglish?'Search':'بحث',
             onPressed:WaffraHaptics.tap(()=>setState((){
              showTransactionSearch=!showTransactionSearch;
              if(!showTransactionSearch)search='';
             })),icon:const Icon(Icons.search)),
            if(showTransactionSearch)Expanded(child:TextField(
             onChanged:(v)=>setState(()=>search=v),
             decoration:InputDecoration(isDense:true,
              hintText:waffraIsEnglish?'Search':'ابحث عن عملية',
              border:const OutlineInputBorder()))),
            if(!showTransactionSearch)const Spacer(),
            PopupMenuButton<String>(
             tooltip:waffraIsEnglish?'More actions':'المزيد من الخيارات',
             icon:const Icon(Icons.more_vert),
             onSelected:WaffraHaptics.selection((action){
              if(action=='delete-all')confirmDeleteAllEntries();
              if(action=='restore-transactions')_showVerifiedDeletedTransactions();
              if(action=='pdf')exportEntriesPdf(visible,'تقرير عمليات وفرة');
             }),
             itemBuilder:(ctx)=>[
              if(_lastFinanceAuthorityRead?.source==
                 WaffraRuntimeFinanceBackend.verifiedEncrypted)
               PopupMenuItem(value:'restore-transactions',child:Row(children:[
                const Icon(Icons.restore_rounded,color:emerald),
                const SizedBox(width:8),
                WaffraText(waffraIsEnglish?
                 'Recently deleted (30 days)':'المعاملات المحذوفة (30 يومًا)'),
               ])),
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
              onSelected:WaffraHaptics.selection((_)=>setState((){
               typeFilter=choice;categoryFilter='الكل';
              })))).toList()),
            DropdownButtonFormField<String>(
             key:ValueKey(typeFilter+'-'+selected),initialValue:selected,
             decoration:InputDecoration(labelText:waffraIsEnglish?
              'Category':'تصفية حسب القسم'),
             items:filterCats.map((value)=>DropdownMenuItem(
              value:value,child:WaffraText(waffraTr(value)))).toList(),
             onChanged:WaffraHaptics.selection((value)=>setState(()=>categoryFilter=value??'الكل'))),
            Align(alignment:AlignmentDirectional.centerStart,
             child:TextButton.icon(onPressed:WaffraHaptics.tap(editTransactionFilters),
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
             TextButton.icon(onPressed:WaffraHaptics.tap(()=>exportEntriesPdf(visible,'تقرير عمليات وفرة')),
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
      onChanged:WaffraHaptics.selection((v)=>setState((){forecastCategory=v;forecastReduction=20;}))),
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
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop(false)),
      child:WaffraText(waffraIsEnglish?'Later':'لاحقًا')),
     FilledButton.icon(onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop(true)),
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
  final smartCharts=waffraSmartChartData(recent,now);
  final top=smartCharts.topCategories;
  final monthStart=DateTime(now.year,now.month);
  final priorStart=DateTime(now.year,now.month-1);
  final currentExpense=sum(entries.where((e)=>!e.income&&!e.date.isBefore(monthStart)&&!e.date.isAfter(now)),false);
  final priorExpense=sum(entries.where((e)=>!e.income&&!e.date.isBefore(priorStart)&&e.date.isBefore(monthStart)),false);
  final hasPrior=entries.any((e)=>!e.date.isBefore(priorStart)&&e.date.isBefore(monthStart));
  final thisMonthCount=entries.where((e)=>!e.date.isBefore(monthStart)&&!e.date.isAfter(now)).length;
  final monthDays=DateTime(now.year,now.month+1,0).day;
  final upcoming=recurring.where((r)=>r.active&&!r.income&&r.day>now.day&&r.day<=monthDays).fold<double>(0,(v,r)=>v+r.amount);
  final forecast=now.day>=5&&thisMonthCount>=3?(currentExpense/now.day*monthDays+upcoming):null;
  final weeklySpend=smartCharts.weeklySpend;
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
   final periods=smartCharts.periods;
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
        onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop())),
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
      onPressed:WaffraHaptics.tap(recent.isEmpty?null:()=>exportEntriesPdf(recent,
       waffraIsEnglish?'Waffra analytics - Last 90 days':'تحليلات وفرة - آخر 90 يوم',
       analytics:true)),
      icon:const Icon(Icons.picture_as_pdf_outlined),
      label:WaffraText(waffraIsEnglish?'Export analytics PDF':'تصدير التحليلات إلى PDF')),
     const SizedBox(height:24),
     ExpansionTile(leading:const Icon(Icons.info_outline,color:emerald),
      title:WaffraText(waffraIsEnglish?'Why this result?':'ليه النتيجة دي؟'),
      children:[Padding(padding:const EdgeInsets.all(14),
       child:WaffraText(waffraIsEnglish?
        'Last 90 days (${recent.length} transactions): income ${cash(income)}, expenses ${cash(spending)}. Indicative score.':
        'آخر 90 يومًا: ${recent.length} معاملة، دخل ${cash(income)}، مصروف ${cash(spending)}. مؤشر تقريبي.'))]),
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
    selected:{period},onSelectionChanged:WaffraHaptics.selection((v)=>setState(()=>period=v.first))),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:DropdownButtonFormField<int>(initialValue:year,
     decoration:InputDecoration(labelText:waffraTr('السنة')),
     items:years.map((x)=>DropdownMenuItem(value:x,child:WaffraText('$x'))).toList(),
     onChanged:WaffraHaptics.selection((v){if(v!=null)setState(()=>year=v);}))),
    if(period=='شهري')Expanded(child:DropdownButtonFormField<int>(initialValue:month,
     decoration:InputDecoration(labelText:waffraTr('الشهر')),
     items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:WaffraText('شهر ${i+1}'))),
     onChanged:WaffraHaptics.selection((v){if(v!=null)setState(()=>month=v);}))),
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
   OutlinedButton.icon(onPressed:WaffraHaptics.tap(()=>exportEntriesPdf(data,'تحليلات وفرة - $period ${period=='شهري'?'$month/':''}$year',analytics:true)),
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
  final budget=TextEditingController(text:initial==null||initial.budget==0?'':formatWaffraEditAmount(initial.budget));
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
      onPressed:WaffraHaptics.tap(()=>update(()=>icon=x)),icon:Icon(categoryIcon(x),color:icon==x?emerald:null))).toList()),
     const WaffraText('اختر لون'),
     Wrap(spacing:7,children:colors.map((x)=>InkWell(
      onTap:WaffraHaptics.tap(()=>update(()=>color=x)),
      child:CircleAvatar(radius:15,backgroundColor:Color(x),
       child:color==x?const Icon(Icons.check,color:Colors.white,size:17):null))).toList()),
     if(!(initial?.income??income))...[
      TextField(controller:budget,onChanged:(_)=>update((){}),
       keyboardType:const TextInputType.numberWithOptions(decimal:true),inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],decoration:InputDecoration(labelText:waffraTr('ميزانية شهرية (اختياري)'),
       errorText:attempted?waffraAmountFieldError(budget.text,required:false):null)),
      const SizedBox(height:10),
      DropdownButtonFormField<int>(initialValue:alertPercent,
       decoration:InputDecoration(labelText:waffraTr('ودّك ننبهك عند كم ٪ من الميزانية؟')),
       items:[50,60,70,75,80,85,90,95,100].map((v)=>DropdownMenuItem(value:v,child:WaffraText('$v٪'))).toList(),
       onChanged:WaffraHaptics.selection((v){if(v!=null)update(()=>alertPercent=v);})),
      if(amountOfDisplay(budget.text)!=null)Padding(padding:const EdgeInsets.only(top:8),
       child:WaffraText('بننبهك عند صرف ${cash(amountOfDisplay(budget.text)!*alertPercent/100)} من ميزانية ${cash(amountOfDisplay(budget.text)!)}')),
     ],
    ])),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      final n=name.text.trim();update(()=>attempted=true);
      if(WaffraValidators.requiredText(n)!=null || WaffraValidators.uniqueCategory(fullName(),
       categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null ||
       WaffraValidators.positiveAmount(budget.text,required:false)!=null)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:fullName(),icon:icon,color:color,
       income:initial?.income??income,parentId:effectiveParentId,budget:budget.text.trim().isEmpty?0:(amountOfDisplay(budget.text)??0),alertPercent:alertPercent,origin:initial?.origin??'user'));
     }),child:const WaffraText('حفظ')),
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
      onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'main'))),
     ListTile(leading:const Icon(Icons.account_tree_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'New subcategory':'إضافة قسم فرعي'),
      onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'sub'))),
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
       onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,parent.id)));
     })),
   ));
  if(!mounted||parentId==null)return;
  await addCategory(income:income,parentId:parentId);
 }
 Future<void> addCategory({bool income=false,String parentId=''})async {
  final c=await categoryDialog(income:income,parentId:parentId);
  if(c==null||!mounted)return;
  if(WaffraValidators.uniqueCategory(c.name,
    categories.where((x)=>x.income==c.income).map((x)=>x.name))=='duplicate'){
   snack(context,'القسم موجود بالفعل');return;
  }
  setState(()=>categories.add(c));
  await _persistModuleOrReload(WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   operation:'category-create');
 }
 Future<void> updateCategory(BudgetCategory c)async {
  final revised=await categoryDialog(initial:c);
  if(revised==null||!mounted)return;
  if(WaffraValidators.uniqueCategory(revised.name,
    categories.where((x)=>x.id!=c.id&&x.income==c.income).map((x)=>x.name))=='duplicate'){
   snack(context,waffraIsEnglish?'Category already exists':'القسم موجود بالفعل');return;
  }
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
     entries[j]=old.withCategory(renamed);
    }
   }
   for(var j=0;j<recurring.length;j++){
    final old=recurring[j];
    final renamed=renames[old.category];
    if(renamed!=null&&old.income==c.income){
     recurring[j]=old.withCategory(renamed);
    }
   }
  });
  try{
   await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  }catch(error){
   debugPrint('Category edit not committed by verified finance source: $error');
   if(mounted)await _loadFinanceSafely();
   if(mounted)snack(context,waffraIsEnglish?
    'Category edit was not saved. Financial data was reloaded safely.':
    'لم يتم حفظ تعديل القسم. أعدنا تحميل بياناتك المالية بشكل آمن.');
  }
 }
 WaffraFinanceRoute _moduleMutationRoute(WaffraFinanceModule module)=>
  switch(module){
   WaffraFinanceModule.categories=>WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   WaffraFinanceModule.goals=>WaffraFinanceRoute.goalCreateEditDeleteRestore,
   WaffraFinanceModule.recurring=>WaffraFinanceRoute.recurringCreateEditDeleteRestore,
  };

 Future<void> _deleteVerifiedModule({
  required WaffraFinanceModule module,
  required Map<String,dynamic> displayed,
 })async{
  try{
   await _financialWriteQueue.drain();
   final baseline=await _financeAuthority.load(route:_moduleMutationRoute(module));
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
      baseline.encryptedWitness==null){
    throw StateError('Verified encrypted finance source is unavailable.');
   }
   WaffraVerifiedModuleUiGuard.requireUnchanged(
    activeRaw:baseline.finance.getString(
     WaffraVerifiedModuleUiGuard.activeKey(module)),
    selected:displayed,
   );
   final id=displayed['id'] as String;
   await _financialWriteQueue.submit(<String,Object>{'id':id},(_)async{
    // No optimistic mutation to goals/categories/recurring; only the typed
    // SQLCipher tombstone writer may remove the source entity.
    await _financeAuthority.deleteVerifiedModuleToRecycle(
     baseline:baseline,module:module,entityId:id,
     now:DateTime.now().toUtc(),userConfirmed:true);
   });
   if(!mounted)return;
   await _loadFinanceSafely();
   if(module==WaffraFinanceModule.recurring)await syncRecurringReminders();
   if(mounted&&ready)snackSuccess(context,waffraIsEnglish?
    'Moved to encrypted Recently Deleted for 30 days':
    'تم النقل إلى المحذوفات المشفرة لمدة 30 يومًا');
  }catch(error){
   debugPrint('Encrypted module delete refused: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Cannot verify deletion. Your financial data was not reset. Reload and retry.':
     'تعذر التحقق من الحذف. لم يتم تصفير البيانات المالية. أعد التحميل وحاول مجددًا.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _restoreVerifiedModule({
  required WaffraFinanceModule module,
  required String entityId,
 })async{
  try{
   await _financialWriteQueue.drain();
   await _financialWriteQueue.submit(<String,Object>{'id':entityId},(_)async{
    final baseline=await _financeAuthority.load(route:_moduleMutationRoute(module));
    if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
       baseline.encryptedWitness==null){
     throw StateError('Verified encrypted module restore source is missing.');
    }
    await _financeAuthority.restoreVerifiedDeletedModule(
     baseline:baseline,module:module,entityId:entityId,
     now:DateTime.now().toUtc());
   });
   if(!mounted)return;
   await _loadFinanceSafely();
   if(module==WaffraFinanceModule.recurring)await syncRecurringReminders();
   if(mounted&&ready)snackSuccess(context,waffraIsEnglish?
    'Encrypted item restored safely':'تم استرجاع العنصر المشفر بأمان');
  }catch(error){
   debugPrint('Encrypted finance module restoration blocked safely: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Restore was not verified. Restore the deleted parent first or retry safely.':
     'تعذر التحقق من الاسترجاع. استرجع القسم الرئيسي أولًا أو حاول مجددًا.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _showVerifiedModuleTrash(WaffraFinanceModule module)async{
  try{
   final route=_moduleMutationRoute(module);
   final baseline=await _financeAuthority.load(route:route);
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
    throw StateError('Encrypted module trash source was not selected.');
   }
   final expiries=await _financeAuthority.listVerifiedDeletedModules(module);
   final items=WaffraVerifiedModuleUiGuard.verifiedTrash(
    module:module,
    trashRaw:baseline.finance.getString(
     WaffraVerifiedModuleUiGuard.trashKey(module)),
    encryptedExpiries:expiries,
   );
   if(!mounted)return;
   final labels=module==WaffraFinanceModule.categories
    ?<String>['Categories','الأقسام']
    :module==WaffraFinanceModule.goals
     ?<String>['Savings goals','الأهداف']
     :<String>['Recurring','المتكررة'];
   final choice=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?
      'Encrypted Recently Deleted — ${labels[0]}':
      'المحذوفات المشفرة — ${labels[1]}'),
     content:SizedBox(
      width:double.maxFinite,
      height:min(365.0,items.length*78.0+35.0),
      child:items.isEmpty
       ?Center(child:WaffraText(waffraIsEnglish?
        'No items available to restore':'لا توجد عناصر قابلة للاسترجاع'))
       :ListView.builder(itemCount:items.length,itemBuilder:(ctx,index){
        final item=items[index];
        final body=item[WaffraVerifiedModuleUiGuard.trashPayloadKey(module)]
          as Map<String,dynamic>;
        final id=body['id'] as String;
        final until=expiries[id]!;
        final expired=DateTime.now().toUtc().millisecondsSinceEpoch>=until;
        return ListTile(
         leading:Icon(Icons.restore_rounded,
          color:expired?Colors.grey:emerald),
         title:WaffraText('${body['name']??body['title']??id}',maxLines:1),
         subtitle:WaffraText(expired
          ?(waffraIsEnglish?'Recovery expired':'انتهت مدة الاسترجاع')
          :(waffraIsEnglish
           ?'Restore until ${dayText(DateTime.fromMillisecondsSinceEpoch(until,isUtc:true).toLocal())}'
           :'الاسترجاع حتى ${dayText(DateTime.fromMillisecondsSinceEpoch(until,isUtc:true).toLocal())}')),
         enabled:!expired,
         onTap:WaffraHaptics.tap(expired?null:()=>Navigator.pop(ctx,id)),
        );
       })),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
   if(choice!=null&&mounted)await _restoreVerifiedModule(
    module:module,entityId:choice);
  }catch(error){
   debugPrint('Encrypted module trash could not be verified: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Encrypted Recently Deleted is unavailable until source verification succeeds.':
    'المحذوفات المشفرة غير متاحة حتى ينجح التحقق من المصدر.');
  }
 }

 Future<void> deleteCategory(BudgetCategory c)async {
  final children=categories.where((item)=>item.parentId==c.id).toList();
  if(children.isNotEmpty){
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Delete subcategories first':'احذف الأقسام الفرعية أولاً'),
    content:WaffraText(waffraIsEnglish?'This category has ${children.length} subcategories. Delete or move them first to protect your categorization.':'القسم يحتوي على ${children.length} قسم فرعي. احذف الأقسام الفرعية أولاً للحفاظ على تصنيف المعاملات.'),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   return;
  }
  final linkedEntries=entries.where((e)=>e.category==c.name&&e.income==c.income).length;
  final linkedRecurring=recurring.where((e)=>e.category==c.name&&e.income==c.income).length;
  if(linkedEntries>0||linkedRecurring>0){
   if(!mounted)return;
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Category cannot be deleted':'لا يمكن حذف القسم'),
    content:WaffraText(waffraIsEnglish
     ?'This category has $linkedEntries transactions and $linkedRecurring recurring items. Remove linked items first.'
     :'القسم مرتبط بـ$linkedEntries معاملة و$linkedRecurring عملية متكررة. احذف العناصر المرتبطة أولًا.'),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('حسنًا')),
     if(linkedEntries>0)TextButton(onPressed:WaffraHaptics.tap((){
      Navigator.pop(ctx);
      setState((){
       tab=0;addFabExpanded=false;showAllTransactions=true;
       showTransactionFilters=true;categoryFilter=c.name;
       typeFilter=c.income?'الدخل':'المصروفات';
       search='';transactionsDateRange=null;
       minTransactionAmount=null;maxTransactionAmount=null;
      });
     }),child:WaffraText(waffraIsEnglish?'View transactions':'عرض المعاملات المرتبطة'))
     else TextButton(onPressed:WaffraHaptics.tap((){
      Navigator.pop(ctx);setState((){tab=4;goalsOpened=false;addFabExpanded=false;});
     }),child:WaffraText(waffraIsEnglish?'View recurring':'عرض العمليات المتكررة')),
    ]));
   return;
  }
  final yes=await confirmDeletion(
   waffraIsEnglish?'Delete category?':'حذف القسم',
   waffraIsEnglish
    ?'Delete «${c.name}» for 30 days? Restore is possible, but its budget resets to zero.'
    :'هل تريد نقل القسم «${c.name}» إلى المحذوفات لمدة 30 يومًا؟ عند استرجاعه سيعود بميزانية صفر.');
  if(yes!=true||!mounted)return;
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _deleteVerifiedModule(
    module:WaffraFinanceModule.categories,displayed:c.toJson());
   return;
  }
  setState((){
   categories.removeWhere((e)=>e.id==c.id);
   deletedCategories.add({'category':c.toJson(),'deletedAt':DateTime.now().toIso8601String()});
  });
  await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  if(mounted)snackSuccess(context,waffraIsEnglish?'Category moved to Recently Deleted for 30 days':'تم نقل القسم للمحذوفات لمدة 30 يومًا');
 }
 Future<void> showCategoryTrash()async {
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _showVerifiedModuleTrash(WaffraFinanceModule.categories);
   return;
  }
  final before=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  if(before!=deletedCategories.length)await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
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
             if(WaffraValidators.uniqueCategory(original.name,
               categories.where((c)=>c.income==original.income).map((c)=>c.name))=='duplicate'){
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
                 ?'Restoring also restores «${restoreParent!.name}». Both budgets reset to zero. Continue?'
                 :'سيُسترجع أيضًا القسم الرئيسي «${restoreParent!.name}»، وتُصفّر الميزانيتان. متابعة؟'),
                actions:[
                 TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(confirmCtx,false)),
                  child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
                 FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(confirmCtx,true)),
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
             await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
             if(!dialogCtx.mounted)return;
             Navigator.pop(dialogCtx);
             if(mounted)snackSuccess(context,waffraIsEnglish
              ?'Category restored with zero budget. Past transactions are unchanged.'
              :'تم استرجاع القسم بميزانية صفر. معاملاتك القديمة محفوظة.');
            },
         onDeleteForever:()async{
             final yes=await confirmDeletion(
              waffraIsEnglish?'Permanently delete category?':'حذف القسم نهائيًا',
              waffraIsEnglish?'Delete «${original.name}» forever? You cannot restore it.'
               :'هل تريد حذف القسم «${original.name}» نهائيًا؟ لا يمكن استرجاعه بعد ذلك.');
             if(yes==true&&mounted){
              setState(()=>deletedCategories.remove(item));
              refresh((){});
              await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
             }
            },
        );
       }).toList())),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
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
  ChoiceChip(label:WaffraText(label),selected:selected,onSelected:WaffraHaptics.selection((_)=>onTap()),
   showCheckmark:selected,
   side:WaffraSubtleSelection.border(selected,Theme.of(context).brightness),
   selectedColor:Theme.of(context).brightness==Brightness.dark
    ?const Color(0xFF28533C):waffraMint,
   labelStyle:TextStyle(
    color:selected?(Theme.of(context).brightness==Brightness.dark
     ?const Color(0xFFD9FFE9):forest):null,
    fontWeight:selected?FontWeight.bold:FontWeight.normal));
 Future<void> goalDialog()async {
  await _ensureFinanceBound();
  final name=TextEditingController(),target=TextEditingController();
  final customGoals=await _financeAuthority.loadCustomGoalSuggestions();
  if(!mounted){name.dispose();target.dispose();return;}
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
  final g=await showWaffraSmoothDialog<SavingGoal>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,updateGoal)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Add savings goal':'إضافة هدف ادخار'),
    scrollable:true,
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     InkWell(
      borderRadius:BorderRadius.circular(14),
      onTap:WaffraHaptics.tap(()async{
       final picked=await showWaffraDialog<String>(context:ctx,
        builder:(pickCtx){
         String query='';
         return StatefulBuilder(builder:(pickCtx,refresh){
          final matches=suggested.where(
           (item)=>waffraSearchMatches(item,query)).toList();
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
              onTap:WaffraHaptics.tap(()=>Navigator.pop(pickCtx,otherGoal))),
             const Divider(height:10),
             Expanded(child:matches.isEmpty
              ?Center(child:WaffraText(waffraIsEnglish?'No matching goals':'لا توجد أهداف مطابقة'))
              :ListView.builder(itemCount:matches.length,itemBuilder:(pickCtx,index)=>
               ListTile(
                dense:true,
                title:WaffraText(matches[index],maxLines:2),
                onTap:WaffraHaptics.tap(()=>Navigator.pop(pickCtx,matches[index]))))),
            ]),
           ),
          );
         });
        });
       if(picked!=null&&ctx.mounted)updateGoal((){
        selectedGoal=picked;
        name.text=picked==otherGoal?'':picked;
       });
      }),
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
      inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
      onChanged:(_)=>updateGoal((){}),
      decoration:InputDecoration(
       labelText:waffraIsEnglish?'Target amount *':'المبلغ المستهدف *',
       hintText:waffraIsEnglish?'e.g. 25000':'مثال: 25000',
       errorText:attempted?waffraAmountFieldError(target.text):null,
       border:const OutlineInputBorder())),
    ]),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      updateGoal(()=>attempted=true);
      final n=amountOfDisplay(target.text);
      if(selectedGoal.isEmpty||validateGoalName()!=null||
       WaffraValidators.positiveAmount(target.text)!=null||n==null)return;
      Navigator.pop(ctx,SavingGoal(id:newId(),name:name.text.trim(),target:n,saved:0));
     }),child:WaffraText(waffraIsEnglish?'Add goal':'إضافة الهدف')),
    ],
   )));
  disposeLater([name,target]);
  if(g!=null&&mounted){
   if(selectedGoal==otherGoal){
    final key=waffraNormalizeGoal(g.name);
    if(!allDefaultNames.contains(key)&&!customGoals.any((entry)=>waffraNormalizeGoal(entry)==key)){
     await _financeAuthority.addCustomGoalSuggestion(g.name);
    }
   }
   if(!mounted)return;
   setState(()=>goals.add(g));
   if(!await _persistModuleOrReload(WaffraFinanceRoute.goalCreateEditDeleteRestore,
     operation:'goal-create'))return;
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
           ?'${WaffraDisplayCurrency.money(g.saved,english:true)} of ${WaffraDisplayCurrency.money(g.target,english:true)}'
           :'${WaffraDisplayCurrency.money(g.saved,english:false)} من ${WaffraDisplayCurrency.money(g.target,english:false)}',
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
         inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
         onChanged:(_)=>update((){}),
         decoration:InputDecoration(
          hintText:'0.00',
          suffixText:WaffraDisplayCurrency.label(waffraIsEnglish),
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
           onPressed:WaffraHaptics.tap(()=>addQuickAmount(quick)),
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
         onPressed:WaffraHaptics.tap((){
          update(()=>attempted=true);
          if(waffraAmountFieldError(amount.text)!=null)return;
          final value=amountOfDisplay(amount.text);
          if(value==null||value<=0)return;
          Navigator.pop(dialogCtx,value);
         }),
         child:WaffraText(waffraIsEnglish?'Add amount':'إضافة'))),
        const SizedBox(height:7),
        SizedBox(width:double.infinity,child:OutlinedButton(
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
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
   if(!await _persistModuleOrReload(WaffraFinanceRoute.goalCreateEditDeleteRestore,
     operation:'goal-funding'))return;
   if(achieved&&mounted){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'🎉 Goal achieved!':'🎉 مبروك!'),
     content:WaffraText(waffraIsEnglish
      ?'You achieved your savings goal “${g.name}”!'
      :'تم تحقيق هدف الادخار «${g.name}» بنجاح!'),
     actions:[FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
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
      inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],decoration:InputDecoration(
       labelText:waffraIsEnglish?'Daily amount *':'الادخار اليومي *',
       errorText:attempted?waffraAmountFieldError(amount.text):null)),
     const SizedBox(height:12),
     DropdownButtonFormField<int>(initialValue:days,
      decoration:InputDecoration(labelText:waffraIsEnglish?'Duration *':'مدة التحدي *'),
      items:[7,14,30].map((n)=>DropdownMenuItem<int>(value:n,
       child:WaffraText(waffraIsEnglish?'$n days':'$n يوم'))).toList(),
      onChanged:WaffraHaptics.selection((n){if(n!=null)update(()=>days=n);})),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?
      'This tracks your habit manually and never deducts money.':
      'التحدي لتتبّع عادتك يدويًا، ولن يخصم أو يحوّل أموالًا تلقائيًا.',
      style:const TextStyle(color:Colors.grey,fontSize:12)),
    ])),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      update(()=>attempted=true);
      if(WaffraValidators.requiredText(name.text)!=null||
       WaffraValidators.positiveAmount(amount.text)!=null)return;
      final value=amountOfDisplay(amount.text);
      if(value==null)return;
      Navigator.pop(ctx,SavingChallenge(id:newId(),title:name.text.trim(),
       dailyAmount:value,days:days));
     }),child:WaffraText(waffraIsEnglish?'Save challenge':'إضافة التحدي')),
    ])));
  disposeLater([name,amount]);
  if(challenge==null||!mounted)return;
  setState(()=>challenges.add(challenge));
  await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
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
         onPressed:WaffraHaptics.tap(()async{
          final ok=await confirmDeletion(waffraIsEnglish?'Delete challenge?':'حذف التحدي',
           waffraIsEnglish?'Progress cannot be recovered.':
            'هل أنت متأكد من حذف هذا التحدي؟ سيتم حذف التحدي نهائيًا، ولن تتمكن من استعادته لاحقًا.');
          if(ok==true&&mounted){
           setState(()=>challenges.removeWhere((x)=>x.id==c.id));await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
          }
         })),
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
        TextButton.icon(onPressed:WaffraHaptics.tap(allowed?()async{
          final i=challenges.indexWhere((x)=>x.id==c.id);
          if(i<0||!challenges[i].canComplete(DateTime.now()))return;
          setState(()=>challenges[i]=challenges[i].complete());
          await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
         }:null),icon:Icon(completed?Icons.check_circle_outline:Icons.check,size:18),
         label:WaffraText(completed?(waffraIsEnglish?'Complete':'مكتمل'):
          allowed?(waffraIsEnglish?'Saved today':'وفّرت اليوم'):
          (waffraIsEnglish?'Marked today':'تم اليوم'))),
       ]),
      ]));
    }),
    Padding(padding:const EdgeInsets.fromLTRB(14,0,14,14),
     child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(createSavingChallenge),
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
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _showVerifiedModuleTrash(WaffraFinanceModule.goals);
   return;
  }
  final before=deletedGoals.length;
  deletedGoals.removeWhere((item){
   final date=DateTime.tryParse('${item['deletedAt']??''}');
   return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));
  });
  if(before!=deletedGoals.length)await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
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
         await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
         if(!ctx.mounted)return;
         Navigator.pop(ctx);
         if(mounted)snackSuccess(context,waffraIsEnglish
          ?'Goal restored with zero savings. Past transactions are unchanged.'
          :'تم استرجاع الهدف بمدخرات صفر. جميع المعاملات القديمة المرتبطة به محفوظة في السجل المالي.');
        },
        onDeleteForever:()async{
         final yes=await confirmDeletion(
          waffraIsEnglish?'Permanently delete goal?':'حذف الهدف نهائيًا',
          waffraIsEnglish
           ?'Permanently delete “${goal.name}”? Cannot undo. Transactions stay saved.'
           :'حذف الهدف «${goal.name}» نهائيًا؟ لا يمكن التراجع. معاملاتك محفوظة.');
         if(yes!=true||!mounted)return;
         setState(()=>deletedGoals.remove(item));
         await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
         if(ctx.mounted)refresh((){});
        },
       );
      }).toList())),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
 Widget goalsPage(){
  final target=goals.fold<double>(0,(v,g)=>v+g.target);
  final saved=goals.fold<double>(0,(v,g)=>v+g.saved);
  final pct=target==0?0.0:(saved/target).clamp(0.0,1.0);
  final filtered=goals.where((g)=>goalDisplay=='all'||
   (goalDisplay=='done'?g.saved>=g.target:g.saved<g.target)).toList();
  return ListView(controller:_goalsScrollController,
   physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
   padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
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
   Row(children:[
    Expanded(flex:3,child:WaffraOutlinedItemsCount(
     label:waffraIsEnglish?'Current goals':'عدد الأهداف الحالية',count:goals.length)),
    const SizedBox(width:9),
    Flexible(flex:2,fit:FlexFit.loose,child:WaffraDeletedItemsButton(
     onPressed:WaffraHaptics.tapRequired(deletedGoalsDialog),
     label:waffraIsEnglish?'Deleted (${deletedGoals.length})'
      :'المحذوفة (${deletedGoals.length})')),
   ]),
   const SizedBox(height:12),

   // Savings additions use the same physical-left circular +.
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
       WaffraIllustration(topic:g.name,size:44),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(g.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        WaffraText(waffraIsEnglish?'Target: ${cash(g.target)}':'المستهدف: ${cash(g.target)}',
         style:const TextStyle(fontSize:12)),
       ])),
       PopupMenuButton<String>(onSelected:WaffraHaptics.selection((v)async {
        if(v=='delete'){
         final linked=g.saved>0||entries.any((e)=>e.category==g.name);
         final yes=await confirmDeletion(waffraIsEnglish?'Delete savings goal?':'حذف هدف الادخار',
          waffraGoalDeleteWarning(g.name,linked,waffraIsEnglish));
         if(yes==true&&mounted){
          if(_lastFinanceAuthorityRead?.source==
             WaffraRuntimeFinanceBackend.verifiedEncrypted){
           await _deleteVerifiedModule(
            module:WaffraFinanceModule.goals,displayed:g.toJson());
          }else{
           setState((){deletedGoals.add({'goal':g.toJson(),'deletedAt':DateTime.now().toIso8601String()});goals.removeWhere((x)=>x.id==g.id);});
           await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
          }
         }
        }
       }),itemBuilder:(_)=>[PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete goal':'حذف الهدف'))]),
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
       if(g.saved<g.target)TextButton.icon(onPressed:WaffraHaptics.tap(()=>fundGoal(g)),
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
      child:const WaffraIllustration(topic:'wallet',size:94)),
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
 Future<void> recurringDialog({String? suggestedTitle,double? suggestedAmount})async {
  final title=TextEditingController(text:suggestedTitle??''),
   amount=TextEditingController(text:suggestedAmount==null?'':formatWaffraEditAmount(suggestedAmount)),
   day=TextEditingController(text:'1');
  bool income=false;String category=forType(false).isNotEmpty?
    forType(false).first.name:'';bool attempted=false;
  DateTime startAt=DateTime.now();
  final r=await showWaffraDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forType(income);
    final selected=options.any((x)=>x.name==category)?category:
      (options.isNotEmpty?options.first.name:'');
    return AlertDialog(title:const WaffraText('عملية شهرية متكررة'),
     content:SizedBox(width:340,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'الوصف *',
       errorText:attempted?waffraTextFieldError(title.text):null)),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(amount.text):null)),
      const SizedBox(height:12),
      DropdownButtonFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:WaffraHaptics.selection((v){if(v!=null)update((){
         income=v;category=forType(v).isNotEmpty?forType(v).first.name:'';
        });})),
      const SizedBox(height:12),
      InkWell(
       borderRadius:BorderRadius.circular(14),
       onTap:WaffraHaptics.tap(()async{
        final picked=await showWaffraDialog<String>(context:ctx,
         builder:(searchCtx){
          String query='';
          return StatefulBuilder(builder:(searchCtx,refresh){
           final filtered=options.where((c)=>
            waffraSearchAny([c.name,waffraTr(c.name)],query)).toList();
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
                  onTap:WaffraHaptics.tap(()=>Navigator.pop(searchCtx,option.name)));
                })),
             ]),
            ),
           );
          });
         });
        if(picked!=null&&ctx.mounted)update(()=>category=picked);
       }),
       child:InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Category *':'القسم *',
         errorText:attempted&&WaffraValidators.requiredCategory(
          selected,options.map((c)=>c.name))!=null?waffraRequiredFieldMessage:null,
         suffixIcon:const Icon(Icons.search_rounded),
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
         contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:15)),
        child:Row(children:[
         Expanded(child:WaffraText(selected.isEmpty?
          (waffraIsEnglish?'Choose a category':'اختر قسمًا'):selected,maxLines:2,
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600))),
         const SizedBox(width:8),
         const Icon(Icons.arrow_drop_down_rounded,size:20),
        ]),
       ),
      ),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
       final picked=await waffraPickDateWithToday(english:waffraIsEnglish,context:ctx,initialDate:startAt,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime(DateTime.now().year+5));
       if(picked!=null)update((){startAt=picked;day.text=picked.day.toString();});
      }),icon:const Icon(Icons.calendar_month_outlined),label:WaffraText(waffraIsEnglish?'First due: ${dayText(startAt)}':'أول استحقاق: ${dayText(startAt)}')),
      const SizedBox(height:8),
      TextField(controller:day,keyboardType:TextInputType.number,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Day of month *':'يوم الشهر *',helperText:waffraIsEnglish?'1–31':'من 1 إلى 31',
       errorText:attempted?waffraDayFieldError(day.text):null)),
     ]))),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final n=amountOfDisplay(amount.text),d=int.tryParse(digits(day.text));update(()=>attempted=true);
       if(WaffraValidators.requiredText(title.text)==null&&
        WaffraValidators.positiveAmount(amount.text)==null&&
        WaffraValidators.dayOfMonth(day.text)==null&&
        WaffraValidators.requiredCategory(selected,options.map((c)=>c.name))==null&&
        n!=null&&d!=null){
        Navigator.pop(ctx,RecurringBill(id:newId(),title:title.text.trim(),category:selected,
         amount:n,income:income,day:d,startAt:startAt));
       }
      }),child:const WaffraText('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState(()=>recurring.add(r));
   if(!await _persistModuleOrReload(WaffraFinanceRoute.recurringCreateEditDeleteRestore,
     operation:'recurring-create'))return;
   await applyRecurring();
   await syncRecurringReminders();
  }
 }
 DateTime nextRecurringDue(RecurringBill r) {
  final today=DateTime.now();
  final monthlyDue=WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
  final monthId=WaffraRecurringPolicy.entryId(r.id,monthlyDue);
  return WaffraRecurringPolicy.nextActionableDue(
   today:today,startAt:r.startAt,day:r.day,
   currentMonthPaid:entries.any((entry)=>entry.id==monthId),
   postponedUntil:DateTime.tryParse(recurringPostponed[monthId]??''));
 }
 Widget recurringPage(){
  final active=recurring.where((r)=>r.active).toList();
  final orderedActive=active.toList()..sort((a,b)=>
   nextRecurringDue(a).compareTo(nextRecurringDue(b)));
  final nextBill=orderedActive.isEmpty?null:orderedActive.first;
  final monthly=active.where((r)=>!r.income).fold<double>(0,(v,r)=>v+r.amount);
  final shown=recurring.where((r)=>recurringDisplay=='all'||
   (recurringDisplay=='active'?r.active:!r.active)).toList();
  final upcoming=active.where((r){
   final days=nextRecurringDue(r).difference(DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day)).inDays;
   return days>=0&&days<=3;
  }).length;
  return ListView(controller:_recurringScrollController,
   physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
   padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'Recurring transactions':'العمليات المتكررة',
    subtitle:waffraIsEnglish?'Track recurring payments and due dates':
     'نظّم عملياتك الشهرية ومواعيد استحقاقها بسهولة.',
    icon:Icons.event_repeat_rounded,titleKey:_tourKeys[4]),
   const SizedBox(height:9),
   Row(children:[
    Expanded(child:OutlinedButton.icon(
     onPressed:WaffraHaptics.tap(showWaffraFinancialCalendar),
     style:OutlinedButton.styleFrom(minimumSize:WaffraActionLayout.minimumSize,
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:12),
      side:BorderSide(color:Theme.of(context).colorScheme.primary,width:1.2),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
     icon:const Icon(Icons.calendar_month,size:18),
     label:WaffraText(waffraIsEnglish?'Financial calendar':'التقويم المالي',
      maxLines:2,textAlign:TextAlign.center,
      style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.bold)))),
    const SizedBox(width:9),
    Flexible(fit:FlexFit.loose,child:WaffraDeletedItemsButton(
     onPressed:WaffraHaptics.tapRequired(deletedRecurringDialog),
     label:waffraIsEnglish?'Deleted recurring (${deletedRecurring.length})':
      'المتكررة المحذوفة (${deletedRecurring.length})')),
   ]),
   const SizedBox(height:10),
   Row(children:[
    Expanded(child:WaffraOutlinedItemsCount(
     key:const Key('waffra-recurring-count-badge'),
     label:waffraIsEnglish?'Recurring count':'عدد العمليات المتكررة',
     count:recurring.length)),
    const SizedBox(width:9),
    Expanded(child:Container(
     padding:const EdgeInsets.symmetric(horizontal:7,vertical:7),
     decoration:BoxDecoration(
      color:Theme.of(context).cardColor,
      border:Border.all(color:Theme.of(context).dividerColor.withValues(alpha:.5)),
      borderRadius:BorderRadius.circular(16)),
     child:Row(children:[
      Expanded(child:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Reminders':'التذكير',
        maxLines:1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
       WaffraText(waffraIsEnglish?'1 day before • 9 AM':'قبل الموعد بيوم',
        maxLines:2,style:const TextStyle(fontSize:10)),
      ])),
      Transform.scale(scale:.82,child:Switch.adaptive(value:recurringRemindersEnabled,
       onChanged:WaffraHaptics.selection(toggleRecurringReminders))),
     ]))),
   ]),
   const SizedBox(height:9),
   if(nextBill!=null)...[
    const SizedBox(height:9),
    Card(child:ListTile(
     dense:true,
     leading:const Icon(Icons.event_available_rounded,color:emerald),
     title:WaffraText(waffraIsEnglish?'Next due date':'أقرب استحقاق',
      style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:WaffraText('${nextBill.title} • ${dayText(nextRecurringDue(nextBill))}',
      maxLines:2),
     trailing:WaffraText(cash(nextBill.amount),
      style:const TextStyle(fontWeight:FontWeight.bold)),
    )),
   ],
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

   // Recurring additions use the same physical-left circular +.
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
      Switch(value:r.active,onChanged:WaffraHaptics.selection((enabled)async {
       final index=recurring.indexWhere((item)=>item.id==r.id);
       if(index<0)return;
       if(enabled){
        final chosen=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:DateTime.now().add(const Duration(days:1)),
         firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+5));
        if(chosen==null||!mounted)return;
        setState(()=>recurring[index]=r.copy(active:true,startAt:chosen,day:chosen.day));
       }else{
        setState(()=>recurring[index]=r.copy(active:false));
       }
       if(!await _persistModuleOrReload(
        WaffraFinanceRoute.recurringCreateEditDeleteRestore,
        operation:'recurring-active-toggle'))return;
       if(enabled)await applyRecurring();
       await syncRecurringReminders();
      })),
      PopupMenuButton<String>(onSelected:WaffraHaptics.selection((v)async {
       if(v!='delete')return;
       final hasHistory=entries.any((e)=>e.id.startsWith('rec_${r.id}_'));
       final ok=await confirmDeletion(waffraIsEnglish?'Delete recurring transaction?':'حذف العملية المتكررة',
        waffraRecurringDeleteWarning(r.title,hasHistory,waffraIsEnglish));
       if(ok==true&&mounted){
        if(_lastFinanceAuthorityRead?.source==
           WaffraRuntimeFinanceBackend.verifiedEncrypted){
         await _deleteVerifiedModule(
          module:WaffraFinanceModule.recurring,displayed:r.toJson());
         return;
        }
        setState((){
         deletedRecurring.add({'recurring':r.toJson(),'deletedAt':DateTime.now().toIso8601String()});
         recurring.removeWhere((e)=>e.id==r.id);
         recurringPostponed.removeWhere((key,value)=>key.startsWith('rec_${r.id}_'));
        });
        if(!await _persistModuleOrReload(
         WaffraFinanceRoute.recurringCreateEditDeleteRestore,
         operation:'recurring-delete'))return;
        await syncRecurringReminders();
       }
      }),itemBuilder:(_)=>[
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

     // Empty state keeps the shared left + available.
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
     CalendarDatePicker(key:ValueKey('recurring-calendar-'+selected.toIso8601String()),initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100),
      onDateChanged:(date)=>refresh(()=>selected=date)),
     if(!waffraCalendarIsToday(selected))
      Align(alignment:AlignmentDirectional.centerEnd,child:TextButton.icon(
       key:const Key('waffra-recurring-calendar-today'),
       onPressed:WaffraHaptics.tap(()=>refresh(()=>selected=DateUtils.dateOnly(DateTime.now()))),
       icon:const Icon(Icons.today_rounded,size:17),
       label:WaffraText(waffraIsEnglish?'Today':'اليوم'))),
     const Divider(),
     Expanded(child:ListView(children:monthEvents.map((r){
      final due=WaffraRecurringPolicy.dueDate(selected.year,selected.month,r.day);
      final id=WaffraRecurringPolicy.entryId(r.id,due);
      final paid=entries.any((e)=>e.id==id);
      final postponed=DateTime.tryParse(recurringPostponed[id]??'');
      return ListTile(dense:true,leading:Icon(paid?Icons.check_circle:Icons.schedule,color:paid?emerald:Colors.orange),
       title:WaffraText(r.title),subtitle:WaffraText('${dayText(postponed??due)} • ${paid?(waffraIsEnglish?'Paid':'مدفوعة'):(waffraIsEnglish?'Pending':'معلقة')}'),trailing:WaffraText(cash(r.amount)));
     }).toList()))])),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
  }));
 }
 String exportBackup({WaffraFinanceAuthorityRead? fromSource}) {
  // A real backup must reflect a single immutable, verified finance source,
  // not a cached Home list after a simultaneous Android widget save.
  final finance=fromSource?.finance;
  Object listValue(String key,Object fallback)=>
   finance==null?fallback:jsonDecode(finance.getString(key)??'[]');
  Object mapValue(String key,Object fallback)=>
   finance==null?fallback:jsonDecode(finance.getString(key)??'{}');
  final sourceBudget=finance?.getDouble('waffra_monthly_budget_v1')??0;
  final payload={
   'format':'waffra-backup','version':24,
   'exportedAt':DateTime.now().toIso8601String(),
   'entries':listValue('entries',entries.map((e)=>e.toJson()).toList()),
   'categories':listValue('waffra_categories_v24',categories.map((e)=>e.toJson()).toList()),
   'goals':listValue('waffra_goals_v24',goals.map((e)=>e.toJson()).toList()),
   'recurring':listValue('waffra_recurring_v24',recurring.map((e)=>e.toJson()).toList()),
   'challenges':listValue('waffra_challenges_v1',challenges.map((e)=>e.toJson()).toList()),
   'deletedCategories':listValue('waffra_deleted_categories_v1',deletedCategories),
   'deletedGoals':listValue('waffra_deleted_goals_v1',deletedGoals),
   'deletedRecurring':listValue('waffra_deleted_recurring_v1',deletedRecurring),
   'recurringPostponed':mapValue('waffra_recurring_postponed_v1',recurringPostponed),
   'monthlyBudget':finance==null?monthlyBudget:sourceBudget,
   'monthlyBudgetEnabled':finance==null?monthlyBudgetEnabled:
    (finance.getBool('waffra_monthly_budget_enabled_v1')??(sourceBudget>0)),
   'learnedMerchants':mapValue('waffra_learned_merchants_v1',learnedMerchantCategories),
   'smsHashes':(List<String>.from(
    finance?.getStringList('waffra_sms_hashes_v1')??smsHashes.toList())..sort()),
   'profile':widget.profile.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
 }
 Future<bool> _authorizeSensitiveAction(String operation)async{
  if(!await WaffraBiometrics.isAvailable()){
   if(mounted)await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Fingerprint required':'بصمة الجهاز مطلوبة'),
    content:WaffraText(waffraIsEnglish?'Enable fingerprint in phone settings before $operation. App PIN cannot replace it.':'يجب تسجيل بصمة على هاتفك أولاً لحماية هذه العملية. لن يسمح وفرة باستخدام رمز التطبيق بدلاً منها.'),
    actions:[OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
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
  await _ensureFinanceBound();
  final secret=TextEditingController(),restoreSecret=TextEditingController();
  String? stagedBackup,backupError,restoreError,restorePasswordError;
  var attempted=false,restoring=false,exporting=false;
  int? mode;
  bool advanced=false;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Secure backup':'نسختك الاحتياطية الآمنة',
    style:const TextStyle(fontWeight:FontWeight.bold)),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    WaffraText(waffraIsEnglish?'Your data. Your password.':
     'بياناتك محفوظة بتشفير قوي. أنت وحدك تملك كلمة المرور.',
      textAlign:TextAlign.center),
    const SizedBox(height:15),
    if(mode==null)...[
     OutlinedButton.icon(key:const Key('waffra-backup-choose-export'),
      onPressed:WaffraHaptics.tap(()=>update(()=>mode=0)),
      icon:const Icon(Icons.file_download_rounded),
      label:WaffraText(waffraIsEnglish?'Save encrypted backup':'حفظ نسخة مشفّرة')),
     const SizedBox(height:10),
     OutlinedButton.icon(key:const Key('waffra-backup-choose-restore'),
      onPressed:WaffraHaptics.tap(()=>update(()=>mode=1)),
      icon:const Icon(Icons.restore_page_outlined),
      label:WaffraText(waffraIsEnglish?'Restore from my device':'استعادة من الجهاز')),
     const SizedBox(height:8),
     Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.lock_outline,color:Colors.grey,size:15),
      const SizedBox(width:5),
      Flexible(child:WaffraText(waffraIsEnglish?'Encrypted • No bank connection':
       'مشفّرة • بدون ربط بالحسابات البنكية',style:const TextStyle(fontSize:11))),
     ]),
    ]else ...[
     TextButton.icon(onPressed:WaffraHaptics.tap(()=>update(()=>mode=null)),
      icon:const Icon(Icons.arrow_back_ios_new_rounded,size:14),
      label:WaffraText(waffraIsEnglish?'Back':'رجوع')),
    ],
    if(mode==0)...[
    const SizedBox(height:10),
    TextField(key:const Key('waffra-new-backup-password'),controller:secret,obscureText:true,
     inputFormatters:[LengthLimitingTextInputFormatter(256)],
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Backup password (12+ characters) *':'كلمة مرور النسخة (12 حرفًا على الأقل) *',
      errorText:backupError,errorMaxLines:3,border:const OutlineInputBorder())),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:WaffraHaptics.tap(exporting?null:()async {
     if(!WaffraSecureBackup.isValidNewPassword(secret.text)){
      update(()=>backupError=waffraIsEnglish?'Use 12 to 256 characters for your backup password.':
       'استخدم كلمة مرور من 12 إلى 256 حرفًا للنسخة الاحتياطية.');return;
     }
     update(()=>exporting=true);
     try{
      // Drain in-process saves, then snapshot the latest authoritative
      // finance after any standalone Widget commit under the shared lock.
      await _financialWriteQueue.drain();
      final current=await _financeAuthority.load(
       route:WaffraFinanceRoute.backupExport);
      final authoritativePayload=exportBackup(fromSource:current);
      final encrypted=await compute(waffraEncryptBackupInIsolate,<String,String>{
       'payload':authoritativePayload,'password':secret.text,
      });
      // Persist the encrypted archive only after system document picker confirms.
      // Never copy it to the system clipboard on export.
      final saved=await WaffraBackupFiles.saveEncryptedArchive(encrypted);
      if(!saved)return;
      final generatedAt=DateTime.now().toIso8601String();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('waffra_backup_last_exported_v1',generatedAt);
      await prefs.setInt('waffra_backup_last_size_v1',utf8.encode(encrypted).length);
      if(mounted)setState((){lastBackupGeneratedAt=generatedAt;lastBackupBytes=utf8.encode(encrypted).length;});
      if(ctx.mounted)snackSuccess(ctx,waffraIsEnglish?
       'Encrypted .waffra backup file saved. Keep its password safe.':
       'تم حفظ ملف .waffra المشفّر بنجاح. احتفظ بكلمة المرور بأمان.');
     }catch(_){
      if(ctx.mounted)update(()=>backupError=waffraIsEnglish?
       'Could not save encrypted backup file. Please retry.':
       'تعذر حفظ ملف النسخة الاحتياطية المشفّر. حاول مرة أخرى.');
     }finally{
      if(ctx.mounted)update(()=>exporting=false);
     }
    }),icon:const Icon(Icons.file_download_outlined),label:WaffraText(waffraIsEnglish?
      'Save encrypted .waffra file':'حفظ ملف .waffra المشفّر')),
    ],
    if(mode==1)...[
    const SizedBox(height:10),
    WaffraText(waffraIsEnglish?'Select a Waffra file, then enter its password.':
     'اختر ملف وفرة، ثم أدخل كلمة مروره.',textAlign:TextAlign.center),
    const SizedBox(height:10),
    WaffraText(waffraIsEnglish?'Restore an encrypted backup file':'استعادة ملف نسخة احتياطية مشفّر',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:10),
    TextField(controller:restoreSecret,key:const Key('waffra-existing-backup-password'),
     obscureText:true,
     inputFormatters:[LengthLimitingTextInputFormatter(256)],
     onChanged:(_)=>update(()=>restorePasswordError=null),
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Backup password *':'كلمة مرور النسخة *',
      errorText:restorePasswordError,errorMaxLines:3,
      border:const OutlineInputBorder())),
    const SizedBox(height:10),
    // Select previously exported archives with Android's SAF document picker.
    // Contents remain hidden and are never copied to the clipboard on export.
    OutlinedButton.icon(key:const Key('waffra-open-backup-file'),
     onPressed:WaffraHaptics.tap(restoring?null:()async{
      try{
       final selected=await WaffraBackupFiles.openArchive();
       if(!ctx.mounted||selected==null)return;
       update((){
        stagedBackup=selected;
        restoreError=null;
        attempted=false;
       });
      }catch(_){
       if(ctx.mounted)update(()=>restoreError=waffraIsEnglish?
        'File verification failed. Please choose a valid Waffra backup.':
        'فشل التحقق من صحة الملف. يرجى اختيار نسخة احتياطية صحيحة من وفرة والمحاولة مرة أخرى.');
      }
     }),icon:const Icon(Icons.file_open_outlined),
     label:WaffraText(waffraIsEnglish?'Choose .waffra file':'اختيار ملف .waffra من الجهاز')),
    // Backward compatibility ONLY: opt-in reading of previously exported
    // clipboard-only text. New exports never put archive data on clipboard.
    TextButton.icon(onPressed:WaffraHaptics.tap(()=>update(()=>advanced=!advanced)),
     icon:Icon(advanced?Icons.expand_less:Icons.expand_more),
     label:WaffraText(waffraIsEnglish?'Advanced options':'خيارات متقدمة')),
    if(advanced)TextButton.icon(key:const Key('waffra-import-legacy-text'),
     onPressed:WaffraHaptics.tap(restoring?null:()async{
      final old=await Clipboard.getData(Clipboard.kTextPlain);
      if(!ctx.mounted)return;
      final text=old?.text?.trim()??'';
      if(text.isEmpty||text.length>WaffraBackupFiles.maxArchiveBytes){
       update(()=>restoreError=waffraIsEnglish?
        'No valid older backup text in clipboard.':
        'لا يوجد نص نسخة احتياطية قديمة صالح في الحافظة.');
       return;
      }
      update((){
       stagedBackup=text;
       restoreError=null;
       attempted=false;
      });
     }),icon:const Icon(Icons.history_outlined,size:18),
     label:WaffraText(waffraIsEnglish?
      'Import older copied backup (legacy)':'استيراد نسخة نصية قديمة (للتوافق فقط)')),
    if(stagedBackup!=null)...[
     const SizedBox(height:8),
     ListTile(dense:true,leading:const Icon(Icons.check_circle_outline,color:Colors.green),
      title:WaffraText(waffraIsEnglish?'Backup file loaded. Ready to verify.':'تم تحميل النسخة الاحتياطية وجاهزة للتحقق.'),
      trailing:IconButton(icon:const Icon(Icons.close),
       tooltip:waffraIsEnglish?'Clear backup':'إزالة النسخة الملصوقة',
       onPressed:WaffraHaptics.tap(restoring?null:()=>update((){
        stagedBackup=null;restoreError=null;attempted=false;
       })))),
    ],
    if(attempted&&stagedBackup==null)
     WaffraText(restoreError??(waffraIsEnglish?'Choose a backup file first.':'اختر ملف نسخة احتياطية أولًا.'),
      style:const TextStyle(color:Colors.red)),
    if(restoreError!=null&&stagedBackup!=null)
     WaffraText(restoreError!,style:const TextStyle(color:Colors.red)),
    if(restoring)const LinearProgressIndicator(),
    ],
   ])),
   actions:[
    TextButton(onPressed:WaffraHaptics.tap(restoring?null:()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Close':'إغلاق')),
    if(mode==1)FilledButton(key:const Key('waffra-confirm-backup-restore'),
     onPressed:WaffraHaptics.tap(restoring?null:()async {
     update(()=>attempted=true);
     if(restoreSecret.text.isEmpty){
      update(()=>restorePasswordError=waffraIsEnglish?
       'Enter the original backup password.':'أدخل كلمة مرور النسخة الأصلية.');
      return;
     }
     if(stagedBackup==null||stagedBackup!.isEmpty)return;
     update(()=>restoring=true);
     try{
      final raw=await compute(waffraDecodeBackupInIsolate,<String,String>{
       'payload':stagedBackup!,'password':restoreSecret.text,
      });
      if(raw['format']!='waffra-backup'||raw['entries'] is! List||
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
      // Build the complete restored finance image without mutating Home
      // state. A rejected source witness or interrupted writer must NOT
      // show transactions that were never durably committed.
      final hashesPayload=raw['smsHashes'];
      if(hashesPayload!=null&&(hashesPayload is! List||
        hashesPayload.length>100000||
        hashesPayload.any((value)=>value is! String||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)))){
       throw const FormatException('Invalid restored SMS fingerprints');
      }
      final restoredHashes=<String>{...?((hashesPayload as List?)?.cast<String>())};
      final restoredBudgetEnabled=raw['monthlyBudgetEnabled'] is bool?
       raw['monthlyBudgetEnabled'] as bool:restoredBudget>0;
      final restoreSnapshot=<String,Object>{
       'entries':jsonEncode(newEntries.map((e)=>e.toJson()).toList()),
       'waffra_categories_v24':jsonEncode(newCategories.map((e)=>e.toJson()).toList()),
       'waffra_goals_v24':jsonEncode(newGoals.map((e)=>e.toJson()).toList()),
       'waffra_recurring_v24':jsonEncode(newRecurring.map((e)=>e.toJson()).toList()),
       'waffra_challenges_v1':jsonEncode(newChallenges.map((e)=>e.toJson()).toList()),
       'waffra_deleted_categories_v1':jsonEncode(newTrash),
       'waffra_deleted_goals_v1':jsonEncode(newDeletedGoals),
       'waffra_deleted_recurring_v1':jsonEncode(newDeletedRecurring),
       'waffra_recurring_postponed_v1':jsonEncode(newPostponed),
       'waffra_monthly_budget_v1':restoredBudget,
       'waffra_monthly_budget_enabled_v1':restoredBudgetEnabled,
       'waffra_learned_merchants_v1':jsonEncode(restoredRules),
       'waffra_sms_hashes_v1':restoredHashes.toList()..sort(),
      };
      // Re-read the latest authority inside the Home write queue. Both
      // backends MUST pass source selection before a single journaled
      // legacy batch / verified SQLCipher transaction is accepted.
      // The SQLCipher bridge currently rejects backupRestore rather than
      // falling back to plaintext until encrypted restore is certified.
      await _financialWriteQueue.submit(restoreSnapshot,(captured)async{
       final baseline=await _financeAuthority.load(
        route:WaffraFinanceRoute.backupRestore);
       final committed=await _financeAuthority.saveCaptured(
        route:WaffraFinanceRoute.backupRestore,
        baseline:baseline,captured:captured);
       _lastFinanceAuthorityRead=committed;
       _lastLedgerSavedRaw=committed.ledgerRaw;
       _lastWidgetRevision=committed.widgetRevision;
      });
      if(!mounted)return;
      // Only publish the restored view after the source reports a durable
      // commit. Never optimistically replace in-memory money on error.
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
       monthlyBudgetEnabled=restoredBudgetEnabled;
       learnedMerchantCategories..clear()..addAll(restoredRules);
       smsHashes..clear()..addAll(restoredHashes);
      });
      unawaited(_refreshWidget());
      await syncRecurringReminders();
      if(ctx.mounted)Navigator.pop(ctx);
      if(mounted)snackSuccess(context,'تمت استعادة البيانات بنجاح');
     }catch(e){
      if(ctx.mounted)update(()=>restoreError=waffraIsEnglish?
       'Restore failed. Check the original password and complete backup.':
       'فشلت الاستعادة. تأكد من كلمة المرور الأصلية واكتمال النسخة.');
     }finally{
      if(ctx.mounted)update(()=>restoring=false);
     }
    }),child:WaffraText(waffraIsEnglish?'Restore':'استعادة')),
   ])));
  disposeLater([secret,restoreSecret]);
 }
 // System credentials are never saved in plain text. A new PIN must be
 // entered twice; keep support for checking older 4-8-digit PINs on disable.
 Future<String?> _askForPin({
  required String title,required String fieldLabel,bool existing=false,
  bool autoAdvance=false,bool Function(String)? verify,String? verifyError,
 })async{
  final input=TextEditingController();
  var attempted=false;String? fieldError;
  try{
   return await showWaffraDialog<String>(context:context,
    builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,update)=>
     Theme(data:Theme.of(dialogContext).copyWith(brightness:Brightness.dark,
      colorScheme:ColorScheme.fromSeed(seedColor:emerald,brightness:Brightness.dark)),
      child:AlertDialog(
       backgroundColor:forest,
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
        side:waffraDialogOutline(Brightness.dark)),
       title:Column(mainAxisSize:MainAxisSize.min,children:[
        const CircleAvatar(radius:26,backgroundColor:emerald,
         child:Icon(Icons.lock_outline,color:Colors.white,size:28)),
        const SizedBox(height:12),
        WaffraText(title,textAlign:TextAlign.center,
         style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
       ]),
       content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
         WaffraText(fieldLabel,textAlign:TextAlign.center,
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),
         const SizedBox(height:12),
         // In-app digits-only keypad avoids Samsung's punctuation keyboard.
         TextField(key:const Key('waffra-pin-input'),controller:input,
          autofocus:false,readOnly:true,showCursor:false,
          enableInteractiveSelection:false,
          textDirection:TextDirection.ltr,textAlign:TextAlign.center,
          keyboardType:TextInputType.number,
          inputFormatters:[FilteringTextInputFormatter.digitsOnly,
           LengthLimitingTextInputFormatter(existing?8:4)],
          obscureText:true,
          style:const TextStyle(color:Color(0xFF12382D),fontWeight:FontWeight.bold),
          decoration:InputDecoration(
           filled:true,fillColor:Colors.white,
           hintText:'••••',hintStyle:const TextStyle(color:Colors.black38),
           errorText:fieldError??
            (attempted?waffraPinFieldError(input.text,existing:existing):null),
           errorMaxLines:3,
           border:const OutlineInputBorder())),
         const SizedBox(height:10),
         for(final keys in const <List<String>>[
          ['1','2','3'],['4','5','6'],['7','8','9'],['','0','back']
         ])Padding(padding:const EdgeInsets.only(bottom:5),child:Row(textDirection:TextDirection.ltr,
          children:[for(final digit in keys)Expanded(child:Padding(
           padding:const EdgeInsets.symmetric(horizontal:3),
           child:digit.isEmpty?const SizedBox(height:42):OutlinedButton(
            key:Key('waffra-pin-key-$digit'),
            style:OutlinedButton.styleFrom(
             minimumSize:const Size(0,42),
             padding:EdgeInsets.zero,foregroundColor:Colors.white,
             side:BorderSide(color:Colors.white.withValues(alpha:.23)),
             shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
            onPressed:WaffraHaptics.tap((){
             if(digit=='back'){
              if(input.text.isEmpty)return;
              input.text=input.text.substring(0,input.text.length-1);
              update(()=>fieldError=null);
              return;
             }
             if(input.text.length>=(existing?8:4))return;
             final value=input.text+digit;
             input.text=value;
             update(()=>fieldError=null);
             if(autoAdvance&&value.length==4&&waffraPinFieldError(value)==null){
              WidgetsBinding.instance.addPostFrameCallback((_){
               if(dialogContext.mounted&&input.text==value){
                Navigator.pop(dialogContext,value);
               }
              });
             }
            }),
            child:digit=='back'
             ?const Icon(Icons.backspace_outlined,size:20)
             :Text(digit,style:const TextStyle(fontFamily:'Tajawal',
               fontSize:19,fontWeight:FontWeight.bold))),
          ))])),
        ])),
       actions:[
        TextButton(
         style:TextButton.styleFrom(foregroundColor:Colors.white,
          backgroundColor:Colors.white.withValues(alpha:.12)),
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext)),
         child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        if(!autoAdvance)FilledButton(
         style:FilledButton.styleFrom(backgroundColor:emerald,
          foregroundColor:Colors.white),
         onPressed:WaffraHaptics.tap((){
          final code=input.text.trim();
          update(()=>attempted=true);
          if(waffraPinFieldError(code,existing:existing)!=null)return;
          if(verify!=null&&!verify(code)){
           update(()=>fieldError=verifyError??
            (waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح'));
           return;
          }
          Navigator.pop(dialogContext,code);
         }),
         child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
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
   fieldLabel:waffraIsEnglish?'Enter a 4-digit PIN':'أدخل رمز القفل من 4 أرقام',
    autoAdvance:true);
  if(firstPin==null||!mounted)return;
  while(mounted){
   final repeated=await _askForPin(
    title:waffraIsEnglish?'Confirm PIN':'تأكيد رمز القفل',
    fieldLabel:waffraIsEnglish?'Re-enter the same 4 digits':'أدخل رمز القفل المكوّن من 4 أرقام مرة ثانية',
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
  final expectedStep=tourStep,expectedTab=tab;
  WidgetsBinding.instance.addPostFrameCallback((_)async {
   if(!mounted||!tourActive||tourStep!=expectedStep||tab!=expectedTab)return;
   // Reset lazily built list pages before focusing a possibly recycled
   // sliver header (e.g. Home balance after scrolling down).
   final ScrollController? pageScroll=switch(expectedTab){
    0=>_dashboardScrollController,
    1=>_categoryScrollController,
    3=>_goalsScrollController,
    4=>_recurringScrollController,
    _=>null,
   };
   if(pageScroll!=null&&pageScroll.hasClients&&pageScroll.offset!=0){
    pageScroll.jumpTo(0);
   }
   BuildContext? focus=tourTargetKeys[expectedStep]<0?null:
    _tourKeys[tourTargetKeys[expectedStep]].currentContext;
   // The selected tab is built lazily, so allow the next animation frame
   // to mount its heading before calculating the coach-mark target.
   if(focus==null&&expectedStep>0){
    await Future<void>.delayed(waffraMotion(120));
    if(!mounted||!tourActive||tourStep!=expectedStep||tab!=expectedTab)return;
    focus=_tourKeys[tourTargetKeys[expectedStep]].currentContext;
   }
   if(focus!=null){
    try{await Scrollable.ensureVisible(focus,
     duration:waffraMotion(250),alignment:.16,
     curve:Curves.easeOutCubic);}catch(e){debugPrint('Tour focus: $e');}
   }
   await Future<void>.delayed(waffraMotion(120));
   if(mounted&&tourActive&&tourStep==expectedStep&&tab==expectedTab){
    // Keep controls accessible even if a lazy child is momentarily absent.
    setState(()=>tourTargetReady=true);
   }
  });
 }
 Future<void> completeTour()async {
  _tourGlow.stop();
  if(mounted)setState((){tourActive=false;tourTargetReady=false;addFabExpanded=false;tab=0;goalsOpened=false;});
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_in_app_tour_seen_v2',true);
 }
 void beginTour(){
  setState((){tourStep=0;tourActive=true;tourTargetReady=false;tab=0;accountOpened=false;_headerCompact=false;goalsOpened=false;addFabExpanded=false;});
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
  const ar=WaffraTourPlan.titlesAr;
  const en=WaffraTourPlan.titlesEn;
  const arHelp=WaffraTourPlan.helpAr;
  const enHelp=WaffraTourPlan.helpEn;
  final element=tourTargetKeys[tourStep]<0?null:_tourKeys[tourTargetKeys[tourStep]].currentContext?.findRenderObject();
  final layer=overlayCtx.findRenderObject();
  // Intro doesn't spotlight the header; its first card is centered.
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
  final headingFocus=tourStep>=3;
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
        TextButton(onPressed:WaffraHaptics.tap(completeTour),child:WaffraText(waffraIsEnglish?'Skip':'تخطي')),
        if(tourStep>0)TextButton(onPressed:WaffraHaptics.tap(previousTour),
         child:WaffraText(waffraIsEnglish?'Back':'السابق')),
        FilledButton(onPressed:WaffraHaptics.tap(advanceTour),
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
 Future<void> deleteAiModel()async {
  final model=WaffraOnDeviceQwen.shared;
  final installed=await model.downloadedOnDisk();
  if(!mounted)return;
  if(!installed&&!model.isReady){
   snack(context,waffraIsEnglish?
    'The AI model is not downloaded. No files need deleting.':
    'نموذج الذكاء الاصطناعي غير منزّل حاليًا.');
   return;
  }
  // Warn BEFORE requesting the operating-system biometric prompt.
  final approved=await confirmDeletion(
   waffraIsEnglish?'Delete the AI model from this phone?':
    'حذف نموذج الذكاء الاصطناعي من الجهاز؟',
   waffraIsEnglish?
    'This will delete the downloaded model (about 484 MB). You will lose '
    'Bank-message importing and image OCR scanning, Ask Waffra, AI financial '
    'analysis and AI saving suggestions until you download it again. '
    'Your saved transactions, invoices, backups and regular tools will NOT be deleted.':
    'سيتم حذف نموذج الذكاء الاصطناعي الذي تم تنزيله (حوالي 484 ميجابايت). '
    'بعد الحذف مش هتقدر تستخدم الرسائل البنكية أو OCR للفواتير والصور، '
    'واسأل وفرة، والتحليل المالي الذكي واقتراحات التوفير، لحد ما تنزّله تاني. '
    'معاملاتك وفواتيرك ونسخك الاحتياطية والأدوات العادية مش هتتحذف.');
  if(approved!=true||!mounted)return;
  // No PIN shortcut; a failed, missing or cancelled phone biometric
  // confirmation always refuses model-file deletion.
  final biometric=await WaffraBiometrics.confirmAiModelRemoval(
   english:waffraIsEnglish);
  if(!mounted)return;
  if(!biometric){
   snack(context,waffraIsEnglish?
    'Biometric confirmation was not completed. The AI model was not deleted.':
    'لم يتم تأكيد البصمة. نموذج الذكاء الاصطناعي لم يُحذف.');
   return;
  }
  try{
   await model.deleteDownloadedModel();
   if(!mounted)return;
   setState((){});
   snackSuccess(context,waffraIsEnglish?
    'AI model deleted. Standard Waffra and your finance data are unchanged.':
    'تم حذف نموذج الذكاء الاصطناعي. بياناتك المالية والأدوات العادية كما هي.');
  }catch(error){
   debugPrint('Local AI model removal could not be verified: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Could not confirm model removal. Please retry from My Account.':
    'تعذر التأكد من حذف النموذج. حاول مرة أخرى من حسابي.');
  }
 }

 Future<void> eraseFinancialData()async {
  if(!await _authorizeSensitiveAction('deleting financial data')||!mounted)return;
  final ok=await confirmDeletion(
   waffraIsEnglish?'Permanently delete financial data?':'حذف البيانات المالية نهائيًا',
   waffraIsEnglish?'This deletes transactions, categories, budgets, goals and recurring schedules. It cannot be undone. Your profile and app settings stay.':
    'سيتم حذف المعاملات والأقسام والميزانيات والأهداف والجدولة المتكررة نهائيًا. لا يمكن التراجع. سيبقى الملف الشخصي وإعدادات التطبيق.');
  if(ok!=true||!mounted)return;
  final cleanCategories=defaultCategories();
  // Every recognized financial field is reset through ONE crash-recoverable
  // journal. SMS hashes must NOT be cleared independently before finance
  // persistence, and non-finance profile/app settings must remain intact.
  final clean=<String,Object>{
   'entries':'[]',
   'waffra_categories_v24':jsonEncode(cleanCategories.map((e)=>e.toJson()).toList()),
   'waffra_goals_v24':'[]',
   'waffra_recurring_v24':'[]',
   'waffra_challenges_v1':'[]',
   'waffra_deleted_categories_v1':'[]',
   'waffra_deleted_goals_v1':'[]',
   'waffra_deleted_recurring_v1':'[]',
   'waffra_recurring_postponed_v1':'{}',
   'waffra_monthly_budget_v1':0.0,
   'waffra_monthly_budget_enabled_v1':false,
   'waffra_learned_merchants_v1':'{}',
   'waffra_sms_hashes_v1':<String>[],
   'waffra_recurring_reminders_enabled_v1':false,
  };
  try{
   final baseline=_lastFinanceAuthorityRead;
   await _financialWriteQueue.submit(clean,(captured)async{
    if(baseline==null)throw StateError('Finance reset source baseline unavailable.');
    final committed=await _financeAuthority.saveCaptured(
     route:WaffraFinanceRoute.fullFinanceReset,
     baseline:baseline,captured:captured,
    );
    _lastFinanceAuthorityRead=committed;
    _lastLedgerSavedRaw=committed.ledgerRaw;
    _lastWidgetRevision=committed.widgetRevision;
   });
   if(!mounted)return;
   setState((){
    entries.clear();
    categories..clear()..addAll(cleanCategories);
    goals.clear();challenges.clear();recurring.clear();
    deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();
    recurringPostponed.clear();smsHashes.clear();learnedMerchantCategories.clear();
    monthlyBudget=0;monthlyBudgetEnabled=false;recurringRemindersEnabled=false;
   });
   unawaited(_refreshWidget());
   try{await WaffraReminders.clear();}catch(e){
    debugPrint('Could not clear old recurring reminders: $e');
   }
   if(mounted)snackSuccess(context,waffraIsEnglish?'Financial data deleted':'تم حذف البيانات المالية');
  }catch(e){
   debugPrint('Financial erase was not fully confirmed: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be verified. Reload before retrying.':
    'تعذر تأكيد حذف البيانات. أعد التحميل قبل المحاولة مجددًا.');
  }
 }
 Widget _accountTile(String label,String subtitle,IconData icon,{VoidCallback? onTap,Widget? trailing,Color tint=emerald})=>
  ListTile(
   leading:CircleAvatar(backgroundColor:tint.withValues(alpha:.12),child:Icon(icon,color:tint,size:21)),
   title:WaffraText(label,style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),
   trailing:trailing??(onTap==null?null:const Icon(Icons.chevron_left)),onTap:WaffraHaptics.tap(onTap));
 Widget _accountSection(String heading,IconData icon,List<Widget> children) {
  final q=accountSearch.trim().toLowerCase();
  if(q.isNotEmpty&&_accountOpenSection!=heading)return const SizedBox.shrink();
  final opened=_accountOpenSection==heading;
  final dim=Theme.of(context).brightness==Brightness.dark;
  return Card(margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(20),
   side:BorderSide(color:dim?const Color(0xFF456855):const Color(0xFFDCEAE1))),
   child:Column(children:[
    InkWell(onTap:WaffraHaptics.tap(()=>setState(()=>_accountOpenSection=opened?null:heading)),
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
 // The third footer tab owns the tool accordion. Finance is read-only:
 // freeze verified snapshots and never read original SMS or modify the ledger.
 Widget _smartToolsTab(){
  if(!ready||_financeBinding==null||_lastFinanceAuthorityRead==null){
   return Center(child:WaffraText(waffraIsEnglish?
    'Financial source not ready':'مصدر البيانات المالية غير جاهز'));
  }
  return WaffraSmartFeaturesPage(
   key:const Key('waffra-m268-footer-page'),
   tourHeadingKey:_tourKeys[3],
   embedded:true,english:waffraIsEnglish,
   onNotice:(message)=>snack(context,message),
   analysisBuilder:(_)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[smartAnalysisEntryCard(),const SizedBox(height:10),smartMoneyInsightsCard()]),
   entries:List<WaffraSmartEntry>.unmodifiable(entries.map((e)=>WaffraSmartEntry(
    id:e.id,title:e.title,category:e.category,amount:e.amount,
    income:e.income,date:e.date,notes:e.notes,
    hasAttachment:e.receiptPath?.isNotEmpty??false))),
   goals:List<WaffraSmartGoal>.unmodifiable(goals.map((g)=>
    WaffraSmartGoal(g.name,g.target,g.saved))),
   recurring:List<WaffraSmartRecurring>.unmodifiable(recurring.where((r)=>r.active).map((r)=>
    WaffraSmartRecurring(r.title,r.amount,r.day,r.income))),
  );
 }
 void openSmartFeatures(){
  if(!ready||_financeBinding==null||_lastFinanceAuthorityRead==null){
   snack(context,waffraIsEnglish?'Financial source not ready':'مصدر البيانات المالية غير جاهز');
   return;
  }
  unawaited(selectFooter(2));
 }
 void openFinancialCalendar()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraFinancialCalendar(items:financialCalendarItems,english:waffraIsEnglish)));
 void openSubscriptionInsights()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraSubscriptionScreen(
   items:financialCalendarItems,english:waffraIsEnglish,
   onAddRecurring:(candidate)=>recurringDialog(
    suggestedTitle:candidate.title,suggestedAmount:candidate.estimatedMonthly))));
 Future<void> chooseAppCurrency()async{
  final searchController=TextEditingController();
  String query='';
  try{
   final chosen=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
     final visible=waffraCountryCurrencies.where((country)=>
      waffraSearchAny([country.countryAr,country.countryEn,country.nameAr,
       country.nameEn,country.code],query)).toList();
     return AlertDialog(
      title:WaffraText(waffraIsEnglish?'Application currency':'العملة الأساسية للتطبيق'),
      content:SizedBox(width:420,height:410,child:Column(children:[
       TextField(key:const Key('waffra-country-currency-search'),
        controller:searchController,autofocus:true,
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
         hintText:waffraIsEnglish?'Find country or currency':'ابحث عن دولة أو عملة'),
        onChanged:(v)=>update(()=>query=v)),
       const SizedBox(height:9),
       Expanded(child:ListView.builder(itemCount:visible.length,
        itemBuilder:(context,index){
         final option=visible[index];
         return ListTile(
          key:Key('waffra-country-currency-${option.code}'),
          selected:WaffraDisplayCurrency.country.code==option.code,
          leading:Text(waffraCurrencyFlag(option.code),
           style:const TextStyle(fontSize:27)),
          title:WaffraText(option.label(waffraIsEnglish)),
          trailing:WaffraDisplayCurrency.country.code==option.code?
           const Icon(Icons.check_circle,color:emerald):null,
          onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,option.code)));
        })),
      ])),
      actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
     );
    }));
   if(chosen==null||!mounted)return;
   try{
    await WaffraDisplayCurrency.setCurrency(chosen);
    if(!mounted)return;
    setState((){});
    await _refreshWidget();
    if(mounted)snackSuccess(context,waffraIsEnglish?
      'Display currency changed; numbers stay exactly the same.':
      'تم تغيير عملة العرض مع الحفاظ على قيمة الأرقام كما هي.');
   }catch(error){
    debugPrint('App country currency rejected safely: $error');
    if(mounted)snack(context,waffraIsEnglish?
      'Could not save display currency; no financial amount was modified.':
      'تعذّر حفظ عملة العرض، ولم يتم تعديل أي مبلغ مالي.');
   }
  }finally{searchController.dispose();}
 }
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
     InkWell(onTap:WaffraHaptics.tap(edit),child:Stack(alignment:Alignment.bottomRight,children:[
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
   OutlinedButton.icon(onPressed:WaffraHaptics.tap(edit),icon:const Icon(Icons.edit_outlined),
    label:WaffraText(waffraIsEnglish?'Edit profile':'تعديل حسابي')),
    ])),
   const SizedBox(height:13),
   TextField(key:const Key('waffra-account-settings-search'),onChanged:(value){
    final q=value.trim();
    final groups=<String,String>{
     waffraIsEnglish?'App settings':'إعدادات التطبيق':'language theme appearance system dark light currency exchange بلد دولة عملة جنيه مصري مصر SAR EGP المظهر اللغة الحركة animation',
     waffraIsEnglish?'Security & privacy':'الأمان والخصوصية':'privacy biometric fingerprint حماية بصمة قفل إخفاء PIN screenshots المعاينة',
     waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات':'backup restore delete نسخ احتياطي استعادة حذف بيانات',
     waffraIsEnglish?'Financial tools':'الأدوات المالية':'calendar subscriptions currency tools التقويم الاشتراكات الأدوات المالية',
     waffraIsEnglish?'AI model':'نموذج الذكاء الاصطناعي':'Qwen AI download remove delete model fingerprint biometric نموذج مكتبة الذكاء الاصطناعي بصمة تنزيل تحميل حذف',
     waffraIsEnglish?'Help & about':'المساعدة وعن وفرة':'tour help about وفرة الجولة المساعدة',
    };
    String? match;
    if(q.isNotEmpty){for(final item in groups.entries){if(waffraSearchAny([item.key,item.value],q)){match=item.key;break;}}}
    setState((){accountSearch=q;_accountOpenSection=match;});
   },decoration:InputDecoration(prefixIcon:const Icon(Icons.search,color:emerald),
    hintText:waffraIsEnglish?'Find a setting':'ابحث داخل إعدادات حسابي')),
   const SizedBox(height:12),
   _accountSection(waffraIsEnglish?'App settings':'إعدادات التطبيق',Icons.settings_outlined,[
    ListTile(
     key:const Key('waffra-app-base-currency-setting'),
     leading:const CircleAvatar(child:Icon(Icons.public_rounded,color:emerald)),
     title:WaffraText(waffraIsEnglish?'App currency by country':'عملة التطبيق حسب الدولة'),
     subtitle:WaffraText(WaffraDisplayCurrency.country.label(waffraIsEnglish)),
     trailing:const Icon(Icons.search_rounded),
     onTap:WaffraHaptics.tap(chooseAppCurrency)),

    ListTile(
     leading:const CircleAvatar(child:Icon(Icons.auto_awesome_outlined,color:emerald)),
     title:WaffraText(waffraIsEnglish?'Animations & effects':'الحركة والتأثيرات',style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:WaffraText(waffraIsEnglish?'Choose motion intensity':'اختر مستوى الحركة في التطبيق'),
     trailing:DropdownButton<String>(value:waffraAnimationLevel.value,underline:const SizedBox.shrink(),
      onChanged:WaffraHaptics.selection((v){if(v!=null)setAnimationLevel(v);}),items:[
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
     onSelectionChanged:WaffraHaptics.selection((v)async{setState(()=>tab=0);await widget.onLanguage(v.first);}))),
    ListTile(
     key:const Key('waffra-regional-arabic-setting'),
     leading:const Icon(Icons.public_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Country / Arabic wording':'البلد واللهجة العربية'),
     subtitle:WaffraText(waffraIsEnglish?
      'Country only changes Arabic wording, not your app language or currency.':
      'اختيار البلد يحدد اللهجة العربية فقط، ولا يغيّر لغة التطبيق أو عملته.'),
     trailing:SizedBox(width:145,child:DropdownButton<String>(
      key:const Key('waffra-region-choice'),
      value:WaffraRegionalCopy.countryIso.value,isExpanded:true,
      underline:const SizedBox.shrink(),
      items:WaffraRegionalCopy.supportedRegions.entries.map((item)=>
       DropdownMenuItem<String>(value:item.key,
        child:Text(WaffraRegionalCopy.regionLabel(
          item.key,english:waffraIsEnglish),
          maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
      onChanged:WaffraHaptics.selection((v)async{
       if(v==null)return;
       try{
        await WaffraRegionalCopy.setCountry(v);
        if(mounted)setState((){});
       }catch(_){
        if(mounted)snack(context,waffraIsEnglish?
          'Could not save country preference. Please retry.':
          'ما قدرنا نحفظ اختيار البلد. جرّب مرة ثانية.');
       }
      }),
     )),
    ),
    ListTile(leading:const Icon(Icons.palette_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Appearance':'المظهر'),
     subtitle:WaffraText(widget.appearance=='system'?(waffraIsEnglish?'System default':'حسب إعدادات الجهاز'):
      widget.appearance=='dark'?(waffraIsEnglish?'Dark':'داكن'):(waffraIsEnglish?'Light':'فاتح')),
     trailing:DropdownButton<String>(value:widget.appearance,underline:const SizedBox.shrink(),
      onChanged:WaffraHaptics.selection((value){if(value!=null)widget.onAppearance(value);}),
      items:[
       DropdownMenuItem(value:'system',child:WaffraText(waffraIsEnglish?'System default':'حسب الجهاز')),
       DropdownMenuItem(value:'light',child:WaffraText(waffraIsEnglish?'Light':'فاتح')),
       DropdownMenuItem(value:'dark',child:WaffraText(waffraIsEnglish?'Dark':'داكن')),
      ])),
   ]),
   _accountSection(waffraIsEnglish?'Security & privacy':'الأمان والخصوصية',Icons.shield_outlined,[
    _accountTile(waffraIsEnglish?'PIN app lock':'قفل التطبيق برمز PIN',
     widget.pinEnabled?(waffraIsEnglish?'Enabled':'مفعّل'):(waffraIsEnglish?'Disabled':'غير مفعّل'),
     widget.pinEnabled?Icons.lock:Icons.lock_open,onTap:WaffraHaptics.tap(configurePin)),
    if(widget.pinEnabled)_accountTile(waffraIsEnglish?'Change PIN':'تغيير رمز PIN',
     waffraIsEnglish?'Update your lock code':'تحديث رمز القفل',
     Icons.password_outlined,onTap:WaffraHaptics.tap(changePin)),
    SwitchListTile(secondary:const Icon(Icons.preview_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Protect Recent Apps preview':'حماية معاينة التطبيقات الأخيرة'),
     value:protectRecentApps,onChanged:WaffraHaptics.selection(_setRecentAppProtection)),
    ValueListenableBuilder<bool>(valueListenable:allowWaffraScreenshots,
     builder:(context,allowed,_)=>SwitchListTile(
      secondary:const Icon(Icons.screenshot_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Allow screenshots':'السماح بلقطات الشاشة'),
      subtitle:WaffraText(allowed?(waffraIsEnglish?'Allowed':'مسموح'):(waffraIsEnglish?'Blocked':'ممنوع')),
      value:allowed,onChanged:WaffraHaptics.selection((v)async{await setWaffraScreenshotsAllowed(v);if(mounted)setState((){});}))),
     ValueListenableBuilder<bool>(
      valueListenable:WaffraCrashlyticsOptIn.consent,
      builder:(context,allowed,_)=>SwitchListTile(
       secondary:const Icon(Icons.bug_report_outlined,color:emerald),
       title:WaffraText(waffraIsEnglish?'Share anonymous crash diagnostics':'مشاركة بيانات الأعطال'),
       subtitle:WaffraText(!waffraCrashlyticsReviewed
        ?(waffraIsEnglish?'Available after privacy and release verification':'ستتوفر بعد التحقق من الأمان والخصوصية')
        :(waffraIsEnglish?'Optional and disabled until you agree':'اختياري ولن يعمل إلا بموافقتك')),
       value:allowed&&waffraCrashlyticsReviewed,
       onChanged:WaffraHaptics.selection(waffraCrashlyticsReviewed?(v)async{
        await WaffraCrashlyticsOptIn.setConsent(v);
       }:null))),
   ]),
   _accountSection(waffraIsEnglish?'Financial tools':'الأدوات المالية',Icons.account_balance_wallet_outlined,[
    _accountTile(waffraIsEnglish?'Financial calendar':'التقويم المالي',
     waffraIsEnglish?'Transactions and recurring dates':'المعاملات ومواعيد العمليات المتكررة',
     Icons.calendar_month_outlined,onTap:WaffraHaptics.tap(openFinancialCalendar)),
    _accountTile(waffraIsEnglish?'Subscription insights':'كشف الاشتراكات',
     waffraIsEnglish?'Recurring costs and possible subscriptions':'المدفوعات الدورية والاشتراكات المحتملة',
     Icons.subscriptions_outlined,onTap:WaffraHaptics.tap(openSubscriptionInsights)),
   ]),
   _accountSection(waffraIsEnglish?'AI model':'نموذج الذكاء الاصطناعي',
    Icons.psychology_outlined,[
    ValueListenableBuilder<int>(
     valueListenable:WaffraOnDeviceQwen.shared.revision,
     builder:(context,revision,_)=>FutureBuilder<bool>(
      future:WaffraOnDeviceQwen.shared.downloadedOnDisk(),
      builder:(context,installed){
       final present=installed.data==true||
        WaffraOnDeviceQwen.shared.isReady;
       return _accountTile(
        waffraIsEnglish?'Delete AI model':'حذف نموذج الذكاء الاصطناعي',
        present?
         (waffraIsEnglish?
          'Remove downloaded AI (~484 MB) after fingerprint/Face ID verification. '
          'Bank messages, OCR and AI analysis will stop until re-download.':
          'حذف النموذج (~484 ميجابايت) بعد تأكيد بصمة الجهاز. '
          'هتتوقف الرسائل البنكية وOCR وميزات AI لحد إعادة التنزيل.'):
         (waffraIsEnglish?
          'Not downloaded. You can install it again from any AI feature.':
          'النموذج غير منزّل. يمكن تنزيله عند فتح أي ميزة AI.'),
        Icons.delete_outline_rounded,
        tint:present?Colors.red:Colors.grey,
        onTap:present?WaffraHaptics.tap(deleteAiModel):null);
      })),
   ]),
   _accountSection(waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات',Icons.cloud_outlined,[
    _accountTile(waffraIsEnglish?'Encrypted backup & restore':'النسخ الاحتياطي المشفر والاستعادة',
     lastBackupGeneratedAt==null?(waffraIsEnglish?'No encrypted backup generated yet':'لم يتم إنشاء نسخة مشفرة بعد'):
      (waffraIsEnglish?'Last encrypted copy: ':'آخر نسخة مشفرة: ')+dayText(DateTime.tryParse(lastBackupGeneratedAt!)?.toLocal()??DateTime.now())+
       ' • ${((lastBackupBytes??0)/1024).toStringAsFixed(1)} KB',
     Icons.backup_outlined,onTap:WaffraHaptics.tap(backupDialog)),
    _accountTile(waffraIsEnglish?'Delete financial data':'حذف البيانات المالية',
     waffraIsEnglish?'Fingerprint verification and final confirmation required':'يتطلب البصمة وتأكيد الحذف النهائي',
     Icons.delete_forever,tint:Colors.red,onTap:WaffraHaptics.tap(eraseFinancialData)),
    _accountTile(waffraIsEnglish?'Delete account & cloud data':'حذف الحساب وبيانات السحابة',
     waffraAccountDeletionReleased
      ?(waffraIsEnglish?'Fresh Google verification required':'يتطلب إعادة التحقق من Google')
      :(waffraIsEnglish?'Available after deletion verification':'متاح بعد اجتياز اختبارات الحذف الآمن'),
     Icons.person_remove_outlined,tint:Colors.red,
     onTap:WaffraHaptics.tap(()=>Navigator.push<void>(context,MaterialPageRoute(
      builder:(_)=>WaffraAccountDeletionPage(
       english:waffraIsEnglish,onAccountDeleted:widget.onLogout))))),
   ]),
   _accountSection(waffraIsEnglish?'Help & about':'المساعدة وعن وفرة',Icons.help_outline_rounded,[
    _accountTile(waffraIsEnglish?'Replay app tour':'إعادة الجولة التعريفية',
     waffraIsEnglish?'Learn Waffra features':'تعرف على خصائص وفرة',
     Icons.help_outline,onTap:WaffraHaptics.tap(beginTour)),
    _accountTile(waffraIsEnglish?'About Waffra':'عن وفرة',
     waffraIsEnglish?'On-device financial management':'إدارة مالية تحفظ بياناتك محليًا',
     Icons.info_outline,onTap:WaffraHaptics.tap(()=>showAboutDialog(context:context,applicationName:'وفرة | Waffra',
      children:[WaffraText(waffraIsEnglish?'No bank account integration. Your data stays on your device.':
       'لا يوجد ربط بالحسابات البنكية؛ بياناتك محفوظة على جهازك.')])))
   ]),
   const SizedBox(height:15),
   OutlinedButton.icon(style:OutlinedButton.styleFrom(
    foregroundColor:(isGuest)?emerald:Colors.red,
    side:BorderSide(color:(isGuest)?emerald:Colors.red)),
    onPressed:WaffraHaptics.tap(()async{
     if(isGuest){await widget.onLogout();return;}
     final ok=await confirm(
      WaffraRegionalCopy.signOutTitle(english:waffraIsEnglish),
      WaffraRegionalCopy.signOutBody(english:waffraIsEnglish));
     if(ok==true&&mounted)await widget.onLogout();
    }),
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
   onTap:WaffraHaptics.tap(onTap),
   borderRadius:BorderRadius.circular(25),
   child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     Icon(icon,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest,size:21),
     const SizedBox(width:10),
     WaffraText(label,style:TextStyle(
      fontSize:15,fontWeight:FontWeight.bold,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest)),
    ]))));
 Widget currentTab(){
  if(accountOpened)return profilePage();
  if(tab==1||tab==3||tab==4){
   return RefreshIndicator(
    onRefresh:()=>_refreshAndSettle(
     tab==1?_categoryScrollController:
     tab==3?_goalsScrollController:_recurringScrollController,tab),
    child:ScrollConfiguration(
     behavior:ScrollConfiguration.of(context).copyWith(
      physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
      overscroll:false),
     child:_currentTabContents()));
  }
  return _currentTabContents();
 }
 Widget _currentTabContents(){
  switch(tab){
   case 0:return goalsOpened?goalsPage():dashboard();
   case 1:return categoriesPage();
   case 2:return _smartToolsTab();
   case 3:return goalsPage();
   case 4:return recurringPage();
   default:return dashboard();
  }
 }
 void _swipeBetweenSections(DragEndDetails details){
  if(!ready||goalsOpened||accountOpened||tourActive)return;
  final velocity=details.primaryVelocity??0;
  final dx=_swipeTravel.abs()>50?_swipeTravel:velocity/10;
  if(dx.abs()<65)return;
  final forward=waffraIsEnglish?dx>0:dx<0;
  final target=(tab+(forward?1:-1)).clamp(0,WaffraFooterNavigation.itemCount-1);
  if(target!=tab)unawaited(selectFooter(target));
 }
 Future<void> selectFooter(int target)async {
  if(target<0||target>=WaffraFooterNavigation.itemCount)return;
  if(mounted)setState((){tab=target;accountOpened=false;goalsOpened=false;addFabExpanded=false;_headerCompact=false;});
 }
 bool _consumeHomeBack(){
  if(!mounted)return false;
  if(accountOpened||goalsOpened||tab!=0||addFabExpanded){
   setState((){tab=0;accountOpened=false;goalsOpened=false;
    addFabExpanded=false;_headerCompact=false;});
   return true;
  }
  return false;
 }
 @override Widget build(BuildContext context)=>PopScope(
  // Let the root back policy route account/tabs before double-back exit.
  canPop:true,
  child:Stack(children:[Scaffold(
  appBar:AppBar(
   toolbarHeight:_headerCompact?52:64,
   flexibleSpace:const ColoredBox(color:forest),
   leading:accountOpened?IconButton(
    key:const Key('waffra-account-header-back'),
    tooltip:waffraIsEnglish?'Back to home':'العودة للرئيسية',
    icon:const Icon(Icons.arrow_back_rounded),
    onPressed:WaffraHaptics.tap(_consumeHomeBack)):
    goalsOpened?IconButton(tooltip:waffraIsEnglish?'Back to home':'العودة للرئيسية',
    icon:const Icon(Icons.arrow_back),onPressed:WaffraHaptics.tap(()=>setState(()=>goalsOpened=false))):null,
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
      onPressed:WaffraHaptics.tap((){
       if(addFabExpanded||_fabPressed)setState((){addFabExpanded=false;_fabPressed=false;});
       widget.onLanguage(waffraIsEnglish?'ar':'en');
      }),
      style:TextButton.styleFrom(
       foregroundColor:Colors.white,minimumSize:const Size(43,37),
       padding:const EdgeInsets.symmetric(horizontal:8),
       backgroundColor:Colors.white.withValues(alpha:.11),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
      child:Text(waffraIsEnglish?'AR':'EN',
       style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))),
    const SizedBox(width:7),
    Tooltip(message:waffraIsEnglish?'My account and settings':'حسابي والإعدادات',
     child:Semantics(label:waffraIsEnglish?'Open account settings':'فتح إعدادات الحساب',
      button:true,child:InkWell(
       key:const Key('waffra-header-account-entry'),
       onTap:WaffraHaptics.tap(()=>setState((){
        addFabExpanded=false;goalsOpened=false;accountOpened=true;_headerCompact=false;
       })),
       borderRadius:BorderRadius.circular(30),
       child:AnimatedContainer(duration:waffraMotion(260),
        curve:Curves.easeOutCubic,padding:const EdgeInsets.all(3),
        decoration:BoxDecoration(shape:BoxShape.circle,
         border:Border.all(color:accountOpened?const Color(0xFF65E5AD):Colors.transparent,
          width:2),
         color:accountOpened?Colors.white.withValues(alpha:.13):Colors.transparent),
        child:KeyedSubtree(key:_tourKeys[5],
         child:waffraAvatar(widget.profile.gender,widget.profile.avatar,radius:18)))))),
    const SizedBox(width:7),
   ]),
  // Instant content swap avoids building/animating the previous heavy tab
  // alongside the next one (the recurring -> savings navigation hitch).
  body:_financeLoadFailure!=null?_financialRecoveryScreen():
   !ready?const Center(child:CircularProgressIndicator()):
   Stack(clipBehavior:Clip.none,children:[GestureDetector(
    behavior:HitTestBehavior.translucent,
    onHorizontalDragStart:(_)=>_swipeTravel=0,
    onHorizontalDragUpdate:(details)=>_swipeTravel+=details.delta.dx,
    onHorizontalDragEnd:_swipeBetweenSections,
    child:ValueListenableBuilder<bool>(
     valueListenable:hideWaffraAmounts,
     builder:(context,hidden,_)=>TweenAnimationBuilder<double>(
      key:ValueKey(accountOpened?'waffra-page-account':'waffra-page-$tab'),
      tween:Tween<double>(begin:0,end:1),
      duration:waffraMotion(accountOpened?340:240),curve:Curves.easeOutCubic,
      builder:(ctx,progress,child)=>Opacity(opacity:progress,
       child:Transform.translate(offset:Offset((1-progress)*(waffraIsEnglish?26:-26),0),
        child:Transform.scale(scale:accountOpened?0.985+0.015*progress:1,child:child))),
      child:currentTab()))),
    if(!accountOpened&&(tab==0||tab==1))
     WaffraFabMenuAnchor(
      english:waffraIsEnglish,
      expanded:addFabExpanded&&!goalsOpened,
      menu:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:waffraIsEnglish?CrossAxisAlignment.end:CrossAxisAlignment.start,
       children:[
        if(tab==0&&!goalsOpened)...[
        _addMenuOption(
         icon:Icons.edit_note_rounded,
         label:waffraIsEnglish?'Manual transaction':'عملية يدوية',
         onTap:WaffraHaptics.tapRequired((){
          unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true));
         })),
        const SizedBox(height:7),
        _addMenuOption(
         icon:Icons.sms_outlined,
         label:waffraIsEnglish?'Bank message':'رسالة بنكية',
         onTap:WaffraHaptics.tapRequired((){
          unawaited(_launchAddAction(()=>bulkSmsSheet(),fromMenu:true));
         })),
        const SizedBox(height:7),
        _addMenuOption(
         icon:Icons.document_scanner_outlined,
         label:waffraIsEnglish?'Scan receipt / image':'تصوير / استخراج فاتورة',
         onTap:WaffraHaptics.tapRequired((){
          unawaited(_launchAddAction(scanAndAddReceipt,fromMenu:true));
         })),
        ]else...[
         _addMenuOption(icon:Icons.trending_up,
          label:waffraIsEnglish?'Income category':'إضافة قسم دخل',
          onTap:WaffraHaptics.tapRequired((){unawaited(_launchAddAction(()=>chooseCategoryLevel(income:true),fromMenu:true));})),
         const SizedBox(height:7),
         _addMenuOption(icon:Icons.trending_down,
          label:waffraIsEnglish?'Expense category':'إضافة قسم مصروفات',
          onTap:WaffraHaptics.tapRequired((){unawaited(_launchAddAction(()=>chooseCategoryLevel(income:false),fromMenu:true));})),
        ]
       ]),
     ),
   ]),
  // A fixed 58x58 FAB: pop-up menu is an independent body overlay.
  // Never allow a menu width to change Scaffold's floating geometry.
  floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish),
  floatingActionButtonAnimator:const WaffraStationaryFabAnimator(),
  floatingActionButton:!ready||accountOpened||tab==2?null:SizedBox(
   width:58,height:58,
   child:
    Material(
      key:_tourKeys[1],
      color:forest,elevation:7,
     shadowColor:Colors.black26,
     shape:const CircleBorder(),
     child:InkWell(
      customBorder:const CircleBorder(),
      onTap:()async{
     if(!_acceptFabTap())return;
     HapticFeedback.lightImpact(); // Only accepted circular + tap triggers haptic feedback.
     final tappedTab=tab;
     setState(()=>_fabPressed=true);
     // Give the press a short, visible response before presenting any menu.
     await Future<void>.delayed(waffraMotion(165));
     if(!mounted)return;
     setState(()=>_fabPressed=false);
     await Future<void>.delayed(waffraMotion(110));
     if(!mounted||tab!=tappedTab)return;
     if(goalsOpened||tab==3){unawaited(_launchAddAction(()=>goalDialog()));return;}
     if(tab==4){unawaited(_launchAddAction(()=>recurringDialog()));return;}
     setState(()=>addFabExpanded=!addFabExpanded);
    },
    splashFactory:NoSplash.splashFactory,
    highlightColor:Colors.transparent,
    child:AnimatedScale(
     scale:_fabPressed?0.96:1.0,
     duration:waffraMotion(220),
     curve:Curves.easeOutCubic,
     child:SizedBox(width:58,height:58,
      child:AnimatedRotation(
       duration:waffraMotion(320),
       curve:Curves.easeInOutCubic,
       turns:addFabExpanded?0.125:0,
       child:const Icon(Icons.add,color:Colors.white,size:28)))),
     )),
   ),
  // The notice reserves real layout height above the bottom footer.
  // The transaction list and the floating + reposition instead of being
  // covered by an overlay. The expanded + menu closes on feedback.
  bottomNavigationBar:accountOpened?null:Column(mainAxisSize:MainAxisSize.min,children:[
   WaffraFooterNoticeHost(onNoticePresented:(){
    if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
   }),
   WaffraFooterNavigation(
    selectedIndex:tab,
    english:waffraIsEnglish,
    onSelected:WaffraHaptics.selectionRequired((selected){
     waffraDismissFooterNotice();
     unawaited(selectFooter(selected));
    }),
   ),
  ])),
  if(tourActive&&tourTargetReady)Positioned.fill(child:tourOverlay()),
  // Outside Scaffold so the loading status never rebuilds the finance list.
  Positioned.fill(child:WaffraSmoothConfirmationOverlay(
   controller:_saveProgress,english:waffraIsEnglish)),
  ]));
}
/// Tour focus remains tied to the same floating add button across both locales.
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
class WaffraDeletedItemsButton extends StatelessWidget {
 final VoidCallback onPressed;
 final String label;
 const WaffraDeletedItemsButton({super.key,required this.onPressed,required this.label});
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  final red=dark?const Color(0xFFFF9090):const Color(0xFFB42332);
  return OutlinedButton(
   onPressed:WaffraHaptics.tap(onPressed),
   style:OutlinedButton.styleFrom(
    foregroundColor:red,backgroundColor:dark?const Color(0xFF3C242A):const Color(0xFFFFF4F4),
    side:BorderSide(color:red,width:1.4),
    minimumSize:WaffraActionLayout.minimumSize,
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
   child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
    Icon(Icons.delete_outline,size:19,color:red),
    const SizedBox(width:5),
    Flexible(child:WaffraText(label,maxLines:2,textAlign:TextAlign.center,
     style:TextStyle(color:red,fontSize:11.5,fontWeight:FontWeight.bold))),
   ]));
 }
}
/// Independently anchored menu: its width cannot move the 58px FAB.
/// The menu follows the same *physical* side, regardless of text direction.
class WaffraFabMenuAnchor extends StatelessWidget {
 const WaffraFabMenuAnchor({
  super.key,required this.english,required this.expanded,required this.menu,
 });
 final bool english;
 final bool expanded;
 final Widget menu;

 @override Widget build(BuildContext context)=>Positioned(
  left:english?null:16,
  right:english?16:null,
  bottom:86, // FAB: 58 high + 16 bottom margin + 12 clear gap
  child:IgnorePointer(
   ignoring:!expanded,
   child:AnimatedSwitcher(
    duration:waffraMotion(280),
    reverseDuration:waffraMotion(220),
    switchInCurve:Curves.easeOutCubic,
    switchOutCurve:Curves.easeInCubic,
    layoutBuilder:(current,previous)=>Stack(
     alignment:english?Alignment.bottomRight:Alignment.bottomLeft,
     children:[...previous,if(current!=null)current],
    ),
    transitionBuilder:(child,animation)=>SizeTransition(
     sizeFactor:animation,axisAlignment:1.0,
     child:FadeTransition(opacity:animation,child:child),
    ),
    child:expanded
      ? KeyedSubtree(key:const ValueKey('waffra-fab-menu-open'),child:menu)
      : const SizedBox(key:ValueKey('waffra-fab-menu-closed')),
   ),
  ),
 );
}

/// Avoid Scaffold's default size/translation animation when tabs or locale
/// change. Only the plus icon itself animates on an explicit user tap.
class WaffraStationaryFabAnimator extends FloatingActionButtonAnimator {
 const WaffraStationaryFabAnimator();
 @override Offset getOffset({
  required Offset begin,required Offset end,required double progress,
 })=>end;
 @override Animation<double> getScaleAnimation({required Animation<double> parent})=>
  const AlwaysStoppedAnimation<double>(1);
 @override Animation<double> getRotationAnimation({required Animation<double> parent})=>
  const AlwaysStoppedAnimation<double>(1);
}

/// Physically left for Arabic, physically right for English on every tab.
class WaffraDirectionalFabLocation extends FloatingActionButtonLocation {
 const WaffraDirectionalFabLocation({required this.english});
 final bool english;

 static double horizontalOffset({
  required bool english,
  required double scaffoldWidth,
  required double fabWidth,
  required double leftInset,
  required double rightInset,
 }) => english
   ? max(0.0,scaffoldWidth-fabWidth-rightInset-16)
   : 16+leftInset;

 @override Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
  final bottom=geometry.contentBottom;
  return Offset(
   horizontalOffset(
    english:english,
    scaffoldWidth:geometry.scaffoldSize.width,
    fabWidth:geometry.floatingActionButtonSize.width,
    leftInset:geometry.minInsets.left,
    rightInset:geometry.minInsets.right,
   ),
   max(16.0,bottom-geometry.floatingActionButtonSize.height-16),
  );
 }
}
/// Approved Design 9: a compact folded triangular attachment corner.
/// RTL uses the top-right corner; LTR mirrors it to top-left.
class WaffraReceiptCornerBadge extends StatelessWidget {
 const WaffraReceiptCornerBadge({
  super.key,required this.count,required this.english,
 });
 final int count;
 final bool english;
 @override Widget build(BuildContext context){
  return ClipPath(
   clipper:WaffraReceiptCornerClipper(english:english),
   child:Container(
    width:36,height:30,color:forest,
    alignment:english?Alignment.topLeft:Alignment.topRight,
    padding:EdgeInsets.only(top:3,left:english?2:0,right:english?0:2),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.attach_file_rounded,size:10,color:Colors.white),
     const SizedBox(width:1),
     Text('$count',style:const TextStyle(
      fontFamily:'Tajawal',fontSize:11,color:Colors.white,
      fontWeight:FontWeight.bold,height:1.1)),
    ]),
   ),
  );
 }
}
class WaffraReceiptCornerClipper extends CustomClipper<Path> {
 const WaffraReceiptCornerClipper({required this.english});
 final bool english;
 @override Path getClip(Size size){
  final path=Path();
  if(english){
   path.moveTo(0,0);
   path.lineTo(size.width,0);
   path.lineTo(0,size.height);
  }else{
   path.moveTo(0,0);
   path.lineTo(size.width,0);
   path.lineTo(size.width,size.height);
  }
  return path..close();
 }
 @override bool shouldReclip(covariant WaffraReceiptCornerClipper oldClipper)=>
  oldClipper.english!=english;
}
/// The Smart Analysis screen and its PDF export use one mathematical model.
/// It is independent of language, rendering and finance persistence.
class WaffraSmartChartData {
 const WaffraSmartChartData({
  required this.periods,required this.weeklySpend,required this.topCategories,
 });
 final List<(double,double)> periods;
 final List<double> weeklySpend;
 final List<MapEntry<String,double>> topCategories;
}
WaffraSmartChartData waffraSmartChartData(List<MoneyEntry> items,DateTime now){
 final valid=items.where((e)=>!e.date.isAfter(now)&&
   e.date.isAfter(now.subtract(const Duration(days:90)))).toList();
 double total(Iterable<MoneyEntry> rows,bool income)=>rows
   .where((e)=>e.income==income).fold<double>(0,(a,e)=>a+e.amount);
 final periods=List<(double,double)>.generate(3,(i){
  final from=now.subtract(Duration(days:(3-i)*30));
  final to=now.subtract(Duration(days:(2-i)*30));
  final rows=valid.where((e)=>!e.date.isBefore(from)&&e.date.isBefore(to));
  return (total(rows,true),total(rows,false));
 });
 final weekly=List<double>.generate(4,(i){
  final from=now.subtract(Duration(days:(4-i)*7));
  final to=now.subtract(Duration(days:(3-i)*7));
  return total(valid.where((e)=>!e.date.isBefore(from)&&e.date.isBefore(to)),false);
 });
 final byCategory=<String,double>{};
 for(final e in valid.where((e)=>!e.income)){
  byCategory[e.category]=(byCategory[e.category]??0)+e.amount;
 }
 final top=byCategory.entries.toList()
  ..sort((a,b)=>b.value.compareTo(a.value));
 return WaffraSmartChartData(
  periods:periods,weeklySpend:weekly,topCategories:top);
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