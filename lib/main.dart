import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'waffra_financial_tools.dart';
import 'waffra_smart_features.dart';
import 'waffra_today_picker.dart';
import 'waffra_action_layout.dart';
import 'waffra_centered_dropdown.dart';
import 'waffra_subtle_selection.dart';
import 'waffra_receipt_filename.dart';
import 'storage/waffra_portable_encrypted_vault_restorer.dart' show WaffraEncryptedReceiptReference;
import 'waffra_sms_intelligence.dart';
import 'waffra_sms_multicurrency_review.dart';
import 'waffra_foreign_currency_preview.dart';
import 'waffra_back_navigation.dart';
import 'waffra_saudi_greetings.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'waffra_biometrics.dart';
import 'waffra_external_media_session.dart';
import 'waffra_sms_sender_brand.dart';
import 'waffra_large_json_decode.dart';
import 'waffra_home_accounts_sheet.dart';
import 'waffra_approved_notifications.dart';
import 'storage/waffra_account_context_read.dart';
import 'storage/waffra_account_context_repository.dart';
import 'waffra_mandatory_biometric_gate.dart';
import 'waffra_idle_biometric_overlay.dart';
import 'waffra_local_phone_credentials.dart';
import 'waffra_local_account_migration.dart';
import 'waffra_amount_formatter.dart';
import 'waffra_display_currency.dart';
import 'waffra_phone_country_codes.dart';
import 'waffra_google_phone_field.dart';
import 'waffra_saudi_mobile.dart';
import 'waffra_country_first_run_page.dart';
import 'waffra_regional_copy.dart';
import 'waffra_saudi_release.dart';
import 'waffra_search.dart';
import 'waffra_balance_art.dart';
import 'waffra_validators.dart';
import 'waffra_financial_insights.dart';
import 'waffra_budget_alert_once.dart';
import 'waffra_goal_budget_forecast.dart';
import 'waffra_goal_due_policy.dart';
import 'waffra_reminders.dart';
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
import 'waffra_budget_template_catalog.dart';
import 'waffra_category_month_totals.dart';
import 'waffra_category_rankings.dart';
import 'waffra_entry_sheet_safe_layout.dart';
import 'waffra_visible_scroll_behavior.dart';
import 'waffra_goal_catalog.dart';
import 'waffra_pdf_reader.dart';
import 'waffra_footer.dart';
import 'waffra_messages.dart';
import 'waffra_auto_sms.dart';
import 'waffra_auto_sms_policy.dart';
import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_local_rules.dart';
import 'waffra_sms_review_groups.dart';
import 'waffra_sms_account_learning.dart';
import 'waffra_sms_rule_settings_page.dart';
import 'waffra_unknown_financial_sms_page.dart';
import 'waffra_auto_sms_consent.dart';
import 'waffra_recurring_policy.dart';
import 'waffra_cross_source_duplicate_review.dart';
import 'waffra_secure_backup.dart';
import 'waffra_backup_files.dart';
import 'storage/waffra_legacy_write_queue.dart';
import 'storage/waffra_authoritative_widget_balance.dart';
import 'storage/waffra_live_legacy_finance_guard.dart';
import 'storage/waffra_fresh_install_source.dart';
import 'storage/waffra_fresh_home_catalog_recovery.dart';
import 'storage/waffra_live_account_write_authority.dart';
import 'storage/waffra_home_finance_persistence.dart';
import 'storage/waffra_verified_finance_authority.dart';
import 'storage/waffra_accounts_portable_backup_v3.dart';
import 'storage/waffra_legacy_v24_sqlcipher_converter.dart';
import 'storage/waffra_restored_ledger_identity_guard.dart';
import 'storage/waffra_verified_active_restore_preflight.dart';
import 'storage/waffra_verified_pull_refresh_source.dart';
import 'storage/waffra_production_finance_authority_binding.dart';
import 'storage/waffra_verified_accounts_api.dart';
import 'storage/waffra_accounts_repository.dart';
import 'waffra_accounts_manager_page.dart';
import 'waffra_new_account_dialog.dart';
import 'waffra_account_transaction_form.dart';
import 'waffra_recurring_account_groups.dart';
import 'waffra_approved_page_designs.dart';
import 'waffra_goal_recurring_account_picker.dart';
import 'waffra_saudi_financial_providers.dart';
import 'storage/waffra_fresh_finance_modules_repository.dart';
import 'storage/waffra_verified_module_ui_guard.dart';
import 'storage/waffra_runtime_finance_route_contract.dart';
import 'storage/waffra_home_transaction_capture.dart';
import 'storage/waffra_verified_transaction_ui_guard.dart';
import 'storage/waffra_production_finance_routing_gate.dart';
import 'waffra_home_widget.dart';
import 'waffra_pull_refresh_scroll_settle.dart';
import 'waffra_haptic_feedback.dart';
import 'waffra_smooth_confirmation.dart';
part 'waffra_categories_page.part.dart';
part 'waffra_budget_directory.part.dart';
part 'waffra_smart_analysis.part.dart';
part 'waffra_recurring_trash.part.dart';
part 'waffra_goal_recurring_actions.part.dart';
part 'waffra_home_finance_tiles.part.dart';
part 'waffra_home_balance_header.part.dart';
part 'waffra_home_pdf_reports.part.dart';
part 'waffra_home_profile.part.dart';
part 'waffra_home_budget_cards.part.dart';
part 'waffra_home_budget_workflows.part.dart';
part 'waffra_home_entry_sheet.part.dart';
part 'waffra_home_account_tools.part.dart';
part 'waffra_home_verified_transfer_cards.part.dart';
part 'waffra_home_category_workflows.part.dart';
part 'waffra_home_sms_transfer_review.part.dart';
part 'waffra_home_goals_recurring_pages.part.dart';
part 'waffra_home_goal_actions.part.dart';
part 'waffra_home_dashboard_analytics.part.dart';
part 'waffra_finance_period_index.part.dart';
part 'waffra_deleted_item_card.part.dart';
part 'waffra_auto_sms_autopost.part.dart';

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

/// A short-lived background FlutterEngine executes the very same verified
/// Home/Widget finance writer after Android schedules receipt of bank SMS.
/// No UI tree, no new database and no cloud inference in the background.
@pragma('vm:entry-point')
void waffraAutoSmsBackgroundEntrypoint() {
 WidgetsFlutterBinding.ensureInitialized();
 const bridge=MethodChannel('waffra/auto_sms_worker');
 bridge.setMethodCallHandler((call)async{
  if(call.method!='process')return false;
  try{
   await WaffraAutoSmsAutoPoster.run();
   return true;
  }catch(_){
   // Do not log banking text or claim it was recorded. WorkManager may retry
   // with the same encrypted candidate and atomic duplicate hash.
   return false;
  }
 });
 unawaited(bridge.invokeMethod<void>('ready'));
}

Future<void> main()async {
 WidgetsFlutterBinding.ensureInitialized();
 // Classify the installation before onboarding writes its first preferences.
 if(Platform.isAndroid){
  try{await WaffraFreshInstallSource.prepare();}catch(_){
   runApp(MaterialApp(home:Scaffold(body:Center(child:FilledButton(
    onPressed:main,child:const Text('تعذّر فتح التخزين المشفّر. إعادة المحاولة / Retry'),
   )))));
   return;
  }
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
    if(!hidden)...[
     WaffraCurrencyMark(english:waffraIsEnglish,
      currencyCode:WaffraDisplayCurrency.country.code,
      arabicLabel:WaffraDisplayCurrency.country.symbolAr,
      size:size*.9,color:color),
     const SizedBox(width:4),
    ],
    WaffraText(hidden?'***':'$prefix${WaffraDisplayCurrency.amount(amount)}',style:effective),
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
 /// Explicitly chosen budget category ID. Null means not assigned.
 final String? budgetId;
 /// Internal merchant identifier is a merchant *name*, never a bank/card ID.
 final String notes,sourceType,merchantKey,personalNotes;
 /// Saved separately from cash: the confirmed goal-due amount funded by
 /// the goals wallet, in integer halalas. Other entries must leave it zero.
 final int goalWalletPaidMinor;
 MoneyEntry({required this.id,required this.title,required this.category,required this.amount,
  required this.income,required this.date,this.receiptPath,this.notes='',
  this.personalNotes='',this.sourceType='manual',this.merchantKey='',this.budgetId,
  this.goalWalletPaidMinor=0});
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,
  'amount':amount,'income':income,'date':date.toIso8601String(),
  'receiptPath':receiptPath,'notes':notes,'personalNotes':personalNotes,
  'sourceType':sourceType,
  'merchantKey':merchantKey,if(budgetId!=null)'budgetId':budgetId,
  if(goalWalletPaidMinor>0)'goalWalletPaidMinor':goalWalletPaidMinor};
 // M530: pure large-ledger serialization; caller freezes immutable entries
 // BEFORE its first await. This worker preserves toJson() field order/bytes.
 static String encodeFrozenSnapshot(List<MoneyEntry> frozenEntries)=>
  jsonEncode(frozenEntries.map((e)=>e.toJson()).toList(growable:false));
 factory MoneyEntry.fromJson(Map<String,dynamic> j)=>MoneyEntry(
  id:'${j['id']??newId()}',title:'${j['title']??''}',
  category:'${j['category']??'أخرى'}',amount:(j['amount'] as num).toDouble(),
  income:j['income']==true,date:DateTime.tryParse('${j['date']}')??DateTime.now(),
  receiptPath:j['receiptPath']?.toString(),
  notes:'${j['notes']??''}',personalNotes:'${j['personalNotes']??''}',
  sourceType:'${j['sourceType']??'legacy'}',
  merchantKey:'${j['merchantKey']??''}',
  budgetId:j['budgetId'] is String&&((j['budgetId'] as String).trim().isNotEmpty)?
   j['budgetId'] as String:null,
  goalWalletPaidMinor:j['sourceType']=='goal_due'&&j['goalWalletPaidMinor'] is int
   ?j['goalWalletPaidMinor'] as int:0);
 /// Category rename is metadata-only; protect SMS notes, source identity,
 /// merchant key, original timestamp and receipt references.
 MoneyEntry withCategory(String next)=>MoneyEntry(
  id:id,title:title,category:next,amount:amount,income:income,date:date,
  receiptPath:receiptPath,notes:notes,personalNotes:personalNotes,
  sourceType:sourceType,merchantKey:merchantKey,budgetId:budgetId,
  goalWalletPaidMinor:goalWalletPaidMinor);
 /// Reassigning a budget must not mutate the amount, date, SMS, merchant or receipt.
 MoneyEntry withBudget(String? budget)=>MoneyEntry(
  id:id,title:title,category:category,amount:amount,income:income,
  date:date,receiptPath:receiptPath,notes:notes,personalNotes:personalNotes,
  sourceType:sourceType,merchantKey:merchantKey,budgetId:income?null:budget,
  goalWalletPaidMinor:goalWalletPaidMinor);
}


/// Flag historical imported placeholders that may already have been
/// entered as SAR despite an unverified foreign bank currency. This is
/// read-only: never migrate, silently edit, or delete existing user money.
bool waffraNeedsLegacyFxReview(MoneyEntry entry) =>
  const <String>{'sms','receipt'}.contains(entry.sourceType) &&
  (entry.title.startsWith('معاملة بعملة تحتاج') ||
   entry.title.toLowerCase().contains('foreign currency needs review'));

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
 // Optional label for a category-scoped named monthly budget.
 final String? budgetLabel;
 /// Paused budgets stay in storage with their former ID, cap and links.
 /// Pre-activation records have no flag, so default to active.
 final bool budgetActive;
 /// Category visibility for NEW postings; unrelated to named budget pause.
 /// Old records and scheduled references retain category IDs and amounts.
 final bool categoryActive;
 BudgetCategory({required this.id,required this.name,required this.icon,required this.color,
  required this.income,this.parentId='',this.budget=0,this.alertPercent=80,
  this.origin='system',this.budgetLabel,this.budgetActive=true,
  this.categoryActive=true});
 bool get isUserAdded=>origin=='user';
 bool get isSubcategory=>parentId.isNotEmpty;
 String get displayName=>isSubcategory?name.split(' / ').last:name;
 BudgetCategory copy({String? name,String? icon,int? color,double? budget,
  int? alertPercent,String? parentId,String? budgetLabel,bool clearBudget=false,
  bool? budgetActive,bool? categoryActive})=>BudgetCategory(
   id:id,name:name??this.name,icon:icon??this.icon,color:color??this.color,
   income:income,parentId:parentId??this.parentId,budget:budget??this.budget,
   alertPercent:alertPercent??this.alertPercent,origin:origin,
   budgetLabel:clearBudget?null:budgetLabel??this.budgetLabel,
   budgetActive:budgetActive??this.budgetActive,
   categoryActive:categoryActive??this.categoryActive);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'icon':icon,'color':color,
  'income':income,'parentId':parentId,'budget':budget,'alertPercent':alertPercent,
  'origin':origin,'budgetActive':budgetActive,
  'categoryActive':categoryActive,
  if(budgetLabel!=null)'budgetLabel':budgetLabel};
 factory BudgetCategory.fromJson(Map<String,dynamic> j)=>BudgetCategory(
  id:'${j['id']??newId()}',name:'${j['name']??'أخرى'}',
  icon:'${j['icon']??'category'}',color:(j['color'] as num?)?.toInt()??0xFF087A54,
  income:j['income']==true,parentId:'${j['parentId']??''}',
  budget:(j['budget'] as num?)?.toDouble()??0,
  alertPercent:(j['alertPercent'] as num?)?.toInt()??80,
  origin:j['origin']=='user'?'user':j['origin']=='detected'?'detected':'system',
  budgetActive:!j.containsKey('budgetActive')||j['budgetActive']==true,
  categoryActive:!j.containsKey('categoryActive')||j['categoryActive']==true,
  budgetLabel:j['budgetLabel'] is String&&
    (j['budgetLabel'] as String).trim().isNotEmpty
    ?(j['budgetLabel'] as String).trim():null);
}
/// Budgets live in their own finance collection, not in category hierarchy.
class WaffraNamedBudget extends BudgetCategory {
 final bool deleted;
 /// Separate from budget activation: user-controlled percentage alerts.
 final bool alertsEnabled;
 /// Explicit display attribution only: shared/unassigned historical budgets
 /// never receive a guessed account from the Home header.
 final String? assignedAccountId;
 WaffraNamedBudget({required String id,required String name,
  required double budget,int alertPercent=80,bool budgetActive=true,
  this.alertsEnabled=true,this.deleted=false,this.assignedAccountId}):super(
   id:id,name:name,icon:'wallet',color:0xFF087A54,income:false,
   budget:budget,alertPercent:alertPercent,budgetActive:budgetActive,
   budgetLabel:name,origin:'user');
 static String _legacyLabel(BudgetCategory c) {
  final raw=(c.budgetLabel??'ميزانية ${c.displayName}').trim();
  // A historic category title may exceed the independent budget 80-char
  // limit. Preserve its stable ID and amount while bounding display text.
  final runes=raw.runes.toList();
  return String.fromCharCodes(runes.length>80?runes.take(80):runes);
 }
 factory WaffraNamedBudget.fromLegacy(BudgetCategory category)=>
  WaffraNamedBudget(id:category.id,
   name:_legacyLabel(category),budget:category.budget,
   alertPercent:category.alertPercent<1||category.alertPercent>100
    ?80:category.alertPercent,
   budgetActive:category.budgetActive);
 factory WaffraNamedBudget.fromJson(Map<String,dynamic> raw) {
  final id=raw['id'],name=raw['name'],amount=raw['budget'];
  final alert=raw['alertPercent'],active=raw['budgetActive'];
  final alerts=raw['alertsEnabled'];
  if(id is! String||id.trim().isEmpty||id.length>256||
   name is! String||name.trim().isEmpty||name.runes.length>80||
   amount is! num||!amount.isFinite||amount<=0||
   alert is! int||alert<1||alert>100||active is! bool||
   (raw.containsKey('deleted')&&raw['deleted'] is! bool)||
   (raw.containsKey('alertsEnabled')&&alerts is! bool)||
   (raw.containsKey('assignedAccountId')&&raw['assignedAccountId']!=null&&
     (raw['assignedAccountId'] is! String||
      (raw['assignedAccountId'] as String).trim().isEmpty||
      (raw['assignedAccountId'] as String).length>128))){
   throw const FormatException('Invalid standalone named budget.');
  }
  return WaffraNamedBudget(id:id,name:name,budget:amount.toDouble(),
   alertPercent:alert,budgetActive:active,
   alertsEnabled:alerts!=false,deleted:raw['deleted']==true,
   assignedAccountId:raw['assignedAccountId'] as String?);
 }
 @override Map<String,dynamic> toJson()=>{
  'id':id,'name':name,'parentId':'','income':false,
  'budget':budget,'budgetActive':budgetActive,
  'alertPercent':alertPercent,'alertsEnabled':alertsEnabled,
  'deleted':deleted,
  if(assignedAccountId!=null)'assignedAccountId':assignedAccountId,
 };
 @override WaffraNamedBudget copy({String? name,String? icon,int? color,
  double? budget,int? alertPercent,String? parentId,
  String? budgetLabel,bool clearBudget=false,bool? budgetActive,
  // Standalone budgets are not categories; keep inherited API compatible
  // without persisting the independent category-activation flag on budgets.
  bool? categoryActive,bool? alertsEnabled,bool? deleted,
  String? assignedAccountId,bool clearAssignedAccount=false})=>WaffraNamedBudget(
    id:id,name:budgetLabel??name??this.name,budget:budget??this.budget,
    alertPercent:alertPercent??this.alertPercent,
    budgetActive:budgetActive??this.budgetActive,
    alertsEnabled:alertsEnabled??this.alertsEnabled,
    deleted:deleted??this.deleted,
    assignedAccountId:clearAssignedAccount?null:
     assignedAccountId??this.assignedAccountId);
}


/// Independent percentage alerts: the budget remains active even when muted.
Widget waffraBudgetAlertControls({
 required bool enabled,required int percent,required bool english,
 required ValueChanged<bool> onEnabled,required ValueChanged<int> onPercent,
 bool goal=false,
})=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 SwitchListTile.adaptive(
  key:Key(goal?'waffra-goal-alert-toggle':'waffra-budget-alert-toggle'),
  contentPadding:EdgeInsets.zero,
  title:WaffraText(goal?
   (english?'Goal progress alerts':'تنبيهات نسبة ادخار الهدف'):
   (english?'Budget percentage alerts':'تنبيهات نسبة الميزانية')),
  subtitle:WaffraText(goal?
   (english?'Notify when savings reach the selected percentage':
    'نبهني عند وصول الادخار للنسبة المحددة'):
   (english?'Alert me after spending reaches the selected percentage':
    'نبهني عند الوصول للنسبة اللي أحددها')),
  value:enabled,activeTrackColor:emerald,
  onChanged:WaffraHaptics.selection(onEnabled)),
 if(enabled)...[
  const SizedBox(height:8),
  WaffraCenteredDropdownFormField<int>(
   key:ValueKey('waffra-${goal?'goal':'budget'}-alert-percent-$percent'),
   initialValue:percent,isExpanded:true,
   decoration:InputDecoration(
    labelText:english?'Notify at':'التنبيه عند نسبة',
    border:const OutlineInputBorder()),
   items:(<int>{50,60,70,75,80,85,90,95,100,percent}.toList()..sort()).map((value)=>
    DropdownMenuItem<int>(value:value,child:WaffraText('$value٪'))).toList(),
   onChanged:WaffraHaptics.selection((value){
    if(value!=null)onPercent(value);
   })),
 ],
]);

/// A budget picker is not part of transaction entry until the user has at
/// least one active named budget. Paused and archived budgets are retained
/// safely but are not selectable for new spending.
bool waffraHasSelectableBudget(Iterable<WaffraNamedBudget> budgets)=>
 budgets.any((b)=>b.budget>0&&b.budgetActive&&!b.deleted);

/// Manual transactions must target an active child category, never a heading.
/// A paused parent disables selection of all its children without mutating
/// any child or historical ledger record. Legacy JSON defaults to enabled.
bool waffraCategoryAvailableForNewEntry(
 Iterable<BudgetCategory> values,BudgetCategory category){
 if(!category.categoryActive)return false;
 if(!category.isSubcategory)return true;
 return values.any((parent)=>parent.id==category.parentId&&
  !parent.isSubcategory&&parent.income==category.income&&
  parent.categoryActive);
}

/// Historical recurring items may reference a legacy main category; respect
/// its pause flag too while retaining the original recurring item unchanged.
bool waffraCategoryNameAvailableForPosting(
 Iterable<BudgetCategory> values,bool income,String name){
 final all=values.toList();
 return all.any((c)=>c.income==income&&c.name==name&&
  waffraCategoryAvailableForNewEntry(all,c));
}

List<BudgetCategory> waffraManualCategoryParents(
 Iterable<BudgetCategory> values,bool income)=>
 values.where((c)=>c.income==income&&!c.isSubcategory&&
  c.categoryActive).toList();

List<BudgetCategory> waffraManualCategoryChildren(
 Iterable<BudgetCategory> values,bool income,String? parentId){
 if(parentId==null)return <BudgetCategory>[];
 final all=values.toList();
 return all.where((c)=>c.income==income&&c.isSubcategory&&
  c.parentId==parentId&&waffraCategoryAvailableForNewEntry(all,c)).toList();
}

bool waffraCanAssignManualCategory(Iterable<BudgetCategory> values,
 bool income,String? parentId,String category){
 if(parentId==null)return false;
 final all=values.toList();
 return all.any((c)=>c.income==income&&!c.isSubcategory&&
  c.id==parentId&&c.categoryActive)&&
  all.any((c)=>c.income==income&&c.isSubcategory&&
   c.parentId==parentId&&c.name==category&&
   waffraCategoryAvailableForNewEntry(all,c));
}

/// M669: bank SMS suggestions are NOT category selections. A root-only
/// candidate, notably "تحويلات", may suggest the main heading but must
/// never be displayed or committed as a child. Name-only matches across
/// parents/directions are ambiguous, so require explicit user selection.
({BudgetCategory? parent,BudgetCategory? leaf})
waffraResolveSmsReviewCategory(Iterable<BudgetCategory> categories,{
 required bool income,required String proposed,
}){
 final all=categories.toList(growable:false);
 final hint=proposed.trim();
 if(hint.isEmpty)return (parent:null,leaf:null);
 final roots=all.where((c)=>!c.isSubcategory&&c.income==income&&
  c.categoryActive).toList();
 final leaves=all.where((c)=>c.isSubcategory&&c.income==income&&
  waffraCategoryAvailableForNewEntry(all,c)).toList();
 final parts=hint.split(RegExp(r'\s*/\s*'));
 if(parts.length==2){
  final matchingParents=roots.where((p)=>p.name==parts.first||
   p.displayName==parts.first).toList();
  if(matchingParents.length!=1)return (parent:null,leaf:null);
  final parent=matchingParents.single;
  final matchingChildren=leaves.where((c)=>c.parentId==parent.id&&
   (c.name==hint||c.name==parts.last||
    c.displayName==parts.last)).toList();
  return (parent:parent,
    leaf:matchingChildren.length==1?matchingChildren.single:null);
 }
 // A catalog root always takes priority over a same-name leaf hint.
 final parents=roots.where((p)=>p.name==hint||
  p.displayName==hint).toList();
 if(parents.length==1)return (parent:parents.single,leaf:null);
 if(parents.isNotEmpty)return (parent:null,leaf:null);
 final matchingChildren=leaves.where((c)=>c.name==hint||
  c.displayName==hint).toList();
 if(matchingChildren.length!=1)return (parent:null,leaf:null);
 final leaf=matchingChildren.single;
 final matches=roots.where((p)=>p.id==leaf.parentId).toList();
 return (parent:matches.length==1?matches.single:null,
   leaf:matches.length==1?leaf:null);
}


class SavingGoal {
 final String id,name;
 /// Stable, user-approved verified funding account; null only for old goals.
 final String? accountId;
 final double target,saved;
 /// Optional savings progress alerts, independent of goal active state.
 final bool progressAlertsEnabled;
 final int progressAlertPercent;
 /// Pausing a goal does not spend, delete or change its saved money.
 final bool active;
 /// Deadline alone never posts money; payment needs user confirmation.
 final DateTime? dueDate;
 SavingGoal({required this.id,required this.name,required this.target,
  required this.saved,this.dueDate,this.active=true,this.accountId,
  this.progressAlertsEnabled=false,this.progressAlertPercent=80});
 SavingGoal copy({String? name,double? target,double? saved,DateTime? dueDate,
  bool? active,bool? progressAlertsEnabled,int? progressAlertPercent,
  String? accountId})=>
  SavingGoal(id:id,name:name??this.name,target:target??this.target,
   saved:saved??this.saved,dueDate:dueDate??this.dueDate,
   accountId:accountId??this.accountId,active:active??this.active,
   progressAlertsEnabled:progressAlertsEnabled??this.progressAlertsEnabled,
   progressAlertPercent:progressAlertPercent??this.progressAlertPercent);
 Map<String,dynamic> toJson()=>{'id':id,'name':name,'target':target,'saved':saved,
  'active':active,'progressAlertsEnabled':progressAlertsEnabled,
  'progressAlertPercent':progressAlertPercent,
  if(accountId!=null)'accountId':accountId,
  if(dueDate!=null)'dueDate':dueDate!.toIso8601String()};
 factory SavingGoal.fromJson(Map<String,dynamic> j){
  final linked=j['accountId'];
  if(linked!=null&&(linked is! String||linked.trim().isEmpty||linked.length>128)){
   throw const FormatException('Invalid linked savings account ID.');
  }
  if(j['progressAlertsEnabled']!=null&&j['progressAlertsEnabled'] is! bool ||
     j['progressAlertPercent']!=null&&
      (j['progressAlertPercent'] is! int||
       !(const [50,60,70,75,80,85,90,95,100]).contains(j['progressAlertPercent']))){
   throw const FormatException('Invalid goal progress alert setting.');
  }
  return SavingGoal(
  id:'${j['id']??newId()}',name:'${j['name']??''}',
  target:(j['target'] as num).toDouble(),
  saved:(j['saved'] as num?)?.toDouble()??0,
  accountId:linked as String?,
  dueDate:DateTime.tryParse('${j['dueDate']??''}'),
  active:!j.containsKey('active')||j['active']==true,
  progressAlertsEnabled:j['progressAlertsEnabled']==true,
  progressAlertPercent:j['progressAlertPercent'] as int? ??80);
 }
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
 final String id,title,category;
 final double amount;final bool income;
 final int day;final bool active;
 final DateTime startAt;
 /// Link to an existing savings goal, without mirroring its saved amount.
 final String? linkedGoalId;
 /// Explicit default funding account. Old schedules may lack one.
 final String? accountId;
 RecurringBill({required this.id,required this.title,required this.category,
  required this.amount,required this.income,required this.day,this.active=true,
  DateTime? startAt,this.linkedGoalId,this.accountId}):startAt=startAt??DateTime.now();
 RecurringBill copy({String? title,String? category,double? amount,bool? active,
  int? day,DateTime? startAt,String? accountId})=>RecurringBill(id:id,title:title??this.title,
   category:category??this.category,amount:amount??this.amount,income:income,
   day:day??this.day,active:active??this.active,
   startAt:startAt??this.startAt,linkedGoalId:linkedGoalId,
   accountId:accountId??this.accountId);
 RecurringBill withCategory(String next)=>copy(category:next);
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,
  'amount':amount,'income':income,'day':day,'active':active,
  'startAt':startAt.toIso8601String(),
  if(linkedGoalId!=null)'linkedGoalId':linkedGoalId,
  if(accountId!=null)'accountId':accountId};
 factory RecurringBill.fromJson(Map<String,dynamic> j)=>RecurringBill(
  id:'${j['id']??newId()}',title:'${j['title']??''}',
  category:'${j['category']??'أخرى'}',
  amount:(j['amount'] as num).toDouble(),income:j['income']==true,
  day:(j['day'] as num?)?.toInt()??1,active:j['active']!=false,
  startAt:DateTime.tryParse('${j['startAt']??''}')??DateTime.now(),
  linkedGoalId:j['linkedGoalId'] is String&&
    (j['linkedGoalId'] as String).trim().isNotEmpty
    ?(j['linkedGoalId'] as String).trim():null,
  accountId:j['accountId'] is String&&
    (j['accountId'] as String).trim().isNotEmpty
    ?(j['accountId'] as String).trim():null);
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

/// M633: only immutable public default categories are prepared on app launch.
/// No account balance, credential, SQLCipher key or user finance is cached.
String _m633EncodePublicCategoryCatalog(bool unused)=>jsonEncode(
 defaultCategories().map((category)=>category.toJson()).toList());

abstract final class WaffraPublicStartupPrewarm {
 static Future<String>? _catalogJson;
 static Future<String> categoriesJson()=>_catalogJson??=
  compute(_m633EncodePublicCategoryCatalog,true);
 static void prime(){
  // Background task may finish before/after login. The actual Home awaits it
  // and still performs fresh verified SQLCipher source/witness validation.
  unawaited(categoriesJson().then((_) {},
   onError:(Object error,StackTrace stackTrace){}));
 }
}

/// Category-scoped monthly budgets never include income, goals, or
/// scheduled-but-unpaid recurring items. No money is created by a budget.
/// Only explicitly budget-linked expense records contribute to a named budget.
/// Legacy transactions are unassigned until the user opts into retrospective linking.
double waffraNamedBudgetSpent(Iterable<MoneyEntry> records,
 Iterable<BudgetCategory> catalog,BudgetCategory budget,DateTime month){
 if(budget.income)return 0;
 return records.where((e)=>!e.income&&e.budgetId==budget.id&&
  e.date.year==month.year&&e.date.month==month.month)
  .fold<double>(0,(sum,e)=>sum+e.amount);
}
/// Goals savings are an independent wallet; saving or creating a goal must
/// NOT debit the current cash ledger. A goal_due explicitly attributes its
/// paid amount to the wallet, with any uncovered remainder paid from cash.
double waffraGoalWalletBalance(Iterable<SavingGoal> goals)=>
 goals.fold<double>(0,(sum,g)=>sum+g.saved);

/// Source-attested goal wallet attribution is integer halalas; only the
/// remainder of this single payment debits an actual money account.
int waffraGoalDueCashMinor(MoneyEntry entry){
 final gross=WaffraRecurringPolicy.toHalalas(entry.amount);
 final wallet=entry.sourceType=='goal_due'
  ?entry.goalWalletPaidMinor.clamp(0,gross).toInt():0;
 return gross-wallet;
}
String waffraEntryReportCategory(MoneyEntry entry)=>
 entry.sourceType=='goal_due'?'استحقاق هدف':entry.category;
/// Historical goal dues encoded internal split markers in personal notes.
/// Hide only this exact machine format; keep actual user-written notes.
String waffraGoalDueVisibleNotes(MoneyEntry entry){
 final notes=entry.sourceType=='sms'?entry.personalNotes:entry.notes;
 if(entry.sourceType=='goal_due'&&RegExp(
  r'^goal_wallet_minor=[0-9]+;current_cash_minor=[0-9]+$')
  .hasMatch(notes.trim()))return '';
 return notes;
}

double waffraAvailableCash(Iterable<MoneyEntry> ledger,Iterable<SavingGoal> goals)=>
 ledger.fold<double>(0,(total,e){
  if(e.income)return total+e.amount;
  final minor=(e.amount*100).round();
  final wallet=e.sourceType=='goal_due'&&e.goalWalletPaidMinor>=0&&
   e.goalWalletPaidMinor<=minor?e.goalWalletPaidMinor/100:0.0;
  return total-e.amount+wallet;
 });

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
  // A transfer between the user's own accounts, or a credit-card settlement,
  // must not be silently counted as everyday income/expense. Account ownership
  // and card liability need explicit user review before ledger classification.
  if(RegExp(r'^\s*(?:Internal\s+Transfer|Credit\s+Card\s+Payment)\b',
      caseSensitive:false).hasMatch(header)||
     RegExp(r'\bas\s+Credit\s+Card\s+Payment\b',
      caseSensitive:false).hasMatch(s)){
   return BankResult(null,false,'تحويل أو سداد يحتاج مراجعة','تحويلات',null,
    currencyCode:discoveredCurrencies.length==1
      ?discoveredCurrencies.single:null,
    requiresCurrencyReview:
      WaffraSmsCurrencies.requiresReviewForSarLedger(s));
  }
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
  final legacyOutgoing=RegExp(r'حوال[ةه].{0,25}صادر|تحويل.{0,25}صادر|شراء|نقاط\s*بيع|pos\b|مدى|سحب|خصم|دفع|فاتورة|شحن\s*(?:الجوال|جوال|الرصيد|رصيد|الهاتف)|purchase|debit\b',caseSensitive:false).hasMatch(s);
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
  // Only complete currency tokens; Arabic رسوم/رسائل are never SAR units.
  // A bank may write بSR, بـSAR or بــريال next to an amount; allow
  // that explicit short Arabic preposition without accepting bare رس words.
  const currency=r'(?<![A-Za-zء-ي])(?:بـ*)?(?:SAR|SR|ر\.\s*س\.?|ر\s+س\.?|ريال(?:\s+سعودي)?|﷼|⃁)(?![A-Za-zء-ي])';
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
  // A bare "Amount 150" is NOT evidence of SAR. The phrase could come
  // from any global bank or from a balance. A stored SAR entry requires
  // positive, source-grounded SAR currency evidence, never a UI setting.
  // SAR appearing only in a balance or a separate fee is not proof
  // that the chosen number was the transaction amount. The exact source
  // amount MUST agree with the conservative action-only currency parser.
  if(value!=null){
   final verifiedSource=WaffraSmsCurrencies.originalAmount(s);
   if(verifiedSource==null||verifiedSource.currency!='SAR'||
      (verifiedSource.amount-value).abs()>0.00001)value=null;
  }
  var title=income?'مبلغ وارد':'عملية بنكية',cat=income?'دخل آخر':'أخرى';
  String? suggestion;
  if(RegExp(r'راتب|salary',caseSensitive:false).hasMatch(header)){title='راتب';cat='راتب';}
  else if(!income&&RegExp(r'شحن\s*(?:الجوال|جوال|الرصيد|رصيد|الهاتف)',
    caseSensitive:false).hasMatch(header)){
   // A mobile top-up is not an ambiguous merchant-number notification.
   // The explicit currency parser still independently verifies its amount.
   title='شحن الجوال';cat='فواتير / جوال';
  }
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
DateTime? bankSmsDate(String raw, {DateTime? referenceDate}) {
 final normalized=digits(raw).replaceAll('‏','').replaceAll('‎','');
 final iso=RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})\b').firstMatch(normalized);
 DateTime? checked(int year,int month,int day,int hour,int minute){
  if(year<2000||year>2100||month<1||month>12||day<1||day>31||
     hour<0||hour>23||minute<0||minute>59)return null;
  final date=DateTime(year,month,day,hour,minute);
  return date.year==year&&date.month==month&&date.day==day?date:null;
 }
 if(iso!=null){
  final y=int.tryParse(iso.group(1)!),m=int.tryParse(iso.group(2)!),
   d=int.tryParse(iso.group(3)!),h=int.tryParse(iso.group(4)!),
   min=int.tryParse(iso.group(5)!);
  return y==null||m==null||d==null||h==null||min==null?
   null:checked(y,m,d,h,min);
 }
 final match=RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{1,4})\s+(\d{1,2}):(\d{2})').firstMatch(normalized);
 if(match==null)return null;
 final a=int.tryParse(match.group(1)!),month=int.tryParse(match.group(2)!),
  c=int.tryParse(match.group(3)!),hour=int.tryParse(match.group(4)!),
  minute=int.tryParse(match.group(5)!);
 if(a==null||month==null||c==null||hour==null||minute==null)return null;
 // DD/MM/YY is common for MADA. Two-digit YY/MM/DD also appears in
 // transfers. The word "transfer" alone does NOT establish that order.
 final dmy=checked(c<100?2000+c:c,month,a,hour,minute);
 final isTransfer=RegExp(r'حوال[ةه]|تحويل|transfer',caseSensitive:false).hasMatch(raw);
 if(!isTransfer)return dmy;
 final ymd=checked(a<100?2000+a:a,month,c,hour,minute);
 if(dmy==null)return ymd;
 if(ymd==null)return dmy;
 if(dmy==ymd)return dmy;
 // A current-year source is more likely than one several years away.
 // Otherwise reject the ambiguous date instead of fabricating a timestamp.
 final ref=referenceDate??DateTime.now();
 final dmyDistance=dmy.difference(ref).inDays.abs();
 final ymdDistance=ymd.difference(ref).inDays.abs();
 // Two dates within the plausible import-history window are ambiguous:
 // 26/10/25 could mean 25 Oct 2026 or 26 Oct 2025. Never silently
 // recast last year's banking transaction as today's or vice versa.
 if(dmyDistance<=730&&ymdDistance<=730)return null;
 if(dmyDistance<=180&&ymdDistance>540)return dmy;
 if(ymdDistance<=180&&dmyDistance>540)return ymd;
 return null;
}
bool bankSmsHasUnverifiedTimestamp(String raw,{DateTime? referenceDate}){
 final normalized=digits(raw).replaceAll('‏','').replaceAll('‎','');
 final hasExplicit=RegExp(
  r'\b(?:\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{1,4})\s+\d{1,2}:\d{2}\b'
 ).hasMatch(normalized);
 return hasExplicit&&bankSmsDate(raw,referenceDate:referenceDate)==null;
}

String bankSmsHash(String raw)=>sha256.convert(utf8.encode(digits(raw).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();

 // M632: a pure compute worker. No BuildContext, widget, native platform
 // channel, SQLCipher handle or owner identity is ever sent to this isolate.
 // Transfer only the current verified native queue and local rule data; return
 // review candidates and requested ACKs for owner-checked main-isolate I/O.
Map<String,Object?> waffraM632ClassifySmsQueue(Map<String,Object?> input){
 final results=(input['results'] as List).cast<Map<String,Object?>>();
 final rules=(input['rules'] as List).map((entry)=>
  WaffraSmsLocalRule.fromJson(Map<String,dynamic>.from(entry as Map)))
  .toList(growable:false);
 final validCategories=(input['categories'] as List).whereType<String>().toSet();
 final hashes=(input['hashes'] as List).whereType<String>().toSet();
 final waiting=<Map<String,Object?>>[];
 final excluded=<String>[];
 final committed=<String>[];
 final retainOnAckFailure=<Map<String,Object?>>[];
 for(final candidate in results){
  final id=candidate['id'],body=candidate['body'];
  if(id is! String||body is! String)continue;
  if(hashes.contains(bankSmsHash(body))){
   committed.add(id);
   retainOnAckFailure.add(Map<String,Object?>.from(candidate));
   continue;
  }
  final annotated=Map<String,Object?>.from(candidate);
  if(WaffraBankSmsFactsParser.isVerificationChallenge(body)){
   annotated['sensitiveOtp']=true;
  }
  final sender=candidate['sender'] is String?candidate['sender'] as String:'';
  final facts=WaffraBankSmsFactsParser.parse(body);
  final parsed=BankParser.parse(body);
  final special=WaffraSmsLocalRules.resolveSpecial(
   body:body,sender:sender,
   bankKind:annotated['sensitiveOtp']==true?
    WaffraBankOperationKind.uncertain:facts.kind,custom:rules);
  Map<String,Object?>? local;
  if(special!=null){
   local=<String,Object?>{
    'rule':special.name,'kind':special.resolvedKind,
    'category':special.category,'income':false,
    'defaultSeed':special.builtIn,
   };
  }else if(!facts.pending&&parsed.amount!=null&&parsed.amount!>0&&
    !parsed.requiresCurrencyReview&&
    !WaffraSmsCurrencies.requiresReviewForSarLedger(body)&&
    ((facts.kind==WaffraBankOperationKind.income)==parsed.income||
     (facts.kind!=WaffraBankOperationKind.income&&
      facts.kind!=WaffraBankOperationKind.expense))){
   final rule=WaffraSmsLocalRules.resolve(
    body:body,sender:sender,bankKind:facts.kind,custom:rules);
   if(rule!=null&&validCategories.contains(
      '${rule.income?'1':'0'}:${rule.category}')){
    local=<String,Object?>{
     'rule':rule.name,'kind':rule.resolvedKind,
     'category':rule.category,'income':rule.income,
    };
   }
  }
  if(local!=null){
   annotated['local']=local;
   if(local['kind']=='excluded'){
    // Only a safe ready or user-confirmed rule may reach this path.
    // Native pending IDs are excluded, never ledger-finance ACKs.
    excluded.add(id);
    retainOnAckFailure.add(annotated);
    continue;
   }
  }
  waiting.add(annotated);
 }
 return <String,Object?>{
  'waiting':waiting,'excluded':excluded,'committed':committed,
  'retainOnAckFailure':retainOnAckFailure,
 };
}
List<String> splitBankMessages(String raw){
 var clean=raw.replaceAll('\r\n','\n').replaceAll('\u200f','').replaceAll('\u200e','').trim();
 if(clean.isEmpty)return [];
 // Concatenated SMS exports can join the end of a bank notification to the next
 // message without a space (e.g. "SARCredit Transfer" or "JODJOD10").
 // Insert boundaries only before strongly recognizable new actions.
 clean=clean.replaceAll(RegExp(
  r'(?<=[A-Za-z0-9.])(?=(?:Credit\s+Transfer\s+via\b|'
  r'Credit\s+via\s+(?:local|domestic|international)\s+transfer\b|'
  r'Purchase\s+Card\b|Online\s+Purchase(?:\s+Card)?\b|'
  r'Online\s+Pre[-\s]?Auth\b|Please\s+use\s+the\s+code\b|'
  r'Declined\s+Transaction\b))',caseSensitive:false),'\n');
 clean=clean.replaceAll(RegExp(
  r'(?<=[A-Za-z0-9.])(?=(?:JOD|AED|SAR|KWD|BHD|OMR)\s*'
  r'[0-9][0-9,]*(?:\.[0-9]{1,3})?\s+has\s+been\s+'
  r'(?:credited|debited)\b)',caseSensitive:false),'\n');
 // Bank SMS messages often start with a transaction heading, even without dates.
 // Separate all posted and unposted notices by header, without relying
 // on blank lines (which also occur *inside* one bank SMS).
 final heading=RegExp(
  r'^\s*(?:(?:JOD|AED|SAR|KWD|BHD|OMR)\s*[0-9][0-9,]*(?:\.[0-9]{1,3})?\s+has\s+been\s+(?:credited|debited)|[0-9][0-9,.]*\s+(?:AED|JOD|SAR)\s+debited\s+from\s+account|Online\s+Purchase(?:\s+Card)?|Online\s+Pre[-\s]?Auth|Pre[-\s]?Authori[sz]ation|Please\s+use\s+the\s+code|Verification\s+Code|OTP\b|Declined\s+Transaction|Transaction\s+Declined|Failed\s+Transaction|Transaction\s+Failed|Unsuccessful\s+Transaction|Incoming\s+Transfer|Outgoing\s+Transfer|Transfer\s+(?:Received|Sent|In|Out|To)|Funds\s+Received|Money\s+(?:Received|Sent)|Account\s+Credited|Salary\s+(?:Credit|Deposit)|Cash\s+Deposit|Refund|Reversal\s+Credit|ATM\s+Withdrawal|Cash\s+Withdrawal|Bill\s+Payment|Direct\s+Debit|Payment\s+(?:Completed|Successful)|Card\s+(?:Purchase|Payment)|Credit\s+Card\s+Purchase|POS|شراء(?:\s+PoS)?|حوال[ةه]|تحويل|إيداع|ايداع|راتب|سحب|دفع|نقاط بيع|Purchase|Debit|Credit)(?=\s|$|[:：])',
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

/// Fit searchable dialogs into the actual viewport after the Android keyboard
/// opens. Fixed fractions of the *full* screen caused RenderFlex overflow.
double waffraKeyboardDialogListHeight(BuildContext context,{
 double desired=490,double reserved=190,
}){
 final media=MediaQuery.of(context);
 final usable=media.size.height-media.viewInsets.bottom-
  media.padding.top-media.padding.bottom;
 return min(desired,max(110.0,usable-reserved));
}

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
/// Saudi edition accepts national 05 numbers, plus the existing Saudi E.164
/// storage representation for backward-compatible Google profiles.
String? waffraGoogleProfilePhoneError(String? value){
 if((value??'').trim().isEmpty)return waffraRequiredFieldMessage;
 return WaffraSaudiMobile.isSupportedStored(value)?null:
  (waffraIsEnglish?'Use a 10-digit Saudi number starting with 05':
    'رقم الجوال السعودي يجب أن يبدأ بـ 05 ويتكون من 10 أرقام');
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
 // OS biometric UI may report success while Flutter is briefly inactive.
 // Keep that success pending only until the app resumes; never reveal while
 // backgrounded, and discard it if the app actually pauses or detaches.
 bool _biometricVerifiedAwaitingResume=false;
 bool googleFirstRunSetup=false;
 bool autoSmsConsentPending=false;
 // True only after a new account was saved or a password challenge passed.
 // A restored session must unlock before its first SMS permission request.
 bool _smsConsentAfterVerifiedSignIn=false;
 // M623: Keep the actual preceding authenticated screen mounted until the
 // complete owner-verified Home can paint. Never replace its wait with black.
 bool _m623HomeReady=false;
 // M663: first credential-verified registration can prepare the real hidden
 // Home while consent/biometric UI is active. No root data/zero is fabricated.
 bool _m663OnboardingHomePreload=false;
 bool _m663PreloadedFinanceReady=false;
 void _m663RevealPreloadedHome(){
  // Only a signed-in, foreground-authenticated owner can show verified Home.
  if(!mounted||locked||showLogin||autoSmsConsentPending||
     (googleFirstRunSetup&&WaffraSaudiRelease.locationCountryOnboarding))return;
  if(_m663PreloadedFinanceReady){
   setState((){_m623HomeReady=true;_m623RetainedStage=null;});
  }
 }
 String? _m623RetainedStage;
 // M627: one Home State per authenticated session, stable across locale.
 int _m627HomeSession=0;
 GlobalKey<_HomeScreenState> _m627HomeKey=GlobalKey<_HomeScreenState>(debugLabel:'home-session-0');
 // M631: speculative BIND only, never decrypt/paint balances before biometric.
 Person? _m631PrewarmOwner;
 int? _m631PrewarmSession;
 Future<WaffraProductionFinanceAuthorityBinding?>? _m631PrewarmBinding;
 bool _m631PrewarmClaimed=false;
 void _m631StartFinancePrewarm(Person owner){
  if(!mounted||_logoutInProgress||_m631PrewarmBinding!=null||
     !identical(profile,owner))return;
  final session=_m627HomeSession;
  final clock=kProfileMode?(Stopwatch()..start()):null;
  _m631PrewarmOwner=owner;
  _m631PrewarmSession=session;
  _m631PrewarmClaimed=false;
  // Successful credentials/profile verification precedes this non-awaited bind.
  _m631PrewarmBinding=()async{
   try{
    final binding=await WaffraProductionFinanceAuthorityBinding.bind(
     installedApp:true,deferInitialDashboardRead:true,
     legacy:const WaffraHomeFinancePersistence(),
     startupRoute:WaffraFinanceRoute.appStartup);
    if(!mounted||_logoutInProgress||!identical(profile,owner)||
       _m627HomeSession!=session){
     await binding.close();
     return null;
    }
    if(kProfileMode&&clock!=null){
     debugPrint('WAFFRA_AUTH_PERF prewarm_bind_ms=${clock.elapsedMilliseconds}');
    }
    return binding;
   }catch(_){
    if(kProfileMode)debugPrint('WAFFRA_AUTH_PERF prewarm_bind_unavailable');
    // Home will retry its original authenticated SQLCipher binding.
    return null;
   }
  }();
 }
 Future<WaffraProductionFinanceAuthorityBinding?>? _m631ClaimFinancePrewarm(
  Person owner){
  if(_m631PrewarmClaimed||!identical(_m631PrewarmOwner,owner)||
     _m631PrewarmSession!=_m627HomeSession||_logoutInProgress)return null;
  final pending=_m631PrewarmBinding;
  if(pending!=null)_m631PrewarmClaimed=true;
  return pending;
 }
 Future<void> _m631CloseUnusedPrewarm({bool includeClaimed=false})async{
  if(_m631PrewarmClaimed&&!includeClaimed)return;
  final pending=_m631PrewarmBinding;
  _m631PrewarmBinding=null;_m631PrewarmOwner=null;
  _m631PrewarmSession=null;_m631PrewarmClaimed=false;
  if(pending==null)return;
  final binding=await pending;
  if(binding!=null)await binding.close();
 }
 // Profile-mode handoff timings; never log identity or financial values.
 Stopwatch? _m625HandoffClock;
 String? _m625HandoffOrigin;
 void _m625TraceHandoff(String origin){
  if(!kProfileMode)return;
  _m625HandoffOrigin=origin;
  _m625HandoffClock=Stopwatch()..start();
 }
 // M624: native SMS must never compete with owner-verified first Home paint.
 // Logout awaits an already running resume before disabling SMS capture.
 Future<bool>? _m624SmsResumeInFlight;
 Future<bool> _m624ResumeSmsAfterRealHome(Person expectedOwner)async{
  bool ownerIsActive()=>mounted&&identical(profile,expectedOwner)&&
   !showLogin&&!locked&&!autoSmsConsentPending&&
   !_logoutInProgress&&_m623HomeReady;
  if(!Platform.isAndroid||!ownerIsActive())return false;
  final previous=_m624SmsResumeInFlight;
  if(previous!=null){
   await previous;
   return ownerIsActive();
  }
  final running=()async{
   try{
    final resumed=await WaffraAutoSms.resumeAfterSignIn();
    if(resumed&&ownerIsActive())waffraAutoSmsUpdates.value++;
   }catch(error){
    debugPrint('Post-Home native SMS resume failed: ${error.runtimeType}');
   }
   // Inbox review is independent of native resume result, but not of owner.
   return ownerIsActive();
  }();
  _m624SmsResumeInFlight=running;
  try{return await running;}
  finally{
   if(identical(_m624SmsResumeInFlight,running)){
    _m624SmsResumeInFlight=null;
   }
  }
 }
 void _m623HomeLoaded(Person expectedOwner){
  if(kProfileMode){
   debugPrint('WAFFRA_HOME_LOAD_STEP first_m623HomeLoaded elapsed_ms='
    '${_m625HandoffClock?.elapsedMilliseconds??-1}');
  }
  final current=profile;
  if(!mounted||current==null||showLogin||
     current.provider!=expectedOwner.provider||
     current.phone!=expectedOwner.phone||current.email!=expectedOwner.email)return;
  // The hidden, owner-verified Home may finish while first-run permission
  // and biometric UI is still active. Remember readiness but NEVER reveal
  // it until the biometric gate and every consent step were completed.
  if(_m663OnboardingHomePreload&&(locked||autoSmsConsentPending)){
   _m663PreloadedFinanceReady=true;
   if(kProfileMode)debugPrint('WAFFRA_AUTH_PERF m663_hidden_home_ready=true');
   return;
  }
  if(locked||autoSmsConsentPending)return;
  setState((){_m623HomeReady=true;_m623RetainedStage=null;});
  final stopwatch=_m625HandoffClock;
  final origin=_m625HandoffOrigin;
  _m625HandoffClock=null;_m625HandoffOrigin=null;
  if(kProfileMode&&stopwatch!=null&&origin!=null){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted&&_m623HomeReady&&identical(profile,expectedOwner)){
     debugPrint('WAFFRA_AUTH_PERF ${origin}_to_home_first_frame_ms='
      '${stopwatch.elapsedMilliseconds}');
    }
   });
  }
 }
 String appearance='light';
 bool introDone=false;
 int _greetingCycle=0;
 bool _greetingCycleInitialized=false;
 final WaffraDoubleBackExit _doubleBackExit=WaffraDoubleBackExit();
 String language='ar';
 String? pinHash;Person? profile;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);
  WaffraRegionalCopy.countryIso.addListener(_onRegionChanged);load();launchIntro();
  // Prime only public resources after the splash's first frame. Never block
  // rendering, login verification, biometric gating or SQLCipher ownership.
  WidgetsBinding.instance.addPostFrameCallback((_){
   WaffraPublicStartupPrewarm.prime();
  });
 }
 void _onRegionChanged(){if(mounted)setState((){});}
 Future<void> launchIntro()async{
  // Startup finance initialization runs independently. The actual splash
  // animation owns when the wordmark can disappear; one frame is not enough.
  await WidgetsBinding.instance.endOfFrame;
 }
 void _m632SplashCompleted(){
  if(!mounted||introDone)return;
  if(kProfileMode)debugPrint('WAFFRA_SPLASH_PERF animation_complete');
  setState(()=>introDone=true);
 }
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.resumed){
   // Only release a biometric gate that succeeded while OS was inactive.
   if(_biometricVerifiedAwaitingResume){
    _biometricVerifiedAwaitingResume=false;
    if(mounted&&locked&&profile!=null&&!showLogin){
     _m625TraceHandoff('biometric');
     setState(()=>locked=false);
     _m663RevealPreloadedHome();
    }
   }
   return;
  }
  // Native camera and gallery picker are trusted short-lived OS activities;
  // the opaque overlay still protects previews without resetting a draft.
  if(WaffraExternalMediaSession.trustedBackgroundTransition(state))return;
  if(WaffraBiometricSessionGuard.mustLockOn(state)){
   _biometricVerifiedAwaitingResume=false;
   // DO NOT set locked=true here. The idle overlay handles the actual
   // 60-second absence without tearing down the entire Home Navigator.
   // Fresh login and explicit signed-out states retain the mandatory gate.
  }
 }
 @override void dispose(){WaffraRegionalCopy.countryIso.removeListener(_onRegionChanged);
  WidgetsBinding.instance.removeObserver(this);
  // Home owns claimed bindings; root closes only unclaimed preparation.
  unawaited(_m631CloseUnusedPrewarm(
   includeClaimed:_m627HomeKey.currentState==null));
  super.dispose();}
 String? startupError;
 Future<void> load()async {
  try {
   final p=await SharedPreferences.getInstance().timeout(const Duration(seconds:15));
   final startup=await WaffraProductionFinanceAuthorityBinding.bind(
    installedApp:true,
    legacy:const WaffraHomeFinancePersistence());
   try {
    if(!startup.encrypted)await const WaffraLiveLegacyFinanceGuard().requireLegacySource(p);
   } finally {await startup.close();}
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
    googleFirstRunSetup=WaffraSaudiRelease.locationCountryOnboarding&&
     waffraGoogleProfileReadyForCountrySetup(u)&&
      !(p.getBool(waffraCountrySetupKey(u!))??false);
    autoSmsConsentPending=Platform.isAndroid&&u!=null&&
     !(p.getBool(WaffraAutoSms.firstRunKey)??false);
    pinHash=p.getString('waffra_pin_sha256');
    locked=u!=null;startupError=null;loading=false;
    _m623HomeReady=false;
    _m623RetainedStage=u==null?null:'biometric';
   });
   // Restored session already passed startup source verification.
   // Prepare the connection, NOT financial data, during biometric gating.
   if(u!=null)_m631StartFinancePrewarm(u);
  }catch(e){
   debugPrint('Waffra startup failed: $e');
   if(mounted)setState((){startupError=e.toString();loading=false;});
  }
 }
 Future<void> finishSmsPermissionChoice()async{
  final p=await SharedPreferences.getInstance();
  if(!await p.setBool(WaffraAutoSms.firstRunKey,true)){
   throw StateError('Could not persist SMS onboarding decision');
  }
  if(mounted)setState((){
   autoSmsConsentPending=false;
   _smsConsentAfterVerifiedSignIn=false;
   // If permissions followed biometric unlock, retain THIS existing screen.
   if(!locked){_m623RetainedStage='consent';_m623HomeReady=false;}
  });
 }
 Future<void> intro()async {
  final p=await SharedPreferences.getInstance();await p.setBool('waffra_onboarding_completed',true);
  if(mounted)setState((){onboarded=true;showLogin=true;});
 }
 // The live account/profile writer must never bypass the same source lock
 // held by Home and the independent Android Widget finance engine.
 final WaffraLiveAccountWriteAuthority _accountWriteAuthority=
     const WaffraLiveAccountWriteAuthority();
 // Verified-login proof is the exact non-shared Person instance returned
 // after a successful phone-bound OS + PBKDF2 password check.
 Person? _verifiedPhoneLoginProof;
 Future<void> _saveVerifiedPhoneLogin(Person u)async{
  if(u.provider.toLowerCase().trim()!='phone'||
     _verifiedPhoneLoginProof!=null){
   throw StateError('Invalid verified phone login handoff');
  }
  _verifiedPhoneLoginProof=u;
  try{await saveUser(u);}
  finally{
   if(identical(_verifiedPhoneLoginProof,u))_verifiedPhoneLoginProof=null;
  }
 }
 Future<void> saveUser(Person u)async {
  final profileCommitClock=kProfileMode?(Stopwatch()..start()):null;
  // M513: refuse to declare a new phone profile successfully registered if
  // Android never retained a verifier for that exact account. Keeping the
  // existing login password usable is part of successful account creation.
  if(u.provider.toLowerCase().trim()=='phone'&&
     !identical(_verifiedPhoneLoginProof,u)){
   // M617: onboarding and profile edits still check fresh OS keystore.
   // Password sign-in just passed the exact phone-bound OS+PBKDF2 verifier.
   final phone=WaffraSaudiMobile.inputFromStored(u.phone);
   final integrity=await WaffraLocalPhoneCredentials.probeForPhone(phone);
   if(integrity!=WaffraLocalCredentialProbe.ready){
    final existing=await SharedPreferences.getInstance();
    final hasLegacy=existing.getString('waffra_local_password_salt')!=null&&
     existing.getString('waffra_local_password_hash')!=null;
    if(integrity!=WaffraLocalCredentialProbe.missing||!hasLegacy){
     throw StateError('phone_credential_not_persisted_for_profile');
    }
   }
  }
  final profileGuardMs=profileCommitClock?.elapsedMilliseconds;
  // Profile edits cannot silently detach the stored phone/password verifier.
  if(profile!=null&&profile!.provider.toLowerCase()=='phone'&&
     u.provider.toLowerCase()=='phone'&&profile!.phone!=u.phone){
   throw StateError('Changing a sign-in phone requires verified account migration');
  }
  // Capture signed-out state before profile write clears it.
  final prefs=await SharedPreferences.getInstance();
  final ordinaryPhoneRelogin=profile==null&&showLogin&&
   u.provider.toLowerCase().trim()=='phone'&&
   (prefs.getBool('waffra_signed_out_explicitly')??false);
  await _accountWriteAuthority.saveProfile(
   profileJson:jsonEncode(u.toJson()),
   registeredProfileJson:u.phone.trim().isNotEmpty?jsonEncode(u.toJson()):null,
   loginMethod:u.provider.toLowerCase().contains('google')?'Google':
    u.provider.toLowerCase().contains('apple')?'Apple':
    u.phone.trim().isNotEmpty?'Phone':'Local',
   email:u.email.trim().isNotEmpty?u.email.trim():null,
   phone:u.phone.trim().isNotEmpty?u.phone.trim():null,
  );
  if(kProfileMode&&profileCommitClock!=null){
   // Profile stage timings only; no phone/password/owner identifiers.
   debugPrint('WAFFRA_AUTH_PERF post_login_profile_guard_ms='
    '${profileGuardMs??-1} profile_persist_ms='
    '${profileCommitClock.elapsedMilliseconds}');
  }
  // Resume native SMS after the verified authenticated frame, not here.
  final needsGoogleSetup=WaffraSaudiRelease.locationCountryOnboarding&&
   waffraGoogleProfileReadyForCountrySetup(u)&&
    !(prefs.getBool(waffraCountrySetupKey(u))??false);
  final needsSmsAccessAfterRegistration=Platform.isAndroid&&profile==null&&
   !(prefs.getBool(WaffraAutoSms.firstRunKey)??false);
  final shouldPrewarmNewSession=profile==null||showLogin;
  if(mounted)setState((){
   if(needsSmsAccessAfterRegistration)autoSmsConsentPending=true;
   // Once the account has been verified, first-run permissions precede
   // the biometric gate. This does NOT apply to a restored, locked session.
   _smsConsentAfterVerifiedSignIn=needsSmsAccessAfterRegistration;
   // First-run and restored protected sessions retain biometrics; an
   // ordinary verified password re-login must not prompt for it again.
   final freshSession=profile==null||showLogin;
   profile=u;showLogin=false;googleFirstRunSetup=needsGoogleSetup;
   if(freshSession)locked=!ordinaryPhoneRelogin;
   if(freshSession){
    _m623HomeReady=false;
    _m623RetainedStage=locked?'biometric':'login';
    _m663PreloadedFinanceReady=false;
    // A credential-verified first registration is the ONLY time we may
    // prepare the hidden owner Home before the first biometric gate.
    // Explicit logout/login and restored sessions never use this path.
    _m663OnboardingHomePreload=needsSmsAccessAfterRegistration&&
     !ordinaryPhoneRelogin;
   }
  });
  // Password verification and protected profile write have succeeded.
  if(mounted&&shouldPrewarmNewSession)_m631StartFinancePrewarm(u);
  // Repeat phone login deliberately skips the second biometric gate;
  // trace the verified-password-to-authentic-Home transition.
  if(mounted&&ordinaryPhoneRelogin&&!locked&&!autoSmsConsentPending){
   _m625TraceHandoff('relogin');
  }
  // M624: do not start native SMS I/O on the login/biometric handoff.
  // Verified Home resumes capture after its first real painted frame
  // and BEFORE the initial encrypted inbox review.
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
  if(mounted)setState((){
   googleFirstRunSetup=false;
   if(!locked){_m623HomeReady=false;_m623RetainedStage='country';}
  });
 }
 Future<void> logout()async {
  if(_logoutInProgress)return;
  _logoutInProgress=true;
  final logoutTiming=kProfileMode?(Stopwatch()..start()):null;
  // The existing Yes/No dialog is the only user confirmation. On Yes,
  // paint immediate feedback before slow OS/SQLCipher/native shutdown, and
  // block new taps until the owner-bound finance session is safely signed out.
  final overlay=_logoutNavigatorKey.currentState?.overlay;
  if(overlay!=null){
   final progress=OverlayEntry(builder:(context)=>Positioned.fill(
    child:Stack(children:[
     const ModalBarrier(dismissible:false,color:Color(0xB3073F31)),
     Center(child:Material(color:Colors.transparent,
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       const RepaintBoundary(child:SizedBox(width:32,height:32,
        child:CircularProgressIndicator(strokeWidth:2.5,
         valueColor:AlwaysStoppedAnimation<Color>(Colors.white)))),
       const SizedBox(height:12),
       WaffraText(waffraIsEnglish?'Signing out...':'جارٍ تسجيل الخروج',
        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
      ]))),
    ])));
   _logoutProgressEntry=progress;
   overlay.insert(progress);
  }
  try{
   if(_logoutProgressEntry!=null){
    await WidgetsBinding.instance.endOfFrame;
   }
  // M545: Yes/No is the entire logout UX. NEVER open a recovery/password
  // dialog on sign-out. Existing secure credentials remain unchanged.
  // If an older APK missed the verifier, silently stage a one-time
  // OS-protected handoff; the next LOGIN (not logout) challenges biometrics.
  // If staging fails, keep this session intact rather than lock out finance.
  final current=profile;
  if(current!=null&&current.provider.toLowerCase().trim()=='phone'){
   final phone=WaffraSaudiMobile.inputFromStored(current.phone);
   WaffraLocalCredentialProbe integrity;
   try{
    integrity=await WaffraLocalPhoneCredentials.probeForPhone(phone)
     .timeout(const Duration(seconds:12));
   }catch(_){integrity=WaffraLocalCredentialProbe.malformed;}
   if(integrity!=WaffraLocalCredentialProbe.ready){
    final prefs=await SharedPreferences.getInstance();
    final hasLegacy=prefs.getString('waffra_local_password_salt')!=null&&
     prefs.getString('waffra_local_password_hash')!=null;
    if(!hasLegacy){
     if(integrity==WaffraLocalCredentialProbe.missing){
     var staged=false;
     try{
      staged=await WaffraBiometrics.isAvailable()&&
       await WaffraLocalPhoneCredentials.stageSignOutRecoveryGrant(phone)
         .timeout(const Duration(seconds:12));
     }catch(_){staged=false;}
     if(!staged){
      if(mounted)_showLogoutFeedback(waffraIsEnglish?
       'Cannot safely sign out yet. Your data and current session are unchanged.':
       'تعذر تأمين الرجوع للحساب؛ لم يتم تسجيل الخروج وبياناتك محفوظة.',
       isError:true);
      return;
     }
     }else{
     if(mounted)_showLogoutFeedback(waffraIsEnglish?
      'Cannot safely sign out with damaged or mismatched account credentials. Your data is unchanged.':
      'بيانات الدخول الآمنة تالفة أو لا تخص هذا الحساب؛ لم يتم تسجيل الخروج وبياناتك محفوظة.',
      isError:true);
     return;
     }
    }
    if(hasLegacy&&integrity!=WaffraLocalCredentialProbe.missing){
     if(mounted)_showLogoutFeedback(waffraIsEnglish?
      'Secure credentials are corrupt or bound to another account; sign-out was cancelled.':
      'بيانات الدخول الآمنة تالفة أو لحساب مختلف؛ لم يتم تسجيل الخروج.',
      isError:true);
     return;
    }
   }
  }
  // M624: a scheduled or in-flight Home SMS resume cannot overtake
  // native capture suspension and re-enable banking SMS after sign-out.
  final pendingSmsResume=_m624SmsResumeInFlight;
  if(pendingSmsResume!=null)await pendingSmsResume;
  // Stop capture BEFORE removing profile. Keep this account's encrypted
  // pending review. If the new native bridge is unavailable, fail closed by
  // using explicit disable; never silently sign out with collection enabled.
  if(Platform.isAndroid){
   final paused=await WaffraAutoSms.suspendForSignOut().timeout(
    const Duration(seconds:12),onTimeout:()=>false);
   if(!paused&&!await WaffraAutoSms.disable().timeout(
    const Duration(seconds:12),onTimeout:()=>false)){
    throw StateError('Could not safely suspend bank SMS before sign-out');
   }
  }
  // M629: verified pull refresh proves independent jobs can be coalesced
  // without blocking each other. AI teardown and Home finance shutdown do
  // not depend on each other, so overlap them, but WAIT FOR BOTH before
  // deleting the account session. Future.wait rejects failures; signout
  // remains fail-closed, with native SMS already suspended above.
  final closingHome=_m627HomeKey.currentState;
  Future<void> closeHomeFinance()async{
   if(closingHome!=null){
    await closingHome._m627CloseForLogout();
    await _m631CloseUnusedPrewarm();
   }else{
    // Logout from biometric or a build/mount race still closes the opener.
    await _m631CloseUnusedPrewarm(includeClaimed:true);
   }
  }
  // M636: retired model has no logout resources; keep full verified finance close.
  await closeHomeFinance();
  await _accountWriteAuthority.signOut();
  // Clear the single progress notice before switching to the signed-out UI.
  if(mounted)waffraDismissFooterNotice();
  if(mounted)_logoutFeedbackKey.currentState?.clearSnackBars();
  if(mounted)setState((){
   profile=null;showLogin=true;locked=true;googleFirstRunSetup=false;
   _m623HomeReady=false;_m623RetainedStage=null;
   _m663OnboardingHomePreload=false;_m663PreloadedFinanceReady=false;
   _m627HomeSession++;
   _m631PrewarmBinding=null;_m631PrewarmOwner=null;
   _m631PrewarmSession=null;_m631PrewarmClaimed=false;
   _m627HomeKey=GlobalKey<_HomeScreenState>(
    debugLabel:'home-session-$_m627HomeSession');
   _m625HandoffClock=null;_m625HandoffOrigin=null;
  });
  }catch(error){
   // A failed logout must keep protected recovery/retry usable, never leave
   // the old Home indefinitely marked as closing with a dead Retry button.
   _m627HomeKey.currentState?._m627AbortFailedLogout();
   // Every sign-out entry point shares this fail-closed feedback. An SMS
   // suspension or credential-integrity failure must NOT look like logout.
   debugPrint('Verified sign-out was not completed: ${error.runtimeType}');
   if(mounted)_showLogoutFeedback(waffraIsEnglish?
    'Could not safely sign out. Your financial data is unchanged; retry.':
    'تعذر تسجيل الخروج بأمان. بياناتك المالية لم تتغير؛ حاول مرة أخرى.',
    isError:true);
  }finally{
   // Never strand a blocking veil after success OR a fail-closed error.
   final progress=_logoutProgressEntry;
   _logoutProgressEntry=null;
   progress?.remove();
   progress?.dispose();
   _logoutInProgress=false;
   if(kProfileMode&&logoutTiming!=null){
    debugPrint('WAFFRA_AUTH_PERF sign_out_ms=${logoutTiming.elapsedMilliseconds}');
   }
  }
 }
 bool _logoutInProgress=false;
 OverlayEntry? _logoutProgressEntry;
 final _logoutFeedbackKey=GlobalKey<ScaffoldMessengerState>();
 final _logoutNavigatorKey=GlobalKey<NavigatorState>();
 void _showLogoutFeedback(String message,{bool isError=false}){
  // The app-level State context is above MaterialApp. The Navigator context
  // is below its ScaffoldMessenger/Theme and can use the SAME public notice
  // presenter as every other Waffra screen. Never create a second snackbar.
  final feedbackContext=_logoutNavigatorKey.currentContext;
  if(feedbackContext==null)return;
  snack(feedbackContext,message,
   isError:isError,
   kind:isError?WaffraSnackKind.error:WaffraSnackKind.info,
   preferFooter:true,
   duration:Duration(seconds:isError?8:5));
 }
 Future<void> setPin(String? value)async {
  final hash=value==null?null:sha256.convert(utf8.encode(value)).toString();
  await _accountWriteAuthority.replacePinVerifier(hash);
  if(mounted)setState((){
   pinHash=hash;
   locked=false;
  });
  _m663RevealPreloadedHome();
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

 // M623: authenticate on the ORIGINAL screen. Build verified Home offstage
 // after successful access, then swap the complete real dashboard in a single
 // frame. No fake balances, skeleton, spinner, blank/black intermediate page
 // or duplicate biometric challenge is introduced.
 Widget _m623RootContent(BuildContext rootContext){
  final account=profile;
  final needsLogin=account==null||showLogin||
   ((account.phone.trim().isEmpty)&&
     (account.provider.toLowerCase().contains('local')||
      account.provider.contains('محلي')||
      account.provider.toLowerCase().contains('guest')||
      account.provider.toLowerCase().contains('demo')));
  final firstConsent=!needsLogin&&autoSmsConsentPending&&
   _smsConsentAfterVerifiedSignIn;
  final needsGate=!needsLogin&&!firstConsent&&locked;
  final laterConsent=!needsLogin&&!firstConsent&&!needsGate&&autoSmsConsentPending;
  final needsCountry=!needsLogin&&!firstConsent&&!needsGate&&!laterConsent&&
   googleFirstRunSetup&&WaffraSaudiRelease.locationCountryOnboarding;
  final canShowHome=!needsLogin&&!firstConsent&&!needsGate&&
   !laterConsent&&!needsCountry;
  // M663: offstage mount is restricted to a NEW credential-verified signup.
  // The visible gate remains mounted and receives every user interaction.
  final canMountHome=canShowHome||
   (_m663OnboardingHomePreload&&!needsLogin&&!needsCountry);
  final homeInteractive=canShowHome&&_m623HomeReady;
  final beforeReady=canShowHome&&!_m623HomeReady;
  final showLoginScreen=needsLogin||(beforeReady&&_m623RetainedStage=='login');
  final showConsent=firstConsent||laterConsent||
   (beforeReady&&_m623RetainedStage=='consent');
  final showGate=needsGate||(beforeReady&&_m623RetainedStage=='biometric');
  final showCountry=needsCountry||
   (beforeReady&&_m623RetainedStage=='country');
  return Stack(fit:StackFit.expand,children:[
   if(showLoginScreen)KeyedSubtree(
    key:const ValueKey('m623-login-stage'),
    child:IgnorePointer(ignoring:!needsLogin,
     child:LoginScreen(onSave:saveUser,
      onVerifiedPasswordSave:_saveVerifiedPhoneLogin))),
   if(showConsent)KeyedSubtree(
    key:const ValueKey('m623-consent-stage'),
    child:IgnorePointer(ignoring:!firstConsent&&!laterConsent,
     child:WaffraAutoSmsConsentPage(
      english:language=='en',onComplete:finishSmsPermissionChoice))),
   if(showGate)KeyedSubtree(
    key:const ValueKey('m623-biometric-stage'),
    child:IgnorePointer(ignoring:!needsGate,
     child:WaffraMandatoryBiometricGate(
      english:language=='en',
      onVerified:(){
       if(!mounted||!locked||profile==null||showLogin)return;
       final lifecycle=WidgetsBinding.instance.lifecycleState;
       if(WaffraBiometricSessionGuard.canReveal(
        authenticated:true,inForeground:lifecycle==AppLifecycleState.resumed)){
        _biometricVerifiedAwaitingResume=false;
        _m625TraceHandoff('biometric');
        setState(()=>locked=false);
        _m663RevealPreloadedHome();
       }else if(lifecycle==AppLifecycleState.inactive){
        _biometricVerifiedAwaitingResume=true;
       }
      },
      onSignOut:logout))),
   if(showCountry)KeyedSubtree(
    key:const ValueKey('m623-country-stage'),
    child:IgnorePointer(ignoring:!needsCountry,
     child:WaffraCountryFirstRunPage(
      english:language=='en',onComplete:completeGoogleCountrySetup,
      onCountryConfirmed:setUiCountry))),
   if(canMountHome)KeyedSubtree(
    key:ValueKey('home-$_m627HomeSession'),
    child:Offstage(offstage:!homeInteractive,
     child:TickerMode(enabled:homeInteractive,child:HomeScreen(
      // Stable across language changes; rotated on explicit sign-out only.
      key:_m627HomeKey,
      profile:account,
      prewarmedFinanceBinding:_m631ClaimFinancePrewarm(account),
      onVerifiedReady:()=>_m623HomeLoaded(account),
      postAuthVisible:homeInteractive,
      onVerifiedHomeSmsResume:()=>_m624ResumeSmsAfterRealHome(account),
      dark:appearance=='dark'||(appearance=='system'&&
       MediaQuery.platformBrightnessOf(rootContext)==Brightness.dark),
      appearance:appearance,onAppearance:setAppearance,onTheme:theme,
      onLanguage:setLanguage,onLogout:logout,onProfile:saveUser,onSetPin:setPin,
      pinEnabled:pinHash!=null,greetingIndex:_greetingCycle)))),
  ]);
 }
 @override Widget build(BuildContext context)=>MaterialApp(
  scaffoldMessengerKey:_logoutFeedbackKey,
  navigatorKey:_logoutNavigatorKey,
  scrollBehavior:const WaffraVisibleScrollBehavior(),
  debugShowCheckedModeBanner:false,title:'وفرة | Waffra',
  locale:language=='en'?const Locale('en','US'):
   WaffraRegionalCopy.arabicCountrySubtag.isEmpty?const Locale('ar'):
    Locale('ar',WaffraRegionalCopy.arabicCountrySubtag),
  supportedLocales:const [Locale('ar'),Locale('ar','SA'),Locale('ar','EG'),Locale('en','US')],
  localizationsDelegates:const [
   GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,
   GlobalCupertinoLocalizations.delegate,
  ],
  // One existing MaterialApp.builder: keep finance masking and RTL/LTR,
  // and place idle biometric overlay ABOVE every Navigator route.
  builder:(context,child)=>WaffraNoticeTapDismissArea(
   child:WaffraIdleBiometricOverlay(
   enabled:profile!=null&&!locked&&!showLogin&&
    !loading&&introDone&&startupError==null&&
    !autoSmsConsentPending&&
    !(googleFirstRunSetup&&WaffraSaudiRelease.locationCountryOnboarding),
   english:language=='en',onSignOut:logout,
   child:ValueListenableBuilder<bool>(
    valueListenable:hideWaffraAmounts,
   builder:(context,hidden,_)=>Directionality(
    textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
    // Language is an immediate LTR/RTL layout change, never a
    // navigator replacement or whole-screen slide of the FAB.
    child:child??const SizedBox.shrink())))),

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
   expansionTileTheme:const ExpansionTileThemeData(
    shape:RoundedRectangleBorder(side:BorderSide.none),
    collapsedShape:RoundedRectangleBorder(side:BorderSide.none)),
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
   expansionTileTheme:const ExpansionTileThemeData(
    shape:RoundedRectangleBorder(side:BorderSide.none),
    collapsedShape:RoundedRectangleBorder(side:BorderSide.none)),
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
  },child:Directionality(textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
   child:AnimatedSwitcher(
    duration:waffraMotion(420),
    switchInCurve:Curves.easeOutCubic,
    switchOutCurve:Curves.easeInCubic,
    // M636: natural splash-to-auth crossfade; do not delay the finished
    // native intro, password verification, or the authenticated Home.
    child:(loading||!introDone)?WaffraLaunchIntro(onFinished:_m632SplashCompleted):
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
   _m623RootContent(rootContext))))));
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
 final VoidCallback? onFinished;
 const WaffraLaunchIntro({super.key,this.onFinished});
 @override State<WaffraLaunchIntro> createState()=>_WaffraLaunchIntroState();
}
class _WaffraLaunchIntroState extends State<WaffraLaunchIntro> with SingleTickerProviderStateMixin {
 late final AnimationController controller;
 bool _completionSent=false;
 @override void initState(){
  super.initState();
  controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1650));
  controller.addStatusListener((status){
   if(status==AnimationStatus.completed&&!_completionSent){
    _completionSent=true;
    widget.onFinished?.call();
   }
  });
  controller.forward();
 }
 @override void dispose(){controller.dispose();super.dispose();}
 double reveal(double t,double start,double end)=>((t-start)/(end-start)).clamp(0.0,1.0);
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFF003C2E),
  body:AnimatedBuilder(animation:controller,builder:(ctx,_){
   final t=controller.value;
   final iconProgress=Curves.easeOutBack.transform(reveal(t,.02,.28));
   // Reveal the full bilingual wordmark earlier; it remains readable until
   // the genuine animation completion before the auth route becomes visible.
   final nameProgress=Curves.easeOutCubic.transform(reveal(t,.12,.33));
   final sloganProgress=Curves.easeOutCubic.transform(reveal(t,.28,.51));
   // Loading may legitimately outlive the animation; retain the complete
   // bilingual logo instead of fading to a blank green screen.
   const fadeOut=1.0;
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
 // Retained for the planned localized native onboarding fallback.
 // ignore: unused_field
 static const titleAr=<String>[
  'إدارة أموالك\nبكل سهولة',
  'سجّل معاملاتك\nبسهولة',
  'افهم نمط\nإنفاقك',
  'حقق أهدافك\nالمالية',
 ];
 // Retained for the planned localized native onboarding fallback.
 // ignore: unused_field
 static const subtitleAr=<String>[
  'تابع دخلك ومصروفاتك بسهولة\nوشوف رصيدك الحالي دائمًا.',
  'انسخ رسائلك البنكية والصقها في وفرة،\nونساعدك تصنّف معاملاتك تلقائيًا.',
  'اكتشف عادات صرفك من خلال\nرسوم بيانية وتقارير واضحة وسهلة الفهم.',
  'سواء تدخر لمنزل، سيارة، سفر أو أي هدف آخر.\nحدد هدفك وتابع تقدمك بكل سهولة.',
 ];
 // Retained for the planned localized native onboarding fallback.
 // ignore: unused_field
 static const titleEn=<String>[
  'All your transactions\nin one place',
  'Paste your messages,\nwe handle the rest',
  'Simple analytics,\nsmarter decisions',
  'Reach your goals\nstep by step',
 ];
 // Retained for the planned localized native onboarding fallback.
 // ignore: unused_field
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
 @override Widget build(BuildContext context)=>Scaffold(
  key:const Key('waffra-first-run-auth-choice'),
  backgroundColor:forest,
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
      key:const Key('waffra-auth-choice-create'),
      onPressed:WaffraHaptics.tap(busy?null:()=>proceed(false)),
      style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
      child:WaffraText(waffraIsEnglish?'Create account':'إنشاء حساب',
       style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)))),
     const SizedBox(height:12),
     SizedBox(width:double.infinity,height:52,child:OutlinedButton(
      key:const Key('waffra-auth-choice-sign-in'),
      onPressed:WaffraHaptics.tap(busy?null:()=>proceed(true)),
      style:OutlinedButton.styleFrom(foregroundColor:Colors.white,
       side:const BorderSide(color:Colors.white70)),
      child:WaffraText(waffraIsEnglish?'Sign in':'تسجيل الدخول',
       style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600)))),
     const SizedBox(height:15),
     const WaffraText('🔒 بياناتك المالية محفوظة على جهازك',
      style:TextStyle(color:Colors.white70,fontSize:12)),
    ])),
   ])),
  ])));
}

class LoginScreen extends StatefulWidget {
 final Future<void> Function(Person) onSave;
 final Future<void> Function(Person) onVerifiedPasswordSave;
 const LoginScreen({super.key,required this.onSave,
  required this.onVerifiedPasswordSave});
 @override State<LoginScreen> createState()=>_LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
 String? provider;
 Person? registered;
 bool signInMode=false,showSignInPassword=false,signingIn=false,signInAttempted=false;
 String? signInAuthError;
 bool returnAfterLogout=false;String lastMethod='Local',lastEmail='',lastPhone='';
 // Never show signup before checking both the old profile and OS verifier.
 // A fresh phone registration is ONE screen; existing phones sign in directly.
 bool _registrationChecked=false,_freshSignup=false;
 // A clean install must ask the owner to choose first. The existing
 // one-screen phone registration is shown ONLY after tapping Create Account.
 // Existing registered/logged-out profiles continue straight to login.
 String? _firstInstallChoice;
 bool _showChoiceAfterBack=false;
 final signInPhone=TextEditingController(),signInPassword=TextEditingController();
 @override void initState(){super.initState();_loadRegistered();}
 Future<void> _loadRegistered()async{
  try{
   final prefs=await SharedPreferences.getInstance();
   final signedOut=prefs.getBool('waffra_signed_out_explicitly')??false;
   final raw=prefs.getString('waffra_registered_profile');
   Person? oldUser;
   if(raw!=null){
    try{oldUser=Person.fromJson(Map<String,dynamic>.from(
     jsonDecode(raw) as Map));}catch(_){
     // Malformed saved identity is NOT permission to replace its finances.
    }
   }
   final hasOldProfile=prefs.getString('waffra_profile')!=null;
   final hasLegacyVerifier=prefs.containsKey('waffra_local_password_hash')||
    prefs.containsKey('waffra_local_password_salt');
   // The OS key may be present even if a profile write was interrupted.
   final hasSecureVerifier=await WaffraLocalPhoneCredentials
    .hasRegisteredCredentials();
   if(!mounted)return;
   setState((){
    returnAfterLogout=signedOut;
    lastMethod=prefs.getString('waffra_last_login_method')??'Local';
    lastEmail=prefs.getString('waffra_last_login_email')??'';
    lastPhone=prefs.getString('waffra_last_login_phone')??'';
    registered=oldUser;
    signInMode=oldUser?.provider.toLowerCase()=='phone';
    _freshSignup=raw==null&&!hasOldProfile&&!hasLegacyVerifier&&
     !hasSecureVerifier;
    _registrationChecked=true;
    if(oldUser!=null){
     signInPhone.text=WaffraSaudiMobile.inputFromStored(oldUser.phone);
    }
   });
  }catch(_){
   // A failed OS credential read must NOT create a fresh local identity.
   if(mounted)setState((){
    _freshSignup=false;_registrationChecked=true;
    signInAuthError=waffraIsEnglish?
     'Secure account check failed. Unlock the phone and retry.':
     'تعذر فحص الحساب الآمن. افتح قفل الهاتف وأعد المحاولة.';
   });
  }
 }
 @override void dispose(){signInPhone.dispose();signInPassword.dispose();super.dispose();}
 Future<void> _signIn()async{
  if(signingIn)return;
  setState(()=>signInAttempted=true);
  if(waffraMobileFieldError(signInPhone.text)!=null||
     signInPassword.text.isEmpty)return;
  setState(()=>signingIn=true);
  // Profile-only timings (never passwords, account IDs or financial data).
  // These let a physical Android trace separate secure preflight, password
  // derivation and verified profile activation from Flutter frame jank.
  final signInTiming=kProfileMode?(Stopwatch()..start()):null;
  int? preflightMs,verifiedMs;
  try{
   // Render the busy label/spinner before any secure-store/KDF work starts.
   // PBKDF2 itself runs off the Flutter frame isolate (M547 PERF-04).
   await WidgetsBinding.instance.endOfFrame;
   if(!mounted)return;
   final account=registered;
   final enteredPhone=signInPhone.text.trim();
   if(account==null){
    if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
     'Account details are unavailable on this device.':
     'بيانات الحساب غير متاحة على هذا الجهاز.');
    return;
   }
   // M629: like fast verified pull refresh, independently requested work
   // begins together. BOTH results are awaited before authenticating;
   // neither preferences nor secure identity is cached across sessions.
   final prefsLoading=SharedPreferences.getInstance();
   final secureInspectionLoading=WaffraLocalPhoneCredentials.readForSignIn();
   final prefs=await prefsLoading;
   final storedPhone=WaffraSaudiMobile.inputFromStored(account.phone);
   // One OS-keystore verifier read, not two identical secure-store reads.
   // Probe reports missing/malformed/foreign distinctly, preserving the
   // legacy fallback and fail-closed sign-in recovery semantics.
   var inspection=await secureInspectionLoading;
   var verifierStatus=await WaffraLocalPhoneCredentials.probeForPhone(
    enteredPhone,inspection:inspection);
   // Missing or malformed OS credentials are not equivalent to a wrong
   // password. Never replace the existing identity or financial data.
   final hasLegacy=prefs.getString('waffra_local_password_salt')!=null&&
    prefs.getString('waffra_local_password_hash')!=null;
   // M545: never ask for a password during logout. For a pre-existing
   // account that lost its verifier, the usual LOGIN password field plus a
   // fresh OS biometric challenge can consume a phone-bound secure grant.
   // The ordinary correct-password path remains unchanged for valid records.
   if(!hasLegacy&&verifierStatus==WaffraLocalCredentialProbe.missing&&
      storedPhone==enteredPhone&&
      await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(enteredPhone)){
    final confirmed=await WaffraBiometrics.unlockMandatory();
    if(!confirmed){
     if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
      'Confirm your device fingerprint to restore secure sign-in.':
      'أكد ببصمة الجهاز استعادة تسجيل الدخول الآمن.');
     return;
    }
    final recovered=await WaffraLocalPhoneCredentials
     .finishSignInRecoveryAfterBiometric(
       phone:enteredPhone,password:signInPassword.text);
    if(!recovered){
     if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
      'Could not safely restore sign-in; your finances are unchanged.':
      'تعذر استعادة تسجيل الدخول بأمان، بياناتك المالية محفوظة.');
     return;
    }
    // A successful recovery may have enrolled a new verifier.
    inspection=await WaffraLocalPhoneCredentials.readForSignIn();
    verifierStatus=await WaffraLocalPhoneCredentials.probeForPhone(
     enteredPhone,inspection:inspection);
   }
   if(!hasLegacy&&(verifierStatus==WaffraLocalCredentialProbe.missing||
      verifierStatus==WaffraLocalCredentialProbe.malformed)){
    if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
     'Secure sign-in record is missing or invalid on this device. Your data has not been deleted. Do not clear app data.':
     'سجل الدخول المشفّر مفقود أو غير صالح على الجهاز. لم تُحذف بياناتك. لا تمسح بيانات التطبيق.');
    return;
   }
   // Derive existence from the same secure-store probe (including any
   // verified biometric recovery). Never treat corrupt/foreign as missing.
   final hasSecureVerifier=verifierStatus!=WaffraLocalCredentialProbe.missing;
   preflightMs=signInTiming?.elapsedMilliseconds;
   // An older editable profile may contain a different display phone.
   // Only the OS-protected verifier may authenticate the entered number.
   // Without a secure verifier, legacy migration must keep its original phone.
   if(!hasSecureVerifier&&storedPhone!=enteredPhone){
    if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
     'Incorrect mobile number or password':'رقم الجوال أو كلمة المرور غير صحيحة');
    return;
   }
   final match=await WaffraLocalPhoneCredentials.verify(
    phone:enteredPhone,password:signInPassword.text,
    inspection:inspection,
    oldSalt:prefs.getString('waffra_local_password_salt'),
    oldHash:prefs.getString('waffra_local_password_hash'));
   verifiedMs=signInTiming?.elapsedMilliseconds;
   if(!match){
    if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
     'Incorrect mobile number or password':'رقم الجوال أو كلمة المرور غير صحيحة');
    return;
   }
   // Repair a stale display profile only AFTER a real password match.
   // This preserves the original account identity and all finance data.
   final verifiedAccount=storedPhone==enteredPhone?account:Person(
    name:account.name,email:account.email,provider:'Phone',
    gender:account.gender,avatar:account.avatar,
    birthday:account.birthday,phone:enteredPhone);
   final activationTiming=kProfileMode?(Stopwatch()..start()):null;
   // Only the previously successful real password check reaches this hook.
   await widget.onVerifiedPasswordSave(verifiedAccount);
   if(kProfileMode&&activationTiming!=null){
    debugPrint('WAFFRA_AUTH_PERF verified_profile_activation_ms='
     '${activationTiming.elapsedMilliseconds}');
   }
  }catch(_){
   if(mounted)setState(()=>signInAuthError=waffraIsEnglish?
    'Local secure storage is unavailable. Unlock your device and retry.':
    'تعذر فتح التخزين الآمن على الجهاز. افتح قفل هاتفك وحاول مجددًا.');
  }finally{
   if(kProfileMode&&signInTiming!=null){
    debugPrint('WAFFRA_AUTH_PERF sign_in_ms=${signInTiming.elapsedMilliseconds} '
     'preflight_ms=${preflightMs??-1} verifier_ms=${verifiedMs??-1}');
   }
   if(mounted)setState(()=>signingIn=false);
  }
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
 // New accounts have a Saudi phone/password entry, never a social provider.
 // Old Google identities still require a controlled, one-time migration.
 void chooseRegistration(){
  if(registered!=null){
   snack(context,waffraIsEnglish?
    'An account already exists on this device. Sign in or migrate it first.':
    'يوجد حساب محفوظ على الجهاز. سجّل الدخول أو انقل الحساب القديم أولًا.');
   return;
  }
  setState(()=>provider='Phone');
 }
 
 @override Widget build(BuildContext context){
  if(!_registrationChecked){
   return const Scaffold(body:Center(child:CircularProgressIndicator()));
  }
  // M510 #441: restore the explicit choice before either auth form on a
  // genuinely clean install. Never infer the choice from an empty profile.
  // M479: View-only Back always returns to the two-choice landing screen.
  if(_showChoiceAfterBack)return IntroScreen(
   onStart:()async{
    if(!mounted)return;
    setState(()=>_showChoiceAfterBack=false);
    // An existing owner must sign in; do not overwrite stored finances.
    chooseRegistration();
   },
   onLogin:()async{
    if(!mounted)return;
    setState((){
     _showChoiceAfterBack=false;
     if(_freshSignup)_firstInstallChoice='login';
     else signInMode=true;
    });
   });
  if(_freshSignup&&_firstInstallChoice==null)return IntroScreen(
   onStart:()async{if(mounted)setState(()=>_firstInstallChoice='create');},
   onLogin:()async{if(mounted)setState(()=>_firstInstallChoice='login');});
  if(_freshSignup&&_firstInstallChoice=='create'){
   return ProfileForm(
    provider:'Phone',onSave:widget.onSave,
    onBack:()=>setState(()=>_firstInstallChoice=null));
  }
  if(provider!=null)return ProfileForm(provider:'Phone',onSave:widget.onSave,
   onBack:()=>setState(()=>provider=null));
  final hasExisting=registered!=null;
  final legacyAccount=hasExisting&&registered!.provider.toLowerCase()!='phone';
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
        if(returnAfterLogout&&!signInMode&&hasExisting)...[
         WaffraText(waffraIsEnglish?'Welcome back':'مرحبًا بك مجددًا',
          textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),
         const SizedBox(height:5),
         WaffraText(waffraIsEnglish?'Sign in to continue':'سجل دخولك للمتابعة',
          textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:14)),
         const SizedBox(height:15),
         recentLoginCard(),
         const SizedBox(height:12),
         if(!legacyAccount)TextButton(
          onPressed:WaffraHaptics.tap(()=>setState(()=>signInMode=true)),
          child:WaffraText(waffraIsEnglish?'Sign in with mobile':'الدخول برقم الجوال',
           style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        ]else if(legacyAccount)...[
         WaffraText(waffraIsEnglish?'Legacy account migration':'نقل الحساب القديم',
          textAlign:TextAlign.center,style:const TextStyle(fontSize:20,color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:10),
         WaffraText(waffraIsEnglish?
          'Your data remains on this phone. You must verify your previous account once before switching to mobile/password.':
          'بياناتك موجودة على الجهاز. لازم نتحقق من حسابك القديم مرة واحدة قبل نقله إلى الجوال وكلمة المرور.',
          textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),
         const SizedBox(height:12),
         FilledButton(onPressed:WaffraHaptics.tap(socialBusy?null:continueLastLogin),
          child:WaffraText(waffraIsEnglish?'Temporary access to old account':'دخول مؤقت للحساب القديم')),
        ]else if((signInMode&&hasExisting)||
         (_freshSignup&&_firstInstallChoice=='login'))...[
         WaffraText(waffraIsEnglish?'Sign in to Waffra':'تسجيل الدخول إلى وفرة',
          textAlign:TextAlign.center,
          style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.white)),
         const SizedBox(height:12),
         WaffraText(waffraIsEnglish?'Phone number *':'رقم الجوال *',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
         const SizedBox(height:6),
         TextField(controller:signInPhone,keyboardType:TextInputType.phone,
          inputFormatters:[FilteringTextInputFormatter.digitsOnly,
           LengthLimitingTextInputFormatter(10)],
          onChanged:(_)=>setState(()=>signInAuthError=null),
          style:const TextStyle(color:forest),textDirection:TextDirection.ltr,
          decoration:InputDecoration(hintText:'05XXXXXXXX',hintStyle:const TextStyle(color:Colors.black38),
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
          key:const Key('m585-login-submit-stable'),
          // Disabled is the IN-PROGRESS state. Material3's default disabled
          // colors previously made the button an empty dark rectangle.
          style:FilledButton.styleFrom(backgroundColor:Colors.white,
           disabledBackgroundColor:Colors.white,
           foregroundColor:forest,disabledForegroundColor:forest,
           minimumSize:const Size(218,48)),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
           if(signingIn)...[
            const RepaintBoundary(child:SizedBox(width:18,height:18,
             child:CircularProgressIndicator(strokeWidth:2.1,
              valueColor:AlwaysStoppedAnimation<Color>(forest)))),
            const SizedBox(width:10),
           ],
           WaffraText(signingIn?
            (waffraIsEnglish?'Signing in...':'جارٍ تسجيل الدخول'):
            (waffraIsEnglish?'Sign in':'تسجيل الدخول'),
            style:const TextStyle(color:forest,fontWeight:FontWeight.bold)),
          ])),
         TextButton(
          key:const Key('m479-login-back-to-choice'),
          onPressed:WaffraHaptics.tap(()=>setState((){
           signInAttempted=false;
           signInAuthError=null;
           if(_freshSignup)_firstInstallChoice=null;
           else _showChoiceAfterBack=true;
          })),
          child:WaffraText(waffraIsEnglish?'Back':'عودة',
           style:const TextStyle(color:Colors.white))),
        ]else...[
         WaffraText(waffraIsEnglish?'Welcome to Waffra':'مرحباً بك في وفرة',
          style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.bold),
          textAlign:TextAlign.center),
         const SizedBox(height:12),
         FilledButton.icon(onPressed:WaffraHaptics.tap(chooseRegistration),
          style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:forest),
          icon:const Icon(Icons.phone_android_outlined),
          label:WaffraText(waffraIsEnglish?'Register with Saudi mobile':'إنشاء حساب برقم الجوال')),
         if(hasExisting&&!legacyAccount)TextButton(onPressed:WaffraHaptics.tap(()=>setState(()=>signInMode=true)),
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
  phoneCountry=WaffraSaudiRelease.enabled?
   WaffraInternationalPhone.byIso('SA'):phoneSeed.country;
  phone=TextEditingController(text:WaffraSaudiRelease.enabled?
   WaffraSaudiMobile.inputFromStored(widget.initial?.phone):
   widget.provider=='Google'?phoneSeed.local:widget.initial?.phone??'');
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
   selected=await WaffraExternalMediaSession.runPicker(()=>
    ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:92));
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
  if(busy)return;
  setState(()=>profileAttempted=true);
  if(gender.isEmpty)return;
  if(waffraTextFieldError(name.text)!=null||
   (WaffraSaudiRelease.enabled?waffraMobileFieldError(phone.text):
    widget.provider=='Google'?WaffraInternationalPhone.error(phoneCountry,phone.text,
      english:waffraIsEnglish):waffraMobileFieldError(phone.text))!=null)return;
  if(widget.initial==null&&(
   waffraPasswordFieldError(password.text)!=null||
   waffraConfirmPasswordFieldError(confirmPassword.text,password.text)!=null))return;
  setState(()=>busy=true);
  try {
   // Paint the disabled Save/registration progress UI before secure I/O.
   await WidgetsBinding.instance.endOfFrame;
   if(!mounted)return;
   if(widget.initial==null&&widget.provider=='Phone'){
    // A completed existing profile must use verified sign-in, never a
    // second registration that can overwrite the account's name or data.
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    if(prefs.getString('waffra_registered_profile')!=null){
     throw StateError('local_profile_already_completed');
    }
    // If the previous attempt stored a verifier but failed to persist the
    // profile, resume ONLY after proving the same phone AND password.
    // No credential deletion, password reset, or new OS key is permitted.
    await WaffraLocalPhoneCredentials.registerOrResume(
     phone:phone.text.trim(),password:password.text);
   }
   await widget.onSave(Person(name:name.text.trim(),email:widget.initial?.email??'',
    phone:widget.initial!=null&&widget.provider=='Phone'?
      widget.initial!.phone:widget.provider=='Google'?
      (WaffraSaudiRelease.enabled?
       (widget.initial!=null&&
        WaffraSaudiMobile.isSupportedStored(widget.initial!.phone)&&
        WaffraSaudiMobile.inputFromStored(widget.initial!.phone)==phone.text.trim()?
        widget.initial!.phone:WaffraSaudiMobile.toE164(phone.text)!):
       WaffraInternationalPhone.e164(phoneCountry,phone.text)!):
      phone.text.trim(),
     provider:widget.provider,gender:gender,avatar:avatar,birthday:birthday));
   if(!mounted)return;
   if(widget.initial!=null&&Navigator.of(context).canPop())Navigator.pop(context);
  }catch(e){
   if(!mounted)return;
   final message=e is StateError&&e.message=='local_credentials_already_exist'?
     (waffraIsEnglish?
       'A different local login already exists. Use its original phone and password to finish, or sign in.':
       'يوجد تسجيل دخول سابق على الجهاز. استخدم نفس رقم الجوال وكلمة المرور الأصلية، أو ارجع لتسجيل الدخول.'):
     e is StateError&&e.message=='local_profile_already_completed'?
     (waffraIsEnglish?
       'This account is already registered. Go back and sign in.':
       'الحساب مسجل بالفعل. ارجع وسجّل الدخول برقم الجوال وكلمة المرور.'):
     (waffraIsEnglish?
       'Unable to complete registration. Your login details were kept; retry with the same phone and password.':
       'تعذر إكمال التسجيل. بيانات الدخول محفوظة؛ حاول مجددًا بنفس رقم الجوال وكلمة المرور.');
   snack(context,message);
  }
  finally{if(mounted)setState(()=>busy=false);}
 }

 Widget _phoneRegistrationForm(){
  return Scaffold(
   appBar:AppBar(title:WaffraText(waffraIsEnglish?
    'Create a Waffra account':'إنشاء حساب وفرة'),
    leading:widget.onBack==null?null:IconButton(
     onPressed:WaffraHaptics.tap(widget.onBack),
     icon:const Icon(Icons.arrow_back))),
   body:SafeArea(child:ListView(
    key:const Key('waffra-register-single-page'),
    padding:const EdgeInsets.fromLTRB(22,14,22,32),
    keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
    children:[
     WaffraText(waffraIsEnglish?'Your account details':'بيانات حسابك',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
     const SizedBox(height:14),
     TextField(key:const Key('waffra-register-name'),controller:name,
      textInputAction:TextInputAction.next,onChanged:(_)=>setState((){}),
      decoration:InputDecoration(labelText:waffraIsEnglish?'Name':'الاسم',
       errorText:profileAttempted?waffraTextFieldError(name.text):null,
       border:const OutlineInputBorder())),
     const SizedBox(height:15),
     WaffraText(waffraIsEnglish?'Gender and avatar':'النوع والصورة الشخصية',
      style:const TextStyle(fontWeight:FontWeight.bold)),
     const SizedBox(height:10),
     Wrap(alignment:WrapAlignment.center,spacing:12,runSpacing:8,
      children:['ذكر','أنثى'].map((g)=>ChoiceChip(
       key:Key(g=='ذكر'?'waffra-register-gender-male':'waffra-register-gender-female'),
       label:Row(mainAxisSize:MainAxisSize.min,children:[
        saudiAvatar(g,radius:21),const SizedBox(width:8),
        WaffraText(waffraIsEnglish?(g=='ذكر'?'Male':'Female'):g),
       ]),
       selected:gender==g,
       onSelected:WaffraHaptics.selection((_)=>setState((){
        gender=g;avatar=g=='ذكر'?'male':'female';
       })))).toList()),
     if(profileAttempted&&gender.isEmpty)Padding(
      padding:const EdgeInsets.only(top:8),
      child:WaffraText(waffraRequiredFieldMessage,
       style:const TextStyle(color:Colors.red))),
     const SizedBox(height:16),
     TextField(key:const Key('waffra-register-phone'),controller:phone,
      keyboardType:TextInputType.phone,textInputAction:TextInputAction.next,
      textDirection:TextDirection.ltr,onChanged:(_)=>setState((){}),
      inputFormatters:[FilteringTextInputFormatter.digitsOnly,
       LengthLimitingTextInputFormatter(10)],
      decoration:InputDecoration(
       labelText:waffraIsEnglish?'Saudi mobile number':'رقم الجوال السعودي',
       hintText:'05XXXXXXXX',
       errorText:profileAttempted?waffraMobileFieldError(phone.text):null,
       border:const OutlineInputBorder())),
     const SizedBox(height:14),
     TextField(key:const Key('waffra-register-password'),
      controller:password,obscureText:!showPassword,
      textInputAction:TextInputAction.next,
      onChanged:(_)=>setState((){}),
      decoration:InputDecoration(labelText:waffraIsEnglish?'Password':'كلمة المرور',
       helperText:waffraIsEnglish?'8+ characters, letters and numbers':'٨ خانات على الأقل، تشمل أحرفًا وأرقامًا',
       errorText:profileAttempted?waffraPasswordFieldError(password.text):null,
       errorMaxLines:3,border:const OutlineInputBorder(),
       suffixIcon:IconButton(
        onPressed:WaffraHaptics.tap(()=>setState(()=>showPassword=!showPassword)),
        icon:Icon(showPassword?Icons.visibility_off:Icons.visibility)))),
     const SizedBox(height:14),
     TextField(key:const Key('waffra-register-confirm-password'),
      controller:confirmPassword,obscureText:!showConfirmPassword,
      textInputAction:TextInputAction.done,
      onChanged:(_)=>setState((){}),
      onSubmitted:(_){if(!busy)save();},
      decoration:InputDecoration(labelText:waffraIsEnglish?'Confirm password':'تأكيد كلمة المرور',
       errorText:profileAttempted?
        waffraConfirmPasswordFieldError(confirmPassword.text,password.text):null,
       errorMaxLines:3,border:const OutlineInputBorder(),
       suffixIcon:IconButton(
        onPressed:WaffraHaptics.tap(()=>setState(()=>showConfirmPassword=!showConfirmPassword)),
        icon:Icon(showConfirmPassword?Icons.visibility_off:Icons.visibility)))),
     if(comparingPasswords&&matchingPasswords)Padding(
      padding:const EdgeInsets.only(top:8),
      child:Row(children:[const Icon(Icons.check_circle_outline,color:emerald,size:18),
       const SizedBox(width:6),
       WaffraText(waffraIsEnglish?'Passwords match':'كلمتا المرور متطابقتان')])),
     const SizedBox(height:22),
     FilledButton(key:const Key('waffra-register-submit'),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),
      onPressed:WaffraHaptics.tap(busy?null:save),
      child:busy?Row(mainAxisSize:MainAxisSize.min,children:[
       const SizedBox(width:18,height:18,child:CircularProgressIndicator(
        strokeWidth:2,color:Colors.white)),
       const SizedBox(width:10),
       WaffraText(waffraIsEnglish?'Saving...':'جارٍ الحفظ'),
      ]):WaffraText(waffraIsEnglish?
       'Complete registration':'إكمال التسجيل')),
    ])),
  );
 }
 @override Widget build(BuildContext context){
  if(widget.initial==null&&widget.provider=='Phone')return _phoneRegistrationForm();
  return Scaffold(
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
     errorText:profileAttempted?
      (WaffraSaudiRelease.enabled?waffraMobileFieldError(phone.text):
       WaffraInternationalPhone.error(phoneCountry,phone.text,
        english:waffraIsEnglish)):null)
   else TextField(controller:phone,keyboardType:TextInputType.phone,
    readOnly:widget.initial!=null&&widget.provider=='Phone',
    onChanged:(_)=>setState((){}),
    inputFormatters:[FilteringTextInputFormatter.digitsOnly,
     LengthLimitingTextInputFormatter(10)],
    decoration:InputDecoration(
     labelText:waffraIsEnglish?'Saudi mobile number *':'رقم الجوال السعودي *',
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
   WaffraCenteredDropdownFormField<String>(initialValue:['ذكر','أنثى'].contains(gender)?gender:null,
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

/// M668 approved design #3: a shared neutral card with a semantic leading
/// stripe, not a fully tinted notification. Both footer and floating fallback
/// reuse this exact card surface and keep all existing notice semantics.
Color waffraNoticeSurfaceColor(BuildContext context)=>
 Theme.of(context).brightness==Brightness.dark?
  const Color(0xFF1D2B25):const Color(0xFFFFFFFF);

Color waffraNoticeOutlineColor(BuildContext context)=>
 Theme.of(context).brightness==Brightness.dark?
  const Color(0xFF4D6659):const Color(0xFFD6E2DA);

class WaffraNoticeEdgeBody extends StatelessWidget {
 const WaffraNoticeEdgeBody({
  super.key,required this.notice,required this.onDismiss,
 });
 final WaffraNoticeData notice;
 final VoidCallback onDismiss;
 @override Widget build(BuildContext context){
  final palette=waffraNoticePalette(context,notice.kind);
  // PositionedDirectional.start is the RIGHT edge in Arabic and LEFT in
  // English; keep the background/stripe a single clipped card.
  // Avoid IntrinsicHeight and overlays to preserve scroll and footer speed.
  return Stack(children:[
   PositionedDirectional(
    start:0,top:0,bottom:0,
    child:Container(key:const Key('waffra-snackbar-edge'),
     width:5,color:palette.$3)),
   Padding(
    padding:const EdgeInsetsDirectional.fromSTEB(13,4,6,4),
    child:WaffraNoticeContent(notice:notice,onDismiss:onDismiss)),
  ]);
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
  // Keep both actions at least 48dp tall for accessible touch targets.
  // Their small icons and compact text preserve visual balance in RTL/LTR.
  // The message stays flexible on narrow Android screens and at 200% text.
  return ConstrainedBox(constraints:const BoxConstraints(minHeight:48),
   child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
    Icon(palette.$4,color:palette.$2,size:19),
    const SizedBox(width:8),
    Expanded(child:Tooltip(message:notice.text,
     child:WaffraText(notice.text,
      style:TextStyle(
       color:palette.$2,fontSize:12,height:1.2,
       fontWeight:FontWeight.w700)))),
    if(notice.onAction!=null)...[
     const SizedBox(width:6),
     TextButton(
      key:const Key('waffra-snackbar-action'),
      style:TextButton.styleFrom(
       foregroundColor:palette.$2,
       minimumSize:const Size(64,48),
       maximumSize:const Size(96,48),
       padding:const EdgeInsets.symmetric(horizontal:10),
       backgroundColor:palette.$2.withValues(alpha:.07),
       side:BorderSide(color:palette.$3.withValues(alpha:.45)),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
      onPressed:WaffraHaptics.tap((){
       onDismiss();
       notice.onAction?.call();
      }),
      child:WaffraText(notice.actionLabel??(waffraIsEnglish?'Undo':'تراجع'),
       maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(
        color:palette.$2,fontSize:12,fontWeight:FontWeight.bold))),
    ],

   ]));
 }
}

/// Captures taps without joining the gesture arena: original navigation,
/// buttons and Undo receive their tap before the notice is hidden.
class WaffraNoticeTapDismissArea extends StatefulWidget {
 const WaffraNoticeTapDismissArea({super.key,required this.child});
 final Widget child;
 @override State<WaffraNoticeTapDismissArea> createState()=>
  _WaffraNoticeTapDismissAreaState();
}
class _WaffraNoticeTapDismissAreaState extends State<WaffraNoticeTapDismissArea> {
 final Map<int,Offset> _touchOrigins=<int,Offset>{};
 @override Widget build(BuildContext context)=>Listener(
  behavior:HitTestBehavior.translucent,
  onPointerDown:(event)=>_touchOrigins[event.pointer]=event.position,
  onPointerCancel:(event)=>_touchOrigins.remove(event.pointer),
  onPointerUp:(event){
   final origin=_touchOrigins.remove(event.pointer);
   if(origin==null||(event.position-origin).distance>18)return;
   final shownFooter=_waffraFooterNotice.value;
   final shownFallback=_waffraFallbackNoticeMessenger;
   final fallbackGeneration=_waffraFallbackNoticeGeneration;
   if(shownFooter==null&&shownFallback==null)return;
   // Allow the *same* tap to activate its real target first, including Undo.
   // A newly shown replacement notice must not be dismissed by an older tap.
   scheduleMicrotask((){
    if(!mounted)return;
    if(shownFooter!=null&&identical(_waffraFooterNotice.value,shownFooter)){
     waffraDismissFooterNotice();
    }
    if(shownFallback!=null&&shownFallback.mounted&&
       fallbackGeneration==_waffraFallbackNoticeGeneration){
     shownFallback.removeCurrentSnackBar();
     if(identical(_waffraFallbackNoticeMessenger,shownFallback)){
      _waffraFallbackNoticeMessenger=null;
     }
    }
   });
  },
  child:widget.child);
}

final ValueNotifier<WaffraNoticeData?> _waffraFooterNotice=
 ValueNotifier<WaffraNoticeData?>(null);
ScaffoldMessengerState? _waffraFallbackNoticeMessenger;
int _waffraFallbackNoticeGeneration=0;
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
   // Instantly remove a dismissed notice. An AnimatedSize with a
   // zero-duration swap can mutate its own RenderAnimatedSize during layout
   // when the user's tap and the footer change arrive in the same frame.
   builder:(ctx,notice,_)=>notice==null?
    const SizedBox(width:double.infinity,height:0):
     Padding(
      padding:const EdgeInsets.only(top:4,bottom:8),
      child:Center(child:SizedBox(
       width:min(MediaQuery.sizeOf(ctx).width*0.87,440.0),
       child:Builder(builder:(panelContext){
        return Material(
         color:waffraNoticeSurfaceColor(panelContext),elevation:2,
         shadowColor:Colors.black.withValues(alpha:0.13),
         clipBehavior:Clip.antiAlias,
         shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(14),
          side:BorderSide(color:waffraNoticeOutlineColor(panelContext),width:1)),
         child:WaffraNoticeEdgeBody(
          notice:notice,onDismiss:widget.onDismiss??waffraDismissFooterNotice),
        );
       }),
      )),
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
 // Explicit root-session feedback uses the footer when one is mounted;
 // dialogs, login and biometric gates use this same notice fallback.
 bool preferFooter=false,
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
 if(_waffraFooterHostCount>0&&(preferFooter||inHome||inHomeDialog)){
  // Switching from a non-footer route must never leave two notices stacked.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  _waffraFallbackNoticeMessenger=null;
  _waffraFallbackNoticeGeneration++;
  _waffraShowFooterNotice(notice);
  return;
 }
 // Login, setup and pushed profile routes have no Waffra footer. Reuse
 // the exact same content/colors with the bottom-aligned fallback Snackbar.
 final messenger=ScaffoldMessenger.maybeOf(context);
 if(messenger==null)return;
 messenger.hideCurrentMaterialBanner();
 messenger.hideCurrentSnackBar();
 _waffraFallbackNoticeMessenger=messenger;
 _waffraFallbackNoticeGeneration++;
 messenger.showSnackBar(SnackBar(
  behavior:SnackBarBehavior.floating,
  margin:const EdgeInsets.only(left:12,right:12,bottom:8),
  duration:requireDismissal?const Duration(days:1):duration,
  backgroundColor:waffraNoticeSurfaceColor(context),
  elevation:2,
  padding:EdgeInsets.zero,
  shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(14),
   side:BorderSide(color:waffraNoticeOutlineColor(context),width:1)),
  content:WaffraNoticeEdgeBody(
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
 /// Only previously persisted provenance is authoritative.
 static String sourceLabel(String source,bool english)=>switch(source){
  'sms'=>english?'Bank SMS — reviewed and saved manually':
   'رسالة بنكية (SMS) — تمت مراجعتها وتسجيلها يدويًا',
  'manual'=>english?'Manual entry':'إدخال يدوي',
  'receipt'=>english?'Receipt capture':'إضافة من فاتورة',
  'goal_due'=>english?'Goal due payment':'استحقاق هدف',
  _=>english?'Previous entry (source unverified)':
   'معاملة سابقة (المصدر غير محدد)',
 };
 final MoneyEntry entry;
 /// A verified read-only SMS original from SQLCipher; never write to notes.
 final String? protectedOriginalSms;
 final VoidCallback onClose;
 final VoidCallback? onViewReceipt;
 final VoidCallback? onLinkBudget;
 final String? linkedBudgetName;
 final bool linkedBudgetPaused;
 final bool showBudgetInfo;
 const WaffraTransactionDetailsDialog({
  super.key,required this.entry,required this.onClose,this.onViewReceipt,
  this.protectedOriginalSms,this.onLinkBudget,this.linkedBudgetName,
  this.linkedBudgetPaused=false,this.showBudgetInfo=true,
 });
 @override Widget build(BuildContext context){
  final rtl=!waffraIsEnglish;
  final dark=Theme.of(context).brightness==Brightness.dark;
  final accent=entry.income?const Color(0xFF087A54):const Color(0xFFB94838);
  final lightTone=entry.income?const Color(0xFFE4F4EB):const Color(0xFFFCECE8);
  final darkTone=entry.income?const Color(0xFF244C3A):const Color(0xFF49302C);
  final muted=Theme.of(context).colorScheme.onSurface.withValues(alpha:.73);
  final displayNotes=waffraGoalDueVisibleNotes(entry);
  // Historical encrypted SMS entries used notes for their source text.
  // Display such content as a bank SMS only, not a personal note.
  final displayOriginalSms=(protectedOriginalSms?.trim().isNotEmpty??false)?
   protectedOriginalSms:entry.sourceType=='sms'&&entry.notes.trim().isNotEmpty?
   entry.notes:null;
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
       const SizedBox(height:12),
       Container(
        key:const Key('waffra-transaction-source-provenance'),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
        decoration:BoxDecoration(
         color:dark?const Color(0xFF18372E):const Color(0xFFEAF5EF),
         borderRadius:BorderRadius.circular(12)),
        child:Row(children:[
         Icon(entry.sourceType=='sms'?Icons.sms_outlined:
          Icons.edit_note_outlined,color:emerald,size:19),
         const SizedBox(width:8),
         Expanded(child:WaffraText(
          WaffraTransactionDetailsDialog.sourceLabel(
           entry.sourceType,waffraIsEnglish),
          style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13))),
        ])),
       if(entry.sourceType=='manual')...[
        const SizedBox(height:7),
        WaffraText(waffraIsEnglish?
         'Added manually. No original SMS exists for this transaction.':
         'تمت إضافة المعاملة يدويًا — لا توجد رسالة SMS أصلية.',
         style:TextStyle(fontSize:12,color:muted)),
       ],
       const SizedBox(height:15),
       Row(children:[
        Icon(entry.sourceType=='goal_due'?Icons.flag_outlined:Icons.category_outlined,
         color:dark?const Color(0xFF74D8A9):emerald,size:20),
        const SizedBox(width:8),
        Expanded(child:WaffraText(entry.sourceType=='goal_due'?
         (waffraIsEnglish?'Savings goal payment':'استحقاق هدف'):
         waffraTr(entry.category),
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
       if(!entry.income&&showBudgetInfo&&entry.sourceType!='goal_due')...[
        const SizedBox(height:12),
        if(entry.budgetId==null)
         Container(
          key:const Key('waffra-transaction-budget-unlinked-warning'),
          padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(
           color:Colors.deepOrange.withValues(alpha:dark ? 0.13 : 0.08),
           borderRadius:BorderRadius.circular(12),
           border:Border.all(color:Colors.deepOrange.withValues(alpha:.40))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Icon(Icons.info_outline_rounded,
             size:18,color:Colors.deepOrange),
            const SizedBox(width:7),
            Expanded(child:WaffraText(waffraIsEnglish?
             'This expense is not linked to a budget.':
             'المعاملة دي غير مرتبطة بميزانية.',
             style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
           ]),
           if(onLinkBudget!=null)
            Align(alignment:AlignmentDirectional.centerStart,
             child:TextButton.icon(
              key:const Key('waffra-transaction-link-budget-action'),
              onPressed:WaffraHaptics.tap(onLinkBudget),
              icon:const Icon(Icons.link_rounded,size:16),
              label:WaffraText(waffraIsEnglish?
               'Link to a budget':'ربط بميزانية'))),
          ]),
         )
        else WaffraText(waffraIsEnglish?
          'Budget: '+(linkedBudgetName??'Saved budget')+
            (linkedBudgetPaused?' (paused)':''):
          'الميزانية: '+(linkedBudgetName??'ميزانية محفوظة')+
            (linkedBudgetPaused?' (متوقفة مؤقتًا)':''),
          style:TextStyle(fontSize:12,color:muted)),
       ],
       const SizedBox(height:15),
       Container(
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
        decoration:BoxDecoration(color:dark?darkTone:lightTone,
         borderRadius:BorderRadius.circular(15)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         WaffraText(entry.sourceType=='goal_due'?
          (waffraIsEnglish?'Total goal payment':'إجمالي استحقاق الهدف'):
          entry.income?
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
       if(entry.sourceType=='goal_due')...[
        const SizedBox(height:11),
        Container(key:const Key('m665-goal-due-details-breakdown'),
         padding:const EdgeInsets.all(12),
         decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),
          color:dark?const Color(0xFF19382F):const Color(0xFFE9F5EF)),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
           Expanded(child:WaffraText(waffraIsEnglish?
            'From saved goal wallet':'من محفظة الهدف')),
           WaffraCurrencyAmount(entry.goalWalletPaidMinor/100,
            fontSize:15,color:emerald),
          ]),
          const SizedBox(height:8),
          Row(children:[
           Expanded(child:WaffraText(waffraIsEnglish?
            'Debited from money account':'المخصوم من الحساب المالي')),
           WaffraCurrencyAmount(waffraGoalDueCashMinor(entry)/100,
            fontSize:15,color:emerald),
          ]),
         ]),
        ),
       ],
       // Personal notes are separate from the original SMS in the UI and
       // canonical JSON. The historical bank SMS field stays encrypted.
       if(displayNotes.trim().isNotEmpty)...[
        const SizedBox(height:15),
        WaffraText(waffraIsEnglish?'Notes':'الملاحظات',
         textAlign:TextAlign.start,style:TextStyle(fontSize:12,color:muted)),
        const SizedBox(height:7),
        Container(width:double.infinity,padding:const EdgeInsets.all(13),
         decoration:BoxDecoration(
          color:dark?const Color(0xFF252A27):const Color(0xFFF1F8F3),
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:dark?const Color(0xFF3B5444):const Color(0xFFD5E8DC))),
         child:SelectableText(displayNotes,
           key:const Key('waffra-transaction-personal-notes'),
           textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
           textAlign:TextAlign.start,
           style:const TextStyle(fontSize:14,height:1.5))),
       ],
       if(entry.sourceType=='sms'&&displayOriginalSms!=null)...[
        const SizedBox(height:15),
        Row(children:[
         Icon(Icons.lock_outline_rounded,size:17,
          color:dark?const Color(0xFF74D8A9):emerald),
         const SizedBox(width:6),
         Expanded(child:WaffraText(waffraIsEnglish?
           'Original bank message':'تفاصيل الرسالة البنكية الأصلية',
           textAlign:TextAlign.start,
           style:TextStyle(fontSize:12,color:muted,fontWeight:FontWeight.w700))),
        ]),
        const SizedBox(height:7),
        Container(width:double.infinity,padding:const EdgeInsets.all(13),
         decoration:BoxDecoration(
          color:dark?const Color(0xFF18372E):const Color(0xFFE9F5EF),
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:dark?const Color(0xFF3B7055):const Color(0xFFB8D9C7))),
         child:SelectableText(displayOriginalSms,
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
 final Future<WaffraProductionFinanceAuthorityBinding?>? prewarmedFinanceBinding;
 final int greetingIndex;
 final bool postAuthVisible;
 final VoidCallback? onVerifiedReady;
 final Future<bool> Function()? onVerifiedHomeSmsResume;
 final Future<void> Function(String) onAppearance;
 final Future<void> Function(String?) onSetPin;
 final VoidCallback onTheme;
 final Future<void> Function(String) onLanguage;
 final Future<void> Function() onLogout;
 final Future<void> Function(Person) onProfile;
 const HomeScreen({super.key,required this.profile,required this.dark,required this.pinEnabled,
  required this.onSetPin,required this.onTheme,required this.onLanguage,required this.onLogout,required this.onProfile,
   required this.appearance,required this.onAppearance,
   required this.greetingIndex,this.onVerifiedReady,
   this.postAuthVisible=true, // Standalone Home remains interactive; root overrides for preload.
   this.prewarmedFinanceBinding,this.onVerifiedHomeSmsResume});
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
     if(!hidden)...[
      WaffraCurrencyMark(english:waffraIsEnglish,
       currencyCode:WaffraDisplayCurrency.country.code,
       arabicLabel:WaffraDisplayCurrency.country.symbolAr,
       size:fontSize*.78,color:color),
      const SizedBox(width:5),
     ],
     WaffraText(hidden?'***':WaffraDisplayCurrency.amount(amount),
      style:TextStyle(fontFamily:'Tajawal',fontSize:fontSize,
       fontWeight:weight,color:color))
    ])));
}
// Collapse the balance as the user scrolls, then let it scroll AWAY
// with the rest of the home page. It is intentionally not pinned.
/// Home balance cover: approved dark-emerald plant-and-coins design.
/// Visual only: the value and hide toggle remain bound to verified Home data.
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
 // M663: separate a verified, hidden first-run Home preload from actual
 // owner-visible first paint. No optional SMS/native/widget I/O during gate.
 final Completer<void> _m663FirstInteractiveFrame=Completer<void>();
 @override void didUpdateWidget(covariant HomeScreen oldWidget){
  super.didUpdateWidget(oldWidget);
  if(widget.postAuthVisible&&!oldWidget.postAuthVisible&&
     !_m663FirstInteractiveFrame.isCompleted){
   WidgetsBinding.instance.addPostFrameCallback((_){
    if(mounted&&widget.postAuthVisible&&
       !_m663FirstInteractiveFrame.isCompleted){
     _m663FirstInteractiveFrame.complete();
    }
   });
  }
 }
 Future<bool> _m663AwaitVisible(int epoch)async{
  if(widget.postAuthVisible){
   // Actual layout is allowed to finish before optional I/O.
   await WidgetsBinding.instance.endOfFrame;
  }else{
   await _m663FirstInteractiveFrame.future;
  }
  return mounted&&widget.postAuthVisible&&
   epoch==_m630HomeStartupEpoch&&!_m627ClosingSession;
 }
 // Stable callback identity ensures an old locale-specific Home disposal
 // cannot clear the replacement Home's back handler.
 late final bool Function() _registeredBackHandler=_consumeHomeBack;
 final WaffraLegacyWriteQueue _financialWriteQueue=WaffraLegacyWriteQueue();
 // Expensive off-isolate preparation cannot overtake an earlier save.
 Future<void> _m468PersistSequence=Future<void>.value();
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
  // Reuse the exact verified owner/session connection; if speculative open
  // failed, use the existing fail-closed original binder instead.
  final pendingWarm=_m631PrewarmConsumed?null:widget.prewarmedFinanceBinding;
  _m631PrewarmConsumed=true;
  final warmed=await pendingWarm;
  if(kProfileMode)debugPrint('WAFFRA_AUTH_PERF home_binding_reused=${warmed!=null}');
  final binding=warmed??await WaffraProductionFinanceAuthorityBinding.bind(
    installedApp:true,
   // The first mandatory Home dashboard read validates this source;
   // skip the duplicate encrypted snapshot read during binder setup.
   deferInitialDashboardRead:true,
   legacy:_homeFinancePersistence,
   startupRoute:WaffraFinanceRoute.appStartup,
  );
  if(!mounted){await binding.close();throw StateError('Home startup was disposed.');}
  _financeBinding=binding;
  _financeAuthority=binding.authority;
 }
 // Never reopen a previously adopted (possibly now CLOSED) binding on Retry,
 // particularly after an aborted signout or an interrupted Home load.
 bool _m631PrewarmConsumed=false;

 // M627: sign-out closes the Home-owned binding, not a root-local phantom.
 bool _m627ClosingSession=false;
 int _m627AccountEpoch=0;
 // M630 / #542: reject stale Home callbacks and await optional vault I/O
 // before explicit logout closes the owner-bound SQLCipher connection.
 int _m630HomeStartupEpoch=0;
 Future<void>? _m630PostFrameFinanceWork;
 bool _m630SmsSessionCurrent(int epoch)=>
  mounted&&ready&&widget.postAuthVisible&&
  !_m627ClosingSession&&_financeLoadFailure==null&&
  epoch==_m630HomeStartupEpoch;
 // A signout must not close SQLCipher while a Home load still owns a read.
 Completer<void>? _m627HomeLoadCompletion;
 // Keep genuine DB reads visible to teardown even after Future.timeout
 // detached an old UI await. Each read must complete before SQLCipher closes.
 final Set<Future<void>> _m627OutstandingAccountReads=<Future<void>>{};
 Future<void> _m627CloseForLogout()async{
  if(_m627ClosingSession)return;
  _m627ClosingSession=true;
  _m627AccountEpoch++;
  _m630HomeStartupEpoch++;
  // M636: retain the last verified Home frame behind the blocking logout
  // overlay. An error/retry view belongs to real failure, never success.
  // _m627ClosingSession still prevents finance work until safe teardown.
  try{
   // Never close an active database underneath a Home load or pending
   // finance preparation/write. Timeout fails signout closed, not finance.
   final pendingLoad=_m627HomeLoadCompletion;
   if(pendingLoad!=null){
    await pendingLoad.future.timeout(const Duration(seconds:20));
   }
   // Future.timeout does not cancel the SQL query: fail signout rather
   // than close a vault whose old account read is still running.
   await Future.wait<void>(_m627OutstandingAccountReads.toList())
    .timeout(const Duration(seconds:20));
   // M630: a widget reread or due-payment/reminder task may still own
   // this source after the first Home frame. Finish it before vault close.
   final postFrameFinance=_m630PostFrameFinanceWork;
   if(postFrameFinance!=null){
    await postFrameFinance.timeout(const Duration(seconds:20));
   }
   await _m468PersistSequence.timeout(const Duration(seconds:20));
   await _financialWriteQueue.drain().timeout(const Duration(seconds:20));
   final pending=_financeBindingFuture;
   if(pending!=null)await pending;
   final binding=_financeBinding;
   if(binding!=null)await binding.close();
   _financeBinding=null;
   _financeBindingFuture=null;
   // Preserve a non-null guarded authority until this Home unmounts.
   _financeAuthority=WaffraVerifiedFinanceAuthority(legacy:_homeFinancePersistence);
   _m468AccountReadInFlight=null;
   _m468AccountReadAgain=false;
   _m468VerifiedAccountsLoaded=false;
  }catch(_){
   _m627ClosingSession=false;
   rethrow;
  }
 }
 void _m627AbortFailedLogout(){
  _m627ClosingSession=false;
  // M636: if the genuine Home DB close fails, keep the owner signed in
  // but offer verified finance Retry rather than a frozen
  // `Signing out` state with a disposed authority or fake old balances.
  if(mounted)setState((){
   ready=false;
   _financeLoadFailure=waffraIsEnglish?
    'Sign-out was cancelled. Retry safely to verify your financial data.':
    'توقف تسجيل الخروج. أعد المحاولة بأمان للتحقق من بياناتك المالية.';
  });
 }

 // Account filters are presentation-only; never inherit them for new money.
 List<WaffraAccountBalance> _m467Accounts=const <WaffraAccountBalance>[];
 // M648: bounded verified transfer read is cached per displayed account.
 // It never affects startup binding or creates a MoneyEntry financial debit.
 String? _m648TransferAccountKey;
 Future<List<WaffraInternalTransferHistory>>? _m648TransferRead;
 String? _m649SavingsAccountKey;
 Future<List<WaffraVerifiedGoalMovement>>? _m649SavingsRead;
 // M650: memoize receipt/linked-money account provenance for paid dues.
 // Display-only metadata, never an extra payment or a source-account guess.
 final Map<String,Future<String?>> _m650DueSourceCache={};
 Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){
  return _m650DueSourceCache.putIfAbsent(entry.id,()async{
   if(entry.sourceType=='goal_due'&&
      entry.goalWalletPaidMinor>=
       WaffraRecurringPolicy.toHalalas(entry.amount)){
    return waffraIsEnglish?'Savings goal wallet':'محفظة الهدف الادخاري';
   }
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)return null;
   final link=await WaffraVerifiedAccountsApi(bridge:bridge)
    .readExistingEntryAccount(entryId:entry.id);
   if(!link.exists||link.accountId==null||_m627ClosingSession)return null;
   for(final account in _m467Accounts){
    if(account.id==link.accountId)return _m647VerifiedAccountLabel(account);
   }
   return null; // Archived/missing account identity must not be invented.
  });
 }
 String? _m652ActivityAccountKey;
 Future<({
  List<WaffraInternalTransferHistory> transfers,
  List<WaffraVerifiedGoalMovement> savings,
 })>? _m652ActivityRead;
 void _m648InvalidateTransfers(){
  _m648TransferAccountKey=null;
  _m648TransferRead=null;
  _m649SavingsAccountKey=null;
  _m649SavingsRead=null;
  _m652ActivityAccountKey=null;
  _m652ActivityRead=null;
  _m650DueSourceCache.clear();
 }
 Future<List<WaffraInternalTransferHistory>> _m648HomeTransfers(String account){
  if(_m648TransferAccountKey==account&&_m648TransferRead!=null){
   return _m648TransferRead!;
  }
  final bridge=_financeBinding?.accountsBridge;
  _m648TransferAccountKey=account;
  _m648TransferRead=bridge==null
   ?Future<List<WaffraInternalTransferHistory>>.error(
     StateError('Verified transfer history source unavailable'))
   :WaffraVerifiedAccountsApi(bridge:bridge)
     .readInternalTransferHistory(accountId:account=='all'?null:account);
  return _m648TransferRead!;
 }
 // M649: source linked goal movements are read only and display account-bound.
 Future<List<WaffraVerifiedGoalMovement>> _m649HomeSavings(String account){
  if(_m649SavingsAccountKey==account&&_m649SavingsRead!=null){
   return _m649SavingsRead!;
  }
  final bridge=_financeBinding?.accountsBridge;
  _m649SavingsAccountKey=account;
  _m649SavingsRead=bridge==null?
   Future<List<WaffraVerifiedGoalMovement>>.error(
    StateError('Verified goal source unavailable')):
   WaffraVerifiedAccountsApi(bridge:bridge)
    .readGoalAccountMovementHistory(accountId:account=='all'?null:account);
  return _m649SavingsRead!;
 }
 // Preserve the first Home frame: merged reads are cached, not awaited.
 Future<({
  List<WaffraInternalTransferHistory> transfers,
  List<WaffraVerifiedGoalMovement> savings,
 })> _m652UnifiedActivities(String account){
  if(_m652ActivityAccountKey==account&&_m652ActivityRead!=null){
   return _m652ActivityRead!;
  }
  _m652ActivityAccountKey=account;
  _m652ActivityRead=()async{
   final transfers=await _m648HomeTransfers(account);
   final savings=await _m649HomeSavings(account);
   return (transfers:transfers,savings:savings);
  }();
  return _m652ActivityRead!;
 }
 WaffraAccountContextReadResult? _m467AccountContext;
 Set<String>? _m684ScopedEntryIds;
 String _m467SelectedAccount='all';
 bool _m467AccountChoiceRestored=false;
 bool _m468VerifiedAccountsLoaded=false;
 Future<void>? _m468AccountReadInFlight;
 bool _m468AccountReadAgain=false;

 String get _m467ChoiceKey{
  final owner=widget.profile.provider+'|'+widget.profile.phone.trim()+
   '|'+widget.profile.email.trim().toLowerCase();
  final hash=sha256.convert(utf8.encode(owner)).toString();
  return 'waffra_home_account_display_'+hash.substring(0,20);
 }

 // Concurrent save, transfer, resume and refresh events share one account read.
 // A later request gets ONE trailing replay so a new commit is not missed.
 Future<void> _m467RefreshHomeAccounts()async{
  final active=_m468AccountReadInFlight;
  if(active!=null){
   _m468AccountReadAgain=true;
   await active;
   return;
  }
  final running=_m468ReadVerifiedAccountsOnce();
  _m627OutstandingAccountReads.add(running);
  _m468AccountReadInFlight=running;
  try{await running;}
  finally{
   _m627OutstandingAccountReads.remove(running);
   // Do not detach a newer retry after an older timeout finishes late.
   if(identical(_m468AccountReadInFlight,running)){
    _m468AccountReadInFlight=null;
    final again=_m468AccountReadAgain;
    _m468AccountReadAgain=false;
    if(again&&mounted&&!_m627ClosingSession)unawaited(_m467RefreshHomeAccounts());
   }
  }
 }

 Future<void> _m468ReadVerifiedAccountsOnce()async{
  final readEpoch=_m627AccountEpoch;
  if(_m627ClosingSession)return;
  try{
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)throw StateError('No verified account bridge');
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   final accounts=await api.balances();
   var chosen=_m467SelectedAccount;
   if(!_m467AccountChoiceRestored){
    final p=await SharedPreferences.getInstance();
    chosen=p.getString(_m467ChoiceKey)??'all';
   }
   if(chosen!='all'&&
      !accounts.any((a)=>!a.archived&&a.id==chosen))chosen='all';
   final now=DateTime.now();
   final month=now.year.toString().padLeft(4,'0')+'-'+
    now.month.toString().padLeft(2,'0');
   // Month-only context plus lightweight all-time account membership.
   final contextView=chosen=='all'?null:await api.readAccountContext(
    monthIso:month,
    selectedAccountId:chosen,summaryOnly:true);
   final scopedIds=chosen=='all'?null:
    await api.readAccountEntryIds(accountId:chosen);
   if(!mounted||_m627ClosingSession||readEpoch!=_m627AccountEpoch)return;
   // A user may switch accounts while this async SQL projection is running.
   // Never repaint that newly chosen view with a stale older selection.
   if(_m467AccountChoiceRestored&&_m467SelectedAccount!=chosen){
    _m468AccountReadAgain=true;
    return;
   }
   // Invalidate only after the new account source has been verified.
   // A fresh transfer card read is asynchronous and never awaited by Home.
   _m648InvalidateTransfers();
   setState((){
    _m467Accounts=accounts.where((a)=>!a.archived).toList();
    _m467AccountContext=contextView;
    _m684ScopedEntryIds=scopedIds;
    _m467SelectedAccount=chosen;
    _m467AccountChoiceRestored=true;
    _m468VerifiedAccountsLoaded=true;
   });
  }catch(error){
   debugPrint('Home accounts view unavailable: '+error.runtimeType.toString());
   if(!mounted||_m627ClosingSession||readEpoch!=_m627AccountEpoch)return;
   // Never show a stale bank balance when verified SQL projection is absent.
   setState((){
    _m467Accounts=const <WaffraAccountBalance>[];
    _m467AccountContext=null;
    _m684ScopedEntryIds=null;
    _m467SelectedAccount='all';
    _m467AccountChoiceRestored=false;
    _m468VerifiedAccountsLoaded=false;
   });
  }
 }

 String get _m467AccountLabel{
  if(_m467SelectedAccount=='all')return (waffraIsEnglish?'All accounts':'كل الحسابات');
  for(final account in _m467Accounts){
   if(account.id==_m467SelectedAccount)return account.name;
  }
  return (waffraIsEnglish?'All accounts':'كل الحسابات');
 }

 Iterable<MoneyEntry> _m467ScopedEntries(){
  final selected=_m467SelectedAccount;
  if(selected=='all')return entries;
  final ids=_m684ScopedEntryIds;
  if(ids==null)return const <MoneyEntry>[];
  // Read-only exact-ID projection over the authenticated hydrated ledger.
  return _m684Periods.byIds(ids);
 }

 List<MoneyEntry> _m684ScopedMonthEntries(int year,int month){
  final monthRows=_m684Periods.month(year,month);
  if(_m467SelectedAccount=='all')return monthRows;
  final ids=_m684ScopedEntryIds;
  if(ids==null)return const <MoneyEntry>[];
  return monthRows.where((e)=>ids.contains(e.id)).toList(growable:false);
 }

 double _m467ShownBalance(){
  if(_m467SelectedAccount=='all'){
   if(!_m468VerifiedAccountsLoaded)return waffraAvailableCash(entries,goals);
   // The sum of verified balances includes openings, account transfers and
   // wallet movements. Unassigned ledger entries do not alter accounts.
   return _m467Accounts.fold<int>(0,(total,a)=>total+a.balanceMinor)/100;
  }
  for(final a in _m467Accounts){
   if(a.id==_m467SelectedAccount)return a.balanceMinor/100;
  }
  return 0;
 }

 Future<void> _m467PickHomeAccount()async{
  // M527: a cold verified read must not block the first sheet frame.
  // No unverified account may ever appear as a selectable money source.
  final pendingAccounts=_m468VerifiedAccountsLoaded
   ?null:_m467RefreshHomeAccounts();
  if(!mounted)return;
  final next=await showModalBottomSheet<String>(
   context:context,isScrollControlled:true,useSafeArea:true,
   showDragHandle:true,
   builder:(sheet){
    Widget verifiedChoices()=>WaffraHomeAccountsSheet(
     english:waffraIsEnglish,
     selected:_m467SelectedAccount,
     accounts:_m467Accounts);
    // Warm cache: render original selector with no FutureBuilder wait frame.
    if(pendingAccounts==null)return verifiedChoices();
    return FutureBuilder<void>(
     future:pendingAccounts,
     builder:(ctx,state){
      if(state.connectionState!=ConnectionState.done){
       return SafeArea(top:false,child:SizedBox(
        key:const Key('m527-account-picker-loading'),
        height:170,
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
         const CircularProgressIndicator(strokeWidth:2.7),
         const SizedBox(height:17),
         Text(waffraIsEnglish?'Verifying accounts…':
          'جارٍ التحقق من الحسابات…'),
        ])));
      }
      if(!_m468VerifiedAccountsLoaded){
       return SafeArea(top:false,child:Padding(
        key:const Key('m527-account-picker-verification-failed'),
        padding:const EdgeInsets.symmetric(horizontal:22,vertical:30),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
         Text(waffraIsEnglish?
          'Could not verify your accounts. No balances were changed.':
          'تعذر التحقق من الحسابات. لم تتغير أي أرصدة.',
          textAlign:TextAlign.center),
         const SizedBox(height:14),
         TextButton(
          onPressed:()=>Navigator.pop(sheet),
          child:Text(waffraIsEnglish?'Close and retry':'إغلاق وإعادة المحاولة')),
        ])));
      }
      return verifiedChoices();
     });
   });
  if(next==null||!mounted)return;
  if(next=='manage'){
   await openVerifiedAccounts();
   return;
  }
  if(next!='all'&&
     !_m467Accounts.any((a)=>a.id==next&&!a.archived))return;
  setState(()=>_m467SelectedAccount=next);
  try{
   final p=await SharedPreferences.getInstance();
   await p.setString(_m467ChoiceKey,next);
  }catch(error){
   debugPrint('Account display preference unavailable: '+error.runtimeType.toString());
  }
  if(mounted)await _m467RefreshHomeAccounts();
 }

 Future<void> openVerifiedAccounts()async{
  await _ensureFinanceBound();
  if(!mounted)return;
  final verifiedBridge=_financeBinding?.accountsBridge;
  if(verifiedBridge==null){
   snack(context,waffraIsEnglish?
    'Accounts require an activated, verified encrypted finance source.':
    'الحسابات تحتاج تفعيل مصدر مالي مشفّر وموثّق أولًا.');
   return;
  }
  await Navigator.of(context).push<void>(MaterialPageRoute(
   builder:(_)=>WaffraAccountsManagerPage(
    repository:WaffraVerifiedAccountsApi(bridge:verifiedBridge),
    english:waffraIsEnglish,
    // M667: the Accounts button enters the *same* Home three-mode sheet as +.
    // Keep the Home-owned verified finance and transfer save paths intact.
    onCreateHomeTransaction:()=>entrySheet(),
    incomeCategories:categories.where((item)=>item.income&&item.isSubcategory&&
      waffraCategoryAvailableForNewEntry(categories,item))
      .map((item)=>item.name).toList(growable:false),
    expenseCategories:categories.where((item)=>!item.income&&item.isSubcategory&&
      waffraCategoryAvailableForNewEntry(categories,item))
      .map((item)=>item.name).toList(growable:false),
    availableBudgets:{for(final item in namedBudgets.where((b)=>
      !b.deleted&&b.budgetActive&&b.budget>0))item.id:item.budgetLabel??item.name},
    onTransferConfirmed:(_)=>_learnManualTransferPreference(),
   )));
  if(mounted)await _m467RefreshHomeAccounts();
 }

 /// Internal transfers use the verified account ledger, never expense.
 /// New manual income and expenses require an explicit money account.
 Future<void> openVerifiedTransfer()async{
  try{
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null){
    if(mounted)snack(context,waffraIsEnglish?
     'Transfers and new manual entries require verified money accounts.':
     'التحويل والدخل والمصروف اليدوي يحتاجوا حسابات مالية موثّقة.',
     isError:true);
    return;
   }
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   final accounts=await api.balances();
   if(!mounted)return;
   // Two different verified accounts are checked only on final submit.
   final knownIds=accounts.map((a)=>a.id).toSet();
   await Navigator.of(context).push<void>(MaterialPageRoute(
    builder:(transferContext)=>Scaffold(
     appBar:AppBar(title:WaffraText(waffraIsEnglish?
      'Transfer between my accounts':'تحويل بين حساباتي')),
     body:WaffraAccountTransactionForm(
      accounts:accounts,english:waffraIsEnglish,
      initialOperation:WaffraAccountOperation.transfer,
      onCreateAccount:(group,createProvider)async{
       await openVerifiedAccounts();
       if(!mounted)return null;
       final updated=await api.balances();
       final created=updated.where((a)=>
        !a.archived&&!knownIds.contains(a.id)).toList();
       knownIds.addAll(updated.map((a)=>a.id));
       return created.length==1?created.single:null;
      },
      onConfirmTransfer:(draft)async{
       await api.transfer(id:draft.requestId,
        fromAccountId:draft.fromId,toAccountId:draft.toId,
        amountMinor:draft.amountMinor,occurredIso:draft.occurredIso,
        note:draft.memo,userConfirmed:true);
       try{await _learnManualTransferPreference();}catch(_){}
       if(transferContext.mounted)Navigator.of(transferContext).pop();
      },
     ),
    )));
  }catch(error){
   debugPrint('Verified transfer route unavailable: ${error.runtimeType}');
   if(mounted)snack(context,waffraIsEnglish?
    'Transfer not verified. Check My Accounts.':
    'تعذر تأكيد التحويل. راجع حساباتي.',isError:true);
  }
 }
 WaffraFinanceAuthorityRead? _lastFinanceAuthorityRead;
 final smsHashes=<String>{};
 final expandedCategoryIds=<String>{};
 final learnedMerchantCategories=<String,String>{};
 final entries=<MoneyEntry>[],categories=<BudgetCategory>[],goals=<SavingGoal>[],recurring=<RecurringBill>[];
 // Verified/legacy hydrated entries are immutable only for this read
 // projection; every ledger mutation invalidates it before the next view.
 WaffraFinancePeriodIndex? _m684PeriodCache;
 WaffraFinancePeriodIndex get _m684Periods=>
  _m684PeriodCache??=WaffraFinancePeriodIndex(entries);
 void _m684InvalidatePeriodRead(){_m684PeriodCache=null;}
 final namedBudgets=<WaffraNamedBudget>[];
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
 String? selectedNamedBudgetCategoryId;
 String budgetStatusFilter='active'; // UI-only: active budgets by default.
 String budgetSearch='';
 String budgetSort='default'; // name, limit or spending, UI-only.
 DateTimeRange? transactionsDateRange;
 double? minTransactionAmount,maxTransactionAmount;
 int tab=0,year=DateTime.now().year,month=DateTime.now().month;
 // UI-only history: no finance record or persisted state is modified.
 final List<int> _tabBackStack=<int>[];
 bool goalsOpened=false;
 String? _lastWidgetRevision;
 // Exact last finance ledger string seen or committed, including null vs [].
 // Detect partial widget saves even if the last-save marker never committed.
 // Snapshot marker is intentionally held for legacy crash forensics.
 // ignore: unused_field
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
 Future<void> setAnimationLevel(String next)async {
  if(!{'full','balanced','reduced','off'}.contains(next))return;
  waffraAnimationLevel.value=next;
  if(mounted)setState((){});
  final p=await SharedPreferences.getInstance();
  await p.setString('waffra_animation_level',next);
 }
 String search='',typeFilter='الكل',categoryFilter='الكل',period='شهري';
 String categorySearch='',categoryDisplay='all',categoryTypeFilter='all',goalDisplay='all',recurringDisplay='all';
 String categorySort='default'; // Presentation-only; never rewrites finance categories.
 String goalSearch='',recurringSearch='';
 bool _m689GoalSearchOpen=false;
 bool _m689DueSearchOpen=false; // Presentation-only queries.
 bool categoryMineOnly=false;
 bool categoryFiltersOpen=false; // Compact category-filter accordion; UI-only state.
 bool monthlyBudgetDetailsOpen=false; // Monthly budget accordion, presentation only.
 DateTime budgetViewedMonth=DateTime(DateTime.now().year,DateTime.now().month,1);
  String? forecastCategory;
  int forecastReduction=20;
 bool recurringRemindersEnabled=false;
 bool ready=false;
 String? _financeLoadFailure;
 String? lastBackupGeneratedAt;
 int? lastBackupBytes;
 bool protectRecentApps=true;
 // M528: stable permission/consent futures across unrelated profile repaints.
 Future<bool>? _m528SmsEnabledFuture;
 Future<bool> _m528SmsEnabled()=>
  _m528SmsEnabledFuture??=WaffraAutoSms.enabled();
 String? _accountOpenSection;
 String accountSearch='';
 bool addFabExpanded=false;
 final LayerLink _fabOverlayAnchor=LayerLink();
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
   // M474: open sheet promptly after closing the menu.
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
 // M689: financial activities are always visible; no expand/collapse state.
 DateTime? _m468LastResumeSmsScan;
 // #410: only ephemeral user-edited SMS form fields, keyed by message hash;
 // never persist a duplicate raw SMS outside the verified encrypted source.
 final Map<String,Map<String,Object?>> _m492SmsEditorDrafts={};
 bool _m486ResumeQueued=false;
 void _m468OnResume(){
  if(!mounted||!ready||!widget.postAuthVisible||
     WaffraExternalMediaSession.shouldSkipResumeBackgroundWork)return;
  _m621OnFinanceNoticeTap();
  // M486 #419: biometrics/OS resume must render a frame before expensive
  // SQLCipher/widget and SMS I/O start. Collapse repeated lifecycle events.
  if(_m486ResumeQueued)return;
  _m486ResumeQueued=true;
  WidgetsBinding.instance.addPostFrameCallback((_){
   _m486ResumeQueued=false;
   if(!mounted||!ready||!widget.postAuthVisible||
      WaffraExternalMediaSession.shouldSkipResumeBackgroundWork)return;
   // Verified finance/widget read is still required, merely deferred one
   // frame. Never infer cash from an unverified snapshot.
   if(accountOpened&&mounted)setState((){
    _m528SmsEnabledFuture=null;
   });
   unawaited(_syncWidgetTransactions());
   final now=DateTime.now();
   final last=_m468LastResumeSmsScan;
   if(_autoSmsRefreshInFlight!=null||
      (last!=null&&now.difference(last)<const Duration(seconds:20)))return;
   _m468LastResumeSmsScan=now;
   // Real-time receiver already stages new SMS. A lifecycle resume must not
   // launch a four-page historical scan while the UI unlock animation runs.
   // The owner's explicit Rescan action continues any incomplete history.
   unawaited(_refreshAutoSmsInbox());
  });
 }
 @override void initState(){super.initState();WaffraBackNavigation.onHomeBack=_registeredBackHandler;_dashboardScrollController.addListener(_handleDashboardScroll);waffraReturnHome.addListener(_returnToHome);waffraIncomingSms.addListener(_receiveSharedSms);waffraAutoSmsUpdates.addListener(_receiveAutoSmsNotice);waffraFinanceNoticeTap.addListener(_m621OnFinanceNoticeTap);waffraWidgetAction.addListener(_receiveWidgetAction);_widgetReloadListener=AppLifecycleListener(onResume:_m468OnResume);unawaited(_loadFinanceSafely());}
 void _returnToHome(){if(mounted)setState((){_tabBackStack.clear();tab=0;accountOpened=false;goalsOpened=false;addFabExpanded=false;});}
 void _receiveWidgetAction(){
  // New pre-auth barrier. Preserve the original owner/action guard below
  // because existing Widgets/source regressions depend on its semantics.
  if(!mounted||!ready||!widget.postAuthVisible)return;
  if(!mounted||!ready||waffraWidgetAction.value!='add')return;
  waffraWidgetAction.value=null;
  setState((){tab=0;goalsOpened=false;addFabExpanded=false;});
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(entrySheet());});
 }
 bool _autoSmsReviewOpen=false;
 bool _autoSmsReviewExpanded=false; // Presentation-only: collapsed by default.
 bool _autoSmsStatusChecked=false;
 bool _autoSmsHistoryComplete=false;
 bool _autoSmsRescanRunning=false;
 Map<String,Object?> _autoSmsProgress=const <String,Object?>{};
 // Count this exact explicit rescan, never reuse historical cumulative count.
 int? _autoSmsLastRescanScanned;
 DateTime? _autoSmsLastChecked;
 String? _autoSmsStatusProblem;
 // M661: warn once while saved encrypted custom rules are unavailable.
 bool _m661RuleLoadErrorNotified=false;
 final List<Map<String,Object?>> _autoSmsPending=<Map<String,Object?>>[];

 String get _smsRuleOwnerKey=>WaffraSmsLocalRuleStore.ownerKey(
  provider:widget.profile.provider,phone:widget.profile.phone,
  email:widget.profile.email);

 Future<void> _openSmsRules({String? seedMessage,String? seedKind,
  String seedSender='',String seedCategory=''})async{
  if(_smsRuleOwnerKey.isEmpty){
   if(mounted)snack(context,waffraIsEnglish?
    'Sign in with a verified phone or email before editing SMS rules.':
    'سجل دخولك برقم جوال أو بريد مؤكد قبل تعديل القواعد.',isError:true);
   return;
  }
  final bankAccounts=<String,String>{};
  try{
   final verified=await _financeBinding?.accountsBridge?.readVerifiedAccounts();
   if(verified!=null){
    for(final account in verified.balances.where((a)=>!a.archived)){
     if(account.kind=='bank'||account.kind=='wallet'){
      bankAccounts[account.id]=account.name;
     }
    }
   }
  }catch(_){ /* Local rules still work without SQLCipher accounts. */ }
  if(!mounted)return;
  final facts=seedMessage==null?null:
   WaffraBankSmsFactsParser.parse(seedMessage);
  final suffix=seedKind=='income'?
   (facts?.destinationSuffix??''):
   (facts?.sourceSuffix??'');
  final ruleSaved=await Navigator.push<bool>(context,MaterialPageRoute(
   builder:(_)=>WaffraSmsRuleSettingsPage(
    english:waffraIsEnglish,ownerKey:_smsRuleOwnerKey,
    seedKind:seedKind,seedSender:seedSender,
    seedCategory:seedCategory,
    seedAccountSuffix:suffix,bankAccounts:bankAccounts,
    scannedMessages:_autoSmsPending.map((row)=>
     row['body'] is String?row['body'] as String:'').toList(),
    scannedSenders:_autoSmsPending.map((row)=>
     row['sender'] is String?row['sender'] as String:'').toList(),
    incomeCategories:categories.where((c)=>c.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c))
     .map((c)=>c.name).toList(),
    expenseCategories:categories.where((c)=>!c.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c))
     .map((c)=>c.name).toList(),
    seedMessage:seedMessage,
    onNotice:(message)=>snack(context,message),
    // M661: manual (+) rule saves also reclassify the current native queue.
    onRulesChanged:()=>_receiveAutoSmsNotice(),
   )));
  // Apply saved local rules to the already queued SMS only. Never perform
  // hidden Android history paging during the rule editor's return animation.
  // A partial original-month scan continues only on explicit Rescan.
  if(mounted&&ruleSaved==true)unawaited(_refreshAutoSmsInbox());
 }

 Future<void> _recordConfirmedSmsAccountAssociation({
  required MoneyEntry record,required String sender,
  required String? accountId,
 })async{
  // Learning happens only AFTER a confirmed finance commit. It never posts
  // money, changes a past entry, or sets autoPost classification permissions.
  if(accountId==null||accountId.isEmpty||sender.trim().isEmpty||
     record.sourceType!='sms'||_smsRuleOwnerKey.isEmpty)return;
  final facts=WaffraBankSmsFactsParser.parse(record.notes);
  if(!facts.canAutoPostAsIncomeExpense||
     (facts.kind==WaffraBankOperationKind.income)!=record.income)return;
  try{
   final verified=await _financeBinding?.accountsBridge?.readVerifiedAccounts();
   if(verified==null||!verified.balances.any((a)=>
       !a.archived&&a.id==accountId))return;
   final suffix=record.income?
    facts.destinationSuffix:facts.sourceSuffix;
   await const WaffraSmsAccountLearningStore().confirm(
    owner:_smsRuleOwnerKey,sender:sender,accountId:accountId,
    suffix:suffix);
  }catch(_){
   // Learning is best-effort; a confirmed financial write is never rolled
   // back because a nonauthoritative suggestion could not be persisted.
  }
 }

 // Local classification learning never authorizes financial posting.
 // Only a specific, independently classified message may produce a rule.
 Future<bool> _learnSafeSmsRule({
  required String body,required String sender,
  required String kind,String category='',
 })async{
  if(_smsRuleOwnerKey.isEmpty)return false;
  final candidate=WaffraSmsLocalRules.suggestedRule(
   body:body,sender:sender,kind:kind,category:category,confidentOnly:true);
  if(candidate==null)return false;
  final store=const WaffraSmsLocalRuleStore();
  final prior=await store.read(_smsRuleOwnerKey);
  // Same sender, category and direction are reused. Never change an
  // already-authorized autoPost rule's matching criteria behind the user.
  final updated=WaffraSmsLocalRules.upsertLearned(
   existing:prior,candidate:candidate);
  if(identical(updated,prior))return prior.any((r)=>
   r.resolvedKind==kind&&r.category==category&&
   WaffraSmsLocalRules.matches(r,body,sender:sender));
  await store.write(_smsRuleOwnerKey,updated);
  // M651: a newly confirmed sender-specific rule must update old pending
  // SMS suggestions too. The existing debounce refresh imports no history,
  // classifies on a worker isolate, and never authorizes a money posting.
  _receiveAutoSmsNotice();
  return true;
 }

 /// Manual entries have no bank SMS sender. Learn only a non-posting
 /// description/category hint after an independently verified save.
 Future<void> _learnManualTransferPreference()async{
  if(_smsRuleOwnerKey.isEmpty)return;
  final store=const WaffraSmsLocalRuleStore();
  final original=await store.read(_smsRuleOwnerKey);
  final updated=WaffraSmsLocalRules.upsertLearned(
   existing:original,candidate:WaffraSmsLocalRules.manualTransferPattern());
  if(!identical(original,updated)){
   await store.write(_smsRuleOwnerKey,updated);
   // Debounced non-posting review refresh; no Android history import.
   _receiveAutoSmsNotice();
  }
 }
 // Reuse one senderless review-only category bucket after a committed
 // manual OR bank-SMS entry; sender/suffix account learning stays separate.
 Future<void> _learnManualCategoryPreference(MoneyEntry record)async{
  if(_smsRuleOwnerKey.isEmpty||
     (record.sourceType!='manual'&&record.sourceType!='sms'))return;
  final merchant=waffraMerchantKey(record.title,income:record.income)??record.title;
  final candidate=WaffraSmsLocalRules.manualCategoryPattern(
   description:merchant,category:record.category,income:record.income);
  if(candidate==null)return;
  final store=const WaffraSmsLocalRuleStore();
  final previous=await store.read(_smsRuleOwnerKey);
  final next=WaffraSmsLocalRules.upsertLearned(
   existing:previous,candidate:candidate);
  if(!identical(next,previous)){
   await store.write(_smsRuleOwnerKey,next);
   // The pending queue is reclassified on its existing background isolate.
   _receiveAutoSmsNotice();
  }
 }

 // Retained single-message reference for on-demand review and M473 parity;
 // the production bulk queue now uses the background compute worker.
 // ignore: unused_element
 Map<String,Object?>? _localSmsClassification(
  Map<String,Object?> item,List<WaffraSmsLocalRule> custom){
  final body=item['body'],sender=item['sender'];
  if(body is! String||body.trim().isEmpty)return null;
  final parsed=BankParser.parse(body);
  final facts=WaffraBankSmsFactsParser.parse(body);
  final special=WaffraSmsLocalRules.resolveSpecial(
   body:body,sender:sender is String?sender:'',
   bankKind:item['sensitiveOtp']==true?
    WaffraBankOperationKind.uncertain:facts.kind,
   custom:custom);
  if(special!=null)return <String,Object?>{
   'rule':special.name,'kind':special.resolvedKind,
   'category':special.category,'income':false,
   'defaultSeed':special.builtIn,
  };
  if(facts.pending||parsed.amount==null||parsed.amount!<=0||
     parsed.requiresCurrencyReview||
     WaffraSmsCurrencies.requiresReviewForSarLedger(body))return null;
  if((facts.kind==WaffraBankOperationKind.income)!=parsed.income &&
     (facts.kind==WaffraBankOperationKind.income||
      facts.kind==WaffraBankOperationKind.expense))return null;
  final rule=WaffraSmsLocalRules.resolve(
   body:body,sender:sender is String?sender:'',
   bankKind:facts.kind,custom:custom);
  if(rule==null||!categories.any((c)=>c.name==rule.category&&
     c.income==rule.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c)))return null;
  return <String,Object?>{
   'rule':rule.name,'kind':rule.resolvedKind,
   'category':rule.category,'income':rule.income,
  };
 }

 Timer? _m632SmsNoticeTimer;
 void _receiveAutoSmsNotice(){
  if(!mounted||!ready||!widget.postAuthVisible||
     _m627ClosingSession)return;
  // One refresh per notification BURST, not one full 2k-message reparse
  // for each new or repeated Android receiver callback.
  _m632SmsNoticeTimer?.cancel();
  _m632SmsNoticeTimer=Timer(const Duration(milliseconds:900),(){
   _m632SmsNoticeTimer=null;
   if(mounted&&ready&&!_m627ClosingSession){
    // A received native notice can queue during first-run biometric setup.
    // Do not start encrypted history work until real Home is interactive.
    if(!widget.postAuthVisible)return;
    unawaited(_refreshAutoSmsInbox());
   }
  });
 }
 Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{
  if(_autoSmsRescanRunning||!mounted)return;
  final feedback=feedbackContext??context;
  setState(()=>_autoSmsRescanRunning=true);
  try{
   // Do not rewind the durable month cursor after it has completed.
   // Repeated explicit scans read only newly arrived provider rows; a
   // partially completed first history pass continues from its last row.
   final active=_autoSmsRefreshInFlight;
   if(active!=null)await active;
   final before=await WaffraAutoSms.scanProgress();
   // M638: Rescan first removes only encrypted, unconfirmed SMS review
   // candidates no longer present in the Android inbox. This checked
   // native source operation fails closed on missing permission or error.
   // It runs on SMS I/O executor, never the first Home frame/UI thread.
   final removedFromPhone=await WaffraAutoSms.reconcilePendingWithAndroidInboxChecked();
   final continuingInitialHistory=before?['initialComplete']!=true;
   if(!mounted)return;
   await _refreshAutoSmsInbox(importMonth:true);
   if(!mounted)return;
   final after=await WaffraAutoSms.scanProgress();
   final priorScanned=before?['scanned'] is num?
    (before!['scanned'] as num).toInt():0;
   final nowScanned=after?['scanned'] is num?
    (after!['scanned'] as num).toInt():priorScanned;
   // The native cursor never rewinds; counters are cumulative and this
   // button reports only the difference observed during this invocation.
   final scanned=(nowScanned-priorScanned).clamp(0,2147483647);
   if(after!=null)setState((){
    _autoSmsProgress=after;
    _autoSmsLastRescanScanned=scanned;
   });
   final previous=before?['added'] is num?
    (before!['added'] as num).toInt():0;
   final current=after?['added'] is num?
    (after!['added'] as num).toInt():previous;
   final added=(current-previous).clamp(0,2147483647);
   if(_autoSmsStatusProblem!=null){
    snack(feedback,_autoSmsStatusProblem!,isError:true);
   }else if(after?['complete']!=true){
    final continuation=continuingInitialHistory?
     (waffraIsEnglish?'Continuing first history scan.':
      'جارٍ استكمال الفحص الأول للرسائل السابقة.'):
     (waffraIsEnglish?'More newly received messages remain to scan.':
      'لسه فيه رسائل جديدة محتاجة استكمال الفحص.');
    snack(feedback,waffraIsEnglish?
     'Examined $scanned new inbox rows • $added added • '
      '$removedFromPhone deleted from phone removed from review • '
      '${_autoSmsPending.length} awaiting review. $continuation':
     'تم فحص $scanned رسالة من الدفعة الحالية • $added اتضافت للمراجعة • '
      '$removedFromPhone اتحذفت من المراجعة بعد حذفها من الهاتف • '
      '${_autoSmsPending.length} بانتظار المراجعة. $continuation');
   }else{
    if(feedbackContext!=null&&!feedbackContext.mounted)return;
    if(added==0){
     snackSuccess(feedback,waffraIsEnglish?
      'No new messages to review.':'لا توجد رسائل جديدة للمراجعة.');
    }else{
     snackSuccess(feedback,waffraIsEnglish?
      '$added new messages added for review.':
      'تمت إضافة $added رسالة جديدة للمراجعة.');
    }
   }
  }catch(_){
   if(mounted&&(feedbackContext==null||feedbackContext.mounted))snack(feedback,waffraIsEnglish?
    'SMS rescan failed. Pending messages were not deleted.':
    'تعذر إعادة الفحص. لم تُحذف الرسائل المعلقة.',isError:true);
  }finally{
   if(mounted)setState(()=>_autoSmsRescanRunning=false);
  }
 }
 Future<void>? _autoSmsRefreshInFlight;
 bool _autoSmsRefreshAgain=false;
 bool _autoSmsImportAgain=false;
 Future<void> _refreshAutoSmsInbox({bool importMonth=false})async{
  final active=_autoSmsRefreshInFlight;
  if(active!=null){
   _autoSmsRefreshAgain=true;
   _autoSmsImportAgain|=importMonth;
   await active;
   return;
  }
  final running=_runAutoSmsRefresh(importMonth:importMonth);
  _autoSmsRefreshInFlight=running;
  try{await running;}finally{
   _autoSmsRefreshInFlight=null;
   if(_autoSmsRefreshAgain){
    final scan=_autoSmsImportAgain;
    _autoSmsRefreshAgain=false;
    _autoSmsImportAgain=false;
    if(mounted)unawaited(_refreshAutoSmsInbox(importMonth:scan));
   }
  }
 }
 Future<void> _runAutoSmsRefresh({bool importMonth=false})async{
  if(!mounted||!ready||_m627ClosingSession||_financeLoadFailure!=null)return;
  final smsEpoch=_m630HomeStartupEpoch;
  final status=await WaffraAutoSms.trackingStatus();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(status==null||status['enabled']!=true){
   final message=status==null?
    (waffraIsEnglish?'Could not verify bank SMS state. Retry.':
     'تعذر التحقق من حالة الرسائل البنكية. حاول التحديث.'):
    status['permissionGranted']!=true?
     (waffraIsEnglish?'Android SMS permission is not granted.':
      'صلاحية رسائل أندرويد غير مفعّلة بالكامل.'):
    status['profileReady']!=true?
     (waffraIsEnglish?'Sign in to access your bank SMS.':
      'سجّل دخولك لمراجعة رسائل حسابك البنكية.'):
    (waffraIsEnglish?
     'Android permission is granted, but Waffra tracking is paused. Enable it in Security & privacy.':
     'صلاحية أندرويد مفعّلة، لكن متابعة الرسائل موقوفة داخل وفرة. فعّلها من الأمان والخصوصية.');
   setState((){
    _autoSmsStatusChecked=true;
    _autoSmsStatusProblem=message;
    _autoSmsHistoryComplete=false;
    _autoSmsPending.clear();
   });
   return;
  }
  if(importMonth){
   // Bounded native cursor pages; the UI reports real scanned/new counts.
   // Stop if the encrypted review queue is full until the user reviews items.
   try{
    for(var page=0;page<4;page++){
     // Preserve complete month scan but avoid uninterrupted native I/O.
     if(page>0)await Future<void>.delayed(const Duration(milliseconds:500));
     if(!_m630SmsSessionCurrent(smsEpoch))return;
     final imported=await WaffraAutoSms.importConsentMonthChecked();
     final snapshot=await WaffraAutoSms.scanProgress();
     if(_m630SmsSessionCurrent(smsEpoch)&&snapshot!=null)setState(()=>_autoSmsProgress=snapshot);
     final progress=await WaffraAutoSms.trackingStatus();
     if(progress==null||progress['enabled']!=true||
        progress['historyComplete']==true)break;
     if(snapshot?['pending'] is num&&snapshot?['capacity'] is num&&
        (snapshot!['pending'] as num)>=(snapshot['capacity'] as num))break;
     if(imported==0&&snapshot==null)break;
    }
   }catch(_){
    if(_m630SmsSessionCurrent(smsEpoch))setState((){
     _autoSmsStatusChecked=true;
     _autoSmsStatusProblem=waffraIsEnglish?
      'Could not finish reading the SMS history. Retry.':
      'تعذر استكمال فحص الرسائل السابقة. أعد المحاولة.';
    });
    return;
   }
  }
  final results=await WaffraAutoSms.pendingChecked();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(results==null){
   setState((){
    _autoSmsStatusChecked=true;
    // Clear only stale in-memory candidates. Native encrypted data remains
    // untouched and the user sees an explicit recoverable read error.
    _autoSmsPending.clear();
    _autoSmsStatusProblem=waffraIsEnglish?
     'Could not read encrypted SMS queue. Nothing was deleted. Retry.':
     'تعذر قراءة الرسائل المشفرة. لم يُحذف شيء. حاول التحديث.';
   });
   return;
  }
  // Update counts on *every* completed refresh, not just initial import.
  final latestScan=await WaffraAutoSms.scanProgress();
  if(_m630SmsSessionCurrent(smsEpoch)&&latestScan!=null){
   setState((){
    _autoSmsProgress=latestScan;
    _autoSmsLastChecked=DateTime.now();
   });
  }
  // On a vault error keep SMS review available with built-in rules.
  var customRules=<WaffraSmsLocalRule>[];
  if(_smsRuleOwnerKey.isNotEmpty){
   try{
    customRules=await const WaffraSmsLocalRuleStore().read(
     _smsRuleOwnerKey);
    _m661RuleLoadErrorNotified=false;
   }catch(_){
    // M661: built-ins are safe fallback, but never silently claim the
    // owner's saved custom rules ran when encrypted storage is unreadable.
    if(_m630SmsSessionCurrent(smsEpoch)&&!_m661RuleLoadErrorNotified){
     _m661RuleLoadErrorNotified=true;
     snack(context,waffraIsEnglish?
      'Saved SMS rules could not be loaded. Custom exclusions are not active. Try refreshing.':
      'تعذر تحميل قواعد الرسائل المحفوظة. قواعد الاستبعاد المضافة غير نشطة حاليًا. حاول التحديث.',
      isError:true);
    }
   }
  }
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  // Heavy SHA256, bank parser, OTP detection and local-rule matching now
  // run on a background isolate; the main isolate handles only native ACKs
  // and one UI update. No network or database is used inside the worker.
  final classifyClock=kProfileMode?(Stopwatch()..start()):null;
  final categoryNames=<String>[
   for(final c in categories)
    if(c.isSubcategory&&waffraCategoryAvailableForNewEntry(categories,c))
     '${c.income?'1':'0'}:${c.name}',
  ];
  final classified=await compute(waffraM632ClassifySmsQueue,<String,Object?>{
   'results':results,
   'rules':customRules.map((r)=>r.toJson()).toList(growable:false),
   'categories':categoryNames,
   'hashes':smsHashes.toList(growable:false),
  });
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(kProfileMode&&classifyClock!=null){
   debugPrint('WAFFRA_SMS_PERF classify_count=${results.length} '
    'isolate_ms=${classifyClock.elapsedMilliseconds}');
  }
  final waiting=(classified['waiting'] as List).cast<Map<String,Object?>>();
  final toAcknowledge=(classified['excluded'] as List).cast<String>();
  final toAcknowledgeCommitted=(classified['committed'] as List).cast<String>();
  final toRestoreOnAckFailure=
   (classified['retainOnAckFailure'] as List).cast<Map<String,Object?>>();
  // One encrypted native queue commit instead of one platform call per SMS.
  // If the durable acknowledgement fails, retain every pending item in UI.
  if(toAcknowledge.isNotEmpty){
   // Native encrypted ACK is capped at 100 IDs per atomic operation.
   // Drain larger review queues in batches without losing failed items.
   final failedAcks=<String>{};
   for(var from=0;from<toAcknowledge.length;from+=100){
    if(!_m630SmsSessionCurrent(smsEpoch))return;
    final batch=toAcknowledge.skip(from).take(100).toList(growable:false);
    final removed=await WaffraAutoSms.excludeMessages(batch);
    if(!removed)failedAcks.addAll(batch);
   }
   waiting.addAll(toRestoreOnAckFailure.where(
    (row)=>failedAcks.contains(row['id'])));
  }
  // Process verified hashes separately from ordinary user exclusions:
  // only real finance commits may create permanent native anti-replay markers.
  if(toAcknowledgeCommitted.isNotEmpty){
   final failed=<String>{};
   for(var from=0;from<toAcknowledgeCommitted.length;from+=100){
    if(!_m630SmsSessionCurrent(smsEpoch))return;
    final batch=toAcknowledgeCommitted.skip(from).take(100).toList(growable:false);
    if(!await WaffraAutoSms.acknowledgeCommitted(batch))failed.addAll(batch);
   }
   waiting.addAll(toRestoreOnAckFailure.where(
    (row)=>failed.contains(row['id'])));
  }
  final progress=await WaffraAutoSms.trackingStatus();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(progress?['enabled']!=true){
   setState((){
    _autoSmsStatusChecked=true;
    _autoSmsPending.clear();
    _autoSmsStatusProblem=waffraIsEnglish?
     'SMS tracking was paused while reading. Refresh after sign-in.':
     'متابعة الرسائل توقفت أثناء القراءة. حدّث بعد تسجيل الدخول.';
   });
   return;
  }
  setState((){
   _autoSmsStatusChecked=true;
   _autoSmsStatusProblem=null;
   _autoSmsHistoryComplete=progress?['historyComplete']==true;
   _autoSmsPending..clear()..addAll(waiting);
  });
  // Passive SMS review is local-only; it never sends a message to
  // cloud analysis or posts money from an unconfirmed match.
 }
 Future<void> _scanPreviousBankSmsFromSettings()async{
  if(!await WaffraAutoSms.enabled()){
   final status=await WaffraAutoSms.trackingStatus();
   if(mounted)snack(context,status?['permissionGranted']!=true?
    (waffraIsEnglish?'Allow bank SMS in Android permissions first.':
     'اسمح لوفرة بقراءة الرسائل من صلاحيات أندرويد أولًا.'):
    (waffraIsEnglish?
     'Android SMS permission is already allowed. Enable Waffra tracking in Security & privacy.':
     'صلاحية أندرويد مفعّلة بالفعل؛ فعّل متابعة وفرة من الأمان والخصوصية.'));
   return;
  }
  await WaffraAutoSms.importConsentMonth();
  await _refreshAutoSmsInbox(importMonth:true);
  if(!mounted)return;
  // Successful scan opens sender/message review; never auto-posts money.
  if(_autoSmsPending.isEmpty){
   snack(context,_autoSmsStatusProblem!=null?_autoSmsStatusProblem!:
    !_autoSmsHistoryComplete?
     (waffraIsEnglish?'History scan incomplete. Scan again to continue.':
      'فحص الرسائل السابقة لسه ما اكتملش. اضغط فحص مرة تانية للاستكمال.'):
    (waffraIsEnglish?
     'No recent bank SMS found since the first day of the installation month.':
     'لا توجد رسائل بنكية حديثة منذ بداية شهر تثبيت التطبيق.'));
   return;
  }
  await _openAutoSmsInbox();
 }
 Future<void> _openUnknownSmsFromSettings()async{
  if(!await WaffraAutoSms.enabled()){
   final status=await WaffraAutoSms.trackingStatus();
   if(mounted)snack(context,status?['permissionGranted']!=true?
    (waffraIsEnglish?'Allow bank SMS in Android permissions first.':
     'اسمح لوفرة بقراءة الرسائل من صلاحيات أندرويد أولًا.'):
    (waffraIsEnglish?
     'Android SMS permission is already allowed. Enable Waffra tracking in Security & privacy.':
     'صلاحية أندرويد مفعّلة بالفعل؛ فعّل متابعة وفرة من الأمان والخصوصية.'));
   return;
  }
  final notices=await WaffraAutoSms.scanUnknownFinancialSms();
  if(!mounted)return;
  await Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>WaffraUnknownFinancialSmsPage(
    english:waffraIsEnglish,
    messages:List<Map<String,Object?>>.unmodifiable(notices),
    onCreateManual:()async{if(mounted)await entrySheet();},
   )));
 }
 Future<void> _openExcludedSenders()async{
  // M517: whole-sender exclusion and single/bulk message exclusion are
  // different encrypted policies. An empty sender list is NOT zero exclusions.
  final saved=await WaffraAutoSms.excludedSenders();
  final excluded=await WaffraAutoSms.excludedMessages();
  if(!mounted)return;
  if(saved==null||excluded==null){
   snack(context,waffraIsEnglish?
    'Excluded messages could not be verified. Check SMS access and sign-in.':
    'تعذر قراءة الرسائل المستبعدة بأمان. تأكد من صلاحية الرسائل وتسجيل الدخول.',
    isError:true);
   return;
  }
  final senders=saved.toList()
   ..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
  final messages=excluded.toList();
  var busy=false;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(
    child:SizedBox(height:min(620.0,MediaQuery.sizeOf(ctx).height*.78),
     child:Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),
       child:Row(children:[
        const Icon(Icons.block_rounded,color:forest),
        const SizedBox(width:10),
        Expanded(child:WaffraText(waffraIsEnglish?'Excluded SMS':
         'المستبعدون',style:Theme.of(ctx).textTheme.titleLarge)),
       ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),
       child:WaffraText(waffraIsEnglish?
        '${messages.length} excluded messages • ${senders.length} blocked senders. '
        'Restoring an individual message allows it on the next manual rescan; '
        'blocked senders remain blocked. Financial records are unchanged.':
        '${messages.length} رسالة مستبعدة • ${senders.length} مرسل مستبعد. '
        'تقدر ترجع الرسالة خلال 30 يوم من الاستبعاد، وبعدها بيتحذف وصفها '
        'تلقائيًا مع استمرار منع ظهورها تاني في الفحص. '
        'استبعاد المرسل منفصل والعمليات المالية لا تتغير.',
        style:Theme.of(ctx).textTheme.bodySmall)),
      Expanded(child:messages.isEmpty&&senders.isEmpty?
       Center(child:WaffraText(waffraIsEnglish?
        'No excluded SMS':'لا توجد رسائل أو مرسلون مستبعدون')):
       ListView.builder(
        key:const Key('waffra-excluded-sms-list'),
        itemCount:messages.length+senders.length+2,
        itemBuilder:(itemContext,index){
         if(index==0){
          return Padding(padding:const EdgeInsets.fromLTRB(18,12,18,4),
           child:WaffraText(waffraIsEnglish?
            'Individual messages (${messages.length})':
            'رسائل مستبعدة (${messages.length})',
            style:Theme.of(ctx).textTheme.titleSmall));
         }
         if(index<=messages.length){
          final message=messages[index-1];
          final id=message['id'] as String;
          final sender=message['sender'] as String? ?? '';
          final receivedAt=message['receivedAt'] as int? ?? 0;
          final excludedAt=message['excludedAt'] as int? ?? 0;
          final expiresAt=excludedAt>0?
           DateTime.fromMillisecondsSinceEpoch(excludedAt).add(
            const Duration(days:30)):null;
          final remaining=expiresAt==null?null:
           (expiresAt.difference(DateTime.now()).inHours/24).ceil().clamp(0,30);
          final expiryNote=remaining==null?'':waffraIsEnglish?
           ' • ${remaining}d to restore':' • متبقي ${remaining} يوم للاسترجاع';
          final date=receivedAt>0?
           DateTime.fromMillisecondsSinceEpoch(receivedAt):null;
          final dateLabel=date==null?'':
           '${date.day}/${date.month}/${date.year}';
          final labelPrefix=dateLabel.isEmpty?'':'$dateLabel • ';
          return ListTile(
           key:Key('waffra-excluded-message-${id.substring(0,12)}'),
           leading:const Icon(Icons.mark_email_read_outlined,color:emerald),
           title:WaffraText(sender.isNotEmpty?sender:
            (waffraIsEnglish?'Excluded message':'رسالة مستبعدة')),
           subtitle:WaffraText(
            '$labelPrefix••••${id.substring(id.length-8)}$expiryNote',
            style:Theme.of(ctx).textTheme.bodySmall),
           trailing:TextButton(
            onPressed:busy?null:()async{
             refresh(()=>busy=true);
             final restored=await WaffraAutoSms.restoreExcludedMessage(id);
             if(ctx.mounted)refresh((){
              busy=false;
              if(restored)messages.removeWhere((item)=>item['id']==id);
             });
             if(mounted){
              if(restored)snackSuccess(context,waffraIsEnglish?
               'Message restored for the next rescan.':
               'اتلغى استبعاد الرسالة. تقدر ترجعها بإعادة الفحص.');
              else snack(context,waffraIsEnglish?
               'Could not restore the message. Retry.':
               'تعذر إلغاء استبعاد الرسالة. حاول مرة أخرى.',isError:true);
             }
            },child:WaffraText(waffraIsEnglish?'Restore':'إلغاء الاستبعاد')),
          );
         }
         if(index==messages.length+1){
          return Padding(padding:const EdgeInsets.fromLTRB(18,12,18,4),
           child:WaffraText(waffraIsEnglish?
            'Blocked senders (${senders.length})':
            'مرسلون مستبعدون (${senders.length})',
            style:Theme.of(ctx).textTheme.titleSmall));
         }
         final sender=senders[index-messages.length-2];
         return ListTile(
          key:Key('waffra-excluded-sender-${index-messages.length-2}'),
          leading:const Icon(Icons.sms_failed_outlined,color:emerald),
          title:WaffraText(sender,maxLines:2),
          trailing:TextButton(
           onPressed:busy?null:()async{
            refresh(()=>busy=true);
            final restored=await WaffraAutoSms.restoreExcludedSender(sender);
            if(ctx.mounted)refresh((){
             busy=false;
             if(restored)senders.remove(sender);
            });
            if(mounted){
             if(restored)snackSuccess(context,waffraIsEnglish?
              'Sender restored for future SMS.':
              'تم إلغاء استبعاد المرسل للرسائل القادمة.');
             else snack(context,waffraIsEnglish?
              'Could not restore the sender. Retry.':
              'تعذر إلغاء استبعاد المرسل. حاول مرة أخرى.',isError:true);
            }
           },
           child:WaffraText(waffraIsEnglish?'Restore':'إلغاء الاستبعاد')),
         );
        })),
     ]))),
   ));
 }

 /// Real notifications: SMS stay pending until the owner confirms a financial
 /// save or exclusion; no mock notifications are ever presented as real.
 List<WaffraReviewNotice> _m549ReviewNotices(){
  return _autoSmsPending.where((row)=>row['id'] is String)
   .map((row){
    final id=row['id'] as String;
    final sender=(row['sender'] as String?)?.trim()??'';
    final sensitive=row['sensitiveOtp']==true;
    final body=sensitive?'':(row['body'] as String? ?? '');
    final snippet=sensitive?
     (waffraIsEnglish?'Verification message':'رسالة تحقق'):
     body.replaceAll(RegExp(r'\s+'),' ').trim();
    final summary=snippet.length>108?snippet.substring(0,108)+'…':snippet;
    final local=row['local'];
    final localInfo=local is Map?local:null;
    final income=localInfo?['income'];
    final amount=localInfo?['amount'];
    // One message's own verified local suggestion is authoritative for its
    // badge. Never infer Expense from a sibling sender or an OTP notice.
    final localKind=localInfo?['kind'];
    final noticeKind=sensitive?'otpReview':
     localKind=='excluded'?'excludeSuggestion':
     localKind=='transfer'?'transfer':
     localKind=='income'?'income':
     localKind=='expense'?'expense':
     income is bool?(income?'income':'expense'):'needsReview';
    return WaffraReviewNotice(
     id:id,sender:sender.isEmpty?(waffraIsEnglish?'Unknown sender':'مرسل غير محدد'):sender,
     preview:summary.isEmpty?(waffraIsEnglish?'Bank message':'رسالة بنكية'):summary,
     kind:noticeKind,
     amount:sensitive?null:(amount is num?amount.toDouble():null));
   }).toList(growable:false);
 }

 /// Only owner-confirmed SMS IDs or fully selected sender groups may be
 /// excluded. Persistent anti-replay markers live in native encrypted SMS
 /// policy; neither the Android inbox nor financial ledger is modified.
 Future<bool> _m592ExcludeNotificationSelection(
  List<String> ids,List<String> senderNames)async{
  if(!mounted||!ready||_financeLoadFailure!=null||
     ids.isEmpty||ids.length>1000)return false;
  final selected=ids.toSet();
  if(selected.length!=ids.length||
     selected.any((id)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)))return false;
  final pending=<String,Map<String,Object?>>{
   for(final row in _autoSmsPending)
    if(row['id'] is String)row['id'] as String:row};
  if(!selected.every(pending.containsKey))return false;
  String canon(String s)=>s.trim().toLowerCase();
  final blockKeys=senderNames.map(canon).toSet();
  if(blockKeys.length!=senderNames.length||
    senderNames.any((s)=>s.trim().isEmpty||s.length>100))return false;
  for(final sender in blockKeys){
   final rows=_autoSmsPending.where((row)=>
    canon((row['sender'] as String?)??'')==sender);
   if(rows.isEmpty||rows.any((row)=>!selected.contains(row['id'])))
    return false;
  }
  final bySender=ids.where((id)=>blockKeys.contains(
   canon((pending[id]!['sender'] as String?)??''))).toSet();
  final individual=ids.where((id)=>!bySender.contains(id)).toList();
  final done=<String>{};
  var failed=false;
  try{
   if(senderNames.isNotEmpty){
    if(await WaffraAutoSms.excludeSenders(senderNames)){
     done.addAll(bySender);
    }else{failed=true;}
   }
   if(!failed){
    for(var start=0;start<individual.length;start+=100){
     final batch=individual.skip(start).take(100).toList();
     if(!await WaffraAutoSms.excludeMessages(batch)){
      failed=true;break;
     }
     done.addAll(batch);
    }
   }
   if(mounted&&done.isNotEmpty){
    setState(()=>_autoSmsPending.removeWhere(
     (row)=>done.contains(row['id'])));
   }
   // Store only safe, sender-scoped exclusion keywords in one encrypted
   // write. No OTP digits, account details, entire SMS texts or 1000 writes.
   if(done.isNotEmpty&&_smsRuleOwnerKey.isNotEmpty){
    try{
     final store=const WaffraSmsLocalRuleStore();
     var rules=await store.read(_smsRuleOwnerKey);
     var changed=false,index=0;
     for(final id in individual){
      if(!done.contains(id))continue;
      final row=pending[id],body=row?['body'],sender=row?['sender'];
      if(body is! String||sender is! String)continue;
      if(++index%16==0){
       await Future<void>.delayed(const Duration(milliseconds:1));
      }
      final rule=WaffraSmsLocalRules.suggestedRule(
       body:body,sender:sender,kind:'excluded',confidentOnly:true);
      if(rule==null)continue;
      final next=WaffraSmsLocalRules.upsertLearned(
       existing:rules,candidate:rule);
      if(!identical(next,rules)){changed=true;rules=next;}
     }
     if(changed){
      await store.write(_smsRuleOwnerKey,rules);
      // Reclassify existing pending messages after the confirmed encrypted
      // rule write; never trigger full SMS history import or financial post.
      _receiveAutoSmsNotice();
     }
    }catch(_){
     // A failed optional learning update cannot undo durable exclusion.
    }
   }
  }catch(e){
   failed=true;
   debugPrint('M592 native exclusion rejected: ${e.runtimeType}');
  }
  if(!mounted)return false;
  if(failed||done.length!=selected.length){
   snack(context,waffraIsEnglish?
    'Some selected SMS remain in review.':
    'بعض الرسائل المحددة ما زالت للمراجعة.',isError:true);
   return false;
  }
  snackSuccess(context,waffraIsEnglish?
   'Messages moved to Excluded for 30 days. Restore them there.':
   'الرسائل بقت في قائمة المستبعدة لمدة 30 يوم، وتقدر ترجعها من هناك.');
  return true;
 }
 Future<void> _m549OpenNotifications()async{
  if(!mounted||!ready)return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
   builder:(route)=>WaffraApprovedNotificationsPage(
    english:waffraIsEnglish,readPending:_m549ReviewNotices,
    onReviewAll:_openAutoSmsInbox,
    onBulkExclude:_m592ExcludeNotificationSelection,
    onReviewOne:(id)=>_reviewAutoSmsCandidates(targetId:id),
    onRescan:()=>_rescanAutoSmsInbox(feedbackContext:route),
    // A user refresh always checks the real incremental native cursor;
    // a false rescanNeeded hint must not make the button inert.
    canRescan:()=>!_autoSmsRescanRunning,
   )));
 }
 Future<void> _openAutoSmsInbox()async{
  // The Home snapshot has already passed native owner/consent verification.
  // Re-reading/decrypting/reclassifying all 1000 SMS on every tap blocks
  // navigation for no gain; initial/invalid/empty snapshots still refresh.
  if(!_autoSmsStatusChecked||_autoSmsStatusProblem!=null||
     _autoSmsPending.isEmpty){
   await _refreshAutoSmsInbox();
  }
  if(!mounted||!ready||_autoSmsStatusProblem!=null||
     _autoSmsPending.isEmpty)return;
  // O(N) case-insensitive grouping; preserve each original sender and date.
  final grouped=WaffraSmsReviewGroups.from(_autoSmsPending,
   unknownSender:waffraIsEnglish?'Unknown sender':'مرسل غير محدد');
  final bySender=grouped.bySender;
  final senders=grouped.senders;
  String? selectedSender,openingReviewId;
  final selectedIds=<String>{};
  var bulkBusy=false;
  List<String> idsOf(Iterable<Map<String,Object?>> rows)=>
   rows.map((row)=>row['id']).whereType<String>().toList(growable:false);
  List<String> visibleIds()=>selectedSender==null?
   idsOf(bySender.values.expand((rows)=>rows)):
   idsOf(bySender[selectedSender]??const <Map<String,Object?>>[]);
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(
    builder:(ctx,refresh)=>PopScope(
     // Explicit SMS selection must bypass Back-to-senders guard.
     canPop:selectedSender==null||openingReviewId!=null,
     onPopInvokedWithResult:(didPop,result){
      if(!didPop&&selectedSender!=null&&openingReviewId==null){
       refresh(()=>selectedSender=null);
      }
     },
     child:SafeArea(
     child:SizedBox(height:selectedSender==null?
       min(MediaQuery.sizeOf(ctx).height*.78,550.0):
       MediaQuery.sizeOf(ctx).height*.84,
      child:Column(children:[
       Padding(padding:const EdgeInsets.fromLTRB(14,3,14,8),
        child:Row(children:[
         IconButton(key:const Key('waffra-sms-senders-back'),
          icon:const Icon(Icons.arrow_back_rounded,color:forest),
          onPressed:(){
           if(selectedSender==null){Navigator.pop(ctx);}
           else{refresh(()=>selectedSender=null);}
          }),
         Expanded(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          WaffraText(selectedSender??(waffraIsEnglish?
           'Messages to review':'مراجعة الرسائل البنكية'),maxLines:2,
           style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          WaffraText(visibleIds().length.toString()+
           (waffraIsEnglish?' messages from ':' رسالة من ')+
           senders.length.toString()+
           (waffraIsEnglish?' senders':' مرسلين'),
           style:TextStyle(fontSize:12,
            color:Theme.of(ctx).colorScheme.onSurfaceVariant)),
         ])),
        ])),
       Padding(padding:const EdgeInsets.fromLTRB(12,1,12,6),
        child:WaffraSmsReviewMetrics(
         shown:visibleIds().length,selected:selectedIds.length,
         senderCount:senders.length,english:waffraIsEnglish)),
       Padding(padding:const EdgeInsets.fromLTRB(13,4,13,7),
        child:Container(
         decoration:BoxDecoration(
          color:Theme.of(ctx).brightness==Brightness.dark?
           const Color(0xFF193E31):const Color(0xFFF2F8F4),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          Checkbox(
           key:const Key('waffra-sms-select-all-visible'),
           value:visibleIds().isNotEmpty&&
            visibleIds().every(selectedIds.contains),
           onChanged:bulkBusy?null:(value)=>refresh((){
            if(value==true){selectedIds.addAll(visibleIds());}
            else{selectedIds.removeAll(visibleIds());}
           })),
          Expanded(child:WaffraText(waffraIsEnglish?
           'Select all shown messages':'تحديد كل الرسائل المعروضة',
           style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
          WaffraText(selectedIds.length.toString()+
           (waffraIsEnglish?' selected':' محددة'),
           style:const TextStyle(fontSize:12,color:emerald)),
          const SizedBox(width:12),
         ]),
        )),
       Expanded(child:ListView.builder(
        key:Key(selectedSender==null?'waffra-sms-sender-list':
         'waffra-sms-sender-transactions'),
        itemCount:selectedSender==null?senders.length:
         (bySender[selectedSender]?.length??0),
        itemBuilder:(rowContext,index){
         if(selectedSender==null){
          final sender=senders[index],count=bySender[sender]!.length;
          return Card(
           margin:const EdgeInsets.symmetric(horizontal:13,vertical:5),
           elevation:0,
           shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
            side:BorderSide(color:forest.withValues(alpha:.14))),
           child:ListTile(
            key:Key('waffra-sms-sender-group-'+index.toString()),
            contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
            leading:WaffraSmsSenderBrand(sender:sender),
            title:WaffraText(sender,maxLines:2,
             style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
            subtitle:Directionality(
             textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,
             child:WaffraText(waffraIsEnglish?
              '$count messages awaiting review':
              '\u2068$count\u2069 رسائل بانتظار المراجعة',
              style:const TextStyle(fontSize:12,color:emerald))),
            trailing:Row(mainAxisSize:MainAxisSize.min,children:[
             Checkbox(
              key:Key('waffra-sms-select-sender-'+index.toString()),
              value:idsOf(bySender[sender]!).isNotEmpty&&
               idsOf(bySender[sender]!).every(selectedIds.contains),
              onChanged:bulkBusy?null:(value)=>refresh((){
               final ids=idsOf(bySender[sender]!);
               if(value==true){selectedIds.addAll(ids);}
               else{selectedIds.removeAll(ids);}
              })),
             const Icon(Icons.chevron_left_rounded,color:forest),
            ]),
            onTap:()=>refresh(()=>selectedSender=sender),
           ));
         }
         final item=bySender[selectedSender]![index];
         final id=item['id'],at=item['receivedAt'];
         final date=at is int?DateTime.fromMillisecondsSinceEpoch(at)
          .toLocal().toString().substring(0,16):'';
         // Legacy external guesses remain untrusted; the user reviews SMS text.
         final local=item['local'] is Map?item['local'] as Map:null;
         return ListTile(
          key:Key('waffra-sms-sender-message-'+index.toString()),
          leading:const Icon(Icons.sms_outlined,color:emerald),
          title:WaffraText(local==null?
           (waffraIsEnglish?'Needs review':'عملية تحتاج مراجعة'):
           (waffraIsEnglish?'Local rule • ':'قاعدة محلية • ')+
            (local['kind']=='transfer'?
             (waffraIsEnglish?'Transfer':'تحويل'):
             local['kind']=='excluded'?
             (waffraIsEnglish?'Excluded':'مستبعدة'):
             local['income']==true?
              (waffraIsEnglish?'Income':'دخل'):
              (waffraIsEnglish?'Expense':'مصروف'))),
          // Preserve the real original SMS text in the history review, with
          // sender and date without presenting untrusted suggestions.
          subtitle:WaffraText(
           ((item['body'] as String?)??'')+'\n'+
           (local!=null?"${local['category']} • ":'')+
           (waffraIsEnglish?'Review amount, category and budget':
            'راجع المبلغ والقسم والميزانية')+
           (date.isEmpty?'':' • '+date),maxLines:5),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[
           Checkbox(
            key:Key('waffra-sms-select-message-'+index.toString()),
            value:id is String&&selectedIds.contains(id),
            onChanged:bulkBusy||id is! String?null:(value)=>refresh((){
             if(value==true){selectedIds.add(id);}
             else{selectedIds.remove(id);}
            })),
           const Icon(Icons.chevron_left_rounded),
          ]),
          onTap:bulkBusy||openingReviewId!=null?null:(id is String)?()async{
           // M486: keep the sender inbox underneath review/editor so Back
           // returns one level and preserves the sender's selection.
           refresh(()=>openingReviewId=id);
           try{
            await _reviewAutoSmsCandidates(targetId:id);
           }finally{
            if(ctx.mounted)refresh((){
             openingReviewId=null;
             if(!_autoSmsPending.any((row)=>row['id']==id)){
              for(final group in bySender.values){
               group.removeWhere((row)=>row['id']==id);
              }
              selectedIds.remove(id);
              senders.removeWhere((name)=>bySender[name]?.isEmpty??true);
              if(selectedSender!=null&&!senders.contains(selectedSender)){
               selectedSender=null;
              }
             }
            });
           }
          }:null,
         );
        })),
       if(selectedIds.isNotEmpty)Padding(
        padding:const EdgeInsets.fromLTRB(12,8,12,4),
        child:SizedBox(width:double.infinity,child:FilledButton.icon(
         key:const Key('waffra-sms-bulk-exclude-selected'),
         icon:bulkBusy?
          const SizedBox(width:18,height:18,
           child:CircularProgressIndicator(strokeWidth:2)):
          const Icon(Icons.delete_outline_rounded),
         label:WaffraText(waffraIsEnglish?
          'Exclude ${selectedIds.length} selected':
          'استبعاد ${selectedIds.length} رسالة محددة'),
         onPressed:bulkBusy?null:()async{
          // Explicit queue removal first, followed by a SEPARATE sender opt-in.
          // No Android SMS or financial ledger entries are deleted.
          final ids=selectedIds.toList(growable:false);
          final idSet=ids.toSet();
          // Selection is an explicit owner decision. Do not synchronously
          // parse up to 1000 SMS on the UI isolate before painting the dialog.
          // This removes an O(N) CPU-heavy path from every bulk exclusion tap.
          final confirmed=await showWaffraDialog<bool>(
           context:ctx,builder:(dialog)=>AlertDialog(
            title:WaffraText(waffraIsEnglish?
             'Exclude selected messages?':'استبعاد الرسائل المحددة؟'),
            content:WaffraText(waffraIsEnglish?
             'Remove ${ids.length} items from Waffra review only. '
             'Your phone SMS and saved financial transactions are untouched. '
             'Some messages may describe finances; review your selection.':
             'سيتم استبعاد ${ids.length} رسالة من مراجعة وفرة فقط، '
             'دون حذف رسائل الهاتف أو أي عمليات مالية محفوظة. '
             'قد تتضمن الرسائل معاملات مالية؛ راجع اختيارك.'),
            actions:[
             TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
             FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:WaffraText(waffraIsEnglish?'Exclude':'تأكيد الاستبعاد')),
            ]));
          if(confirmed!=true||!ctx.mounted)return;
          // M479 / #417: no native message acknowledgement occurs until
          // both confirmations are settled. 'Back' preserves selected IDs
          // and returns to this still-open review rather than hiding SMS.
          // One sender decision for the entire selection rather than one
          // confirmation dialog PER SENDER (1000 dialogs were possible).
          final fullySelectedSenders=senders.where((sender){
           final groupIds=idsOf(bySender[sender]??const []);
           return groupIds.isNotEmpty&&groupIds.every(idSet.contains);
          }).toList(growable:false);
          final senderChoice=fullySelectedSenders.isEmpty?'messages':
           await showWaffraDialog<String>(
            context:context,builder:(dialog)=>AlertDialog(
             title:WaffraText(waffraIsEnglish?
              'Exclude these senders too?':'هل تريد استبعاد المرسلين أيضًا؟'),
             content:WaffraText(waffraIsEnglish?
              'Exclude selected messages only, or block the selected senders '
              'from future reviews too? Sender blocking stores names only.':
              'تستبعد الرسائل المحددة فقط، أو تستبعد المرسلين كمان '
              'من المراجعات القادمة؟ عند استبعاد المرسل هنحتفظ باسمه فقط.'),
             actions:[
              TextButton(onPressed:()=>Navigator.pop(dialog,'back'),
               child:WaffraText(waffraIsEnglish?'Back':'العودة')),
              TextButton(onPressed:()=>Navigator.pop(dialog,'messages'),
               child:WaffraText(waffraIsEnglish?'Messages only':'الرسائل فقط')),
              FilledButton(onPressed:()=>Navigator.pop(dialog,'senders'),
               child:WaffraText(waffraIsEnglish?'Block senders':'استبعاد المرسلين')),
             ]));
          if(senderChoice==null||senderChoice=='back'||!ctx.mounted)return;
          final senderBlockChoices=senderChoice=='senders'?
           fullySelectedSenders.toSet():<String>{};
          final blockedIds=<String>{};
          for(final sender in senderBlockChoices){
           blockedIds.addAll(idsOf(bySender[sender]??const []));
          }
          refresh(()=>bulkBusy=true);
          final done=<String>{};
          var failed=false;
          try{
           // One native encrypted commit blocks selected senders and purges
           // their queued and previous individually excluded SMS metadata.
           if(senderBlockChoices.isNotEmpty){
            if(await WaffraAutoSms.excludeSenders(senderBlockChoices.toList())){
             done.addAll(blockedIds);
            }else{failed=true;}
           }
           // Unblocked individual SMS need durable anti-replay IDs. Native
           // policy commits up to 100 IDs per batch and preserves failures.
           final remainingMessageIds=ids.where((id)=>!blockedIds.contains(id))
            .toList(growable:false);
           if(!failed)for(var at=0;at<remainingMessageIds.length;at+=100){
            final batch=remainingMessageIds.skip(at).take(100)
             .toList(growable:false);
            if(!await WaffraAutoSms.excludeMessages(batch)){
             failed=true;break;
            }
            done.addAll(batch);
           }
           if(done.isNotEmpty){
            // Bulk and individual exclusions learn identical safe,
            // owner-encrypted review-only keywords after native success.
            if(_smsRuleOwnerKey.isNotEmpty){
             try{
              final store=const WaffraSmsLocalRuleStore();
              final previous=await store.read(_smsRuleOwnerKey);
              var next=previous;
              for(final row in _autoSmsPending.where(
                  (row)=>done.contains(row['id']))){
               final body=row['body'],sender=row['sender'];
               if(body is! String||sender is! String||
                  blockedIds.contains(row['id']))continue;
               final candidate=WaffraSmsLocalRules.suggestedRule(
                body:body,sender:sender,kind:'excluded',
                confidentOnly:true);
               if(candidate!=null){
                next=WaffraSmsLocalRules.upsertLearned(
                 existing:next,candidate:candidate);
               }
              }
              // Do not retain automatically learned exclusion keywords for
              // sender-blocked messages. Keep explicit user-authored rules.
              final blocked=senderBlockChoices.map(
               WaffraSmsLocalRules.normalized).toSet();
              final clean=next.where((rule)=>!(rule.id.startsWith('smart_')&&
               rule.resolvedKind=='excluded'&&blocked.contains(
                WaffraSmsLocalRules.normalized(rule.sender)))).toList();
              if(clean.length!=next.length)next=clean;
              if(!identical(previous,next)){
               await store.write(_smsRuleOwnerKey,next);
              }
             }catch(_){
              if(mounted)snack(context,waffraIsEnglish?
               'Messages excluded; safe rule learning unavailable.':
               'تم الاستبعاد، لكن تعذر حفظ قاعدة تعلم آمنة.',isError:true);
             }
            }
            if(mounted)setState(()=>
             _autoSmsPending.removeWhere((row)=>done.contains(row['id'])));
            for(final rows in bySender.values){
             rows.removeWhere((row)=>done.contains(row['id']));
            }
            senders.removeWhere((sender)=>bySender[sender]!.isEmpty);
            selectedIds.removeAll(done);
           }
           // On a partial native failure, keep the list mounted so the
           // unprocessed selection is still visible and safely retryable.
           if(!failed&&ctx.mounted)Navigator.pop(ctx);
           if(mounted){
            if(failed)snack(context,waffraIsEnglish?
             'Only ${done.length} messages were excluded. Retry remaining items.':
             'تم استبعاد ${done.length} فقط. أعد محاولة الباقي.',isError:true);
            else snackSuccess(context,waffraIsEnglish?
             'Excluded ${done.length} messages from review.':
             'تم استبعاد ${done.length} رسالة من المراجعة.');
            // Keep the queue and counts synced without silently launching
            // another historical import during the bulk-exclusion animation.
            // The user can continue an incomplete history via Rescan.
            unawaited(_refreshAutoSmsInbox());
           }
          }catch(_){
           if(mounted)snack(context,waffraIsEnglish?
            'Bulk exclusion failed. Unconfirmed messages remain in review.':
            'تعذر الاستبعاد الجماعي. الرسائل غير المؤكدة باقية للمراجعة.',
            isError:true);
          }finally{
           if(ctx.mounted)refresh(()=>bulkBusy=false);
          }
         },
        ))),
       Padding(padding:const EdgeInsets.fromLTRB(13,8,13,14),
        child:Container(padding:const EdgeInsets.all(12),
         decoration:BoxDecoration(color:const Color(0xFFE8F4EB),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          const Icon(Icons.info_outline_rounded,color:forest,size:20),
          const SizedBox(width:9),
          Expanded(child:WaffraText(waffraIsEnglish?
           'Nothing is recorded before your review and confirmation.':
           'لن تُسجَّل أي عملية مالية إلا بعد مراجعتك وتأكيدك.',
           style:const TextStyle(color:forest,fontSize:12),maxLines:3)),
         ]))),
      ]),
     ),
    ),
    ),
   ),
  );
  // The sender inbox route remains beneath the message review.
 }
 // ignore: unused_element
 Widget _autoSmsReviewCard(){
  final count=_autoSmsPending.length;
  final localCount=_autoSmsPending.where((row)=>row['local'] is Map).length;
  final ambiguous=count-localCount;
  final canRescan=!_autoSmsRescanRunning&&
   (_autoSmsStatusProblem!=null||_autoSmsProgress['rescanNeeded']==true);
  return Container(
   key:const Key('waffra-auto-sms-review-card'),
   decoration:BoxDecoration(color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(16),
    border:Border.all(color:forest.withValues(alpha:.16))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    // Match Quick Actions: tap anywhere on the framed title to expand.
    Semantics(
     button:true,expanded:_autoSmsReviewExpanded,
     label:waffraIsEnglish?'Transactions requiring review':
      'عمليات تحتاج مراجعة',
     child:InkWell(
      key:const Key('waffra-auto-sms-review-expand'),
      borderRadius:BorderRadius.circular(16),
      onTap:WaffraHaptics.tap(
       ()=>setState(()=>_autoSmsReviewExpanded=!_autoSmsReviewExpanded)),
      child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
       Icon(_autoSmsReviewExpanded?
        Icons.keyboard_arrow_up_rounded:Icons.keyboard_arrow_down_rounded,
        color:forest),
       const SizedBox(width:8),
       const Icon(Icons.fact_check_outlined,color:emerald),
       const SizedBox(width:8),
       Expanded(child:WaffraText(waffraIsEnglish?
        'Transactions requiring review':'عمليات تحتاج مراجعة',
        style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
       Container(
        key:const Key('waffra-auto-sms-review-count'),
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
        decoration:BoxDecoration(color:const Color(0xFFE4F4EB),
         borderRadius:BorderRadius.circular(24)),
        child:Text(!_autoSmsStatusChecked||_autoSmsStatusProblem!=null?
         '—':count.toString(),
         style:const TextStyle(color:forest,fontWeight:FontWeight.bold))),
      ]))),
    ),
    if(_autoSmsReviewExpanded)Padding(
     key:const Key('waffra-auto-sms-review-expanded-content'),
     padding:const EdgeInsets.fromLTRB(14,0,14,14),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(_autoSmsStatusProblem!=null?_autoSmsStatusProblem!:
       !_autoSmsStatusChecked?
        (waffraIsEnglish?'Checking SMS tracking status...':
         'جارٍ التحقق من حالة الرسائل البنكية...'):
       count==0?
        (!_autoSmsHistoryComplete?
         (waffraIsEnglish?'History scan incomplete. Tap refresh to continue.':
          'فحص الرسائل السابقة غير مكتمل؛ اضغط تحديث للاستكمال.'):
         (waffraIsEnglish?'No bank SMS awaiting review.':
          'ما فيه رسائل بنكية بانتظار المراجعة.')):
        (waffraIsEnglish?
         'Bank SMS since the installation month await approval.':
         'رسائل من بداية شهر تثبيت التطبيق بانتظار مراجعتك وتأكيدك.')),
      if(count>0)...[
       const SizedBox(height:5),
       WaffraText(waffraIsEnglish?
        '$localCount classified locally • ${ambiguous<0?0:ambiguous} need review':
        '$localCount مصنفة محليًا • ${ambiguous<0?0:ambiguous} تحتاج مراجعة',
        style:const TextStyle(color:emerald,fontSize:12,
         fontWeight:FontWeight.w600)),
      ],
      const SizedBox(height:12),
      if(_autoSmsRescanRunning)...[
       Row(children:[
        const SizedBox(width:18,height:18,
         child:CircularProgressIndicator(strokeWidth:2.4)),
        const SizedBox(width:9),
        Expanded(child:WaffraText(waffraIsEnglish?
         'Scanning SMS now…':'جارٍ الآن فحص الرسائل…')),
       ]),
       const SizedBox(height:10),
      ],
      if(_autoSmsLastRescanScanned!=null)...[
       WaffraText(waffraIsEnglish?
        'Last rescan checked: $_autoSmsLastRescanScanned • Awaiting review: ${_autoSmsProgress['pending']}':
        'آخر إعادة فحص: $_autoSmsLastRescanScanned رسالة • بانتظار المراجعة: ${_autoSmsProgress['pending']}',
        style:const TextStyle(fontSize:12,color:emerald)),
       if(_autoSmsLastChecked!=null)
        WaffraText(waffraIsEnglish?
         'Updated: ${dayText(_autoSmsLastChecked!)}':
         'آخر تحديث: ${dayText(_autoSmsLastChecked!)}',
         style:const TextStyle(fontSize:11,color:emerald)),
       if(_autoSmsProgress['complete']==false)
        Padding(padding:const EdgeInsets.only(top:6),child:WaffraText(
         ((_autoSmsProgress['pending'] as num?)?.toInt()??0)>=
           ((_autoSmsProgress['capacity'] as num?)?.toInt()??1000)?
          (waffraIsEnglish?
           'Review pending messages to continue scanning other senders.':
           'قائمة المراجعة ممتلئة. راجع بعض الرسائل عشان نكمل فحص باقي المرسلين.'):
          _autoSmsProgress['initialComplete']!=true?
          (waffraIsEnglish?
           'First history scan is unfinished. Tap Rescan to continue.':
           'الفحص الأول للرسائل السابقة لسه ما اكتملش. اضغط إعادة الفحص للاستكمال.'):
          (waffraIsEnglish?
           'There are more new messages. Tap Rescan to continue.':
           'فيه رسائل جديدة باقي فحصها. اضغط إعادة الفحص للاستكمال.'),
         style:const TextStyle(fontSize:12,color:emerald))),
       const SizedBox(height:8),
      ],
      Row(children:[
       Expanded(child:FilledButton.icon(
        key:const Key('waffra-auto-sms-review-open'),
        onPressed:count==0||_autoSmsStatusProblem!=null?
         null:WaffraHaptics.tap(_openAutoSmsInbox),
        icon:const Icon(Icons.rate_review_outlined,size:18),
        label:WaffraText(waffraIsEnglish?'Review messages':'مراجعة العمليات'))),
       const SizedBox(width:8),
       OutlinedButton.icon(
        key:const Key('waffra-auto-sms-review-refresh'),
        onPressed:canRescan?
         WaffraHaptics.tap(()=>unawaited(_rescanAutoSmsInbox())):null,
        icon:_autoSmsRescanRunning?
         const SizedBox(width:19,height:19,
          child:CircularProgressIndicator(strokeWidth:2)):
         const Icon(Icons.refresh_rounded,size:19),
        label:WaffraText(_autoSmsRescanRunning?
         (waffraIsEnglish?'Scanning…':'جارٍ الفحص'):
         (waffraIsEnglish?'Rescan':'إعادة الفحص'))),
      ]),
     ])),
   ]),
  );
 }
 /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.
 // M703: implementation moved byte-identically to registered Home part.
 /// M593: even with JSON decoded on a worker isolate, creating thousands
 /// of MoneyEntry models synchronously can stall the progress animation.
 /// Convert bounded chunks and yield to the next Flutter event loop frame
 /// without publishing partial/unverified ledger state to Home.
 Future<List<MoneyEntry>> _m593BuildVerifiedEntries(List<dynamic> raw)async{
  final items=<MoneyEntry>[];
  const batchSize=96;
  for(var at=0;at<raw.length;at+=batchSize){
   final end=min(at+batchSize,raw.length);
   for(var i=at;i<end;i++){
    final row=raw[i];
    if(row is! Map)throw const FormatException(
     'Invalid verified financial record');
    items.add(MoneyEntry.fromJson(Map<String,dynamic>.from(row)));
   }
   if(end<raw.length){
    await Future<void>.delayed(Duration.zero);
   }
  }
  return items;
 }
 /// M565: a reviewed bank SMS posts only with a verified account, exact
 /// date and source SAR amount; the original hash is committed atomically.
 Future<void> _m565ConfirmSms({
  required String id,required String body,required String sender,
  required String category,required bool income,
  required double value,required DateTime date,
  required ({List<String?>? ids,int? generation}) selectedAccount})async{
  if(!mounted||_financeLoadFailure!=null)return;
  // Account was explicitly reviewed BEFORE the final Yes, not in a second
  // account dialog after it. The atomic writer rechecks the SQLCipher witness.
  if(selectedAccount.ids?.length!=1||
     selectedAccount.ids!.single==null||
     selectedAccount.generation==null)return;
  final hash=bankSmsHash(body);
  final facts=WaffraBankSmsFactsParser.parse(body);
  final original=WaffraSmsCurrencies.originalAmount(body);
  if(!facts.canAutoPostAsIncomeExpense||
    (facts.kind==WaffraBankOperationKind.income)!=income||
    original==null||original.currency!='SAR'||
    (original.amount-value).abs()>0.00001||
    bankSmsDate(body)==null||bankSmsHasUnverifiedTimestamp(body)){
   if(mounted)snack(context,'راجع المبلغ والتاريخ والعملة من شاشة التعديل.',isError:true);
   return;
  }
  if(smsHashes.contains(hash)){
   final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
   if(ack&&mounted)setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
   return;
  }
  final valid=categories.where((c)=>c.income==income&&c.isSubcategory&&
   c.name==category&&waffraCategoryAvailableForNewEntry(categories,c)).toList();
  if(valid.length!=1){if(mounted)snack(context,'راجع القسم الفرعي أولًا.',isError:true);return;}
  final parsed=BankParser.parse(body);
  final record=MoneyEntry(id:newId(),title:parsed.title,
   category:category,amount:value,income:income,date:date,
   notes:body,sourceType:'sms');
  final budgets=await reviewSmsBudgetLinks([record]);
  if(budgets==null||!mounted)return;
  final reviewed=record.withBudget(budgets.single);
  final chosen=selectedAccount;
  if(!mounted)return;
  try{
   final applied=await _saveProgress.track('m565-confirm-sms',()=>
    _financeAuthority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
     records:[Map<String,Object?>.from(reviewed.toJson())],
     hashes:[hash],userConfirmed:true,allowDuplicateHashes:false,
     selectedAccountIds:chosen.ids,
     expectedAccountGeneration:chosen.generation));
   if(applied.saved!=1){
    if(mounted)snack(context,'العملية محفوظة سابقًا؛ لم يتم تكرارها.');
    return;
   }
   final decoded=await WaffraLargeJsonDecode.parse(applied.current.ledgerRaw??'[]');
   if(decoded is! List)throw StateError('Verified SMS ledger missing');
   final updated=await _m593BuildVerifiedEntries(decoded);
   if(!updated.any((v)=>v.id==reviewed.id))throw StateError('Missing committed SMS');
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(updated);
    smsHashes..clear()..addAll(
     applied.current.finance.getStringList('waffra_sms_hashes_v1')??
     const <String>[]);
    _lastFinanceAuthorityRead=applied.current;
    _lastLedgerSavedRaw=applied.current.ledgerRaw;
    _lastWidgetRevision=applied.current.widgetRevision;
   });
   if(sender.trim().isNotEmpty){
    unawaited(_recordConfirmedSmsAccountAssociation(
     record:reviewed,sender:sender,accountId:chosen.ids!.single));
   }
   try{await _learnManualCategoryPreference(reviewed);}catch(_){}
   if(sender.trim().isNotEmpty){
    try{await _learnSafeSmsRule(body:body,sender:sender,
     kind:income?'income':'expense',category:category);}catch(_){}
   }
   unawaited(_refreshWidget());
   final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
   if(ack&&mounted){
    setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
    snackSuccess(context,'تم تسجيل العملية المؤكدة.');
   }else if(mounted){
    snack(context,'تم الحفظ لكن تأكيد إزالة الرسالة لم يكتمل. لا يوجد خصم مكرر.',isError:true);
   }
  }catch(e){
   debugPrint('M565 verified SMS save rejected: ${e.runtimeType}');
   if(mounted){
    await _refreshFromVerifiedFinance();
    if(mounted)snack(context,'تعذر تأكيد حفظ العملية؛ أعد المراجعة.',isError:true);
   }
  }
 }
 // M615: consistent, responsive detail rows with clear RTL text margins.
 Widget _m615ReviewDetail(String label,String value,IconData symbol)=>
  Padding(padding:const EdgeInsets.symmetric(vertical:6),
   child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(symbol,size:17,color:emerald),
    const SizedBox(width:7),
    Expanded(flex:4,child:WaffraText(label,
     style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
    const SizedBox(width:8),
    Expanded(flex:5,child:WaffraText(value,
     textAlign:TextAlign.start,style:const TextStyle(fontSize:12))),
   ]));

 Future<void> _reviewAutoSmsCandidates({String? targetId})async {
  if(!mounted||!ready||_autoSmsReviewOpen||
     _financeLoadFailure!=null)return;
  _autoSmsReviewOpen=true;
  try{
   // The tapped notification knows its exact native SMS ID: retrieve only
   // that item, not a 1000-row encrypted queue on every tap. Native still
   // verifies owner/session and never posts or acknowledges during lookup.
   final direct=targetId==null?null:await WaffraAutoSms.pendingById(targetId);
   final items=targetId==null?await WaffraAutoSms.pending():
    direct==null?<Map<String,Object?>>[]:<Map<String,Object?>>[direct];
   if(!mounted||items.isEmpty)return;
   Map<String,Object?>? selected;
   for(final item in items){
    final id=item['id'],body=item['body'];
    if(id is! String||body is! String||body.trim().isEmpty)continue;
    if(targetId!=null&&id!=targetId)continue;
    if(smsHashes.contains(bankSmsHash(body))){
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }
     continue;
    }
    selected=item;break;
   }
   if(!mounted||selected==null)return;
   final id=selected['id'],body=selected['body'];
   final sender=selected['sender'] is String?selected['sender'] as String:'';
   if(id is! String||body is! String)return;
   final facts=WaffraBankSmsFactsParser.parse(body);
   final sensitive=selected['sensitiveOtp']==true||
    WaffraBankSmsFactsParser.isVerificationChallenge(body);
   final localMatches=_autoSmsPending.where((row)=>row['id']==id);
   final local=localMatches.isEmpty?null:localMatches.first['local'];
   final localFacts=local is Map?local:null;
   final understood=facts.kind==WaffraBankOperationKind.income||
    facts.kind==WaffraBankOperationKind.expense;
   final originalAmount=WaffraSmsCurrencies.originalAmount(body);
   final originalDate=bankSmsDate(body);
   final parsed=BankParser.parse(body);
   final proposedCategory=localFacts?['category'] is String?
    localFacts!['category'] as String:parsed.category;
   final expectedIncome=facts.kind==WaffraBankOperationKind.income;
   // M669: a bank classifier can suggest a ROOT (e.g. تحويلات) without
   // providing any leaf. The root is shown as MAIN only; a user must pick
   // an actual child. Same-name/legacy hints need exact parent validation.
   final previewHint=waffraResolveSmsReviewCategory(categories,
    income:expectedIncome,proposed:proposedCategory);
   final previewMainName=previewHint.parent?.displayName??
    (waffraIsEnglish?'Choose main category':'يحتاج اختيار القسم الرئيسي');
   // The first account is an independent setup step, NOT a valid-category
   // confirmation. A user must be able to create it before fixing category.
   final hasActiveMoneyAccount=_m467Accounts.any((a)=>!a.archived);
   final previewSuffix=WaffraSmsAccountLearning.suffix4(
    expectedIncome?facts.destinationSuffix:facts.sourceSuffix);
   final previewAccountLabel=previewSuffix==null?
    (waffraIsEnglish?'Account needs confirmation':'الحساب يحتاج تأكيد'):
    (waffraIsEnglish?'Account ••••':'الحساب ••••')+previewSuffix;
   final previewDateTime=originalDate==null?
    (waffraIsEnglish?'Date/time needs review':'التاريخ والوقت يحتاجان مراجعة'):
    originalDate.toIso8601String().replaceFirst('T',' ').substring(0,16);
   // The SMS category can be corrected inline without re-opening a money-account
   // selector. A verified account alone never bypasses mandatory category checks.
   String reviewedCategory=previewHint.leaf?.name??
    (waffraIsEnglish?'Choose subcategory':'يحتاج اختيار القسم الفرعي');
   String reviewedMainName=previewMainName;
   bool reviewCategoryValid=previewHint.leaf!=null&&
    previewHint.parent!=null;
   // M669: an independent conservative BankParser may decline to extract
   // an amount even when verified original SAR facts did extract one.
   // The atomic writer validates original facts, NOT that optional second
   // parser. A present conflicting parsed amount/direction still blocks Yes.
   bool canConfirm=understood&&facts.canAutoPostAsIncomeExpense&&
    originalAmount!=null&&originalAmount.currency=='SAR'&&
    originalDate!=null&&!bankSmsHasUnverifiedTimestamp(body)&&
    (parsed.amount==null||
     (parsed.amount!-originalAmount.amount).abs()<0.00001)&&
    (parsed.amount==null||parsed.income==expectedIncome)&&
    reviewCategoryValid;
   // A type selection in compact review is only a requested correction;
   // it must never ACK or post money until the verified ledger editor saves.
   String? reviewType=sensitive?null:switch(facts.kind){
    WaffraBankOperationKind.income=>'income',
    WaffraBankOperationKind.expense=>'expense',
    WaffraBankOperationKind.transfer=>'transfer',
    _=>null,
   };
   final firstChoice=sensitive?'exclude':
    facts.kind==WaffraBankOperationKind.transfer?'transfer':
    understood?'no':'manual';
   // Verified institution/sub-account selection must occur IN this review
   // before enabling Yes. A second picker after Yes is prohibited.
   ({List<String?>? ids,int? generation})? reviewedAccount;
   String? reviewedAccountName;
   bool choosingAccount=false;
   // M669: a disabled Yes must say WHY and offer the safe editor. The
   // conditions mirror the verified atomic writer; choosing a category or
   // account alone never bypasses currency, source and timestamp checks.
   // M689: verification remains in canConfirm; no verbose blocking panel.
   Future<void> selectReviewCategory(StateSetter redraw,BuildContext dialog)async{
    // M669: the SMS hint is only a suggestion. Choose a real ACTIVE parent
    // and then one of its ACTIVE children; both steps are searchable.
    // No category, bank balance or SMS is modified on cancel/back.
    final mainChoices=categories.where((c)=>
     !c.isSubcategory&&c.income==expectedIncome&&
     c.categoryActive).toList();
    BudgetCategory? chosenMain;
    var query='';
    final chosen=await showWaffraDialog<BudgetCategory>(
     context:dialog,builder:(picker)=>
      StatefulBuilder(builder:(picker,choose){
       final children=chosenMain==null?<BudgetCategory>[]:
        waffraManualCategoryChildren(categories,expectedIncome,chosenMain!.id);
       final mainMatches=mainChoices.where((parent)=>
        waffraSearchAny([parent.name,parent.displayName,
         waffraTr(parent.name)],query)||
        categories.any((child)=>child.isSubcategory&&
         child.parentId==parent.id&&child.income==expectedIncome&&
         waffraCategoryAvailableForNewEntry(categories,child)&&
         waffraSearchAny([child.name,child.displayName,
          waffraTr(child.displayName)],query))).toList();
       final leafMatches=children.where((leaf)=>
        waffraSearchAny([leaf.name,leaf.displayName,
         waffraTr(leaf.displayName)],query)).toList();
       return AlertDialog(
       title:WaffraText(waffraIsEnglish?
        'Choose main and subcategory':'اختيار القسم الرئيسي والفرعي'),
       content:SizedBox(width:360,height:350,child:Column(children:[
        TextField(
         key:ValueKey('m669-review-category-search-${chosenMain?.id??'main'}'),
         onChanged:(value)=>choose(()=>query=value),
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search_rounded),
          hintText:waffraIsEnglish?'Search categories':'ابحث في الأقسام',
          border:const OutlineInputBorder())),
        const SizedBox(height:8),
        Expanded(child:ListView(children:[
         if(chosenMain!=null)ListTile(
          leading:const Icon(Icons.arrow_back_rounded),
          title:WaffraText(chosenMain!.displayName),
          onTap:()=>choose((){
           chosenMain=null;query='';
          })),
         if(chosenMain==null)...[
          for(final parent in mainMatches)ListTile(
           title:WaffraText(parent.displayName),
           trailing:const Icon(Icons.chevron_left_rounded),
           onTap:()=>choose((){
            chosenMain=parent;query='';
           })),
          if(mainMatches.isEmpty)ListTile(
           key:const Key('m669-review-category-no-results'),
           title:WaffraText(waffraIsEnglish?
            'No matching main categories':'لا توجد أقسام رئيسية مطابقة')),
         ]else...[
          for(final leaf in leafMatches)ListTile(
           title:WaffraText(leaf.displayName),
           onTap:()=>Navigator.pop(picker,leaf)),
          if(leafMatches.isEmpty)ListTile(
           key:const Key('m669-review-category-no-results'),
           title:WaffraText(waffraIsEnglish?
            'No matching subcategories':'لا توجد أقسام فرعية مطابقة')),
         ],
        ])),
       ])),
       actions:[TextButton(
        onPressed:()=>Navigator.pop(picker),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
      );
      }));
    if(chosen==null||!mounted||!dialog.mounted)return;
    final parent=categories.where((c)=>!c.isSubcategory&&
      c.id==chosen.parentId&&c.income==expectedIncome&&
      c.categoryActive).toList();
    if(parent.length!=1)return;
    // The persisted finance record still stores category name. Do not
    // falsely enable Yes when two active children share the same name.
    final unambiguous=categories.where((c)=>c.isSubcategory&&
      c.income==expectedIncome&&c.name==chosen.name&&
      waffraCategoryAvailableForNewEntry(categories,c)).length==1;
    redraw((){
     reviewedCategory=chosen.name;
     reviewedMainName=parent.single.displayName;
     reviewCategoryValid=unambiguous;
     canConfirm=understood&&facts.canAutoPostAsIncomeExpense&&
      originalAmount!=null&&originalAmount.currency=='SAR'&&
      originalDate!=null&&!bankSmsHasUnverifiedTimestamp(body)&&
      (parsed.amount==null||
       (parsed.amount!-originalAmount.amount).abs()<0.00001)&&
      (parsed.amount==null||parsed.income==expectedIncome)&&
      reviewCategoryValid;
    });
   }
   Future<void> selectAccountBeforeYes(StateSetter redraw,BuildContext dialog)async{
    // Account setup/selection may happen BEFORE category/date corrections;
    // only Yes authorizes posting and retains the full canConfirm guard.
    if(choosingAccount)return;
    redraw(()=>choosingAccount=true);
    try{
     final bridge=_financeBinding?.accountsBridge;
     if(bridge==null)return;
     final before=await bridge.readVerifiedAccounts();
     if(!mounted||!dialog.mounted)return;
     String? pickedId;
     if(!before.balances.any((a)=>!a.archived)){
      // No account: the one clear action opens account creation directly,
      // without an extra bank-account prompt or a transaction save.
      final knownBank=WaffraSmsAccountLearning.bankGroup(sender);
      final suffix=WaffraSmsAccountLearning.suffix4(
       expectedIncome?facts.destinationSuffix:facts.sourceSuffix);
      final draft=await showWaffraDialog<WaffraNewAccountDraft>(
       context:dialog,builder:(ctx)=>WaffraNewAccountDialog(
        english:waffraIsEnglish,suggestedProviderId:knownBank,
        suggestedSenderName:sender,suggestedLastFour:suffix));
      if(draft==null||!mounted||!dialog.mounted)return;
      if(knownBank!=null&&(draft.kind!='bank'||
         draft.providerId!=knownBank||draft.subtype==null)){
       throw StateError('SMS account must match the verified bank sender');
      }
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      final newId='m632-sms-'+DateTime.now().microsecondsSinceEpoch.toString();
      await api.balances();
      await api.createTypedAccountWithIdentity(
       id:newId,name:draft.name,kind:draft.kind,
       providerId:draft.providerId??'none',
       subtype:draft.subtype??'other',
       openingMinor:draft.openingMinor,
       createdIso:DateTime.now().toUtc().toIso8601String(),
       lastFour:draft.lastFour,
       customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
      pickedId=newId;
     }else{
      // An existing account can be selected even when the transaction's
      // category/date needs editing; the trial is never posted.
      final trial=MoneyEntry(
       id:newId(),title:parsed.title,category:proposedCategory,
       amount:originalAmount?.amount??parsed.amount??0.0,
       income:expectedIncome,date:originalDate??DateTime.now(),
       notes:body,sourceType:'sms');
      final picked=await reviewSmsAccountLinks([trial],smsSender:sender);
      pickedId=picked?.ids?.single;
     }
     if(pickedId==null||!mounted||!dialog.mounted)return;
     // Always read the CURRENT SQLCipher witness after selecting/creating.
     final fresh=await bridge.readVerifiedAccounts();
     final active=fresh.balances.where(
      (a)=>!a.archived&&a.id==pickedId).toList();
     if(active.length!=1)return;
     redraw((){
      reviewedAccount=(ids:<String?>[pickedId],
       generation:fresh.witness.generation);
      reviewedAccountName=active.single.name;
     });
     // Refresh dashboard accounts without reloading the Home ledger and
     // without opening a second account-confirmation dialog.
     unawaited(_m467RefreshHomeAccounts());
    }catch(e){
     debugPrint('M632 pre-Yes account setup: ${e.runtimeType}');
     if(mounted)snack(context,waffraIsEnglish?
      'Could not verify or add this account. Please retry.':
      'تعذر إضافة الحساب أو التحقق منه. حاول مرة أخرى.',isError:true);
    }finally{
     if(dialog.mounted)redraw(()=>choosingAccount=false);
    }
   }
   final reviewScroll=ScrollController();
   var decision=await showWaffraDialog<String>(context:context,
    builder:(dialog)=>StatefulBuilder(builder:(dialog,redraw)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?
      'Review bank message':'مراجعة رسالة بنكية'),
     content:Scrollbar(controller:reviewScroll,thumbVisibility:true,
      thickness:4,radius:const Radius.circular(8),
      child:SingleChildScrollView(controller:reviewScroll,
       child:Padding(
        // End in RTL is the left edge: never let scrollbar cover text.
        padding:const EdgeInsetsDirectional.only(start:6,end:24),
        child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
       // M689: the duplicated bank sender/type preview was removed.
       // Original SMS and review details below stay unchanged.
       // M662: no duplicate type picker above the original SMS. Uncertain
       // SMS keeps explicit user-driven choices BELOW the message.
       // M669: all actual financial SMS review confirmations show the
       // UNCHANGED original message, not just a parser's summary. This
       // shared dialog serves sender inbox, notification tap and per-message
       // review. A genuine OTP/security challenge must remain hidden.
       if(!sensitive)Padding(
        padding:const EdgeInsets.only(top:10),
        child:Card(
         color:Theme.of(dialog).colorScheme.surfaceContainerLow,
         child:ExpansionTile(
         key:const Key('waffra-sms-original-expand'),
         initiallyExpanded:true,
         title:WaffraText(waffraIsEnglish?
          'Read original bank message':'عرض نص الرسالة البنكية الأصلي'),
         children:[Padding(padding:const EdgeInsets.all(14),
          child:KeyedSubtree(
           key:const Key('m669-review-original-sms-text'),
           child:SelectableText(body,textAlign:TextAlign.start)))],
        )))
       else Card(child:Padding(
        padding:const EdgeInsets.all(12),
        child:WaffraText(waffraIsEnglish?
         'Verification SMS content is hidden for your safety.':
         'نص رسالة التحقق مخفي لحمايتك.'))),
       if(!sensitive&&!understood&&
          facts.kind!=WaffraBankOperationKind.transfer)...[
        const SizedBox(height:8),
        for(final kind in const <String>['income','expense','transfer'])
         Padding(padding:const EdgeInsets.only(bottom:6),
          child:OutlinedButton(
           key:Key('m662-unknown-correct-to-'+kind),
           onPressed:()=>Navigator.pop(dialog,'m662-type-'+kind),
           child:WaffraText(switch(kind){
            'income'=>waffraIsEnglish?'Income':'دخل',
            'expense'=>waffraIsEnglish?'Expense':'مصروف',
            _=>waffraIsEnglish?'Transfer':'تحويل',
           }))),
       ],
       if(understood&&!sensitive&&
          reviewType==(expectedIncome?'income':'expense'))...[
        const SizedBox(height:10),
        Card(color:Theme.of(dialog).colorScheme.surfaceContainerLow,
         child:Padding(padding:const EdgeInsets.all(12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Row(children:[
            const Icon(Icons.check_circle_outline_rounded,color:emerald),
            const SizedBox(width:8),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Is this transaction correct?':'هل العملية صحيحة؟',
             style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
           ]),
           const Divider(height:18),
           _m615ReviewDetail(waffraIsEnglish?'Type':'نوع العملية',
            expectedIncome?(waffraIsEnglish?'Income':'دخل'):
             (waffraIsEnglish?'Expense':'مصروف'),Icons.category_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Amount':'المبلغ',
            originalAmount==null?'—':
             '${originalAmount.amount.toStringAsFixed(2)} ${originalAmount.currency}',
            Icons.payments_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Description':'الوصف',
            parsed.title,Icons.edit_note_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Main category':'القسم الرئيسي',
            reviewedMainName,Icons.grid_view_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Subcategory':'القسم الفرعي',
            reviewedCategory,Icons.list_alt_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Sender':'المرسل',
            sender,Icons.account_balance_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Money account':'الحساب المالي',
            (reviewedAccountName??(hasActiveMoneyAccount?
              previewAccountLabel:(waffraIsEnglish?
               'No money account yet':'لم تضف حسابًا ماليًا بعد')))+' • '+
            (reviewedAccount!=null?
             (waffraIsEnglish?'Verified':'تم تأكيد الحساب'):
             (waffraIsEnglish?'Choose before saving':'اختار الحساب قبل الحفظ')),
            Icons.account_balance_wallet_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Original date/time':'تاريخ ووقت العملية',
            previewDateTime,Icons.calendar_month_outlined),
          ]))),
        const SizedBox(height:8),
        OutlinedButton.icon(
         key:const Key('m665-review-pick-category'),
         onPressed:()=>selectReviewCategory(redraw,dialog),
         icon:const Icon(Icons.category_outlined),
         label:WaffraText(reviewCategoryValid?
          (waffraIsEnglish?'Change category':'تغيير القسم الرئيسي والفرعي'):
          (waffraIsEnglish?'Choose category':'اختيار القسم الرئيسي والفرعي')),
        ),
        const SizedBox(height:8),
        OutlinedButton.icon(
         key:const Key('m590-sms-choose-account-before-yes'),
         onPressed:!choosingAccount?
          ()=>selectAccountBeforeYes(redraw,dialog):null,
         icon:choosingAccount?
          const SizedBox(width:17,height:17,
           child:CircularProgressIndicator(strokeWidth:2)):
          const Icon(Icons.account_balance_wallet_outlined),
         label:WaffraText(reviewedAccountName??(!hasActiveMoneyAccount?
          (waffraIsEnglish?'Add account':'إضافة حساب'):
          (waffraIsEnglish?'Choose money account':'اختيار الحساب المالي'))),
        ),
        const SizedBox(height:6),
        Row(children:[
         Expanded(child:FilledButton.icon(
          key:const Key('m565-sms-yes-confirm'),
          onPressed:canConfirm&&reviewedAccount?.ids?.single!=null&&
           reviewedAccount?.generation!=null&&
           !choosingAccount?()=>Navigator.pop(dialog,'yes'):null,
          icon:const Icon(Icons.check_rounded,size:18),
          label:WaffraText(waffraIsEnglish?'Done':'تم',maxLines:1))),
         const SizedBox(width:6),
         Expanded(child:OutlinedButton.icon(
          key:const Key('m565-sms-no-edit'),
          onPressed:()=>Navigator.pop(dialog,'no'),
          icon:const Icon(Icons.edit_outlined,size:18),
          label:WaffraText(waffraIsEnglish?'Edit':'تعديل',maxLines:1))),
         if(!sensitive&&facts.kind!=WaffraBankOperationKind.transfer)...[
          const SizedBox(width:6),
          Expanded(flex:2,child:OutlinedButton.icon(
           key:const Key('m595-review-single-exclude'),
           onPressed:()=>Navigator.pop(dialog,'exclude'),
           icon:const Icon(Icons.block_outlined,size:17),
           label:WaffraText(waffraIsEnglish?'Exclude':'استبعاد الرسالة',
            maxLines:2,textAlign:TextAlign.center))),
         ],
        ]),
       ],
       // A separate Exclude remains for unknown/transfer review only;
       // verified income/expense uses the same approved three-button row.
       const SizedBox(height:12),
       const SizedBox(height:8),
       if(facts.kind==WaffraBankOperationKind.transfer&&!sensitive&&
          reviewType=='transfer')
        Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         FilledButton.icon(
          key:const Key('m587-sms-transfer-yes'),
          onPressed:()=>Navigator.pop(dialog,'transfer'),
          icon:const Icon(Icons.swap_horiz_rounded),
          label:WaffraText(waffraIsEnglish?
           'Confirm transfer details':'تأكيد التحويل')),
         const SizedBox(height:6),
         OutlinedButton(
          key:const Key('m587-sms-transfer-no'),
          onPressed:()=>Navigator.pop(dialog,'transfer-manual'),
          child:WaffraText(waffraIsEnglish?
           'No, add income or expense':'لا، إضافة دخل أو مصروف')),
         const SizedBox(height:4),
         TextButton.icon(
          key:const Key('m587-sms-transfer-exclude'),
          onPressed:()=>Navigator.pop(dialog,'exclude'),
          icon:const Icon(Icons.block_outlined),
          label:WaffraText(waffraIsEnglish?
           'Exclude this message':'استبعاد الرسالة')),
        ])
       else if(sensitive)Card(child:ListTile(
        key:const Key('waffra-sms-understood-action'),
        leading:Icon(sensitive?Icons.shield_outlined:
         facts.kind==WaffraBankOperationKind.transfer?Icons.sync_alt_rounded:
         understood?Icons.account_balance_wallet_outlined:Icons.edit_note_outlined),
        title:WaffraText(sensitive?
         (waffraIsEnglish?'Exclude verification SMS':'استبعاد رسالة التحقق'):
         facts.kind==WaffraBankOperationKind.transfer?
          (waffraIsEnglish?'Review bank transfer':'مراجعة حوالة بنكية'):
         understood?(waffraIsEnglish?'I understand this transaction':'مراجعة العملية'):
         (waffraIsEnglish?'Add a separate manual transaction':'إضافة عملية يدوية')),
        subtitle:WaffraText(sensitive?
         (waffraIsEnglish?'Exclude only this reviewed message':'استبعاد الرسالة دي فقط'):
         (waffraIsEnglish?'Continue with verified transaction review':
          'استكمال المراجعة قبل تسجيل أي مبلغ')),
        onTap:()=>Navigator.pop(dialog,firstChoice),
       )),
      ])))),
     actions:[
      if(facts.kind!=WaffraBankOperationKind.transfer)
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:WaffraText(waffraIsEnglish?'Later':'لاحقًا')),
     ])));
   reviewScroll.dispose();
   if(decision=='no'&&understood&&!sensitive&&
      facts.kind!=WaffraBankOperationKind.transfer&&mounted){
    // For suggested Expense, only Income / Transfer are alternative types.
    final alternatives=expectedIncome?
     const <String>['expense','transfer']:
     const <String>['income','transfer'];
    final corrected=await showWaffraDialog<String>(context:context,
     builder:(pick)=>AlertDialog(
      title:Row(children:[
       Expanded(child:WaffraText(waffraIsEnglish?
        'Choose the correct transaction type':'اختار نوع العملية الصحيح')),
       IconButton(icon:const Icon(Icons.close),
        onPressed:()=>Navigator.pop(pick)),
      ]),
      content:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        for(final kind in alternatives)Padding(
         padding:const EdgeInsets.only(bottom:8),
         child:OutlinedButton.icon(
          key:Key('m618-correct-to-'+kind),
          onPressed:()=>Navigator.pop(pick,kind),
          icon:Icon(kind=='transfer'?Icons.swap_horiz_rounded:
           kind=='income'?Icons.south_west_rounded:Icons.north_east_rounded),
          label:WaffraText(switch(kind){
           'income'=>waffraIsEnglish?'Income':'دخل',
           'expense'=>waffraIsEnglish?'Expense':'مصروف',
           _=>waffraIsEnglish?'Transfer':'تحويل',
          }))),
       ]),
     ));
    if(corrected!=null){reviewType=corrected;decision='correct-type';}
    else decision=null;
   }
   if(decision!=null&&decision.startsWith('m662-type-')){
    reviewType=decision.substring('m662-type-'.length);
    decision='correct-type';
   }
   if(decision=='correct-type'&&mounted&&reviewType!=null){
    if(reviewType=='transfer'){
     // A correction from unknown/income/expense to internal transfer cannot
     // infer ownership of the source or destination from SMS wording.
     // It opens a SEPARATE manual transfer with fresh account confirmation.
     // The original SMS remains pending and can still be excluded/reviewed.
     final approved=await showWaffraDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
       title:WaffraText(waffraIsEnglish?
        'Confirm separate internal transfer':'تأكيد تحويل منفصل بين حساباتي'),
       content:WaffraText(waffraIsEnglish?
        'The message does not prove both accounts are yours. Continue only '
        'to a new manual transfer with two verified accounts. The bank SMS '
        'will stay pending, and nothing is saved by this choice alone.':
        'الرسالة لا تثبت أن الحسابين ملكك. المتابعة هتفتح تحويلًا يدويًا '
        'بحسابين موثّقين، والرسالة الأصلية هتفضل للمراجعة. '
        'الاختيار وحده مش هيسجل أي مبلغ.'),
       actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),
         child:WaffraText(waffraIsEnglish?'Back':'عودة')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
         child:WaffraText(waffraIsEnglish?'Continue':'متابعة')),
       ],
      ));
     if(approved==true&&mounted)await openVerifiedTransfer();
    }else{
     // Preserve source identity for manual correction; posting remains
     // user-confirmed through the existing atomic SQLCipher SMS writer.
     await entrySheet(sms:true,initialSms:body,
      reviewedSender:sender,reviewedIncomeOverride:reviewType=='income');
     if(smsHashes.contains(bankSmsHash(body))){
      final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
      if(ack&&mounted){
       setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
      }
     }
    }
   }else if(decision=='exclude'&&mounted){
    // Never mark user-excluded SMS as a financially committed transaction.
    final acknowledged=await WaffraAutoSms.excludeMessages([id]);
    if(acknowledged&&mounted){
     setState(()=>_autoSmsPending.removeWhere((item)=>item['id']==id));
     // M661: a durable single-message exclusion is NOT a learned pattern.
     // The user sees the distinction instead of a misleading silent success.
     var learned=false;
     try{learned=await _learnSafeSmsRule(
      body:body,sender:sender,kind:'excluded');}catch(_){}
     if(mounted){
      snackSuccess(context,learned?
       (waffraIsEnglish?
        'Message excluded for 30 days; a reusable safe rule was saved.':
        'تم استبعاد الرسالة لمدة 30 يوم، واتحفظت قاعدة آمنة للرسائل المشابهة.'):
       (waffraIsEnglish?
        'Only this message was excluded for 30 days. No reusable rule was learned.':
        'تم استبعاد الرسالة دي فقط لمدة 30 يوم. لم يتم تعلّم قاعدة للرسائل المشابهة.'));
      unawaited(_refreshAutoSmsInbox());
     }
    }else if(mounted){
     snack(context,waffraIsEnglish?
      'Could not exclude the message safely. Try again.':
      'تعذر استبعاد الرسالة بأمان. حاول تاني.',isError:true);
    }
   }else if(decision=='transfer'&&mounted){
    // The transfer editor itself requires two different verified accounts,
    // original principal amount, and an additional owner save confirmation.
    await _reviewSmsAccountTransfer(item:selected,facts:facts);
   }else if(decision=='transfer-manual'&&mounted){
    final kind=await showWaffraDialog<String>(context:context,
     builder:(dialog)=>AlertDialog(
      title:WaffraText(waffraIsEnglish?
       'Choose the type of transaction to add:':
       'اختر نوع العملية التي تريد إضافتها:'),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:WaffraText(waffraIsEnglish?'Back':'العودة')),
       OutlinedButton(onPressed:()=>Navigator.pop(dialog,'expense'),
        child:WaffraText(waffraIsEnglish?'Expense':'مصروف')),
       FilledButton(onPressed:()=>Navigator.pop(dialog,'income'),
        child:WaffraText(waffraIsEnglish?'Income':'دخل')),
      ]));
    if(mounted&&(kind=='income'||kind=='expense')){
     // The chosen entry is a genuinely separate MANUAL operation: show
     // the original transfer SMS for reference, but never ACK or relabel it.
     await entrySheet(manualIncomeOverride:kind=='income',
      reviewedOriginalSms:body);
    }
   }else if(decision=='yes'&&mounted&&canConfirm&&
             reviewedAccount!=null&&originalAmount!=null&&
             originalDate!=null){
    await _m565ConfirmSms(id:id,body:body,sender:sender,
     category:reviewedCategory,income:expectedIncome,
     value:originalAmount.amount,date:originalDate,
     selectedAccount:reviewedAccount!);
   }else if(decision=='no'&&mounted){
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender);
    if(smsHashes.contains(bankSmsHash(body))){
     final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(ack&&mounted){
      setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
     }
    }
   }else if(decision=='manual'&&mounted){
    // Keep the SMS's verified source/hash instead of replacing it with
    // a blank 'manual' record. Uncertain fields remain editable.
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender);
    if(smsHashes.contains(bankSmsHash(body))){
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }else if(mounted){
      // The confirmed finance hash prevents a duplicate debit on retry.
      // A failed Android acknowledgement must retain the review row.
      snack(context,waffraIsEnglish?
       'Saved transaction, but could not remove the SMS from review. Retry safely.':
       'تم حفظ العملية، لكن تعذر إزالة الرسالة من المراجعة. أعد المحاولة بأمان.',
       isError:true);
     }
    }
   }else if(decision=='review'&&mounted){
    // M636: the verified SMS editor remains, while the paste template is retired.
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender);
    if(smsHashes.contains(bankSmsHash(body))){
     // M484 #411: remove from review only after an exact saved SMS hash
     // and the native acknowledgement both succeed.
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }else if(mounted){
      snack(context,waffraIsEnglish?
       'Saved transaction, but message removal failed. Retry safely.':
       'تم حفظ العملية، لكن تعذر إزالة الرسالة من المراجعة. أعد المحاولة.',
       isError:true);
     }
     if(acknowledged&&mounted&&_smsRuleOwnerKey.isNotEmpty){
      // Once a confirmed entry is committed, learn only a specific and
      // verified bank direction; generic/uncertain categories need review.
      try{
       // The user's FINAL saved category wins over pre-review guesses.
       // Only use a record verified back from the encrypted ledger.
       final confirmed=entries.where((entry)=>entry.sourceType=='sms'&&
        entry.notes.isNotEmpty&&
        bankSmsHash(entry.notes)==bankSmsHash(body)).toList();
       final match=confirmed.length==1?confirmed.single:null;
       final expectedIncome=facts.kind==WaffraBankOperationKind.income;
       final specific=match!=null&&
        (facts.kind==WaffraBankOperationKind.income||
         facts.kind==WaffraBankOperationKind.expense)&&
        match.income==expectedIncome&&
        categories.any((c)=>c.name==match.category&&
         c.income==match.income&&c.isSubcategory&&
         waffraCategoryAvailableForNewEntry(categories,c));
       final learned=specific?
        await _learnSafeSmsRule(
         body:body,sender:sender,
         kind:expectedIncome?'income':'expense',
         category:match.category):false;
       // Unsafe keywords? Preserve the saved entry, no forced rule popup.
       if(learned&&mounted){
        snackSuccess(context,waffraIsEnglish?
         'Matching SMS rule saved automatically.':
         'اتحفظت قاعدة الرسائل المطابقة تلقائيًا.');
       }
      }catch(_){
       if(mounted)snack(context,waffraIsEnglish?
        'Could not securely save a rule; your confirmed transaction is unchanged.':
        'تعذر حفظ قاعدة التصنيف بأمان. العملية المالية المؤكدة لم تتغير.',
        isError:true);
      }
     }
    }
   }
  }finally{
   _autoSmsReviewOpen=false;
   // Another Android notice tapped during this review is still waiting.
   if(mounted&&waffraFinanceNoticeTap.value!=null){
    WidgetsBinding.instance.addPostFrameCallback((_){
     if(mounted)_m621OnFinanceNoticeTap();
    });
   }
   // A simple Back/Cancel only inspected an already loaded SMS. Reloading
   // and reclassifying 1000 encrypted messages after every closed dialog
   // caused avoidable jank. Successful exclusion, transfer and
   // finance-save paths already update the live queue or refresh explicitly.
   // An unchanged review never posts, ACKs, or invalidates the snapshot.
  }
 }
 void _receiveSharedSms(){
  if(!mounted||!ready||!widget.postAuthVisible)return;
  final shared=waffraIncomingSms.value;
  if(shared==null||shared.trim().isEmpty)return;
  // M636: never resurrect the removed SMS paste/review screen.
  waffraIncomingSms.value=null;
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(mounted)snack(context,waffraIsEnglish?
    'Bank-message paste was retired. Use manual entry or automatic SMS Review.':
    'أُلغيت إضافة الرسائل باللصق. استخدم الإضافة اليدوية أو مراجعة الرسائل.');
  });
 }
 Future<void> _loadFinanceSafely()async{
  if(!mounted||_m627ClosingSession)return;
  // One Home finance load at a time. Do not concurrently clear the same
  // verified ledger or race a sign-out DB close.
  final activeLoad=_m627HomeLoadCompletion;
  if(activeLoad!=null){
   await activeLoad.future;
   return;
  }
  final completion=Completer<void>();
  _m627HomeLoadCompletion=completion;
  final startupEpoch=++_m630HomeStartupEpoch;
  // Retry invalidates any late completion from a previous account read.
  _m627AccountEpoch++;
  // M614: measure the real verified finance wait separately from login.
  final startupClock=kProfileMode?(Stopwatch()..start()):null;
  setState((){ready=false;_financeLoadFailure=null;});
  _m684InvalidatePeriodRead();
  entries.clear();categories.clear();namedBudgets.clear();goals.clear();recurring.clear();challenges.clear();
  deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();
  recurringPostponed.clear();smsHashes.clear();learnedMerchantCategories.clear();
  try{
   await load();
   if(_m627ClosingSession)return;
   if(mounted)widget.onVerifiedReady?.call();
   if(kProfileMode&&startupClock!=null){
    debugPrint('WAFFRA_FINANCE_PERF source_to_ready_ms='
     '${startupClock.elapsedMilliseconds}');
   }
   // Account balances were verified before ready=true; no second startup read.
   WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(()async{
    if(!await _m663AwaitVisible(startupEpoch)||
       !_m630SmsSessionCurrent(startupEpoch))return;
    if(kProfileMode&&startupClock!=null){
     debugPrint('WAFFRA_FINANCE_PERF first_home_frame_ms='
      '${startupClock.elapsedMilliseconds}');
    }
    // Finance notice dispatch happens with the other optional UI work,
    // never on the first authenticated Home frame.
    // Home first: encrypted SMS scan starts only after initial layout settles.
    unawaited(()async{
     await Future<void>.delayed(const Duration(milliseconds:900));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     // M624: native SMS resume and encrypted inbox scan are sequential,
     // only after the first fully verified Home frame has painted.
     final activeOwner=(await widget.onVerifiedHomeSmsResume?.call())??true;
     if(!activeOwner||!_m630SmsSessionCurrent(startupEpoch))return;
     // Let Home receive interactions and finish its first tab animation
     // before Android starts historical month paging and native AES I/O.
     await Future<void>.delayed(const Duration(milliseconds:1200));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete);
    }());
    }());
   });
  }catch(e){
   debugPrint('Financial startup integrity/recovery gate blocked access: $e');
   if(_m627ClosingSession)return;
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Could not verify your financial data. Nothing was deleted. Retry or restore a trusted backup.':
     'تعذر التحقق من بياناتك. لم يُحذف شيء. حاول مجددًا أو استعد نسخة موثوقة.';
   });
   // A genuine failed-source recovery page is actionable; never leave
   // the previous auth screen stuck forever if vault verification fails.
   if(mounted)widget.onVerifiedReady?.call();
  }finally{
   if(identical(_m627HomeLoadCompletion,completion)){
    _m627HomeLoadCompletion=null;
   }
   if(!completion.isCompleted)completion.complete();
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
 // M621: a notification is a navigation request, NOT permission to write
 // money. Deferred across cold start and biometric/credential verification.
 bool _m621NoticeOpening=false;
 void _m621OnFinanceNoticeTap(){
  if(!mounted||!ready||!widget.postAuthVisible||_financeLoadFailure!=null||
     _m621NoticeOpening||_autoSmsReviewOpen)return;
  final target=waffraFinanceNoticeTap.value;
  if(target==null)return;
  final lifecycle=WidgetsBinding.instance.lifecycleState;
  if(lifecycle!=null&&lifecycle!=AppLifecycleState.resumed)return;
  _m621NoticeOpening=true;
  waffraFinanceNoticeTap.value=null;
  WidgetsBinding.instance.addPostFrameCallback((_)async{
   try{
    if(!mounted||!ready||_financeLoadFailure!=null)return;
    if(target.destination=='review'){
     // The existing targeted review performs an owner-verified pendingById.
     // An excluded/stale/committed SMS cannot be posted twice from a tap.
     await _reviewAutoSmsCandidates(targetId:target.id);
    }else if(target.destination=='saved'){
     // Only records from the CURRENT verified finance ledger can open.
     final matching=entries.where((record)=>
      record.id==target.entryId&&record.sourceType=='sms').toList();
     if(matching.length==1){
      await transactionDetails(matching.single);
     }else if(mounted){
      snack(context,waffraIsEnglish?
       'This saved transaction is not available in the current account.':
       'العملية المحفوظة غير موجودة في الحساب الحالي.');
     }
    }
   }catch(error){
    debugPrint('Finance notification route refused: ${error.runtimeType}');
   }finally{
    _m621NoticeOpening=false;
    if(mounted&&waffraFinanceNoticeTap.value!=null){
     _m621OnFinanceNoticeTap();
    }
   }
  });
 }
 @override void dispose(){if(!_m663FirstInteractiveFrame.isCompleted)_m663FirstInteractiveFrame.complete();_m632SmsNoticeTimer?.cancel();if(identical(WaffraBackNavigation.onHomeBack,_registeredBackHandler))WaffraBackNavigation.onHomeBack=null;_dashboardScrollController.dispose();_categoryScrollController.dispose();_goalsScrollController.dispose();_recurringScrollController.dispose();waffraReturnHome.removeListener(_returnToHome);waffraIncomingSms.removeListener(_receiveSharedSms);waffraAutoSmsUpdates.removeListener(_receiveAutoSmsNotice);waffraFinanceNoticeTap.removeListener(_m621OnFinanceNoticeTap);waffraWidgetAction.removeListener(_receiveWidgetAction);_widgetReloadListener?.dispose();_saveProgress.dispose();final binding=_financeBinding;if(binding!=null)unawaited(_financialWriteQueue.drain().whenComplete(binding.close));super.dispose();}
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
   // Widget resume may follow a biometric/background transition. Decode
   // large verified ledgers off Flutter's UI isolate to preserve tap/animation
   // frames; this is read-only and keeps all finance integrity gates intact.
   final parsed=await WaffraLargeJsonDecode.parse(raw);
   if(parsed is! List)throw const FormatException(
    'Widget finance ledger is not a list.');
   final loaded=await _m593BuildVerifiedEntries(parsed);
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
 // M474: coalesce overlapping user refresh gestures only. Internal verified
 // finance reads/writes still run independently after each committed change.
 Future<void>? _m474PullRefreshInFlight;
 Future<void> _refreshAndSettle(ScrollController controller,int originalTab){
  final pending=_m474PullRefreshInFlight;
  if(pending!=null)return pending;
  late final Future<void> tracked;
  tracked=waffraRefreshAndRestoreScroll(
   refresh:_refreshFromVerifiedFinance,
   controller:controller,
   isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null&&
    tab==originalTab&&(originalTab!=0||!goalsOpened))
   .whenComplete((){
    if(identical(_m474PullRefreshInFlight,tracked)){
     _m474PullRefreshInFlight=null;
    }
   });
  _m474PullRefreshInFlight=tracked;
  return tracked;
 }

 Future<void> _refreshFromVerifiedFinance()async {
  if(!mounted||!ready)return;
  try {
   await _financialWriteQueue.drain();
   await _ensureFinanceBound();
   final current=await _financeAuthority.load(
    route:WaffraFinanceRoute.dashboardRead);
   final view=current.finance;
   view.requireIntegrity();
   // A same-generation/same-digest SQLCipher read is verified but unchanged.
   // Re-decoding the entire ledger and rebuilding every page on every swipe
   // caused avoidable UI lag. Do not apply this shortcut to guarded legacy.
   final previous=_lastFinanceAuthorityRead;
   final encryptedCurrent=current.encryptedWitness?.snapshot;
   final encryptedPrevious=previous?.encryptedWitness?.snapshot;
   if(current.source==WaffraRuntimeFinanceBackend.verifiedEncrypted&&
      previous?.source==current.source&&
      encryptedCurrent!=null&&encryptedPrevious!=null&&
      encryptedCurrent.generation==encryptedPrevious.generation&&
      encryptedCurrent.digest==encryptedPrevious.digest&&
      current.widgetRevision==previous?.widgetRevision){
    return;
   }
   // Legacy first installs may omit their empty ledger or category catalog.
   // Activated SQLCipher still fails closed if either required source is absent.
   final refreshSource=WaffraVerifiedPullRefreshSource.fromAuthority(current);
   final ledger=refreshSource.ledgerRaw;
   final catalog=refreshSource.categoriesRaw;
   Future<List<T>> readList<T>(String? raw,T Function(Map<String,dynamic>) make) async {
    if(raw==null)return <T>[];
    final parsed=await WaffraLargeJsonDecode.parse(raw);
    if(parsed is! List)throw const FormatException('Invalid finance list.');
    return parsed.map((e)=>make(Map<String,dynamic>.from(e as Map))).toList();
   }
   // This verified refresh source always exposes its normalized ledger.
   // Preserve fail-closed parsing and asynchronous bounded entry mapping.
   final nextEntries=await _m593BuildVerifiedEntries(
    (await WaffraLargeJsonDecode.parse(ledger)) as List);
   final nextCategories=catalog==null
    ?defaultCategories()
    :await readList<BudgetCategory>(catalog,BudgetCategory.fromJson);
   if(current.source==WaffraRuntimeFinanceBackend.guardedLegacy){
    if(nextCategories.isEmpty)nextCategories.addAll(defaultCategories());
    for(final entry in nextEntries){
     if(!nextCategories.any((c)=>c.name==entry.category&&c.income==entry.income)){
      nextCategories.add(BudgetCategory(id:newId(),name:entry.category,
       icon:'category',color:colors[7],income:entry.income));
     }
    }
   }
   final nextNamedBudgets=await readList<WaffraNamedBudget>(
    view.getString('waffra_named_budgets_v1'),WaffraNamedBudget.fromJson);
   for(final c in nextCategories.where((c)=>!c.income&&c.budget>0)){
    if(!nextNamedBudgets.any((b)=>b.id==c.id)){
     nextNamedBudgets.add(WaffraNamedBudget.fromLegacy(c));
    }
   }
   // Legacy category caps remain in the source UNTIL a single verified
   // finance batch commits BOTH new budget rows and cleared category caps.
   // Never clear category caps during a catalog upgrade or read-only refresh.
   final nextGoals=await readList<SavingGoal>(
    view.getString('waffra_goals_v24'),SavingGoal.fromJson);
   final nextRecurring=await readList<RecurringBill>(
    view.getString('waffra_recurring_v24'),RecurringBill.fromJson);
   final nextChallenges=await readList<SavingChallenge>(
    view.getString('waffra_challenges_v1'),SavingChallenge.fromJson);
   Future<List<Map<String,dynamic>>> readTrash(String key)=>readList<Map<String,dynamic>>(
    view.getString(key),(row)=>row);
   final nextCategoryTrash=await readTrash('waffra_deleted_categories_v1');
   final nextGoalTrash=await readTrash('waffra_deleted_goals_v1');
   final nextRecurringTrash=await readTrash('waffra_deleted_recurring_v1');
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
    namedBudgets..clear()..addAll(nextNamedBudgets);
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
   // The verified pull read already includes the full authoritative ledger.
   // Reusing it prevents a second SQLCipher decrypt for the Home widget.
   unawaited(_publishVerifiedWidgetBalance(current));
   unawaited(_m467RefreshHomeAccounts());
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
  final financeClock=kProfileMode?(Stopwatch()..start()):null;
  final startupEpoch=_m630HomeStartupEpoch;
  void traceHomeStep(String stage){
   if(financeClock==null)return;
   debugPrint('WAFFRA_HOME_LOAD_STEP $stage elapsed_ms='
    '${financeClock.elapsedMilliseconds}');
  }
  // M629: on cold Home, start the independent cheap preference read while
  // binding the verified SQLCipher source. Both must finish BEFORE Home can
  // consume user-specific settings or display any financial balance.
  traceHomeStep('before_sharedPreferences');
  final preferencesLoading=SharedPreferences.getInstance();
  traceHomeStep('before_ensureFinanceBound');
  await _ensureFinanceBound();
  traceHomeStep('after_ensureFinanceBound');
  final bindMs=financeClock?.elapsedMilliseconds;
  final p=await preferencesLoading;
  traceHomeStep('after_sharedPreferences');
  // An authenticated fresh SQLCipher vault is born with an empty snapshot.
  // Add only absent first-run ledger and category fields via the existing
  // atomic SQLCipher writer before displaying Home; never use legacy fallback.
  traceHomeStep('before_catalog_recovery');
  final loadedFinance=await WaffraFreshHomeCatalogRecovery.load(
   authority:_financeAuthority,
   defaultCategoriesJson:await WaffraPublicStartupPrewarm.categoriesJson(),
  );
  traceHomeStep('after_catalog_recovery');
  final verifiedSourceMs=financeClock?.elapsedMilliseconds;
  _lastFinanceAuthorityRead=loadedFinance;
  final financeView=loadedFinance.finance;
  financeView.requireIntegrity();
  final verifiedEncryptedStartup=
   loadedFinance.source==WaffraRuntimeFinanceBackend.verifiedEncrypted;
  if(verifiedEncryptedStartup&&
     financeView.getString('waffra_categories_v24')==null){
   throw StateError('Verified encrypted category source is incomplete.');
  }
  // M622: verified accounts can read while immutable source JSON decodes.
  // Legacy category migration must finish before its account projection.
  traceHomeStep('before_accounts_refresh');
  final Future<void>? accountsLoading=verifiedEncryptedStartup?
   _m467RefreshHomeAccounts():null;
  traceHomeStep('after_accounts_refresh_started');
  _lastWidgetRevision=loadedFinance.widgetRevision;
  _lastLedgerSavedRaw=loadedFinance.ledgerRaw;
  // M633: one batch-decode for immutable, integrity-verified finance JSON.
  // The verified accounts projection started above runs concurrently.
  traceHomeStep('before_batch_json_decode');
  final startupSources=<String,String>{};
  for(final field in <String>[
   'entries',
   'waffra_categories_v24',
   'waffra_named_budgets_v1',
   'waffra_goals_v24',
   'waffra_recurring_v24',
   'waffra_challenges_v1',
   'waffra_deleted_categories_v1',
   'waffra_deleted_goals_v1',
   'waffra_deleted_recurring_v1',
   'waffra_recurring_postponed_v1',
   'waffra_learned_merchants_v1',
  ]){
   final raw=financeView.getString(field);
   if(raw!=null)startupSources[field]=raw;
  }
  final decodedStartup=await WaffraLargeJsonDecode.parseStartupFields(
   startupSources);
  traceHomeStep('after_batch_json_decode');
  _m684InvalidatePeriodRead();
  try{final raw=financeView.getString('entries');if(raw!=null)entries.addAll(await _m593BuildVerifiedEntries((decodedStartup.read('entries')) as List));}catch(e){throw StateError('Saved transactions cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(decodedStartup.read('waffra_categories_v24') as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved categories cannot be decoded safely: $e');}
  try{
   final raw=financeView.getString('waffra_named_budgets_v1');
   if(raw!=null)namedBudgets.addAll((decodedStartup.read('waffra_named_budgets_v1') as List).map(
    (x)=>WaffraNamedBudget.fromJson(Map<String,dynamic>.from(x))));
   for(final c in categories.where((c)=>!c.income&&c.budget>0)){
    if(!namedBudgets.any((b)=>b.id==c.id)){
     namedBudgets.add(WaffraNamedBudget.fromLegacy(c));
    }
   }
  }catch(e){throw StateError('Saved independent budgets are invalid: $e');}
  try{final raw=financeView.getString('waffra_goals_v24');if(raw!=null)goals.addAll((decodedStartup.read('waffra_goals_v24') as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((decodedStartup.read('waffra_recurring_v24') as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved recurring finance cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_challenges_v1');if(raw!=null)challenges.addAll((decodedStartup.read('waffra_challenges_v1') as List).map((e)=>SavingChallenge.fromJson(Map<String,dynamic>.from(e))));}catch(e){throw StateError('Saved challenges cannot be decoded safely: $e');}
  try{
   final raw=financeView.getString('waffra_deleted_categories_v1');
   if(raw!=null)deletedCategories.addAll((decodedStartup.read('waffra_deleted_categories_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));
  }catch(e){throw StateError('Deleted categories cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_goals_v1');if(raw!=null)deletedGoals.addAll((decodedStartup.read('waffra_deleted_goals_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_recurring_v1');if(raw!=null)deletedRecurring.addAll((decodedStartup.read('waffra_deleted_recurring_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted recurring cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_postponed_v1');if(raw!=null)recurringPostponed.addAll((decodedStartup.read('waffra_recurring_postponed_v1') as Map).map((k,v)=>MapEntry(k.toString(),v.toString())));}catch(e){throw StateError('Recurring postponements cannot be decoded safely: $e');}
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
    // Catalog v5 installs only new leaves, preserving user budgets and trash.
  if(!verifiedEncryptedStartup&&
     !(p.getBool('waffra_category_catalog_v5_installed')??false)){
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
    version:5,
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
    final data=decodedStartup.read('waffra_learned_merchants_v1');
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
  // Category display no longer shows caps. Keep the original category rows
  // intact until the user-confirmed atomic migration commits BOTH collections.
  if(!mounted)return;
  if(kProfileMode&&financeClock!=null){
   // Timings only. Never log private finance content or account identity.
   debugPrint('WAFFRA_FINANCE_PERF bind_ms=${bindMs??-1} '
    'verified_catalog_ms=${verifiedSourceMs??-1} '
    'decoded_ready_ms=${financeClock.elapsedMilliseconds}');
  }
   // Previously Home painted transaction sums and only afterwards loaded
   // verified bank account balances. Never flash a provisional amount.
   traceHomeStep('before_accounts_await');
   try{
    await (accountsLoading??_m467RefreshHomeAccounts())
     .timeout(const Duration(seconds:15));
   }on TimeoutException{
    traceHomeStep('accounts_timeout');
    // timeout() does not cancel the underlying SQL task: reject late state.
    _m627AccountEpoch++;
    _m468AccountReadInFlight=null;
    _m468AccountReadAgain=false;
    rethrow;
   }
   traceHomeStep('after_accounts_await');
   if(!mounted||_m627ClosingSession)return;
   if(!_m468VerifiedAccountsLoaded){
    throw StateError('Verified financial account balances are unavailable.');
   }
   setState(()=>ready=true);
   // M486 #419: let Home's first interactive frame paint before competing
   // asynchronous widget reads and incoming SMS callbacks begin.
   WidgetsBinding.instance.addPostFrameCallback((_){
    unawaited(()async{
     // First-install preload is intentionally hidden during consent+biometric.
     if(!await _m663AwaitVisible(startupEpoch)||
        !_m630SmsSessionCurrent(startupEpoch))return;
     // Load returns before the retained biometric/login stage is dismissed.
     // Let its FIRST genuinely verified Home frame render before optional I/O.
     await Future<void>.delayed(const Duration(milliseconds:400));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     // M630: these happen after the verified Home frame, not during paint.
     _m621OnFinanceNoticeTap();
     _receiveSharedSms();
     _receiveWidgetAction();
     // Track ALL optional finance operations so signout cannot close the
     // verified SQLCipher source beneath an in-flight widget/recurring read.
     // They remain after Home render, and never post SMS automatically.
     final postFrameFinance=()async{
      try{
       await _refreshWidget();
       if(!_m630SmsSessionCurrent(startupEpoch))return;
       if(!verifiedEncryptedStartup)await applyRecurring();
       if(!_m630SmsSessionCurrent(startupEpoch))return;
       if(recurringRemindersEnabled)await syncRecurringReminders();
      }catch(error){
       debugPrint('Post-frame optional finance: ${error.runtimeType}');
      }
     }();
     _m630PostFrameFinanceWork=postFrameFinance;
     unawaited(()async{
      await postFrameFinance;
      if(identical(_m630PostFrameFinanceWork,postFrameFinance)){
       _m630PostFrameFinanceWork=null;
      }
     }());
    }());
   });
  // An explicit Google onboarding notification consent may be pending;
  // enable reminder scheduling only through the verified finance authority.
  // No reminder OS permission at startup; wait for explicit recurring toggle.
  if(!verifiedEncryptedStartup&&trashBefore!=deletedCategories.length){
   await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  }
 }
 Future<void> _refreshWidget()async{
  if(!Platform.isAndroid)return;
  try{
   await _ensureFinanceBound();
   final verified=await _financeAuthority.load(
    route:WaffraFinanceRoute.widgetBalanceRefresh);
   await _publishVerifiedWidgetBalance(verified);
  }catch(e){
   debugPrint('Widget source unavailable: ${e.runtimeType}');
   await refreshWaffraHomeWidget(
    balance:'***',negative:false,hidden:true,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }
 }
 Future<void> _publishVerifiedWidgetBalance(
  WaffraFinanceAuthorityRead verified)async{
  if(!Platform.isAndroid)return;
  try{
   verified.finance.requireIntegrity();
   final raw=verified.ledgerRaw;
   if(raw==null)throw StateError('Verified widget ledger is missing.');
   // After authority validation, sum large ledgers on a worker isolate.
   final net=raw.length>=WaffraLargeJsonDecode.isolateThreshold
    ?await compute(WaffraAuthoritativeWidgetBalance.netHalalas,raw)
    :WaffraAuthoritativeWidgetBalance.netHalalas(raw);
   await refreshWaffraHomeWidget(
    balance:hideWaffraAmounts.value?'***':WaffraDisplayCurrency.amount(net/100),
    negative:net<0,
    hidden:hideWaffraAmounts.value,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }catch(e){
   debugPrint('Verified widget balance refresh unavailable: ${e.runtimeType}');
   await refreshWaffraHomeWidget(
    balance:'***',negative:false,hidden:true,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }
 }
 Future<void> persist({
  WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit,
  bool userConfirmed = false,
  String? selectedAccountId,
 }) {
  // Freeze a snapshot BEFORE any await. Previously Future.wait launched
  // overlapping multi-key saves, so a slower old save could finish last.
  // This protects in-app ordering, not cross-process widget writes or a crash
  // in the middle of SharedPreferences' non-atomic multi-key update.
  // Snapshot immutable final-field MoneyEntry references before ANY await.
  // The expensive per-entry toJson conversion now runs after the spinner
  // frame and off the UI isolate for large ledgers, without moving the
  // source snapshot capture past another pending write.
  final frozenEntries=List<MoneyEntry>.unmodifiable(entries);
  final snapshot=<String,Object>{
   'entries':'', // replaced by the exact frozen payload under the save overlay
   // Migrate old category caps together with the independent budget list.
   // Historic ledger budget IDs are kept unchanged.
   'waffra_categories_v24':jsonEncode(categories.map((c)=>
    route==WaffraFinanceRoute.challengeAndBudgetUpdate&&
    c.budget>0&&namedBudgets.any((b)=>b.id==c.id)?
     c.copy(budget:0,clearBudget:true).toJson():c.toJson()).toList()),
   'waffra_named_budgets_v1':jsonEncode(
    namedBudgets.map((b)=>b.toJson()).toList()),
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
  // Fresh verified SQLCipher vaults intentionally omit optional empty modules.
  // A manual append may change ONLY the ledger; the authoritative writer
  // still checks its exact witness and the one-entry append invariant.
  final previousWrite=_m468PersistSequence;
  final saving=_saveProgress.track<void>(
   'persist-financial-change',() async {
   // The frozen capture cannot overtake an earlier confirmed finance write.
   await previousWrite;
   // The overlay is on screen; move large JSON serialization off the UI
   // isolate without changing a single byte or the source witness.
   snapshot['entries']=frozenEntries.length>=
     WaffraLargeJsonDecode.encodeRowThreshold
      ?await compute(MoneyEntry.encodeFrozenSnapshot,frozenEntries)
      :await WaffraLargeJsonDecode.encodeRecords(
       frozenEntries.map((e)=>e.toJson()).toList(growable:false));
   WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
    route:route,source:baseline?.source,snapshot:snapshot);
   WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
    route:route,source:baseline?.source,snapshot:snapshot,
    witnessedValues:baseline?.encryptedWitness?.snapshot.values);
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
    selectedAccountId:selectedAccountId,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }).then((_){unawaited(_refreshWidget());});
  });
  _m468PersistSequence=saving.then<void>(
   (_){},onError:(Object error,StackTrace stack){});
  return saving;
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
   if(mounted)await _refreshFromVerifiedFinance();
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
    recurring.where((r)=>r.active&&waffraCategoryNameAvailableForPosting(
     categories,r.income,r.category)&&(r.linkedGoalId==null||
      goals.any((g)=>g.id==r.linkedGoalId&&g.dueDate!=null)))
     .map((r)=>WaffraReminder(id:r.id,title:r.title,day:r.day,
      startAt:r.startAt,
      oneTimeDueAt:r.linkedGoalId==null?null:r.startAt)).toList(),
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
   if(!r.active||!waffraCategoryNameAvailableForPosting(
    categories,r.income,r.category))continue;
   // A goal is a one-time obligation. Its immutable original due month
   // remains the same even when the user returns to the app much later.
   final isGoalDue=r.linkedGoalId!=null;
   final linkedGoals=isGoalDue?
    goals.where((g)=>g.id==r.linkedGoalId&&g.dueDate!=null).toList():
    <SavingGoal>[];
   if(isGoalDue&&linkedGoals.length!=1)continue;
   final linkedAccount=r.accountId==null
    ?const <WaffraAccountBalance>[]
    :_m467Accounts.where((a)=>a.id==r.accountId&&!a.archived).toList();
   final accountLabel=linkedAccount.length==1?
    linkedAccount.single.name:(r.accountId==null?null:
     (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'));
   final due=isGoalDue?
    DateTime(r.startAt.year,r.startAt.month,r.startAt.day):
    WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
   final goalPreview=isGoalDue?WaffraGoalDueAllocation.allocate(
    dueAmount:r.amount,goalSaved:linkedGoals.single.saved):null;
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
       WaffraText(isGoalDue?
        (waffraIsEnglish?'Savings goal payment due':'استحقاق هدف ادخار'):
        (waffraIsEnglish?'Recurring payment due':'عملية متكررة مستحقة'),
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
       if(accountLabel!=null)...[
        const SizedBox(height:8),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
         const Icon(Icons.account_balance_wallet_outlined,size:16,color:emerald),
         const SizedBox(width:6),
         Flexible(child:WaffraText(
          (waffraIsEnglish?'Linked account: ':'الحساب المرتبط: ')+accountLabel,
          maxLines:2,textAlign:TextAlign.center)),
        ]),
       ],
       const SizedBox(height:15),
       if(goalPreview!=null)...[
        const SizedBox(height:8),
        WaffraText(waffraIsEnglish?
         'Goal wallet: ${cash(goalPreview.fromGoalWallet)} • '
         'Spendable cash: ${cash(goalPreview.fromCurrentBalance)}':
         'من محفظة الهدف: ${cash(goalPreview.fromGoalWallet)} • '
         'من الرصيد الحالي: ${cash(goalPreview.fromCurrentBalance)}',
         textAlign:TextAlign.center,
         style:const TextStyle(fontSize:12,color:emerald)),
        const SizedBox(height:8),
       ],
       WaffraText(isGoalDue?
        (waffraIsEnglish?
         'Record this goal payment once, or postpone it?':
         'هل تم دفع استحقاق الهدف؟ أكّد الخصم مرة واحدة أو أجّل الموعد.'):
        (waffraIsEnglish?
         'Have you paid, or would you like to postpone?':
         'هل تم الدفع، أم ترغب في تأجيل الاستحقاق؟'),
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
     if(isGoalDue){
      if(_lastFinanceAuthorityRead?.source==
        WaffraRuntimeFinanceBackend.verifiedEncrypted){
       final cashMinor=WaffraRecurringPolicy.toHalalas(r.amount)-
        goalPreview!.fromGoalMinor;
       final activeAccounts=await _m641VerifiedGoalRecurringAccounts();
       if(activeAccounts==null||!mounted)return;
       final defaultId=r.accountId;
       if(defaultId!=null&&
          !activeAccounts.any((a)=>a.id==defaultId&&!a.archived)){
        snack(context,waffraIsEnglish?
         'The goal account is unavailable. Edit the goal before paying.':
         'الحساب المرتبط بالهدف غير متاح. عدّل حساب الهدف قبل تسجيل الدفع.',
         isError:true);
        return;
       }
       // The linked goal account is the default; don't require another
       // picker or debit saved funds twice. Old unlinked goals still ask.
       final chosen=cashMinor>0&&defaultId==null?
        await reviewSmsAccountLinks([
         MoneyEntry(id:id,title:r.title,category:r.category,
          amount:r.amount,income:false,date:DateTime.now(),
          sourceType:'goal_due',goalWalletPaidMinor:goalPreview.fromGoalMinor)]):null;
       if(cashMinor>0&&defaultId==null&&chosen==null)return;
       final chosenId=defaultId??chosen?.ids?.single;
       if(cashMinor>0&&chosenId==null)return;
       if(chosen!=null&&chosenId!=null&&chosen.generation!=
          _lastFinanceAuthorityRead?.encryptedWitness?.generation){
        if(mounted)await _loadFinanceSafely();
        if(mounted)snack(context,waffraIsEnglish?
         'Account changed; review the goal due again.':
         'الحساب اتغير؛ راجع استحقاق الهدف مرة تانية.');
        return;
       }
       try{
        await _financialWriteQueue.drain();
        final baseline=_lastFinanceAuthorityRead;
        if(baseline==null||baseline.encryptedWitness==null){
         throw StateError('Verified goal due witness unavailable.');
        }
        await _saveProgress.track('settle-verified-goal-due',()=>
         _financeAuthority.settleLinkedGoalDue(
          baseline:baseline,goalId:r.linkedGoalId!,recurringId:r.id,
          dueKey:id,amountMinor:WaffraRecurringPolicy.toHalalas(r.amount),
          confirmedAtIso:DateTime.now().toIso8601String(),
          userConfirmed:true,selectedAccountId:chosenId));
        if(mounted)await _loadFinanceSafely();
        if(mounted)await syncRecurringReminders();
       }catch(error){
        debugPrint('Goal due SQLCipher commit rejected: $error');
        if(mounted)await _loadFinanceSafely();
        if(mounted)snack(context,waffraIsEnglish?
         'Goal payment was not verified. Reload before retrying.':
         'لم يتم تأكيد استحقاق الهدف؛ أعد تحميل البيانات قبل المحاولة.');
       }
       return;
      }
      // The same deterministic recurring ID cannot settle a goal twice.
      if(entries.any((e)=>e.id==id))continue;
      final currentGoal=goals.where((g)=>g.id==r.linkedGoalId).toList();
      final currentSchedule=recurring.where((x)=>x.id==r.id&&x.active).toList();
      if(currentGoal.length!=1||currentSchedule.length!=1){
       snack(context,waffraIsEnglish?
        'Goal or due date changed; refresh before paying.':
        'الهدف أو موعده اتغير؛ حدّث البيانات قبل تسجيل الدفع.');
       return;
      }
      final allocation=WaffraGoalDueAllocation.allocate(
       dueAmount:r.amount,goalSaved:currentGoal.single.saved);
      if(allocation.fromGoalMinor!=goalPreview!.fromGoalMinor||
        currentSchedule.single.startAt!=r.startAt){
       snack(context,waffraIsEnglish?
        'Wallet allocation changed. Reopen and confirm the new split.':
        'توزيع الدفع اتغير؛ افتح الاستحقاق وراجع المبالغ قبل التأكيد.');
       return;
      }
      // A confirmed goal settlement changes ledger, goal and schedule in
      // the guarded legacy batch. Encrypted mode is refused above until a
      // separately audited atomic SQLCipher writer supports this exact delta.
      setState((){
       final goalIndex=goals.indexWhere((g)=>g.id==r.linkedGoalId);
       final scheduleIndex=recurring.indexWhere((x)=>x.id==r.id);
       goals[goalIndex]=currentGoal.single.copy(
        saved:allocation.remainingGoalSavings);
       recurring[scheduleIndex]=currentSchedule.single.copy(active:false);
       recurringPostponed.remove(id);
       _m684InvalidatePeriodRead();
       entries.insert(0,MoneyEntry(
        id:id,title:r.title,category:r.category,
        amount:allocation.amount,income:false,date:DateTime.now(),
        sourceType:'goal_due',goalWalletPaidMinor:allocation.fromGoalMinor,
        notes:waffraIsEnglish?
         'From goal wallet: ${cash(allocation.fromGoalWallet)}; '
         'from current balance: ${cash(allocation.fromCurrentBalance)}':
         'من محفظة الهدف: ${cash(allocation.fromGoalWallet)}؛ '
         'من الرصيد الحالي: ${cash(allocation.fromCurrentBalance)}'));
      });
      try{
       // The guarded source checks the loaded finance witness; a failed
       // multi-module save is reloaded rather than assuming success.
       await persist(route:WaffraFinanceRoute.transactionEdit,
        userConfirmed:true);
       if(mounted)await syncRecurringReminders();
      }catch(error){
       debugPrint('Goal due settlement could not be confirmed: $error');
       if(mounted)await _loadFinanceSafely();
       if(mounted)snack(context,waffraIsEnglish?
        'Goal payment not confirmed. Records refreshed safely.':
        'لم يتم تأكيد خصم استحقاق الهدف؛ أعدنا تحميل البيانات بأمان.');
       return;
      }
     }else{
      // Select the destination/source money account BEFORE changing the
      // in-memory ledger. A cancellation does not post or clear postponement.
      final chosen=await reviewSmsAccountLinks([MoneyEntry(
       id:id,title:r.title,category:r.category,amount:r.amount,
       income:r.income,date:DateTime.now(),sourceType:'recurring')],
       recurringId:r.id);
      if(chosen==null)return;
      if(!entries.any((e)=>e.id==id)){
       _m684InvalidatePeriodRead();
       setState(()=>entries.insert(0,MoneyEntry(
        id:id,title:r.title,category:r.category,amount:r.amount,
        income:r.income,date:DateTime.now(),sourceType:'recurring')));
      }
      recurringPostponed.remove(id);
      // SQLCipher commits the posted due, cleared postponement, and account
      // link atomically; guarded legacy preserves its existing safe writer.
      try{
       await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,
        userConfirmed:true,selectedAccountId:chosen.ids?.single);
      }catch(error){
       debugPrint('Recurring payment commit could not be confirmed: $error');
       if(mounted)await _loadFinanceSafely();
       if(mounted)snack(context,waffraIsEnglish?
        'Payment not confirmed. Records refreshed; check before retrying.':
        'لم يتم تأكيد الدفع. تم تحديث البيانات؛ تحقق منها قبل إعادة المحاولة.');
       return;
      }
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
  categories.where((c)=>c.income==income&&c.isSubcategory&&
   waffraCategoryAvailableForNewEntry(categories,c)).toList();
 // Used in NEW recurring selections. forType stays historical/complete.
 List<BudgetCategory> forSelectableType(bool income)=>
  forManualTransactionType(income);
 Future<bool?> confirm(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),child:const WaffraText('تأكيد'))]));
 Future<bool?> confirmDeletion(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(title),content:WaffraText(body),
   actionsPadding:const EdgeInsets.fromLTRB(14,6,14,14),
   actions:[SizedBox(width:double.maxFinite,child:Row(children:[
    Expanded(child:OutlinedButton(
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',maxLines:2,
      textAlign:TextAlign.center))),
    const SizedBox(width:10),
    Expanded(child:FilledButton(
     style:FilledButton.styleFrom(backgroundColor:Colors.red),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
     child:WaffraText(waffraIsEnglish?'Confirm delete':'تأكيد الحذف',
      maxLines:2,textAlign:TextAlign.center))),
   ]))]));
 /// Read a single authoritative SQLCipher account witness immediately
 /// before posting an explicitly reviewed bank SMS. Guarded legacy keeps the
 /// existing SMS save behavior, without a shadow account database.
 Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(
  List<MoneyEntry> candidates,{String? recurringId,String smsSender='',
   List<String?>? initialSelectedIds})async{
  final manualRequiresAccount=candidates.any((c)=>c.sourceType=='manual');
  // A confirmed due payment is a new finance entry, not an unassigned SMS.
  final dueRequiresAccount=recurringId!=null||
   candidates.any((c)=>c.sourceType=='goal_due');
  // User-approved M470: no NEW posted income/expense, SMS, receipt or due
  // can be saved without an active account. Old unassigned history is kept.
  final mustSelectAccount=candidates.isNotEmpty;
  assert(!mustSelectAccount||manualRequiresAccount||dueRequiresAccount||
   candidates.isNotEmpty);
  final bridge=_financeBinding?.accountsBridge;
  if(bridge==null){
   if(mustSelectAccount&&mounted)snack(context,waffraIsEnglish?
    'Create a verified money account in My Accounts before adding income or expenses.':
    'أنشئ حسابًا ماليًا موثّقًا من حساباتي قبل إضافة دخل أو مصروف.',isError:true);
   return mustSelectAccount?null:(ids:null,generation:null);
  }
  if(candidates.isEmpty)return (ids:null,generation:null);
  try{
   var verified=await bridge.readVerifiedAccounts();
   if(!mounted)return null;
   var active=verified.balances.where((a)=>!a.archived).toList();
   String? createdFromSmsAccountId;
   // One owner-bound evidence snapshot governs first-time prompt and exact reuse.
   var learned=<WaffraSmsAccountEvidence>[];
   if(smsSender.isNotEmpty&&_smsRuleOwnerKey.isNotEmpty){
    try{learned=await const WaffraSmsAccountLearningStore()
     .read(_smsRuleOwnerKey);}
    catch(_){/* Missing evidence must never auto-select an account. */}
   }
   // First *reviewed* SMS from a known bank with no existing verified
   // account for that institution can offer a NEW account. Neither sender
   // text nor a suggested bank automatically creates a financial account.
   final knownBank=WaffraSmsAccountLearning.bankGroup(smsSender);
   final firstSenderIncomeExpense=knownBank!=null&&candidates.length==1&&
    candidates.single.sourceType=='sms'&&
    candidates.single.notes.trim().isNotEmpty&&
    WaffraBankSmsFactsParser.parse(candidates.single.notes)
     .canAutoPostAsIncomeExpense;
   final sameBankIdsForOffer=<String>{
    if(knownBank!=null)
     for(final account in active)
      if((account.kind=='bank'||account.kind=='wallet')&&
       (account.providerId!=null?account.providerId==knownBank:
        WaffraSmsAccountLearning.bankGroup(account.name)==knownBank))
       account.id,
   };
   final alreadyLinkedToBank=sameBankIdsForOffer.isNotEmpty;
   final firstSmsFacts=firstSenderIncomeExpense?
    WaffraBankSmsFactsParser.parse(candidates.single.notes):null;
   final identitySuffix=firstSmsFacts==null?null:
    WaffraSmsAccountLearning.suffix4(
     firstSmsFacts.kind==WaffraBankOperationKind.income?
      firstSmsFacts.destinationSuffix:firstSmsFacts.sourceSuffix);
   final verifiedIdentity=identitySuffix==null?null:
    WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
     suffix:identitySuffix,
     activeAccountIds:active.map((account)=>account.id).toSet(),
     sameBankAccountIds:sameBankIdsForOffer);
   // A second account at the SAME bank is a new identity with different
   // last four. First time: choose an existing account or create a new one.
   // A previously confirmed exact sender+four must not be prompted again.
   final needsNewIdentityChoice=firstSenderIncomeExpense&&
    (!alreadyLinkedToBank||
     (identitySuffix!=null&&verifiedIdentity==null));
   if(needsNewIdentityChoice&&
       (initialSelectedIds==null||initialSelectedIds.every((id)=>id==null))){
    final offered=await showWaffraDialog<bool>(
     context:context,builder:(dialog)=>AlertDialog(
      title:WaffraText(waffraIsEnglish?
       'Create an account for this bank?':
       'إنشاء حساب مالي لهذا البنك؟'),
      content:WaffraText(waffraIsEnglish?
       'Bank identity "$smsSender"'+
        (identitySuffix==null?'':' ••••$identitySuffix')+
        ' needs account confirmation. Choose an existing bank account or '
        'create a new one with an editable 0 SAR opening balance. '
        'No transaction is posted without consent.':
       'هوية البنك "$smsSender"'+
        (identitySuffix==null?'':' ••••$identitySuffix')+
        ' محتاجة ربط أول مرة. اختار حساب موجود أو أنشئ حساب بنكي جديد '
        'برصيد افتتاحي صفر ريال قابل للتعديل. '
        'لن تُسجل العملية من غير موافقتك.'),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog,false),
        child:WaffraText(waffraIsEnglish?'Choose existing':'اختيار حساب موجود')),
       FilledButton(onPressed:()=>Navigator.pop(dialog,true),
        child:WaffraText(waffraIsEnglish?'Add account':'إضافة حساب')),
      ],
     ));
    if(!mounted)return null;
    if(offered==true){
     // M483 / #407: prefill only the masked source for outgoing
     // transactions or masked destination for incoming transactions.
     // Nothing is linked or posted until the user explicitly confirms.
     final verifiedFacts=WaffraBankSmsFactsParser.parse(
      candidates.single.notes);
     final reviewedIncome=verifiedFacts.kind==WaffraBankOperationKind.income;
     final proposedSuffix=WaffraSmsAccountLearning.suffix4(
      reviewedIncome?verifiedFacts.destinationSuffix:
       verifiedFacts.sourceSuffix);
     final savedCustomTypes=active.where((account)=>
       account.kind=='bank'&&account.customSubtypeLabel!=null)
       .map((account)=>account.customSubtypeLabel!).toSet().toList()..sort();
     final draft=await showWaffraDialog<WaffraNewAccountDraft>(
      context:context,builder:(dialog)=>WaffraNewAccountDialog(
       english:waffraIsEnglish,suggestedProviderId:knownBank,
       suggestedSenderName:smsSender,suggestedLastFour:proposedSuffix,
       customSubtypeOptions:{'bank':savedCustomTypes}));
     if(!mounted)return null;
     if(draft!=null){
      // Users may edit the form. Never silently approve a different bank
      // than the reviewed sender or convert a bank SMS to a cash account.
      if(draft.kind!='bank'||draft.providerId!=knownBank||
         draft.subtype==null)throw StateError(
        'New SMS account does not match verified sender institution.');
      final id='m470-sms-'+DateTime.now().microsecondsSinceEpoch.toString();
      final createdIso=DateTime.now().toUtc().toIso8601String();
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      await api.balances();
      await api.createTypedAccountWithIdentity(
       id:id,name:draft.name,kind:'bank',providerId:knownBank,
       subtype:draft.subtype!,openingMinor:draft.openingMinor,
       createdIso:createdIso,lastFour:draft.lastFour,
       customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
      // A bank account creation is one verified SQLCipher transaction.
      // The later SMS posting is a SEPARATE user-confirmed transaction;
      // failure cannot debit twice or erase the newly confirmed account.
      await _refreshFromVerifiedFinance();
      if(!mounted||_financeLoadFailure!=null)return null;
      verified=await bridge.readVerifiedAccounts();
      active=verified.balances.where((a)=>!a.archived).toList();
      if(!active.any((a)=>a.id==id))throw StateError(
       'Created SMS account was not verified after save.');
      createdFromSmsAccountId=id;
     }
    }
   }
   if(active.isEmpty){
    if(mustSelectAccount){
     snack(context,waffraIsEnglish?
      'Add at least one bank, cash, or wallet account in My Accounts first.':
      'لازم تضيف حسابًا ماليًا واحدًا على الأقل من حساباتي أولًا.',isError:true);
     return null;
    }
    return (
     ids:List<String?>.filled(candidates.length,null),
     generation:verified.witness.generation);
   }
   final assigned=List<String?>.filled(candidates.length,null);
   if(createdFromSmsAccountId!=null){
    assigned[0]=createdFromSmsAccountId;
   }
   if(initialSelectedIds!=null){
    if(initialSelectedIds.length!=candidates.length)return null;
    for(var index=0;index<assigned.length;index++){
     final requested=initialSelectedIds[index];
     if(requested==null)continue;
     if(!active.any((a)=>a.id==requested))return null;
     assigned[index]=requested;
    }
   }
   // Only verified masked bank evidence can suggest a specific SMS account.
   // Manual, recurring, goal-due and uncertain bank messages stay unassigned
   // until the user makes an explicit choice; never inherit Home's header.
   final accountEvidence=WaffraVerifiedAccountsApi(bridge:bridge);
   // Sender-only learning needs two confirmations AND exactly one account
   // whose user-chosen bank name matches the sender. No sender guesses for
   // two accounts at the same bank; suffix evidence remains authoritative.
   // Reuse the evidence snapshot read before the first-identity prompt.
   final bankGroup=WaffraSmsAccountLearning.bankGroup(smsSender);
   final sameBankIds=<String>{
    if(bankGroup!=null)
     for(final account in active)
      if((account.kind=='bank'||account.kind=='wallet')&&
         (account.providerId!=null?account.providerId==bankGroup:
          WaffraSmsAccountLearning.bankGroup(account.name)==bankGroup))
       account.id,
   };
   final activeAccountIds=active.map((account)=>account.id).toSet();
   // A recurring template owns its default, not the active Home header.
   // A change in this review applies to this payment only; users manage
   // future defaults separately in Accounts -> Recurring defaults.
   if(recurringId!=null&&candidates.length==1){
    try{
     final saved=await accountEvidence.recurringDefaultAccount(recurringId);
     if(saved!=null&&active.any((a)=>a.id==saved))assigned[0]=saved;
    }catch(_){
     // Missing/unverified template means explicit choice or unassigned.
    }
   }
   for(var i=0;i<candidates.length;i++){
    final item=candidates[i];
    if(assigned[i]!=null||item.sourceType!='sms'||item.notes.trim().isEmpty)continue;
    final facts=WaffraBankSmsFactsParser.parse(item.notes);
    if(!facts.canAutoPostAsIncomeExpense||
       (facts.kind==WaffraBankOperationKind.income)!=item.income)continue;
    try{
     final exactFour=WaffraSmsAccountLearning.suffix4(
      item.income?facts.destinationSuffix:facts.sourceSuffix);
     final previouslyConfirmed=exactFour==null?null:
      WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
       suffix:exactFour,activeAccountIds:activeAccountIds,
       sameBankAccountIds:sameBankIds);
     if(previouslyConfirmed!=null){assigned[i]=previouslyConfirmed;continue;}
     final match=await accountEvidence.suggestSmsAccount(facts);
     if(match.confident&&match.accountId!=null&&
        bankGroup!=null&&sameBankIds.contains(match.accountId)&&
        active.any((a)=>a.id==match.accountId)){
      // A suffix by itself cannot prove the SMS belongs to this sender's bank.
      assigned[i]=match.accountId;
     }
    }catch(_){
     // Suggestion failure must never guess or silently link an account.
    }
   }
   if(!mounted)return null;
   // M475 #412: don't ask for the same money account twice after an
   // explicit entry-editor choice or user-approved account creation.
   final allEditorAccountsConfirmed=initialSelectedIds!=null&&
    initialSelectedIds.length==assigned.length&&
    initialSelectedIds.every((id)=>id!=null);
   final newAccountConfirmed=createdFromSmsAccountId!=null&&
    candidates.length==1;
   // Only a previously owner-confirmed, exact sender+four identity may
   // bypass REPEATING account linking. The finance writer still requires
   // the owner's transaction Yes and a fresh SQLCipher account witness.
   final exactSmsIdentityConfirmed=candidates.length==1&&
    assigned.single!=null&&candidates.single.sourceType=='sms'&&
    WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
     suffix:WaffraSmsAccountLearning.suffix4(
      candidates.single.income?
       WaffraBankSmsFactsParser.parse(candidates.single.notes).destinationSuffix:
       WaffraBankSmsFactsParser.parse(candidates.single.notes).sourceSuffix),
     activeAccountIds:activeAccountIds,
     sameBankAccountIds:sameBankIds)==assigned.single;
   if((allEditorAccountsConfirmed||newAccountConfirmed||
      exactSmsIdentityConfirmed)&&assigned.every((id)=>id!=null)){
    // Read a fresh SQLCipher account witness, not a stale picker snapshot.
    final latest=await bridge.readVerifiedAccounts();
    final liveIds=latest.balances.where((a)=>!a.archived)
     .map((a)=>a.id).toSet();
    if(!assigned.every((id)=>liveIds.contains(id))){
     if(mounted)snack(context,waffraIsEnglish?
      'Selected account changed; choose it again before saving.':
      'الحساب المختار اتغير؛ اختاره مرة تانية قبل الحفظ.',isError:true);
     return null;
    }
    return (ids:List<String?>.unmodifiable(assigned),
     generation:latest.witness.generation);
   }
   final providerGroups=WaffraRecurringAccountGroups.fromAccounts(active);
   final chosenProviders=List<String?>.generate(assigned.length,(index){
    for(final group in providerGroups){
     if(group.accounts.any((a)=>a.id==assigned[index]))return group.id;
    }
    return null;
   });
   final approved=await showWaffraDialog<bool>(context:context,
    builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
     title:WaffraText(mustSelectAccount?
      (waffraIsEnglish?'Choose a money account':'اختار الحساب المالي للعملية'):
      (waffraIsEnglish?
       'Which account for each bank transaction?':
       'تسجيل كل معاملة بنكية في أي حساب؟')),
     content:SizedBox(width:double.maxFinite,
      height:waffraKeyboardDialogListHeight(ctx,desired:500),
      child:ListView(children:[
       WaffraText(recurringId!=null
        ?(waffraIsEnglish
          ?'This selection is for this payment only. Change future defaults from Accounts.'
          :'الاختيار لهذه الدفعة فقط. غيّر الحساب للدفعات القادمة من الحسابات.')
        :manualRequiresAccount?
         (waffraIsEnglish?
          'Manual income and expenses must use an existing money account.':
          'الدخل والمصروف اليدوي لازم يرتبطوا بحساب مالي موجود.')
        :(waffraIsEnglish
          ?'Choose a verified money account; new entries cannot be unassigned.'
          :'اختار حسابًا ماليًا موثّقًا لكل عملية؛ الحفظ بدون حساب غير مسموح.')),
       const SizedBox(height:12),
       for(var n=0;n<candidates.length;n++)
        Padding(padding:const EdgeInsets.only(bottom:12),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          WaffraText(candidates[n].title+' · '+cash(candidates[n].amount),
           maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold)),
          const SizedBox(height:5),
          WaffraCenteredDropdownFormField<String>(
           key:ValueKey('m470-review-provider-'+n.toString()+'-'+
            (chosenProviders[n]??'none')),
           initialValue:chosenProviders[n],isExpanded:true,
           menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
           decoration:InputDecoration(
            labelText:waffraIsEnglish?'Bank or provider':'الجهة أو البنك',
            border:const OutlineInputBorder()),
           items:providerGroups.map((group)=>DropdownMenuItem<String>(
            value:group.id,child:WaffraText(waffraIsEnglish?
             group.labelEn:group.labelAr,maxLines:1))).toList(),
           onChanged:WaffraHaptics.selection((value)=>update((){
            chosenProviders[n]=value;
            assigned[n]=null; // Provider never silently approves an account.
           })),
          ),
          const SizedBox(height:7),
          WaffraCenteredDropdownFormField<String>(
           key:ValueKey('waffra-sms-account-'+n.toString()+'-'+
            (assigned[n]??'none')),
           initialValue:mustSelectAccount?
            assigned[n]:assigned[n]??'none',isExpanded:true,
           menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
           decoration:InputDecoration(
            labelText:waffraIsEnglish?'Money account':'الحساب المالي',
            border:const OutlineInputBorder()),
           items:providerGroups.where((p)=>p.id==chosenProviders[n])
            .expand((p)=>p.accounts).map((a)=>DropdownMenuItem(
             value:a.id,child:WaffraText(a.name,maxLines:1))).toList(),
           onChanged:chosenProviders[n]==null?null:
            WaffraHaptics.selection((value)=>update(
             ()=>assigned[n]=value)),
          ),
         ])),
      ])),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(
       onPressed:mustSelectAccount&&assigned.any((account)=>account==null)?
        null:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
       child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد')),
     ],
    )));
   if(approved!=true)return null;
   if(mustSelectAccount&&assigned.any((account)=>account==null))return null;
   return (ids:List<String?>.unmodifiable(assigned),
    generation:verified.witness.generation);
  }catch(_){
   if(mounted)snack(context,waffraIsEnglish?
    'Accounts could not be verified. Open My accounts before saving.':
    'تعذر التحقق من الحسابات. افتح حساباتي قبل حفظ العملية.');
   return null;
  }
 }
/// Budget assignment is OPTIONAL in every bank import: no assignment never blocks saving.
 Future<List<String?>?> reviewSmsBudgetLinks(List<MoneyEntry> candidates)async{
  final choices=namedBudgets.where((b)=>
   !b.deleted&&b.budget>0&&b.budgetActive).toList();
  final assigned=List<String?>.filled(candidates.length,null);
  if(!candidates.any((e)=>!e.income)||choices.isEmpty)return assigned;
  return showWaffraDialog<List<String?>>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose budgets for expenses':'تسجيل كل مصروف في أي ميزانية؟'),
    content:SizedBox(width:double.maxFinite,
     height:waffraKeyboardDialogListHeight(ctx,desired:500),
     child:ListView(children:[
      WaffraText(waffraIsEnglish?
       'Choose a budget for each expense, or leave it unlinked.':
       'اختار ميزانية لكل مصروف، أو سيبه بدون ربط.'),
      const SizedBox(height:12),
      for(var n=0;n<candidates.length;n++)
       if(!candidates[n].income)Padding(
        padding:const EdgeInsets.only(bottom:12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         WaffraText(candidates[n].title+' · '+cash(candidates[n].amount),
          style:const TextStyle(fontWeight:FontWeight.bold),maxLines:2),
         const SizedBox(height:5),
         WaffraCenteredDropdownFormField<String>(
          key:ValueKey('waffra-sms-budget-'+n.toString()+'-'+(assigned[n]??'none')),
          menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
          initialValue:assigned[n]??'none',isExpanded:true,
          decoration:InputDecoration(labelText:waffraIsEnglish?'Budget':'الميزانية',
           border:const OutlineInputBorder()),
          items:[
           DropdownMenuItem(value:'none',child:WaffraText(
            waffraIsEnglish?'Without a budget':'بدون ميزانية',maxLines:1)),
           ...choices.map((c)=>DropdownMenuItem(value:c.id,child:WaffraText(
            c.budgetLabel??'ميزانية '+c.displayName,maxLines:1))),
          ],
          onChanged:WaffraHaptics.selection((value)=>update(
           ()=>assigned[n]=value=='none'?null:value)),
         ),
         Align(alignment:AlignmentDirectional.centerStart,
          child:TextButton.icon(
           key:Key('waffra-sms-batch-create-budget-'+n.toString()),
           icon:const Icon(Icons.add_circle_outline_rounded,size:17),
           label:WaffraText(waffraIsEnglish?
            'Create new budget':'إنشاء ميزانية جديدة'),
           onPressed:WaffraHaptics.tap(()async{
            final id=await chooseBudgetCategory();
            if(id==null||!ctx.mounted)return;
            final found=namedBudgets.where((b)=>b.id==id&&
             b.budget>0&&b.budgetActive&&!b.deleted).toList();
            if(found.length!=1)return;
            update((){
             choices
              ..clear()
              ..addAll(namedBudgets.where((b)=>
               b.budget>0&&b.budgetActive&&!b.deleted));
             assigned[n]=id;
            });
           }),
          )),
        ])),
     ])),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel batch':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()async{
      final unlinked=List<int>.generate(candidates.length,(i)=>i)
       .where((i)=>!candidates[i].income&&assigned[i]==null).length;
      if(unlinked>0){
       final confirmed=await waffraConfirmUnlinkedBudgetSave(
        context:ctx,expenseCount:unlinked);
       if(!confirmed||!ctx.mounted)return;
      }
      if(ctx.mounted)Navigator.pop(ctx,List<String?>.from(assigned));
     }),
      child:WaffraText(waffraIsEnglish?
       'Continue saving':'متابعة الحفظ')),
    ],
   )));
 }
 // M636: Manual paste/review sheet retired. Automatic encrypted SMS Review
 // and owner-verified account-bound finance editor are retained.

 // M643: Saudi FX posting stays disabled; retain non-posting preview for strict FX QA.
 // ignore: unused_element
 Future<void> _previewForeignBankCurrency(String raw)async {
  if(!WaffraSaudiRelease.bankSmsForeignCurrencyPreview){
   if(mounted)snack(context,waffraIsEnglish?
    'Non-SAR transactions cannot be saved in this Saudi release.':
    'العمليات بغير الريال غير مدعومة في النسخة السعودية الحالية.');
   return;
  }
  // No bank message contents, personal identifiers, photos or notes are
  // included in the FX network request: only original and target codes.
  final source=WaffraSmsCurrencies.originalAmount(raw);
  if(!mounted)return;
  if(source==null){
   snack(context,waffraIsEnglish?
    'Original currency or amount is uncertain. Check the bank message first.':
    'العملة أو المبلغ الأصلي غير مؤكد. راجع الرسالة البنكية أولًا.');
   return;
  }
  final target=WaffraDisplayCurrency.country.code;
  if(source.currency==target){
   snack(context,waffraIsEnglish?
    'Bank currency matches the app display currency. Encrypted foreign-currency saving is not enabled yet.':
    'عملة الرسالة مطابقة لعملة العرض. حفظ العملات الأجنبية المشفر غير مفعل بعد.');
   return;
  }
  snack(context,waffraIsEnglish?
   'Retrieving the latest available exchange rate…':
   'جاري جلب أحدث سعر صرف متاح…',isError:false);
  final approved=await WaffraForeignCurrencyPreview.show(context,
   originalAmount:source.amount,originalCurrency:source.currency,
   targetCurrency:target,english:waffraIsEnglish);
  if(approved!=null&&mounted){
   // Do not write an FX amount to the guarded legacy ledger. We can only
   // persist the conversion together with original currency + approved quote
   // in the atomically encrypted FX finance source after cutover approval.
   snack(context,waffraIsEnglish?
    'Conversion preview approved. No amount was saved; encrypted FX posting is not active.':
    'تمت الموافقة على معاينة التحويل فقط. لم يُحفظ أي مبلغ؛ تسجيل العملات المحوّلة ينتظر تفعيل التخزين المعتمد.');
  }
 }

 // M719: original verified transaction entry form extracted to same-library Home part.
 Future<String?> chooseTransactionCategory(
  BuildContext ctx,List<BudgetCategory> options,String selected,{
  bool leafLabels=false,bool allowCreate=false,bool typeIncome=false,
  String? parentId,String? suggested,
 })async{
  var query='';
  const createMain='__waffra_category_picker_new_main__';
  const createSub='__waffra_category_picker_new_sub__';
  final picked=await showWaffraDialog<String>(
   context:ctx,builder:(dialogCtx)=>StatefulBuilder(
    builder:(dialogCtx,refresh){
     final filtered=options.where((item){
      final label=leafLabels?item.displayName:item.name;
      return waffraSearchAny([label,waffraTr(label),waffraTr(item.name)],query);
     }).toList();
     return AlertDialog(
      title:WaffraText(waffraIsEnglish?'Search categories':'بحث في الأقسام'),
      content:SizedBox(
       width:360,height:waffraKeyboardDialogListHeight(dialogCtx),
       child:Column(children:[
        TextField(onChanged:(v)=>refresh(()=>query=v),
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search),
          hintText:waffraIsEnglish?'Search…':'اكتب اسم القسم',
          border:const OutlineInputBorder())),
        if(allowCreate&&!leafLabels)...[
         const SizedBox(height:6),
         ListTile(
          key:const Key('waffra-inline-create-main-category'),
          dense:true,
          leading:const Icon(Icons.create_new_folder_outlined,color:emerald),
          title:WaffraText(waffraIsEnglish?
           'New main category':'إضافة قسم رئيسي جديد'),
          onTap:WaffraHaptics.tap(()=>
           Navigator.pop(dialogCtx,createMain))),
        ],
        if(allowCreate&&leafLabels)...[
         const SizedBox(height:6),
         ListTile(
          key:const Key('waffra-inline-create-subcategory'),
          dense:true,
          leading:const Icon(Icons.account_tree_outlined,color:emerald),
          title:WaffraText(waffraIsEnglish?
           'New subcategory':'إضافة قسم فرعي جديد'),
          onTap:WaffraHaptics.tap(()=>
           Navigator.pop(dialogCtx,createSub))),
         const Divider(height:8),
        ],
        Expanded(child:filtered.isEmpty?
         Center(child:WaffraText(waffraIsEnglish?
          'No matching categories':'لا توجد أقسام مطابقة')):
         ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){
          final item=filtered[i];
          return ListTile(
           selected:selected==item.name,
           leading:Icon(categoryIcon(item.icon),color:Color(item.color)),
           title:WaffraText(waffraTr(leafLabels?
            item.displayName:item.name),maxLines:3),
           onTap:WaffraHaptics.tap(()=>
            Navigator.pop(dialogCtx,item.name)));
         })),
       ])),
      actions:[TextButton(
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
       child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
     );
    }));
  if(picked==null||!mounted||!ctx.mounted)return null;
  if(picked!=createMain&&picked!=createSub)return picked;
  var categoryParentId='';
  if(picked==createSub){
   final root=categories.where((c)=>c.id==parentId&&
    !c.isSubcategory&&c.income==typeIncome).toList();
   if(root.isNotEmpty){
    categoryParentId=root.single.id;
   }else{
    final parents=categories.where((c)=>
     !c.isSubcategory&&c.income==typeIncome).toList();
    if(parents.isEmpty){
     snack(ctx,waffraIsEnglish?
      'Create a main category first':'أضف قسمًا رئيسيًا أولًا');
     return null;
    }
    final selectedParent=await chooseTransactionCategory(ctx,parents,'');
    if(selectedParent==null||!mounted||!ctx.mounted)return null;
    final chosen=parents.where((c)=>c.name==selectedParent).toList();
    if(chosen.length!=1)return null;
    categoryParentId=chosen.single.id;
   }
  }
  // The exact same icon/color/name dialog used by Categories handles both
  // new main and new child categories. No parallel incomplete form exists.
  final created=await categoryDialog(
   income:typeIncome,parentId:categoryParentId,
   suggested:picked==createSub?suggested:null);
  if(created==null||!mounted||!ctx.mounted)return null;
  if(WaffraValidators.uniqueCategory(created.name,
    categories.where((c)=>c.income==created.income).map((c)=>c.name))
    !=null){
   snack(ctx,waffraIsEnglish?
    'Category name already exists':'اسم القسم موجود بالفعل');
   return null;
  }
  setState(()=>categories.add(created));
  if(!await _persistModuleOrReload(
   WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   operation:'transaction-category-picker-create'))return null;
  return created.name;
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
  final original=picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.\u0600-\u06FF ]'),'_');
  final target='${directory.path}/${newId()}__$original';
  await File(picked.path).copy(target);
  return target;
 }
 Future<void> showReceipt(String encoded,{int initialIndex=0,String? entryId})async {
  final paths=waffraReceiptPaths(encoded);
  final encrypted=paths.isNotEmpty&&
   paths.every((p)=>p.startsWith('waffra-receipt://'));
  final available=<String>[];
  final encryptedBytes=<Uint8List>[];
  if(encrypted){
   // The tokens are opaque and owner-bound; never treat them as file paths.
   if(entryId==null||!List.generate(paths.length,
      (i)=>WaffraEncryptedReceiptReference.matches(
       paths[i],entryId,i)).every((matched)=>matched)){
    if(mounted)snack(context,waffraIsEnglish?
     'Encrypted receipt owner could not be verified.':
     'تعذر التحقق من ارتباط الصورة بالعملية.',isError:true);
    return;
   }
   try{
    encryptedBytes.addAll(await _financeAuthority.loadEncryptedReceiptImages(
     route:WaffraFinanceRoute.receiptView,entryId:entryId));
    if(encryptedBytes.length!=paths.length){
     throw StateError('Encrypted receipt count mismatch');
    }
    available.addAll(paths);
   }catch(error){
    if(mounted)snack(context,waffraIsEnglish?
     'Could not verify encrypted attachments.':
     'تعذر التحقق من المرفقات المشفرة.',isError:true);
    return;
   }
  }else{
   if(paths.any((p)=>p.startsWith('waffra-receipt://'))){
    if(mounted)snack(context,waffraIsEnglish?
     'Mixed receipt references were rejected.':
     'تم رفض مراجع مرفقات غير متطابقة.',isError:true);
    return;
   }
   for(final path in paths){if(await File(path).exists())available.add(path);}
  }
  if(available.isEmpty){if(mounted)snack(context,waffraIsEnglish?
   'Images not found on this device':'ما لقينا الصور على الجهاز');return;}
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
          child:Center(child:encrypted?
           Image.memory(encryptedBytes[index],fit:BoxFit.contain):
           Image.file(File(available[index]),fit:BoxFit.contain)))))),
       Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        child:WaffraText(encrypted?
         (waffraIsEnglish?'Attachment ${current+1}':'مرفق ${current+1}'):
         WaffraReceiptFilename.displayName(available[current]),
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
 Future<void> _requestPercentageAlertPermission()async{
  try{
   final granted=await WaffraReminders.requestPermission();
   if(!granted&&mounted)snack(context,waffraIsEnglish?
    'In-app alerts are on; allow notifications in Android Settings for lock-screen alerts.':
    'تنبيهات التطبيق مفعلة. فعّل إشعارات وفرة من إعدادات أندرويد عشان توصلك خارج التطبيق.');
  }catch(error){
   debugPrint('Optional percentage notification permission unavailable: $error');
  }
 }
 Future<void> budgetAlert(MoneyEntry entry,double previousSpent)async {
  if(entry.income)return;
  final budgets=namedBudgets.where((b)=>b.budget>0&&
    b.budgetActive&&b.alertsEnabled&&!b.deleted&&b.id==entry.budgetId).toList();
  if(budgets.length!=1)return;
  final category=budgets.single;
  final spent=waffraNamedBudgetSpent(entries,categories,category,entry.date);
  final stages=<int>{category.alertPercent,100}.toList()..sort();
  final crossedStages=stages.where((stage)=>
   previousSpent<category.budget*stage/100&&
   spent>=category.budget*stage/100).toList();
  if(crossedStages.isEmpty||!mounted)return;
  // Only non-financial hashed alert markers are stored locally. A later edit
  // that reduces spend must not re-alert for a threshold already shown.
  final newlyCrossed=await WaffraBudgetAlertOnce.claim(
   owner:'${widget.profile.provider}|${widget.profile.phone}|${widget.profile.email}',
   budgetId:category.id,month:entry.date,crossedStages:crossedStages);
  if(!newlyCrossed||!mounted)return;
  final crossed=crossedStages.last;
  try{await WaffraReminders.showBudgetThreshold(
   budgetId:category.id,stage:crossed,english:waffraIsEnglish);}
  catch(error){debugPrint('Budget notification unavailable: $error');}
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Budget alert':'⚠️ تنبيه الميزانية'),
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
 // M687: PDF exporter moved to a same-library State extension.
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
   _m684InvalidatePeriodRead();
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
     'هل تريد نقل المعاملة «${entry.title}» وفواتيرها إلى المحذوفات لمدة 30 يومًا؟');
   if(approved!=true||!mounted)return;
   await _financialWriteQueue.submit(<String,Object>{'id':entry.id},(_)async{
    // M675: a concurrent SMS/Widget writer may have changed the source
    // generation while the user was reading the confirmation dialog.
    // Re-open and verify all witnesses under the serialized write queue.
    final current=await _financeAuthority.load(
     route:WaffraFinanceRoute.transactionDeleteAndUndo);
    if(current.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
       current.encryptedWitness==null){
     throw StateError('Current encrypted deletion source unavailable.');
    }
    WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
     ledgerRaw:current.ledgerRaw,selected:entry.toJson());
    final receipt=await _financeAuthority.loadVerifiedReceiptScreen(
     route:WaffraFinanceRoute.receiptView,entryId:entry.id);
    if(receipt.entryId!=entry.id||
       receipt.generation!=current.encryptedWitness!.generation||
       receipt.isInRecycleBin){
     throw StateError('Encrypted receipt changed during deletion.');
    }
    final committed=await _financeAuthority.deleteVerifiedTransactionToRecycle(
     baseline:current,entryId:entry.id,
     expectedImageHashes:receipt.imageSha256,
     userConfirmed:true,now:DateTime.now().toUtc());
    _publishVerifiedTransactionLedger(committed);
   });
   if(!mounted)return;
   snack(context,waffraIsEnglish?
    'Transaction saved in encrypted Recently Deleted for 30 days.':
    'تم نقل المعاملة إلى المحذوفات لمدة 30 يومًا.',
    isError:false,duration:const Duration(seconds:6),
    actionLabel:waffraIsEnglish?'Undo':'تراجع',
    onAction:(){if(mounted)unawaited(_undoVerifiedDeletedEntry(entry.id));});
  }catch(error){
   debugPrint('Verified encrypted transaction delete refused: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Deletion could not be verified. Your saved financial data was not reset. Reload before retrying.':
     'تعذر التحقق من الحذف. لم يتم تصفير بياناتك المالية. أعد تحميل المعاملات قبل المحاولة.');
    // No full startup reset or transient black screen on failed deletion.
    unawaited(_refreshFromVerifiedFinance());
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
    unawaited(_refreshFromVerifiedFinance());
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
      'لا توجد معاملات لاسترجاعها.'),
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
  // Deleting a confirmed goal debit without also reversing its goal-wallet
  // earmark would silently increase spendable cash. No unverified rollback.
  if(e.sourceType=='goal_due'){
   snack(context,waffraIsEnglish?
    'Goal payments need a verified wallet reversal before deletion. '
    'No money was changed.':
    'حذف استحقاق الهدف يحتاج عكس الخصم من محفظة الهدف بأمان؛ '
    'لم يتم تغيير أي مبلغ.');
   return;
  }
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _deleteVerifiedEntry(e);
   return;
  }
  final yes=await confirmDeletion(waffraIsEnglish?'Delete transaction':'حذف العملية',
   waffraIsEnglish?'Delete «'+e.title+'»? You can undo for 6 seconds after deletion.':'هل تريد حذف المعاملة «'+e.title+'»؟ يمكنك التراجع خلال 6 ثوانٍ بعد الحذف.');
  if(yes!=true||!mounted)return;
  // A tentative removal is never success until the source acknowledges it.
  _m684InvalidatePeriodRead();
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
    _m684InvalidatePeriodRead();
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

   ])),
  ));
  if(!mounted)return;
  switch(action){
   case 'open':await transactionDetails(entry);break;
   case 'edit':
    if(entry.sourceType=='goal_due'){
     await _m665ExplainLinkedGoalEdit(paid:true);
    }else{
     await entrySheet(initial:entry);
    }
    break;
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
    linkedBudgetName:namedBudgets.where((b)=>b.id==entry.budgetId)
      .map((b)=>b.name).firstOrNull,
    linkedBudgetPaused:namedBudgets.any((b)=>b.id==entry.budgetId&&
      (!b.budgetActive||b.deleted)),
    showBudgetInfo:entry.budgetId!=null||waffraHasSelectableBudget(namedBudgets),
    onLinkBudget:entry.income||entry.budgetId!=null||
      !waffraHasSelectableBudget(namedBudgets)?null:(){
      Navigator.pop(ctx);
      unawaited(assignExistingExpenseToBudget(entry));
    },
    onClose:()=>Navigator.pop(ctx),
    onViewReceipt:waffraReceiptPaths(entry.receiptPath).isNotEmpty
      ?(){Navigator.pop(ctx);showReceipt(entry.receiptPath!,entryId:entry.id);}
      :null,
   ),
  );
 }

 Widget tile(MoneyEntry e){
  final c=categoryFor(e.category,e.income);
  // Restored M384 corner count uses persisted receipt references only.
  // Never migrate, move or modify existing receipt files during rendering.
  final attachmentCount=waffraReceiptPaths(e.receiptPath).length;
  return Card(color:e.income?waffraIncomeBackground:waffraExpenseBackground,
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:EdgeInsets.only(top:attachmentCount>0?16:0),child:ListTile(
   textColor:waffraInk,iconColor:forest,
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
      child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:WaffraText(e.title,style:const TextStyle(color:waffraInk,fontWeight:FontWeight.w600)),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(color:waffraInk)),
    WaffraText(WaffraTransactionDetailsDialog.sourceLabel(
     e.sourceType,waffraIsEnglish),
     style:const TextStyle(fontSize:11,color:waffraInk)),

   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    Column(mainAxisSize:MainAxisSize.min,children:[
     FittedBox(fit:BoxFit.scaleDown,child:RiyalAmount(e.amount,
      prefix:e.income?'+':'-',style:TextStyle(fontFamily:'Tajawal',fontSize:18,
       fontWeight:FontWeight.w800,color:e.income?const Color(0xFF075C40):waffraInk))),
    ]),
    IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
     onPressed:WaffraHaptics.tap(()=>transactionActions(e)),icon:const Icon(Icons.more_vert,color:forest)),
   ]))),
    if(attachmentCount>0)PositionedDirectional(top:0,start:0,
     child:WaffraReceiptCornerAction(
      key:Key('waffra-receipt-corner-list-'+e.id),
      count:attachmentCount,english:waffraIsEnglish,
      onTap:()=>showReceipt(e.receiptPath!,entryId:e.id))),
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
   setState((){_m684InvalidatePeriodRead();entries.clear();smsHashes.clear();});
   unawaited(_refreshWidget());
   snackSuccess(context,waffraIsEnglish?'All transactions deleted':'تم حذف جميع المعاملات');
  }catch(e){
   debugPrint('Confirmed transaction deletion could not be verified: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be confirmed. Reload before retrying.':
    'تعذر تأكيد الحذف. أعد تحميل المعاملات قبل المحاولة مجددًا.');
  }
 }
 // M715: budget editor, historical linking and category administration moved to registered Home part.
 Future<void> showSummaryTransactions(bool income)async {
  final items=_m467ScopedEntries().where((e)=>e.income==income).toList()
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
 /// M611: read the actual owner-scoped encrypted transfer journal.
 /// A Home history tile cannot post any money.
 Future<void> showInternalTransferTransactions()async{
  await _m647ShowInternalTransfers();
 }
 /// Parent institution is a visual attribute of a *verified* child account.
 /// Never treat the provider catalog as authorization to post money.
 // M733: verified transfer and savings card UI moved to registered same-library part.
 Widget compactTransaction(MoneyEntry entry){
  final cat=categoryFor(entry.category,entry.income);
  final attachmentCount=waffraReceiptPaths(entry.receiptPath).length;
  // M650: paid recurring/goal-due rows are already persisted MoneyEntry
  // rows. Violet is a visual facet, never a new ledger debit.
  final paidDue=entry.sourceType=='recurring'||entry.sourceType=='goal_due';
  final darkMode=Theme.of(context).brightness==Brightness.dark;
  final valueColor=paidDue?(darkMode?const Color(0xFFD6BBFF):
   const Color(0xFF7653AA)):(entry.income?waffraIncomeTone(context):Colors.deepOrange);
  final rowColor=paidDue?(darkMode?const Color(0xFF302744):
   const Color(0xFFEFE9F8)):entry.income?
   (darkMode?const Color(0xFF244C3A):const Color(0xFFB2D5C2)):
   (darkMode?const Color(0xFF49302C):const Color(0xFFFCECE8));
  return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Container(
   constraints:const BoxConstraints(minHeight:98),
   decoration:BoxDecoration(color:rowColor,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:forest.withValues(alpha:darkMode ? 0.18 : 0.08))),
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:EdgeInsets.fromLTRB(10,attachmentCount>0?20:9,10,9),child:Row(children:[
     CircleAvatar(radius:16,
      backgroundColor:(entry.sourceType=='goal_due'?valueColor:Color(cat.color))
       .withValues(alpha:0.13),
      child:entry.sourceType=='goal_due'?
       Icon(Icons.flag_outlined,color:valueColor,size:21):
       WaffraIllustration(topic:cat.icon,size:36)),
     const SizedBox(width:8),
     Expanded(child:InkWell(onTap:WaffraHaptics.tap(()=>transactionDetails(entry)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       if(paidDue)WaffraText(waffraIsEnglish?'Paid due':'استحقاق مدفوع',
        style:TextStyle(fontSize:11,color:valueColor,fontWeight:FontWeight.w700)),
       Tooltip(message:entry.title,child:WaffraText(entry.title,maxLines:3,
        style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
       if(entry.title.startsWith('معاملة بعملة تحتاج'))
        Padding(padding:const EdgeInsets.only(top:2,bottom:2),
         child:WaffraText(waffraIsEnglish?'Review source currency':
          'راجع عملة المعاملة قبل اعتماد قيمتها',
          maxLines:2,style:const TextStyle(
           fontSize:10,color:Colors.deepOrange,fontWeight:FontWeight.w600))),
       const SizedBox(height:2),
       WaffraText((entry.sourceType=='goal_due'?
        (waffraIsEnglish?'Savings goal due':'استحقاق هدف'):
        waffraTr(entry.category))+' • '+dayText(entry.date),
        maxLines:1,style:const TextStyle(fontSize:11,color:Colors.grey)),
        const SizedBox(height:2),
        if(!paidDue)Row(children:[
         Icon(entry.sourceType=='sms'?Icons.sms_outlined:
          Icons.edit_note_outlined,size:13,color:Colors.grey),
         const SizedBox(width:4),
         Expanded(child:WaffraText(
          WaffraTransactionDetailsDialog.sourceLabel(
           entry.sourceType,waffraIsEnglish),
          maxLines:1,style:const TextStyle(fontSize:11,color:Colors.grey))),
        ]),
        // A settled due is linked to the *verified* financial source,
        // not its mutable schedule title or sender label.
        if(paidDue&&_m468VerifiedAccountsLoaded)
         FutureBuilder<String?>(
          future:_m650DueVerifiedAccount(entry),
          builder:(ctx,snapshot){
           if(snapshot.connectionState!=ConnectionState.done){
            return const SizedBox.shrink();
           }
           if(entry.sourceType=='goal_due'){
            return Padding(padding:const EdgeInsets.only(top:5),
             child:Row(children:[
              Expanded(child:WaffraText(
               (waffraIsEnglish?'From money account: ':'من الحساب المالي: ')+
               (snapshot.data??(waffraIsEnglish?
                'Unverified account':'حساب غير محدد')),
               maxLines:2,style:TextStyle(color:valueColor,fontSize:11))),
              const SizedBox(width:5),
              Flexible(child:WaffraCurrencyAmount(
               waffraGoalDueCashMinor(entry)/100,fontSize:12,color:valueColor)),
             ]));
           }
           return Padding(padding:const EdgeInsets.only(top:4),
            child:WaffraText(
             (waffraIsEnglish?'Paid from: ':'تم السداد من: ')+
             (snapshot.data??(waffraIsEnglish?
              'Unverified account':'حساب غير محدد')),
             maxLines:2,style:TextStyle(
              color:valueColor,fontSize:11,fontWeight:FontWeight.w600)));
          }),
        if(entry.sourceType=='goal_due')
         Padding(padding:const EdgeInsets.only(top:3),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
           WaffraText(waffraIsEnglish?
            'From goal wallet: ':'من محفظة الهدف: ',
            style:TextStyle(color:valueColor,fontSize:11)),
           Flexible(child:WaffraCurrencyAmount(
            entry.goalWalletPaidMinor/100,fontSize:11,color:valueColor)),
          ])),
       const SizedBox(height:4),
       if(entry.sourceType=='goal_due')
        Row(children:[
         Expanded(child:WaffraText(waffraIsEnglish?
          'Total goal due':'إجمالي الاستحقاق',
          style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:valueColor))),
         WaffraText(waffraIsEnglish?'Amount':'المبلغ',
          style:TextStyle(fontSize:11,color:valueColor)),
         const SizedBox(width:5),
         Flexible(child:WaffraCurrencyAmount(
          entry.amount,fontSize:15,color:valueColor)),
        ])
       else Align(alignment:AlignmentDirectional.centerStart,
        child:Row(mainAxisSize:MainAxisSize.min,children:[
         WaffraText(waffraIsEnglish?'Amount':'المبلغ',style:TextStyle(color:valueColor,fontSize:11)),
         const SizedBox(width:5),
         WaffraCurrencyAmount(entry.income?entry.amount:-entry.amount,
          fontSize:15,color:valueColor),
        ])),
      ]))),
     const SizedBox(width:2),
     IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
      onPressed:WaffraHaptics.tap(()=>transactionActions(entry)),icon:const Icon(Icons.more_vert,size:18)),
    ])),
    if(attachmentCount>0)PositionedDirectional(top:0,start:0,
     child:WaffraReceiptCornerAction(
      key:Key('waffra-receipt-corner-home-'+entry.id),
      count:attachmentCount,english:waffraIsEnglish,
      onTap:()=>showReceipt(entry.receiptPath!,entryId:entry.id))),
   ])));
 }
 Widget _m549HomeFinanceAction({
  required String title,required IconData icon,
  required Color background,required Color iconColor,
  required VoidCallback onTap,
 })=>this._m684HomeFinanceAction(title:title,icon:icon,
  background:background,iconColor:iconColor,onTap:onTap);
 // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.
 // M735: Home category workflows extracted unchanged to registered same-library part.
 Widget categoriesPage()=>categoriesPageV2();
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
 // M711: original Home goal workflows live in the registered goal-actions part.
 // M689: all goal actions stay available by tapping the compact card.
 // The card itself has no redundant "View" or oversized quick-actions row.
 // M711: goal action sheet implementation lives in the goal-actions part.
 // M707: approved Goals and Recurring pages moved to registered Home part.
 // M721: original Home calendar, backup and account tools moved to registered same-library part.
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
  if(!ready||goalsOpened||accountOpened)return;
  final velocity=details.primaryVelocity??0;
  final dx=_swipeTravel.abs()>50?_swipeTravel:velocity/10;
  if(dx.abs()<65)return;
  final forward=waffraIsEnglish?dx>0:dx<0;
  final target=(tab+(forward?1:-1)).clamp(0,WaffraFooterNavigation.itemCount-1);
  if(target!=tab)unawaited(selectFooter(target));
 }
 Future<void> selectFooter(int target)async {
  if(target<0||target>=WaffraFooterNavigation.itemCount||!mounted||
    (target==tab&&!accountOpened&&!goalsOpened&&!addFabExpanded))return;
  setState((){
   if(target!=tab){
    _tabBackStack.add(tab);
    if(_tabBackStack.length>20)_tabBackStack.removeAt(0);
   }
   tab=target;accountOpened=false;goalsOpened=false;
   addFabExpanded=false;_headerCompact=false;
  });
 }
 bool _consumeHomeBack(){
  if(!mounted||!widget.postAuthVisible)return false;
  // Go back one UI layer at a time, without rebuilding earlier forms.
  if(addFabExpanded){setState(()=>addFabExpanded=false);return true;}
  if(accountOpened){
   // Existing product rule: Account back always returns to Home.
   setState((){
    accountOpened=false;goalsOpened=false;tab=0;
    _tabBackStack.clear();_headerCompact=false;
   });
   return true;
  }
  if(goalsOpened){setState(()=>goalsOpened=false);return true;}
  if(tab!=0){
   setState((){
    tab=_tabBackStack.isNotEmpty?_tabBackStack.removeLast():0;
    _headerCompact=false;
   });
   return true;
  }
  return false;
 }
 @override Widget build(BuildContext context)=>PopScope(
  // Let the root back policy route account/tabs before double-back exit.
  canPop:true,
  child:!ready&&_financeLoadFailure==null?
   const SizedBox.shrink():Stack(children:[Scaffold(
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
    Tooltip(message:waffraIsEnglish?'Notifications':'الإشعارات',
     child:Semantics(
      button:true,label:waffraIsEnglish?'Open financial notifications':'فتح الإشعارات المالية',
      child:InkWell(
       key:const Key('m549-header-notification-bell'),
       borderRadius:BorderRadius.circular(22),
       onTap:WaffraHaptics.tap(()=>unawaited(_m549OpenNotifications())),
       child:SizedBox(width:48,height:45,child:Stack(
        clipBehavior:Clip.none,children:[
        const Center(child:Icon(Icons.notifications_none_rounded,color:Colors.white,size:27)),
        if(_autoSmsPending.isNotEmpty)PositionedDirectional(
         end:0,top:0,child:Container(
          key:const Key('m549-notification-count-badge'),
          constraints:const BoxConstraints(minWidth:21,minHeight:17),
          padding:const EdgeInsets.symmetric(horizontal:3),
          decoration:BoxDecoration(color:const Color(0xFFE22F37),
           borderRadius:BorderRadius.circular(12)),
          child:Center(child:Text(
           _autoSmsPending.length>999?'+999':_autoSmsPending.length.toString(),
           style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold))),
         )),
       ]))))),
    const SizedBox(width:7),
    Tooltip(message:waffraIsEnglish?'My account and settings':'حسابي والإعدادات',
     child:Semantics(label:waffraIsEnglish?'Open account settings':'فتح إعدادات الحساب',
      button:true,child:InkWell(
       key:const Key('waffra-header-account-entry'),
       onTap:WaffraHaptics.tap(()=>setState((){
        // Device settings might have changed since the previous visit.
        _m528SmsEnabledFuture=null;
        addFabExpanded=false;goalsOpened=false;accountOpened=true;_headerCompact=false;
       })),
       borderRadius:BorderRadius.circular(30),
       child:AnimatedContainer(duration:waffraMotion(260),
        curve:Curves.easeOutCubic,padding:const EdgeInsets.all(3),
        decoration:BoxDecoration(shape:BoxShape.circle,
         border:Border.all(color:accountOpened?const Color(0xFF65E5AD):Colors.transparent,
          width:2),
         color:accountOpened?Colors.white.withValues(alpha:.13):Colors.transparent),
        child:waffraAvatar(widget.profile.gender,widget.profile.avatar,radius:18))))),
    const SizedBox(width:7),
   ]),
  // Instant content swap avoids building/animating the previous heavy tab
  // alongside the next one (the recurring -> savings navigation hitch).
  // No fragment of the Home is visible before owner-verified entries AND
  // account balances have loaded. The root gate above reveals this layout
  // as one complete screen with no fake amount or loading illustration.
  body:_financeLoadFailure!=null?_financialRecoveryScreen():
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
      // The first verified Home paints its complete values together; do
      // not make the dashboard fade in for an extra quarter-second.
      duration:tab==0&&!accountOpened?Duration.zero:
       waffraMotion(accountOpened?340:240),curve:Curves.easeOutCubic,
      builder:(ctx,progress,child)=>Opacity(opacity:progress,
       child:Transform.translate(offset:Offset((1-progress)*(waffraIsEnglish?26:-26),0),
        child:Transform.scale(scale:accountOpened?0.985+0.015*progress:1,child:child))),
      child:currentTab()))),
   ]),
  // A fixed 58x58 FAB: pop-up menu is an independent body overlay.
  // Never allow a menu width to change Scaffold's floating geometry.
  floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish),
  floatingActionButtonAnimator:const WaffraStationaryFabAnimator(),
  floatingActionButton:!ready||accountOpened||tab==2?null:CompositedTransformTarget(
   link:_fabOverlayAnchor,child:SizedBox(
   width:58,height:58,
   child:
    Material(
      color:forest,elevation:7,
     shadowColor:Colors.black26,
     shape:const CircleBorder(),
     child:InkWell(
      customBorder:const CircleBorder(),
      onTap:(){
     if(!_acceptFabTap())return;
     HapticFeedback.lightImpact();
     // M474: open immediately, with no 275ms artificial delay.
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
   )),
  // M675: footer height stays invariant. The global + is unchanged.
  // Notice is composited BESIDE its existing anchor, never inside the footer.
  bottomNavigationBar:accountOpened?null:WaffraFooterNavigation(
   selectedIndex:tab,
   english:waffraIsEnglish,
   onSelected:WaffraHaptics.selectionRequired((selected){
    waffraDismissFooterNotice();
    unawaited(selectFooter(selected));
   }),
  ),
  ),
  if(!accountOpened&&tab!=2)
   WaffraApprovedFixedFabNoticePosition(
    key:const Key('m675-snackbar-beside-unchanged-fab'),
    link:_fabOverlayAnchor,english:waffraIsEnglish,
    child:WaffraFooterNoticeHost(onNoticePresented:(){
     if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
    }),
   ),
  if(!accountOpened&&tab==2)
   PositionedDirectional(start:12,end:12,bottom:90,
    child:WaffraFooterNoticeHost()),
  if(addFabExpanded&&!accountOpened)...[
   Positioned.fill(
    key:const Key('waffra-fullscreen-fab-blur'),
    child:GestureDetector(
      behavior:HitTestBehavior.opaque,
      onTap:WaffraHaptics.tap(()=>setState(()=>addFabExpanded=false)),
      // M636: true blur composited only while '+' is expanded.
      child:ClipRect(child:BackdropFilter(
       filter:ui.ImageFilter.blur(sigmaX:6,sigmaY:6),
       child:ColoredBox(color:Colors.black.withValues(alpha:.22))))),
   ),
    if(addFabExpanded&&!accountOpened&&(tab==0||tab==1||tab==3||tab==4||goalsOpened))
     WaffraFabMenuAnchor(
      english:waffraIsEnglish,
      expanded:addFabExpanded,
      link:_fabOverlayAnchor,
      menu:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:waffraIsEnglish?CrossAxisAlignment.end:CrossAxisAlignment.start,
       children:[
        if(tab==0&&!goalsOpened)...[
        _addMenuOption(
         icon:Icons.edit_note_rounded,
         label:waffraIsEnglish?'Add manual transaction':'إضافة عملية يدوية',
         onTap:WaffraHaptics.tapRequired((){
          unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true));
         })),
        ]else if(goalsOpened||tab==3)...[
         _addMenuOption(icon:Icons.add_circle_outline_rounded,
          label:waffraIsEnglish?'New savings goal':'إضافة هدف جديد',
          onTap:WaffraHaptics.tapRequired((){
           unawaited(_launchAddAction(()=>goalDialog(),fromMenu:true));
          })),
         if(goals.isNotEmpty)...[
          const SizedBox(height:7),
          _addMenuOption(icon:Icons.copy_all_outlined,
           label:waffraIsEnglish?'Duplicate an existing goal':'تكرار هدف موجود',
           onTap:WaffraHaptics.tapRequired((){
            unawaited(_launchAddAction(_duplicateGoalFromMenu,fromMenu:true));
           })),
         ],
        ]else if(tab==4)...[
         _addMenuOption(icon:Icons.event_repeat_rounded,
          label:waffraIsEnglish?'New recurring transaction':'إضافة عملية متكررة',
          onTap:WaffraHaptics.tapRequired((){
           unawaited(_launchAddAction(()=>recurringDialog(),fromMenu:true));
          })),
         if(recurring.isNotEmpty)...[
          const SizedBox(height:7),
          _addMenuOption(icon:Icons.copy_all_outlined,
           label:waffraIsEnglish?'Duplicate recurring transaction':'تكرار عملية متكررة موجودة',
           onTap:WaffraHaptics.tapRequired((){
            unawaited(_launchAddAction(_duplicateRecurringFromMenu,fromMenu:true));
           })),
         ],
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
   Positioned.fill(
    child:Align(alignment:Alignment.topLeft,
     child:CompositedTransformFollower(
      link:_fabOverlayAnchor,showWhenUnlinked:false,
      targetAnchor:Alignment.topLeft,followerAnchor:Alignment.topLeft,
      child:Material(color:forest,elevation:7,shape:const CircleBorder(),
       child:InkWell(key:const Key('waffra-fab-menu-close'),
        onTap:WaffraHaptics.tap(()=>setState(()=>addFabExpanded=false)),
        customBorder:const CircleBorder(),
        child:const SizedBox(width:58,height:58,
         child:Icon(Icons.close_rounded,color:Colors.white,size:28)))))),
   ),
  ],
  // Outside Scaffold so the loading status never rebuilds the finance list.
  Positioned.fill(child:WaffraSmoothConfirmationOverlay(
   controller:_saveProgress,english:waffraIsEnglish)),
  ]));
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
  required this.link,
 });
 final bool english,expanded;
 final Widget menu;
 final LayerLink link;
 /// Follow the actual FAB's position, including the footer and system inset.
 @override Widget build(BuildContext context)=>Positioned.fill(
  child:Align(alignment:Alignment.topLeft,
   child:CompositedTransformFollower(
    link:link,showWhenUnlinked:false,
    targetAnchor:english?Alignment.topRight:Alignment.topLeft,
    followerAnchor:english?Alignment.bottomRight:Alignment.bottomLeft,
    offset:const Offset(0,-12),
    child:IgnorePointer(
     ignoring:!expanded,
     child:AnimatedSwitcher(
      duration:waffraMotion(280),
      reverseDuration:waffraMotion(220),
      switchInCurve:Curves.easeOutCubic,
      switchOutCurve:Curves.easeInCubic,
      child:expanded?
       KeyedSubtree(key:const ValueKey('waffra-fab-menu-open'),child:menu):
       const SizedBox(key:ValueKey('waffra-fab-menu-closed')),
     )),
   )),
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
/// Accessible 48×48 tap target that keeps the approved 36×30 badge artwork.
/// Uses the existing receipt viewer and never reads or rewrites saved files.
class WaffraReceiptCornerAction extends StatelessWidget {
 const WaffraReceiptCornerAction({
  super.key,required this.count,required this.english,required this.onTap,
 });
 final int count;
 final bool english;
 final VoidCallback onTap;
 @override Widget build(BuildContext context)=>Semantics(
  button:true,
  label:english?'View $count attachments':'عرض $count مرفقات',
  child:Tooltip(
   message:english?'View attachments':'عرض المرفقات',
   child:Material(type:MaterialType.transparency,
    child:InkWell(
     onTap:WaffraHaptics.tap(onTap),
     child:SizedBox(width:48,height:48,
      child:Align(alignment:AlignmentDirectional.topStart,
       child:WaffraReceiptCornerBadge(count:count,english:english))),
    ))));
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
  final label=waffraEntryReportCategory(e);
  byCategory[label]=(byCategory[label]??0)+e.amount;
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