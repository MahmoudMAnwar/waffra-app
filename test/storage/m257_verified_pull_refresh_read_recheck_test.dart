import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_verified_refresh_read_recheck.dart';

void main() {
  test('M257 normal refresh reads and verifies exactly once', () async {
    var reads = 0, validations = 0, retries = 0;
    final value = await WaffraVerifiedRefreshReadRecheck.read<int>(
      load: () async => ++reads,
      verify: (candidate) {
        validations++;
        expect(candidate, 1);
      },
      beforeRetry: () async { retries++; },
    );
    expect(value, 1);
    expect(reads, 1);
    expect(validations, 1);
    expect(retries, 0);
  });

  test('M257 transient read failure is recovered only by a new verified read', () async {
    var reads = 0, validations = 0, retries = 0;
    final result = await WaffraVerifiedRefreshReadRecheck.read<String>(
      load: () async {
        reads++;
        if (reads == 1) throw StateError('interrupted read');
        return 'authoritative-and-verified';
      },
      verify: (record) {
        validations++;
        expect(record, 'authoritative-and-verified');
      },
      beforeRetry: () async { retries++; },
    );
    expect(result, 'authoritative-and-verified');
    expect(reads, 2);
    expect(validations, 1);
    expect(retries, 1);
  });

  test('M257 first *unverified* snapshot cannot be displayed as success', () async {
    var reads = 0;
    final result = await WaffraVerifiedRefreshReadRecheck.read<String>(
      load: () async => ++reads == 1 ? 'unverified' : 'valid',
      verify: (record) {
        if (record != 'valid') throw StateError('snapshot integrity failed');
      },
    );
    expect(result, 'valid');
    expect(reads, 2);
  });

  test('M257 repeated read failure propagates to fail-closed recovery', () async {
    var reads = 0, retries = 0;
    await expectLater(
      WaffraVerifiedRefreshReadRecheck.read<String>(
        load: () async {
          reads++;
          throw StateError('corrupt or unavailable authority');
        },
        verify: (_) { fail('no source may be verified'); },
        beforeRetry: () async { retries++; },
      ),
      throwsStateError,
    );
    expect(reads, 2);
    expect(retries, 1);
  });

  test('M257 repeated integrity failure is not silently converted to empty', () async {
    var reads = 0, validations = 0;
    await expectLater(
      WaffraVerifiedRefreshReadRecheck.read<String>(
        load: () async {
          reads++;
          return 'unsafe-cipher-snapshot';
        },
        verify: (_) {
          validations++;
          throw StateError('failed source witness');
        },
      ),
      throwsStateError,
    );
    expect(reads, 2);
    expect(validations, 2);
  });

  test('M257 a failed retry preflight never invokes the source a second time', () async {
    var reads = 0;
    await expectLater(
      WaffraVerifiedRefreshReadRecheck.read<String>(
        load: () async {
          reads++;
          throw StateError('lock error');
        },
        verify: (_) {},
        beforeRetry: () async { throw StateError('writer drain failed'); },
      ),
      throwsStateError,
    );
    expect(reads, 1);
  });

  test('M257 never retries source-changing writes or persists snapshots', () {
    final code = File('lib/storage/waffra_verified_refresh_read_recheck.dart')
        .readAsStringSync();
    expect(code, isNot(contains('SharedPreferences')));
    expect(code, isNot(contains('persist(')));
    expect(code, isNot(contains('commit(')));
    expect(code, isNot(contains('initializeEmpty(')));
    expect(code, contains('final second = await load();'));
    expect(code, contains('verify(second);'));
  });

  test('M257 Home uses one verified reread inside the M255 single-flight gate', () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf('Future<void> _refreshFromVerifiedFinance()async {');
    final end = home.indexOf('Future<void> load()async {', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final flow = home.substring(start, end);
    final singleFlight = flow.indexOf('await _verifiedRefreshGate.run(()async {');
    final recheck = flow.indexOf('WaffraVerifiedRefreshReadRecheck.read(');
    final source = flow.indexOf('WaffraVerifiedPullRefreshSource.fromAuthority(source)');
    final publish = flow.indexOf('setState((){\n    entries..clear()');
    expect(singleFlight, greaterThanOrEqualTo(0));
    expect(recheck, greaterThan(singleFlight));
    expect(source, greaterThan(recheck));
    expect(publish, greaterThan(source));
    expect(flow, contains('await _financialWriteQueue.drain();'));
    expect(flow, contains('await Future<void>.delayed(const Duration(milliseconds:120));'));
    expect(flow, contains('route:WaffraFinanceRoute.dashboardRead'));
    expect(flow, contains('view.requireIntegrity();'));
    expect(flow, contains('ready=false;'));
    expect(flow, contains('_financeLoadFailure='));
    expect(flow, isNot(contains('await persist(')));
  });
}
