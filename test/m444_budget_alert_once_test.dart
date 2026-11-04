import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_budget_alert_once.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>SharedPreferences.setMockInitialValues(
  <String,Object>{'existing_finance_ledger':'KEEP_ORIGINAL'}));

 test('M444 monthly budget threshold is never replayed after a decrease',()async{
  const owner='phone:0500000000',id='budget-one';
  final month=DateTime(2026,11,4);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:month,crossedStages:[50]),isTrue);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:month,crossedStages:[50]),isFalse);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:month,crossedStages:[100]),isTrue);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:month,crossedStages:[100]),isFalse);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:DateTime(2026,12,1),
   crossedStages:[50]),isTrue);
  expect((await SharedPreferences.getInstance()).getString(
   'existing_finance_ledger'),'KEEP_ORIGINAL');
 });

 test('M444 single jump to 100 marks both percentage thresholds',()async{
  final month=DateTime(2026,11,4);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:'person1',budgetId:'rent',month:month,crossedStages:[50,100]),isTrue);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:'person1',budgetId:'rent',month:month,crossedStages:[50]),isFalse);
  expect(await WaffraBudgetAlertOnce.claim(
   owner:'person2',budgetId:'rent',month:month,crossedStages:[50]),isTrue);
 });

 test('M444 concurrent confirmed finance saves cannot duplicate a dialog',()async{
  final outcomes=await Future.wait(List.generate(8,(_)=>
   WaffraBudgetAlertOnce.claim(owner:'same',budgetId:'fuel',
    month:DateTime(2026,11,5),crossedStages:[70])));
  expect(outcomes.where((x)=>x).length,1);
 });
}
