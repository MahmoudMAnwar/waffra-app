import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// Regression for the 56-saved/13-rejected device report. Synthetic data only:
/// a user's previously omitted SMS text cannot be reconstructed from hashes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const disposableKey='m224-test-only-56-full-sms-batch-key';
  late Directory directory;
  late File dbFile;
  late WaffraEncryptedStore db;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store:db,experimentalEnabled:true,
  );
  WaffraUnifiedFinanceWriter writer()=>WaffraUnifiedFinanceWriter(
    snapshot:snapshot(),writerDirectory:directory,experimentalEnabled:true,
  );

  String original(int n) {
    final amount=(n+1)*1.25;
    return 'عملية شراء\nمبلغ العملية: ${amount.toStringAsFixed(2)} ر.س\n'
      'Card: ****TEST\nرقم المرجع: DEMO-$n\n'
      'Merchant: Shop-$n\nExtra: عربي English / untouched\n'
      'سطر أخير خاص بالعملية $n';
  }
  String fingerprint(int n)=>n.toRadixString(16).padLeft(64,'0');

  Map<String,Object?> sms(int n) => {
    'id':'synthetic-sms-$n',
    'title':'شراء تجريبي #$n',
    'category':'أخرى',
    'amount':(n+1)*1.25,
    'income':false,
    'date':'2026-10-25T12:00:00',
    'receiptPath':null,
    'sourceType':'sms',
    'notes':original(n),
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({'waffra_language':'ar'});
    directory=await Directory.systemTemp.createTemp('m224-bulk-sms-');
    dbFile=File('${directory.path}/finance.sqlite');
    db=WaffraEncryptedStore.openAt(dbFile,key:disposableKey);
    await WaffraFreshEncryptedVaultBootstrap(
      store:db,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });

  tearDown(() async {
    await db.close();
    if(await directory.exists())await directory.delete(recursive:true);
  });

  test('M224 all 56 full bank SMS notes survive encrypted batch and cold reopen',
      () async {
    final records=List<Map<String,Object?>>.generate(56,sms);
    final fingerprints=List<String>.generate(56,fingerprint);
    final saved=await writer().appendTransactions(
      records:records,messageHashes:fingerprints,userConfirmed:true,
    );
    expect(saved.saved,56);
    expect(saved.savedExpenses,56);
    expect(saved.expenseMinor,((56*57)~/2)*125);
    final before=await snapshot().read();
    expect(before.generation,1);
    final beforeRows=jsonDecode(before.values['entries'] as String) as List;
    expect(beforeRows,hasLength(56));
    for(var n=0;n<56;n++){
      final row=beforeRows[n] as Map;
      expect(row['id'],'synthetic-sms-$n');
      expect(row['notes'],original(n));
      expect(row['amount'],(n+1)*1.25);
    }
    expect(before.values['waffra_sms_hashes_v1'],fingerprints);
    await db.close();
    db=WaffraEncryptedStore.openAt(dbFile,key:disposableKey);
    final after=await snapshot().read();
    expect(after.digest,before.digest);
    expect(after.generation,1);
    expect(after.values['entries'],before.values['entries']);
    final typed=await db.customSelect(
      'SELECT entry_id,source_json,amount_minor FROM fresh_finance_entries'
    ).get();
    expect(typed.length,56);
    final byId={for(final row in typed) row.read<String>('entry_id'):
      (jsonDecode(row.read<String>('source_json')) as Map)};
    for(var n=0;n<56;n++){
      expect(byId['synthetic-sms-$n']?['notes'],original(n));
      expect(byId['synthetic-sms-$n']?['sourceType'],'sms');
    }
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(),{'waffra_language'});
    expect(prefs.getString('entries'),isNull);
    final encryptedBytes=await dbFile.readAsBytes();
    final sample=utf8.encode(original(30));
    bool found(List<int> haystack,List<int> needle){
      for(var i=0;i<=haystack.length-needle.length;i++){
        var same=true;
        for(var j=0;j<needle.length;j++){
          if(haystack[i+j]!=needle[j]){same=false;break;}
        }
        if(same)return true;
      }
      return false;
    }
    expect(found(encryptedBytes,sample),isFalse,
      reason:'SQLCipher must not leak original bank SMS as plaintext');
  });

  test('M224 replayed 56 SMS hashes cannot create duplicate transactions',
      () async {
    await writer().appendTransactions(
      records:List.generate(56,sms),
      messageHashes:List.generate(56,fingerprint),userConfirmed:true,
    );
    final again=await writer().appendTransactions(
      records:List.generate(56,(n)=>{...sms(n),'id':'duplicate-$n'}),
      messageHashes:List.generate(56,fingerprint),userConfirmed:true,
    );
    expect(again.saved,0);
    expect(again.skippedDuplicates,56);
    expect((await snapshot().read()).generation,1);
    final typed=await db.customSelect(
      'SELECT count(*) AS total FROM fresh_finance_entries').getSingle();
    expect(typed.read<int>('total'),56);
  });

  test('M224 synthetic failure in one original-SMS row rolls back whole batch',
      () async {
    await db.customStatement('''
CREATE TRIGGER fail_broken_56_bank_sms
BEFORE INSERT ON fresh_finance_entries
WHEN NEW.entry_id='synthetic-sms-30'
BEGIN SELECT RAISE(ABORT,'synthetic only'); END
''');
    await expectLater(writer().appendTransactions(
      records:List.generate(56,sms),
      messageHashes:List.generate(56,fingerprint),userConfirmed:true,
    ),throwsA(anything));
    final state=await snapshot().read();
    expect(state.generation,0);
    expect(state.values.containsKey('waffra_sms_hashes_v1'),isFalse);
    final entries=await db.customSelect(
      'SELECT count(*) AS total FROM fresh_finance_entries').getSingle();
    expect(entries.read<int>('total'),0);
    final hashes=await db.customSelect(
      'SELECT count(*) AS total FROM fresh_finance_sms_hashes').getSingle();
    expect(hashes.read<int>('total'),0);
  });
}
