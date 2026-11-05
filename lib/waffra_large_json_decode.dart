import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parsing is read-only and outside the verified finance writer.
/// Small JSON remains synchronous; large ledgers decode off the UI isolate
/// to avoid dropped spinner and scroll frames during launch and refresh.
Object? _waffraDecodeJsonWorker(String source)=>jsonDecode(source);
String _waffraEncodeFrozenRows(List<Map<String,dynamic>> rows)=>jsonEncode(rows);

abstract final class WaffraLargeJsonDecode {
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
