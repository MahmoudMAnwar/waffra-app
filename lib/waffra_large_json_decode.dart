import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parsing is read-only and outside the verified finance writer.
/// Small JSON remains synchronous; large ledgers decode off the UI isolate
/// to avoid dropped spinner and scroll frames during launch and refresh.
Object? _waffraDecodeJsonWorker(String source)=>jsonDecode(source);
String _waffraEncodeFrozenRows(List<Map<String,dynamic>> rows)=>jsonEncode(rows);


 
/// A verified finance snapshot can contain many independently typed JSON fields.
/// Decode them together to avoid spawning one isolate per field. Malformed data
/// stays malformed: the caller gets a field-specific error when it reads it.
class WaffraStartupDecodedFields {
 const WaffraStartupDecodedFields._(this._values,this._failures);
 final Map<String,Object?> _values;
 final Set<String> _failures;
 Object? read(String field) {
  if(_failures.contains(field)) {
   throw FormatException('Invalid verified startup JSON field: $field');
  }
  return _values[field];
 }
}

Map<String,Object?> _waffraDecodeStartupWorker(Map<String,String> sources){
 final values=<String,Object?>{};
 final failures=<String>[];
 for(final entry in sources.entries){
  try{values[entry.key]=jsonDecode(entry.value);}
  catch(_){failures.add(entry.key);}
 }
 return <String,Object?>{'values':values,'failures':failures};
}

abstract final class WaffraLargeJsonDecode {
 // M633: aggregate threshold keeps tiny sources on the event loop and runs
 // a single pure-JSON worker for a large immutable verified snapshot. No
 // storage authority, passwords, encryption key or plugin crosses isolates.
 static const int startupAggregateIsolateThreshold=32768;
 static Future<WaffraStartupDecodedFields> parseStartupFields(
  Map<String,String> sources)async{
  final frozen=Map<String,String>.from(sources);
  var totalBytes=0;
  for(final raw in frozen.values){totalBytes+=raw.length;}
  final Map<String,Object?> result=
   totalBytes<startupAggregateIsolateThreshold?
    _waffraDecodeStartupWorker(frozen):
    await compute(_waffraDecodeStartupWorker,frozen);
  return WaffraStartupDecodedFields._(
   Map<String,Object?>.from(result['values']! as Map),
   Set<String>.from(result['failures']! as List));
 }

 static const int isolateThreshold=65536;
 static const int encodeRowThreshold=240;
 /// Input rows MUST be captured before the first await in the caller.
 /// This is only serialization; Waffra's existing source/witness guards
 /// still validate the eventual confirmed write and reject stale snapshots.
 static Future<String> encodeRecords(List<Map<String,dynamic>> frozenRows)async{
  if(frozenRows.length<encodeRowThreshold)return jsonEncode(frozenRows);
  return compute(_waffraEncodeFrozenRows,frozenRows);
 }
 static Future<Object?> parse(String source)async{
  if(source.length<isolateThreshold)return jsonDecode(source);
  return compute(_waffraDecodeJsonWorker,source);
 }
}
