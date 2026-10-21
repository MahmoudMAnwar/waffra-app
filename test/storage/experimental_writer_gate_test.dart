import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_experimental_writer_gate.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-writer-gate-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  WaffraExperimentalWriterGate gate({bool enabled = true}) =>
      WaffraExperimentalWriterGate(
        disposableDirectory: root,
        experimentalEnabled: enabled,
      );

  test('default-off does not open or create finance lock', () async {
    await expectLater(gate(enabled: false).withExclusiveAccess(() async => 1),
        throwsA(isA<StateError>()));
    expect(await root.list().toList(), isEmpty);
  });

  test('serializes concurrent callbacks across separate gateway instances',
      () async {
    var active = 0, maximum = 0;
    final done = await Future.wait(
      List.generate(12, (n) => gate().withExclusiveAccess(() async {
        active++;
        if (active > maximum) maximum = active;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 3));
          return n;
        } finally {
          active--;
        }
      })),
    );
    expect(maximum, 1);
    expect(done.toSet(), Set<int>.from(List.generate(12, (i) => i)));
  });

  test('exception unlocks writer and allows next valid writer', () async {
    await expectLater(gate().withExclusiveAccess(() async {
      throw StateError('synthetic failed write');
    }), throwsA(isA<StateError>()));
    expect(await gate().withExclusiveAccess(() async => 17), 17);
  });

  test('rejects replacing lock path with a directory', () async {
    await Directory('${root.path}/.waffra-writer.lock').create();
    await expectLater(gate().withExclusiveAccess(() async => 1),
        throwsA(isA<StateError>()));
  });

  test('rejects a nonexistent writer parent instead of creating user storage',
      () async {
    final missing = Directory('${root.path}/never-created');
    final other = WaffraExperimentalWriterGate(
      disposableDirectory: missing, experimentalEnabled: true,
    );
    await expectLater(other.withExclusiveAccess(() async => 1),
        throwsA(isA<StateError>()));
    expect(await missing.exists(), false);
  });

  test('revision guard permits only exact current version', () {
    const revisions = WaffraWriterRevisionGuard();
    expect(revisions.nextRevision(
      expectedRevision: 0, authoritativeRevision: 0,
    ), 1);
    expect(revisions.nextRevision(
      expectedRevision: 41, authoritativeRevision: 41,
    ), 42);
    expect(() => revisions.nextRevision(
      expectedRevision: 5, authoritativeRevision: 6,
    ), throwsA(isA<StateError>()));
    expect(() => revisions.nextRevision(
      expectedRevision: -1, authoritativeRevision: -1,
    ), throwsA(isA<StateError>()));
  });
}
