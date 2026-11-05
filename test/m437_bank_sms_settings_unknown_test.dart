import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M437 account bank SMS settings contain both requested features',(){
  final ui=File('lib/main.dart').readAsStringSync();
  final sms=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(ui,contains("'Bank SMS':'رسائل SMS البنكية'"));
  expect(ui,contains("'Scan previous SMS':'فحص رسائل SMS السابقة'"));
  expect(ui,contains("'Unrecognized SMS':'رسائل SMS غير معروفة'"));
  expect(ui,contains('_scanPreviousBankSmsFromSettings()'));
  expect(ui,contains('_openUnknownSmsFromSettings()'));
  expect(ui,contains('await WaffraAutoSms.importConsentMonth()'));
  expect(ui,contains('await WaffraAutoSms.scanUnknownFinancialSms()'));
  final newSettings=ui.substring(
   ui.indexOf('Future<void> _scanPreviousBankSmsFromSettings()'),
   ui.indexOf('Future<void> _openAutoSmsInbox()'));
  expect(newSettings,contains('if(!await WaffraAutoSms.enabled())'));
  expect(newSettings,isNot(contains('requestAutoSmsPermission')));
  expect(newSettings,isNot(contains('commitConfirmedSms(')));
  expect(sms,contains("'scanUnknownFinancialSms'"));
  expect(newSettings,contains('await _openAutoSmsInbox()'));
  expect(newSettings,contains('لا توجد رسائل بنكية حديثة'));
  expect(ui,contains("((item['body'] as String?)??'')"));
 });

 test('M437 Etimad debt notices are not monetary transactions',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final code=native.substring(native.indexOf('private val debtNotice'),
   native.indexOf('private fun id(sender: String, body: String, at: Long)'));
  expect(code,contains('مديونية'));
  expect(code,contains('مستحقة'));
  expect(code,contains('etimad'));
  expect(code,contains('name.firstOrNull()?.isLetter() == true'));
  expect(code,contains('return "debt_notice"'));
  expect(code,contains('otp.containsMatchIn(safe)'));
  expect(code,contains('qualifies(name, safe)'));
  // Read-only unknown-notice review can scan a larger, bounded history;
  // a separate import cursor pages confirmed bank-SMS history safely.
  expect(code,contains('maxRead: Int = 5000'));
  expect(code,contains('maxResults: Int = 500'));
  expect(code,contains('"date >= ? AND date < ?"'));
  expect(code,contains('installationMonthStart(context)'));
  expect(code,contains('"date DESC"'));
  expect(code,isNot(contains('cloud')));
  expect(code,isNot(contains('offer(context')));
  expect(code,isNot(contains('commitConfirmedSms(')));
 });

 test('M437 unknown notice screen shows original and manual-only action',(){
  final view=File('lib/waffra_unknown_financial_sms_page.dart')
   .readAsStringSync();
  final main=File('lib/main.dart').readAsStringSync();
  expect(view,contains("Key('waffra-unknown-sms-list')"));
  expect(view,contains("Key('waffra-unknown-sms-create-manual')"));
  expect(view,contains('إشعار مديونية'));
  expect(view,contains('ليست معاملة مالية مكتملة'));
  expect(view,contains('onCreateManual'));
  expect(main,contains('onCreateManual:()async{if(mounted)await entrySheet();}'));
  expect(view,isNot(contains('BankParser.parse(')));
  expect(view,isNot(contains('WaffraSmsCloudService')));
  expect(view,isNot(contains('commitConfirmedSms(')));
 });

 test('M437 Native Android scan is read-only and uses one-time consent',(){
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  // Keep the expensive Android provider scan off the UI thread, then
  // report the read-only result on Android's UI thread.
  expect(activity,contains('"scanUnknownFinancialSms" -> {'));
  expect(activity,contains('smsHistoryExecutor.execute {'));
  expect(activity,contains('runOnUiThread { result.success(found) }'));
  // The worker must use applicationContext rather than a captured Activity.
  expect(activity,contains('val app = applicationContext'));
  expect(activity,contains('WaffraAutoSmsStore.scanUnknownFinancialSms(app)'));
  expect(bridge,contains('static Future<List<Map<String,Object?>>> scanUnknownFinancialSms()'));
  expect(bridge,contains('if(!Platform.isAndroid||!await enabled())return const [];'));
  final scan=store.substring(store.indexOf('fun scanUnknownFinancialSms('),
   store.indexOf('private fun id(sender: String, body: String, at: Long)'));
  expect(scan,contains('if (!enabled(context)'));
  expect(scan,contains('installationMonthStart(context)'));
  expect(scan,contains('System.currentTimeMillis() + 1'));
  expect(scan,isNot(contains('getLong(activationMonth')));
  expect(scan,contains('content://sms/inbox'));
  expect(scan,isNot(contains('save(context')));
  expect(scan,isNot(contains('seal(')));
  expect(scan,isNot(contains('OPENROUTER')));
 });
 test('M437 history cutoff is original install month, scan remains resumable',(){
  final code=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final begin=code.indexOf('fun importConsentMonth(');
  final end=code.indexOf('fun claimReviewNotification(',begin);
  final history=code.substring(begin,end);
  expect(code,contains('getPackageInfo(context.packageName, 0).firstInstallTime'));
  expect(code,contains('set(Calendar.DAY_OF_MONTH, 1)'));
  expect(history,contains('installationMonthStart(context)'));
  expect(history,contains('historySourceMonth'));
  expect(history,contains('date ASC, _id ASC'));
  expect(history,isNot(contains('prefs.getBoolean(historyComplete, false)')));
  expect(history,isNot(contains('getLong(activationMonth')));
  expect(history,isNot(contains('commitConfirmedSms(')));
 });
}
