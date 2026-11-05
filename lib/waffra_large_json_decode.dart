import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parsing is read-only and outside the verified finance writer.
/// Small JSON remains synchronous; large ledgers decode off the UI isolate
/// to avoid dropped spinner and scroll frames during launch and refresh.
Object? _waffraDecodeJsonWorker(String source)=>jsonDecode(source);

abstract final class WaffraLargeJsonDecode {
 static const int isolateThreshold=65536;
 static Future<Object?> parse(String source)async{
  if(source.length<isolateThreshold)return jsonDecode(source);
  return compute(_waffraDecodeJsonWorker,source);
 }
}
