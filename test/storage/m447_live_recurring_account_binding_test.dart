import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
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

class _SyntheticSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source: WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode: 'm447_disposable_source_not_production');
}

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore db;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraEncryptedFinanceSession session;
 late WaffraVerifiedFinanceAuthority authority;

 const schedule=<String,Object?>{
  'id':'rent','title':'Rent','category':'Housing',
  'amount':125.50,'income':false,'day':24,
  'startAt':'2026-01-01T00:00:00','active':true,
 };
 Map<String,Object?> payment()=> <String,Object?>{
  'id':'rec_rent_2026_10','title':'Rent','category':'Housing',
  'amount':125.50,'income':false,'date':'2026-10-24T12:00:00',
  'receiptPath':null,
 };

 Future<WaffraFinanceAuthorityRead> load()=>
  authority.load(route:WaffraFinanceRoute.recurringPostingAndPostponement);

 Future<WaffraFinanceAuthorityRead> pay({
  required String account,
  WaffraFinanceAuthorityRead? baseline,
 })async{
  final verified=baseline??await load();
  return authority.saveCaptured(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   baseline:verified,
   captured:<String,Object>{
    'entries':jsonEncode([payment()]),
    'waffra_recurring_postponed_v1':'{}',
   },
   userConfirmed:true,
   selectedAccountId:account,
  );
 }

 setUp(()async{
  SharedPreferences.setMockInitialValues({
   'entries':'[]',WaffraLiveLegacyFinanceGuard.activeKey:true,
  });
  dir=await Directory.systemTemp.createTemp('waffra-m447-');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/source.sqlite'),
   key:'synthetic-disposable-m447-key-long');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  snapshot=WaffraAtomicFinanceSnapshot(
   store:db,experimentalEnabled:true);
  await snapshot.initializeEmpty();
  final first=await snapshot.commit(expectedGeneration:0,
   fullFinanceSnapshot:const <String,Object?>{'entries':'[]'});
  final journal=WaffraEncryptedCutoverJournal(
   store:db,snapshot:snapshot,experimentalEnabled:true);
  final digest=WaffraLegacyPreflight.inspect(
   const <String,Object?>{'entries':'[]'}).sourceSha256;
  await journal.prepare(sourceDigest:digest,targetDigest:first.digest,
   now:DateTime.utc(2026,10,24));
  await journal.verify(now:DateTime.utc(2026,10,24));
  await journal.acknowledgeExternalActivation(
   externalMarkerVerified:true,allWritersRouted:true,
   now:DateTime.utc(2026,10,24));
  session=WaffraEncryptedFinanceSession(
   experimentalEnabled:true,
   bridge:WaffraVerifiedEncryptedFinanceBridge(
    snapshot:snapshot,cutoverJournal:journal,
    writerDirectory:dir,experimentalEnabled:true,
    allWritersRoutedVerified:true,secureKeyVerified:true,
   ),
  );
  authority=WaffraVerifiedFinanceAuthority(
   sourceGuard:_SyntheticSource(),encryptedSession:session,
   encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
   verifiedKeyRecoveryInDevice:true,
   audit:WaffraFinanceRouteAudit(
    verifiedRoutes:WaffraFinanceRoute.values.toSet(),
    keyRecoveryVerified:true,twoWitnessRecoveryVerified:true,
    receiptRollbackVerified:true,backupRestoreVerified:true,
    crossEngineLockVerified:true,legacyParityVerified:true,
   ),
  );
  final baseline=await session.loadForDashboardOrWidget();
  await session.saveChangedFields(baseline:baseline,
   changedValues:<String,Object?>{'waffra_recurring_v24':jsonEncode([schedule])});
  final latest=await session.loadForDashboardOrWidget();
  await session.bridge.commitVerifiedAccountChange<void>(
   baseline:latest,userConfirmed:true,initializeSchema:true,
   change:(accounts)async{
    await accounts.createAccount(
     id:'bank',name:'Bank',kind:'bank',openingMinor:30000,
     createdIso:'2026-10-24T08:00:00',userConfirmed:true);
   });
 });

 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('M447 actual finance authority posts recurring and its SAR account link atomically',()async{
  final before=await load();
  final committed=await pay(account:'bank',baseline:before);
  expect(jsonDecode(committed.ledgerRaw!),hasLength(1));
  final rows=await db.customSelect(
   'SELECT entry_id,account_id FROM fresh_finance_account_entry_links').get();
  expect(rows,hasLength(1));
  expect(rows.single.read<String>('entry_id'),'rec_rent_2026_10');
  expect(rows.single.read<String>('account_id'),'bank');
  final balances=await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances();
  expect(balances.single.balanceMinor,17450);
  await expectLater(pay(account:'bank'),throwsStateError);
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
   .read<int>('n'),1);
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_account_entry_links').getSingle())
   .read<int>('n'),1);
 });

 test('M447 invalid or archived account cannot partially post recurring expense',()async{
  await expectLater(pay(account:'unknown'),throwsStateError);
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
   .read<int>('n'),0);
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_account_entry_links').getSingle())
   .read<int>('n'),0);
 });

 test('M447 stale account revision blocks recurring before money changes',()async{
  final baseline=await load();
  final verified=await session.loadForDashboardOrWidget();
  await session.bridge.commitVerifiedAccountChange<void>(
   baseline:verified,userConfirmed:true,
   change:(accounts)=>accounts.renameAccount(
    id:'bank',name:'Updated bank',userConfirmed:true),
  );
  await expectLater(pay(account:'bank',baseline:baseline),throwsStateError);
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
   .read<int>('n'),0);
  expect((await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .balances()).single.balanceMinor,30000);
 });
}
