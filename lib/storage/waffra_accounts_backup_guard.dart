import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// Account balances and transfers are NOT included in portable backup V2.
/// Until an account-aware, authenticated backup/restore version is certified,
/// exporting a V2 archive with real accounts would permanently lose money.
abstract final class WaffraAccountsPortableV2Guard {
 static Future<void> refuseUnrestorableAccounts(WaffraEncryptedStore db)async{
  final marker=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' "
   "AND name='fresh_finance_account_revision'").get();
  if(marker.isEmpty){
   // A half-created accounts schema must never be mistaken for no accounts.
   for(final table in WaffraAccountsSchema.tables){
    final exists=await db.customSelect(
     "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
     variables:[Variable.withString(table)]).get();
    if(exists.isNotEmpty)throw StateError(
     'Partial account domain cannot be included in portable V2 backup.');
   }
   return;
  }
  await WaffraAccountsSchema.requireReady(db);
  for(final table in WaffraAccountsSchema.tables){
   final count=await db.customSelect(
    'SELECT count(*) AS total FROM '+table).getSingle();
   if(count.read<int>('total')!=0)throw StateError(
    'Account balances/transfers require account-aware encrypted backup and restore.');
  }
 }
}
