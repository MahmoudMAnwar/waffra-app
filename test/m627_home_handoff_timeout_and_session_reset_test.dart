import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final app=File('lib/main.dart').readAsStringSync();
  final root=app.split('class _WaffraAppState extends State<WaffraApp>')[1]
    .split('class PinLockScreen extends StatefulWidget')[0];
  final home=app.split('class _HomeScreenState extends State<HomeScreen>')[1];
  final load=home.split(' Future<void> load()async {')[1]
    .split(' Future<void> _refreshWidget()async{')[0];
  final safe=home.split(' Future<void> _loadFinanceSafely()async{')[1]
    .split(' Widget _financialRecoveryScreen()')[0];

  test('M627 profile only timestamps the exact genuine Home stages',() {
    expect(load,contains('final financeClock=kProfileMode?(Stopwatch()..start()):null;'));
    expect(load,contains("debugPrint('WAFFRA_HOME_LOAD_STEP \$stage elapsed_ms='"));
    for(final step in <String>[
      'before_ensureFinanceBound','after_ensureFinanceBound',
      'before_sharedPreferences','after_sharedPreferences',
      'before_catalog_recovery','after_catalog_recovery',
      'before_accounts_refresh','after_accounts_refresh_started',
      'before_accounts_await','after_accounts_await','accounts_timeout',
    ]){
      expect(load,contains("traceHomeStep('$step')"),reason:step);
    }
    expect(load.indexOf("traceHomeStep('before_ensureFinanceBound')"),
      lessThan(load.indexOf('await _ensureFinanceBound();')));
    expect(load.indexOf("traceHomeStep('before_catalog_recovery')"),
      lessThan(load.indexOf('WaffraFreshHomeCatalogRecovery.load(')));
    expect(root,contains('WAFFRA_HOME_LOAD_STEP first_m623HomeLoaded elapsed_ms='));
    expect(root,contains('if(kProfileMode){'));
  });

  test('M627 account timeout fails closed with existing visible Retry',() {
    expect(load,contains('.timeout(const Duration(seconds:15));'));
    expect(load,contains('}on TimeoutException{'));
    expect(load,contains('_m627AccountEpoch++;'));
    expect(load,contains('_m468AccountReadInFlight=null;'));
    expect(load,contains("throw StateError('Verified financial account balances are unavailable.');"));
    expect(safe.indexOf('await load();'),
      lessThan(safe.indexOf('widget.onVerifiedReady?.call();')));
    expect(safe,contains("}catch(e){"));
    expect(safe,contains('_financeLoadFailure=waffraIsEnglish?'));
    expect(safe,contains('if(mounted)widget.onVerifiedReady?.call();'));
    expect(home,contains("label:WaffraText(waffraIsEnglish?'Retry safely':'إعادة المحاولة بأمان')"));
    expect(home,contains('unawaited(_loadFinanceSafely())'));
    expect(home,contains('readEpoch!=_m627AccountEpoch'));
  });

  test('M627 logout drains and closes the old Home before next session',() {
    expect(root,contains('GlobalKey<_HomeScreenState> _m627HomeKey='));
    expect(root,contains("key:ValueKey('home-\$_m627HomeSession')"));
    expect(root,contains('key:_m627HomeKey,'));
    expect(root,contains('await closingHome._m627CloseForLogout();'));
    expect(root.indexOf('await closingHome._m627CloseForLogout();'),
      lessThan(root.indexOf('await _accountWriteAuthority.signOut();')));
    expect(root,contains('_m627HomeSession++;'));
    expect(root,contains('profile=null;showLogin=true;locked=true;'));
    expect(root,contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
    expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));

    final cleanup=home.split(' Future<void> _m627CloseForLogout()async{')[1]
      .split(' void _m627AbortFailedLogout()')[0];
    expect(cleanup,contains('_m627HomeLoadCompletion;'));
    expect(cleanup,contains('await pendingLoad.future.timeout(const Duration(seconds:20));'));
    expect(cleanup,contains('_m627OutstandingAccountReads.toList()'));
    expect(cleanup,contains('await _m468PersistSequence.timeout(const Duration(seconds:20));'));
    expect(cleanup,contains('await _financialWriteQueue.drain().timeout(const Duration(seconds:20));'));
    expect(cleanup,contains('if(pending!=null)await pending;'));
    expect(home,contains('_m627OutstandingAccountReads.add(running);'));
    expect(home,contains('_m627OutstandingAccountReads.remove(running);'));
    expect(home,contains('Completer<void>? _m627HomeLoadCompletion;'));
    expect(home,contains('if(activeLoad!=null){'));
    expect(home,contains('if(_m627ClosingSession)return;'));
    expect(home,contains('if(!completion.isCompleted)completion.complete();'));
    expect(home,contains('if(binding!=null)await binding.close();'));
    expect(home,contains('_financeBinding=null;'));
    expect(home,contains('_financeBindingFuture=null;'));
    expect(home,contains('_financeAuthority=WaffraVerifiedFinanceAuthority(legacy:_homeFinancePersistence);'));
    expect(home,contains('_m627AbortFailedLogout()'));
    expect(root,contains('_m627HomeKey.currentState?._m627AbortFailedLogout();'));
    expect(root,contains('await WaffraAutoSms.suspendForSignOut().timeout('));
  });

  test('M627 never makes SMS a pre-Home loading dependency',() {
    expect(safe.indexOf('widget.onVerifiedReady?.call();'),
      lessThan(safe.indexOf('Duration(milliseconds:900)')));
    expect(safe,contains('await widget.onVerifiedHomeSmsResume?.call()'));
    expect(safe,contains('await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete)'));
  });
}
