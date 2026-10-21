import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_legacy_write_queue.dart';

void main() {
  test('submitted snapshots never overtake delayed earlier writes', () async {
    final queue = WaffraLegacyWriteQueue();
    final entered = Completer<void>();
    final finish = Completer<void>();
    final log = <String>[];
    final mutable = <String, Object>{'entries': 'v1', 'budget': 1.0};
    final first = queue.submit(mutable, (captured) async {
      log.add('first-start:${captured['entries']}');
      entered.complete();
      await finish.future;
      log.add('first-end:${captured['entries']}');
    });
    await entered.future;
    mutable['entries'] = 'v2';
    final second = queue.submit(mutable, (captured) async {
      log.add('second:${captured['entries']}');
    });
    mutable['entries'] = 'v3'; // Mutating state after enqueue cannot change v2.
    await Future<void>.delayed(Duration.zero);
    expect(log, ['first-start:v1']);
    expect(queue.pendingBatches, 2);
    finish.complete();
    await Future.wait([first, second]);
    expect(log, ['first-start:v1', 'first-end:v1', 'second:v2']);
    expect(queue.pendingBatches, 0);
  });

  test('failed batch returns failure but cannot poison subsequent writes',
      () async {
    final queue = WaffraLegacyWriteQueue();
    final ran = <String>[];
    final failure = queue.submit({'entries': 'bad'}, (s) async {
      ran.add('failed');
      throw StateError('storage disconnected');
    });
    final recovered = queue.submit({'entries': 'good'}, (s) async {
      ran.add(s['entries']! as String);
    });
    await expectLater(failure, throwsA(isA<StateError>()));
    await recovered;
    await queue.drain();
    expect(ran, ['failed', 'good']);
    expect(queue.pendingBatches, 0);
  });

  test('drain waits for all submitted in-process writes', () async {
    final queue = WaffraLegacyWriteQueue();
    final barrier = Completer<void>();
    var flushed = false;
    final op = queue.submit({'entries': 'latest'}, (_) async {
      await barrier.future;
      flushed = true;
    });
    var drained = false;
    final waiting = queue.drain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    barrier.complete();
    await Future.wait([op, waiting]);
    expect(flushed, isTrue);
    expect(drained, isTrue);
  });

  test('does not allow saver to mutate captured data', () async {
    final queue = WaffraLegacyWriteQueue();
    await expectLater(queue.submit({'entries': 'stable'}, (s) async {
      s['entries'] = 'tampered';
    }), throwsA(isA<UnsupportedError>()));
    expect(queue.pendingBatches, 0);
  });
}
