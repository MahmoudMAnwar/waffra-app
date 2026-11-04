import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../waffra_secure_backup.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

/// Authenticated account-aware envelope. V2 remains untouched for old backups.
/// The inner V2 contains the full finance snapshot and receipt bytes, while
/// V3 adds SQLCipher-only accounts, associations and internal transfers.
class WaffraAccountsBackupV3Preview {
 const WaffraAccountsBackupV3Preview({
  required this.encryptedV2,required this.accounts,
  required this.links,required this.transfers,
 });
 final String encryptedV2;
 final List<Map<String,Object?>> accounts,links,transfers;
}

abstract final class WaffraAccountsPortableBackupV3 {
 static const format='waffra-accounts-portable';
 static const version=3;
 static const maxAccounts=1000,maxLinks=100000,maxTransfers=100000;
 static const maxEncryptedCharacters=150*1024*1024;
 static const _accountFields=<String>{
  'account_id','label','kind','currency','opening_minor','archived','created_iso'
 };
 static const _linkFields=<String>{'entry_id','account_id','confirmed_iso'};
 static const _transferFields=<String>{
  'transfer_id','from_account_id','to_account_id',
  'amount_minor','occurred_iso','note'
 };

 static Future<Map<String,Object?>> capture(WaffraEncryptedStore store)async{
  await WaffraAccountsSchema.requireReady(store);
  final accounts=await store.customSelect(
   'SELECT account_id,label,kind,currency,opening_minor,archived,created_iso '
   'FROM fresh_finance_money_accounts ORDER BY account_id').get();
  final links=await store.customSelect(
   'SELECT entry_id,account_id,confirmed_iso '
   'FROM fresh_finance_account_entry_links ORDER BY entry_id').get();
  final transfers=await store.customSelect(
   'SELECT transfer_id,from_account_id,to_account_id,amount_minor,occurred_iso,note '
   'FROM fresh_finance_internal_transfers ORDER BY transfer_id').get();
  if(accounts.length>maxAccounts||links.length>maxLinks||
     transfers.length>maxTransfers){
   throw StateError('Account backup exceeds supported bounded capacity.');
  }
  return <String,Object?>{
   'accounts':accounts.map((r)=><String,Object?>{
    'account_id':r.read<String>('account_id'),
    'label':r.read<String>('label'),
    'kind':r.read<String>('kind'),
    'currency':r.read<String>('currency'),
    'opening_minor':r.read<int>('opening_minor'),
    'archived':r.read<int>('archived'),
    'created_iso':r.read<String>('created_iso'),
   }).toList(growable:false),
   'links':links.map((r)=><String,Object?>{
    'entry_id':r.read<String>('entry_id'),
    'account_id':r.read<String>('account_id'),
    'confirmed_iso':r.read<String>('confirmed_iso'),
   }).toList(growable:false),
   'transfers':transfers.map((r)=><String,Object?>{
    'transfer_id':r.read<String>('transfer_id'),
    'from_account_id':r.read<String>('from_account_id'),
    'to_account_id':r.read<String>('to_account_id'),
    'amount_minor':r.read<int>('amount_minor'),
    'occurred_iso':r.read<String>('occurred_iso'),
    'note':r.read<String>('note'),
   }).toList(growable:false),
  };
 }

 static List<Map<String,Object?>> _rows(
  Object? raw,Set<String> fields,int limit
 ){
  if(raw is! List||raw.length>limit){
   throw const FormatException('Malformed account backup collection.');
  }
  final result=<Map<String,Object?>>[];
  for(final rawRow in raw){
   if(rawRow is! Map || rawRow.keys.any((k)=>k is! String)){
    throw const FormatException('Invalid typed account backup row.');
   }
   final row=Map<String,Object?>.from(rawRow);
   if(row.keys.toSet().difference(fields).isNotEmpty||
      fields.difference(row.keys.toSet()).isNotEmpty){
    throw const FormatException('Account backup row field mismatch.');
   }
   result.add(row);
  }
  return result;
 }

 static bool _id(Object? value)=>value is String &&
  value.trim().isNotEmpty && value.length<=128;
 static bool _time(Object? value)=>value is String &&
  value.length<=40 && DateTime.tryParse(value)!=null;

 static void _validate(
  List<Map<String,Object?>> accounts,
  List<Map<String,Object?>> links,
  List<Map<String,Object?>> transfers,
  Set<String> ledgerIds,
 ){
  final ids=<String>{},entryIds=<String>{},transferIds=<String>{};
  for(final a in accounts){
   final id=a['account_id'];
   if(!_id(id)||!ids.add(id as String)||
      a['label'] is! String ||
      (a['label'] as String).trim().isEmpty ||
      (a['label'] as String).runes.length>80||
      !const {'cash','bank','wallet','other'}.contains(a['kind'])||
      a['currency']!='SAR'||
      a['opening_minor'] is! int || (a['opening_minor'] as int)<0||
      (a['archived']!=0 && a['archived']!=1)||
      !_time(a['created_iso'])){
    throw const FormatException('Invalid or duplicated account metadata.');
   }
  }
  for(final l in links){
   final entry=l['entry_id'],account=l['account_id'];
   if(!_id(entry)||!entryIds.add(entry as String)||
      !ledgerIds.contains(entry)||!ids.contains(account)||
      !_time(l['confirmed_iso'])){
    throw const FormatException('Orphan or duplicate account entry association.');
   }
  }
  for(final t in transfers){
   final id=t['transfer_id'];
   if(!_id(id)||!transferIds.add(id as String)||
      !ids.contains(t['from_account_id'])||
      !ids.contains(t['to_account_id'])||
      t['from_account_id']==t['to_account_id']||
      t['amount_minor'] is! int||(t['amount_minor'] as int)<=0||
      !_time(t['occurred_iso'])||
      t['note'] is! String||(t['note'] as String).runes.length>2000){
    throw const FormatException('Invalid or duplicate internal transfer.');
   }
  }
 }

 static Future<Set<String>> _ledgerIds(String encryptedV2,String password)async{
  final preview=await WaffraPortableBackupV2.verifyAndPreview(
   encryptedArchive:encryptedV2,password:password);
  final raw=preview.financialSnapshot['entries'] as String?;
  final decoded=jsonDecode(raw??'[]');
  if(decoded is! List)throw const FormatException('Invalid finance ledger.');
  final ids=<String>{};
  for(final row in decoded){
   if(row is! Map||!_id(row['id'])||!ids.add(row['id'] as String)){
    throw const FormatException('Invalid V2 ledger identities.');
   }
  }
  return ids;
 }

 /// Always call from the same verified native writer lock as finance export.
 /// No account metadata is ever written outside password-authenticated data.
 static Future<String> bundle({
  required String encryptedV2,
  required Map<String,Object?> capturedAccounts,
  required String password,
 })async{
  final accounts=_rows(capturedAccounts['accounts'],_accountFields,maxAccounts);
  final links=_rows(capturedAccounts['links'],_linkFields,maxLinks);
  final transfers=_rows(capturedAccounts['transfers'],_transferFields,maxTransfers);
  _validate(accounts,links,transfers,await _ledgerIds(encryptedV2,password));
  return WaffraSecureBackup.encrypt(jsonEncode(<String,Object?>{
   'format':format,'version':version,
   'innerV2Sha256':sha256.convert(utf8.encode(encryptedV2)).toString(),
   'innerV2':encryptedV2,
   'accounts':accounts,'links':links,'transfers':transfers,
  }),password);
 }

 static Future<WaffraAccountsBackupV3Preview> verifyAndPreview({
  required String encryptedArchive,required String password,
 })async{
  if(encryptedArchive.length>maxEncryptedCharacters ||
     !WaffraSecureBackup.hasValidEncryptedHeader(encryptedArchive)){
   throw const FormatException('Encrypted account backup header is invalid.');
  }
  final text=await WaffraSecureBackup.decrypt(encryptedArchive,password);
  final raw=jsonDecode(text);
  if(raw is! Map || raw.keys.any((k)=>k is! String)||
     raw.keys.toSet().difference(const {
      'format','version','innerV2Sha256','innerV2','accounts','links','transfers'
     }).isNotEmpty||
     raw.length!=7||raw['format']!=format||raw['version']!=version||
     raw['innerV2'] is! String||raw['innerV2Sha256'] is! String){
   throw const FormatException('Unsupported account backup format.');
  }
  final inner=raw['innerV2'] as String;
  if(sha256.convert(utf8.encode(inner)).toString()!=raw['innerV2Sha256']){
   throw const FormatException('Nested finance archive checksum mismatch.');
  }
  final accounts=_rows(raw['accounts'],_accountFields,maxAccounts);
  final links=_rows(raw['links'],_linkFields,maxLinks);
  final transfers=_rows(raw['transfers'],_transferFields,maxTransfers);
  _validate(accounts,links,transfers,await _ledgerIds(inner,password));
  return WaffraAccountsBackupV3Preview(
   encryptedV2:inner,accounts:accounts,links:links,transfers:transfers);
 }

 /// Restores ONLY into a caller-owned empty, disposable SQLCipher vault.
 /// The V2 finance+receipts and all V3 account rows share a single outer
 /// SQLite transaction. Any bad association rolls every inserted row back.
 /// Production source selection/cutover is deliberately not done here.
 static Future<void> restoreToEmptyEncryptedVault({
  required String encryptedArchive,
  required String password,
  required WaffraEncryptedStore disposableStore,
  required bool userConfirmed,
  bool experimentalEnabled=false,
 })async{
  if(!userConfirmed||!experimentalEnabled){
   throw StateError('Authenticated account restore requires approval.');
  }
  final verified=await verifyAndPreview(
   encryptedArchive:encryptedArchive,password:password);
  await disposableStore.transaction(()async{
   await WaffraPortableEncryptedVaultRestorer(
    disposableStore:disposableStore,experimentalEnabled:true,
   ).restore(encryptedArchive:verified.encryptedV2,password:password);
   await WaffraAccountsSchema.install(disposableStore);
   for(final a in verified.accounts){
    await disposableStore.customStatement(
     'INSERT INTO fresh_finance_money_accounts '
     '(account_id,label,kind,currency,opening_minor,archived,created_iso) '
     'VALUES (?,?,?,?,?,?,?)',[
      a['account_id'],a['label'],a['kind'],a['currency'],a['opening_minor'],
      a['archived'],a['created_iso'],
     ]);
   }
   for(final l in verified.links){
    await disposableStore.customStatement(
     'INSERT INTO fresh_finance_account_entry_links '
     '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',[
      l['entry_id'],l['account_id'],l['confirmed_iso'],
     ]);
   }
   for(final t in verified.transfers){
    await disposableStore.customStatement(
     'INSERT INTO fresh_finance_internal_transfers '
     '(transfer_id,from_account_id,to_account_id,amount_minor,occurred_iso,note) '
     'VALUES (?,?,?,?,?,?)',[
      t['transfer_id'],t['from_account_id'],t['to_account_id'],
      t['amount_minor'],t['occurred_iso'],t['note'],
     ]);
   }
   await WaffraAccountsSchema.requireReady(disposableStore);
  });
 }
}
