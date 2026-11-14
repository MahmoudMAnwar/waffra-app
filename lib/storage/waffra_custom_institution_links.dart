import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_account_details_schema.dart';
import 'waffra_encrypted_store.dart';

/// M943: explicitly user-owned "Other bank/wallet" child relationships.
/// The root is a concrete verified account ID, never a guessed institution
/// name. Root and child balances/ledgers remain financially independent.
abstract final class WaffraCustomInstitutionLinks {
 static const table='fresh_finance_custom_institution_links';

 static Future<bool> exists(WaffraEncryptedStore db)async{
  final rows=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
   variables:[Variable.withString(table)]).get();
  return rows.length==1;
 }

 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  await WaffraAccountDetailsSchema.requireReady(db);
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS $table(
 account_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 root_account_id TEXT NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 confirmed_iso TEXT NOT NULL,
 CHECK(account_id<>root_account_id)
)''');
 }

 static Future<void> requireReady(WaffraEncryptedStore db)async{
  if(!await exists(db))throw StateError('Custom institution link table absent.');
  final rows=await db.customSelect('PRAGMA table_info($table)').get();
  final columns=rows.map((row)=>row.read<String>('name')).toSet();
  if(columns.length!=3||
     !columns.containsAll({'account_id','root_account_id','confirmed_iso'})){
   throw StateError('Custom institution identity schema mismatch.');
  }
 }

 static Future<void> assign(WaffraEncryptedStore db,{
  required String accountId,required String rootAccountId,
  required String confirmedIso,required bool userConfirmed,
  bool allowArchivedRestore=false,
 })async{
  if(!userConfirmed||accountId.isEmpty||accountId.length>128||
     rootAccountId.isEmpty||rootAccountId.length>128||
     accountId==rootAccountId||confirmedIso.length>40||
     DateTime.tryParse(confirmedIso)==null){
   throw ArgumentError('Custom institution link requires user approval.');
  }
  await install(db);
  await db.transaction(()async{
   final rows=await db.customSelect('''
SELECT a.account_id,a.kind,a.archived,d.provider_id
FROM fresh_finance_money_accounts a
JOIN fresh_finance_account_details d ON d.account_id=a.account_id
WHERE a.account_id IN (?,?)
''',variables:[
    Variable.withString(accountId),Variable.withString(rootAccountId),
   ]).get();
   if(rows.length!=2)throw StateError('Missing verified custom bank or wallet.');
   final child=rows.singleWhere((r)=>r.read<String>('account_id')==accountId);
   final root=rows.singleWhere((r)=>r.read<String>('account_id')==rootAccountId);
   if(!const {'bank','wallet'}.contains(child.read<String>('kind'))||
      child.read<String>('kind')!=root.read<String>('kind')||
      child.read<String>('provider_id')!='other'||
      root.read<String>('provider_id')!='other'||
      (!allowArchivedRestore&&(child.read<int>('archived')!=0||
        root.read<int>('archived')!=0))){
    throw StateError('Unverified or incompatible custom institutions.');
   }
   final rootAlreadyLinked=await db.customSelect(
    'SELECT root_account_id FROM $table WHERE account_id=?',
    variables:[Variable.withString(rootAccountId)]).get();
   if(rootAlreadyLinked.isNotEmpty)throw StateError(
    'Nested or ambiguous custom institution roots are not permitted.');
   final prior=await db.customSelect(
    'SELECT root_account_id FROM $table WHERE account_id=?',
    variables:[Variable.withString(accountId)]).get();
   if(prior.isNotEmpty)throw StateError(
    'Existing custom institution affiliation cannot be silently changed.');
   await db.customStatement(
    'INSERT INTO $table(account_id,root_account_id,confirmed_iso) VALUES (?,?,?)',
    [accountId,rootAccountId,confirmedIso]);
  });
 }

 static Future<List<Map<String,Object?>>> capture(WaffraEncryptedStore db)async{
  if(!await exists(db))return const [];
  await requireReady(db);
  final rows=await db.customSelect(
   'SELECT account_id,root_account_id,confirmed_iso FROM $table '
   'ORDER BY account_id').get();
  if(rows.length>1000)throw StateError('Too many custom institution links.');
  return rows.map((r)=><String,Object?>{
   'account_id':r.read<String>('account_id'),
   'root_account_id':r.read<String>('root_account_id'),
   'confirmed_iso':r.read<String>('confirmed_iso'),
  }).toList(growable:false);
 }

 static List<Map<String,Object?>>? validateBackup(Object? raw,
  List<Map<String,Object?>> accounts,List<Map<String,Object?>>? details){
  if(raw==null)return null;
  if(raw is! List||raw.length>1000)throw const FormatException(
   'Invalid custom institution backup metadata.');
  final kinds=<String,String>{
   for(final a in accounts)
    if(a['account_id'] is String&&a['kind'] is String)
     a['account_id'] as String:a['kind'] as String,
  };
  final providers=<String,String>{
   for(final d in details??const <Map<String,Object?>>[])
    if(d['account_id'] is String&&d['provider_id'] is String)
     d['account_id'] as String:d['provider_id'] as String,
  };
  final used=<String>{};
  final validated=<Map<String,Object?>>[];
  for(final item in raw){
   if(item is! Map||item.keys.any((k)=>k is! String))throw const FormatException(
    'Invalid custom institution backup row.');
   final row=Map<String,Object?>.from(item);
   if(row.keys.toSet().difference(const {
    'account_id','root_account_id','confirmed_iso'
   }).isNotEmpty||row.length!=3)throw const FormatException(
    'Custom institution backup fields changed.');
   final id=row['account_id'],root=row['root_account_id'],when=row['confirmed_iso'];
   if(id is! String||root is! String||id==root||
      id.isEmpty||root.isEmpty||id.length>128||root.length>128||
      !used.add(id)||!const {'bank','wallet'}.contains(kinds[id])||
      kinds[id]!=kinds[root]||providers[id]!='other'||
      providers[root]!='other'||when is! String||when.length>40||
      DateTime.tryParse(when)==null){
    throw const FormatException('Unverified custom institution backup link.');
   }
   validated.add(row);
  }
  if(validated.any((row)=>used.contains(row['root_account_id']))){
   throw const FormatException('Nested custom institution links forbidden.');
  }
  return List<Map<String,Object?>>.unmodifiable(validated);
 }

 static Future<void> restore(WaffraEncryptedStore db,
  List<Map<String,Object?>>? rows)async{
  if(rows==null||rows.isEmpty)return;
  for(final row in rows){
   await assign(db,
    accountId:row['account_id']! as String,
    rootAccountId:row['root_account_id']! as String,
    confirmedIso:row['confirmed_iso']! as String,
    userConfirmed:true,allowArchivedRestore:true);
  }
 }
}
