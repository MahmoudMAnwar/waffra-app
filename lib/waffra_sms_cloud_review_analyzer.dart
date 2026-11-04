import 'package:shared_preferences/shared_preferences.dart';
import 'waffra_auto_sms.dart';
import 'waffra_sms_cloud_redactor.dart';
import 'waffra_sms_cloud_service.dart';

/// M436: bank SMS intake can request *suggestions* automatically only after
/// the owner explicitly opts in to off-device redacted cloud processing.
/// The local financial ledger remains review-only, without automatic writes.
///
/// This is intentionally a bounded QA transport for OpenRouter's shared free
/// quota; signed-device App Check and accuracy acceptance are still required.
abstract final class WaffraSmsCloudReviewAnalyzer {
 static const perInstallationDailyLimit=8;
 static const _dayKey='waffra_cloud_sms_review_utc_day_v1';
 static const _usedKey='waffra_cloud_sms_review_used_v1';

 /// Tries a small batch. Native encrypted claim prevents repeated requests
 /// for the same SMS even when foreground and WorkManager race.
 /// Returns how many model suggestions were safely staged for user review.
 static Future<int> stagePending(
  List<Map<String,Object?>> candidates,{int maxPerRun=2,
  required bool explicitlyRequested}) async {
  // A general opt-in never grants permission to automatically upload SMS.
  if(!explicitlyRequested||maxPerRun<=0||
     !await WaffraSmsCloudService.hasConsent())return 0;
  final prefs=await SharedPreferences.getInstance();
  await prefs.reload();
  final day=DateTime.now().toUtc().toIso8601String().substring(0,10);
  var used=prefs.getString(_dayKey)==day?
   (prefs.getInt(_usedKey)??0):0;
  if(used>=perInstallationDailyLimit)return 0;
  final prioritized=List<Map<String,Object?>>.from(candidates)
   ..sort((a,b){
    final x=a['receivedAt'] is int?a['receivedAt'] as int:0;
    final y=b['receivedAt'] is int?b['receivedAt'] as int:0;
    return y.compareTo(x);
   });
  var attempted=0,staged=0;
  for(final item in prioritized){
   if(attempted>=maxPerRun||used>=perInstallationDailyLimit)break;
   if(item['cloud'] is Map)continue;
   final id=item['id'],body=item['body'];
   if(id is! String||body is! String||body.trim().isEmpty)continue;
   // No message that cannot be locally redacted reaches an external model.
   if(WaffraSmsCloudRedactor.redact(body)==null)continue;
   if(!await WaffraAutoSms.claimCloudAttempt(id))continue;
   // Count BEFORE the external request, so failures and restarts do not
   // accidentally burn through the shared provider quota.
   used++;
   attempted++;
   await prefs.setString(_dayKey,day);
   await prefs.setInt(_usedKey,used);
   final suggestion=await WaffraSmsCloudService.analyzeIfConsented(body);
   if(suggestion==null)continue;
   final safe=Map<String,Object?>.from(suggestion)
    ..remove('verifiedForPosting')
    ..['requiresReview']=true;
   if(await WaffraAutoSms.stageCloudAnalysis(id,safe))staged++;
  }
  return staged;
 }
}
