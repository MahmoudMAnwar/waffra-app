import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_recurring_account_groups.dart';

void main() {
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
    final src=File('lib/main.dart').readAsStringSync();
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
    expect(authority,contains('reviewedSmsReceiptImages: reviewedSmsReceiptImages'));
    expect(authority,contains('Bank SMS receipts require verified encrypted storage.'));
    expect(writer,contains("confirmedRecords.single['sourceType'] == 'sms'"));
  });

  test('M506 native bank sender aliases preserve OTP and consented review', () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    expect(native,contains('الإنماء|الانماء'));
    expect(native,contains('الراجحي'));
    expect(native,contains('otp.containsMatchIn(safe)'));
    expect(native,contains('fun qualifies(sender: String, body: String)'));
    expect(native,contains('if (queued >= maxCandidates) return 0'));
  });
}
