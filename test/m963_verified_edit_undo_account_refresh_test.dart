import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M963: Undo after a verified metadata/amount/date edit must refresh bank
/// balances. A fresh account move intentionally offers no Undo shortcut.
void main(){
 test('M963 verified Undo refreshes Home SQLCipher account views; moved '
      'money never exposes a metadata-only Undo action',(){
  final source=File('lib/waffra_home_entry_sheet.part.dart')
    .readAsStringSync();
  final begin=source.indexOf(
    'onAction:linkedHistoricalAccountInThisEdit||movedLinkedAccountInThisEdit?null:()async{');
  final end=source.indexOf(
    "if(mounted)snackSuccess(context,waffraIsEnglish?",begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final undo=source.substring(begin,end);
  expect(undo,contains(
    'if(!await _m953SaveExistingVerifiedEntry(result,initial))return;'));
  expect(undo,contains(
    'if(mounted)unawaited(_m467RefreshHomeAccounts());'));
  expect(undo,contains('WaffraRuntimeFinanceBackend.verifiedEncrypted'));
  expect(undo,contains('if(!await _persistModuleOrReload('));
  expect(source,contains(
    'actionLabel:linkedHistoricalAccountInThisEdit||movedLinkedAccountInThisEdit?null:'));
  expect(source,contains(
    'onAction:linkedHistoricalAccountInThisEdit||movedLinkedAccountInThisEdit?null:'));
 });
}
