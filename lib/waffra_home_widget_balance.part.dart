part of 'main.dart';

/// M904 / #633: exact original read-only verified Widget balance.
/// Missing finance source must remain hidden, not a fabricated zero.
extension _WaffraHomeWidgetBalance on _HomeScreenState {
 Future<void> _refreshWidget()async{
  if(!Platform.isAndroid)return;
  try{
   await _ensureFinanceBound();
   final verified=await _financeAuthority.load(
    route:WaffraFinanceRoute.widgetBalanceRefresh);
   await _publishVerifiedWidgetBalance(verified);
  }catch(e){
   debugPrint('Widget source unavailable: ${e.runtimeType}');
   await refreshWaffraHomeWidget(
    balance:'***',negative:false,hidden:true,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }
 }
 Future<void> _publishVerifiedWidgetBalance(
  WaffraFinanceAuthorityRead verified)async{
  if(!Platform.isAndroid)return;
  try{
   verified.finance.requireIntegrity();
   final raw=verified.ledgerRaw;
   if(raw==null)throw StateError('Verified widget ledger is missing.');
   // After authority validation, sum large ledgers on a worker isolate.
   final net=raw.length>=WaffraLargeJsonDecode.isolateThreshold
    ?await compute(WaffraAuthoritativeWidgetBalance.netHalalas,raw)
    :WaffraAuthoritativeWidgetBalance.netHalalas(raw);
   await refreshWaffraHomeWidget(
    balance:hideWaffraAmounts.value?'***':WaffraDisplayCurrency.amount(net/100),
    negative:net<0,
    hidden:hideWaffraAmounts.value,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }catch(e){
   debugPrint('Verified widget balance refresh unavailable: ${e.runtimeType}');
   await refreshWaffraHomeWidget(
    balance:'***',negative:false,hidden:true,
    currency:WaffraDisplayCurrency.label(waffraIsEnglish));
  }
 }
}
