import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M1008 P0: UI cannot treat a committed SQLCipher SMS as invisible merely
/// because the account-ID cache or chronological period index is older.
void main(){
 final entry=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
 final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
 final refresh=File('lib/waffra_home_verified_refresh.part.dart').readAsStringSync();
 final account=File('lib/waffra_home_verified_account_flows.part.dart').readAsStringSync();
 final summary=File('lib/waffra_home_budget_cards.part.dart').readAsStringSync();
 final timeline=File('lib/waffra_home_dashboard_analytics.part.dart').readAsStringSync();

 test('M1008 sheet bank SMS saves immutable ledger and refreshes verified '
  'account IDs and balances before presenting successful completion',(){
  final begin=entry.indexOf('  if(pendingHash!=null&&initial==null){');
  final end=entry.indexOf('  }else{\n   // An account is selected',begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final section=entry.substring(begin,end);
  final saved=section.indexOf('if(applied.saved!=1)');
  final changed=section.indexOf('entries..clear()..addAll(verified);');
  final invalidated=section.indexOf('_m684InvalidatePeriodRead();');
  final accountRefresh=section.indexOf('await _m467RefreshHomeAccounts();');
  final widget=section.indexOf('unawaited(_refreshWidget());');
  expect(saved,greaterThan(0));
  expect(invalidated,greaterThan(saved));
  expect(changed,greaterThan(invalidated));
  expect(accountRefresh,greaterThan(changed));
  expect(widget,greaterThan(accountRefresh));
  expect(section,contains('selectedAccountIds:reviewedAccount.ids'));
  expect(section,contains('expectedAccountGeneration:reviewedAccount.generation'));
  expect(section,contains('if(mounted&&!_m468VerifiedAccountsLoaded)'));
  expect(section,isNot(contains('commitConfirmedManual(')));
 });

 test('M1008 direct verified SMS write invalidates indexed history and '
  're-reads account projection without repeating the debit on read failure',(){
  final begin=review.indexOf(' Future<void> _m565ConfirmSms({');
  final end=review.indexOf(' Widget _m615ReviewDetail(',begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final src=review.substring(begin,end);
  final commit=src.indexOf('_financeAuthority.commitConfirmedSms(');
  final change=src.indexOf('entries..clear()..addAll(updated);');
  final invalidate=src.indexOf('_m684InvalidatePeriodRead();');
  final update=src.indexOf('await _m467RefreshHomeAccounts();');
  final ack=src.indexOf('WaffraAutoSms.acknowledgeCommitted([id]);',commit);
  expect(commit,greaterThan(0));
  expect(invalidate,greaterThan(commit));
  expect(change,greaterThan(invalidate));
  expect(update,greaterThan(change));
  expect(ack,greaterThan(update));
  expect(src,contains('accountProjectionVerified=mounted&&_m468VerifiedAccountsLoaded;'));
  expect(src,contains('Post-commit presentation failure is not a failed save.'));
  expect(src,contains('if(applied.saved!=1)'));
 });

 test('M1008 pull refresh also refreshes account ID cache on same digest '
  'and invalidates period index on a changed background SMS ledger',(){
  final begin=refresh.indexOf(' Future<void> _refreshFromVerifiedFinance()async {');
  expect(begin,greaterThan(0));
  final code=refresh.substring(begin);
  final fast=code.indexOf('encryptedCurrent.generation==encryptedPrevious.generation');
  final fastRefresh=code.indexOf('await _m467RefreshHomeAccounts();',fast);
  final fastReturn=code.indexOf('return;',fast);
  expect(fastRefresh,greaterThan(fast));
  expect(fastReturn,greaterThan(fastRefresh));
  final invalidate=code.indexOf('_m684InvalidatePeriodRead();');
  final assign=code.indexOf('entries..clear()..addAll(nextEntries);');
  final slowRefresh=code.indexOf('await _m467RefreshHomeAccounts();',assign);
  expect(invalidate,greaterThan(fastReturn));
  expect(assign,greaterThan(invalidate));
  expect(slowRefresh,greaterThan(assign));
  expect(code,isNot(contains('unawaited(_m467RefreshHomeAccounts());')));
 });

 test('M1008 account choice and monthly summary read same verified IDs, '
  'not inferred sender or an unverified all-time balance',(){
  expect(account,contains('final scopedIds=verified.entryIds;'));
  expect(account,contains('_m684ScopedEntryIds=scopedIds;'));
  expect(account,contains('return _m684Periods.byIds(ids);'));
  expect(account,contains('return _m940LedgerReads.scopedMonth(monthRows,ids);'));
  expect(account,contains('return _m467Accounts.fold<int>(0,'));
  expect(summary,contains('final month=_m684ScopedMonthEntries(now.year,now.month);'));
  expect(summary,contains('final difference=income-spent;'));
  expect(timeline,contains('verifiedEntryIds:verifiedIds,where:transactionFilter.accepts'));
  expect(timeline,contains('for(final e in fullFilteredTransactions())'));
 });
}
