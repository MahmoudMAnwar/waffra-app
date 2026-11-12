import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_finance_history.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_v24_sqlcipher_converter.dart';
import 'package:waffra/storage/waffra_restore_staging_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'Synthetic-Dummy-Only-616-DoNotReuse';

  Map<String, dynamic> highCardinalityV24() {
    // Reproduce historical record SHAPES / COUNTS, not any private records,
    // sender names, bank digits, notes, real dates, account IDs or amounts.
    final roots = List.generate(79, (i) => <String, Object?>{
      'id': 'r-$i', 'name': 'Synthetic root $i',
      'parentId': '', 'income': false, 'budget': 0.0,
      'alertPercent': 80, 'categoryActive': true,
    });
    final children = List.generate(977, (i) => <String, Object?>{
      'id': 'c-$i', 'name': 'Synthetic child $i',
      'parentId': 'r-${i % 79}', 'income': false, 'budget': 0.0,
      'alertPercent': 80, 'categoryActive': true,
    });
    final entries = List.generate(19, (i) => <String, Object?>{
      'id':'synthetic-616-$i',
      'title':'No real transaction', 'category':'Synthetic child',
      'amount':i>=17 ? 100.0 : 5.25,
      'income':i>=17,
      'date':'2026-10-12T10:30:00.000',
      'receiptPath':i<2 ? '/synthetic/never-present-$i.jpg' : '',
      'sourceType':i<8 ? 'manual' : 'sms',
      'notes':'', 'merchantKey':'',
      if(i<17) 'budgetId':i<9 ? 'budget-A' : 'budget-B',
    });
    final goals=List.generate(4, (i) => <String, Object?>{
      'id':'goal-$i','name':'Synthetic goal $i',
      'target':1000.0,'saved':125.0,'active':true,
      'dueDate':'2027-04-11T00:00:00.000',
    });
    final recurring=List.generate(3, (i) => <String, Object?>{
      'id':'rec-$i','title':'Synthetic recurring $i',
      'amount':9.0,'category':'Synthetic child',
      'income':false,'day':i+1,'active':true,
      'startAt':'2026-10-01T00:00:00.000',
      'linkedGoalId':'goal-$i',
    });
    return {
      'format':'waffra-backup','version':24,
      'entries':entries,
      'categories':[...children,...roots],
      'namedBudgets':[
        for(final id in const ['budget-A','budget-B'])
          {'id':id,'name':'Synthetic Budget $id',
            'parentId':'','income':false,
            'budget':500.0,'budgetActive':true,
            'alertPercent':80,'deleted':false}
      ],
      'goals':goals,'recurring':recurring,
      'challenges':<Object>[],
      'deletedCategories':<Object>[],
      'deletedGoals':<Object>[],
      'deletedRecurring':<Object>[],
      'recurringPostponed':<String, Object?>{},
      'learnedMerchants':<String, Object?>{},
      'monthlyBudget':0.0,'monthlyBudgetEnabled':false,
      'smsHashes':List<String>.generate(11,
          (i)=>i.toRadixString(16).padLeft(64,'0')),
    };
  }

  test('M616 disposable restore directory is uniquely created under app-supplied '
      'private root, and cleanup does not touch its siblings', () async {
    final root=await Directory.systemTemp.createTemp('m616-sandbox-parent-');
    try {
      final previous=await File('${root.path}/keep.txt').writeAsString('keep');
      final one=await WaffraRestoreStagingDirectory.create(
        prefix:'waffra-v24-to-v3-',explicitTestRoot:root);
      final two=await WaffraRestoreStagingDirectory.create(
        prefix:'waffra-verified-restore-preflight-',explicitTestRoot:root);
      expect(one.path,startsWith(root.path));
      expect(two.path,startsWith(root.path));
      expect(one.path,isNot(two.path));
      await one.delete(recursive:true);
      await two.delete(recursive:true);
      expect(await previous.readAsString(),'keep');
      expect(await root.list().toList(),hasLength(1));
    } finally {
      if(await root.exists())await root.delete(recursive:true);
    }
  });

  test('M616 Android and iOS use app-private cache instead of systemTemp, '
      'both production stages route through same helper', () {
    final helper=File('lib/storage/waffra_restore_staging_directory.dart')
      .readAsStringSync();
    expect(helper,contains('Platform.isAndroid || Platform.isIOS'));
    expect(helper,contains('await getTemporaryDirectory()'));
    expect(helper,contains('parent.createTemp(prefix)'));
    for(final source in [
      'lib/storage/waffra_legacy_v24_sqlcipher_converter.dart',
      'lib/storage/waffra_verified_active_restore_preflight.dart',
    ]){
      final code=File(source).readAsStringSync();
      expect(code,contains('WaffraRestoreStagingDirectory.create('));
      expect(code,isNot(contains('Directory.systemTemp.createTemp(')));
    }
    final ui=File('lib/main.dart').readAsStringSync();
    expect(ui,contains("restoreStage='V24_STAGING'"));
    expect(ui,contains("restoreStage='SQL_PREFLIGHT'"));
    expect(ui,contains("restoreStage='SQL_APPLY'"));
    expect(ui,contains(r'R616:$restoreStage'));
  });

  test('1056-category V24, two historical budgets and goal-linked recurring '
      'restore into accountless typed V3 without duplicate charge', () async {
    final candidate=await WaffraLegacyV24SqlCipherConverter.prepare(
      payload:highCardinalityV24(),password:password,
      userApprovedMissingReceipts:true);
    expect(candidate.transactionCount,19);
    expect(candidate.unavailableReceiptCount,2);
    final v3=await WaffraAccountsPortableBackupV3.verifyAndPreview(
      encryptedArchive:candidate.encryptedV3,password:password);
    expect(v3.accounts,isEmpty);
    expect(v3.links,isEmpty);
    expect(v3.transfers,isEmpty);
    expect(v3.history!['fresh_finance_categories'],hasLength(1056));
    expect(v3.history!['fresh_finance_standalone_budgets'],hasLength(2));
    expect(v3.history!['fresh_finance_standalone_allocations'],hasLength(17));
    final directory=await Directory.systemTemp.createTemp('m616-vault-');
    WaffraEncryptedStore? db;
    try {
      final file=File('${directory.path}/isolated.sqlite');
      db=WaffraEncryptedStore.openAt(file,key:'m616-disposable-synthetic-test-only');
      final result=await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
        encryptedArchive:candidate.encryptedV3,
        password:password,disposableStore:db,
        userConfirmed:true,experimentalEnabled:true);
      expect(result.transactionCount,19);
      await db.close();
      db=null;
      db=WaffraEncryptedStore.openAt(file,key:'m616-disposable-synthetic-test-only');
      final history=await WaffraAccountsFinanceHistory.capture(db);
      expect(history['fresh_finance_categories'],hasLength(1056));
      expect(history['fresh_finance_goals'],hasLength(4));
      expect(history['fresh_finance_recurring'],hasLength(3));
      expect(history['fresh_finance_standalone_allocations'],hasLength(17));
      expect(history['fresh_finance_goal_opening_balances'],hasLength(4));
      final accountLinks=await db.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_account_entry_links').getSingle();
      expect(accountLinks.read<int>('n'),0);
    } finally {
      await db?.close();
      if(await directory.exists())await directory.delete(recursive:true);
    }
  });
}
