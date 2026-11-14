import 'dart:convert';
import 'dart:io';
import '../support/waffra_main_source.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

class _M457ActivatedSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'm457_test_verified_fresh_source',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;
  String? key;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    key = null; // New disposable installation requires an absent OS key.
    dir = await Directory.systemTemp.createTemp('waffra-m457-');
    final origin = await WaffraFreshInstallSource.prepareIn(
      dir, readKey: () async => key,
      writeKey: (value) async { key = value; },
    );
    expect(origin, isNotNull);
    store = WaffraEncryptedStore.openAt(
      File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
      key: key!,
    );
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: store, snapshot: snapshot, experimentalEnabled: true,
    );
    final bridge = WaffraVerifiedEncryptedFinanceBridge(
      snapshot: snapshot, cutoverJournal: journal, writerDirectory: dir,
      allWritersRoutedVerified: true, secureKeyVerified: true,
      experimentalEnabled: true,
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _M457ActivatedSource(),
      freshInstall: origin,
      encryptedSession: WaffraEncryptedFinanceSession(
        bridge: bridge, experimentalEnabled: true,
      ),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority,
      defaultCategoriesJson: jsonEncode(
        defaultCategories().map((c) => c.toJson()).toList(),
      ),
    );
    await WaffraAccountsRepository(db:store,experimentalEnabled:true)
      .createAccount(id:'cash',name:'Test cash account',kind:'cash',
       openingMinor:0,createdIso:'2026-11-05T00:00:00Z',
       userConfirmed:true);
  });

  tearDown(() async {
    await store.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Map<String, Object?> manual(String id, bool income) => MoneyEntry(
    id:id,
    title:income?'Synthetic salary':'Synthetic groceries',
    category:defaultCategories()
        .firstWhere((item) => item.income==income&&item.isSubcategory).name,
    amount:income?1000.0:20.50,
    income:income,
    date:DateTime.utc(2026,11,5,6,30),
  ).toJson();

  test('M457 fresh SQLCipher commits manual expense then income with typed parity',
      () async {
    for (final entry in <Map<String,Object?>>[
      manual('m457-expense', false), manual('m457-income',true),
    ]) {
      final read=await authority.commitConfirmedManual(
        route: WaffraFinanceRoute.manualTransactionSave,
        record: entry, userConfirmed: true,
        selectedAccountId:'cash',
        expectedAccountGeneration:(await snapshot.read()).generation,
      );
      final list=jsonDecode(read.ledgerRaw!) as List;
      expect(list.any((x)=>x is Map&&x['id']==entry['id']), isTrue);
    }
    final records=await store.customSelect(
      'SELECT entry_id,amount_minor,is_income FROM fresh_finance_entries'
      ' ORDER BY entry_id',
    ).get();
    expect(records.length, 2);
    expect(records.map((r)=>r.read<int>('amount_minor')).toList(),[2050,100000]);
    expect(records.map((r)=>r.read<int>('is_income')).toList(),[0,1]);
    final cold=await authority.load(route:WaffraFinanceRoute.dashboardRead);
    expect(jsonDecode(cold.ledgerRaw!) as List, hasLength(2));
  });

  test('M457 previously confirmed SMS survives next manual append unchanged',
      () async {
    final sms=<String,Object?>{
      'id':'m457-sms','title':'Synthetic bank credit',
      'category':defaultCategories()
        .firstWhere((x)=>x.income&&x.isSubcategory).name,
      'amount':125.0,'income':true,'date':'2026-11-05T06:00:00.000Z',
      'sourceType':'sms', 'notes':'SYNTHETIC BANK MESSAGE - no account details',
    };
    final hash=List<String>.filled(64,'b').join();
    await authority.commitConfirmedSms(
      route:WaffraFinanceRoute.bulkSmsConfirmedSave,
      records:[sms], hashes:[hash], userConfirmed:true,
    );
    final baseline=await authority.load(
      route:WaffraFinanceRoute.manualTransactionSave);
    final priorRaw=(jsonDecode(baseline.ledgerRaw!) as List).single as Map;
    // The legacy Home UI normalizes records before serialization. That
    // normalization can alter raw SMS JSON without changing bank facts.
    // The old manual whole-ledger comparison refuses this legitimate append.
    final uiSms=MoneyEntry.fromJson(Map<String,dynamic>.from(priorRaw)).toJson();
    final expense=manual('m457-manual-after-sms',false);
    await expectLater(authority.saveCaptured(
      route:WaffraFinanceRoute.manualTransactionSave,
      baseline:baseline,
      captured:<String,Object>{'entries':jsonEncode([expense,uiSms])},
      userConfirmed:true,
    ),throwsStateError);
    final priorSnapshot=await snapshot.read();
    expect((jsonDecode(priorSnapshot.values['entries'] as String) as List),
      hasLength(1));
    final committed=await authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:expense,userConfirmed:true,
      selectedAccountId:'cash',
      expectedAccountGeneration:(await snapshot.read()).generation,
    );
    final after=jsonDecode(committed.ledgerRaw!) as List;
    expect(after,hasLength(2));
    expect(after.first,priorRaw);
    expect(after.last['id'],'m457-manual-after-sms');
    final finalSnapshot=await snapshot.read();
    expect(finalSnapshot.values['waffra_sms_hashes_v1'],[hash]);
    final sql=await store.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(sql.read<int>('n'),2);
  });

  test('M457 consent, duplicate and invalid account fail closed', () async {
    final entry=manual('m457-one',false);
    final before=await snapshot.read();
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:entry,userConfirmed:false,
    ),throwsStateError);
    expect((await snapshot.read()).digest,before.digest);

    await authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:entry,userConfirmed:true,
      selectedAccountId:'cash',
      expectedAccountGeneration:(await snapshot.read()).generation,
    );
    final good=await snapshot.read();
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:entry,userConfirmed:true,
    ),throwsStateError);
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.transactionEdit,
      record:manual('m457-wrong-route',false),userConfirmed:true,
    ),throwsStateError);
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:{...manual('m457-wrong-type',true),'sourceType':'sms'},
      userConfirmed:true,
    ),throwsStateError);
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:manual('m457-account-rejected',false),userConfirmed:true,
      selectedAccountId:'nonexistent',
      expectedAccountGeneration:good.generation,
    ),throwsStateError);
    expect((await snapshot.read()).digest,good.digest);
    expect((jsonDecode((await authority.load(
      route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List),hasLength(1));
  });

  test('M466 attached manual expense preserves existing income and links exactly once',
      () async {
    final earlier=manual('m466-before-image',true);
    await authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,record:earlier,
      userConfirmed:true,selectedAccountId:'cash',
      expectedAccountGeneration:(await snapshot.read()).generation);
    final prior=(jsonDecode((await snapshot.read()).values['entries'] as String)
      as List).single;
    final image=Uint8List.fromList([137,80,78,71,13,10,26,10,0,1,2,3]);
    final record=manual('m466-with-image',false);
    final confirmed=await authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,record:record,
      manualReceiptImages:[image],userConfirmed:true,
      selectedAccountId:'cash',
      expectedAccountGeneration:(await snapshot.read()).generation);
    final entries=jsonDecode(confirmed.ledgerRaw!) as List;
    expect(entries,hasLength(2));
    expect(entries.first,prior);
    final attached=entries.last as Map;
    expect(attached['id'],'m466-with-image');
    expect(WaffraEncryptedReceiptReference.matches(
      attached['receiptPath'] as String,'m466-with-image',0),isTrue);
    expect((attached['receiptPath'] as String).contains('/'),isTrue);
    final opened=await authority.loadEncryptedReceiptImages(
      route:WaffraFinanceRoute.receiptView,entryId:'m466-with-image');
    expect(opened,hasLength(1));
    expect(opened.single,image);
    final sql=await store.customSelect(
      "SELECT receipt_count,source_json FROM fresh_finance_entries "
      "WHERE entry_id='m466-with-image'").getSingle();
    expect(sql.read<int>('receipt_count'),1);
    expect((jsonDecode(sql.read<String>('source_json')) as Map)['receiptPath'],
      attached['receiptPath']);
    final links=await store.customSelect(
      "SELECT account_id FROM fresh_finance_account_entry_links "
      "WHERE entry_id='m466-with-image'").get();
    expect(links,hasLength(1));
    expect(links.single.read<String>('account_id'),'cash');
    final stable=(await snapshot.read()).digest;
    await expectLater(authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:manual('m466-invalid-owner',false),
      manualReceiptImages:[image],userConfirmed:true,
      selectedAccountId:'not-an-account',
      expectedAccountGeneration:(await snapshot.read()).generation),
      throwsStateError);
    expect((await snapshot.read()).digest,stable);
    expect((await authority.loadEncryptedReceiptImages(
      route:WaffraFinanceRoute.receiptView,
      entryId:'m466-with-image')).single,image);
  });

  test('M466 Home manual popup shares three choices and encrypted attachment view',(){
    final app=readWaffraMainSourceForContracts();
    expect(app,contains("Key('waffra-manual-three-modes')"));
    expect(app,contains('WaffraAccountOperation.transfer'));
    expect(app,contains("Key('m466-confirm-transfer')"));
    expect(app,contains("manualReceiptImages:images.isEmpty?null:images"));
    expect(app,contains("if(initial==null&&result.sourceType=='manual'){"));
    expect(app,contains("Image.memory(encryptedBytes[index]"));
    final start=app.indexOf("if(tab==0&&!goalsOpened)...[");
    final end=app.indexOf("]else if(goalsOpened||tab==3)...[",start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final menu=app.substring(start,end);
    expect(menu,contains("'Add manual transaction':'إضافة عملية يدوية'"));
    expect(menu, isNot(contains(
      "'Transfer between my accounts':'تحويل بين حساباتي'")));
  });

  test('M457 manual UI posts a single frozen entry without optimistic ledger',
      () {
    final app=readWaffraMainSourceForContracts();
    final start=app.indexOf('   final chosenManual=initial==null');
    final end=app.indexOf('  if(mounted)await budgetAlert(result,previousSpent);',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final flow=app.substring(start,end);
    expect(flow,contains('commitConfirmedManual('));
    expect(flow,contains('selectedAccountId:chosenManual?.ids?.single'));
    expect(flow,contains('expectedAccountGeneration:'));
    expect(flow,contains("jsonEncode(result.toJson())"));
    expect(flow.indexOf('commitConfirmedManual('),
      lessThan(flow.indexOf('final previousEntries=')));
    expect(flow,contains('await _refreshFromVerifiedFinance();'));
    expect(flow,isNot(contains('await _loadFinanceSafely();')));
    expect(flow,contains('if(initial==null&&result.sourceType=='));
    // M466: direct append ALWAYS checks the active authority under the lock,
    // rather than guessing source type from a stale Home cache. Pictures
    // follow the same source and never fall back to legacy whole-ledger save.
    expect(flow,contains('await _ensureFinanceBound();'));
    expect(flow,contains("safeRecord['receiptPath']=null;"));
    expect(flow,contains('manualReceiptImages:images.isEmpty?null:images'));
    expect(flow,isNot(contains(
     "(result.receiptPath==null||result.receiptPath!.isEmpty)")));
  });
}
