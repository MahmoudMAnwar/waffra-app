import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_recurring_account_groups.dart';

void main() {
  test('M506 Android bank SMS state reads never decrypt on main thread', () {
    final native=File('native/WaffraMainActivity.kt').readAsStringSync();
    final messageHandler=native.substring(
      native.indexOf('messageChannel?.setMethodCallHandler {'),
      native.indexOf('"importConsentMonthBankSms" ->'));
    expect(messageHandler,contains(
      '"autoSmsEnabled", "autoSmsTrackingStatus", "autoSmsScanProgress" -> {'));
    expect(messageHandler,contains('smsHistoryExecutor.execute {'));
    expect(messageHandler,contains('WaffraAutoSmsStore.scanProgress(app)'));
    expect(messageHandler,contains('runOnUiThread { result.success(response) }'));
    expect(messageHandler,
      isNot(contains('result.success(WaffraAutoSmsStore.scanProgress(this))')));
  });

  test('M506 widget-resume large finance decode uses the isolate threshold', () {
    final src=readWaffraMainSourceForContracts();
    final sync=src.substring(src.indexOf(' Future<void> _syncWidgetTransactions()async{'),
      src.indexOf(' Future<void> _refreshAndSettle('));
    expect(sync,contains('WaffraLargeJsonDecode.parse(raw)'));
    expect(sync,isNot(contains('(jsonDecode(raw) as List)')));
    expect(sync,contains('loadedFinance.finance.requireIntegrity()'));
  });


  testWidgets('M506 splash animation settles within 1.9 seconds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WaffraLaunchIntro()));
    // A frame-based widget regression guard for the launch animation. Real
    // frame jank and startup I/O still require Android profile tracing.
    final frames=await tester.pumpAndSettle(
      const Duration(milliseconds:100));
    expect(frames,lessThanOrEqualTo(19));
    expect(tester.takeException(),isNull);
  });

  test('M506 SMS original stays independent from personal notes across JSON and category edits', () {
    final record=MoneyEntry(
      id:'m506-sms-demo',title:'شحن الجوال',category:'فواتير / جوال',
      amount:276,income:false,date:DateTime(2026,11,5),
      sourceType:'sms',notes:'شحن الجوال مبلغ 276 ريال إلى **8308',
      personalNotes:'ملاحظتي الخاصة');
    final persisted=MoneyEntry.fromJson(record.toJson());
    expect(persisted.notes,record.notes);
    expect(persisted.personalNotes,'ملاحظتي الخاصة');
    expect(persisted.withCategory('فواتير / موبايل').personalNotes,
      'ملاحظتي الخاصة');
    expect(persisted.withBudget('budget-1').notes,record.notes);
    final map=Map<String,dynamic>.from(record.toJson())..remove('personalNotes');
    final historical=MoneyEntry.fromJson(map);
    expect(historical.personalNotes,isEmpty);
    expect(historical.notes,record.notes);
  });

  testWidgets('M506 legacy SMS is source-only, not a personal note',
      (tester) async {
    final historical=MoneyEntry(
      id:'old',title:'شحن جوال',category:'جوال',amount:276,
      income:false,date:DateTime(2026,11,5),
      sourceType:'sms',notes:'رسالة بنكية تجريبية مبلغ 276 ريال');
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:WaffraTransactionDetailsDialog(entry:historical,onClose:(){}))));
    expect(find.byKey(const Key('waffra-transaction-personal-notes'),
      skipOffstage:false),findsNothing);
    final original=find.byKey(
      const Key('waffra-transaction-protected-bank-sms'),skipOffstage:false);
    expect(original,findsOneWidget);
    expect(tester.widget<SelectableText>(original).data,historical.notes);
    expect(find.textContaining('التخزين المشفّر'),findsNothing);
  });

  test('M506 known providers exist without fabricated money accounts', () {
    const accounts=[
      WaffraAccountBalance('i-1','الإنماء الجاري','bank',10000,false,
        providerId:'inma'),
      WaffraAccountBalance('r-1','الراجحي','bank',2000,false,
        providerId:'rajhi'),
    ];
    final groups=WaffraRecurringAccountGroups.withBankProviderChoices(accounts);
    expect(groups.where((p)=>p.id=='bank:institution:inma')
      .single.accounts.single.id,'i-1');
    expect(groups.where((p)=>p.id=='bank:institution:other')
      .single.accounts,isEmpty);
    expect(groups.where((p)=>p.id=='bank:institution:bilad'),hasLength(1));
  });

  test('M506 SMS receipt, rule learning and transfer require confirmed verified source', () {
    final src=readWaffraMainSourceForContracts();
    final authority=File('lib/storage/waffra_verified_finance_authority.dart')
      .readAsStringSync();
    final writer=File('lib/storage/waffra_unified_finance_writer.dart')
      .readAsStringSync();
    final editor=src.substring(src.indexOf(' Future<void> entrySheet('),
      src.indexOf(' Future<void> showReceipt('));
    expect(editor,contains('reviewedSmsReceiptImages:smsReceiptImages.isEmpty?'));
    expect(editor,contains("smsRecord['receiptPath']=null;"));
    expect(editor,contains('try{await _learnManualCategoryPreference(result);}catch(_){}'));
    expect(editor,contains("key:const Key('m506-transfer-date')"));
    expect(editor,contains('final latest=await transferApi!.balances();'));
    expect(editor,contains('occurredIso:transferDate.toIso8601String(),'));
    // Verified authority forwards the SMS receipt bytes to the unified
    // encrypted transaction writer's existing manualReceiptImages argument.
    expect(authority,contains('manualReceiptImages: reviewedSmsReceiptImages'));
    expect(authority,contains('encryptedSession!.appendConfirmed('));
    expect(authority,contains('Bank SMS receipts require verified encrypted storage.'));
    expect(writer,contains("confirmedRecords.single['sourceType'] == 'sms'"));
  });

  test('M506 local sign-out recovery requires fingerprint and never overwrites a verifier', () {
    final src=readWaffraMainSourceForContracts();
    final logout=src.substring(src.indexOf(' Future<void> logout()async {'),
      src.indexOf(' Future<void> setPin('));
    final registration=src.substring(src.indexOf(' Future<void> saveUser(Person u)async {'),
      src.indexOf(' Future<void> setUiCountry('));
    expect(logout,contains('WaffraLocalPhoneCredentials.probeForPhone('));
    expect(logout,contains('if(!hasLegacy){'));
    expect(logout,contains('WaffraLocalCredentialProbe.missing'));
    expect(logout,contains('return;'));
    expect(logout,contains('await _accountWriteAuthority.signOut();'));
    expect(logout,isNot(contains('_repairMissingLocalCredential(')));
    expect(logout,isNot(contains('WaffraLocalPhoneCredentials.registerOrResume(')));
    expect(src,isNot(contains('m506-recovery-password')));
    expect(registration,contains('phone_credential_not_persisted_for_profile'));
    expect(registration.indexOf('WaffraLocalPhoneCredentials.probeForPhone('),
      lessThan(registration.indexOf('await _accountWriteAuthority.saveProfile(')));
  });

  test('M506 native bank sender aliases preserve OTP and consented review', () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    expect(native,contains('الإنماء|الانماء'));
    expect(native,contains('الراجحي'));
    expect(native,contains('otp.containsMatchIn(safe)'));
    expect(native,contains('fun qualifies(sender: String, body: String)'));
    // The new historical importer checks the encrypted queue at entry and
    // inside the batch, preserving the cursor when 1000 review slots fill.
    expect(native,contains('private const val maxCandidates = 1000'));
    expect(native,contains('if (currentSize >= maxCandidates) return 0'));
    expect(native,contains('if (queue.length() >= maxCandidates)'));
    expect(native,contains('stoppedForCapacity = true'));
    expect(native,contains('.putLong(historyCursorAt, nextAt)'));
  });
}
