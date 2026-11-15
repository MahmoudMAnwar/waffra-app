import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'waffra_saudi_financial_providers.dart';

/// Independent from income/expense/transfer classification rules.
/// Confirmations are saved per verified owner, on device, encrypted.
class WaffraSmsAccountEvidence {
 const WaffraSmsAccountEvidence({
  required this.sender,required this.key,required this.accountId,
  required this.confirmations,
 });
 final String sender,key,accountId;
 final int confirmations;
 Map<String,Object?> toJson()=>{
  'sender':sender,'key':key,'accountId':accountId,
  'confirmations':confirmations,
 };
 factory WaffraSmsAccountEvidence.fromJson(Map<String,dynamic> json)=>
  WaffraSmsAccountEvidence(
   sender:(json['sender']??'').toString(),
   key:(json['key']??'').toString(),
   accountId:(json['accountId']??'').toString(),
   confirmations:json['confirmations'] is int?
    json['confirmations'] as int:0,
  );
}

abstract final class WaffraSmsAccountLearning {
 static String senderKey(String sender)=>sender.trim().toLowerCase()
  .replaceAll(RegExp(r'\s+'),' ')
  .replaceAll(RegExp(r'[\u200e\u200f\u061c]'),'');
 static String? suffix4(String? value){
  if(value==null)return null;
  const arabic='٠١٢٣٤٥٦٧٨٩',persian='۰۱۲۳۴۵۶۷۸۹';
  final normalized=value.runes.map((r){
   final c=String.fromCharCode(r);
   final ar=arabic.indexOf(c),fa=persian.indexOf(c);
   return ar>=0?ar.toString():fa>=0?fa.toString():c;
  }).join();
  return RegExp(r'^[0-9]{4}$').hasMatch(normalized)?normalized:null;
 }
 static String? bankGroup(String text){
  // Only anchored, published institution aliases qualify as *suggestions*.
  // SMS wording, merchant names and arbitrary substrings never authorize
  // a new account, suffix association or financial ledger POST.
  final compact=senderKey(text).replaceAll(RegExp(r'[ _\\-]'),'')
   .replaceAll('أ','ا').replaceAll('إ','ا').replaceAll('آ','ا')
   .replaceAll('ى','ي');
  const aliases=<String,String>{
   'rajhi':'rajhi','alrajhi':'rajhi','alrajhibank':'rajhi',
   'الراجحي':'rajhi',
   'inma':'inma','alinma':'inma','alinmah':'inma','الانماء':'inma',
   'snb':'snb','alahli':'snb','الاهلي':'snb','البنكالاهليالسعودي':'snb',
   'riyad':'riyad','riyadbank':'riyad','بنكالرياض':'riyad',
   'bilad':'bilad','albilad':'bilad','البلاد':'bilad','بنكالبلاد':'bilad',
   'stcbank':'stc','stcpay':'stc','بنكاستيسي':'stc',
   'sabb':'sabb','saudiawwalbank':'sabb','البنكالسعودياالاول':'sabb',
   'البنكالسعوديالاول':'sabb',
   'anb':'anb','arabnationalbank':'anb','البنكالعربيالوطني':'anb',
   'bsf':'bsf','banquesaudifransi':'bsf','البنكالسعوديالفرنسي':'bsf',
   'saib':'saib','saudiinvestmentbank':'saib','البنكالسعوديللاستثمار':'saib',
   'jazira':'jazira','aljazira':'jazira','bankaljazira':'jazira','بنكالجزيرة':'jazira',
   'gib':'gib','gulfinternationalbank':'gib','بنكالخليجالدولي':'gib',
   'vision':'vision','visionbank':'vision','بنكفيجن':'vision',
   'd360':'d360','d360bank':'d360',
   'barq':'barq','barqpay':'barq','برق':'barq',
   'enjazpay':'enjazpay','انجازباي':'enjazpay',
   'alinmapay':'alinmapay','الانماءباي':'alinmapay',
  };
  final id=aliases[compact]??(compact.startsWith('bank')?
   aliases[compact.substring(4)]:null);
  // The catalog, not the untrusted SMS sender, is the allowlist.
  return WaffraSaudiFinancialProviders.byId(id)==null?null:id;
 }
 /// One actual source-verified user confirmation permits exact sender+last4
 /// reuse on subsequent messages; unverified sender-only never does.
 static List<WaffraSmsAccountEvidence> confirmed(
  Iterable<WaffraSmsAccountEvidence> previous,{
  required String sender,required String accountId,String? suffix,
 }){
  final scoped=senderKey(sender);
  if(scoped.length<3||scoped.length>64||accountId.trim().isEmpty||
     bankGroup(sender)==null) return List.unmodifiable(previous);
  final endings=<String>['sender'];
  final four=suffix4(suffix);
  if(four!=null)endings.add('suffix:$four');
  final result=previous.toList(growable:true);
  for(final key in endings){
   final at=result.indexWhere((row)=>
    row.sender==scoped&&row.key==key);
   final prior=at<0?null:result.removeAt(at);
   result.add(WaffraSmsAccountEvidence(
    sender:scoped,key:key,accountId:accountId,
    confirmations:prior?.accountId==accountId?
     (prior!.confirmations+1).clamp(1,2).toInt():1));
  }
  if(result.length>200)result.removeRange(0,result.length-200);
  return List.unmodifiable(result);
 }
 /// A unique verified suffix is stronger than sender-only history. Sender-only
 /// learning is usable only if the sender's bank has exactly one live account.
 /// No match ever grants automatic financial POST permission.
 static String? suggest(
  Iterable<WaffraSmsAccountEvidence> evidence,{
  required String sender,String? suffix,
  required Set<String> activeAccountIds,
  required Set<String> sameBankAccountIds,
 }){
  final scoped=senderKey(sender);
  if(bankGroup(sender)==null)return null;
  final four=suffix4(suffix);
  if(four!=null){
   final exact=evidence.where((item)=>item.sender==scoped&&
    item.key=='suffix:$four'&&item.confirmations>=1&&
    activeAccountIds.contains(item.accountId)&&
    sameBankAccountIds.contains(item.accountId)).toList();
   return exact.length==1?exact.single.accountId:null;
  }
  // One bank sender may have many accounts; never suggest by sender alone.
  return null;
 }
}

class WaffraSmsAccountLearningStore {
 const WaffraSmsAccountLearningStore();
 static const _storage=FlutterSecureStorage(
  aOptions:AndroidOptions(encryptedSharedPreferences:true));
 String _key(String owner){
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(owner))
   throw const FormatException('Verified SMS owner missing');
  return 'waffra_sms_account_evidence_v1_$owner';
 }
 Future<List<WaffraSmsAccountEvidence>> read(String owner)async{
  final raw=await _storage.read(key:_key(owner));
  if(raw==null||raw.isEmpty)return const [];
  final decoded=jsonDecode(raw);
  if(decoded is! List||decoded.length>200)
   throw const FormatException('Invalid SMS account evidence');
  final result=<WaffraSmsAccountEvidence>[];
  for(final row in decoded){
   if(row is! Map)throw const FormatException('Bad evidence record');
   final evidence=WaffraSmsAccountEvidence.fromJson(
    Map<String,dynamic>.from(row));
   if(evidence.sender.length<3||evidence.sender.length>64||
      evidence.accountId.isEmpty||evidence.confirmations<1||
      evidence.confirmations>2||
      (evidence.key!='sender'&&
       !RegExp(r'^suffix:[0-9]{4}$').hasMatch(evidence.key)))
    throw const FormatException('Invalid bank account evidence');
   result.add(evidence);
  }
  if(result.map((e)=>'${e.sender}|${e.key}').toSet().length!=result.length)
   throw const FormatException('Duplicate SMS account evidence');
  return List.unmodifiable(result);
 }
 Future<void> confirm({required String owner,required String sender,
  required String accountId,String? suffix})async{
  final existing=await read(owner);
  final updated=WaffraSmsAccountLearning.confirmed(existing,
   sender:sender,accountId:accountId,suffix:suffix);
  if(updated.length==existing.length &&
     jsonEncode(updated.map((e)=>e.toJson()).toList())==
     jsonEncode(existing.map((e)=>e.toJson()).toList()))return;
  await _storage.write(key:_key(owner),
   value:jsonEncode(updated.map((e)=>e.toJson()).toList()));
 }
}
