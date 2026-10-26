import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main() {
  test('new installs start in light mode while an explicit choice persists', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("String appearance='light';"));
    expect(source, contains(
      "appearance=p.getString('waffra_appearance_mode_v1')??"));
    expect(source, contains(
      "if(!{'light','dark','system'}.contains(appearance))appearance='light';"));
  });

  test('AR/EN changes direction instantly without whole-page slide or Navigator replacement', () {
    final source=File('lib/main.dart').readAsStringSync();
    final root=source.substring(source.indexOf('builder:(context,child)=>ValueListenableBuilder<bool>('),
      source.indexOf('theme:ThemeData(',source.indexOf('builder:(context,child)=>ValueListenableBuilder<bool>(')));
    expect(root,contains("textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr"));
    expect(root,isNot(contains('KeyedSubtree(key:ValueKey(language)')));
    expect(root,isNot(contains('SlideTransition(')));
    expect(root,isNot(contains('AnimatedSwitcher(')));
    expect(source,contains('floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
  });

  test('replayable tour only includes six core screens', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('static const tourTabs=<int>[0,0,0,1,2,3];'));
    expect(source, contains('static const tourTargetKeys=<int>[-1,0,1,2,6,4];'));
    final tour = source.substring(source.indexOf('Widget tourOverlay()=>'),
      source.indexOf('Future<void> changePin()', source.indexOf('Widget tourOverlay()=>')));
    expect(tour, isNot(contains('التحليل المالي الذكي')));
    expect(tour, isNot(contains('حسابي وإعداداتي')));
    expect(tour, contains(r"'${tourStep+1}/${tourTabs.length}'"));
  });

  test('SMS content remains in memory for encrypted source, legacy bridge redacts plaintext', () {
    final home = File('lib/main.dart').readAsStringSync();
    final widget = File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    expect(home, contains("date:bankSmsDate(raw)??DateTime.now(),notes:raw,sourceType:'sms'"));
    expect(home, contains('date:now,notes:messages[index],sourceType:'));
    expect(home, contains('notes:sms?message.text:notes.text'));
    expect(widget, contains('notes:entry.raw,sourceType:'));
    expect(widget, contains('waffraSafeSmsTransactionTitle(parsed.title,entry.raw'));
    expect(home, contains('child:SelectableText(entry.notes'));
    final authority=File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    expect(authority,contains("return Map<String, Object?>.unmodifiable({...record, 'notes': ''});"));
    expect(authority,contains('records: redacted, messageHashes: fingerprints'));
    final legacy=File('lib/storage/waffra_home_finance_persistence.dart').readAsStringSync();
    expect(legacy,contains('WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)'));
  });

  test('FAB launch waits for the menu collapse and suppresses double taps', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(_addActionOpening)return;'));
    expect(source, contains('if(fromMenu)await Future<void>.delayed(waffraMotion(260));'));
    expect(source, contains('if(!_acceptFabTap())return;'));
    expect(source, contains('splashFactory:NoSplash.splashFactory'));
    expect(source, contains('key:_tourKeys[1]'));
    expect(source, contains('final tappedTab=tab;'));
    expect(source, contains('scale:_fabPressed?0.96:1.0'));
    expect(source, contains('await Future<void>.delayed(waffraMotion(165));'));
    expect(source, contains('duration:waffraMotion(320)'));
    expect(source, contains('await Future<void>.delayed(waffraMotion(110));'));
    expect(source, contains('duration:waffraMotion(220)'));
    expect(source, contains('now.difference(_lastFabTapAt!)<const Duration(milliseconds:380)'));
    expect(source, contains("ValueKey('waffra-fab-menu-open')"));
    expect(source, contains("ValueKey('waffra-fab-menu-closed')"));
    expect(source, contains('showWaffraSmoothDialog<SavingGoal>'));
    expect(source, contains('child:const Icon(Icons.add,color:Colors.white,size:28)'));
    expect(source, isNot(contains('child:Icon(addFabExpanded?Icons.close:Icons.add')));
  });

  testWidgets('details show entire notes and keep concise name', (tester) async {
    const raw = 'عملية شراء\nبمبلغ 84.72 ريال\nتاريخ 2026/10/24\nمرجع ABC123\nرصيد متبقٍ 900 ريال';
    final entry = MoneyEntry(
      id:'m206-test', title:'شراء - متجر', category:'تسوق', amount:84.72,
      income:false, date:DateTime(2026,10,24), notes:raw, sourceType:'sms');
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:WaffraTransactionDetailsDialog(
        entry:entry, onClose:(){},
      )),
    ));
    expect(find.text('شراء - متجر'),findsWidgets);
    expect(find.text(raw),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  test('synthetic English Saudi bank batch: 56 confirmed, 13 excluded notices', () {
    // No actual bank account, card, sender name, OTP or real transaction.
    final samples=<String>[];
    for(var i=0;i<37;i++){
      samples.add('Purchase Card\nCard: **0000 MADA\nAmount: ${i+1}.25 SAR\n'
        'At: DEMO SHOP\nOn: 2026-10-24 18:53\nRemaining Balance: 13.38 SAR');
      if(i<16){
        samples.add('Online Purchase Card\nCard: **0000 MADA\n'
          'Amount: ${i+1}.75 SAR\nAccount:**0000\nAt: DEMO ONLINE\n'
          'On: 2026-10-23 20:32\nRemaining Balance: 55.38 SAR');
      }
      if(i<3){
        samples.add('Credit Transfer via Example Bank\nAmount: ${(i+1)*100} SAR\n'
          'From: SAMPLE SENDER\nIBAN: **0000\nDate: 2026-10-22 23:39');
      }
      if(i<4){
        samples.add('Online Pre-Auth\nCard: MADA 0000\nAmount: 8.57 SAR\n'
          'Account:**0000\nAt: DEMO RIDE\nOn: 2026-10-21 12:24');
      }
      if(i<8){
        samples.add('Please use the code:0000\nFor card:*0000\n'
          'Amount:1 SAR\nMerchant:DEMO\nOn:26-10-21 10:58');
      }
    }
    samples.add('Declined Transaction\nReason: Online purchases disabled');
    expect(samples.length,69);
    final chunks=splitBankMessages(samples.join('\n'));
    expect(chunks.length,69);
    expect(chunks.where((v)=>v.startsWith('Online Purchase Card')).length,16);
    final parsed=chunks.map(BankParser.parse).toList();
    final confirmed=parsed.where((v)=>v.amount!=null&&v.amount!>0).toList();
    expect(confirmed.length,56);
    expect(confirmed.where((v)=>v.income).length,3);
    expect(confirmed.where((v)=>!v.income).length,53);
    expect(parsed.where((v)=>v.amount==null).length,13);
    expect(confirmed.where((v)=>v.income).fold<double>(0,(sum,v)=>sum+v.amount!),600);
  });

  test('English bank credit versus debit never reverses transaction direction', () {
    const incoming=[
      'Credit Transfer via Example Bank\nAmount: 100 SAR\nFrom: SAMPLE SENDER\nIBAN: **0000\nDate: 2026-10-24 14:58',
      'Credit via local transfer\nVia:Sample Wallet\nAmount:SAR 1613.00\nFrom:SAMPLE SENDER\nAccount:**0000\nOn:2026-10-03 00:29',
      'Incoming Transfer\nAmount: 20 SAR',
      'Transfer Received\nAmount: 42 SAR',
      'Cash Deposit\nAmount: 50 SAR',
      'Salary Credit\nAmount: 500 SAR',
      'Refund Received\nAmount: 9 SAR',
    ];
    const outgoing=[
      'Purchase Card\nAmount: 42 SAR\nAt: DEMO STORE',
      'Online Purchase Card\nAmount: 15.50 SAR\nAt: DEMO STORE',
      'Credit Card Purchase\nAmount: 12 SAR',
      'Debit Transfer\nAmount: 100 SAR\nTo: SOMEONE',
      'Outgoing Transfer\nAmount: 7 SAR',
      'Transfer Sent\nAmount: 6 SAR',
      'ATM Withdrawal\nAmount: 20 SAR',
      'Bill Payment\nAmount: 30 SAR',
    ];
    for(final sms in incoming){
      final parsed=BankParser.parse(sms);
      expect(parsed.amount,greaterThan(0),reason:sms.split('\n').first);
      expect(parsed.income,isTrue,reason:sms.split('\n').first);
    }
    for(final sms in outgoing){
      final parsed=BankParser.parse(sms);
      expect(parsed.amount,greaterThan(0),reason:sms.split('\n').first);
      expect(parsed.income,isFalse,reason:sms.split('\n').first);
    }
    for(final sms in [
      'Online Pre-Auth\nAmount: 8.57 SAR\nAt: DEMO TAXI',
      'Please use the code:0000\nAmount: 1 SAR\nMerchant: DEMO',
      'Declined Transaction\nAmount: 21 SAR',
      'Transaction Failed\nAmount: 31 SAR',
      'Purchase Card\nAmount: 1 SAR\nStatus: Declined',
      'Amount: 3 SAR',
    ]){
      expect(BankParser.parse(sms).amount,isNull,reason:sms.split('\n').first);
    }
  });

  test('English dates and merchant categories stay safe and accurate', () {
    expect(bankSmsDate('Purchase Card\nOn: 2026-10-24 18:53'),
      DateTime(2026,10,24,18,53));
    expect(bankSmsDate('Credit Transfer\nDate: 2026-10-22 23:39'),
      DateTime(2026,10,22,23,39));
    expect(bankSmsDate('شراء POS\n24/10/26 18:53'),
      DateTime(2026,10,24,18,53));
    expect(bankSmsDate('Purchase Card\nOn: 2026-13-45 18:53'),isNull);
    const sms='Online Purchase Card\nAmount: 31.47 SAR\n'
      'Account:**0000\nAt: Noon\nOn: 2026-10-21 18:44';
    expect(waffraMerchantName(sms), 'Noon');
    expect(waffraRecognizedMerchantLeaf('LULU HYPER TEST',income:false),
      'بقالة وتموين / سوبرماركت');
    expect(waffraRecognizedMerchantLeaf('ALNAHDI PHARMACY',income:false),
      'صحة / صيدلية وأدوية');
    // A synthetic terminal suffix is not part of the merchant identity.
    expect(waffraMerchantName('Purchase Card\nAmount: 16.27 SAR\n'
      'At: ALNAHDI PHARMACY9999'),'ALNAHDI PHARMACY');
    expect(waffraRecognizedMerchantLeaf('Marakez Medical',income:false),
      'صحة / عيادات');
    expect(waffraRecognizedMerchantLeaf('Keeta',income:false),
      'مطاعم وكافيهات / توصيل الطعام');
    expect(waffraRecognizedMerchantLeaf('Jeeny',income:false),
      'مواصلات / تاكسي');
    expect(waffraRecognizedMerchantLeaf('Noon',income:false),
      'تسوّق / تسوق إلكتروني');
    expect(waffraMerchantName('Credit Transfer via Example Bank\n'
      'Amount: 100 SAR\nFrom: SAMPLE SENDER\nIBAN: **0000',income:true),
      'SAMPLE SENDER');
    expect(waffraMerchantName('Purchase Card\nAmount: 5 SAR\nAt: Account **0000'),
      isNull);
    expect(BankParser.parse(sms).amount,31.47);
  });
  test('same clipboard content is reanalyzed with new/duplicate counts', () {
    const sampleA='Purchase Card\nAmount: 15 SAR\nAt: DEMO A\nOn: 2026-10-24 10:10';
    const sampleB='Online Purchase Card\nAmount: 20 SAR\nAt: DEMO B\nOn: 2026-10-24 11:10';
    const pasted='$sampleA\n$sampleB';
    final first=waffraSummarizeBankPaste(pasted,<String>{});
    expect(first.detected,2);
    expect(first.fresh,2);
    expect(first.duplicates,0);
    final savedHashes=<String>{bankSmsHash(sampleA)};
    final second=waffraSummarizeBankPaste(pasted,savedHashes);
    expect(second.detected,2);
    expect(second.fresh,1);
    expect(second.duplicates,1);
    final repeatedAgain=waffraSummarizeBankPaste(pasted,savedHashes);
    expect(repeatedAgain.detected,2);
    expect(repeatedAgain.fresh,1);
    expect(repeatedAgain.duplicates,1);
    expect(waffraSummarizeBankPaste('Online Pre-Auth\nAmount: 8 SAR',savedHashes).detected,0);
  });

}
