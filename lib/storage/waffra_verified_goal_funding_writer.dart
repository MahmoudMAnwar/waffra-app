import 'dart:convert';

import 'waffra_account_context_repository.dart';
import 'waffra_account_context_schema.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_repository.dart';

/// Verified funding is a wallet transfer, not an income/expense entry.
/// Both the canonical goal snapshot and typed goal movement (plus its source)
/// commit in one SQLCipher transaction. Call ONLY while the native Home/Widget
/// writer lock and active-source certificate are held.
class WaffraVerifiedGoalFundingWriter {
 const WaffraVerifiedGoalFundingWriter({
  required this.store,required this.snapshot,this.experimentalEnabled=false,
 });
 final WaffraEncryptedStore store;
 final WaffraAtomicFinanceSnapshot snapshot;
 final bool experimentalEnabled;

 static int _minor(num value) {
  if (!value.isFinite || value < 0 ||
      value > 90071992547409 || (value*100-(value*100).round()).abs()>0.00001) {
   throw StateError('Invalid goal amount precision.');
  }
  return (value*100).round();
 }

 Future<bool> fund({
  required int expectedGeneration,required String expectedDigest,
  required String goalId,required int amountMinor,
  required String movementId,required String occurredIso,
  required String? sourceAccountId,required bool userConfirmed,
  bool release=false,
 }) async {
  if (!experimentalEnabled || !userConfirmed ||
      goalId.trim().isEmpty || movementId.trim().isEmpty ||
      goalId.length>128 || movementId.length>128 ||
      amountMinor<=0 || amountMinor>9007199254740991 ||
      DateTime.tryParse(occurredIso)==null) {
   throw StateError('Verified savings funding requires explicit confirmation.');
  }
  return store.transaction(() async {
   await WaffraAccountsSchema.requireReady(store);
   await WaffraAccountContextSchema.requireReady(store);
   final current=await snapshot.read();
   if(current.generation!=expectedGeneration ||
      current.digest!=expectedDigest) {
    throw StateError('Savings changed before confirmation; refresh first.');
   }
   final raw=current.values['waffra_goals_v24'];
   if(raw is! String)throw StateError('Encrypted goals snapshot is unavailable.');
   final decoded=jsonDecode(raw);
   if(decoded is! List)throw StateError('Encrypted goal list is invalid.');
   final goals=<Map<String,dynamic>>[];
   var matches=0;
   for(final item in decoded) {
    if(item is! Map<String,dynamic>) {
     throw StateError('Goal source contains a malformed record.');
    }
    final goal=Map<String,dynamic>.from(item);
    if(goal['id']==goalId) {
     matches++;
     final old=goal['saved'];
     if(old is! num)throw StateError('Goal saved balance is invalid.');
     final priorMinor=_minor(old);
     final nextMinor=release?priorMinor-amountMinor:priorMinor+amountMinor;
     if(nextMinor<0||nextMinor>9007199254740991) {
      throw StateError('Goal savings exceed safe precision.');
     }
     goal['saved']=nextMinor/100;
    }
    goals.add(goal);
   }
   if(matches!=1)throw StateError('Savings goal no longer exists uniquely.');
   final finance=Map<String,Object?>.from(current.values);
   finance['waffra_goals_v24']=jsonEncode(goals);
   final movement=await WaffraFreshFinanceDomainRepository(
    store:store,experimentalEnabled:true,
   ).updateGoalSavings(
    movementId:movementId,goalId:goalId,amountMinor:amountMinor,
    release:release,idempotencyKey:movementId,occurredAtIso:occurredIso,
    userConfirmed:true,
   );
   if(!movement) {
    throw StateError('Repeated goal transfer must not be posted twice.');
   }
   if(sourceAccountId!=null) {
    await WaffraAccountContextRepository(
     store:store,experimentalEnabled:true,
    ).attributeGoalMovement(
     movementId:movementId,accountId:sourceAccountId,
     linkedIso:occurredIso,userConfirmed:true,
    );
   }
   await snapshot.commit(expectedGeneration:current.generation,
    fullFinanceSnapshot:finance);
   return true;
  });
 }
}
