import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// M644: regression for goal/recurring error UX and verified goal funding.
void main(){
 test('M644 account pickers route failure through one footer-aware notice',(){
  final picker=File('lib/waffra_goal_recurring_account_picker.dart').readAsStringSync();
  final app=readWaffraMainSourceForContracts();
  final actions=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(picker,contains('required this.onCreateAccount,required this.onError'));
  expect(picker,contains('widget.onError(label('));
  expect(RegExp(r'\bSnackBar\s*\(').allMatches(picker),isEmpty);
  expect(RegExp(r'\.showSnackBar\s*\(').allMatches(app).length,1);
  expect(RegExp(r'\bSnackBar\s*\(').allMatches(app).length,1);
  expect(RegExp(r'WaffraGoalRecurringAccountPicker\(').allMatches(app).length,3);
  expect(RegExp(r'onError:\(message\)=>snack\(context,message\)').allMatches(app).length,3);
  expect(RegExp(r'WaffraGoalRecurringAccountPicker\(').allMatches(actions).length,1);
  expect(actions,contains('onError:(message)=>snack(context,message),'));
 });

 test('M644 savings success only occurs after source-verified atomic posting',(){
  final code=File('lib/main.dart').readAsStringSync();
  final a=code.indexOf('Future<void> fundGoal(SavingGoal g)async {');
  final b=code.indexOf('IconData goalIcon(',a);
  expect(a,greaterThan(0));
  expect(b,greaterThan(a));
  final fund=code.substring(a,b);
  expect(fund,contains('final verifiedFundingAccounts=await _m641VerifiedGoalRecurringAccounts();'));
  expect(fund,contains('final available=source.single.balanceMinor/100;'));
  // A visibly unaffordable amount is explained inside the open dialog,
  // disabling Add rather than dismissing into a generic funding failure.
  expect(fund,contains('final fundingExceedsBalance='));
  expect(fund,contains('errorText:fundingExceedsBalance?'));
  expect(fund,contains(
   'onPressed:fundingExceedsBalance?null:WaffraHaptics.tap('));
  expect(fund,contains('The encrypted writer checks cash again at commit time.'));
  expect(fund,contains('if(n>available){'));
  // M689: insufficient cash cannot be bypassed by a confirmation dialog.
  expect(fund,contains('if(n>available){'));
  expect(fund,contains('snack(context,waffraIsEnglish?'));
  expect(fund,isNot(contains('if(acknowledged!=true||!mounted)return;')));
  expect(fund,contains('baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted'));
  final commit=fund.indexOf('await fundingBridge.fundVerifiedGoal(');
  final reload=fund.indexOf('if(mounted)await _refreshFromVerifiedFinance();',commit);
  final abort=fund.indexOf('return;',fund.indexOf('}catch(error){',commit));
  final success=fund.indexOf('if(achieved&&mounted)');
  expect(commit,greaterThan(0));
  expect(reload,greaterThan(commit));
  expect(abort,greaterThan(reload));
  expect(success,greaterThan(abort));
  expect(fund,isNot(contains('goals[i]=current.copy(saved:current.saved+n)')));
 });
}
