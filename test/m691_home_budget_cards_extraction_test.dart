import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M691 budget, summary, insights run from real same-library Dart part',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_budget_cards.part.dart').readAsStringSync();
  final source=readWaffraMainSourceForContracts();
  expect(main,contains("part 'waffra_home_budget_cards.part.dart';"));
  expect(main,isNot(contains(' Widget monthlyBudgetCard(){')));
  for(final method in [' Widget monthlyBudgetCard(){',
   ' Widget monthlySummaryCard(){',' Widget smartMoneyInsightsCard(){']){
   expect(part,contains(method));
   expect(source,contains(method));
  }
  expect(source,contains('final relevantEntries=_m684ScopedMonthEntries('));
  expect(part,isNot(contains('commitConfirmedSms(')));
  expect(part,isNot(contains('WaffraVerifiedFinanceAuthority.write(')));
 });
}
