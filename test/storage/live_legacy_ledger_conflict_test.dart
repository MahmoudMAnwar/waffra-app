import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unchanged ledger permits a later local finance write', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"old"}]',
      'waffra_widget_last_save_v1': 'v1',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs,
      expectedRaw: '[{"id":"old"}]',
      expectedWidgetRevision: 'v1',
    ), returnsNormally);
  });

  test('unmarked widget write is detected before dashboard can overwrite',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"old"}]',
      'waffra_widget_last_save_v1': 'v1',
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries',
        '[{"id":"new-from-widget"},{"id":"old"}]');
    // Simulates a process kill *before* widget last-save revision commit.
    expect(prefs.getString('waffra_widget_last_save_v1'), 'v1');
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: '[{"id":"old"}]',
      expectedWidgetRevision: 'v1',
    ), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), contains('new-from-widget'));
  });

  test('changed widget marker alone also blocks stale dashboard', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_widget_last_save_v1': 'v2',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: '[]',
      expectedWidgetRevision: 'v1',
    ), throwsA(isA<StateError>()));
  });

  test('missing and empty finance entries are distinct', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: null, expectedWidgetRevision: null,
    ), returnsNormally);
    await prefs.setString('entries', '[]');
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: null, expectedWidgetRevision: null,
    ), throwsA(isA<StateError>()));
  });

  test('a successful dashboard commit can use its new ledger as baseline',
      () async {
    SharedPreferences.setMockInitialValues({'entries': '[]'});
    final prefs = await SharedPreferences.getInstance();
    WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: '[]', expectedWidgetRevision: null,
    );
    final saved = await prefs.setString('entries', '[{"id":"new"}]');
    expect(saved, isTrue);
    expect(() => WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
      prefs, expectedRaw: '[{"id":"new"}]',
      expectedWidgetRevision: null,
    ), returnsNormally);
  });
}
