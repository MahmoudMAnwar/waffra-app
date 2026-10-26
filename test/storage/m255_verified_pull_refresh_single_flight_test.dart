import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_verified_refresh_single_flight.dart';

void main() {
  test('M255 concurrent pull gestures wait for one authoritative load', () async {
    final gate = WaffraVerifiedRefreshSingleFlight();
    final finish = Completer<void>();
    var loads = 0;
    final first = gate.run(() async {
      loads++;
      await finish.future;
    });
    final second = gate.run(() async {
      loads++;
    });
    expect(identical(first, second), isTrue);
    expect(gate.isRefreshing, isTrue);
    expect(loads, 1);
    finish.complete();
    await Future.wait([first, second]);
    expect(gate.isRefreshing, isFalse);
    expect(loads, 1);
    await gate.run(() async {
      loads++;
    });
    expect(loads, 2);
  });

  test('M255 reentrant refresh cannot start another read', () async {
    final gate = WaffraVerifiedRefreshSingleFlight();
    final finish = Completer<void>();
    var loads = 0;
    late Future<void> nested;
    final outer = gate.run(() async {
      loads++;
      nested = gate.run(() async {
        loads++;
      });
      await finish.future;
    });
    expect(loads, 1);
    expect(identical(outer, nested), isTrue);
    finish.complete();
    await outer;
    expect(loads, 1);
  });

  test('M255 failed refresh propagates failure and permits later retry', () async {
    final gate = WaffraVerifiedRefreshSingleFlight();
    final finish = Completer<void>();
    var loads = 0;
    final first = gate.run(() async {
      loads++;
      await finish.future;
      throw StateError('verified source failed');
    });
    final second = gate.run(() async {
      loads++;
    });
    final failures = Future.wait([
      expectLater(first, throwsStateError),
      expectLater(second, throwsStateError),
    ]);
    finish.complete();
    await failures;
    expect(loads, 1);
    expect(gate.isRefreshing, isFalse);
    await gate.run(() async {
      loads++;
    });
    expect(loads, 2);
  });

  test('M255 synchronous source error is not swallowed', () async {
    final gate = WaffraVerifiedRefreshSingleFlight();
    await expectLater(
      gate.run(() {
        throw StateError('no verified source');
      }),
      throwsStateError,
    );
    expect(gate.isRefreshing, isFalse);
  });

  test('M255 dashboard still refreshes from independently verified source', () {
    final code = File('lib/main.dart').readAsStringSync();
    expect(code, contains(
      'final WaffraVerifiedRefreshSingleFlight _verifiedRefreshGate=',
    ));
    final from = code.indexOf('Future<void> _refreshFromVerifiedFinance()async');
    final until = code.indexOf('Future<void> load()async', from);
    expect(from, greaterThanOrEqualTo(0));
    expect(until, greaterThan(from));
    final refresh = code.substring(from, until);
    expect(refresh, contains('await _verifiedRefreshGate.run(()async {'));
    expect(refresh, contains('await _financialWriteQueue.drain();'));
    expect(refresh, contains('view.requireIntegrity();'));
    expect(refresh, contains('WaffraVerifiedPullRefreshSource.fromAuthority(current)'));
    expect(refresh, contains('ready=false;'));
    expect(refresh, contains('_financeLoadFailure='));
    expect(refresh, isNot(contains('await persist(')));
  });
}
