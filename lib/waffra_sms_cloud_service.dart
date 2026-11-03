import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'waffra_sms_cloud_redactor.dart';
import 'waffra_cloudflare_sms_gateway.dart';

/// M427: one installation-level opt-in; the app phone is NOT verified identity.
/// App Check attests the signed APK/device; no OTP or Firebase Auth is used.
abstract final class WaffraSmsCloudService {
 static const _key='waffra_cloud_sms_installation_consent_v2';
 static bool _activated=false;
 static Future<void> _ready()async{
  if(Firebase.apps.isEmpty)await Firebase.initializeApp();
  if(!_activated){
   await FirebaseAppCheck.instance.activate(
    androidProvider:kReleaseMode?AndroidProvider.playIntegrity:AndroidProvider.debug);
   _activated=true;
  }
 }
 static Future<bool> hasConsent()async{
  if(!Platform.isAndroid||!WaffraCloudflareSmsGateway.configured)return false;
  final p=await SharedPreferences.getInstance();
  await p.reload();
  return p.getBool(_key)==true;
 }
 static Future<bool> setConsent(bool enabled)async{
  if(!Platform.isAndroid)return false;
  final p=await SharedPreferences.getInstance();
  if(!enabled)return p.setBool(_key,false);
  final endpoint=WaffraCloudflareSmsGateway.validEndpoint(
   WaffraCloudflareSmsGateway.configuredUrl);
  if(!WaffraCloudflareSmsGateway.configured||endpoint==null)return false;
  return p.setBool(_key,true);
 }
 static Future<Map<String,Object?>?> analyzeIfConsented(String source)async{
  if(!await hasConsent())return null;
  if(WaffraSmsCloudRedactor.redact(source)==null)return null;
  final endpoint=WaffraCloudflareSmsGateway.validEndpoint(
   WaffraCloudflareSmsGateway.configuredUrl);
  if(endpoint==null)return null;
  try{
   await _ready();
   final token=await FirebaseAppCheck.instance.getToken();
   if(token==null||token.isEmpty)return null;
   return WaffraCloudflareSmsGateway.analyze(
    source:source,appCheckToken:token,endpoint:endpoint);
  }catch(_){
   // Keep local parse and ledger untouched. No bank SMS in logs.
   return null;
  }
 }
}
