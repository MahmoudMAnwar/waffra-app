import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final n=senderKey(text).replaceAll(RegExp(r'[ _-]'),'');
  if(n.contains('alrajhi')||n.contains('rajhi')||n.contains('الراجحي'))return 'rajhi';
  if(n.contains('alinma')||n.contains('alinmah')||
     n.contains('الانماء')||n.contains('الإنماء'))return 'inma';
  if(n.contains('snb')||n.contains('alahli')||n.contains('الأهلي')||
     n.contains('الاهلي'))return 'snb';
  if(n.contains('riyadbank')||n.contains('بنكالرياض'))return 'riyad';
  if(n.contains('albilad')||n.contains('البلاد'))return 'bilad';
  if(n.contains('stcpay')||n.contains('stcbank'))return 'stc';
  return null;
 }
 /// User must explicitly choose a verified existing account each time until
 /// the SAME association has been confirmed twice. A conflicting choice
 /// resets evidence instead of creating competing account rules.
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
    item.key=='suffix:$four'&&item.confirmations>=2&&
    activeAccountIds.contains(item.accountId)&&
    sameBankAccountIds.contains(item.accountId)).toList();
   return exact.length==1?exact.single.accountId:null;
  }
  if(sameBankAccountIds.length!=1)return null;
  final senderOnly=evidence.where((item)=>item.sender==scoped&&
   item.key=='sender'&&item.confirmations>=2&&
   sameBankAccountIds.contains(item.accountId)).toList();
  return senderOnly.length==1?senderOnly.single.accountId:null;
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
