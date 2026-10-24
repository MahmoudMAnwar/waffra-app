import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;

  Future<WaffraFinanceReadView> read() async {
    final persistence = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: temporary,
        testBypassNativeLock: true,
      ),
    );
    return (await persistence.loadWithWitness()).finance;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('waffra-finance-startup-');
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('empty first install safely passes without creating defaults', () async {
    final view = await read();
    expect(() => view.requireIntegrity(), returnsNormally);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('valid finance and ordinary profile settings remain intact', () async {
    SharedPreferences.setMockInitialValues({
      'entries':
          '[{"id":"one","title":"POS","category":"Shopping","amount":12.5,'
          '"income":false,"date":"2026-10-21T18:00:00","receiptPath":null}]',
      'waffra_goals_v24':
          '[{"id":"goal","name":"Trip","target":2000,"saved":300}]',
      'waffra_monthly_budget_v1': 850.75,
      'waffra_profile': '{"name":"Do not copy as finance"}',
    });
    final view = await read();
    expect(() => view.requireIntegrity(), returnsNormally);
    expect(view.getString('waffra_goals_v24'), contains('Trip'));
    expect(view.getDouble('waffra_monthly_budget_v1'), 850.75);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_profile'),
        '{"name":"Do not copy as finance"}');
  });

  test('invalid ledger JSON blocks finance readiness and does not reset', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"broken"',
    });
    final view = await read();
    expect(() => view.requireIntegrity(), throwsA(isA<StateError>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), '[{"id":"broken"');
  });

  test('duplicate transaction IDs block unsafe startup', () async {
    const record =
        '{"id":"same","amount":1,"income":false,"date":"2026-10-21"}';
    SharedPreferences.setMockInitialValues({
      'entries': '[$record,$record]',
    });
    final view = await read();
    expect(() => view.requireIntegrity(), throwsA(isA<StateError>()));
  });

  test('corrupt goal cannot be turned into empty goals list', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_goals_v24':
          '[{"id":"goal","name":"Trip","target":1000,"saved":-10}]',
    });
    final view = await read();
    expect(() => view.requireIntegrity(), throwsA(isA<StateError>()));
    expect((await SharedPreferences.getInstance()).getString(
        'waffra_goals_v24'), contains('"saved":-10'));
  });

  test('unsupported money precision blocks startup', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_monthly_budget_v1': 12.345,
    });
    final view = await read();
    expect(() => view.requireIntegrity(), throwsA(isA<StateError>()));
  });

  test('malformed deleted category prevents silent loss of trash', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_deleted_categories_v1':
          '[{"category":{"id":"cat","name":"Food"}}]',
    });
    final view = await read();
    expect(() => view.requireIntegrity(), throwsA(isA<StateError>()));
  });

  test('encrypted and legacy reads share the same integrity guarantee',
      () async {
    final encrypted = WaffraFinanceReadView.fromEncrypted(
      const WaffraFinanceSnapshotState(
        generation: 1, digest: 'synthetic-only',
        values: {'entries': '{"not":"an array"}'},
      ),
    );
    expect(() => encrypted.requireIntegrity(), throwsA(isA<StateError>()));
  });
}
