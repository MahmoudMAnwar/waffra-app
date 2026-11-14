part of 'main.dart';

/// M905 #633 unchanged verified transfer and savings history cache methods.
extension _WaffraHomeUnifiedActivityReads on _HomeScreenState {
 void _m648InvalidateTransfers(){
  _m648TransferAccountKey=null;
  _m648TransferRead=null;
  _m649SavingsAccountKey=null;
  _m649SavingsRead=null;
  _m652ActivityAccountKey=null;
  _m652ActivityRead=null;
  _m650DueSourceCache.clear();
 }
 Future<List<WaffraInternalTransferHistory>> _m648HomeTransfers(String account){
  if(_m648TransferAccountKey==account&&_m648TransferRead!=null){
   return _m648TransferRead!;
  }
  final bridge=_financeBinding?.accountsBridge;
  _m648TransferAccountKey=account;
  _m648TransferRead=bridge==null
   ?Future<List<WaffraInternalTransferHistory>>.error(
     StateError('Verified transfer history source unavailable'))
   :WaffraVerifiedAccountsApi(bridge:bridge)
     .readInternalTransferHistory(accountId:account=='all'?null:account);
  return _m648TransferRead!;
 }
 // M649: source linked goal movements are read only and display account-bound.
 Future<List<WaffraVerifiedGoalMovement>> _m649HomeSavings(String account){
  if(_m649SavingsAccountKey==account&&_m649SavingsRead!=null){
   return _m649SavingsRead!;
  }
  final bridge=_financeBinding?.accountsBridge;
  _m649SavingsAccountKey=account;
  _m649SavingsRead=bridge==null?
   Future<List<WaffraVerifiedGoalMovement>>.error(
    StateError('Verified goal source unavailable')):
   WaffraVerifiedAccountsApi(bridge:bridge)
    .readGoalAccountMovementHistory(accountId:account=='all'?null:account);
  return _m649SavingsRead!;
 }
 // Preserve the first Home frame: merged reads are cached, not awaited.
 Future<({
  List<WaffraInternalTransferHistory> transfers,
  List<WaffraVerifiedGoalMovement> savings,
 })> _m652UnifiedActivities(String account){
  if(_m652ActivityAccountKey==account&&_m652ActivityRead!=null){
   return _m652ActivityRead!;
  }
  _m652ActivityAccountKey=account;
  _m652ActivityRead=()async{
   final transfers=await _m648HomeTransfers(account);
   final savings=await _m649HomeSavings(account);
   return (transfers:transfers,savings:savings);
  }();
  return _m652ActivityRead!;
 }
}
