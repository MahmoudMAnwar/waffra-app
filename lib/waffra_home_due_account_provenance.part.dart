part of 'main.dart';

/// M908 / #633: real verified due-source account provenance; no money writes.
extension _WaffraHomeDueAccountProvenance on _HomeScreenState {
 Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){
  return _m650DueSourceCache.putIfAbsent(entry.id,()async{
   if(entry.sourceType=='goal_due'&&
      entry.goalWalletPaidMinor>=
       WaffraRecurringPolicy.toHalalas(entry.amount)){
    return waffraIsEnglish?'Savings goal wallet':'محفظة الهدف الادخاري';
   }
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)return null;
   final link=await WaffraVerifiedAccountsApi(bridge:bridge)
    .readExistingEntryAccount(entryId:entry.id);
   if(!link.exists||link.accountId==null||_m627ClosingSession)return null;
   for(final account in _m467Accounts){
    if(account.id==link.accountId)return _m647VerifiedAccountLabel(account);
   }
   return null; // Archived/missing account identity must not be invented.
  });
 }
}
