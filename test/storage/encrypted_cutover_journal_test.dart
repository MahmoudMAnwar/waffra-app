import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore vault;
  const key = 'isolated-cutover-journal-test-key-32';
  final source = List.filled(64, 'a').join();
  final now = DateTime.utc(2026, 10, 21, 12);

  WaffraAtomicFinanceSnapshot snapshot() =>
      WaffraAtomicFinanceSnapshot(store: vault, experimentalEnabled: true);

  WaffraEncryptedCutoverJournal journal({bool enabled = true}) =>
      WaffraEncryptedCutoverJournal(
        store: vault,
        snapshot: snapshot(),
        experimentalEnabled: enabled,
      );

  Future<String> initialize({String entries = '[]'}) async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final result = await snapshot().commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: {'entries': entries},
    );
    return result.digest;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-cutover-journal-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('preparing snapshot records verified source and target digests',
      () async {
    final target = await initialize();
    final result = await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    expect(result.phase, WaffraCutoverPhase.prepared);
    expect(result.sourceDigest, source);
    expect(result.encryptedDigest, target);
    expect(await journal().recover(
      externalMarkerPresent: false,
      encryptedKeyReadable: true,
      allWritersRouted: false,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
  });

  test('only matching digest permits preparation', () async {
    await initialize();
    await expectLater(journal().prepare(
      sourceDigest: source,
      targetDigest: List.filled(64, 'f').join(),
      now: now,
    ), throwsA(isA<StateError>()));
    expect(await journal().read(), isNull);
  });

  test('replayed prepare is idempotent but a different source is rejected',
      () async {
    final target = await initialize();
    await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    final repeat = await journal().prepare(
      sourceDigest: source, targetDigest: target,
      now: now.add(const Duration(hours: 1)),
    );
    expect(repeat.phase, WaffraCutoverPhase.prepared);
    await expectLater(journal().prepare(
      sourceDigest: List.filled(64, 'b').join(),
      targetDigest: target, now: now,
    ), throwsA(isA<StateError>()));
    expect((await journal().read())!.sourceDigest, source);
  });

  test('no activation until snapshot verified and writers routed',
      () async {
    final target = await initialize();
    await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    await expectLater(journal().acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true, now: now,
    ), throwsA(isA<StateError>()));
    expect((await journal().verify(now: now)).phase,
        WaffraCutoverPhase.verified);
    for (final evidence in [
      (marker: false, routed: true),
      (marker: true, routed: false),
    ]) {
      await expectLater(journal().acknowledgeExternalActivation(
        externalMarkerVerified: evidence.marker,
        allWritersRouted: evidence.routed,
        now: now,
      ), throwsA(isA<StateError>()));
    }
    expect((await journal().read())!.phase, WaffraCutoverPhase.verified);
  });

  test('verified+external evidence required at every cold start', () async {
    final target = await initialize();
    await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    await journal().verify(now: now);
    await journal().acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true, now: now,
    );
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: key,
    );
    expect((await journal().read())!.phase, WaffraCutoverPhase.active);
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: true,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.encryptedReady);
    expect(await journal().recover(
      externalMarkerPresent: false,
      encryptedKeyReadable: true,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: false,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
  });

  test('receipt-path data cannot be marked as migrated until copied',
      () async {
    final target = await initialize(entries: jsonEncode([
      {
        'id': 'entry-with-receipt',
        'title': 'Invoice',
        'category': 'Purchases',
        'amount': 10.0,
        'income': false,
        'date': '2026-10-21T12:00:00',
        'receiptPath': '/old/user/receipt.png',
      },
    ]));
    await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    await expectLater(journal().verify(now: now),
        throwsA(isA<StateError>()));
    expect((await journal().read())!.phase, WaffraCutoverPhase.prepared);
  });

  test('finance changed after prepare blocks verification and activation',
      () async {
    final target = await initialize();
    await journal().prepare(
      sourceDigest: source, targetDigest: target, now: now,
    );
    await snapshot().commit(
      expectedGeneration: 1,
      fullFinanceSnapshot: {'entries': '[]', 'waffra_goals_v24': '[]'},
    );
    await expectLater(journal().verify(now: now),
        throwsA(isA<StateError>()));
    expect((await journal().read())!.phase, WaffraCutoverPhase.prepared);
  });

  test('invalid digest and disabled gate do not create metadata', () async {
    final target = await initialize();
    await expectLater(journal().prepare(
      sourceDigest: 'wrong', targetDigest: target, now: now,
    ), throwsA(isA<ArgumentError>()));
    await expectLater(journal(enabled: false).prepare(
      sourceDigest: source, targetDigest: target, now: now,
    ), throwsA(isA<StateError>()));
    expect(await journal().read(), isNull);
  });

  test('no checkpoint and no external marker remains unactivated', () async {
    await initialize();
    expect(await journal().recover(
      externalMarkerPresent: false,
      encryptedKeyReadable: true,
      allWritersRouted: false,
    ), WaffraCutoverRecoveryStatus.noCheckpoint);
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: true,
      allWritersRouted: false,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
  });
}
