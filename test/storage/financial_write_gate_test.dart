import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_financial_write_gate.dart';

void main() {
  test('freeze drains a running writer and blocks new writes until release',
      () async {
    final gate = WaffraFinancialWriteGate();
    final writerEntered = Completer<void>();
    final finishWriter = Completer<void>();
    final first = gate.runWrite(() async {
      writerEntered.complete();
      await finishWriter.future;
      return 42;
    });
    await writerEntered.future;

    var frozen = false;
    final leaseFuture = gate.freeze().then((value) {
      frozen = true;
      return value;
    });

    var secondRan = false;
    final second = gate.runWrite(() {
      secondRan = true;
      return 43;
    });
    await Future<void>.delayed(Duration.zero);
    expect(gate.isFrozen, isTrue);
    expect(frozen, isFalse);
    expect(secondRan, isFalse);

    finishWriter.complete();
    expect(await first, 42);
    final lease = await leaseFuture;
    expect(frozen, isTrue);
    expect(secondRan, isFalse);

    lease.release();
    expect(lease.isReleased, isTrue);
    lease.release(); // Idempotent, no completer double-completion.
    expect(await second, 43);
    expect(secondRan, isTrue);
    expect(gate.isFrozen, isFalse);
  });

  test('a failing write still drains, and a freeze can be released', () async {
    final gate = WaffraFinancialWriteGate();
    final entered = Completer<void>();
    final finish = Completer<void>();
    final failed = gate.runWrite<void>(() async {
      entered.complete();
      await finish.future;
      throw StateError('test failure');
    });
    await entered.future;

    final leaseFuture = gate.freeze();
    finish.complete();
    await expectLater(failed, throwsA(isA<StateError>()));
    final lease = await leaseFuture;
    expect(gate.isFrozen, isTrue);
    lease.release();
    expect(await gate.runWrite(() => 'recovered'), 'recovered');
  });

  test('nested writes and freeze inside a writer fail without deadlocking',
      () async {
    final gate = WaffraFinancialWriteGate();
    await expectLater(
      gate.runWrite(() async => gate.runWrite(() => 1)),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      gate.runWrite(() async => gate.freeze()),
      throwsA(isA<StateError>()),
    );
    expect(gate.isFrozen, isFalse);
    expect(await gate.runWrite(() => 2), 2);
  });

  test('overlapping freezes are refused; waiting writers resume', () async {
    final gate = WaffraFinancialWriteGate();
    final lease = await gate.freeze();
    expect(gate.isFrozen, isTrue);
    await expectLater(gate.freeze(), throwsA(isA<StateError>()));

    var executed = false;
    final queued = gate.runWrite(() async {
      executed = true;
      return 'ok';
    });
    await Future<void>.delayed(Duration.zero);
    expect(executed, isFalse);

    lease.release();
    expect(await queued, 'ok');
    expect(executed, isTrue);
    final again = await gate.freeze();
    again.release();
    expect(await gate.runWrite(() => 7), 7);
  });

  test('freeze handles multiple in-flight writers before taking a snapshot',
      () async {
    final gate = WaffraFinancialWriteGate();
    final started = <Completer<void>>[
      Completer<void>(), Completer<void>()
    ];
    final endings = <Completer<void>>[
      Completer<void>(), Completer<void>()
    ];
    final writes = List.generate(2, (i) => gate.runWrite(() async {
      started[i].complete();
      await endings[i].future;
      return i;
    }));
    await Future.wait(started.map((c) => c.future));
    var acquired = false;
    final waitLease = gate.freeze().then((lease) {
      acquired = true;
      return lease;
    });
    endings[0].complete();
    expect(await writes[0], 0);
    await Future<void>.delayed(Duration.zero);
    expect(acquired, isFalse);
    endings[1].complete();
    expect(await writes[1], 1);
    final lease = await waitLease;
    expect(acquired, isTrue);
    lease.release();
  });
}
