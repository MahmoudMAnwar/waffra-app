import 'package:drift/drift.dart';

import 'waffra_account_details_schema.dart';
import 'waffra_encrypted_store.dart';

/// Optional encrypted V3 extension: old archives and old accounts legitimately
/// have no structured provider identity. Validate all identities BEFORE write.
abstract final class WaffraAccountDetailsBackup {
 static const maxAccounts=1000;
 static const fields=<String>{
  'account_id','provider_id','subtype','confirmed_iso',
 };

 static List<Map<String,Object?>>? validate(Object? raw,
  List<Map<String,Object?>> accounts){
  if(raw==null)return null;
  if(raw is! List||raw.length>maxAccounts){
   throw const FormatException('Invalid account identity backup collection.');
  }
  final accountKinds=<String,String>{
   for(final a in accounts)
    if(a['account_id'] is String&&a['kind'] is String)
     a['account_id'] as String:a['kind'] as String,
  };
  final used=<String>{};
  final values=<Map<String,Object?>>[];
  for(final item in raw){
   if(item is! Map||item.keys.any((k)=>k is! String)){
    throw const FormatException('Invalid account identity backup row.');
   }
   final row=Map<String,Object?>.from(item);
   if(row.keys.toSet().difference(fields).isNotEmpty||
      fields.difference(row.keys.toSet()).isNotEmpty){
    throw const FormatException('Account identity fields changed.');
   }
   final id=row['account_id'],provider=row['provider_id'],
    subtype=row['subtype'],date=row['confirmed_iso'];
   if(id is! String||id.isEmpty||id.length>128||!used.add(id)||
      provider is! String||subtype is! String||
      !accountKinds.containsKey(id)||
      !WaffraAccountDetailsSchema.valid(
       kind:accountKinds[id]!,providerId:provider,subtype:subtype)||
      date is! String||date.length>40||DateTime.tryParse(date)==null){
    throw const FormatException('Invalid or unowned account identity.');
   }
   values.add(row);
  }
  return List<Map<String,Object?>>.unmodifiable(values);
 }

 static Future<List<Map<String,Object?>>> capture(
  WaffraEncryptedStore store)async{
  if(!await WaffraAccountDetailsSchema.exists(store))return const [];
  await WaffraAccountDetailsSchema.requireReady(store);
  final rows=await store.customSelect(
   'SELECT account_id,provider_id,subtype,confirmed_iso FROM '
   'fresh_finance_account_details ORDER BY account_id').get();
  if(rows.length>maxAccounts)throw StateError(
   'Typed account backup exceeds safe bounded capacity.');
  return rows.map((row)=><String,Object?>{
   'account_id':row.read<String>('account_id'),
   'provider_id':row.read<String>('provider_id'),
   'subtype':row.read<String>('subtype'),
   'confirmed_iso':row.read<String>('confirmed_iso'),
  }).toList(growable:false);
 }

 static Future<void> restore(WaffraEncryptedStore store,
  List<Map<String,Object?>>? validated)async{
  if(validated==null||validated.isEmpty)return;
  await WaffraAccountDetailsSchema.install(store);
  for(final row in validated){
   final accountId=row['account_id']! as String;
   final kindRows=await store.customSelect(
    'SELECT kind FROM fresh_finance_money_accounts WHERE account_id=?',
    variables:[Variable.withString(accountId)]).get();
   if(kindRows.length!=1)throw StateError('Restored account identity orphan.');
   await WaffraAccountDetailsSchema.assign(store,
    accountId:accountId,
    kind:kindRows.single.read<String>('kind'),
    providerId:row['provider_id']! as String,
    subtype:row['subtype']! as String,
    confirmedIso:row['confirmed_iso']! as String);
  }
 }
}
