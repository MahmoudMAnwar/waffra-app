import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HomeScreen reads the same finance fields from current legacy prefs',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"legacy"}]',
      'waffra_goals_v24': '[]',
      'waffra_categories_v24': '[]',
      'waffra_recurring_v24': '[]',
      'waffra_monthly_budget_v1': 1450.50,
      'waffra_monthly_budget_enabled_v1': true,
      'waffra_sms_hashes_v1': <String>['hash-a'],
      'waffra_language': 'en',
    });
    final prefs = await SharedPreferences.getInstance();
    final view = WaffraFinanceReadView.fromLegacy(prefs);
    expect(view.getString('entries'), contains('legacy'));
    expect(view.getDouble('waffra_monthly_budget_v1'), 1450.50);
    expect(view.getBool('waffra_monthly_budget_enabled_v1'), isTrue);
    expect(view.getStringList('waffra_sms_hashes_v1'), ['hash-a']);
    expect(view.containsKey('waffra_goals_v24'), isTrue);
    expect(view.containsKey('waffra_deleted_goals_v1'), isFalse);
    expect(prefs.getString('waffra_language'), 'en');
  });

  test('encrypted finance does not fall back to stale SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"old-legacy"}]',
      'waffra_goals_v24': '[{"id":"old-goal"}]',
      'waffra_language': 'ar',
    });
    final vault = WaffraFinanceSnapshotState(
      generation: 3, digest: 'test-digest',
      values: const {
        'entries': '[{"id":"encrypted-new"}]',
        'waffra_goals_v24': '[]',
        'waffra_sms_hashes_v1': <String>[],
      },
    );
    final view = WaffraFinanceReadView.fromEncrypted(vault);
    expect(view.getString('entries'), contains('encrypted-new'));
    expect(view.getString('entries'), isNot(contains('old-legacy')));
    expect(view.getString('waffra_goals_v24'), '[]');
    expect(view.getString('waffra_categories_v24'), isNull);
    expect(view.containsKey('waffra_categories_v24'), isFalse);
    expect(view.getStringList('waffra_sms_hashes_v1'), isEmpty);
  });

  test('absent differs from a saved empty finance list', () {
    final view = WaffraFinanceReadView.fromEncrypted(
      const WaffraFinanceSnapshotState(
        generation: 0, digest: 'test',
        values: {'entries': '[]'},
      ),
    );
    expect(view.containsKey('entries'), true);
    expect(view.getString('entries'), '[]');
    expect(view.containsKey('waffra_goals_v24'), false);
    expect(view.getString('waffra_goals_v24'), isNull);
  });

  test('invalid finance type and unknown profile keys are rejected', () {
    final view = WaffraFinanceReadView.fromEncrypted(
      const WaffraFinanceSnapshotState(
        generation: 0, digest: 'test',
        values: {'entries': true},
      ),
    );
    expect(() => view.getString('entries'), throwsA(isA<StateError>()));
    expect(() => view.getString('waffra_profile'), throwsA(isA<ArgumentError>()));
    expect(() => WaffraFinanceReadView.fromEncrypted(
      const WaffraFinanceSnapshotState(
        generation: 0, digest: 'test',
        values: {'waffra_pin_sha256': 'secret'},
      ),
    ), throwsA(isA<StateError>()));
  });
}
