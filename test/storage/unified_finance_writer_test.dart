import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore vault;
  const key='synthetic-unified-writer-key-32-chars';

  WaffraAtomicFinanceSnapshot currentSnapshot() =>
      WaffraAtomicFinanceSnapshot(store:vault,experimentalEnabled:true);
  WaffraUnifiedFinanceWriter writer()=>WaffraUnifiedFinanceWriter(
    writerDirectory:root,snapshot:currentSnapshot(),experimentalEnabled:true,
  );
  String digest(int n)=>n.toRadixString(16).padLeft(64,'0');
  Map<String,Object?> entry(String id,{bool income=false, num amount=9.50})=> {
    'id':id,'title':'تحويل تجريبي $id','category':income?'راتب':'طعام',
    'amount':amount,'income':income,'date':'2026-10-21T13:30:00',
    'receiptPath':null,
  };
  Future<void> prepare()async{
    await WaffraFreshEncryptedVaultBootstrap(
      store:vault,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await currentSnapshot().initializeEmpty();
  }
  Future<int> count() async {
    final data=(await currentSnapshot().read()).values;
    return (jsonDecode(data['entries'] as String? ?? '[]') as List).length;
  }

  setUp(()async{
    root=await Directory.systemTemp.createTemp('waffra-write-gate-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/finance.sqlite'),key:key,
    );
  });
  tearDown(()async{
    await vault.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  test('no user confirmation means no finance or hash writes',()async{
    await prepare();
    await expectLater(writer().appendTransactions(
      records:[entry('a')],messageHashes:[digest(1)],userConfirmed:false,
    ),throwsA(isA<StateError>()));
    expect(await count(),0);
    expect((await currentSnapshot().read()).generation,0);
  });

  test('app and standalone widget append concurrently without losing entries',
      ()async{
    await prepare();
    final results=await Future.wait([
      writer().appendTransactions(
        records:[entry('manual-app')],messageHashes:[null],userConfirmed:true,
      ),
      writer().appendTransactions(
        records:[entry('widget-sms')],messageHashes:[digest(1)],
        userConfirmed:true,
      ),
    ]);
    expect(results.map((r)=>r.saved).toList(),[1,1]);
    final state=await currentSnapshot().read();
    expect(state.generation,2);
    expect((jsonDecode(state.values['entries'] as String) as List).map(
      (x)=>(x as Map)['id'],
    ).toSet(),{'manual-app','widget-sms'});
    expect(state.values['waffra_sms_hashes_v1'],[digest(1)]);
  });

  test('duplicate SMS reports skipped and preserves finance revision',()async{
    await prepare();
    await writer().appendTransactions(
      records:[entry('first')],messageHashes:[digest(1)],
      userConfirmed:true,
    );
    final result=await writer().appendTransactions(
      records:[entry('attempted-replay')],messageHashes:[digest(1)],
      userConfirmed:true,
    );
    expect(result.saved,0);
    expect(result.skippedDuplicates,1);
    expect(result.generation,1);
    expect(await count(),1);
  });

  test('five entries confirmed together give actual income/expense counts',
      ()async{
    await prepare();
    final result=await writer().appendTransactions(
      records:[
        entry('a',income:true),entry('b'),entry('c'),
        entry('d',income:true),entry('e'),
      ],
      messageHashes:List.generate(5,(i)=>digest(i+1)),
      userConfirmed:true,
    );
    expect(result.saved,5);
    expect(result.savedIncome,2);
    expect(result.savedExpenses,3);
    expect(result.skippedDuplicates,0);
    expect(await count(),5);
    expect((await currentSnapshot().read()).generation,1);
  });

  test('error on duplicate ID rolls back entire batch and SMS hashes',()async{
    await prepare();
    await expectLater(writer().appendTransactions(
      records:[entry('duplicate'),entry('duplicate')],
      messageHashes:[digest(1),digest(2)],
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect((await currentSnapshot().read()).generation,0);
    expect(await count(),0);
    expect((await currentSnapshot().read()).values.containsKey('waffra_sms_hashes_v1'),
        false);
  });

  test('existing goals, categories and deleted items survive widget write',
      ()async{
    await prepare();
    const savedGoals='[{"id":"goal-one","name":"رحلة","target":3000,"saved":700}]';
    const deletedCategories='[]';
    final finance= <String,Object?>{
      'waffra_goals_v24':savedGoals,
      'waffra_deleted_categories_v1':deletedCategories,
      'waffra_monthly_budget_v1':350.0,
    };
    await currentSnapshot().commit(expectedGeneration:0,fullFinanceSnapshot:finance);
    await writer().appendTransactions(
      records:[entry('widget')],messageHashes:[digest(99)],
      userConfirmed:true,
    );
    final reread=(await currentSnapshot().read()).values;
    expect(reread['waffra_goals_v24'],savedGoals);
    expect(reread['waffra_deleted_categories_v1'],deletedCategories);
    expect(reread['waffra_monthly_budget_v1'],350.0);
    expect(await count(),1);
  });

  test('invalid mandatory transaction or receipt never changes SQL',()async{
    await prepare();
    for(final invalid in [
      {...entry('a'),'title':''},
      {...entry('a'),'amount':1.005},
      {...entry('a'),'receiptPath':'/legacy/receipt.jpg'},
    ]){
      await expectLater(writer().appendTransactions(
        records:[invalid],messageHashes:[null],userConfirmed:true,
      ),throwsA(anything));
    }
    expect((await currentSnapshot().read()).generation,0);
  });

  test('100 allowed but 101 rejected before writing',()async{
    await prepare();
    await expectLater(writer().appendTransactions(
      records:List.generate(101,(i)=>entry('id-$i')),
      messageHashes:List.filled(101,null),userConfirmed:true,
    ),throwsA(isA<ArgumentError>()));
    expect(await count(),0);
  });

  test('M79 freezes confirmed widget/SMS payload before awaiting source witness',
      () async {
    await prepare();
    final form = entry('confirmed', income: false, amount: 12.34);
    final submitted = <Map<String, Object?>>[form];
    final hashes = <String?>[digest(17)];
    final checkedWriter = WaffraUnifiedFinanceWriter(
      writerDirectory: root,
      snapshot: currentSnapshot(),
      experimentalEnabled: true,
      verifySourceUnderLock: () async {
        // The real Home/widget may clear the pending form or receive a new
        // bank SMS while the shared native finance lock is being acquired.
        form['title'] = 'Changed after confirmation';
        form['amount'] = 999.99;
        form['income'] = true;
        form['category'] = 'راتب';
        form['date'] = '2026-11-22T00:00:00';
        submitted.add(entry('unconfirmed-extra'));
        hashes[0] = digest(99);
        hashes.add(digest(100));
      },
    );
    final result = await checkedWriter.appendTransactions(
      records: submitted, messageHashes: hashes, userConfirmed: true,
    );
    expect(result.saved, 1);
    expect(result.savedIncome, 0);
    expect(result.savedExpenses, 1);
    final saved = await currentSnapshot().read();
    final row = (jsonDecode(saved.values['entries'] as String) as List)
        .single as Map<String, dynamic>;
    expect(row['id'], 'confirmed');
    expect(row['amount'], 12.34);
    expect(row['title'], 'تحويل تجريبي confirmed');
    expect(row['category'], 'طعام');
    expect(row['income'], false);
    expect(row['date'], '2026-10-21T13:30:00');
    expect(saved.values['waffra_sms_hashes_v1'], [digest(17)]);
    expect(saved.generation, 1);
  });

  test('M79 manual/widget append also commits normalized SQL row projections',
      () async {
    await prepare();
    final result = await writer().appendTransactions(
      records: [entry('manual', amount: 84.72), entry('salary', income: true)],
      messageHashes: [null, digest(11)], userConfirmed: true,
    );
    expect(result.saved, 2);
    final rows = await vault.customSelect(
      'SELECT entry_id, amount_minor, is_income, receipt_count, source_json '
      'FROM fresh_finance_entries ORDER BY entry_id',
    ).get();
    expect(rows.length, 2);
    expect(rows[0].read<String>('entry_id'), 'manual');
    expect(rows[0].read<int>('amount_minor'), 8472);
    expect(rows[0].read<int>('receipt_count'), 0);
    expect(jsonDecode(rows[0].read<String>('source_json'))['amount'], 84.72);
    expect(rows[1].read<String>('entry_id'), 'salary');
    expect(rows[1].read<int>('is_income'), 1);
    expect((await currentSnapshot().read()).generation, 1);
  });

  test('M79 SQL insert failure atomically rolls back both finance and SMS hashes',
      () async {
    await prepare();
    await vault.customStatement('''
CREATE TRIGGER synthetic_m79_fail_second
BEFORE INSERT ON fresh_finance_entries
WHEN NEW.entry_id='failed-row'
BEGIN
  SELECT RAISE(ABORT, 'synthetic finance row failure');
END
''');
    await expectLater(writer().appendTransactions(
      records: [entry('first-row'), entry('failed-row')],
      messageHashes: [digest(20), digest(21)], userConfirmed: true,
    ), throwsA(anything));
    final state = await currentSnapshot().read();
    expect(state.generation, 0);
    expect((jsonDecode(state.values['entries'] as String? ?? '[]') as List),
        isEmpty);
    expect(state.values.containsKey('waffra_sms_hashes_v1'), false);
    final sqlCount = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(sqlCount.read<int>('n'), 0);
  });

  test('M79 refuses equal-size split-brain snapshot and SQL row IDs',
      () async {
    await prepare();
    await writer().appendTransactions(
      records: [entry('genuine')],
      messageHashes: [digest(40)], userConfirmed: true,
    );
    await vault.customStatement(
      "UPDATE fresh_finance_entries SET entry_id='imposter' "
      "WHERE entry_id='genuine'",
    );
    await expectLater(writer().appendTransactions(
      records: [entry('must-not-save')],
      messageHashes: [digest(41)], userConfirmed: true,
    ), throwsA(isA<StateError>()));
    final state = await currentSnapshot().read();
    expect(state.generation, 1);
    expect(state.values['waffra_sms_hashes_v1'], [digest(40)]);
    expect(await count(), 1);
  });

  test('cold reopening retains user-updated balances and dedupe hashes',
      ()async{
    await prepare();
    await writer().appendTransactions(
      records:[entry('widget')],messageHashes:[digest(3)],
      userConfirmed:true,
    );
    await vault.close();
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/finance.sqlite'),key:key,
    );
    final result=await writer().appendTransactions(
      records:[entry('manual')],messageHashes:[null],userConfirmed:true,
    );
    expect(result.saved,1);
    expect(await count(),2);
    expect((await currentSnapshot().read()).values['waffra_sms_hashes_v1'],[digest(3)]);
  });
}
