import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';

class _SyntheticM447Source extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 })async=>const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'synthetic_m447_account_regression_only',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore db;
 late WaffraAtomicFinanceSnapshot finance;
 late WaffraVerifiedFinanceAuthority authority;
 const schedule=<String,Object?>{
  'id':'rent','title':'Rent','category':'Housing',
  'amount':125.5,'income':false,'day':24,
  'startAt':'2026-01-01T00:00:00','active':true,
 };
 Map<String,Object?> entry()=>{
  'id':'rec_rent_2026_10',
  'title':'Rent','category':'Housing','amount':125.5,
  'income':false,'date':'2026-10-24T12:00:00',
  'receiptPath':null,'sourceType':'recurring',
 };
 setUp(()async{
  SharedPreferences.setMockInitialValues({
   'entries':'[]',WaffraLiveLegacyFinanceGuard.activeKey:true,
  });
  dir=await Directory.systemTemp.createTemp('waffra-m447-account-due-');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/finance.sqlite'),
   key:'synthetic-m447-account-due-key-long-enough');
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  finance=WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
  await finance.initializeEmpty();
  final initial=await finance.commit(
   expectedGeneration:0,
   fullFinanceSnapshot:const <String,Object?>{'entries':'[]'},
  );
  final journal=WaffraEncryptedCutoverJournal(
   store:db,snapshot:finance,experimentalEnabled:true);
  final original=WaffraLegacyPreflight.inspect(
   const <String,Object?>{'entries':'[]'});
  await journal.prepare(
   sourceDigest:original.sourceSha256,targetDigest:initial.digest,
   now:DateTime.utc(2026,10,24));
  await journal.verify(now:DateTime.utc(2026,10,24));
  await journal.acknowledgeExternalActivation(
   externalMarkerVerified:true,allWritersRouted:true,
   now:DateTime.utc(2026,10,24));
  final session=WaffraEncryptedFinanceSession(
   experimentalEnabled:true,
   bridge:WaffraVerifiedEncryptedFinanceBridge(
    snapshot:finance,cutoverJournal:journal,writerDirectory:dir,
    experimentalEnabled:true,allWritersRoutedVerified:true,
    secureKeyVerified:true,
   ));
  authority=WaffraVerifiedFinanceAuthority(
   sourceGuard:_SyntheticM447Source(),
   encryptedSession:session,encryptedSqlWitnessActive:true,
   externalSourceWitnessActive:true,verifiedKeyRecoveryInDevice:true,
   audit:WaffraFinanceRouteAudit(
    verifiedRoutes:WaffraFinanceRoute.values.toSet(),
    keyRecoveryVerified:true,twoWitnessRecoveryVerified:true,
    receiptRollbackVerified:true,backupRestoreVerified:true,
    crossEngineLockVerified:true,legacyParityVerified:true,
   ),
  );
  final before=await session.loadForDashboardOrWidget();
  await session.saveChangedFields(
   baseline:before,
   changedValues:<String,Object?>{
    'waffra_recurring_v24':jsonEncode([schedule]),
   },
  );
  await WaffraAccountsSchema.install(db);
  final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  await accounts.createAccount(
   id:'bank',name:'Bank account',kind:'bank',openingMinor:20000,
   createdIso:'2026-11-04T09:00:00',userConfirmed:true);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });
 Future<WaffraFinanceAuthorityRead> post(String accountId)async{
  final baseline=await authority.load(
   route:WaffraFinanceRoute.recurringPostingAndPostponement);
  return authority.saveCaptured(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   baseline:baseline,userConfirmed:true,
   selectedAccountId:accountId,
   captured:<String,Object>{
    'entries':jsonEncode([entry()]),
    'waffra_recurring_postponed_v1':'{}',
   },
  );
 }
 Future<int> count(String name)async=>(await db.customSelect(
  'SELECT count(*) AS n FROM '+name).getSingle()).read<int>('n');
 test('M447 recurring Paid posts one SQL entry and one account link, with cash conservation',()async{
  final result=await post('bank');
  expect(jsonDecode(result.ledgerRaw!),hasLength(1));
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),1);
  final balances=await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances();
  expect(balances.single.balanceMinor,7450);
  final before=await finance.read();
  await expectLater(post('bank'),throwsStateError);
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),1);
  expect((await finance.read()).digest,before.digest);
 });
 test('M447 non-existent recurring account rolls back ledger and postponement atomically',()async{
  final before=await finance.read();
  await expectLater(post('unknown'),throwsStateError);
  expect(await count('fresh_finance_entries'),0);
  expect(await count('fresh_finance_account_entry_links'),0);
  expect((await finance.read()).digest,before.digest);
 });
}
