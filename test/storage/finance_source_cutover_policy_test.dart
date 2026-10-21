import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_finance_source_cutover_policy.dart';

void main() {
  const policy=WaffraFinanceSourceCutoverPolicy();
  const marker=WaffraFinanceSourceCutoverPolicy.preferenceActivationKey;

  WaffraFinanceSourceStatus resolve({
    Map<String,Object?> preferences=const {},
    bool file=false,bool key=false,bool sql=false,
    bool writersFrozen=true,bool enabled=true,
  })=>policy.resolve(WaffraFinanceSourceEvidence(
    preferences:preferences,
    encryptedFileExists:file,
    encryptedKeyReadable:key,
    encryptedSqlActivationVerified:sql,
    cooperatingWritersFrozen:writersFrozen,
    encryptedFeatureAvailable:enabled,
  ));

  test('truly new, fully frozen device is candidate only',(){
    expect(resolve(),WaffraFinanceSourceStatus.freshCandidate);
    expect(resolve(writersFrozen:false),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('empty legacy finance array is NOT a fresh finance source',(){
    expect(resolve(preferences:{'entries':'[]'}),
        WaffraFinanceSourceStatus.legacyPreferences);
    expect(resolve(preferences:{'waffra_goals_v24':'[]'}),
        WaffraFinanceSourceStatus.legacyPreferences);
    expect(resolve(preferences:{'waffra_monthly_budget_v1':0.0}),
        WaffraFinanceSourceStatus.legacyPreferences);
  });

  test('unrecognized and existing account keys use legacy review',(){
    expect(resolve(preferences:{'waffra_profile':'{}'}),
        WaffraFinanceSourceStatus.legacyPreferences);
    expect(resolve(preferences:{'unknown_setting':true}),
        WaffraFinanceSourceStatus.legacyPreferences);
  });

  test('valid appearance-only settings do not force finance wipe',(){
    expect(resolve(preferences:{
      'waffra_language':'ar',
      'waffra_dark_mode':true,
    }),WaffraFinanceSourceStatus.freshCandidate);
  });

  test('consistent independent witnesses select encrypted vault',(){
    expect(resolve(preferences:{
      marker:true,
      'entries':'[{"id":"old"}]',
    },file:true,key:true,sql:true),
        WaffraFinanceSourceStatus.encryptedVault);
  });

  test('orphan database cannot be overwritten with new blank finance',(){
    expect(resolve(file:true,key:true,sql:false),
        WaffraFinanceSourceStatus.recoveryRequired);
    expect(resolve(file:true,key:false),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('missing DB with activation pointer is a recovery error',(){
    expect(resolve(preferences:{marker:true},file:false,key:false),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('SQL pointer without preferences pointer needs recovery',(){
    expect(resolve(file:true,key:true,sql:true),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('a corrupt or false activation pointer requires recovery',(){
    expect(resolve(preferences:{marker:false}),
        WaffraFinanceSourceStatus.recoveryRequired);
    expect(resolve(preferences:{marker:'true'},file:true,key:true,sql:true),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('encrypted users cannot silently fall back in a disabled release',(){
    expect(resolve(preferences:{marker:true},file:true,key:true,sql:true,
        enabled:false),WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('an encryption key without a vault can indicate lost data',(){
    expect(resolve(key:true),
        WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('legacy mode is still discoverable without encryption availability',(){
    expect(resolve(preferences:{'entries':'[]'},enabled:false,
        writersFrozen:false),
        WaffraFinanceSourceStatus.legacyPreferences);
  });
}
