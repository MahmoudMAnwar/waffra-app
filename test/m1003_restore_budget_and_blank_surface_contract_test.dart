import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1003 budget edit and historical link require explicit source consent',(){
  final src=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart').readAsStringSync();
  expect(src,contains("Key('m1003-historical-opening-exclusion')"));
  expect(src,contains('onPressed:attested?()=>Navigator.pop(dialog,true):null'));
  expect(src,contains('if(approved!=true||!attested||!sheetContext.mounted)return;'));
  expect(src,contains('historicalOpeningExcluded=attested;'));
  expect(src,contains('openingExcludesHistory:historicalOpeningExcluded'));
  expect(src,contains('linkUnassignedAccountId:canLinkExistingAccount&&'));
  expect(src,contains('editExistingAndLinkUnassigned('));
  expect(src,isNot(contains('await api.linkUnassignedEntry(entryId:initial.id')));
  expect(bridge,contains('Future<WaffraFinanceSnapshotState> editExistingAndLinkUnassigned('));
  expect(bridge,contains('WaffraAccountContextRead.attachPreviouslyUnassigned('));
  expect(bridge,contains('WaffraEncryptedEntryProjectionGuard.reconcile('));
  expect(bridge,contains('return snapshot.store.transaction(()async{'));
  expect(bridge,contains('before.generation!=baseline.generation'));
  expect(bridge,contains('before.digest!=baseline.digest'));
  expect(bridge,contains('openingExcludesHistory:openingExcludesHistory'));
  expect(bridge,contains('Historical transaction is already account-linked.'));
  expect(bridge,contains('Atomic restored edit/link read-back failed.'));
 });
 test('M1003 a verified Home recovery never exposes a blank finance screen',(){
  final shell=File('lib/waffra_home_root_shell.part.dart').readAsStringSync();
  final root=File('lib/main.dart').readAsStringSync();
  expect(shell,contains('Widget _m1003FinanceHandoffSurface()=>Scaffold('));
  expect(shell,contains('_m1003FinanceHandoffSurface():Stack(children:[Scaffold('));
  expect(shell,isNot(contains('const SizedBox.shrink():Stack(children:[Scaffold(')));
  expect(shell,contains('body:_financeLoadFailure!=null?_financialRecoveryScreen():'));
  expect(root,contains('final missingRetainedStage=beforeReady&&'));
  expect(root,contains('!showLoginScreen&&!showConsent&&!showGate&&!showCountry;'));
  expect(root,contains('if(missingRetainedStage)'));
  expect(root,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(root,contains('WaffraMandatoryBiometricGate('));
  expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
 });
}
