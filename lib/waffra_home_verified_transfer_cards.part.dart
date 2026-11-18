part of 'main.dart';

/// M733 / Issue #633: original Home transfer/savings history presentation.
/// Same library, unchanged account identity, amount direction and goal history.
extension _WaffraHomeVerifiedTransferCards on _HomeScreenState {
 String _m647VerifiedAccountLabel(WaffraAccountBalance account){
  final provider=WaffraSaudiFinancialProviders.byId(account.providerId);
  if(provider==null)return account.name;
  final label=waffraIsEnglish?provider.labelEn:provider.labelAr;
  final name=account.name.trim();
  if(name.isEmpty||name.toLowerCase()==label.toLowerCase())return label;
  if(name.toLowerCase().contains(label.toLowerCase()))return name;
  return '${label} • ${name}';
 }
 /// A prior transfer is immutable; corrections are opposite signed
 /// two-account movements, not in-place amount edits.
 /// M1036: correction of Waffra's ledger only, not a bank refund.
 /// The verified writer still enforces generation and deterministic replay.
 Future<void> _m1032ReverseTransfer(WaffraInternalTransferHistory movement,
  {VoidCallback? onReversed})async{
  if(movement.isReversal||movement.isReversed)return;
  try{
   if(movement.fromAccountId==movement.toAccountId||
      movement.amountMinor<=0){
    throw StateError('Invalid source and destination accounts for reversal.');
   }
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)throw StateError('Verified account bridge unavailable');
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   // Show the impact on BOTH verified accounts, not a guessed Home filter.
   // balances() also obtains the source witness consumed by the write.
   final balances=await api.balances();
   final originalFrom=balances.where((a)=>
    a.id==movement.fromAccountId&&!a.archived).toList();
   final originalTo=balances.where((a)=>
    a.id==movement.toAccountId&&!a.archived).toList();
   if(originalFrom.length!=1||originalTo.length!=1){
    throw StateError('Verified transfer endpoints are unavailable.');
   }
   final from=originalFrom.single,to=originalTo.single;
   final restoredFrom=from.balanceMinor+movement.amountMinor;
   final debitedTo=to.balanceMinor-movement.amountMinor;
   final preview=waffraIsEnglish?
    'Amount: ${cash(movement.amountMinor/100)}\n'
    'Original source: ${_m647VerifiedAccountLabel(from)}\n'
    '${cash(from.balanceMinor/100)} → ${cash(restoredFrom/100)}\n'
    'Original destination: ${_m647VerifiedAccountLabel(to)}\n'
    '${cash(to.balanceMinor/100)} → ${cash(debitedTo/100)}\n\n'
    'Only Waffra records will be corrected. This will NOT return real '
    'funds at the bank. The original stays in history and bank fees '
    'are not reversed automatically.':
    'المبلغ: ${cash(movement.amountMinor/100)}\n'
    'الحساب المصدر الأصلي: ${_m647VerifiedAccountLabel(from)}\n'
    '${cash(from.balanceMinor/100)} ← ${cash(restoredFrom/100)}\n'
    'الحساب المستلم الأصلي: ${_m647VerifiedAccountLabel(to)}\n'
    '${cash(to.balanceMinor/100)} ← ${cash(debitedTo/100)}\n\n'
    'هذا تصحيح لقيد داخل وفرة فقط، وليس استردادًا فعليًا من البنك. '
    'ستظل العملية الأصلية محفوظة، ولن تُعكس الرسوم البنكية تلقائيًا.';
   if(!mounted)return;
   final approved=await confirmDeletion(
    waffraIsEnglish?'Confirm internal transfer correction?':
     'تأكيد تصحيح التحويل بين حساباتي؟',preview);
   if(approved!=true||!mounted)return;
   final reversed=await api.reverseInternalTransfer(
    originalTransferId:movement.id,
    reversedIso:DateTime.now().toUtc().toIso8601String(),
    userConfirmed:true);
   _m648InvalidateTransfers();
   await _m467RefreshHomeAccounts();
   if(mounted){
    // The modal's FutureBuilder must explicitly reload its own Future.
    onReversed?.call();
    snackSuccess(context,waffraIsEnglish?
     (reversed?'Transfer correction saved':'Transfer already corrected'):
     (reversed?'تم تسجيل عكس التحويل وتحديث الحسابين':
      'تم عكس التحويل مسبقًا ولم تُسجّل عملية مكررة'));
   }
  }catch(error){
   if(mounted)snack(context,waffraIsEnglish?
    'Transfer correction could not be verified. No new correction was posted.':
    'تعذر تأكيد تصحيح التحويل. لم تُسجّل حركة عكس جديدة.',
    isError:true);
  }
 }

 /// M647: source and destination are separate verified account identities.
 /// Presentation-only: no money write, no inferred sender, no extra expense.
 Widget _m647TransferCard(WaffraInternalTransferHistory t,{
  bool compact=false,VoidCallback? onReversed,
  ValueChanged<String>? onOpenRelated,
 }){
  final names={for(final a in _m467Accounts)a.id:_m647VerifiedAccountLabel(a)};
  final from=names[t.fromAccountId]??(waffraIsEnglish?
   'Account unavailable':'حساب غير متاح');
  final to=names[t.toAccountId]??(waffraIsEnglish?
   'Account unavailable':'حساب غير متاح');
  final dark=Theme.of(context).brightness==Brightness.dark;
  const accent=Color(0xFF2764AD);
  final bg=dark?const Color(0xFF182C40):const Color(0xFFE7F0FA);
  final textColor=dark?const Color(0xFFC6DDF8):const Color(0xFF194B82);
  final when=DateTime.tryParse(t.occurredIso);
  // The original reviewed SMS is private and encrypted in transfer notes.
  // Show it only on an explicit details tap, never in compact Home previews.
  const sourceMarker='نص الرسالة البنكية الأصلية:\n';
  final sourceAt=t.id.startsWith('sms-transfer-')?
   t.note.indexOf(sourceMarker):-1;
  final originalSms=sourceAt<0?null:
   t.note.substring(sourceAt+sourceMarker.length);
  final visibleMemo=t.isReversal?'':(sourceAt<0?t.note:t.note.substring(0,sourceAt).trim());
  Widget endpoint(String label,String name)=>Expanded(child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    WaffraText(label,style:TextStyle(color:textColor,fontSize:11)),
    const SizedBox(height:2),
    WaffraText(name,maxLines:compact?2:3,overflow:TextOverflow.ellipsis,
     style:TextStyle(fontSize:compact?12:15,fontWeight:FontWeight.bold)),
   ]));
  return Container(
   key:Key('m647-verified-transfer-'+t.id),
   constraints:const BoxConstraints(minHeight:98),
   margin:const EdgeInsets.symmetric(vertical:3),
   padding:EdgeInsets.symmetric(horizontal:12,vertical:compact?9:11),
   decoration:BoxDecoration(
    color:bg,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:accent.withValues(alpha:.32))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.swap_horiz_rounded,color:accent,size:18),
     const SizedBox(width:7),
     Expanded(child:WaffraText((t.isReversal?
       (waffraIsEnglish?'Transfer correction':'عكس تحويل بين حساباتي'):
       (waffraIsEnglish?'Between my accounts':'تحويل بين حساباتي')),
      style:TextStyle(color:textColor,fontWeight:FontWeight.bold,fontSize:13))),
     // M648: the same transfer has opposite signed effects when viewing
     // either involved account; All Accounts remains one unsigned event.
     Flexible(child:FittedBox(fit:BoxFit.scaleDown,
      child:Row(mainAxisSize:MainAxisSize.min,children:[
       WaffraText(waffraIsEnglish?'Amount':'المبلغ',style:TextStyle(color:textColor,fontSize:11)),
       const SizedBox(width:5),
       if(_m467SelectedAccount==t.fromAccountId)
        WaffraText('−',style:TextStyle(color:textColor,
         fontWeight:FontWeight.bold,fontSize:compact?14:18))
       else if(_m467SelectedAccount==t.toAccountId)
        WaffraText('+',style:TextStyle(color:textColor,
         fontWeight:FontWeight.bold,fontSize:compact?14:18)),
       WaffraCurrencyAmount(t.amountMinor/100,
        fontSize:compact?14:18,color:textColor),
      ]))),
    ]),
    if(_m467SelectedAccount==t.fromAccountId||
       _m467SelectedAccount==t.toAccountId)...[
     const SizedBox(height:4),
     WaffraText(_m467SelectedAccount==t.fromAccountId?
      (waffraIsEnglish?'Outgoing from selected account':
       'صادر من الحساب المحدد'):
      (waffraIsEnglish?'Incoming to selected account':
       'وارد إلى الحساب المحدد'),
      style:TextStyle(color:textColor,fontSize:11)),
    ],
    const SizedBox(height:7),
    Row(textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,
     children:[
      endpoint(waffraIsEnglish?'From':'من الحساب',from),
      Padding(padding:const EdgeInsets.symmetric(horizontal:8),
       child:Icon(waffraIsEnglish?Icons.arrow_forward_rounded:
        Icons.arrow_back_rounded,textDirection:TextDirection.ltr,
        color:accent,size:24)),
      endpoint(waffraIsEnglish?'To':'إلى الحساب',to),
     ]),
    const SizedBox(height:5),
    Row(children:[
     Icon(Icons.event_outlined,size:15,color:textColor),
     const SizedBox(width:5),
     Expanded(child:WaffraText(when==null?t.occurredIso:
      dayText(when),style:TextStyle(color:textColor,fontSize:11))),
    ]),
    if(visibleMemo.trim().isNotEmpty)...[
     const SizedBox(height:6),
     Row(children:[
      Icon(Icons.notes_rounded,size:15,color:textColor),
      const SizedBox(width:5),
      Expanded(child:WaffraText(visibleMemo,maxLines:compact?1:4,
       overflow:TextOverflow.ellipsis,
       style:TextStyle(fontSize:12,color:textColor))),
     ]),
    ],
    if(t.isReversed||t.isReversal)...[
     const SizedBox(height:6),
     Row(children:[
      const Icon(Icons.verified_outlined,color:accent,size:16),
      const SizedBox(width:6),
      Expanded(child:WaffraText(
       t.isReversal?
        (waffraIsEnglish?'Correction of original transfer':
         'عملية عكس للتحويل الأصلي'):
        (waffraIsEnglish?'Transfer was reversed':'تم عكس التحويل'),
       style:TextStyle(color:textColor,fontWeight:FontWeight.w700,
        fontSize:12))),
     ]),
    ],
    if(!t.isReversal&&!t.isReversed)
     Align(alignment:AlignmentDirectional.centerStart,
      child:TextButton.icon(
       key:Key('m1032-reverse-transfer-'+t.id),
       onPressed:WaffraHaptics.tap(()=>
        _m1032ReverseTransfer(t,onReversed:onReversed)),
       icon:const Icon(Icons.undo_rounded,size:17),
       label:WaffraText(waffraIsEnglish?
        'Reverse transfer':'عكس التحويل'))),
    if(t.reversalId!=null||t.originalTransferId!=null)
     Align(alignment:AlignmentDirectional.centerStart,
      child:TextButton.icon(
       key:Key('m1036-related-transfer-'+t.id),
       onPressed:WaffraHaptics.tap((){
        final related=t.reversalId??t.originalTransferId!;
        if(onOpenRelated!=null){onOpenRelated(related);}
        else{_m647ShowInternalTransfers(focusId:related);}
       }),
       icon:const Icon(Icons.link,size:16),
       label:WaffraText(
        t.isReversal?
         (waffraIsEnglish?'View original transfer':'عرض التحويل الأصلي'):
         (waffraIsEnglish?'View correction':'عرض عملية العكس')))),
    if(originalSms!=null&&originalSms.trim().isNotEmpty)
     Align(alignment:AlignmentDirectional.centerStart,
      child:TextButton.icon(
       key:Key('m1011-transfer-original-'+t.id),
       icon:const Icon(Icons.lock_outline_rounded,size:17),
       label:WaffraText(waffraIsEnglish?
        'View original bank message':'عرض نص الرسالة البنكية الأصلية'),
       onPressed:WaffraHaptics.tap(()=>showWaffraDialog<void>(
        context:context,builder:(dialog)=>AlertDialog(
         title:WaffraText(waffraIsEnglish?
          'Original bank message':'نص الرسالة البنكية الأصلية'),
         content:SingleChildScrollView(child:SelectableText(originalSms)),
         actions:[TextButton(
          onPressed:()=>Navigator.pop(dialog),
          child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]))))),
   ]));
 }


 /// M649: this gold card never writes to or doubles the financial ledger.
 Widget _m649SavingsCard(WaffraVerifiedGoalMovement movement){
  final dark=Theme.of(context).brightness==Brightness.dark;
  final account=_m467Accounts.where((a)=>a.id==movement.accountId).toList();
  final accountName=account.length==1?_m647VerifiedAccountLabel(account.single):
   (waffraIsEnglish?'Account unavailable':'حساب غير متاح');
  final funded=movement.kind=='fund';
  final when=DateTime.tryParse(movement.occurredIso);
  final accent=dark?const Color(0xFFF4D790):const Color(0xFF866017);
  return Container(
   key:Key('m649-verified-saving-'+movement.id),
   constraints:const BoxConstraints(minHeight:96),
   margin:const EdgeInsets.symmetric(vertical:3),
   padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
   decoration:BoxDecoration(
    color:dark?const Color(0xFF3C3223):const Color(0xFFF8F0D9),
    borderRadius:BorderRadius.circular(17),
    border:Border.all(color:accent.withValues(alpha:.36))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     Icon(Icons.account_balance_wallet_outlined,color:accent,size:22),
     const SizedBox(width:5),
     Expanded(child:WaffraText(funded?
      (waffraIsEnglish?'Savings contribution':'إضافة مبلغ للهدف الادخاري'):
      (waffraIsEnglish?'Savings withdrawal':'سحب من الادخار'),
      style:TextStyle(fontWeight:FontWeight.bold,color:accent,fontSize:12))),
     WaffraText(waffraIsEnglish?'Amount':'المبلغ',style:TextStyle(color:accent,fontSize:11)),
     const SizedBox(width:5),
     WaffraCurrencyAmount(movement.amountMinor/100,fontSize:13,color:accent),
    ]),
    const SizedBox(height:4),
    WaffraText(movement.goalName,maxLines:2,
     style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
    const SizedBox(height:3),
    WaffraText(funded?
     (waffraIsEnglish?'From: ':'من: ')+accountName+
      (waffraIsEnglish?'  →  Goal wallet':'  ←  محفظة الهدف'):
     (waffraIsEnglish?'Goal wallet  →  ':'محفظة الهدف  ←  ')+accountName,
     maxLines:2,overflow:TextOverflow.ellipsis,
     style:const TextStyle(fontSize:11,height:1.25)),
    const SizedBox(height:3),
    WaffraText(when==null?movement.occurredIso:dayText(when),
     style:TextStyle(color:accent,fontSize:10)),
   ]));
 }

 /// M647: content-sized sheet replaces a forced 70% blank white pane.
 Future<void> _m647ShowInternalTransfers({String? focusId})async{
  final selected=_m467SelectedAccount;
  Future<List<WaffraInternalTransferHistory>> future=
   _m648HomeTransfers(selected);
  String? focusedId=focusId;
  if(!mounted)return;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,
   showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(
    builder:(sheetContext,setSheetState)=>ConstrainedBox(
     constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheet).height*.82),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,4,12,8),
       child:Row(children:[
        const Icon(Icons.swap_horiz_rounded,color:Color(0xFF2764AD)),
        const SizedBox(width:8),
        Expanded(child:WaffraText(waffraIsEnglish?
         'Transfers between my accounts':'التحويلات بين حساباتي',
         style:Theme.of(sheet).textTheme.titleLarge)),
        if(focusedId!=null)
         IconButton(
          tooltip:waffraIsEnglish?'All transfers':'جميع التحويلات',
          onPressed:()=>setSheetState(()=>focusedId=null),
          icon:const Icon(Icons.arrow_back_rounded)),
        IconButton(onPressed:()=>Navigator.pop(sheet),
         icon:const Icon(Icons.close)),
       ])),
      Flexible(child:FutureBuilder<List<WaffraInternalTransferHistory>>(
       future:future,builder:(ctx,snapshot){
        if(snapshot.connectionState!=ConnectionState.done){
         return const Padding(padding:EdgeInsets.all(42),
          child:Center(child:CircularProgressIndicator(strokeWidth:3)));
        }
        if(snapshot.hasError){
         return Padding(padding:const EdgeInsets.all(24),
          child:WaffraText(waffraIsEnglish?
           'Transfer history could not be verified. No data changed.':
           'تعذر التحقق من سجل التحويلات. لم تتغير أي بيانات.',
           textAlign:TextAlign.center));
        }
        final items=(snapshot.data??const <WaffraInternalTransferHistory>[])
         .where((t)=>focusedId==null||t.id==focusedId).toList();
        if(items.isEmpty){
         return Padding(padding:const EdgeInsets.all(32),
          child:WaffraText(waffraIsEnglish?
           'No verified transfers for this account.':
           'لا توجد تحويلات موثقة لهذا الحساب.',
           textAlign:TextAlign.center));
        }
        return ListView.builder(
         shrinkWrap:true,padding:const EdgeInsets.fromLTRB(16,0,16,20),
         itemCount:items.length,itemBuilder:(ctx,index)=>
          _m647TransferCard(items[index],
           onReversed:(){
            if(!sheetContext.mounted)return;
            setSheetState(()=>future=_m648HomeTransfers(selected));
           },
           onOpenRelated:(id){
            if(!sheetContext.mounted)return;
            setSheetState(()=>focusedId=id);
           }));
       })),
     ]))));
 }

 Widget _dashboardShortcut(String title,IconData icon,VoidCallback onTap)=>
  this._m684DashboardShortcut(title,icon,onTap);
 Widget homeSummaryCard(String label,double value,IconData symbol,Color color,Color tint)=>
  this._m684HomeSummaryCard(label,value,symbol,color,tint);
}
