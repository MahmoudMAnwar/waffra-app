import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_finance_history.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_authoritative_widget_balance.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_v24_sqlcipher_converter.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_restored_ledger_identity_guard.dart';

/// M935 / Issue #639: synthetic-only phase-two financial acceptance.
 /// Do not use customer backups, actual SMS, private account IDs or keys here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password='m935-synthetic-only-not-a-real-user-password';

  Map<String, dynamic> legacyFixture() {
    return <String, dynamic>{
      'format':'waffra-backup', 'version':24,
      'entries':<Map<String, Object?>>[
        for(var i=0;i<19;i++)
          <String, Object?>{
            'id':'m935-synthetic-$i',
            'title':'Synthetic historical transaction $i',
            'category':i<17?'Example expense':'Example income',
            'amount':i<17?19.25:(i==17?1000.99:300.01),
            'income':i>=17,
            'date':'2026-11-01T10:00:00.000',
            'sourceType':i.isEven?'manual':'sms',
            'notes':'', 'merchantKey':'', 'receiptPath':'',
            if(i<17)'budgetId':'m935-expense-budget',
          },
      ],
      'categories':<Map<String,Object?>>[
        {'id':'m935-expense-child','name':'Example expense',
          'parentId':'m935-expense-root','income':false,'budget':0},
        {'id':'m935-expense-root','name':'Expenses',
          'parentId':'','income':false,'budget':0},
        {'id':'m935-income-root','name':'Example income',
          'parentId':'','income':true,'budget':0},
      ],
      'namedBudgets':<Map<String,Object?>>[
        {'id':'m935-expense-budget','name':'Example monthly cap',
          'parentId':'','income':false,'budget':3000.0,
          'budgetActive':true,'alertPercent':80},
      ],
      'goals':<Map<String,Object?>>[
        for(var i=0;i<2;i++)
          {'id':'m935-goal-$i','name':'Synthetic goal $i',
            'target':1000.0,'saved':75.0,'active':true},
      ],
      'recurring':<Map<String,Object?>>[
        {'id':'m935-recurring-0','title':'Synthetic due','category':'Example expense',
          'amount':25.0,'income':false,'day':5,'active':true,
          'startAt':'2026-11-01T00:00:00.000'},
      ],
      'challenges':<Object>[], 'deletedCategories':<Object>[],
      'deletedGoals':<Object>[], 'deletedRecurring':<Object>[],
      'recurringPostponed':<String,Object?>{},
      'learnedMerchants':<String,Object?>{},
      'monthlyBudget':0.0,'monthlyBudgetEnabled':false,
      'smsHashes':<String>[for(var i=0;i<11;i++) i.toRadixString(16).padLeft(64,'0')],
    };
  }

  int signedHalalas(List<dynamic> rows) => rows.fold<int>(0,(total,item){
    final entry=item as Map;
    final minor=((entry['amount'] as num)*100).round();
    return total+(entry['income']==true?minor:-minor);
  });

  test('M935 authenticated V24 -> V3 -> SQLCipher cold reopen retains '
      '19 unique source IDs, correct money and empty bank accounts on TWO '
      'disposable targets',()async{
    final source=(legacyFixture()['entries'] as List).cast<Map<String,Object?>>();
    expect(source,hasLength(19));
    expect(source.map((e)=>e['id']).toSet(),hasLength(19));
    expect(source.where((e)=>e['income']==false),hasLength(17));
    expect(source.where((e)=>e['income']==true),hasLength(2));

    // Integer halalas avoid rounding and prohibit a fake zero bank balance.
    const incomeMinor=130100,expenseMinor=32725,netMinor=97375;
    expect(signedHalalas(source),netMinor);
    final candidate=await WaffraLegacyV24SqlCipherConverter.prepare(
      payload:legacyFixture(),password:password,
      userApprovedMissingReceipts:true);
    expect(candidate.transactionCount,19);
    expect(candidate.unavailableReceiptCount,0);
    final v3=await WaffraAccountsPortableBackupV3.verifyAndPreview(
      encryptedArchive:candidate.encryptedV3,password:password);
    expect(v3.accounts,isEmpty);
    expect(v3.links,isEmpty);
    expect(v3.transfers,isEmpty);
    expect(v3.history!['fresh_finance_categories'],hasLength(3));
    expect(v3.history!['fresh_finance_goals'],hasLength(2));
    expect(v3.history!['fresh_finance_recurring'],hasLength(1));
    expect(v3.history!['fresh_finance_standalone_allocations'],hasLength(17));
    final v2=await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive:v3.encryptedV2,password:password);
    final archiveRaw=v2.financialSnapshot['entries'] as String;
    final archiveRows=jsonDecode(archiveRaw) as List<dynamic>;
    expect(WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,verifiedSnapshot:archiveRows).verifiedCount,19);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(archiveRaw),netMinor);

    final root=await Directory.systemTemp.createTemp('m935-phase-two-');
    try {
      for(var trial=0;trial<2;trial++){
        final path=File('${root.path}/isolated-device-$trial.sqlite');
        final key='m935-disposable-sqlcipher-key-$trial-not-production';
        WaffraEncryptedStore? db;
        try{
          db=WaffraEncryptedStore.openAt(path,key:key);
          final result=await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
            encryptedArchive:candidate.encryptedV3,
            password:password,disposableStore:db,
            userConfirmed:true,experimentalEnabled:true);
          expect(result.transactionCount,19);
          await db.close();
          db=null;

          // This deliberately tests a *cold* encrypted database reopen;
          // both trials are independent. It never writes to a real device.
          db=WaffraEncryptedStore.openAt(path,key:key);
          // A second attempt at restoring to the SAME non-empty vault must
          // be refused without doubling rows or changing the source digest.
          final beforeRetry=await WaffraAtomicFinanceSnapshot(
            store:db,experimentalEnabled:true).read();
          await expectLater(
            WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
              encryptedArchive:candidate.encryptedV3,
              password:password,disposableStore:db,
              userConfirmed:true,experimentalEnabled:true),
            throwsA(anything));
          final afterRetry=await WaffraAtomicFinanceSnapshot(
            store:db,experimentalEnabled:true).read();
          expect(afterRetry.generation,beforeRetry.generation);
          expect(afterRetry.digest,beforeRetry.digest);
          final sql=await db.customSelect(
            'SELECT count(*) AS n, '
            'COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0) AS inc, '
            'COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0) AS exp '
            'FROM fresh_finance_entries').getSingle();
          expect(sql.read<int>('n'),19);
          expect(sql.read<int>('inc'),incomeMinor);
          expect(sql.read<int>('exp'),expenseMinor);
          expect(sql.read<int>('inc')-sql.read<int>('exp'),netMinor);
          final rows=await db.customSelect(
            'SELECT entry_id FROM fresh_finance_entries ORDER BY entry_id').get();
          expect(rows.map((r)=>r.read<String>('entry_id')).toSet(),
            source.map((e)=>e['id'] as String).toSet());
          expect(await WaffraAccountsRepository(
            db:db,experimentalEnabled:true).balances(),isEmpty,
            reason:'Old accountless V24 entries must never become invented bank cash');
          final snapshot=await WaffraAtomicFinanceSnapshot(
            store:db,experimentalEnabled:true).read();
          final coldRaw=snapshot.values['entries'] as String;
          final coldRows=jsonDecode(coldRaw) as List<dynamic>;
          expect(WaffraRestoredLedgerIdentityGuard.verify(
            authenticatedSource:source,
            verifiedSnapshot:coldRows).verifiedCount,19);
          expect(WaffraAuthoritativeWidgetBalance.netHalalas(coldRaw),netMinor);
          expect(signedHalalas(coldRows),netMinor);
          final coldHistory=await WaffraAccountsFinanceHistory.capture(db);
          expect(const DeepCollectionEquality().equals(coldHistory,v3.history),
            isTrue,reason:'Goals, due items, categories, budgets and linkage '
              'must survive a cold reopen on both independent targets');
          expect((await db.customSelect('PRAGMA foreign_key_check').get()),isEmpty);
        } finally {
          await db?.close();
        }
      }
    } finally {
      if(await root.exists())await root.delete(recursive:true);
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('M935 duplicate / missing / changed rows fail closed, never '
      'collapse distinct same-looking transactions',(){
    final source=(legacyFixture()['entries'] as List).cast<Map<String,Object?>>();
    final twice=<Map<String,Object?>>[
      ...source,...source.map((r)=>Map<String,Object?>.from(r))];
    expect(()=>WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,verifiedSnapshot:twice),throwsStateError);
    expect(()=>WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,verifiedSnapshot:source.skip(1).toList()),
      throwsStateError);
    expect(()=>WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,
      verifiedSnapshot:[{...source.first,'amount':source.first['amount'] as double+1},
        ...source.skip(1)]),throwsStateError);
    final sameLooking=[source.first,
      {...source.first,'id':'m935-different-id'}];
    expect(WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:sameLooking,
      verifiedSnapshot:sameLooking).verifiedCount,2);
  });

  test('M935 production PDF, Home and Widget use the verified ledger '
      'and keep accountless historical net separate',(){
    final home=File('lib/waffra_home_account_tools.part.dart').readAsStringSync();
    final pdf=File('lib/waffra_home_pdf_reports.part.dart').readAsStringSync();
    final widget=File('lib/waffra_home_widget_balance.part.dart').readAsStringSync();
    expect(home,contains("restoreStage='CANONICAL_PARITY'"));
    expect(home,contains("restoreStage='HOME_PARITY'"));
    expect(home,contains('WaffraRestoredLedgerIdentityGuard.verify('));
    expect(home,contains('entries..clear()..addAll(exact)'));
    expect(home,isNot(contains('externallySavedRescueConfirmed:true')));
    expect(pdf,contains('final totalIncome=sum(items,true),totalExpenses=sum(items,false);'));
    expect(pdf,contains('if(items.isEmpty&&pdfTransfers.isEmpty&&pdfSavings.isEmpty)'));
    expect(pdf,contains('final pdfQuote=WaffraDisplayCurrency.active.value;'));
    expect(pdf,contains("throw StateError('Verified display FX rate required for PDF export.')"));
    expect(widget,contains('verified.finance.requireIntegrity();'));
    expect(widget,contains('WaffraAuthoritativeWidgetBalance.netHalalas'));
    expect(widget,contains("balance:'***',negative:false,hidden:true"));
    // This is source-contract evidence, not a rendered PDF or physical-Android
    // claim; visual PDF totals, pages and Riyal alignment require owner UAT.
  });
}
