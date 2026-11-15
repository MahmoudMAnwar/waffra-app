import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M944 axis 3: all finance rows live in a disposable encrypted SQLCipher DB.
/// These checks do not decrypt, read or alter an owner's personal backup.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M944 replayed transfers never post twice or change net worth on reopen',
  ()async{
   final directory=await Directory.systemTemp.createTemp('m944-replay-');
   final path=File(directory.path+'/finance.sqlite');
   const key='m944-disposable-replay-only';
   const time='2026-11-15T06:00:00Z';
   WaffraEncryptedStore? store;
   try{
    store=WaffraEncryptedStore.openAt(path,key:key);
    await WaffraFreshEncryptedVaultBootstrap(
     store:store,experimentalEnabled:true).initialize(
     decision:WaffraFirstRunDecision.freshCandidate);
    await WaffraAccountsSchema.install(store);
    WaffraAccountsRepository repo()=>WaffraAccountsRepository(
     db:store!,experimentalEnabled:true);
    await repo().createAccount(id:'a',name:'Verified Bank A',kind:'bank',
     openingMinor:100000,createdIso:time,userConfirmed:true);
    await repo().createAccount(id:'b',name:'Verified Bank B',kind:'bank',
     openingMinor:250000,createdIso:time,userConfirmed:true);

    Future<int> count(String table)async=>(await store!.customSelect(
     'SELECT COUNT(*) AS n FROM '+table).getSingle()).read<int>('n');
    Future<Map<String,int>> balances()async=>({
      for(final account in await repo().balances())
       account.id:account.balanceMinor,
    });
    expect(await balances(),{'a':100000,'b':250000});
    expect(await repo().transfer(id:'payment-1',fromAccountId:'a',
     toAccountId:'b',amountMinor:7000,occurredIso:time,userConfirmed:true),
     isTrue);
    expect(await balances(),{'a':93000,'b':257000});
    expect(await repo().transfer(id:'payment-1',fromAccountId:'a',
     toAccountId:'b',amountMinor:7000,occurredIso:time,userConfirmed:true),
     isFalse,reason:'Replay of the same intent must be idempotent.');
    await expectLater(repo().transfer(id:'payment-1',fromAccountId:'a',
     toAccountId:'b',amountMinor:7001,occurredIso:time,userConfirmed:true),
     throwsStateError);
    await expectLater(repo().transfer(id:'payment-2',fromAccountId:'a',
     toAccountId:'b',amountMinor:500,occurredIso:time,userConfirmed:false),
     throwsStateError);
    await expectLater(repo().transfer(id:'payment-2',fromAccountId:'a',
     toAccountId:'a',amountMinor:500,occurredIso:time,userConfirmed:true),
     throwsArgumentError);
    await expectLater(repo().linkHistoricalEntries(
     accountId:'a',linkedIso:time,userConfirmed:true,
     verifiedMigration:true),throwsStateError,
     reason:'History cannot be counted on top of an attested opening.');

    expect(await count('fresh_finance_internal_transfers'),1);
    expect(await count('fresh_finance_entries'),0);
    expect(await count('fresh_finance_account_entry_links'),0);
    expect(await balances(),{'a':93000,'b':257000});

    // Exercise many distinct immutable transfer IDs without inventing
    // a second expense or income for either side of the transfer.
    for(var i=0;i<80;i++){
     await repo().transfer(
      id:'move-'+i.toString().padLeft(4,'0'),
      fromAccountId:i.isEven?'a':'b',
      toAccountId:i.isEven?'b':'a',
      amountMinor:500,occurredIso:time,userConfirmed:true);
    }
    final before=await balances();
    expect(before,{'a':93000,'b':257000});
    expect(before.values.fold<int>(0,(n,v)=>n+v),350000);
    expect(await count('fresh_finance_internal_transfers'),81);
    expect(await count('fresh_finance_entries'),0);

    await store.close();
    store=null;
    store=WaffraEncryptedStore.openAt(path,key:key);
    await WaffraAccountsSchema.requireReady(store);
    expect(await balances(),before);
    expect(await count('fresh_finance_internal_transfers'),81);
    expect(await count('fresh_finance_entries'),0);
    final persisted=await store.customSelect(
     'SELECT COUNT(*) AS n FROM fresh_finance_internal_transfers '
     'WHERE amount_minor=?',variables:[const Variable.withInt(500)]
    ).getSingle();
    expect(persisted.read<int>('n'),80);
   }finally{
    await store?.close();
    if(await directory.exists())await directory.delete(recursive:true);
   }
 });
}
