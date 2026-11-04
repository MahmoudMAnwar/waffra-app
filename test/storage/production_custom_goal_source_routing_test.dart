import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraHomeFinancePersistence persistence;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m75-custom-goals-');
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"previous-transaction","amount":10}]',
      'waffra_custom_goals_v1': <String>['Home'],
    });
    persistence = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
      ),
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M75 suggestions are loaded through the common source guard',
      () async {
    final first = await persistence.loadCustomGoalSuggestions();
    expect(first, ['Home']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(
      persistence.loadCustomGoalSuggestions(), throwsA(isA<StateError>()),
    );
    expect(prefs.getString('entries'), contains('previous-transaction'));
  });

  test('M75 concurrent writers merge unique goals without stale overwrites',
      () async {
    final results = await Future.wait([
      persistence.addCustomGoalSuggestion(' سيارة '),
      persistence.addCustomGoalSuggestion('سفر'),
      persistence.addCustomGoalSuggestion('سيارة'),
      persistence.addCustomGoalSuggestion('Travel'),
    ]);
    expect(results.where((added) => added).length, 3);
    // The native cross-writer lock guarantees one complete mutation,
    // but concurrent call acquisition order is deliberately unspecified.
    // Prove no missing/duplicate goals without assuming thread scheduling.
    final persisted = await persistence.loadCustomGoalSuggestions();
    expect(persisted.length, 4);
    expect(persisted.first, 'Home');
    expect(persisted.toSet(), {'Home', 'سيارة', 'سفر', 'Travel'});
    expect(persisted.where((name) => name == 'سيارة').length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('previous-transaction'));
  });

  test('M75 activated source never permits legacy custom catalog edits',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    await expectLater(
      persistence.addCustomGoalSuggestion('Vacation'),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getStringList('waffra_custom_goals_v1'), ['Home']);
  });

  test('M75 malformed goal names and duplicate suggestions fail safely',
      () async {
    await expectLater(
      persistence.addCustomGoalSuggestion(' '),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      persistence.addCustomGoalSuggestion(List<String>.filled(101, 'a').join()),
      throwsA(isA<ArgumentError>()),
    );
    expect(await persistence.addCustomGoalSuggestion(' home '), isFalse);
    final current = await persistence.loadCustomGoalSuggestions();
    expect(current, ['Home']);
  });

  test('M75 custom suggestions remain independent of profile preferences',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('waffra_profile', '{"name":"Tester"}');
    await persistence.addCustomGoalSuggestion('Education');
    expect(prefs.getString('waffra_profile'), '{"name":"Tester"}');
    expect(prefs.getString('entries'), contains('previous-transaction'));
  });
}
