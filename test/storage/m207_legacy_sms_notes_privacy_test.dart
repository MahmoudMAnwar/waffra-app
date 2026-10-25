import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';

/// Synthetic, disposable legacy-only regression. Does not enable SQLCipher.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraHomeFinancePersistence persistence;

  Map<String, Object?> sms(String id, {String notes = ''}) => {
    'id': id,
    'title': 'Synthetic merchant',
    'category': 'أخرى',
    'amount': 12.5,
    'income': false,
    'date': '2026-10-24T12:00:00.000Z',
    'receiptPath': null,
    'sourceType': 'sms',
    'notes': notes,
  };
  String encode(List<Map<String, Object?>> rows) => jsonEncode(rows);

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('m207-sms-privacy-');
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>[],
    });
    persistence = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
        testBypassNativeLock: true,
      ),
    );
  });
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('confirmed Home or Widget SMS raw notes fail before any journal write',
      () async {
    await expectLater(
      persistence.commitConfirmedLegacySms(
        records: [sms('one', notes: 'Sensitive raw bank SMS')],
        messageHashes: [List.filled(64, 'a').join()],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(prefs.getString('waffra_widget_last_save_v1'), isNull);
  });

  test('confirmed SMS without original notes still saves under legacy lock',
      () async {
    final result = await persistence.commitConfirmedLegacySms(
      records: [sms('safe')],
      messageHashes: [List.filled(64, 'b').join()],
      userConfirmed: true,
    );
    expect(result.added, 1);
    final rows = jsonDecode(result.savedEntriesRaw) as List;
    expect((rows.single as Map)['notes'], '');
  });

  test('dashboard batch cannot introduce plaintext notes to a new SMS row',
      () async {
    await expectLater(
      persistence.saveLegacy(
        snapshot: {'entries': encode([sms('new', notes: 'Full bank SMS')])},
        expectedLedgerRaw: '[]',
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
  });

  test('existing SMS notes are preserved on unrelated finance updates',
      () async {
    final old = encode([sms('existing', notes: 'Previously stored SMS')]);
    SharedPreferences.setMockInitialValues({'entries': old});
    final next = encode([sms('existing', notes: 'Previously stored SMS')]);
    await persistence.saveLegacy(
      snapshot: {'entries': next, 'waffra_goals_v24': '[]'},
      expectedLedgerRaw: old,
      expectedWidgetRevision: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), next);
    expect(prefs.getString('waffra_goals_v24'), '[]');
  });

  test('changing existing SMS notes or disguising it as manual is blocked',
      () async {
    final old = encode([sms('existing', notes: 'Previously stored SMS')]);
    SharedPreferences.setMockInitialValues({'entries': old});
    final changed = sms('existing', notes: 'Different raw SMS');
    changed['sourceType'] = 'manual';
    await expectLater(
      persistence.saveLegacy(
        snapshot: {'entries': encode([changed])},
        expectedLedgerRaw: old,
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), old);
  });

  test('two-save SMS source downgrade is blocked before plaintext can be added',
      () async {
    // Without an immutable SMS source, an attacker could first relabel the
    // entry with unchanged notes, then save raw SMS as a manual note.
    final old = encode([sms('existing')]);
    SharedPreferences.setMockInitialValues({
      'entries': old,
      'waffra_sms_hashes_v1': <String>[List.filled(64, 'a').join()],
    });
    final downgraded = sms('existing');
    downgraded['sourceType'] = 'manual';
    await expectLater(
      persistence.saveLegacy(
        snapshot: {'entries': encode([downgraded])},
        expectedLedgerRaw: old,
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), old);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), [List.filled(64, 'a').join()]);
    expect(prefs.getString('waffra_widget_last_save_v1'), isNull);
  });

  test('manual transaction notes remain allowed without bank SMS source',
      () async {
    final manual = sms('manual', notes: 'User-written manual note');
    manual['sourceType'] = 'manual';
    final next = encode([manual]);
    await persistence.saveLegacy(
      snapshot: {'entries': next},
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), next);
  });
}
