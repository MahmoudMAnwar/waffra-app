import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory lockDirectory;

  setUp(() async {
    lockDirectory = await Directory.systemTemp.createTemp(
      'waffra-m73-locked-selector-',
    );
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"old-existing-transaction"}]',
    });
  });

  tearDown(() async {
    if (await lockDirectory.exists()) {
      await lockDirectory.delete(recursive: true);
    }
  });

  WaffraLegacyFinanceWriterCoordinator coordinator({
    Future<void> Function(SharedPreferences)? inspector,
  }) => WaffraLegacyFinanceWriterCoordinator(
    testDirectory: lockDirectory,
    sourceProbe: inspector,
  );

  test('M73 source changed between startup and widget save is blocked IN lock',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final firstPreflight = coordinator();
    await firstPreflight.withCurrentPreferences((prefs) async {
      expect(prefs.getString('entries'), contains('old-existing-transaction'));
    });

    var entered = false;
    final lockedProbe = coordinator(inspector: (prefs) async {
      expect(prefs.getString('entries'), contains('old-existing-transaction'));
      // Mock a concurrently visible encrypted source witness: it must be
      // checked while holding the same lock BEFORE the save callback.
      if (prefs.getBool('test_encrypted_witness') == true) {
        throw StateError('Encrypted source activated while app was open.');
      }
    });
    await preferences.setBool('test_encrypted_witness', true);
    await expectLater(lockedProbe.withCurrentPreferences((prefs) async {
      entered = true;
      await prefs.setString('entries', '[]');
    }), throwsA(isA<StateError>()));
    expect(entered, isFalse);
    expect(preferences.getString('entries'),
        contains('old-existing-transaction'));
  });

  test('M73 rejected probe prevents legacy journal replay or user callbacks',
      () async {
    var probeCount = 0;
    var callbacks = 0;
    final denied = coordinator(inspector: (_) async {
      probeCount++;
      throw StateError('OS encryption key mismatch');
    });
    await expectLater(denied.withCurrentPreferences((prefs) async {
      callbacks++;
      await prefs.remove('entries');
    }), throwsA(isA<StateError>()));
    expect(probeCount, 1);
    expect(callbacks, 0);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('entries'), contains('old-existing-transaction'));
  });

  test('M73 source probe is serialized across independent writer engines',
      () async {
    var active = 0;
    var maxConcurrent = 0;
    var count = 0;
    final probe = (SharedPreferences prefs) async {
      active++;
      if (active > maxConcurrent) maxConcurrent = active;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        expect(prefs.getBool(WaffraLiveLegacyFinanceGuard.activeKey), isNull);
      } finally {
        active--;
      }
    };
    final first = coordinator(inspector: probe);
    final second = coordinator(inspector: probe);
    await Future.wait(List.generate(8, (i) {
      final writer = i.isEven ? first : second;
      return writer.withCurrentPreferences((prefs) async {
        final old = prefs.getInt('test_counter') ?? 0;
        await prefs.setInt('test_counter', old + 1);
        count++;
      });
    }));
    expect(count, 8);
    expect(maxConcurrent, 1);
    expect((await SharedPreferences.getInstance()).getInt('test_counter'), 8);
  });

  test('M73 pending/active cutover is rejected before user probe',
      () async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    var called = false;
    final worker = coordinator(inspector: (_) async { called = true; });
    await expectLater(worker.withCurrentPreferences((prefs) async {
      await prefs.setString('entries', '[]');
    }), throwsA(isA<StateError>()));
    expect(called, isFalse);
    expect(p.getString('entries'), contains('old-existing-transaction'));
  });
}
