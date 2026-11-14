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
part 'waffra_home_sms_inbox.part.dart';
part 'waffra_home_sms_rules.part.dart';
part 'waffra_home_sms_refresh.part.dart';
part 'waffra_home_finance_startup.part.dart';
part 'waffra_home_sms_confirmation.part.dart';
part 'waffra_home_verified_account_flows.part.dart';
part 'waffra_home_finance_persistence_due.part.dart';
part 'waffra_home_transaction_ledger_actions.part.dart';
part 'waffra_home_transaction_cards.part.dart';
part 'waffra_home_verified_refresh.part.dart';
part 'waffra_home_compact_activity_cards.part.dart';
part 'waffra_home_finance_recovery.part.dart';
part 'waffra_home_transaction_summary.part.dart';
part 'waffra_home_widget_sync.part.dart';
part 'waffra_home_sms_management.part.dart';
part 'waffra_home_category_receipt_dialogs.part.dart';
part 'waffra_home_budget_alert_charts.part.dart';
part 'waffra_home_verified_finance_pickers.part.dart';
part 'waffra_home_navigation_helpers.part.dart';
part 'waffra_home_sms_review_indicator.part.dart';
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
 // M760: unchanged verified-account refresh, selection, transfer and account filter methods moved to registered Home part.
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

 // M741: original local SMS rule and learning methods moved to registered same-library part.
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
 // M742: original native SMS inbox refresh and offline classification moved to registered part.
 // M783: original SMS settings, exclusions and local notification actions moved to registered Home part.
 // M739: original sender-grouped bank SMS inbox dialog moved to same-library part.
 // M835: existing bank SMS review indicator card moved unchanged to registered Home part.
 /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.
 // M703: implementation moved byte-identically to registered Home part.
 /// M593: even with JSON decoded on a worker isolate, creating thousands
 /// of MoneyEntry models synchronously can stall the progress animation.
 /// Convert bounded chunks and yield to the next Flutter event loop frame
 /// without publishing partial/unverified ledger state to Home.
 // M770: original verified SMS review confirmation and entry batching moved to same-library part.
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
 // M791: original fail-closed Home finance startup and recovery UI in registered part.
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
 // M840: original verified Home/Widget synchronization now in registered Dart part.
 Future<void>? _m474PullRefreshInFlight;
 // M782: verified pull-to-refresh and finance reload moved to registered Home part.
 // M750: verified Home financial startup load lives in registered same-library part.
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
 // M762: verified finance persistence and recurring due/postponement methods moved unchanged to registered Home part.
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
 // M812: verified SMS money-account and optional budget pickers moved to real registered Home part.
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
 // M795: Home category selector and protected receipt dialogs moved to registered Dart part.
 // M805: original Home budget alerts and chart SVG methods moved to registered part.
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
 // M810: original Home income/expense transaction summary now in registered part.
 Future<void> showInternalTransferTransactions()async{
  await _m647ShowInternalTransfers();
 }
 /// Parent institution is a visual attribute of a *verified* child account.
 /// Never treat the provider catalog as authorization to post money.
 // M733: verified transfer and savings card UI moved to registered same-library part.
 // M790: original compact financial activity cards live in registered Home part.
 // M830: original Home navigation and summary helpers moved to registered same-library part.
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