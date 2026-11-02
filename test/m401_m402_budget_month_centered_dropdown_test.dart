import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_centered_dropdown.dart';

void main() {
  test('M401 monthly budget card counts user budgets and navigates display month', () {
    final source=File('lib/main.dart').readAsStringSync();
    final from=source.indexOf('Widget monthlyBudgetCard(){');
    final to=source.indexOf('Widget _budgetFigure(',from);
    expect(from,greaterThan(0));
    expect(to,greaterThan(from));
    final card=source.substring(from,to);
    expect(card,contains("key:const Key('waffra-budget-month-control')"));
    expect(card,contains("key:const Key('waffra-budget-month-prev')"));
    expect(card,contains("key:const Key('waffra-budget-month-next')"));
    expect(card,contains("key:const Key('waffra-budget-month-today')"));
    expect(card,contains("key:const Key('waffra-budget-month-label')"));
    expect(card,contains("'${allBudgets.length} ميزانية مضافة'"));
    expect(card,contains('MaterialLocalizations.of(context).formatMonthYear(viewedMonth)'));
    expect(card,contains('e.date.month==viewedMonth.month'));
    expect(card,contains('waffraNamedBudgetSpent(entries,categories,selected,viewedMonth)'));
    expect(card,contains("waffraIsEnglish?'Budget overview':'متابعة الميزانيات'"));
    expect(card,isNot(contains('(selected.budgetLabel??\'ميزانية \'+selected.displayName),')));
    // The budget total remains a projection; there is no ledger mutation.
    expect(card,contains('final overallLimit=allBudgets.fold<double>'));
    expect(card,contains('final overallSpent=monthEntries.where('));
    expect(card,isNot(contains('persist(')));
    expect(card,isNot(contains('entries.add(')));
    expect(card,isNot(contains('namedBudgets.add(')));
  });

  for (final direction in [TextDirection.rtl,TextDirection.ltr]) {
    testWidgets('M402 centered picker $direction saves only after tapping an item',
        (tester) async {
      String? chosen;
      await tester.pumpWidget(MaterialApp(home:Directionality(
        textDirection:direction,
        child:Scaffold(body:Center(child:SizedBox(width:300,
          child:WaffraCenteredDropdownFormField<String>(
            key:const Key('centered-picker'),
            initialValue:'one',
            decoration:const InputDecoration(labelText:'ميزانية العملية',
              border:OutlineInputBorder()),
            items:const [
              DropdownMenuItem(value:'one',child:Text('الوقود')),
              DropdownMenuItem(value:'two',child:Text('الطعام')),
            ],
            onChanged:(v)=>chosen=v,
          )),
        )),
      )));
      await tester.tap(find.byKey(const Key('centered-picker')));
      await tester.pumpAndSettle();
      final dialog=find.byType(Dialog);
      expect(dialog,findsOneWidget);
      expect(tester.widget<Dialog>(dialog).shape,isA<RoundedRectangleBorder>());
      expect(find.byType(BackdropFilter),findsWidgets);
      final center=tester.getCenter(dialog).dx;
      expect((center-tester.view.physicalSize.width/
        tester.view.devicePixelRatio/2).abs(),lessThan(4));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(chosen,isNull);
      await tester.tap(find.byKey(const Key('centered-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waffra-modal-choice-1')));
      await tester.pumpAndSettle();
      expect(chosen,'two');
      expect(find.text('الطعام'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }

  test('M402 normal form dropdowns use centered modal, not anchored popup', () {
    for (final path in [
      'lib/main.dart',
      'lib/waffra_budget_directory.part.dart',
      'lib/waffra_categories_page.part.dart',
      'lib/waffra_country_first_run_page.dart',
      'lib/waffra_gold_market_section.dart',
      'lib/waffra_oil_market_section.dart',
      'lib/waffra_practical_tools_page.dart',
    ]) {
      final src=File(path).readAsStringSync();
      expect(src,contains('WaffraCenteredDropdownFormField<'),
        reason:'$path must use centered, blurry, bordered dropdowns');
      expect(src,isNot(contains('DropdownButtonFormField<')));
    }
  });
}
