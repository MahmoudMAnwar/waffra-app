part of 'main.dart';

/// M840 / Issue #633: original verified finance transaction widget source sync.
/// No ledger amount calculation or writer intentionally changed.
extension _WaffraHomeWidgetSync on _HomeScreenState {
 Future<void> _syncWidgetTransactions()async{
  if(!mounted||!ready)return;
  try{
   await _ensureFinanceBound();
   final loadedFinance=await _financeAuthority.load(route:WaffraFinanceRoute.dashboardRead);
   loadedFinance.finance.requireIntegrity();
   final revision=loadedFinance.widgetRevision;
   // A newer widget write invalidates the dashboard's previous baseline.
   // Never carry a pre-widget snapshot into another finance save.
   if(revision==null||revision==_lastWidgetRevision)return;
   final raw=loadedFinance.ledgerRaw;
   if(raw==null)return;
   // Widget resume may follow a biometric/background transition. Decode
   // large verified ledgers off Flutter's UI isolate to preserve tap/animation
   // frames; this is read-only and keeps all finance integrity gates intact.
   final parsed=await WaffraLargeJsonDecode.parse(raw);
   if(parsed is! List)throw const FormatException(
    'Widget finance ledger is not a list.');
   final loaded=await _m593BuildVerifiedEntries(parsed);
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(loaded);
    _lastWidgetRevision=revision;
    _lastLedgerSavedRaw=raw;
    _lastFinanceAuthorityRead=loadedFinance;
   });
   unawaited(_refreshWidget());
  }catch(e){
   debugPrint('Widget ledger sync failed safely: $e');
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Financial data could not be verified after widget activity. Retry safely.':
     'تعذر التحقق من البيانات بعد إضافة عملية من الويدجت. أعد المحاولة بأمان.';
   });
  }
 }
 /// Refresh from the authoritative source, not an in-memory repaint.
 /// A failed integrity check never replaces user money with zeroes.
 // M474: coalesce overlapping user refresh gestures only. Internal verified
 // finance reads/writes still run independently after each committed change.
}
