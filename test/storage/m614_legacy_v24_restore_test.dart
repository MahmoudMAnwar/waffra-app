import 'dart:convert';
import 'dart:io';
import '../support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_accounts_finance_history.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_v24_sqlcipher_converter.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'SyntheticOnlyPassphraseForTests-614!';

  Map<String, dynamic> synthetic({bool withPathOnlyReceipts = true}) {
    final roots = <Map<String, Object?>>[
      {'id':'expense-root','name':'مصروفات','parentId':'','income':false,'budget':0},
      {'id':'income-root','name':'دخل','parentId':'','income':true,'budget':0},
    ];
    final children = <Map<String, Object?>>[
      {'id':'expense-child','name':'تنقل','parentId':'expense-root',
       'income':false,'budget':0},
    ];
    final entries = List<Map<String, Object?>>.generate(19, (index) => {
      'id':'synthetic-entry-$index','title':'Operation $index',
      'category':index < 17 ? 'تنقل' : 'دخل',
      'amount':index < 17 ? 75.25 : 500.0,
      'income':index >= 17,
      'date':'2026-10-12T10:30:00.000',
      'sourceType':index < 8 ? 'manual' : 'sms',
      'notes':'', 'merchantKey':'',
      'receiptPath': withPathOnlyReceipts && index < 2
        ? '/synthetic/never-present/receipt-$index.jpg' : '',
      if (index < 17) 'budgetId':'legacy-budget-root',
    });
    return <String, dynamic>{
      'format':'waffra-backup','version':24,'exportedAt':'2026-11-12T12:00:00Z',
      'entries':entries,
      // Exercise unsorted source order: root parents are created first.
      'categories':[...children,...roots],
      'namedBudgets':[{
        'id':'legacy-budget-root','name':'شهري','parentId':'',
        'income':false,'budget':1900.0,'budgetActive':true,
        'alertPercent':80,
      }],
      'goals':List.generate(4, (index) => {
        'id':'goal-$index','name':'Goal $index',
        'target':1000.0,'saved':100.0,'active':true,
      }),
      'recurring':List.generate(3, (index) => {
        'id':'recurring-$index','title':'Due $index',
        'category':'تنقل','amount':80.0,'income':false,
        'day':index+1,'active':true,'startAt':'2026-10-01T00:00:00.000',
      }),
      'deletedGoals':[{
        'deletedAt':'2026-11-01T00:00:00.000',
        'goal':{'id':'deleted-goal','name':'Deleted',
                'target':100.0,'saved':1.0,'active':false},
      }],
      'deletedRecurring':<Object>[], 'deletedCategories':<Object>[],
      'challenges':<Object>[], 'recurringPostponed':<String, String>{},
      'learnedMerchants':<String, String>{},
      'monthlyBudget':0.0,'monthlyBudgetEnabled':false,
      'smsHashes':List<String>.generate(11,
        (i) => i.toRadixString(16).padLeft(64,'0')),
      'profile':{'name':'synthetic only'},
    };
  }

  test('V24 AEAD authenticated file decrypts, still requires typed migration', () async {
    final encrypted=await WaffraSecureBackup.encryptUserBackup(
      jsonEncode(synthetic(withPathOnlyReceipts:false)),password);
    final decrypted=jsonDecode(await WaffraSecureBackup.decrypt(encrypted,password));
    expect(decrypted['format'],'waffra-backup');
    expect(decrypted['entries'],hasLength(19));
    await expectLater(WaffraSecureBackup.decrypt(encrypted,'WrongPasswordExample!'),
      throwsA(anything));
  });

  test('path-only receipt references are never silently advertised as restored',
      () async {
    final data=synthetic();
    expect(WaffraLegacyV24SqlCipherConverter.unavailableReceiptCount(data),2);
    await expectLater(
      WaffraLegacyV24SqlCipherConverter.prepare(
        payload:data,password:password,userApprovedMissingReceipts:false),
      throwsA(isA<StateError>()),
    );
  });

  test('19 historical entries, budgets, goals, due dates, hash IDs and typed history '
      'survive encrypted V3 conversion and cold SQLCipher reopen', () async {
    final candidate=await WaffraLegacyV24SqlCipherConverter.prepare(
      payload:synthetic(),password:password,
      userApprovedMissingReceipts:true,
    );
    expect(candidate.transactionCount,19);
    expect(candidate.unavailableReceiptCount,2);
    final v3=await WaffraAccountsPortableBackupV3.verifyAndPreview(
      encryptedArchive:candidate.encryptedV3,password:password);
    expect(v3.accounts,isEmpty);
    expect(v3.links,isEmpty);
    expect(v3.transfers,isEmpty);
    expect(v3.history,isNotNull);
    final verifiedV2=await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive:v3.encryptedV2,password:password);
    expect(verifiedV2.receipts,isEmpty);
    final raw=jsonDecode(verifiedV2.financialSnapshot['entries'] as String) as List;
    expect(raw,hasLength(19));
    expect(raw.where((e)=>(e as Map)['receiptPath']!=''),isEmpty);
    expect(raw.where((e)=>(e as Map)['budgetId']!=null),hasLength(17));
    final base=await Directory.systemTemp.createTemp('m614-v24-test-');
    final file=File('${base.path}/destination.sqlite');
    WaffraEncryptedStore? db;
    try {
      db=WaffraEncryptedStore.openAt(file,key:'m614-physical-test-32bytes-key');
      final result=await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
        encryptedArchive:candidate.encryptedV3,password:password,
        disposableStore:db,userConfirmed:true,experimentalEnabled:true);
      expect(result.transactionCount,19);
      await db.close();
      db=null;
      db=WaffraEncryptedStore.openAt(file,key:'m614-physical-test-32bytes-key');
      final history=await WaffraAccountsFinanceHistory.capture(db);
      expect(history['fresh_finance_categories'],hasLength(3));
      expect(history['fresh_finance_goals'],hasLength(4));
      expect(history['fresh_finance_recurring'],hasLength(3));
      expect(history['fresh_finance_standalone_budgets'],hasLength(1));
      expect(history['fresh_finance_standalone_allocations'],hasLength(17));
      expect(history['fresh_finance_goal_opening_balances'],hasLength(4));
      final entries=await db.customSelect('SELECT entry_id FROM fresh_finance_entries').get();
      expect(entries,hasLength(19));
      expect((await db.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_account_entry_links'
      ).getSingle()).read<int>('n'),0);
    } finally {
      await db?.close();
      if(await base.exists())await base.delete(recursive:true);
    }
  });

  test('V24 malformed records and unknown archive versions fail closed', () async {
    final wrong=synthetic()..['version']=23;
    expect(() => WaffraLegacyV24SqlCipherConverter.unavailableReceiptCount(wrong),
      throwsFormatException);
    final invalid=synthetic()..['smsHashes']=<String>['not-a-hash'];
    await expectLater(WaffraLegacyV24SqlCipherConverter.prepare(
      payload:invalid,password:password,userApprovedMissingReceipts:true),
      throwsA(isA<FormatException>()));
  });

  test('UI routes legacy authenticated backups through separate V3 restore '
      'rather than claiming bad password', () {
    final code=readWaffraMainSourceForContracts();
    expect(code,contains('WaffraLegacyV24SqlCipherConverter.prepare('));
    expect(code,contains('encryptedArchive:restoreArchive'));
    expect(code,contains('backupDecrypted=true;'));
    expect(code,contains('كلمة مرور النسخة صحيحة'));
    expect(code,contains('الصور دي لن تنتقل'));
    expect(code,isNot(contains('externallySavedRescueConfirmed:true')));
    expect(code,isNot(contains('Waffra_Rescue_Before_Restore_')));
    expect(code,contains('preflightChecksum:result.archiveChecksum'));
  });
}
