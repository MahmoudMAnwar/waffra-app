import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owner-scoped, bounded encrypted metadata, not a money/acknowledgement store.
/// Never put unredacted SMS text, bank reference, suffix or amount into JSON.
class WaffraSmsLifecycleHistoryStore {
 const WaffraSmsLifecycleHistoryStore();
 static const maxRecords=256;
 static const maxAge=Duration(days:30);
 static const _storage=FlutterSecureStorage(
  aOptions:AndroidOptions(encryptedSharedPreferences:true));
 static final _hex=RegExp(r'^[a-f0-9]{64}$');
 static const _stages=<String>{
  'pending','posted','failed','reversed','refunded','uncertain',
 };

 static String _key(String owner){
  if(!_hex.hasMatch(owner)){
   throw const FormatException('Verified SMS history owner missing');
  }
  return 'waffra_sms_lifecycle_hints_v1_$owner';
 }

 /// Accept only SHA256 identifiers, enum stage and current epoch millis.
 /// Keep the newest row for each exact relation. No raw bank data survives.
 static List<Map<String,Object?>> sanitize(
  Iterable<dynamic> raw,{required int nowMillis}){
  final byKey=<String,Map<String,Object?>>{};
  for(final item in raw){
   if(item is! Map)continue;
   final key=item['key'],source=item['source'];
   final stage=item['stage'],seenAt=item['seenAt'];
   if(key is! String||source is! String||stage is! String||
      seenAt is! int||!_hex.hasMatch(key)||!_hex.hasMatch(source)||
      !_stages.contains(stage)||seenAt>nowMillis+300000||
      seenAt<nowMillis-maxAge.inMilliseconds)continue;
   final prior=byKey[key];
   if(prior==null||(prior['seenAt'] as int)<seenAt){
    byKey[key]=<String,Object?>{
     'key':key,'source':source,'stage':stage,'seenAt':seenAt,
    };
   }
  }
  final recent=byKey.values.toList()
   ..sort((a,b)=>(b['seenAt'] as int).compareTo(a['seenAt'] as int));
  return List<Map<String,Object?>>.unmodifiable(
   recent.take(maxRecords).map((x)=>Map<String,Object?>.unmodifiable(x)));
 }

 Future<List<Map<String,Object?>>> read(String owner) async{
  final raw=await _storage.read(key:_key(owner));
  if(raw==null||raw.isEmpty)return const [];
  final decoded=jsonDecode(raw);
  if(decoded is! List)throw const FormatException('Invalid SMS history');
  return sanitize(decoded,nowMillis:DateTime.now().millisecondsSinceEpoch);
 }

 Future<void> write(String owner,Iterable<Map<String,Object?>> hints)async{
  final key=_key(owner);
  final safe=sanitize(hints,nowMillis:DateTime.now().millisecondsSinceEpoch);
  await _storage.write(key:key,value:jsonEncode(safe));
 }
}
