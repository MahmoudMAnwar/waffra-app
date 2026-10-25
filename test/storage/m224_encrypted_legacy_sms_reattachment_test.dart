import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_legacy_sms_reattachment.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// Disposable SQLCipher-only proof; NEVER operates on an actual user vault.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const testKey='m224-reattach-encrypted-test-key-do-not-ship';
  const original='شراء عبر نقاط بيع\nAmount SAR 84.72\nالوقت ١٠:٣٥\nShop XY';
  final originalHash=WaffraEncryptedLegacySmsReattachment.bankSmsFingerprint(original);
  late Directory root;
  late File path;
  late WaffraEncryptedStore vault;
  WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(
    store:vault,experimentalEnabled:true);
  WaffraEncryptedLegacySmsReattachment repair({bool enabled=true})=>
   WaffraEncryptedLegacySmsReattachment(
    snapshot:snapshot(),writerDirectory:root,experimentalEnabled:enabled,
    verifyEncryptedSourceUnderLock:()async{
      // Rehearsal-only supplied witness, never production authorization.
      final version=await vault.customSelect(
        "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'").get();
      if(version.length!=1)throw StateError('Synthetic vault missing');
    });
  Future<void> addOldSms()async{
    await WaffraUnifiedFinanceWriter(
      snapshot:snapshot(),writerDirectory:root,experimentalEnabled:true,
    ).appendTransactions(
      records:[{
       'id':'old-entry','title':'نقاط بيع','category':'أخرى',
       'amount':84.72,'income':false,'date':'2026-10-25T10:35:00',
       'receiptPath':null,'sourceType':'sms','notes':'',
      }],
      messageHashes:[originalHash],userConfirmed:true,
    );
  }
  Future<int> attach({String text=original,String title='نقاط بيع',
    int amountMinor=8472,int? generation,bool approved=true,
    String entryId='old-entry'})async=>
    repair().attachExactOriginal(
     entryId:entryId,originalSms:text,expectedHash:originalHash,
     verifiedAmountMinor:amountMinor,verifiedIncome:false,
     confirmedTitle:title,confirmedCategory:'أخرى',
     confirmedDate:'2026-10-25T10:35:00',
     expectedGeneration:generation??(await snapshot().read()).generation,
     userConfirmed:approved,
    );

  setUp(()async{
    SharedPreferences.setMockInitialValues({'safe_setting':true});
    root=await Directory.systemTemp.createTemp('waffra-m224-old-sms-');
    path=File('${root.path}/recovery.sqlite');
    vault=WaffraEncryptedStore.openAt(path,key:testKey);
    await WaffraFreshEncryptedVaultBootstrap(
      store:vault,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    await addOldSms();
  });
  tearDown(()async{
    await vault.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  test('old ID is preserved; original multiline multilingual SMS cold-reopens exact',()async{
    final first=await snapshot().read();
    expect(first.generation,1);
    final beforeRows=jsonDecode(first.values['entries'] as String) as List;
    expect((beforeRows.single as Map)['notes'],'');
    final result=await attach();
    expect(result,2);
    await vault.close();
    vault=WaffraEncryptedStore.openAt(path,key:testKey);
    final after=await snapshot().read();
    final rows=jsonDecode(after.values['entries'] as String) as List;
    expect(rows,hasLength(1));
    final row=rows.single as Map;
    expect(row['id'],'old-entry');
    expect(row['notes'],original);
    expect(row['amount'],84.72);
    expect(row['date'],'2026-10-25T10:35:00');
    final sql=await vault.customSelect(
      "SELECT source_json,amount_minor FROM fresh_finance_entries WHERE entry_id='old-entry'"
    ).getSingle();
    expect((jsonDecode(sql.read<String>('source_json')) as Map)['notes'],original);
    expect(sql.read<int>('amount_minor'),8472);
    expect(after.values['waffra_sms_hashes_v1'],[originalHash]);
    expect(after.values.keys,first.values.keys);
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(),{'safe_setting'});
    expect(prefs.getString('entries'),isNull);
  });

  test('no confirmation or wrong parser amount/name/hash never updates either projection',()async{
    final first=await snapshot().read();
    await expectLater(attach(approved:false),throwsStateError);
    await expectLater(attach(amountMinor:8473),throwsStateError);
    await expectLater(attach(title:'مختلف'),throwsStateError);
    await expectLater(attach(text:'wrong bank SMS'),throwsStateError);
    await expectLater(attach(entryId:'missing'),throwsStateError);
    final after=await snapshot().read();
    expect(after.generation,first.generation);
    expect(after.digest,first.digest);
    expect((jsonDecode(after.values['entries'] as String) as List).single['notes'],'');
  });

  test('concurrent stale generation refuses later SMS edit without mutation',()async{
    final old=(await snapshot().read()).generation;
    await attach();
    await expectLater(attach(generation:old),throwsStateError);
    expect((await snapshot().read()).generation,old+1);
  });

  test('same source SMS cannot reattach over an already attached note',()async{
    await attach();
    await expectLater(attach(),throwsStateError);
    expect((await snapshot().read()).generation,2);
  });

  test('tampered typed SQL source prevents recovery (no silent overwrite)',()async{
    final before=await snapshot().read();
    await vault.customStatement(
      "UPDATE fresh_finance_entries SET title='different' WHERE entry_id='old-entry'");
    // Title is a projection field. Source JSON and typed totals still match;
    // caller-level required title is independently checked.
    await expectLater(attach(title:'different'),throwsStateError);
    final after=await snapshot().read();
    expect(after.digest,before.digest);
  });

  test('SQL failure rolls back typed JSON and canonical snapshot together',()async{
    final before=await snapshot().read();
    await vault.customStatement('''
CREATE TRIGGER synthetic_block_reattach BEFORE UPDATE OF source_json
ON fresh_finance_entries BEGIN SELECT RAISE(ABORT,'fixture'); END
''');
    await expectLater(attach(),throwsA(anything));
    final after=await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    final sql=await vault.customSelect(
      "SELECT source_json FROM fresh_finance_entries WHERE entry_id='old-entry'").getSingle();
    expect((jsonDecode(sql.read<String>('source_json')) as Map)['notes'],'');
  });

  test('disabled-by-default API rejects reattachment even with valid data',()async{
    await expectLater(repair(enabled:false).attachExactOriginal(
      entryId:'old-entry',originalSms:original,expectedHash:originalHash,
      verifiedAmountMinor:8472,verifiedIncome:false,
      confirmedTitle:'نقاط بيع',confirmedCategory:'أخرى',
      confirmedDate:'2026-10-25T10:35:00',
      expectedGeneration:1,userConfirmed:true,
    ),throwsStateError);
    expect((await snapshot().read()).generation,1);
  });
}
