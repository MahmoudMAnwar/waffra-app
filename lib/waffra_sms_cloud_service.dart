import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// M690 / #632: retired external SMS analysis. Old opt-ins cannot
/// reactivate external processing, and previous consent is erased on
/// permissions setup without affecting the local encrypted SMS review.
abstract final class WaffraSmsCloudService {
 static const _key='waffra_cloud_sms_installation_consent_v2';
 static Future<bool> hasConsent()async=>false;
 static Future<bool> setConsent(bool enabled)async{
  if(!Platform.isAndroid)return !enabled;
  final prefs=await SharedPreferences.getInstance();
  await prefs.remove(_key);
  return !enabled;
 }
 static Future<Map<String,Object?>?> analyzeIfConsented(String source)async=>null;
}
