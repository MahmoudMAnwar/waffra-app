import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local *non-financial* notification history. Never writes to the ledger.
///
/// A threshold is shown at most once per account, budget and calendar month,
/// even if an edited expense later drops below it and crosses it again.
/// No owner identity, budget name, balance or amount is persisted here.
class WaffraBudgetAlertOnce {
 WaffraBudgetAlertOnce._();
 static const _key='waffra_budget_threshold_seen_v1';
 // Serialize concurrent SMS/manual completions in the current Dart isolate.
 static Future<void> _serial=Future<void>.value();

 static Future<bool> claim({
  required String owner,
  required String budgetId,
  required DateTime month,
  required List<int> crossedStages,
 }) {
  if(owner.trim().isEmpty||budgetId.trim().isEmpty){
   return Future<bool>.value(false);
  }
  final stages=crossedStages.toSet().where((n)=>n>0&&n<=100).toList()..sort();
  if(stages.isEmpty)return Future<bool>.value(false);
  final prefix='$owner|$budgetId|${month.year}-${month.month}|';
  final tokens=stages.map((s)=>
   sha256.convert(utf8.encode('$prefix$s')).toString()).toList();
  final highest=tokens.last;
  final outcome=Completer<bool>();
  _serial=_serial.then((_)async{
   try{
    final prefs=await SharedPreferences.getInstance();
    final recorded=prefs.getStringList(_key)??<String>[];
    final alreadyShown=recorded.contains(highest);
    final seen=recorded.toSet();
    // Record all stages passed by a single large transaction (for example
    // 0% -> 105%) so a later reduction cannot replay the lower warning.
    final fresh=tokens.where((t)=>!seen.contains(t)).toList();
    if(fresh.isEmpty){outcome.complete(false);return;}
    final next=<String>[...recorded,...fresh];
    if(next.length>4096)next.removeRange(0,next.length-4096);
    final persisted=await prefs.setStringList(_key,next);
    outcome.complete(persisted&&!alreadyShown);
   }catch(_){
    // Do not pretend deduplication succeeded if durable local storage fails.
    outcome.complete(false);
   }
  });
  return outcome.future;
 }
}
