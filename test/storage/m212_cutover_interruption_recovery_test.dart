import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Synthetic process-restart rehearsals. These are NOT evidence of hardware
/// OS-keystore recovery or of an activated customer finance database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore store;
  const key = 'm212-disposable-cutover-recovery-key-32';
  final sourceDigest = List<String>.filled(64, 'a').join();
  final now = DateTime.utc(2026, 10, 25, 12, 0);

  WaffraAtomicFinanceSnapshot snap() =>
      WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);

  WaffraEncryptedCutoverJournal journal() => WaffraEncryptedCutoverJournal(
    store: store, snapshot: snap(), experimentalEnabled: true,
  );

  Future<void> coldReopen() async {
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${temp.path}/cutover.sqlite'), key: key,
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('m212-cutover-');
    store = WaffraEncryptedStore.openAt(
      File('${temp.path}/cutover.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snap().initializeEmpty();
    await snap().commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
  });

  tearDown(() async {
    await store.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M212 interrupted prepared stage cannot become a live data source',
      () async {
    final current = await snap().read();
    await journal().prepare(
      sourceDigest: sourceDigest, targetDigest: current.digest, now: now,
    );
    await coldReopen();
    expect((await journal().read())!.phase, WaffraCutoverPhase.prepared);
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: true,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
    await expectLater(journal().acknowledgeExternalActivation(
      externalMarkerVerified: true, allWritersRouted: true, now: now,
    ), throwsStateError);
    expect((await snap().read()).values['entries'], '[]');
  });

  test('M212 interrupted verified stage needs explicit activation witness',
      () async {
    final current = await snap().read();
    await journal().prepare(
      sourceDigest: sourceDigest, targetDigest: current.digest, now: now,
    );
    await journal().verify(now: now);
    await coldReopen();
    expect((await journal().read())!.phase, WaffraCutoverPhase.verified);
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: true,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
    expect((await snap().read()).digest, current.digest);
  });

  test('M212 active SQL witness without external pointer blocks cold reads',
      () async {
    final current = await snap().read();
    await journal().prepare(
      sourceDigest: sourceDigest, targetDigest: current.digest, now: now,
    );
    await journal().verify(now: now);
    await journal().acknowledgeExternalActivation(
      externalMarkerVerified: true, allWritersRouted: true, now: now,
    );
    await coldReopen();
    for (final data in <(bool,bool,bool)>[
      (false,true,true), (true,false,true), (true,true,false),
    ]) {
      expect(await journal().recover(
        externalMarkerPresent: data.$1,
        encryptedKeyReadable: data.$2,
        allWritersRouted: data.$3,
      ), WaffraCutoverRecoveryStatus.manualReconciliationRequired);
    }
    expect(await journal().recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: true,
      allWritersRouted: true,
    ), WaffraCutoverRecoveryStatus.encryptedReady);
  });
}
