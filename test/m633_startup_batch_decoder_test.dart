import 'dart:convert';
import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_large_json_decode.dart';

void main(){
 test('M633 verified startup small fields preserve JSON type and null',()async{
  final decoded=await WaffraLargeJsonDecode.parseStartupFields({
   'entries':'[{"amount":12.5,"income":true}]',
   'categories':'[{"name":"مصروف"}]',
   'empty':'null',
   'postponed':'{"first":"2026-11"}',
  });
  expect((decoded.read('entries') as List).single['amount'],12.5);
  expect((decoded.read('categories') as List).single['name'],'مصروف');
  expect(decoded.read('empty'),isNull);
  expect((decoded.read('postponed') as Map)['first'],'2026-11');
  expect(decoded.read('missing'),isNull);
 });
 test('M633 large multi-field source decodes on one worker unchanged',()async{
  final ledger=List.generate(15000,(i)=><String,Object?>{
   'id':'txn-$i','amount':i,'income':i.isEven});
  final raw=jsonEncode(ledger);
  expect(raw.length,greaterThan(WaffraLargeJsonDecode.startupAggregateIsolateThreshold));
  final decoded=await WaffraLargeJsonDecode.parseStartupFields({
   'entries':raw,'goals':'[{"saved":5}]',
   'rules':'{"bank":"expense"}',
  });
  final decodedLedger=decoded.read('entries') as List;
  expect(decodedLedger.length,ledger.length);
  expect(decodedLedger.first['id'],'txn-0');
  expect(decodedLedger.last['amount'],14999);
  expect((decoded.read('goals') as List).single['saved'],5);
  expect((decoded.read('rules') as Map)['bank'],'expense');
 });
 test('M633 corrupted one field fails closed while others remain inspectable',()async{
  final decoded=await WaffraLargeJsonDecode.parseStartupFields({
   'entries':'[broken',
   'categories':'[{"id":"other"}]',
  });
  expect(()=>decoded.read('entries'),throwsFormatException);
  expect((decoded.read('categories') as List).single['id'],'other');
 });
 test('M633 Home waits for verified balances and keeps owner/session fencing',(){
  final src=readWaffraMainSourceForContracts();
  final load=src.split(' Future<void> load()async {\n  final financeClock=')[1]
    .split(' Future<void> _refreshWidget()async{')[0];
  final app=src.split('class _WaffraAppState extends State<WaffraApp>')[1];
  final login=src.split(' Future<void> _signIn()async{')[1]
    .split(' String get maskedLastPhone{')[0];
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('final decodedStartup=await WaffraLargeJsonDecode.parseStartupFields('));
  expect(load,contains("traceHomeStep('after_batch_json_decode');"));
  expect(load.indexOf('_m467RefreshHomeAccounts()'),
    lessThan(load.indexOf('parseStartupFields(')));
  expect(load.indexOf('await (accountsLoading??_m467RefreshHomeAccounts())'),
    lessThan(load.indexOf('setState(()=>ready=true);')));
  expect(load,contains("if(!_m468VerifiedAccountsLoaded){"));
  expect(app,contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
  expect(app,contains('_m627HomeSession++;'));
  expect(app,contains('prewarmedFinanceBinding:_m631ClaimFinancePrewarm(account)'));
  expect(app,contains('if(binding!=null)await binding.close();'));
  expect(app,contains('WaffraPublicStartupPrewarm.prime();'));
  expect(login,contains('WaffraLocalPhoneCredentials.verify('));
  expect(src,isNot(contains('Widget _m622ImmediateHomeSurface()=>')));
 });
}
