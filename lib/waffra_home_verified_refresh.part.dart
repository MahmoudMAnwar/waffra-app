part of 'main.dart';

/// M782 / Issue #633: original verified Home pull-refresh and finance snapshot reload.
/// Preserve SQLCipher authority, in-flight State field and fail-closed UX behavior.
extension _WaffraHomeVerifiedRefresh on _HomeScreenState {
 Future<void> _refreshAndSettle(ScrollController controller,int originalTab){
  final pending=_m474PullRefreshInFlight;
  if(pending!=null)return pending;
  late final Future<void> tracked;
  tracked=waffraRefreshAndRestoreScroll(
   refresh:_refreshFromVerifiedFinance,
   controller:controller,
   isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null&&
    tab==originalTab&&(originalTab!=0||!goalsOpened))
   .whenComplete((){
    if(identical(_m474PullRefreshInFlight,tracked)){
     _m474PullRefreshInFlight=null;
    }
   });
  _m474PullRefreshInFlight=tracked;
  return tracked;
 }

 Future<void> _refreshFromVerifiedFinance()async {
  if(!mounted||!ready)return;
  try {
   await _financialWriteQueue.drain();
   await _ensureFinanceBound();
   final current=await _financeAuthority.load(
    route:WaffraFinanceRoute.dashboardRead);
   final view=current.finance;
   view.requireIntegrity();
   // A same-generation/same-digest SQLCipher read is verified but unchanged.
   // Re-decoding the entire ledger and rebuilding every page on every swipe
   // caused avoidable UI lag. Do not apply this shortcut to guarded legacy.
   final previous=_lastFinanceAuthorityRead;
   final encryptedCurrent=current.encryptedWitness?.snapshot;
   final encryptedPrevious=previous?.encryptedWitness?.snapshot;
   if(current.source==WaffraRuntimeFinanceBackend.verifiedEncrypted&&
      previous?.source==current.source&&
      encryptedCurrent!=null&&encryptedPrevious!=null&&
      encryptedCurrent.generation==encryptedPrevious.generation&&
      encryptedCurrent.digest==encryptedPrevious.digest&&
      current.widgetRevision==previous?.widgetRevision){
    return;
   }
   // Legacy first installs may omit their empty ledger or category catalog.
   // Activated SQLCipher still fails closed if either required source is absent.
   final refreshSource=WaffraVerifiedPullRefreshSource.fromAuthority(current);
   final ledger=refreshSource.ledgerRaw;
   final catalog=refreshSource.categoriesRaw;
   Future<List<T>> readList<T>(String? raw,T Function(Map<String,dynamic>) make) async {
    if(raw==null)return <T>[];
    final parsed=await WaffraLargeJsonDecode.parse(raw);
    if(parsed is! List)throw const FormatException('Invalid finance list.');
    return parsed.map((e)=>make(Map<String,dynamic>.from(e as Map))).toList();
   }
   // This verified refresh source always exposes its normalized ledger.
   // Preserve fail-closed parsing and asynchronous bounded entry mapping.
   final nextEntries=await _m593BuildVerifiedEntries(
    (await WaffraLargeJsonDecode.parse(ledger)) as List);
   final nextCategories=catalog==null
    ?defaultCategories()
    :await readList<BudgetCategory>(catalog,BudgetCategory.fromJson);
   if(current.source==WaffraRuntimeFinanceBackend.guardedLegacy){
    if(nextCategories.isEmpty)nextCategories.addAll(defaultCategories());
    for(final entry in nextEntries){
     if(!nextCategories.any((c)=>c.name==entry.category&&c.income==entry.income)){
      nextCategories.add(BudgetCategory(id:newId(),name:entry.category,
       icon:'category',color:colors[7],income:entry.income));
     }
    }
   }
   final nextNamedBudgets=await readList<WaffraNamedBudget>(
    view.getString('waffra_named_budgets_v1'),WaffraNamedBudget.fromJson);
   for(final c in nextCategories.where((c)=>!c.income&&c.budget>0)){
    if(!nextNamedBudgets.any((b)=>b.id==c.id)){
     nextNamedBudgets.add(WaffraNamedBudget.fromLegacy(c));
    }
   }
   // Legacy category caps remain in the source UNTIL a single verified
   // finance batch commits BOTH new budget rows and cleared category caps.
   // Never clear category caps during a catalog upgrade or read-only refresh.
   final nextGoals=await readList<SavingGoal>(
    view.getString('waffra_goals_v24'),SavingGoal.fromJson);
   final nextRecurring=await readList<RecurringBill>(
    view.getString('waffra_recurring_v24'),RecurringBill.fromJson);
   final nextChallenges=await readList<SavingChallenge>(
    view.getString('waffra_challenges_v1'),SavingChallenge.fromJson);
   Future<List<Map<String,dynamic>>> readTrash(String key)=>readList<Map<String,dynamic>>(
    view.getString(key),(row)=>row);
   final nextCategoryTrash=await readTrash('waffra_deleted_categories_v1');
   final nextGoalTrash=await readTrash('waffra_deleted_goals_v1');
   final nextRecurringTrash=await readTrash('waffra_deleted_recurring_v1');
   Map<String,String> readStringMap(String key) {
    final raw=view.getString(key);
    if(raw==null)return <String,String>{};
    return (jsonDecode(raw) as Map).map((k,v)=>
     MapEntry(k.toString(),v.toString()));
   }
   final nextPostponed=readStringMap('waffra_recurring_postponed_v1');
   final nextLearned=readStringMap('waffra_learned_merchants_v1');
   final nextHashes=view.getStringList('waffra_sms_hashes_v1')??<String>[];
   final nextBudget=view.getDouble('waffra_monthly_budget_v1')??0;
   final nextBudgetEnabled=view.getBool('waffra_monthly_budget_enabled_v1')
    ??(nextBudget>0);
   final nextReminders=view.getBool('waffra_recurring_reminders_enabled_v1')??false;
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(nextEntries);
    categories..clear()..addAll(nextCategories);
    namedBudgets..clear()..addAll(nextNamedBudgets);
    goals..clear()..addAll(nextGoals);
    recurring..clear()..addAll(nextRecurring);
    challenges..clear()..addAll(nextChallenges);
    deletedCategories..clear()..addAll(nextCategoryTrash);
    deletedGoals..clear()..addAll(nextGoalTrash);
    deletedRecurring..clear()..addAll(nextRecurringTrash);
    recurringPostponed..clear()..addAll(nextPostponed);
    learnedMerchantCategories..clear()..addAll(nextLearned);
    smsHashes..clear()..addAll(nextHashes);
    monthlyBudget=nextBudget;
    monthlyBudgetEnabled=nextBudgetEnabled;
    recurringRemindersEnabled=nextReminders;
    _lastFinanceAuthorityRead=current;
    _lastLedgerSavedRaw=ledger;
    _lastWidgetRevision=current.widgetRevision;
   });
   // The verified pull read already includes the full authoritative ledger.
   // Reusing it prevents a second SQLCipher decrypt for the Home widget.
   unawaited(_publishVerifiedWidgetBalance(current));
   unawaited(_m467RefreshHomeAccounts());
  }catch(error) {
   debugPrint('Verified pull refresh failed closed: $error');
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Refreshed financial data could not be verified. Nothing was erased. Retry safely.':
     'تعذر التحقق من البيانات أثناء التحديث. لم تُحذف أي معاملات. أعد المحاولة بأمان.';
   });
  }
 }
}
