import 'storage/waffra_accounts_repository.dart';
import 'waffra_sms_account_learning.dart';
import 'waffra_saudi_financial_providers.dart';

/// First-step picker groups only verified, active accounts. It never changes
/// money routing or infers an account to charge from the Home header.
class WaffraRecurringAccountGroup {
 const WaffraRecurringAccountGroup({
  required this.id,required this.labelAr,required this.labelEn,
  required this.accounts,
 });
 final String id,labelAr,labelEn;
 String get category=>WaffraSaudiFinancialProviders.categoryForGroup(id);
 final List<WaffraAccountBalance> accounts;
}

abstract final class WaffraRecurringAccountGroups {
 /// Keep the original bank provider IDs; new labels are centralized so
 /// Home, recurring and new-account pickers never classify a wallet as bank.
 static Map<String,({String ar,String en})> get _bankNames=> {
  for(final p in WaffraSaudiFinancialProviders.all)
   p.id:(ar:p.labelAr,en:p.labelEn),
 };

 /// Provider category -> institution -> verified account. Every catalog item
 /// is just a selection, not an invented financial account or new balance.
 static List<WaffraRecurringAccountGroup> withBankProviderChoices(
  Iterable<WaffraAccountBalance> accounts,
 ){
  final groups=fromAccounts(accounts);
  final byId=<String,WaffraRecurringAccountGroup>{
   for(final group in groups)group.id:group,
  };
  for(final provider in WaffraSaudiFinancialProviders.all){
   byId.putIfAbsent(provider.groupId,
    ()=>WaffraRecurringAccountGroup(
     id:provider.groupId,
     labelAr:provider.labelAr,labelEn:provider.labelEn,
     accounts:const <WaffraAccountBalance>[]));
  }
  byId.putIfAbsent('bank:institution:other',
   ()=>const WaffraRecurringAccountGroup(
    id:'bank:institution:other',labelAr:'بنك آخر',
    labelEn:'Other bank',accounts:<WaffraAccountBalance>[]));
  byId.putIfAbsent('wallet:institution:other',
   ()=>const WaffraRecurringAccountGroup(
    id:'wallet:institution:other',labelAr:'محفظة أخرى',
    labelEn:'Other wallet',accounts:<WaffraAccountBalance>[]));
  return List<WaffraRecurringAccountGroup>.unmodifiable(byId.values);
 }

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
