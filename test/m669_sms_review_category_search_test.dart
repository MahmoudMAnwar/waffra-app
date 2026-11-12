import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
    BudgetCategory, waffraResolveSmsReviewCategory;
import 'package:waffra/waffra_centered_dropdown.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

/// Owner issue #600: a root like "تحويلات" must never appear as a leaf,
/// and choosing a verified account alone must never post a bank SMS.
void main() {
  BudgetCategory category(String id,String name,{
    bool income=false,String parentId='',bool active=true,
  })=>BudgetCategory(id:id,name:name,parentId:parentId,
    income:income,icon:'category',color:0xFF087A54,
    categoryActive:active);

  final catalog=<BudgetCategory>[
    category('transfers','تحويلات'),
    category('local','حوالات محلية',parentId:'transfers'),
    category('people','تحويل لأفراد',parentId:'transfers'),
    category('shopping','تسوّق'),
    category('online','تسوق إلكتروني',parentId:'shopping'),
    category('incoming','حوالات واردة',income:true),
    category('incoming-local','حوالة محلية',
      parentId:'incoming',income:true),
    category('salary','راتب',income:true),
    category('salary-basic','راتب أساسي',
      parentId:'salary',income:true),
    category('paused','قسم متوقف',active:false),
    category('paused-child','فرعي متوقف',parentId:'paused'),
  ];

  test('M669 root-only transfer hint is a main suggestion, never a leaf', () {
    final r=waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'تحويلات');
    expect(r.parent?.name,'تحويلات');
    expect(r.leaf,isNull);
    final chosen=waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'تحويلات / حوالات محلية');
    expect(chosen.parent?.name,'تحويلات');
    expect(chosen.leaf?.name,'حوالات محلية');
    expect(chosen.leaf?.parentId,chosen.parent?.id);
  });

  test('M669 expense and income use separate typed trees', () {
    expect(waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'راتب').leaf,isNull);
    expect(waffraResolveSmsReviewCategory(catalog,
      income:true,proposed:'راتب / راتب أساسي').leaf?.name,
      'راتب أساسي');
    expect(waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'حوالات واردة').parent,isNull);
    expect(waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'قسم متوقف').parent,isNull);
    expect(waffraResolveSmsReviewCategory(catalog,
      income:false,proposed:'فرعي متوقف').leaf,isNull);
  });

  test('M669 ambiguous duplicate leaf never gets guessed or auto selected', () {
    final duplicates=[...catalog,
      category('other','أخرى'),
      category('other-x','حوالات محلية',parentId:'other')];
    final r=waffraResolveSmsReviewCategory(duplicates,
      income:false,proposed:'حوالات محلية');
    expect(r.leaf,isNull);
    expect(r.parent,isNull);
    final exact=waffraResolveSmsReviewCategory(duplicates,
      income:false,proposed:'تحويلات / حوالات محلية');
    expect(exact.leaf?.id,'local');
  });

  for(final direction in [TextDirection.rtl,TextDirection.ltr]){
    testWidgets('M669 centered dropdown searches labels in $direction '
      'without choosing until explicit tap', (tester)async {
      String? selected;
      var changes=0;
      await tester.pumpWidget(MaterialApp(
        home:Directionality(textDirection:direction,
          child:Scaffold(body:Center(
            child:WaffraCenteredDropdownFormField<String>(
              key:const Key('m669-any-picker'),
              initialValue:'other',
              decoration:const InputDecoration(labelText:'اختيار القسم'),
              items:const [
                DropdownMenuItem(value:'other',child:Text('أخرى')),
                DropdownMenuItem(value:'transfers',child:Text('تحويلات')),
                DropdownMenuItem(value:'food',child:Text('مطاعم وكافيهات')),
              ],
              onChanged:(v){selected=v;changes++;},
            ),
          ))),
        ),
      ));
      await tester.tap(find.byKey(const Key('m669-any-picker')));
      await tester.pumpAndSettle();
      final search=find.byKey(const Key('waffra-centered-dropdown-search'));
      expect(search,findsOneWidget);
      await tester.enterText(search,'تَحْوِيلات');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('waffra-modal-choice-1')),findsOneWidget);
      expect(find.byKey(const Key('waffra-modal-choice-0')),findsNothing);
      expect(find.text('مطاعم وكافيهات'),findsNothing);
      expect(changes,0);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(changes,0);
      await tester.tap(find.byKey(const Key('m669-any-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(search,'تحويلات');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waffra-modal-choice-1')));
      await tester.pumpAndSettle();
      expect(selected,'transfers');
      expect(changes,1);
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('M669 generic dropdown search shows no-results state',
      (tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      WaffraCenteredDropdownFormField<String>(
        initialValue:'one',
        decoration:const InputDecoration(labelText:'Category'),
        items:const [DropdownMenuItem(value:'one',child:Text('Salary')),
          DropdownMenuItem(value:'two',child:Text('Shopping'))],
        onChanged:(_){},
      ),
    )));
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('waffra-centered-dropdown-search')),
      'does not exist');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-centered-dropdown-no-results')),
      findsOneWidget);
    expect(find.byKey(const Key('waffra-modal-choice-0')),findsNothing);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

  test('M669 all SMS review routes keep original source and explicit reasons',(){
    final main=File('lib/main.dart').readAsStringSync();
    final part=main.substring(
      main.indexOf(' Future<void> _reviewAutoSmsCandidates('),
      main.indexOf(' void _receiveSharedSms('));
    expect(part,contains("Key('m669-review-original-sms-text')"));
    expect(part,contains('SelectableText(body,'));
    expect(part,contains('WaffraBankSmsFactsParser.isVerificationChallenge'));
    expect(part,contains("Key('m669-review-category-search')"));
    expect(part,contains('waffraSearchAny('));
    expect(part,contains("Key('m669-sms-review-blockers')"));
    expect(part,contains("Key('m565-sms-yes-confirm')"));
    expect(part,contains("Key('m590-sms-choose-account-before-yes')"));
    expect(part,contains("category:reviewedCategory,income:expectedIncome"));
    expect(main,contains("Key('waffra-entry-original-sms-text')"));
    final transfer=File('lib/waffra_account_transaction_form.dart')
      .readAsStringSync();
    expect(transfer,contains("Key('m662-transfer-original-sms-text')"));
    expect(transfer,contains('SelectableText(widget.originalSmsText!'));
    expect(main,contains('initialSmsTransfer:prefill,originalSmsText:body,'));
    expect(main,contains('WaffraAutoSms.acknowledgeCommitted'));
  });

  test('M669 SMS rules have searchable category and account selectors',(){
    final src=File('lib/waffra_sms_rule_settings_page.dart')
      .readAsStringSync();
    expect(src,contains('WaffraCenteredDropdownFormField<String>'));
    expect(src,isNot(contains('DropdownButtonFormField<String>')));
    expect(src,contains('category='));
    expect(src,contains('accountId='));
  });

  test('M669 actual bank transfer is never treated as automatic expense',(){
    const internal='تحويل بين حسابات\nالمبلغ: 1900 ريال';
    final facts=WaffraBankSmsFactsParser.parse(internal);
    expect(facts.kind,WaffraBankOperationKind.transfer);
    expect(facts.canAutoPostAsIncomeExpense,isFalse);
    const outgoing='حوالة صادرة\nالمبلغ: 1900 ريال';
    final expense=WaffraBankSmsFactsParser.parse(outgoing);
    expect(expense.kind,WaffraBankOperationKind.expense);
  });
}
