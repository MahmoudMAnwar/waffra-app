part of 'main.dart';

/// Background SMS capture never creates income or expense transactions,
/// analyzes remotely, or changes the ledger. It only preserves encrypted
/// pending candidates and emits review notifications. Explicit foreground
/// user confirmation owns every financial posting and AI request.
abstract final class WaffraAutoSmsAutoPoster {
 static bool get reviewOnly => true;

 static Future<Map<String,int>> run()async{
  final summary=<String,int>{'saved':0,'duplicates':0,'review':0};
  if(!await WaffraAutoSms.enabled())return summary;
  final pending=await WaffraAutoSms.pending();
  for(final candidate in pending){
   final id=candidate['id'];
   if(id is String)await WaffraAutoSms.notifyReview(id);
  }
  summary['review']=pending.length;
  return summary;
 }
}
