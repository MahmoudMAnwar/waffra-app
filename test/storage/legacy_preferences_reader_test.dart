import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_preferences_reader.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
    'entries': '[]',
    'waffra_goals_v24': '[]',
    'waffra_sms_hashes_v1': <String>['first', 'second'],
    'waffra_monthly_budget_v1': 250.25,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_local_password_hash': 'not-for-migration',
    'waffra_pin_sha256': 'never-include',
    'waffra_profile': '{"name":"test"}',
  }));

  test('reads only finance values and never security or user-profile keys', () async {
    final prefs = await SharedPreferences.getInstance();
    final values = await const LegacyPreferencesSnapshotReader().readStable(prefs);
    expect(values['entries'], '[]');
    expect(values['waffra_sms_hashes_v1'], ['first', 'second']);
    expect(values['waffra_monthly_budget_v1'], 250.25);
    expect(values.containsKey('waffra_pin_sha256'), isFalse);
    expect(values.containsKey('waffra_local_password_hash'), isFalse);
    expect(values.containsKey('waffra_profile'), isFalse);
    expect(prefs.getString('waffra_profile'), '{"name":"test"}');
  });

  test('changed source content changes checksum without modifying data', () async {
    final prefs = await SharedPreferences.getInstance();
    final reader = const LegacyPreferencesSnapshotReader();
    final first = await reader.readStable(prefs);
    final hash = WaffraLegacyPreflight.inspect(first).sourceSha256;
    await prefs.setString('entries', '[{"id":"new","date":"2026-10-21","amount":2.00,"income":false}]');
    final second = await reader.readStable(prefs);
    expect(WaffraLegacyPreflight.inspect(second).sourceSha256, isNot(hash));
  });

  test('malformed source does not produce a stageable snapshot', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', '[bad-json');
    await expectLater(
      const LegacyPreferencesSnapshotReader().readStable(prefs),
      throwsStateError,
    );
    expect(prefs.getString('entries'), '[bad-json');
  });
}
