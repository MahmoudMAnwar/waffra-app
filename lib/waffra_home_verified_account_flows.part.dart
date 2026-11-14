part of 'main.dart';

/// M760 / Issue #633: unchanged verified Home bank-account context and transfer editor.
/// Same Dart library. Owner-bound SQLCipher source and finance writers unchanged.
extension _WaffraHomeVerifiedAccountFlows on _HomeScreenState {
 Future<void> _m467RefreshHomeAccounts()async{
  final active=_m468AccountReadInFlight;
  if(active!=null){
   _m468AccountReadAgain=true;
   await active;
   return;
  }
  final running=_m468ReadVerifiedAccountsOnce();
  _m627OutstandingAccountReads.add(running);
  _m468AccountReadInFlight=running;
  try{await running;}
  finally{
   _m627OutstandingAccountReads.remove(running);
   // Do not detach a newer retry after an older timeout finishes late.
   if(identical(_m468AccountReadInFlight,running)){
    _m468AccountReadInFlight=null;
    final again=_m468AccountReadAgain;
    _m468AccountReadAgain=false;
    if(again&&mounted&&!_m627ClosingSession)unawaited(_m467RefreshHomeAccounts());
   }
  }
 }

 Future<void> _m468ReadVerifiedAccountsOnce()async{
  final readEpoch=_m627AccountEpoch;
  if(_m627ClosingSession)return;
  try{
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)throw StateError('No verified account bridge');
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   final accounts=await api.balances();
   var chosen=_m467SelectedAccount;
   if(!_m467AccountChoiceRestored){
    final p=await SharedPreferences.getInstance();
    chosen=p.getString(_m467ChoiceKey)??'all';
   }
   if(chosen!='all'&&
      !accounts.any((a)=>!a.archived&&a.id==chosen))chosen='all';
   final now=DateTime.now();
   final month=now.year.toString().padLeft(4,'0')+'-'+
    now.month.toString().padLeft(2,'0');
   // Month-only context plus lightweight all-time account membership.
   final contextView=chosen=='all'?null:await api.readAccountContext(
    monthIso:month,
    selectedAccountId:chosen,summaryOnly:true);
   final scopedIds=chosen=='all'?null:
    await api.readAccountEntryIds(accountId:chosen);
   if(!mounted||_m627ClosingSession||readEpoch!=_m627AccountEpoch)return;
   // A user may switch accounts while this async SQL projection is running.
   // Never repaint that newly chosen view with a stale older selection.
   if(_m467AccountChoiceRestored&&_m467SelectedAccount!=chosen){
    _m468AccountReadAgain=true;
    return;
   }
   // Invalidate only after the new account source has been verified.
   // A fresh transfer card read is asynchronous and never awaited by Home.
   _m648InvalidateTransfers();
   setState((){
    _m467Accounts=accounts.where((a)=>!a.archived).toList();
    _m467AccountContext=contextView;
    _m684ScopedEntryIds=scopedIds;
    _m467SelectedAccount=chosen;
    _m467AccountChoiceRestored=true;
    _m468VerifiedAccountsLoaded=true;
   });
  }catch(error){
   debugPrint('Home accounts view unavailable: '+error.runtimeType.toString());
   if(!mounted||_m627ClosingSession||readEpoch!=_m627AccountEpoch)return;
   // Never show a stale bank balance when verified SQL projection is absent.
   setState((){
    _m467Accounts=const <WaffraAccountBalance>[];
    _m467AccountContext=null;
    _m684ScopedEntryIds=null;
    _m467SelectedAccount='all';
    _m467AccountChoiceRestored=false;
    _m468VerifiedAccountsLoaded=false;
   });
  }
 }

 String get _m467AccountLabel{
  if(_m467SelectedAccount=='all')return (waffraIsEnglish?'All accounts':'كل الحسابات');
  for(final account in _m467Accounts){
   if(account.id==_m467SelectedAccount)return account.name;
  }
  return (waffraIsEnglish?'All accounts':'كل الحسابات');
 }

 Iterable<MoneyEntry> _m467ScopedEntries(){
  final selected=_m467SelectedAccount;
  if(selected=='all')return entries;
  final ids=_m684ScopedEntryIds;
  if(ids==null)return const <MoneyEntry>[];
  // Read-only exact-ID projection over the authenticated hydrated ledger.
  return _m684Periods.byIds(ids);
 }

 List<MoneyEntry> _m684ScopedMonthEntries(int year,int month){
  final monthRows=_m684Periods.month(year,month);
  if(_m467SelectedAccount=='all')return monthRows;
  final ids=_m684ScopedEntryIds;
  if(ids==null)return const <MoneyEntry>[];
  return monthRows.where((e)=>ids.contains(e.id)).toList(growable:false);
 }

 double _m467ShownBalance(){
  if(_m467SelectedAccount=='all'){
   if(!_m468VerifiedAccountsLoaded)return waffraAvailableCash(entries,goals);
   // The sum of verified balances includes openings, account transfers and
   // wallet movements. Unassigned ledger entries do not alter accounts.
   return _m467Accounts.fold<int>(0,(total,a)=>total+a.balanceMinor)/100;
  }
  for(final a in _m467Accounts){
   if(a.id==_m467SelectedAccount)return a.balanceMinor/100;
  }
  return 0;
 }

 Future<void> _m467PickHomeAccount()async{
  // M527: a cold verified read must not block the first sheet frame.
  // No unverified account may ever appear as a selectable money source.
  final pendingAccounts=_m468VerifiedAccountsLoaded
   ?null:_m467RefreshHomeAccounts();
  if(!mounted)return;
  final next=await showModalBottomSheet<String>(
   context:context,isScrollControlled:true,useSafeArea:true,
   showDragHandle:true,
   builder:(sheet){
    Widget verifiedChoices()=>WaffraHomeAccountsSheet(
     english:waffraIsEnglish,
     selected:_m467SelectedAccount,
     accounts:_m467Accounts);
    // Warm cache: render original selector with no FutureBuilder wait frame.
    if(pendingAccounts==null)return verifiedChoices();
    return FutureBuilder<void>(
     future:pendingAccounts,
     builder:(ctx,state){
      if(state.connectionState!=ConnectionState.done){
       return SafeArea(top:false,child:SizedBox(
        key:const Key('m527-account-picker-loading'),
        height:170,
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
         const CircularProgressIndicator(strokeWidth:2.7),
         const SizedBox(height:17),
         Text(waffraIsEnglish?'Verifying accounts…':
          'جارٍ التحقق من الحسابات…'),
        ])));
      }
      if(!_m468VerifiedAccountsLoaded){
       return SafeArea(top:false,child:Padding(
        key:const Key('m527-account-picker-verification-failed'),
        padding:const EdgeInsets.symmetric(horizontal:22,vertical:30),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
         Text(waffraIsEnglish?
          'Could not verify your accounts. No balances were changed.':
          'تعذر التحقق من الحسابات. لم تتغير أي أرصدة.',
          textAlign:TextAlign.center),
         const SizedBox(height:14),
         TextButton(
          onPressed:()=>Navigator.pop(sheet),
          child:Text(waffraIsEnglish?'Close and retry':'إغلاق وإعادة المحاولة')),
        ])));
      }
      return verifiedChoices();
     });
   });
  if(next==null||!mounted)return;
  if(next=='manage'){
   await openVerifiedAccounts();
   return;
  }
  if(next!='all'&&
     !_m467Accounts.any((a)=>a.id==next&&!a.archived))return;
  setState(()=>_m467SelectedAccount=next);
  try{
   final p=await SharedPreferences.getInstance();
   await p.setString(_m467ChoiceKey,next);
  }catch(error){
   debugPrint('Account display preference unavailable: '+error.runtimeType.toString());
  }
  if(mounted)await _m467RefreshHomeAccounts();
 }

 Future<void> openVerifiedAccounts()async{
  await _ensureFinanceBound();
  if(!mounted)return;
  final verifiedBridge=_financeBinding?.accountsBridge;
  if(verifiedBridge==null){
   snack(context,waffraIsEnglish?
    'Accounts require an activated, verified encrypted finance source.':
    'الحسابات تحتاج تفعيل مصدر مالي مشفّر وموثّق أولًا.');
   return;
  }
  await Navigator.of(context).push<void>(MaterialPageRoute(
   builder:(_)=>WaffraAccountsManagerPage(
    repository:WaffraVerifiedAccountsApi(bridge:verifiedBridge),
    english:waffraIsEnglish,
    // M667: the Accounts button enters the *same* Home three-mode sheet as +.
    // Keep the Home-owned verified finance and transfer save paths intact.
    onCreateHomeTransaction:()=>entrySheet(),
    incomeCategories:categories.where((item)=>item.income&&item.isSubcategory&&
      waffraCategoryAvailableForNewEntry(categories,item))
      .map((item)=>item.name).toList(growable:false),
    expenseCategories:categories.where((item)=>!item.income&&item.isSubcategory&&
      waffraCategoryAvailableForNewEntry(categories,item))
      .map((item)=>item.name).toList(growable:false),
    availableBudgets:{for(final item in namedBudgets.where((b)=>
      !b.deleted&&b.budgetActive&&b.budget>0))item.id:item.budgetLabel??item.name},
    onTransferConfirmed:(_)=>_learnManualTransferPreference(),
   )));
  if(mounted)await _m467RefreshHomeAccounts();
 }

 /// Internal transfers use the verified account ledger, never expense.
 /// New manual income and expenses require an explicit money account.
 Future<void> openVerifiedTransfer()async{
  try{
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null){
    if(mounted)snack(context,waffraIsEnglish?
     'Transfers and new manual entries require verified money accounts.':
     'التحويل والدخل والمصروف اليدوي يحتاجوا حسابات مالية موثّقة.',
     isError:true);
    return;
   }
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   final accounts=await api.balances();
   if(!mounted)return;
   // Two different verified accounts are checked only on final submit.
   final knownIds=accounts.map((a)=>a.id).toSet();
   await Navigator.of(context).push<void>(MaterialPageRoute(
    builder:(transferContext)=>Scaffold(
     appBar:AppBar(title:WaffraText(waffraIsEnglish?
      'Transfer between my accounts':'تحويل بين حساباتي')),
     body:WaffraAccountTransactionForm(
      accounts:accounts,english:waffraIsEnglish,
      initialOperation:WaffraAccountOperation.transfer,
      onCreateAccount:(group,createProvider)async{
       await openVerifiedAccounts();
       if(!mounted)return null;
       final updated=await api.balances();
       final created=updated.where((a)=>
        !a.archived&&!knownIds.contains(a.id)).toList();
       knownIds.addAll(updated.map((a)=>a.id));
       return created.length==1?created.single:null;
      },
      onConfirmTransfer:(draft)async{
       await api.transfer(id:draft.requestId,
        fromAccountId:draft.fromId,toAccountId:draft.toId,
        amountMinor:draft.amountMinor,occurredIso:draft.occurredIso,
        note:draft.memo,userConfirmed:true);
       try{await _learnManualTransferPreference();}catch(_){}
       if(transferContext.mounted)Navigator.of(transferContext).pop();
      },
     ),
    )));
  }catch(error){
   debugPrint('Verified transfer route unavailable: ${error.runtimeType}');
   if(mounted)snack(context,waffraIsEnglish?
    'Transfer not verified. Check My Accounts.':
    'تعذر تأكيد التحويل. راجع حساباتي.',isError:true);
  }
 }
}
