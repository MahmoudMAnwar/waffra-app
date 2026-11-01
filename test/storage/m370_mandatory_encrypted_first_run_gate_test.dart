import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_mandatory_encrypted_first_run_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

void main() {
  const gate = WaffraMandatoryEncryptedFirstRunGate();

  WaffraMandatoryFirstRunVerdict check({
    Map<String,Object?> preferences = const {},
    bool file = false,
    bool key = false,
    bool pointer = false,
    bool writer = false,
    bool routes = false,
    bool backup = false,
    bool lock = false,
  }) => gate.evaluate(
    existingPreferences: preferences,
    encryptedVaultFileExists: file,
    activationMarkerExists: pointer,
    secureKeyExists: key,
    independentWriterMayBeActive: writer,
    verifiedLiveRoutes: routes ? WaffraFinanceRoute.values.toSet() : const {},
    portableAllDomainsAndReceiptsVerified: backup,
    homeWidgetCrossEngineLockVerified: lock,
  );

  test('M370 fresh install does not silently fallback to legacy finance', () {
    final verdict=check();
    expect(verdict.action,
      WaffraMandatoryFirstRunAction.blockedUntilEncryptedRuntimeCertified);
    expect(verdict.mayPrepareNewVault,false);
    expect(verdict.mayAutomaticallyActivate,false);
  });

  test('M370 all 24 certified routes and portable archive permit only staging',
      () {
    final verdict=check(routes:true,backup:true,lock:true);
    expect(verdict.action,
      WaffraMandatoryFirstRunAction.provisionEncryptedCandidateOnly);
    expect(verdict.mayPrepareNewVault,true);
    expect(verdict.mayAutomaticallyActivate,false);
  });

  test('M370 no backup, missing Widget lock or even one unverified route blocks',
      () {
    expect(check(routes:true,lock:true).mayPrepareNewVault,false);
    expect(check(routes:true,backup:true).mayPrepareNewVault,false);
    final missing=WaffraFinanceRoute.values.toSet()
      ..remove(WaffraFinanceRoute.widgetSmsConfirmedSave);
    final result=gate.evaluate(
      existingPreferences:const {},
      encryptedVaultFileExists:false,
      activationMarkerExists:false,
      secureKeyExists:false,
      independentWriterMayBeActive:false,
      verifiedLiveRoutes:missing,
      portableAllDomainsAndReceiptsVerified:true,
      homeWidgetCrossEngineLockVerified:true,
    );
    expect(result.mayPrepareNewVault,false);
  });

  test('M370 preexisting manual records cannot be treated as fresh', () {
    for(final prefs in <Map<String,Object?>>[
      {'entries':'[]'},
      {'waffra_goals_v24':'[]'},
      {'waffra_categories_v24':'[]'},
      {'waffra_user_id':'synthetic'},
      {'waffra_language':'invalid'},
      {'waffra_dark_mode':'not-a-boolean'},
    ]) {
      final verdict=check(preferences:prefs,
        routes:true,backup:true,lock:true);
      expect(verdict.action,
        WaffraMandatoryFirstRunAction.preserveAndReviewLegacy,
        reason:'No existing user data, even empty arrays, may be erased');
    }
  });

  test('M370 a broken key/file pair blocks before any fresh provisioning', () {
    for(final state in [(true,false),(false,true)]) {
      final result=check(file:state.$1,key:state.$2,
        routes:true,backup:true,lock:true);
      expect(result.action,
        WaffraMandatoryFirstRunAction.manualRecoveryRequired);
      expect(result.mayAutomaticallyActivate,false);
    }
  });

  test('M370 existing activated encrypted vault must be verified, never reset',
      () {
    final result=check(file:true,key:true,pointer:true,
      routes:true,backup:true,lock:true);
    expect(result.action,
      WaffraMandatoryFirstRunAction.verifyExistingEncryptedVault);
    expect(result.mayPrepareNewVault,false);
    expect(result.mayAutomaticallyActivate,false);
  });

  test('M370 unmarked vault, dangling pointer or concurrent writer fail closed',
      () {
    for(final verdict in [
      check(file:true,key:true,pointer:false,
        routes:true,backup:true,lock:true),
      check(pointer:true,routes:true,backup:true,lock:true),
      check(writer:true,routes:true,backup:true,lock:true),
    ]) {
      expect(verdict.action,
        WaffraMandatoryFirstRunAction.manualRecoveryRequired);
    }
  });

  test('M370 appearance-only setup remains eligible without ignoring finance',
      () {
    final verdict=check(preferences:{
      'waffra_language':'ar','waffra_dark_mode':false,
    },routes:true,backup:true,lock:true);
    expect(verdict.mayPrepareNewVault,true);
    expect(verdict.mayAutomaticallyActivate,false);
  });
}
