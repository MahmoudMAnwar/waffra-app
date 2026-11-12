import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
    BudgetCategory, defaultCategories, waffraResolveSmsReviewCategory;
import 'package:waffra/waffra_centered_dropdown.dart';
import 'package:waffra/waffra_category_catalog.dart';
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

  test('M669 entire seeded income/expense taxonomy has verified parents', () {
    final all=defaultCategories();
    final roots=all.where((c)=>!c.isSubcategory).toList();
    final children=all.where((c)=>c.isSubcategory).toList();
    expect(roots.length,waffraCategoryCatalog.length);
    expect(children.length,greaterThan(700));
    final ids=<String>{};
    for(final c in all){
      expect(ids.add(c.id),isTrue,reason:'Duplicate category ID: ${c.id}');
      if(!c.isSubcategory)continue;
      final parent=roots.where((r)=>r.id==c.parentId).toList();
      expect(parent.length,1,reason:'Orphan category: ${c.name}');
      expect(parent.single.income,c.income);
      expect(c.name,startsWith('${parent.single.name} / '));
      expect(c.displayName,isNot(parent.single.name));
    }
    for(final root in roots){
      final hint=waffraResolveSmsReviewCategory(all,
        income:root.income,proposed:root.name);
      expect(hint.parent?.id,root.id);
      expect(hint.leaf,isNull);
    }
  });

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
      );
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
    expect(part,contains("m669-review-category-search-"));
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

  test('M669 all non-command production dropdowns use centralized search', () {
    final files=<String>[
      'lib/waffra_goal_recurring_account_picker.dart',
      'lib/waffra_new_account_dialog.dart',
      'lib/waffra_account_context_page.dart',
      'lib/waffra_account_context_settings.dart',
      'lib/waffra_account_transaction_form.dart',
      'lib/waffra_sms_rule_settings_page.dart',
    ];
    for(final path in files){
      final src=File(path).readAsStringSync();
      expect(src,isNot(contains('DropdownButtonFormField<String>(')),
        reason:'$path must not contain unsearchable Material dropdowns');
      expect(src,contains('WaffraCenteredDropdownFormField<String>('),
        reason:'$path must share the tested live-search picker');
      expect(src,contains("import 'waffra_centered_dropdown.dart';"));
    }
    final picker=File('lib/waffra_centered_dropdown.dart').readAsStringSync();
    expect(picker,contains("Key('waffra-centered-dropdown-search')"));
    expect(picker,contains('waffraSearchAny('));
    expect(picker,contains('waffraTr('));
  });

  test('M669 SMS rules have searchable category and account selectors',(){
    final src=File('lib/waffra_sms_rule_settings_page.dart')
      .readAsStringSync();
    expect(src,contains('WaffraCenteredDropdownFormField<String>'));
    expect(src,isNot(contains('DropdownButtonFormField<String>')));
    expect(src,contains('category='));
    expect(src,contains('accountId='));
    expect(src,contains("Key('m669-sms-rule-original-text')"));
  });

  test('M669 all account, goal, recurring and transfer dropdowns use shared search',(){
    for(final path in <String>[
      'lib/waffra_goal_recurring_account_picker.dart',
      'lib/waffra_new_account_dialog.dart',
      'lib/waffra_account_context_page.dart',
      'lib/waffra_account_context_settings.dart',
      'lib/waffra_account_transaction_form.dart',
      'lib/waffra_sms_rule_settings_page.dart',
    ]){
      final source=File(path).readAsStringSync();
      expect(source,contains("import 'waffra_centered_dropdown.dart';"),
        reason:'$path must inherit live shared search');
      expect(source,contains('WaffraCenteredDropdownFormField<String>'),
        reason:'$path should use accessible centered options');
      expect(source,isNot(contains('DropdownButtonFormField<')),
        reason:'$path may not leave any unsearchable native dropdown');
    }
    final shared=File('lib/waffra_centered_dropdown.dart').readAsStringSync();
    expect(shared,contains("Key('waffra-centered-dropdown-search')"));
    expect(shared,contains("Key('waffra-centered-dropdown-no-results')"));
    expect(shared,contains('waffraSearchAny('));
  });

  test('M669 actual bank transfer is never treated as automatic expense',(){
    const internal='تحويل بين حسابات\nالمبلغ: 1900 ريال';
    final facts=WaffraBankSmsFactsParser.parse(internal);
    expect(facts.kind,WaffraBankOperationKind.transfer);
    expect(facts.canAutoPostAsIncomeExpense,isFalse);
    const outgoing='شراء نقاط بيع\nالمبلغ: 1900 ريال';
    final expense=WaffraBankSmsFactsParser.parse(outgoing);
    expect(expense.kind,WaffraBankOperationKind.expense);
    const bankTransfer='حوالة صادرة\nالمبلغ: 1900 ريال';
    expect(WaffraBankSmsFactsParser.parse(bankTransfer).kind,
      WaffraBankOperationKind.transfer,
      reason:'Bank transfer is not automatically an everyday expense');
  });
}
