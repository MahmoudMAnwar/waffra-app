import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_transaction_form.dart';

void main() {
 test('M611 transfer SAR parser accepts only legitimate grouped amounts', () {
  expect(waffraSarAmountMinor('1,000'), 100000);
  expect(waffraSarAmountMinor('1,000.50'), 100050);
  expect(waffraSarAmountMinor('١٬٠٠٠٫٥٠'), 100050);
  expect(waffraSarAmountMinor('1000.50'), 100050);
  expect(waffraSarAmountMinor('1,00'), isNull);
  expect(waffraSarAmountMinor('10,00'), isNull);
  expect(waffraSarAmountMinor('1,000.123'), isNull);
  expect(waffraSarAmountMinor('-1,000'), isNull);
  expect(waffraSarAmountMinor('0'), isNull);
 });

 test('M611 Home action tiles show read-only histories, never an add form', () {
  final src = File('lib/main.dart').readAsStringSync();
  final start=src.indexOf("Row(key:const Key('m549-three-home-finance-actions')");
  final end=src.indexOf('          const SizedBox(height:10),',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final home=src.substring(start,end);
  expect(home,contains('showSummaryTransactions(true)'));
  expect(home,contains('showSummaryTransactions(false)'));
  expect(home,contains('showInternalTransferTransactions()'));
  expect(home,isNot(contains('entrySheet(')));
  expect(home,isNot(contains('openVerifiedTransfer()')));
  final tile=File('lib/waffra_home_finance_tiles.part.dart').readAsStringSync();
  expect(src,contains('this._m684HomeFinanceAction('));
  expect(tile,contains("key:Key('m549-home-action-'"));
  expect(tile,contains('height:60,'));
 });

 test('M611 account selection is readable and mandatory for manual save', () {
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Widget monthlySummaryCard()');
  final end=src.indexOf('Future<void> showSummaryTransactions(',start);
  final summary=src.substring(start,end);
  expect(summary,contains("key:const Key('m549-home-account-filter')"));
  expect(summary,contains("label:Text(_m467AccountLabel,softWrap:true"));
  expect(summary,isNot(contains('BoxConstraints(maxWidth:100)')));
  final editor=src.substring(src.indexOf('Future<void> entrySheet('),
   src.indexOf('Future<void> showReceipt('));
  expect(editor,contains('errorText:attempted&&initial==null&&!sms&&chosenManualAccount==null'));
  expect(editor,contains('p.id==chosenManualProvider&&'));
  expect(editor,contains('p.accounts.any((a)=>a.id==chosenManualAccount)'));
 });

 test('M611 transfer history reads real encrypted rows under owner witness', () {
  final src=File('lib/main.dart').readAsStringSync();
  // M647/M648 refactored presentation into a read-only sheet and a
  // cached, verified-account SQLCipher reader. Verify the entire call chain
  // rather than requiring the storage call inside the UI click handler.
  final handlerStart=src.indexOf('Future<void> showInternalTransferTransactions()async');
  final handlerEnd=src.indexOf('String _m647VerifiedAccountLabel(',handlerStart);
  expect(handlerStart,greaterThanOrEqualTo(0));
  expect(handlerEnd,greaterThan(handlerStart));
  final handler=src.substring(handlerStart,handlerEnd);
  expect(handler,contains('await _m647ShowInternalTransfers();'));

  final sheetStart=src.indexOf('Future<void> _m647ShowInternalTransfers({String? focusId})async');
  final sheetEnd=src.indexOf('Widget _dashboardShortcut(',sheetStart);
  expect(sheetStart,greaterThanOrEqualTo(0));
  expect(sheetEnd,greaterThan(sheetStart));
  final sheet=src.substring(sheetStart,sheetEnd);
  expect(sheet,contains('final future=_m648HomeTransfers(selected);'));
  expect(sheet,isNot(contains('transferApi!.transfer(')));

  final readStart=src.indexOf(
   'Future<List<WaffraInternalTransferHistory>> _m648HomeTransfers(String account){');
  final readEnd=src.indexOf(
   'Future<List<WaffraVerifiedGoalMovement>> _m649HomeSavings(',readStart);
  expect(readStart,greaterThanOrEqualTo(0));
  expect(readEnd,greaterThan(readStart));
  final reader=src.substring(readStart,readEnd);
  expect(reader,contains('final bridge=_financeBinding?.accountsBridge;'));
  expect(reader,contains('WaffraVerifiedAccountsApi(bridge:bridge)'));
  expect(reader,contains(
   "readInternalTransferHistory(accountId:account=='all'?null:account)"));
  expect(reader,contains('Verified transfer history source unavailable'));
  expect(reader,isNot(contains('transferApi!.transfer(')));
  final context=File('lib/storage/waffra_account_context_repository.dart').readAsStringSync();
  expect(context,contains('FROM fresh_finance_internal_transfers'));
  expect(context,contains('WHERE from_account_id=? OR to_account_id=?'));
  final api=File('lib/storage/waffra_verified_accounts_api.dart').readAsStringSync();
  expect(api,contains('bridge.readVerifiedAccountMetadata((context)=>'));
  expect(api,contains('context.readInternalTransferHistory('));
 });
 test('M681-M684 Account review uses SQL page, consent and all-time unassigned',(){
  final page=File('lib/waffra_account_context_page.dart').readAsStringSync();
  final read=File('lib/storage/waffra_account_context_read.dart').readAsStringSync();
  final api=File('lib/storage/waffra_verified_accounts_api.dart').readAsStringSync();
  expect(page,contains('m681-unassigned-reconciliation-summary'));
  expect(page,contains('m684-ledger-page-next'));
  expect(page,contains('m684-previous-month'));
  expect(page,contains('summaryOnly:true'));
  expect(page,contains('linkUnassignedEntry('));
  expect(page,contains('m681-opening-balance-attestation'));
  expect(page,contains('openingExcludesHistory:openingVerified'));
  expect(page,contains('readUnassignedPage('));
  expect(page,contains('readMonthlyPage('));
  expect(page,isNot(contains('data.entries.where(')));
  expect(read,contains('loadUnassignedEntries('));
  expect(read,contains('SELECT COUNT(*) AS entry_count'));
  expect(read,contains("opening_minor')!=0"));
  expect(api,contains('readVerifiedAccountMetadata('));
 });

 test('M684 card extraction preserves original + and compact layout',(){
  final main=File('lib/main.dart').readAsStringSync();
  final tiles=File('lib/waffra_home_finance_tiles.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_finance_tiles.part.dart';"));
  expect(main,contains('this._m684HomeFinanceAction('));
  expect(tiles,contains("key:Key('m549-home-action-'"));
  expect(tiles,contains('WaffraHaptics.tap(onTap)'));
  expect(tiles,contains('height:60,'));
  expect(main,contains('floatingActionButtonLocation:WaffraDirectionalFabLocation('));
  expect(main,contains('floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
 });

}
