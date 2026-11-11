import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M637 / #557: shorten the account-balance hot path after biometric
/// WITHOUT skipping SQLCipher source integrity or corrupt-schema rejection.
void main() {
 late Directory directory;
 late WaffraEncryptedStore db;
 WaffraAccountsRepository accounts() =>
   WaffraAccountsRepository(db:db,experimentalEnabled:true);

 setUp(() async {
  directory=await Directory.systemTemp.createTemp('waffra-m637-');
  db=WaffraEncryptedStore.openAt(
   File('${directory.path}/m637.sqlite'),
   key:'m637-disposable-test-sqlcipher-secret-not-production');
 });
 tearDown(() async {
  await db.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 Future<void> bootstrap() async {
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
 }

 test('M637 first verified account read installs context once; repeat balances stay authoritative',() async {
  await bootstrap();
  final initial=await accounts().balances();
  expect(initial,isEmpty);
  await accounts().createAccount(
   id:'bank',name:'Bank',kind:'bank',openingMinor:234500,
   createdIso:'2026-11-11T09:00:00',userConfirmed:true);
  for(var i=0;i<3;i++){
   final verified=await accounts().balances();
   expect(verified.length,1);
   expect(verified.single.id,'bank');
   expect(verified.single.balanceMinor,234500);
  }
  await WaffraAccountContextSchema.requireReady(db);
  final marker=await db.customSelect(
   "SELECT version FROM fresh_finance_account_context_revision "
   "WHERE slot='account_context'").getSingle();
  expect(marker.read<int>('version'),WaffraAccountContextSchema.version);
 });

 test('M637 account reads never initialize missing original encrypted finance schema',() async {
  await expectLater(accounts().balances(),throwsA(isA<StateError>()));
 });

 test('M637 installed but invalid context revision rejects balances instead of caching success',() async {
  await bootstrap();
  await WaffraAccountContextSchema.install(db);
  expect(await accounts().balances(),isEmpty);
  await db.customStatement(
   "UPDATE fresh_finance_account_context_revision "
   "SET version=999 WHERE slot='account_context'");
  await expectLater(accounts().balances(),throwsA(isA<StateError>()));
  final stillWrong=await db.customSelect(
   "SELECT version FROM fresh_finance_account_context_revision "
   "WHERE slot='account_context'").getSingle();
  expect(stillWrong.read<int>('version'),999);
 });

 test('M637 missing account-context table fails closed after previous successful read',() async {
  await bootstrap();
  await WaffraAccountContextSchema.install(db);
  expect(await accounts().balances(),isEmpty);
  await db.customStatement('DROP TABLE fresh_finance_account_sms_suffixes');
  await expectLater(accounts().balances(),throwsA(isA<StateError>()));
 });

 test('M637 source bridge keeps owner lock and witnessed snapshot while delegating validation',(){
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
    .readAsStringSync();
  final start=bridge.indexOf(
   'List<WaffraAccountBalance> balances})> readVerifiedAccounts() async {');
  final end=bridge.indexOf(
   '/// Read only existing and owner-verified encrypted attachment BLOBs.',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final hotPath=bridge.substring(start,end);
  expect(hotPath,contains('.withExclusiveAccess(() async {'));
  expect(hotPath,contains('await _requireActivatedUnderLock();'));
  expect(hotPath,contains('final current=await snapshot.read();'));
  expect(hotPath,contains('.balances();'));
  expect(hotPath,isNot(contains('WaffraAccountContextSchema.install(snapshot.store)')));
  expect(hotPath,isNot(contains('WaffraAccountsSchema.requireReady(snapshot.store)')));

  final repository=File('lib/storage/waffra_accounts_repository.dart')
    .readAsStringSync();
  final repoStart=repository.indexOf('Future<void> _ready()async{');
  final repoEnd=repository.indexOf('static void _id(String value){',repoStart);
  expect(repoStart,greaterThan(0));
  expect(repoEnd,greaterThan(repoStart));
  final ready=repository.substring(repoStart,repoEnd);
  expect(ready,contains('if(!experimentalEnabled)throw StateError('));
  expect(ready,contains('await WaffraAccountContextSchema.install(db);'));
  expect(ready,isNot(contains('await WaffraAccountsSchema.requireReady(db);')));

  final schema=File('lib/storage/waffra_account_context_schema.dart')
    .readAsStringSync();
  final schemaStart=schema.indexOf('static Future<void> install(');
  final schemaEnd=schema.indexOf('static Future<void> requireReady(',schemaStart);
  final install=schema.substring(schemaStart,schemaEnd);
  expect(install,contains('if(existing.isNotEmpty){await requireReady(db);return;}'));
  expect(install,contains('await WaffraAccountsSchema.requireReady(db);'));
  expect(install,contains('await db.transaction(()async{'));
  expect(install,contains('if(markers.isNotEmpty){await requireReady(db);return;}'));
  expect(schema,contains("PRAGMA foreign_key_check"));
 });
}
