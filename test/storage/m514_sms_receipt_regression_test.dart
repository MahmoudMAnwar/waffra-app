import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _Activated extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'm514_disposable_verified_source',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore db;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;
  String? key;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    key = null;
    root = await Directory.systemTemp.createTemp('m514-receipt-');
    final origin = await WaffraFreshInstallSource.prepareIn(
      root,
      readKey: () async => key,
      writeKey: (value) async { key = value; },
    );
    expect(origin, isNotNull);
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
      key: key!,
    );
    snapshot = WaffraAtomicFinanceSnapshot(
      store: db, experimentalEnabled: true);
    final journal = WaffraEncryptedCutoverJournal(
      store: db, snapshot: snapshot, experimentalEnabled: true);
    final bridge = WaffraVerifiedEncryptedFinanceBridge(
      snapshot: snapshot, cutoverJournal: journal, writerDirectory: root,
      allWritersRoutedVerified: true, secureKeyVerified: true,
      experimentalEnabled: true);
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Activated(), freshInstall: origin,
      encryptedSession: WaffraEncryptedFinanceSession(
        bridge: bridge, experimentalEnabled: true),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority,
      defaultCategoriesJson: jsonEncode(
        defaultCategories().map((category)=>category.toJson()).toList()),
    );
    await WaffraAccountsRepository(db:db,experimentalEnabled:true)
      .createAccount(id:'m514-money',name:'Test verified bank',
        kind:'bank',openingMinor:0,createdIso:'2026-11-07T00:00:00Z',
        userConfirmed:true);
  });

  tearDown(() async {
    await db.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  Map<String,Object?> expense(String id,{bool sms=true}) => MoneyEntry(
    id:id,title:'Synthetic SMS service',amount:276,income:false,
    category:defaultCategories().firstWhere(
      (x)=>!x.income&&x.isSubcategory).name,
    date:DateTime.utc(2026,11,7,8,12),
    sourceType:sms?'sms':'manual',
    notes:sms?'Test bank message: Purchase SAR 276':'',
  ).toJson();

  const hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final picture=Uint8List.fromList([1,2,3,4,90,91,92,93]);

  test('M514: newly reviewed SMS and manual expense share same encrypted receipt writer', () async {
    final manual = expense('m514-manual',sms:false);
    final committedManual = await authority.commitConfirmedManual(
      route:WaffraFinanceRoute.manualTransactionSave,
      record:manual,userConfirmed:true,
      manualReceiptImages:[picture],
      selectedAccountId:'m514-money',
      expectedAccountGeneration:(await snapshot.read()).generation);
    expect((jsonDecode(committedManual.ledgerRaw!) as List),hasLength(1));
    final sms = expense('m514-sms');
    final result=await authority.commitConfirmedSms(
      route:WaffraFinanceRoute.bulkSmsConfirmedSave,
      records:[sms],hashes:[hash],userConfirmed:true,
      reviewedSmsReceiptImages:[picture],
      selectedAccountIds:['m514-money'],
      expectedAccountGeneration:(await snapshot.read()).generation);
    expect(result.saved,1);
    final ledger=jsonDecode(result.current.ledgerRaw!) as List;
    expect(ledger,hasLength(2));
    for(final id in ['m514-manual','m514-sms']){
      final row=ledger.singleWhere((r)=>r['id']==id);
      expect((row['receiptPath'] as String).isNotEmpty,isTrue);
      final parts=await WaffraEncryptedReceiptVault(
        store:db,experimentalEnabled:true).readAll(id);
      expect(parts,hasLength(1));
      expect(parts.single.bytes,picture);
    }
    final rows=await db.customSelect(
      'SELECT entry_id,receipt_count FROM fresh_finance_entries').get();
    expect(rows.length,2);
    expect(rows.every((r)=>r.read<int>('receipt_count')==1),isTrue);
    expect(result.current.finance.getStringList('waffra_sms_hashes_v1'),[hash]);
  });

  test('M514: attaching first receipt to saved SMS does not charge again or change hash', () async {
    final sms=expense('m514-existing');
    final before=await authority.commitConfirmedSms(
      route:WaffraFinanceRoute.bulkSmsConfirmedSave,
      records:[sms],hashes:[hash],userConfirmed:true,
      selectedAccountIds:['m514-money'],
      expectedAccountGeneration:(await snapshot.read()).generation);
    expect(before.saved,1);
    final hashBefore=before.current.finance.getStringList('waffra_sms_hashes_v1');
    final oldLedger=jsonDecode(before.current.ledgerRaw!) as List;
    expect(oldLedger,hasLength(1));
    expect(oldLedger.single['receiptPath'],anyOf(isNull,''));
    final after=await authority.attachReceiptsToExisting(
      entryId:'m514-existing',expectedOriginal:sms,
      images:[picture],userConfirmed:true);
    final ledger=jsonDecode(after.ledgerRaw!) as List;
    expect(ledger,hasLength(1));
    expect(ledger.single['amount'],276);
    expect(ledger.single['receiptPath'],isA<String>());
    expect(after.finance.getStringList('waffra_sms_hashes_v1'),hashBefore);
    final sql=await db.customSelect(
      'SELECT amount_minor,receipt_count FROM fresh_finance_entries '
      "WHERE entry_id='m514-existing'").get();
    expect(sql,hasLength(1));
    expect(sql.single.read<int>('amount_minor'),27600);
    expect(sql.single.read<int>('receipt_count'),1);
    expect((await WaffraEncryptedReceiptVault(
      store:db,experimentalEnabled:true).readAll('m514-existing'))
      .single.bytes,picture);
    final digestBefore=(await snapshot.read()).digest;
    await expectLater(authority.attachReceiptsToExisting(
      entryId:'m514-existing',expectedOriginal:sms,
      images:[picture],userConfirmed:true),throwsStateError);
    expect((await snapshot.read()).digest,digestBefore);
  });

  test('M514: invalid empty attachment fails without finance or SMS hash mutation', () async {
    final sms=expense('m514-rejected');
    final before=await snapshot.read();
    await expectLater(authority.commitConfirmedSms(
      route:WaffraFinanceRoute.bulkSmsConfirmedSave,
      records:[sms],hashes:[hash],userConfirmed:true,
      reviewedSmsReceiptImages:[Uint8List(0)],
      selectedAccountIds:['m514-money'],
      expectedAccountGeneration:before.generation),throwsStateError);
    expect((await snapshot.read()).digest,before.digest);
  });
}
