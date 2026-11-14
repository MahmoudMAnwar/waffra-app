part of 'main.dart';

/// M929 / Issue #633: byte-preserved Home method extraction; no financial writer change.
extension _WaffraHomeFinanceNotificationRoute on _HomeScreenState {
 void _m621OnFinanceNoticeTap(){
  if(!mounted||!ready||!widget.postAuthVisible||_financeLoadFailure!=null||
     _m621NoticeOpening||_autoSmsReviewOpen)return;
  final target=waffraFinanceNoticeTap.value;
  if(target==null)return;
  final lifecycle=WidgetsBinding.instance.lifecycleState;
  if(lifecycle!=null&&lifecycle!=AppLifecycleState.resumed)return;
  _m621NoticeOpening=true;
  waffraFinanceNoticeTap.value=null;
  WidgetsBinding.instance.addPostFrameCallback((_)async{
   try{
    if(!mounted||!ready||_financeLoadFailure!=null)return;
    if(target.destination=='review'){
     // The existing targeted review performs an owner-verified pendingById.
     // An excluded/stale/committed SMS cannot be posted twice from a tap.
     await _reviewAutoSmsCandidates(targetId:target.id);
    }else if(target.destination=='saved'){
     // Only records from the CURRENT verified finance ledger can open.
     final matching=entries.where((record)=>
      record.id==target.entryId&&record.sourceType=='sms').toList();
     if(matching.length==1){
      await transactionDetails(matching.single);
     }else if(mounted){
      snack(context,waffraIsEnglish?
       'This saved transaction is not available in the current account.':
       'العملية المحفوظة غير موجودة في الحساب الحالي.');
     }
    }
   }catch(error){
    debugPrint('Finance notification route refused: ${error.runtimeType}');
   }finally{
    _m621NoticeOpening=false;
    if(mounted&&waffraFinanceNoticeTap.value!=null){
     _m621OnFinanceNoticeTap();
    }
   }
  });
 }
}
