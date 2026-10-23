import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_experimental_writer_gate.dart';

/// M144: defensive checks for the experimental cooperating-writer file gate.
/// Every fixture lives under a disposable directory, never an app database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String lockPath;

  WaffraExperimentalWriterGate gate({bool enabled = true}) =>
      WaffraExperimentalWriterGate(
        disposableDirectory: root,
        experimentalEnabled: enabled,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m144-gate-');
    lockPath = '${root.path}${Platform.pathSeparator}.waffra-writer.lock';
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M144: disabled gate refuses mutation and creates no lock file', () async {
    var invoked = false;
    await expectLater(
      gate(enabled: false).withExclusiveAccess(() async {
        invoked = true;
      }),
      throwsStateError,
    );
    expect(invoked, isFalse);
    expect(await FileSystemEntity.type(lockPath, followLinks: false),
        FileSystemEntityType.notFound);
  });

  test('M144: removed writer directory is not recreated on rejected write', () async {
    await root.delete(recursive: true);
    var invoked = false;
    await expectLater(
      gate().withExclusiveAccess(() async {
        invoked = true;
      }),
      throwsStateError,
    );
    expect(invoked, isFalse);
    expect(await root.exists(), isFalse);
  });

  test('M144: directory occupying lock path blocks writer, then recovers', () async {
    final obstruction = await Directory(lockPath).create();
    var invoked = false;
    await expectLater(
      gate().withExclusiveAccess(() async {
        invoked = true;
      }),
      throwsStateError,
    );
    expect(invoked, isFalse);
    expect(await obstruction.exists(), isTrue);
    await obstruction.delete();
    final result = await gate().withExclusiveAccess(() async => 42);
    expect(result, 42);
    expect(await FileSystemEntity.type(lockPath, followLinks: false),
        FileSystemEntityType.file);
  });

  test('M144: pre-existing symbolic-link lock path cannot redirect writes',
      () async {
    if (Platform.isWindows) return;
    final target = File('${root.path}/sensitive-sentinel.txt');
    await target.writeAsString('keep-existing-data');
    final symlink = await Link(lockPath).create(target.path);
    var invoked = false;
    await expectLater(
      gate().withExclusiveAccess(() async {
        invoked = true;
      }),
      throwsStateError,
    );
    expect(invoked, isFalse);
    expect(await symlink.exists(), isTrue);
    expect(await target.readAsString(), 'keep-existing-data');
    await symlink.delete();
    expect(await gate().withExclusiveAccess(() async => 'recovered'),
        'recovered');
    expect(await target.readAsString(), 'keep-existing-data');
  });

  test('M144: throwing writer releases its gate for the next writer', () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    final events = <String>[];

    final rejected = gate().withExclusiveAccess(() async {
      events.add('first-entered');
      firstEntered.complete();
      await releaseFirst.future;
      events.add('first-failed');
      throw StateError('synthetic-save-error');
    });
    await firstEntered.future;

    final second = gate().withExclusiveAccess(() async {
      events.add('second-entered');
      return 'safe-next-write';
    });
    // Register the expected error before letting the failed writer finish.
    final expectedFailure = expectLater(
      rejected,
      throwsA(predicate((Object error) =>
          error.toString().contains('synthetic-save-error'))),
    );
    releaseFirst.complete();
    await expectedFailure;
    expect(await second, 'safe-next-write');
    expect(events, <String>[
      'first-entered',
      'first-failed',
      'second-entered',
    ]);
  });

  test('M144: concurrent participants serialize under the same gate', () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    final events = <String>[];

    final first = gate().withExclusiveAccess(() async {
      events.add('first-enter');
      firstEntered.complete();
      await releaseFirst.future;
      events.add('first-exit');
      return 1;
    });
    await firstEntered.future;
    final second = gate().withExclusiveAccess(() async {
      events.add('second-enter');
      events.add('second-exit');
      return 2;
    });
    releaseFirst.complete();
    expect(await first, 1);
    expect(await second, 2);
    expect(events, <String>[
      'first-enter', 'first-exit', 'second-enter', 'second-exit',
    ]);
  });
}
