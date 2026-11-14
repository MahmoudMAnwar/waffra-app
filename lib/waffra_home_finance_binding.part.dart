part of 'main.dart';

/// M930 / Issue #633: original verified session/nav method extraction.
extension _WaffraHomeFinanceBinding on _HomeScreenState {
 Future<void> _ensureFinanceBound()async{
  if(_financeBinding!=null)return;
  final pending=_financeBindingFuture??=_bindFinanceSource();
  try{await pending;}
  catch(_){if(identical(_financeBindingFuture,pending))_financeBindingFuture=null;rethrow;}
 }
 Future<void> _bindFinanceSource()async{
  // Reuse the exact verified owner/session connection; if speculative open
  // failed, use the existing fail-closed original binder instead.
  final pendingWarm=_m631PrewarmConsumed?null:widget.prewarmedFinanceBinding;
  _m631PrewarmConsumed=true;
  final warmed=await pendingWarm;
  if(kProfileMode)debugPrint('WAFFRA_AUTH_PERF home_binding_reused=${warmed!=null}');
  final binding=warmed??await WaffraProductionFinanceAuthorityBinding.bind(
    installedApp:true,
   // The first mandatory Home dashboard read validates this source;
   // skip the duplicate encrypted snapshot read during binder setup.
   deferInitialDashboardRead:true,
   legacy:_homeFinancePersistence,
   startupRoute:WaffraFinanceRoute.appStartup,
  );
  if(!mounted){await binding.close();throw StateError('Home startup was disposed.');}
  _financeBinding=binding;
  _financeAuthority=binding.authority;
 }
}
