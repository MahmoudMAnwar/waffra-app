import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_recurring_policy.dart';

/// M1015 / Issue #731: verified paid approval for standalone recurring dues.
/// Source tests prove wiring; actual financial lifecycle is guarded by
/// SQLCipher writer unit tests plus mandatory physical Android acceptance.
void main(){
 test('M1015 authenticated first-frame dispatch reviews ALL expense dues',(){
  final startup=File('lib/waffra_home_finance_startup.part.dart')
   .readAsStringSync();
  expect(startup,contains('await applyRecurring(goalLinkedOnly:false);'));
  expect(startup,isNot(contains('goalLinkedOnly:verifiedEncryptedStartup')));
  expect(startup.indexOf('setState(()=>ready=true);'),
   lessThan(startup.indexOf('await applyRecurring(goalLinkedOnly:false);')));
  expect(startup.indexOf('if(!await _m663AwaitVisible(startupEpoch)||'),
   lessThan(startup.indexOf('await applyRecurring(goalLinkedOnly:false);')));
  expect(startup,contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
 });

 test('M1015 standalone expenses use Paid/Postpone/Not now, no silent payment',(){
  final due=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  final handler=due.split(' Future<void> applyRecurring({bool goalLinkedOnly=false})async {')[1];
  expect(handler,contains('if(goalLinkedOnly&&r.linkedGoalId==null)continue;'));
  expect(handler,contains('r.linkedGoalId==null&&r.income)continue;'));
  expect(handler,contains('WaffraRecurringPolicy.isOutstanding('));
  expect(handler,contains("alreadyPaid:entries.any((e)=>e.id==id)"));
  expect(handler,contains('if(!r.active||!waffraCategoryNameAvailableForPosting('));
  expect(handler,contains("Navigator.pop(ctx,'paid')"));
  expect(handler,contains("Navigator.pop(ctx,'postpone')"));
  expect(handler,contains("Navigator.pop(ctx,'later')"));
  final paid=handler.split("if(action=='paid'){")[1].split("}else if(action=='postpone'){")[0];
  expect(paid,contains('if(isGoalDue){'));
  expect(paid,contains('await reviewSmsAccountLinks(['));
  expect(paid,contains("sourceType:'recurring'"));
  expect(paid,contains('if(chosen==null)return;'));
  expect(paid,contains('userConfirmed:true,selectedAccountId:chosen.ids?.single'));
  expect(paid,contains('WaffraFinanceRoute.recurringPostingAndPostponement'));
  final postpone=handler.split("}else if(action=='postpone'){")[1];
  expect(postpone,contains('recurringPostponed[id]=selected.toIso8601String();'));
  expect(postpone,contains("operation:'recurring-postpone'"));
  expect(postpone,isNot(contains('entries.insert(')));
  final beforeAction=handler.split("if(action=='paid'){")[0];
  expect(beforeAction,isNot(contains('entries.insert(')));
  expect(beforeAction,isNot(contains('settleLinkedGoalDue(')));
  expect(beforeAction,isNot(contains('persist(route:')));
 });

 test('M1015 current-month payment cannot duplicate, later month independent',(){
  final today=DateTime(2026,11,16);
  final id=WaffraRecurringPolicy.entryId('independent-due',today);
  expect(id,'rec_independent-due_2026_11');
  expect(WaffraRecurringPolicy.isOutstanding(
   due:DateTime(2026,11,16),today:today,
   startAt:DateTime(2026,10,1),alreadyPaid:false),isTrue);
  expect(WaffraRecurringPolicy.isOutstanding(
   due:DateTime(2026,11,16),today:today,
   startAt:DateTime(2026,10,1),alreadyPaid:true),isFalse);
  expect(WaffraRecurringPolicy.isOutstanding(
   due:DateTime(2026,11,16),today:today,
   startAt:DateTime(2026,10,1),alreadyPaid:false,
   postponedUntil:DateTime(2026,11,20)),isFalse);
  expect(WaffraRecurringPolicy.entryId('independent-due',DateTime(2026,12,16)),
   isNot(id));
 });

 test('M1015 immutable verified SQLCipher recurring writer is already wired',(){
  final authority=File('lib/storage/waffra_verified_finance_authority.dart')
   .readAsStringSync();
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
   .readAsStringSync();
  expect(authority,contains('await encryptedSession!.commitRecurringPayment('));
  expect(authority,contains('if (!userConfirmed ||'));
  expect(authority,contains('additions.length != 1'));
  expect(bridge,contains('Future<WaffraFinanceSnapshotState> commitRecurringPayment({'));
  expect(bridge,contains('if (!experimentalEnabled || !userConfirmed)'));
  expect(bridge,contains("throw StateError('Recurring payment is already posted.')"));
  expect(bridge,contains("throw StateError('Recurring payment may only clear its own postponement.')"));
  expect(bridge,contains('SELECT archived,currency FROM fresh_finance_money_accounts'));
  expect(bridge,contains('INSERT INTO fresh_finance_account_entry_links'));
  expect(bridge,contains('INSERT INTO fresh_finance_entries'));
  expect(bridge,contains("..['waffra_recurring_postponed_v1'] = proposedPostponedJson"));
  expect(bridge,contains('return snapshot.commit('));
  final source=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  expect(source,contains('await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,'));
  expect(source,contains('if(mounted)await _loadFinanceSafely();'));
 });
}
