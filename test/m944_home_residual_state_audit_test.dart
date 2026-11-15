import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

/// Axis 4: no staged production financial writer or giant screen tree is
/// allowed to leak back into Home's 1-owner State and lifecycle.
void main() {
 test('M944 core Home State remains lifecycle/source ownership, not page UI', () {
  final main=File('lib/main.dart').readAsStringSync();
  final start=main.indexOf('class _HomeScreenState extends State<HomeScreen>');
  final end=main.indexOf('class WaffraDeletedItemsButton extends StatelessWidget',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final state=main.substring(start,end);
  expect(state.split('\n').length,lessThan(300),
   reason:'Page assembly must stay in registered parts; never reintroduce the 246-line widget tree.');
  for(final required in [
   ' @override void didUpdateWidget(', ' @override void dispose(){',
   ' @override void initState(){', ' _financeBinding',
   '_m627OutstandingAccountReads', '_m627ClosingSession',
   '_m663FirstInteractiveFrame', '_registeredBackHandler',
   ' @override Widget build(BuildContext context)=>_m944BuildHome();',
  ]) {
   expect(state,contains(required),reason:'Protected owner session lifecycle: $required');
  }
  for(final gone in [
   ' Widget dashboard(){', ' Widget goalsPage(){', ' Widget recurringPage(){',
   ' Future<void> recurringDialog(', 'floatingActionButtonLocation:',
   'WaffraApprovedFixedFabNoticePosition(', ' Future<void> entrySheet(',
   ' Widget _m944BuildHome()=>PopScope(',
   'INSERT INTO fresh_finance_entries',
  ]) {
   expect(state,isNot(contains(gone)),reason:'Must be implemented in an owner-bound registered module: $gone');
  }
  final shell=File('lib/waffra_home_root_shell.part.dart').readAsStringSync();
  final editor=File('lib/waffra_home_recurring_workflows.part.dart').readAsStringSync();
  final page=File('lib/waffra_home_goals_recurring_pages.part.dart').readAsStringSync();
  expect(shell,contains(' Widget _m944BuildHome()=>PopScope('));
  expect(page,contains(' Widget goalsPage(){'));
  expect(page,contains(' Widget recurringPage(){'));
  expect(editor,contains(' Future<void> recurringDialog('));
  expect(editor,contains(' _setRecurringActiveFromCard('));
  expect(editor,contains(' _handleRecurringCardAction('));
  expect(editor,contains(' nextRecurringDue('));
  final reconstructed=readWaffraMainSourceForContracts();
  expect(reconstructed,contains(' @override Widget build(BuildContext context)=>PopScope('));
  expect(reconstructed.indexOf(' Future<void> recurringDialog('),
   lessThan(reconstructed.indexOf(' Widget recurringPage(){')));
 });
}
