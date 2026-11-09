import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_finance_authority_binding.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

/// M625: the installed Android Home may skip the *duplicated* binder read.
/// Its immediately following dashboard read must still verify the actual
/// SQLCipher witness and owner-specific ledger BEFORE first visible Home.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deferred read cannot be requested by unrelated bindings', () async {
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        deferInitialDashboardRead: true,
      ),
      throwsArgumentError,
    );
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        installedApp: true,
        startupRoute: WaffraFinanceRoute.widgetStartup,
        deferInitialDashboardRead: true,
      ),
      throwsArgumentError,
    );
  });

  test('only installed Home skips duplicated full read, never source checks', () {
    final binder=File('lib/storage/waffra_production_finance_authority_binding.dart')
        .readAsStringSync();
    final app=File('lib/main.dart').readAsStringSync();
    final binding=app.split(' Future<void> _bindFinanceSource()async{')[1]
        .split(' // Account filters are presentation-only;')[0];
    expect(binding,contains('installedApp:true,'));
    expect(binding,contains('deferInitialDashboardRead:true,'));
    expect(binding,contains('startupRoute:WaffraFinanceRoute.appStartup,'));
    expect(binder,contains('if (!deferInitialDashboardRead) {'));
    expect(binder,contains('await sourceGuard.inspect();'));
    expect(binder,contains('await freshInstall.verify(store);'));
    expect(binder,contains('checkpoint.phase != WaffraCutoverPhase.active'));
    expect(binder,contains('await authority.load(route: startupRoute);'));
    expect(binder,contains('await startup.finance.requireIntegrityInBackground();'));
    expect(binder,contains('Only installed Android Home may defer initial dashboard read.'));
    expect(app,contains('final loadedFinance=await WaffraFreshHomeCatalogRecovery.load('));
    expect(app,contains('financeView.requireIntegrity();'));
    expect(app,contains('await (accountsLoading??_m467RefreshHomeAccounts());'));
    expect(app.indexOf('await (accountsLoading??_m467RefreshHomeAccounts());'),
        lessThan(app.indexOf('setState(()=>ready=true);')));
  });

  test('verified biometric and relogin meet identical complete-Home contract', () {
    final app=File('lib/main.dart').readAsStringSync();
    final root=app.split(' Widget _m623RootContent(BuildContext rootContext){')[1]
        .split(' @override Widget build(BuildContext context)=>MaterialApp(')[0];
    final homeLoader=app.split(' Future<void> _loadFinanceSafely()async{')[1]
        .split(' Widget _financialRecoveryScreen()')[0];
    final signIn=app.split(' Future<void> _signIn()async{')[1]
        .split(' String get maskedLastPhone{')[0];
    final saveUser=app.split(' Future<void> saveUser(Person u)async {')[1]
        .split(' Future<void> setUiCountry(')[0];
    final logout=app.split(' Future<void> logout()async {')[1]
        .split(' bool _logoutInProgress=false;')[0];
    expect(signIn,contains('await WaffraLocalPhoneCredentials.verify('));
    expect(signIn,contains('await widget.onVerifiedPasswordSave(verifiedAccount);'));
    expect(root,contains("_m625TraceHandoff('biometric');"));
    expect(saveUser,contains('locked=!ordinaryPhoneRelogin;'));
    expect(saveUser,contains("_m625TraceHandoff('relogin');"));
    expect(root,contains('child:Offstage(offstage:!_m623HomeReady,'));
    expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
    expect(homeLoader.indexOf('await load();'),
        lessThan(homeLoader.indexOf('widget.onVerifiedReady?.call();')));
    expect(homeLoader,contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(homeLoader,contains('Duration(milliseconds:900)'));
    expect(homeLoader,contains('await widget.onVerifiedHomeSmsResume?.call()'));
    expect(homeLoader,contains('await _refreshAutoSmsInbox(importMonth:'));
    expect(logout.indexOf('await WaffraAutoSms.suspendForSignOut()'),
        lessThan(logout.indexOf('profile=null;showLogin=true;')));
    expect(app,contains(r'WAFFRA_AUTH_PERF ${origin}_to_home_first_frame_ms='));
  });
}
