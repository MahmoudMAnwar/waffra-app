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
 /// M647: source and destination are separate verified account identities.
 /// Presentation-only: no money write, no inferred sender, no extra expense.
 Widget _m647TransferCard(WaffraInternalTransferHistory t,{bool compact=false}){
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
     Expanded(child:WaffraText(waffraIsEnglish?
      'Between my accounts':'تحويل بين حساباتي',
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
    if(t.note.trim().isNotEmpty)...[
     const SizedBox(height:6),
     Row(children:[
      Icon(Icons.notes_rounded,size:15,color:textColor),
      const SizedBox(width:5),
      Expanded(child:WaffraText(t.note,maxLines:compact?1:4,
       overflow:TextOverflow.ellipsis,
       style:TextStyle(fontSize:12,color:textColor))),
     ]),
    ],
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
  final future=_m648HomeTransfers(selected);
  if(!mounted)return;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,
   showDragHandle:true,
   builder:(sheet)=>ConstrainedBox(
    constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheet).height*.82),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     Padding(padding:const EdgeInsets.fromLTRB(18,4,12,8),
      child:Row(children:[
       const Icon(Icons.swap_horiz_rounded,color:Color(0xFF2764AD)),
       const SizedBox(width:8),
       Expanded(child:WaffraText(waffraIsEnglish?
        'Transfers between my accounts':'التحويلات بين حساباتي',
        style:Theme.of(sheet).textTheme.titleLarge)),
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
        .where((t)=>focusId==null||t.id==focusId).toList();
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
         _m647TransferCard(items[index]));
      })),
    ])));
 }

 Widget _dashboardShortcut(String title,IconData icon,VoidCallback onTap)=>
  this._m684DashboardShortcut(title,icon,onTap);
 Widget homeSummaryCard(String label,double value,IconData symbol,Color color,Color tint)=>
  this._m684HomeSummaryCard(label,value,symbol,color,tint);
}
