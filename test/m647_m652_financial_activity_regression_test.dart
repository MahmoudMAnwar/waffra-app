import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 final app = File('lib/main.dart').readAsStringSync();
 final repository = File('lib/storage/waffra_account_context_repository.dart')
     .readAsStringSync();
 final api = File('lib/storage/waffra_verified_accounts_api.dart')
     .readAsStringSync();

 test('M647 transfer uses compact verified from and to instead of 70 percent pane', () {
  final start = app.indexOf('Widget _m647TransferCard(');
  final end = app.indexOf(' Widget _dashboardShortcut(', start);
  expect(start, greaterThan(0));
  expect(end, greaterThan(start));
  final transfer = app.substring(start, end);
  expect(transfer, contains('fromAccountId'));
  expect(transfer, contains('toAccountId'));
  expect(transfer, contains("'من الحساب'"));
  expect(transfer, contains("'إلى الحساب'"));
  expect(transfer, contains('WaffraCurrencyAmount(t.amountMinor/100'));
  expect(transfer, contains('mainAxisSize:MainAxisSize.min'));
  expect(transfer, isNot(contains('height*.7')));
  expect(transfer, contains("Key('m647-verified-transfer-'"));
 });

 test('M648 transfer activity is read-only from encrypted journal and separate from MoneyEntry', () {
  expect(repository, contains('FROM fresh_finance_internal_transfers'));
  expect(repository, contains('readInternalTransferHistory('));
  expect(api, contains('bridge.readVerifiedAccountMetadata'));
  expect(app, contains('_m648HomeTransfers(_m467SelectedAccount)'));
  expect(app, contains("Key('m648-home-transfer-'"));
  expect(app, contains("'التحويلات'=>'Transfers'"));
  final cards = app.substring(app.indexOf('Widget _m647TransferCard('),
      app.indexOf(' Widget _dashboardShortcut('));
  expect(cards, isNot(contains('entries.insert')));
  expect(cards, isNot(contains('commitConfirmedManual(')));
  expect(cards, isNot(contains('api.transfer(')));
 });

 test('M649 gold goals are actual verified fund/release source movements', () {
  expect(repository, contains('JOIN fresh_finance_goal_account_sources'));
  expect(repository, contains('JOIN fresh_finance_goals'));
  expect(repository, contains("m.kind IN ('fund','release')"));
  expect(repository, contains('ORDER BY m.occurred_at_iso DESC'));
  expect(api, contains('readGoalAccountMovementHistory('));
  expect(app, contains('_m649HomeSavings(_m467SelectedAccount)'));
  expect(app, contains("Key('m649-verified-saving-'"));
  expect(app, contains("'إضافة مبلغ للهدف الادخاري'"));
  expect(app, contains("'سحب من الادخار'"));
  final card = app.substring(app.indexOf('Widget _m649SavingsCard('),
      app.indexOf('Future<void> _m647ShowInternalTransfers(', app.indexOf('Widget _m649SavingsCard(')));
  expect(card, contains('accountId'));
  expect(card, isNot(contains('commitConfirmedManual(')));
 });

 test('M650 paid recurring and goal due are only presentation facets', () {
  final begin = app.indexOf('Widget compactTransaction(MoneyEntry entry)');
  final end = app.indexOf(' Widget _m549HomeFinanceAction(', begin);
  final widget = app.substring(begin,end);
  expect(widget, contains("entry.sourceType=='recurring'"));
  expect(widget, contains("entry.sourceType=='goal_due'"));
  expect(widget, contains("'استحقاق مدفوع'"));
  expect(widget, contains('0xFFEFE9F8'));
  expect(widget, isNot(contains('entries.insert(')));
 });

 test('M651 durable local rule learning triggers debounced non-posting refresh', () {
  final from = app.indexOf('Future<void> _learnManualTransferPreference()');
  final to = app.indexOf(' Map<String,Object?>? _localSmsClassification(',from);
  final learning = app.substring(from,to);
  expect(learning, contains('await store.write('));
  expect(learning, contains('_receiveAutoSmsNotice()'));
  expect(learning, isNot(contains('_refreshAutoSmsInbox(importMonth:true)')));
  final start = app.indexOf('void _receiveAutoSmsNotice()');
  final end = app.indexOf(' Future<void> _rescanAutoSmsInbox()',start);
  final notice = app.substring(start,end);
  expect(notice, contains('Duration(milliseconds:900)'));
  expect(notice, contains('unawaited(_refreshAutoSmsInbox())'));
  final refresh = app.substring(app.indexOf('Future<void> _runAutoSmsRefresh('),
      app.indexOf(' Future<void> _rescanAutoSmsInbox('));
  expect(refresh, contains('compute(waffraM632ClassifySmsQueue'));
  expect(refresh, contains('if(importMonth){'));
  expect(refresh, contains('_m630SmsSessionCurrent('));
 });

 test('M652 PDF follows selected types and preserves non-posting internal movements', () {
  final begin = app.indexOf('Future<void> exportEntriesPdf(');
  final end = app.indexOf(' Future<void> _deleteVerifiedEntry(', begin);
  final pdf = app.substring(begin,end);
  expect(pdf, contains('pdfTransfers=await _m648HomeTransfers(account)'));
  expect(pdf, contains('pdfSavings=await _m649HomeSavings(account)'));
  expect(pdf, contains("'التحويلات بين حساباتي'"));
  expect(pdf, contains("'حركات الادخار'"));
  expect(pdf, contains('0xFFE7F0FA'));
  expect(pdf, contains('0xFFF8F0D9'));
  expect(pdf, contains('0xFFEFE9F8'));
  expect(pdf, contains('final totalIncome=sum(items,true),totalExpenses=sum(items,false);'));
  expect(pdf, isNot(contains('sum(pdfTransfers')));
  expect(pdf, isNot(contains('sum(pdfSavings')));
 });
}
