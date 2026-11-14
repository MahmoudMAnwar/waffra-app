import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  const valid = 'حوالة داخلية\n'
      'من حساب: **8308\n'
      'إلى حساب: **9288\n'
      'المبلغ: 135.00 SAR\n'
      'رسوم مستقطعة: 0.58 SAR';

  test('M470 #13: internal transfer principal and separate SAR fee', () {
    final facts = WaffraBankSmsFactsParser.parse(valid);
    expect(facts.kind, WaffraBankOperationKind.transfer);
    expect(facts.sourceSuffix, '8308');
    expect(facts.destinationSuffix, '9288');
    expect(facts.fee, 0.58);
    final verified = WaffraSmsCurrencies.originalAmount(valid);
    expect(verified, isNotNull);
    expect(verified!.currency, 'SAR');
    expect(verified.amount, 135);
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(valid), isFalse);
  });

  test('M470 #13: fee or unsupported original currency never makes SAR principal', () {
    const onlyFee = 'حوالة داخلية\n'
        'المبلغ: 135.00\nرسوم مستقطعة: 0.58 SAR';
    expect(WaffraSmsCurrencies.originalAmount(onlyFee), isNull);
    const foreign = 'حوالة داخلية\n'
        'المبلغ: 135.00 USD\nرسوم مستقطعة: 0.58 SAR';
    expect(WaffraSmsCurrencies.originalAmount(foreign)?.currency, 'USD');
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(foreign), isTrue);
  });

  test('M470 #19: subcategory is resolved only under chosen parent', () {
    final root1=BudgetCategory(id:'r1',name:'المواصلات',
      icon:'directions_car',color:0xFF087A54,income:false);
    final root2=BudgetCategory(id:'r2',name:'السكن',
      icon:'home',color:0xFF087A54,income:false);
    final leaf1=BudgetCategory(id:'s1',name:'أخرى',icon:'category',
      color:0xFF087A54,income:false,parentId:'r1');
    final leaf2=BudgetCategory(id:'s2',name:'أخرى',icon:'category',
      color:0xFF087A54,income:false,parentId:'r2');
    final values=[root1,root2,leaf1,leaf2];
    expect(waffraManualCategoryChildren(values,false,'r1'),[leaf1]);
    expect(waffraManualCategoryChildren(values,false,'r2'),[leaf2]);
    expect(waffraCanAssignManualCategory(values,false,'r1','أخرى'),isTrue);
  });

  test('M470 #18: first SMS tap opens selected review without PopScope veto', () {
    final app=readWaffraMainSourceForContracts();
    final inbox=app.substring(app.indexOf(' Future<void> _openAutoSmsInbox()'),
        app.indexOf(' Widget _autoSmsReviewCard()'));
    expect(inbox,contains('openingReviewId'));
    expect(inbox,contains('canPop:selectedSender==null||openingReviewId!=null'));
    expect(inbox,contains('refresh(()=>openingReviewId=id);'));
    // #410/#409: keep the inbox mounted so Back returns one screen,
    // without requiring a now-removed pop-and-reopen route.
    expect(inbox,contains('await _reviewAutoSmsCandidates(targetId:id);'));
    expect(inbox,contains('finally{'));
    expect(inbox,contains('openingReviewId=null;'));
    expect(inbox,isNot(contains('Navigator.pop(ctx,id);')));
  });

  test('M470 #19: post-back subcategory must be current parent-scoped', () {
    final app=readWaffraMainSourceForContracts();
    final editor=app.substring(app.indexOf(' Future<void> entrySheet('),
      app.indexOf(' Future<void> showReceipt('));
    expect(editor,contains("Key('m470-entry-subcategory-picker')"));
    expect(editor,contains('final selectedParentAtTap=selectedParentId;'));
    expect(editor,contains(
        'waffraManualCategoryChildren(categories,income,selectedParentAtTap)'));
    expect(editor,contains('selectedParentId!=selectedParentAtTap'));
    expect(editor,contains('.where((c)=>c.name==picked).toList()'));
  });

  test('M470 #13: transfer review never relies on fee-bearing BankParser amount', () {
    final app=readWaffraMainSourceForContracts();
    final transfer=app.substring(
      app.indexOf(' Future<void> _reviewSmsAccountTransfer('),
      app.indexOf(' Future<void> _reviewAutoSmsCandidates('));
    expect(transfer,contains('WaffraSmsCurrencies.originalAmount(body)'));
    expect(transfer,contains("sourceAmount.currency!='SAR'"));
    expect(transfer,contains('amountMinor:verifiedMinor'));
    expect(transfer,isNot(contains('parsed.amount')));
    expect(transfer,contains('facts.fee'));
    expect(transfer,contains('await api.transfer('));
  });

 test('M470 currency guard preserves valid bank بSR and بـSAR amounts', () {
  const examples = <(String, double)>[
   ('حوالة داخلية واردة بSR 15.50\\nل9001\\nمن9002', 15.5),
   ('حوالة داخلية صادرة بSR 60\\nمن9001\\nل9004', 60),
   ('شراء PoS\\nبSAR 74\\nمتجر', 74),
   ('شراء PoS\\nبـSAR 20', 20),
   ('شراء PoS\\nبـ84.72SR', 84.72),
  ];
  for (final entry in examples) {
   final raw=entry.$1.replaceAll(r'\n','\n');
   expect(WaffraSmsCurrencies.originalAmount(raw)?.amount, entry.$2,
     reason: 'Valid bank currency prefix must survive strict lexer: $raw');
   expect(BankParser.parse(raw).amount, entry.$2,
     reason: 'Currency-prefixed bank SMS must remain recognized: $raw');
  }
  expect(WaffraSmsCurrencies.originalAmount(
    '500 رسالة بنكية\\nرسوم مستقطعة: 0.58 SAR'),isNull);
 });
}
