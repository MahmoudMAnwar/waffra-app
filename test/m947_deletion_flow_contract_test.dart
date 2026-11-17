import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M947 single financial delete asks consent, verifies SQLCipher witnesses '
  'and only publishes after committed deletion; undo uses current source',(){
  final source=File('lib/waffra_home_transaction_ledger_actions.part.dart')
   .readAsStringSync();
  final start=source.indexOf(' Future<void> _deleteVerifiedEntry(');
  final end=source.indexOf(' Future<void> _undoVerifiedDeletedEntry(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final deletion=source.substring(start,end);
  expect(deletion,contains('await confirmDeletion('));
  expect(deletion,contains('if(approved!=true||!mounted)return;'));
  expect(deletion,contains('WaffraVerifiedTransactionUiGuard.requireUnchangedSelected('));
  expect(deletion,contains('await _financeAuthority.loadVerifiedReceiptScreen('));
  expect(deletion,contains('await _financeAuthority.deleteVerifiedTransactionToRecycle('));
  expect(deletion,contains('userConfirmed:true'));
  final commit=deletion.indexOf('final committed=await');
  final publish=deletion.indexOf('_publishVerifiedTransactionLedger(committed);');
  expect(commit,greaterThan(0));
  expect(publish,greaterThan(commit));
  expect(deletion,isNot(contains('Navigator.pushReplacement(')));
  expect(deletion,isNot(contains('entries.clear()')));
  expect(deletion,isNot(contains('ready=false')));
  final publisher=source.substring(
   source.indexOf(' void _publishVerifiedTransactionLedger('),start);
  expect(publisher,contains('if(!mounted)return;'));
  expect(publisher,contains('setState((){'));
  expect(publisher,contains('_m684InvalidatePeriodRead();'));
  expect(publisher,contains('entries..clear()..addAll(loaded);'));
  expect(publisher,contains('_lastFinanceAuthorityRead=committed;'));
  final undo=source.substring(end,source.indexOf(
   ' Future<void> _showVerifiedDeletedTransactions()',end));
  expect(undo,contains('restoreVerifiedDeletedTransaction('));
  expect(undo,contains('_publishVerifiedTransactionLedger(committed);'));
  expect(undo,isNot(contains('Navigator.pushReplacement(')));
 });

 test('M947 Cancel in the actual dialog returns FALSE, never removes records',(){
  final source=File('lib/waffra_home_category_confirmations.part.dart')
   .readAsStringSync();
  final start=source.indexOf(' Future<bool?> confirmDeletion(');
  expect(start,greaterThan(0));
  final confirm=source.substring(start);
  expect(confirm,contains('Navigator.pop(ctx,false)'));
  expect(confirm,contains('Navigator.pop(ctx,true)'));
  expect(confirm,contains("'Cancel':'إلغاء'"));
  expect(confirm,contains("'Confirm delete':'تأكيد الحذف'"));
  final delete=File('lib/waffra_home_transaction_ledger_actions.part.dart')
   .readAsStringSync();
  expect(delete,contains('if(yes!=true||!mounted)return;'));
 });

 test('M947 Delete all only clears Home after source-authorized durable save; '
  'independent biometric full-vault erase remains guarded',(){
  final source=File('lib/waffra_home_delete_all_transactions.part.dart')
   .readAsStringSync();
  expect(source,contains('if(confirmed!=true||!mounted)return;'));
  final write=source.indexOf('await _financialWriteQueue.submit(');
  final clear=source.indexOf('setState((){_m684InvalidatePeriodRead();entries.clear();});');
  expect(write,greaterThan(0));
  expect(clear,greaterThan(write));
  expect(source,isNot(contains('smsHashes.clear();')));
  expect(source,contains('route:WaffraFinanceRoute.deleteAllTransactions'));
  expect(source,contains('userConfirmed:true'));
  expect(source,isNot(contains('Navigator.pushReplacement(')));
  expect(source,isNot(contains('ready=false')));
  final settings=File('lib/waffra_home_account_tools.part.dart').readAsStringSync();
  final erase=settings.substring(settings.indexOf(
   ' Future<void> eraseFinancialData()async {'));
  expect(erase,contains("_authorizeSensitiveAction('deleting financial data')"));
  expect(erase,contains('WaffraFinanceRoute.fullFinanceReset'));
  expect(erase.indexOf('_authorizeSensitiveAction('),
   lessThan(erase.indexOf('WaffraFinanceRoute.fullFinanceReset')));
 });

 test('M947 goal/recurring delete preserves history, expiration and recovery',(){
  final source=File('lib/waffra_recurring_trash.part.dart').readAsStringSync();
  expect(source,contains('Duration(days:30)'));
  expect(source,contains('deletedRecurringDialog()'));
  expect(source,contains("hasHistory?'Completed transactions remain in your financial history."));
  expect(source,contains('if(ok!=true||!mounted)return;'));
  final goal=File('lib/waffra_home_goal_actions.part.dart').readAsStringSync();
  expect(goal,contains('delete'));
  final account=File('lib/waffra_account_deletion.dart').readAsStringSync();
  expect(account,contains('waffraAccountDeletionReleased'));
  expect(account,contains('defaultValue: false'));
 });
}
