import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore store;
  const key='waffra-encrypted-receipt-device-test-secret';
  WaffraEncryptedReceiptVault vault({bool enabled=true}) =>
      WaffraEncryptedReceiptVault(
        store:store,experimentalEnabled:enabled,
      );

  Future<void> prepare()async{
    await WaffraFreshEncryptedVaultBootstrap(
      store:store,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await store.customStatement(
      'INSERT INTO fresh_finance_entries '
      '(entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,receipt_count,source_json) VALUES(?,?,?,?,?,?,?,?)',
      ['entry-one','شراء اختبار','مأكولات',350,0,
       '2026-10-21T14:00:00',0,'{}'],
    );
  }

  Future<int> receiptCount()async{
    final row=await store.customSelect(
      "SELECT receipt_count FROM fresh_finance_entries "
      "WHERE entry_id='entry-one'",
    ).getSingle();
    return row.read<int>('receipt_count');
  }

  setUp(()async{
    root=await Directory.systemTemp.createTemp('waffra-receipt-bytes-');
    store=WaffraEncryptedStore.openAt(
      File('${root.path}/receipt.sqlite'),key:key,
    );
  });
  tearDown(()async{
    await store.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  test('two receipts are encrypted atomically with their transaction',()async{
    await prepare();
    await vault().attachNewBatch(entryId:'entry-one',images:[
      Uint8List.fromList([2,40,60,80]),
      Uint8List.fromList([4,15,25,35,45]),
    ]);
    final receipts=await vault().readAll('entry-one');
    expect(receipts,hasLength(2));
    expect(receipts.first.position,0);
    expect(receipts.last.position,1);
    expect(receipts.first.bytes,[2,40,60,80]);
    expect(receipts.last.bytes,[4,15,25,35,45]);
    expect(receipts.first.safeName,endsWith('.bin'));
    expect(await receiptCount(),2);
  });

  test('cold reopen decrypts identical images but database has no SQLite header',
      ()async{
    await prepare();
    await vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([1,2,3,4,5])],
    );
    await store.close();
    final file=File('${root.path}/receipt.sqlite');
    final prefix=await file.openRead(0,16).toList();
    expect(prefix.expand((x)=>x).toList(),
        isNot([83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0]));
    store=WaffraEncryptedStore.openAt(file,key:key);
    final stored=await vault().readAll('entry-one');
    expect(stored.single.bytes,[1,2,3,4,5]);
    expect(await receiptCount(),1);
  });

  test('missing transaction and empty image do not create partial data',()async{
    await prepare();
    await expectLater(vault().attachNewBatch(
      entryId:'unknown',images:[Uint8List.fromList([1])],
    ),throwsA(isA<StateError>()));
    await expectLater(vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List(0)],
    ),throwsA(isA<ArgumentError>()));
    expect(await receiptCount(),0);
    expect(await vault().readAll('entry-one'),isEmpty);
  });

  test('a second image batch cannot silently overwrite prior bytes',()async{
    await prepare();
    await vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([12,13])],
    );
    await expectLater(vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([20,21])],
    ),throwsA(isA<StateError>()));
    expect((await vault().readAll('entry-one')).single.bytes,[12,13]);
    expect(await receiptCount(),1);
  });

  test('tampered blob fails checksum verification rather than showing it',()async{
    await prepare();
    await vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([10,20])],
    );
    await store.customStatement(
      "UPDATE fresh_finance_receipt_blobs "
      "SET encrypted_blob=? WHERE entry_id='entry-one'",
      [Uint8List.fromList([11,21])],
    );
    await expectLater(
      vault().readAll('entry-one'),throwsA(isA<StateError>()),
    );
  });

  test('receipt count mismatch refuses incomplete results',()async{
    await prepare();
    await vault().attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([5])],
    );
    await store.customStatement(
      "UPDATE fresh_finance_entries SET receipt_count=2 "
      "WHERE entry_id='entry-one'",
    );
    await expectLater(vault().readAll('entry-one'),
        throwsA(isA<StateError>()));
  });

  test('safely rejects too many receipts and oversized bytes',()async{
    await prepare();
    await expectLater(vault().attachNewBatch(
      entryId:'entry-one',
      images:List.generate(11,(_) => Uint8List.fromList([1])),
    ),throwsA(isA<ArgumentError>()));
    await expectLater(vault().attachNewBatch(
      entryId:'entry-one',images:[
        Uint8List(WaffraEncryptedReceiptVault.maxReceiptBytes+1),
      ],
    ),throwsA(isA<ArgumentError>()));
    expect(await receiptCount(),0);
  });

  test('verified image replacement survives cold reopen and keeps count', () async {
    await prepare();
    await vault().attachNewBatch(entryId: 'entry-one', images: [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5, 6]),
    ]);
    final prior = await vault().readAll('entry-one');
    await vault().replaceExistingImage(
      entryId: 'entry-one', position: 0,
      image: Uint8List.fromList([7, 8, 9]),
      expectedSha256: prior.first.sha256Hex,
    );
    expect(await receiptCount(), 2);
    expect((await vault().readAll('entry-one'))[1].bytes, [4, 5, 6]);
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/receipt.sqlite'), key: key,
    );
    final recovered = await vault().readAll('entry-one');
    expect(recovered[0].bytes, [7, 8, 9]);
    expect(recovered[1].bytes, [4, 5, 6]);
  });

  test('stale digest fails closed without overwriting existing bytes', () async {
    await prepare();
    await vault().attachNewBatch(
      entryId: 'entry-one', images: [Uint8List.fromList([1, 2])],
    );
    await expectLater(vault().replaceExistingImage(
      entryId: 'entry-one', position: 0,
      image: Uint8List.fromList([3, 4]),
      expectedSha256: '0' * 64,
    ), throwsStateError);
    expect((await vault().readAll('entry-one')).single.bytes, [1, 2]);
  });

  test('invalid replacement never changes receipt count or bytes', () async {
    await prepare();
    await vault().attachNewBatch(
      entryId: 'entry-one', images: [Uint8List.fromList([11])],
    );
    final old = (await vault().readAll('entry-one')).single;
    await expectLater(vault().replaceExistingImage(
      entryId: 'entry-one', position: 1,
      image: Uint8List.fromList([12]),
      expectedSha256: old.sha256Hex,
    ), throwsStateError);
    await expectLater(vault().replaceExistingImage(
      entryId: 'entry-one', position: 0,
      image: Uint8List(0),
      expectedSha256: old.sha256Hex,
    ), throwsArgumentError);
    expect(await receiptCount(), 1);
    expect((await vault().readAll('entry-one')).single.bytes, [11]);
  });

  test('receipt writing remains disabled by default',()async{
    await prepare();
    await expectLater(vault(enabled:false).attachNewBatch(
      entryId:'entry-one',images:[Uint8List.fromList([1,2])],
    ),throwsA(isA<StateError>()));
    expect(await receiptCount(),0);
  });

  test('input buffer mutations cannot change persisted attachment data',
      ()async{
    await prepare();
    final original=Uint8List.fromList([6,7,8]);
    await vault().attachNewBatch(entryId:'entry-one',images:[original]);
    original[0]=99;
    expect((await vault().readAll('entry-one')).single.bytes,[6,7,8]);
  });
}
