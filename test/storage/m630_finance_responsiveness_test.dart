import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('measure cold encrypted open and repeated verified snapshot reads', () async {
    final root = await Directory.systemTemp.createTemp('waffra-m630-');
    final file = File('${root.path}/finance.sqlite');
    final key = '${WaffraEncryptedStore.freshSqlCipherKeyPrefix}test-only-32-byte-original-key';
    var store = WaffraEncryptedStore.openAt(file, key: key);
    final clock = Stopwatch()..start();
    var last = 0, worstGap = 0, beats = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final now = clock.elapsedMilliseconds;
      final gap = now - last;
      if (gap > worstGap) worstGap = gap;
      last = now;
      beats++;
    });
    try {
      await WaffraFreshEncryptedVaultBootstrap(store: store, experimentalEnabled: true)
        .initialize(decision: WaffraFirstRunDecision.freshCandidate);
      var snapshot = WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);
      await snapshot.initializeEmpty();
      final raw = jsonEncode(List.generate(2000, (i) => {
        'id': 'entry-$i', 'title': 'Expense $i', 'category': 'Food',
        'amount': 10.25, 'income': false, 'date': '2026-11-01T12:00:00',
        'receiptPath': null,
      }));
      await snapshot.commit(expectedGeneration: 0, fullFinanceSnapshot: {'entries': raw});
      await store.close();
      store = WaffraEncryptedStore.openAt(file, key: key);
      snapshot = WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);
      final readClock = Stopwatch()..start();
      for (var i = 0; i < 12; i++) {
        final current = await snapshot.read();
        expect(current.values['entries'], raw);
        expect(current.generation, 1);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Synthetic workload only; never logs user data or key material.
      print('M630_HOST_METRICS total_ms=${clock.elapsedMilliseconds} '
        'repeat_read_ms=${readClock.elapsedMilliseconds} worst_event_gap_ms=$worstGap heartbeats=$beats');
      expect(beats, greaterThan(10), reason: 'Finance work must allow UI event-loop progress');
      expect(worstGap, lessThan(500), reason: 'Reject multi-second UI stalls; this is not a device FPS budget');
    } finally {
      timer.cancel();
      await store.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('installation lock contention does not block the event that releases it', () async {
    final root = await Directory.systemTemp.createTemp('waffra-m630-lock-');
    SharedPreferences.setMockInitialValues({'waffra_goals_v24': '[{"id":"existing"}]'});
    final otherEngine = sqlite3.open('${root.path}/waffra-install-lock.sqlite');
    otherEngine.execute('BEGIN IMMEDIATE');
    var released = false;
    final timer = Timer(const Duration(milliseconds: 150), () {
      otherEngine.execute('ROLLBACK');
      released = true;
    });
    try {
      final source = await WaffraFreshInstallSource.prepareIn(root,
        readKey: () async => null,
        writeKey: (_) async => fail('Must not create a new vault over legacy data'));
      expect(released, isTrue);
      expect(source, isNull);
    } finally {
      timer.cancel();
      otherEngine.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('cached validation still detects changed SQL bytes and transaction rollback', () async {
    final root = await Directory.systemTemp.createTemp('waffra-m630-integrity-');
    final store = WaffraEncryptedStore.openAt(File('${root.path}/vault.sqlite'),
      key: 'test-only-snapshot-cache-integrity-key');
    try {
      await WaffraFreshEncryptedVaultBootstrap(store: store, experimentalEnabled: true)
        .initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);
      await snapshot.initializeEmpty();
      final original = await snapshot.commit(expectedGeneration: 0,
        fullFinanceSnapshot: {'entries': '[]', 'waffra_sms_hashes_v1': <String>['original']});
      final row = await store.customSelect(
        'SELECT snapshot_json,digest FROM fresh_finance_snapshot_state WHERE singleton=1').getSingle();
      await snapshot.read(); // Warm the validation cache.
      await store.customStatement(
        'UPDATE fresh_finance_snapshot_state SET snapshot_json=? WHERE singleton=1',
        ['{}']); // Same revision and digest must NOT authorize different bytes.
      await expectLater(snapshot.read(), throwsStateError);
      await store.customStatement(
        'UPDATE fresh_finance_snapshot_state SET snapshot_json=? WHERE singleton=1',
        [row.read<String>('snapshot_json')]);
      final recovered = await snapshot.read();
      expect(recovered.digest, original.digest);
      expect(() => (recovered.values['waffra_sms_hashes_v1'] as List<String>).add('tamper'),
        throwsUnsupportedError);
      await expectLater(store.transaction(() async {
        await snapshot.commit(expectedGeneration: 1,
          fullFinanceSnapshot: {'entries': '[]', 'waffra_monthly_budget_v1': 123.0});
        throw StateError('injected rollback');
      }), throwsStateError);
      final afterRollback = await snapshot.read();
      expect(afterRollback.generation, 1);
      expect(afterRollback.digest, original.digest);
      final next = await snapshot.commit(expectedGeneration: 1,
        fullFinanceSnapshot: {'entries': '[]', 'waffra_monthly_budget_v1': 456.0});
      expect((await snapshot.read()).digest, next.digest);
      expect((await snapshot.read()).values['waffra_monthly_budget_v1'], 456.0);
      await store.customStatement(
        "UPDATE fresh_finance_snapshot_state SET digest='invalid' WHERE singleton=1");
      await expectLater(snapshot.read(), throwsStateError);
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });

  test('a public snapshot cannot impersonate a preflight-validated read', () {
    const forged = WaffraFinanceSnapshotState(generation: 1, digest: 'unverified',
      values: {'entries': 'not-json'});
    expect(() => WaffraFinanceReadView.fromEncrypted(forged).requireIntegrity(), throwsStateError);
  });

}
