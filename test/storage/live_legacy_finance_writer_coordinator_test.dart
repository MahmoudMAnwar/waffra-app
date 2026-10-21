import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  WaffraLegacyFinanceWriterCoordinator coordinator() =>
      WaffraLegacyFinanceWriterCoordinator(testDirectory: temp);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('waffra-real-widget-lock-');
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('two independently constructed finance coordinators never overlap',
      () async {
    var concurrent = 0;
    var maximum = 0;
    final results = await Future.wait(List.generate(15, (n) async =>
      coordinator().withCurrentPreferences((prefs) async {
        concurrent++;
        if (concurrent > maximum) maximum = concurrent;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 3));
          final before = prefs.getInt('test_finance_generation') ?? 0;
          final saved = await prefs.setInt('test_finance_generation', before + 1);
          expect(saved, isTrue);
          return n;
        } finally {
          concurrent--;
        }
      }),
    ));
    expect(maximum, 1);
    expect(results.toSet(), Set<int>.from(List.generate(15, (i) => i)));
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('test_finance_generation'), 15);
  });

  test('widget and dashboard see latest persisted transaction list in lock',
      () async {
    final first = coordinator().withCurrentPreferences((prefs) async {
      expect(prefs.getString('entries'), isNull);
      final result = await prefs.setString(
        'entries', '[{"id":"first","amount":9.5}]');
      expect(result, isTrue);
    });
    final second = coordinator().withCurrentPreferences((prefs) async {
      expect(prefs.getString('entries'), contains('first'));
      final result = await prefs.setString(
        'entries', '[{"id":"first","amount":9.5},{"id":"second","amount":5}]');
      expect(result, isTrue);
    });
    await Future.wait([first, second]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('second'));
  });

  test('active or pending cutover marker stops live legacy writes', () async {
    for (final key in [
      WaffraLiveLegacyFinanceGuard.activeKey,
      WaffraLiveLegacyFinanceGuard.pendingKey,
    ]) {
      SharedPreferences.setMockInitialValues({
        key: true,
        'entries': '[{"id":"old"}]',
      });
      await expectLater(coordinator().withCurrentPreferences((prefs) async {
        await prefs.setString('entries', '[]');
      }), throwsA(isA<StateError>()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('entries'), contains('old'));
    }
  });

  test('a failed app writer unlocks and leaves next widget writer running',
      () async {
    await expectLater(coordinator().withCurrentPreferences<void>((prefs) async {
      throw StateError('synthetic app save failed');
    }), throwsA(isA<StateError>()));
    await coordinator().withCurrentPreferences((prefs) async {
      await prefs.setString('entries', '[{"id":"widget"}]');
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('widget'));
  });

  test('do not make a missing test finance directory', () async {
    final nonexistent = Directory('${temp.path}/nonexistent');
    await expectLater(
      WaffraLegacyFinanceWriterCoordinator(testDirectory: nonexistent)
          .withCurrentPreferences((prefs) async => 1),
      throwsA(isA<StateError>()),
    );
    expect(await nonexistent.exists(), isFalse);
  });
}
