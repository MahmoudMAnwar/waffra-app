import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_finance_history.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_v24_sqlcipher_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'm618-private-synthetic-regression-only-passphrase';
  const vaultKey = 'm618-test-only-durable-sqlcipher-key';

  Map<String, dynamic> syntheticV24() {
    final roots = <Map<String, Object?>>[
      for (var i=0; i<79; i++)
        {'id':'root-$i','name':'Placeholder root $i',
         'parentId':'','income':i.isOdd,'budget':0.0,
         'color':i,'icon':'synthetic','alertPercent':80,
         'budgetActive':false,'categoryActive':true,'origin':'synthetic'},
    ];
    final children = <Map<String, Object?>>[
      for (var i=0; i<977; i++)
        {'id':'child-$i','name':'Placeholder child $i',
         'parentId':'root-${i%79}','income':(i%79).isOdd,'budget':0.0,
         'color':i,'icon':'synthetic','alertPercent':80,
         'budgetActive':false,'categoryActive':true,'origin':'synthetic'},
    ];
    final transactions = <Map<String, Object?>>[
      for (var i=0; i<19; i++)
        {'id':'synthetic-transaction-$i','title':'Placeholder $i',
         'category':i<17?'Placeholder expense':'Placeholder income',
         'amount':i<17?19.25:250.0,'income':i>=17,
         'date':'2026-11-01T10:00:00.000','notes':'',
         'merchantKey':'','sourceType':i<8?'manual':'sms',
         'receiptPath':i<2?'/fake-unavailable-$i.jpg':null,
         if(i<17)'budgetId':i.isEven?'budget-one':'budget-two'},
    ];
    return {
      'format':'waffra-backup', 'version':24,
      'entries':transactions,
      // V24 user exports can contain children before roots; the converter
      // accepts this but the generated SQLCipher history becomes root-first.
      'categories':[...children,...roots],
      'namedBudgets':[
        for(final id in ['budget-one','budget-two'])
          {'id':id,'name':'Placeholder $id','budget':500.0,
           'parentId':'','income':false,'alertPercent':80,
           'budgetActive':true,'deleted':false},
      ],
      'goals':[
        for(var i=0;i<4;i++)
          {'id':'goal-$i','name':'Placeholder goal $i',
           'target':1000.0,'saved':100.0,'active':true,
           'dueDate':'2027-12-01T00:00:00.000'},
      ],
      'recurring':[
        for(var i=0;i<3;i++)
          {'id':'recurring-$i','title':'Placeholder recurring $i',
           'category':'Placeholder expense','amount':25.0,
           'income':false,'day':i+1,'active':true,
           'startAt':'2026-11-01T00:00:00.000',
           'linkedGoalId':'goal-$i'},
      ],
      'challenges':<Object>[],
      'deletedCategories':<Object>[],
      'deletedGoals':<Object>[],
      'deletedRecurring':<Object>[],
      'recurringPostponed':<String, Object?>{},
      'learnedMerchants':<String, Object?>{},
      'monthlyBudget':0.0,'monthlyBudgetEnabled':false,
      'smsHashes':[
        for(var i=0;i<11;i++)i.toRadixString(16).padLeft(64,'0'),
      ],
    };
  }

  test('M618 full authenticated V3 SQL_PREFLIGHT category history stays '
       'identical after real encrypted cold reopen', () async {
    final candidate=await WaffraLegacyV24SqlCipherConverter.prepare(
      payload:syntheticV24(),password:password,
      userApprovedMissingReceipts:true);
    final v3=await WaffraAccountsPortableBackupV3.verifyAndPreview(
      encryptedArchive:candidate.encryptedV3,password:password);
    expect(v3.accounts,isEmpty);
    expect(v3.history!['fresh_finance_categories'],hasLength(1056));
    expect(v3.history!['fresh_finance_standalone_budgets'],hasLength(2));
    expect(v3.history!['fresh_finance_standalone_allocations'],hasLength(17));

    final root=await Directory.systemTemp.createTemp('m618-history-cold-');
    final path=File('${root.path}/reopened.sqlite');
    WaffraEncryptedStore? store;
    try {
      store=WaffraEncryptedStore.openAt(path,key:vaultKey);
      final receipt=await WaffraAccountsPortableBackupV3
          .restoreToEmptyEncryptedVault(
        encryptedArchive:candidate.encryptedV3,password:password,
        disposableStore:store,userConfirmed:true,experimentalEnabled:true);
      expect(receipt.transactionCount,19);
      var history=await WaffraAccountsFinanceHistory.capture(store);
      expect(const DeepCollectionEquality().equals(history,v3.history),
        isTrue,reason:'Warm SQLCipher V3 history must match archive row order');
      await store.close();
      store=null;
      store=WaffraEncryptedStore.openAt(path,key:vaultKey);
      history=await WaffraAccountsFinanceHistory.capture(store);
      expect(const DeepCollectionEquality().equals(history,v3.history),
        isTrue,reason:'Cold reopened V3 history must preserve the rowid order');
      expect((history['fresh_finance_categories'] as List).length,1056);
      expect((history['fresh_finance_recurring'] as List).length,3);
    } finally {
      await store?.close();
      if(await root.exists())await root.delete(recursive:true);
    }
  });

  test('M618 restore uses stable partition rather than unstable category sort',
      () {
    final code=File('lib/storage/waffra_accounts_finance_history.dart')
        .readAsStringSync();
    expect(code,contains('Stable partition'));
    expect(code,isNot(contains('List<Map<String, dynamic>>.of(recorded)..sort')));
  });
}
