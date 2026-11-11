import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  const guard = WaffraLiveLegacyFinanceGuard();

  test('fresh and existing legacy preferences stay readable', () async {
    SharedPreferences.setMockInitialValues({});
    final empty = await SharedPreferences.getInstance();
    await guard.requireLegacySource(empty);
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_goals_v24': '[]',
      'waffra_language': 'ar',
    });
    final old = await SharedPreferences.getInstance();
    await guard.requireLegacySource(old);
    expect(old.getString('entries'), '[]');
  });

  test('active encrypted marker blocks legacy reads even when false', () async {
    for (final value in [true, false, 'corrupt']) {
      SharedPreferences.setMockInitialValues({
        WaffraLiveLegacyFinanceGuard.activeKey: value,
        'entries': jsonEncode([
          {'id':'existing','amount':100},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      await expectLater(guard.requireLegacySource(prefs),
          throwsA(isA<StateError>()));
      // The guard itself never rewrites or deletes the old record.
      expect(prefs.getString('entries'), contains('existing'));
    }
  });

  test('pending activation marker blocks legacy writes and reads', () async {
    SharedPreferences.setMockInitialValues({
      WaffraLiveLegacyFinanceGuard.pendingKey: 'prepare',
      'waffra_goals_v24': '[{"id":"goal","saved":400}]',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(guard.requireLegacySource(prefs),
        throwsA(isA<StateError>()));
    expect(prefs.getString('waffra_goals_v24'), contains('400'));
  });

  test('without activation evidence no accounts or balances are reset', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"old"}]',
      'waffra_goals_v24': '[{"id":"goal"}]',
      'waffra_sms_hashes_v1': <String>['previous-hash'],
    });
    final prefs = await SharedPreferences.getInstance();
    await guard.requireLegacySource(prefs);
    expect(prefs.getString('entries'), contains('old'));
    expect(prefs.getString('waffra_goals_v24'), contains('goal'));
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['previous-hash']);
  });

  test('M636 widget shortcut cannot bypass an activated encrypted finance source',() async {
    SharedPreferences.setMockInitialValues({
      WaffraLiveLegacyFinanceGuard.activeKey: true,
      'entries':'[{"id":"existing-verified"}]',
      'waffra_language':'ar',
    });
    final prefs=await SharedPreferences.getInstance();
    await expectLater(guard.requireLegacySource(prefs),
      throwsA(isA<StateError>()));
    // No obsolete widget capture engine can read or rewrite these records.
    expect(prefs.getString('entries'),contains('existing-verified'));
    final native=File('native/WaffraWidget.kt').readAsStringSync();
    expect(native,contains('Intent(context, MainActivity::class.java)'));
    expect(File('lib/waffra_widget_capture.part.dart').existsSync(),isFalse);
  });
}
