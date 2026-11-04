import 'waffra_account_context_schema.dart';
import 'waffra_encrypted_store.dart';

/// Authenticated V3 optional extension. Old archives omit it; new archives
/// preserve goal source attribution, recurring defaults and verified bank
/// last-four mappings across a fresh encrypted restore.
abstract final class WaffraAccountContextBackup {
 static const specs=<String,Set<String>>{
  'goalSources':{'movement_id','account_id','linked_iso'},
  'recurringDefaults':{'recurring_id','account_id','changed_iso'},
  'smsSuffixes':{'account_id','last_four','confirmed_iso'},
 };
 static const caps=<String,int>{
  'goalSources':100000,'recurringDefaults':1000,'smsSuffixes':1000,
 };
 static const destinations=<String,String>{
  'goalSources':'fresh_finance_goal_account_sources',
  'recurringDefaults':'fresh_finance_recurring_account_defaults',
  'smsSuffixes':'fresh_finance_account_sms_suffixes',
 };
 static const columns=<String,String>{
  'goalSources':'movement_id,account_id,linked_iso',
  'recurringDefaults':'recurring_id,account_id,changed_iso',
  'smsSuffixes':'account_id,last_four,confirmed_iso',
 };

 static Map<String,List<Map<String,Object?>>>? validate(
  Object? raw,List<Map<String,Object?>> accounts,
 ){
  if(raw==null)return null;
  if(raw is! Map||raw.length!=specs.length||
     raw.keys.toSet().difference(specs.keys.toSet()).isNotEmpty){
   throw const FormatException('Invalid account-context envelope.');
  }
  final accountsById={
   for(final a in accounts)a['account_id']:a['kind'],
  };
  final result=<String,List<Map<String,Object?>>>{};
  for(final name in specs.keys){
   final data=raw[name];
   if(data is! List||data.length>caps[name]!){
    throw const FormatException('Unbounded context collection.');
   }
   final unique=<String>{};
   final rows=<Map<String,Object?>>[];
   for(final original in data){
    if(original is! Map||original.keys.any((x)=>x is! String)){
     throw const FormatException('Malformed context row.');
    }
    final row=Map<String,Object?>.from(original);
    if(row.keys.toSet().difference(specs[name]!).isNotEmpty||
       row.length!=specs[name]!.length){
     throw const FormatException('Context row field mismatch.');
    }
    final idKey=name=='goalSources'?'movement_id':
     name=='recurringDefaults'?'recurring_id':'account_id';
    final id=row[idKey],accountId=row['account_id'];
    final date=row[name=='goalSources'?'linked_iso':
     name=='recurringDefaults'?'changed_iso':'confirmed_iso'];
    if(id is! String||id.isEmpty||id.length>128||
       !unique.add(id)||accountId is! String||
       !accountsById.containsKey(accountId)||
       date is! String||date.length>40||DateTime.tryParse(date)==null){
     throw const FormatException('Invalid account-context reference.');
    }
    if(name=='smsSuffixes' && (
      accountsById[accountId]!='bank'||
      row['last_four'] is! String||
      !RegExp(r'^[0-9]{4}$').hasMatch(row['last_four'] as String))){
     throw const FormatException('Invalid masked bank identifier.');
    }
    rows.add(row);
   }
   result[name]=rows;
  }
  return result;
 }

 static Future<void> restore(WaffraEncryptedStore store,
  Map<String,List<Map<String,Object?>>>? context)async{
  await WaffraAccountContextSchema.install(store);
  if(context==null)return;
  for(final name in specs.keys){
   final sql='INSERT INTO '+destinations[name]!+
    ' ('+columns[name]!+') VALUES (?,?,?)';
   for(final row in context[name]!){
    final params=columns[name]!.split(',').map((column)=>
     row[column]).toList(growable:false);
    await store.customStatement(sql,params);
   }
  }
  await WaffraAccountContextSchema.requireReady(store);
 }
}
