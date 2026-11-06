import 'storage/waffra_accounts_repository.dart';
import 'waffra_sms_account_learning.dart';

/// First-step picker groups only verified, active accounts. It never changes
/// money routing or infers an account to charge from the Home header.
class WaffraRecurringAccountGroup {
 const WaffraRecurringAccountGroup({
  required this.id,required this.labelAr,required this.labelEn,
  required this.accounts,
 });
 final String id,labelAr,labelEn;
 final List<WaffraAccountBalance> accounts;
}

abstract final class WaffraRecurringAccountGroups {
 static const _bankNames=<String,({String ar,String en})>{
  'rajhi':(ar:'مصرف الراجحي',en:'Al Rajhi Bank'),
  'inma':(ar:'مصرف الإنماء',en:'Alinma Bank'),
  'snb':(ar:'البنك الأهلي السعودي',en:'Saudi National Bank'),
  'riyad':(ar:'بنك الرياض',en:'Riyad Bank'),
  'bilad':(ar:'بنك البلاد',en:'Bank Albilad'),
  'stc':(ar:'STC Bank',en:'STC Bank'),
 };

 /// Accounts without a recognized institution are deliberately kept in
 /// individual groups, rather than guessed into a potentially wrong bank.
 /// Selecting a group does not select an account or authorize a payment.
 static List<WaffraRecurringAccountGroup> fromAccounts(
  Iterable<WaffraAccountBalance> accounts,
 ){
  final buckets=<String,List<WaffraAccountBalance>>{};
  final names=<String,({String ar,String en})>{};
  for(final account in accounts){
   if(account.archived)continue;
   final String id;
   final ({String ar,String en}) name;
   if(account.kind=='bank'||account.kind=='wallet'){
    // Versioned, user-selected provider takes precedence over a label.
    // Only OLD accounts without structured metadata may use name hints.
    final institution=account.providerId!=null?
     (account.providerId=='other'?null:account.providerId):
     WaffraSmsAccountLearning.bankGroup(account.name);
    id=institution==null
      ?'${account.kind}:account:${account.id}'
      :'${account.kind}:institution:$institution';
    name=institution==null
      ?(ar:account.name,en:account.name)
      :_bankNames[institution]??(ar:account.name,en:account.name);
   }else if(account.kind=='cash'){
    id='cash';
    name=(ar:'نقدي',en:'Cash');
   }else{
    id='other:account:${account.id}';
    name=(ar:account.name,en:account.name);
   }
   buckets.putIfAbsent(id,()=>[]).add(account);
   names[id]=name;
  }
  return List<WaffraRecurringAccountGroup>.unmodifiable(
   buckets.entries.map((entry)=>WaffraRecurringAccountGroup(
    id:entry.key,labelAr:names[entry.key]!.ar,
    labelEn:names[entry.key]!.en,
    accounts:List<WaffraAccountBalance>.unmodifiable(entry.value),
   )),
  );
 }
}
