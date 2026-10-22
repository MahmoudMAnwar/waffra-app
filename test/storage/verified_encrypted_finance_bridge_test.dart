import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const testKey = 'm61-disposable-encrypted-vault-only-key';
  const hashA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  late Directory directory;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      );
  WaffraEncryptedCutoverJournal journal() => WaffraEncryptedCutoverJournal(
        store: vault, snapshot: snapshot(), experimentalEnabled: true,
      );
  WaffraVerifiedEncryptedFinanceBridge bridge({
    bool enabled = true,
    bool routed = true,
    bool keyVerified = true,
  }) => WaffraVerifiedEncryptedFinanceBridge(
        snapshot: snapshot(),
        cutoverJournal: journal(),
        writerDirectory: directory,
        experimentalEnabled: enabled,
        allWritersRoutedVerified: routed,
        secureKeyVerified: keyVerified,
      );

  Map<String, Object?> record(String id) => {
        'id': id,
        'title': 'Bank SMS test',
        'category': 'Shopping',
        'amount': 18.25,
        'income': false,
        'date': '2026-10-21T18:00:00',
        'receiptPath': null,
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_language': 'ar',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    directory = await Directory.systemTemp.createTemp('waffra-m61-bridge-');
    vault = WaffraEncryptedStore.openAt(
      File('${directory.path}/encrypted.sqlite'), key: testKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final saved = await snapshot().commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const {
        'entries': '[]',
        'waffra_goals_v24':
            '[{"id":"trip","name":"Trip","target":2500,"saved":200}]',
      },
    );
    final source = WaffraLegacyPreflight.inspect({'entries': '[]'});
    await journal().prepare(
      sourceDigest: source.sourceSha256,
      targetDigest: saved.digest,
      now: DateTime.utc(2026, 10, 22),
    );
    await journal().verify(now: DateTime.utc(2026, 10, 22));
    await journal().acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 10, 22),
    );
  });

  tearDown(() async {
    await vault.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('verified encrypted screen reads come solely from SQLCipher', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', '[{"id":"stale-legacy"}]');
    final loaded = await bridge().loadForHomeAndWidget();
    expect(loaded.ledgerRaw, '[]');
    expect(loaded.generation, 1);
    expect(loaded.widgetRevision, '1');
    expect(loaded.finance.getString('waffra_goals_v24'), contains('trip'));
    expect(prefs.getString('entries'), contains('stale-legacy'));
  });

  test('widget SMS append and stale Home goal edit preserve both values',
      () async {
    final homeBaseline = await bridge().loadForHomeAndWidget();
    final result = await bridge().appendConfirmedTransactions(
      records: [record('sms-1')],
      messageHashes: [hashA],
      userConfirmed: true,
    );
    expect(result.saved, 1);
    expect(result.generation, 2);
    final homeSave = await bridge().saveHomeChanges(
      baseline: homeBaseline,
      replacements: const {
        'waffra_goals_v24':
            '[{"id":"trip","name":"Trip","target":2500,"saved":300}]',
      },
      changedKeys: const {'waffra_goals_v24'},
    );
    expect(homeSave.generation, 3);
    expect(homeSave.values['entries'], contains('sms-1'));
    expect(homeSave.values['waffra_goals_v24'], contains('"saved":300'));
    expect(homeSave.values['waffra_sms_hashes_v1'], [hashA]);
    final reloaded = await bridge().loadForHomeAndWidget();
    expect(reloaded.widgetRevision, '3');
    expect((jsonDecode(reloaded.ledgerRaw!) as List), hasLength(1));
  });

  test('widget write and stale Home ledger edit cannot lose transactions',
      () async {
    final stale = await bridge().loadForHomeAndWidget();
    await bridge().appendConfirmedTransactions(
      records: [record('new-widget-entry')],
      messageHashes: [hashA],
      userConfirmed: true,
    );
    await expectLater(
      bridge().saveHomeChanges(
        baseline: stale,
        replacements: const {'entries': '[]'},
        changedKeys: const {'entries'},
      ),
      throwsA(isA<StateError>()),
    );
    final current = await bridge().loadForHomeAndWidget();
    expect(current.ledgerRaw, contains('new-widget-entry'));
    expect(current.generation, 2);
  });

  test('repeated bank SMS does not add a duplicate or advance revision',
      () async {
    await bridge().appendConfirmedTransactions(
      records: [record('original')],
      messageHashes: [hashA],
      userConfirmed: true,
    );
    final duplicate = await bridge().appendConfirmedTransactions(
      records: [record('duplicate')],
      messageHashes: [hashA],
      userConfirmed: true,
    );
    expect(duplicate.saved, 0);
    expect(duplicate.skippedDuplicates, 1);
    expect(duplicate.generation, 2);
    expect((await bridge().loadForHomeAndWidget()).ledgerRaw,
        isNot(contains('"id":"duplicate"')));
  });

  test('cannot start encrypted writer without verified route and key', () async {
    for (final unsafe in [
      bridge(enabled: false),
      bridge(routed: false),
      bridge(keyVerified: false),
    ]) {
      await expectLater(
        unsafe.loadForHomeAndWidget(),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        unsafe.appendConfirmedTransactions(
          records: [record('blocked')],
          messageHashes: [null],
          userConfirmed: true,
        ),
        throwsA(isA<StateError>()),
      );
    }
    expect((await snapshot().read()).generation, 1);
  });

  test('interrupted pointer blocks reads and all writers before mutation',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(
      bridge().loadForHomeAndWidget(),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      bridge().appendConfirmedTransactions(
        records: [record('blocked')],
        messageHashes: [hashA],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await snapshot().read()).generation, 1);
  });

  test('missing activation pointer refuses finance updates', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(WaffraLiveLegacyFinanceGuard.activeKey);
    final previous = await snapshot().read();
    await expectLater(
      bridge().loadForHomeAndWidget(),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      bridge().appendConfirmedTransactions(
        records: [record('blocked')],
        messageHashes: [hashA],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await snapshot().read()).digest, previous.digest);
  });

  test('mismatched SQL cutover checkpoint cannot authorize a save', () async {
    await vault.customStatement(
      "UPDATE fresh_finance_cutover_checkpoint SET phase='prepared' "
      'WHERE singleton=1',
    );
    await expectLater(
      bridge().appendConfirmedTransactions(
        records: [record('blocked')],
        messageHashes: [hashA],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await snapshot().read()).generation, 1);
  });

  test('new encrypted entries survive cold open without consulting legacy',
      () async {
    await bridge().appendConfirmedTransactions(
      records: [record('cold-start')],
      messageHashes: [hashA],
      userConfirmed: true,
    );
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${directory.path}/encrypted.sqlite'), key: testKey,
    );
    final resumed = await bridge().loadForHomeAndWidget();
    expect(resumed.ledgerRaw, contains('cold-start'));
    expect(resumed.generation, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), '[]');
  });
  test('encrypted active bridge refuses unowned receipt lookups', () async {
    await bridge().appendConfirmedTransactions(
      records: [record('receipt-free')],
      messageHashes: [null],
      userConfirmed: true,
    );
    final images = await bridge().loadReceiptImages(entryId: 'receipt-free');
    expect(images, isEmpty);
    await expectLater(
      bridge().loadReceiptImages(entryId: 'foreign-entry'),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(
      bridge().loadReceiptImages(entryId: 'receipt-free'),
      throwsA(isA<StateError>()),
    );
  });

  test('M67 finance port preserves widget entries during a goals editor save',
      () async {
    final home = WaffraEncryptedFinanceSession(
      bridge: bridge(), experimentalEnabled: true,
    );
    final witness = await home.loadForDashboardOrWidget();
    await home.appendConfirmed(
      records: [record('widget-m67')],
      hashes: [hashA],
      userConfirmed: true,
    );
    final persisted = await home.saveDashboardBatch(
      baseline: witness,
      captured: <String, Object>{
        'entries': witness.ledgerRaw!,
        'waffra_goals_v24':
            '[{"id":"trip","name":"Trip","target":2500,"saved":400}]',
      },
    );
    expect(persisted.values['entries'], contains('widget-m67'));
    expect(persisted.values['waffra_goals_v24'], contains('"saved":400'));
    expect(persisted.values['waffra_sms_hashes_v1'], [hashA]);
    expect(persisted.generation, 3);
  });

  test('M67 SMS digest merge never overwrites a widget digest', () async {
    const hashB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final port = WaffraEncryptedFinanceSession(
      bridge: bridge(), experimentalEnabled: true,
    );
    await port.appendConfirmed(
      records: [record('widget-first')], hashes: [hashA],
      userConfirmed: true,
    );
    final merged = await port.addSmsHashes([hashB]);
    expect(merged.values['waffra_sms_hashes_v1'], [hashA, hashB]);
    final noOp = await port.addSmsHashes([hashA, hashB]);
    expect(noOp.generation, merged.generation);
    expect((await port.loadForDashboardOrWidget())
        .finance.getStringList('waffra_sms_hashes_v1'), [hashA, hashB]);
  });

  test('M67 concurrent changes to the SAME ledger reject stale screen writes',
      () async {
    final port = WaffraEncryptedFinanceSession(
      bridge: bridge(), experimentalEnabled: true,
    );
    final stale = await port.loadForDashboardOrWidget();
    await port.appendConfirmed(
      records: [record('newer-entry')], hashes: [hashA],
      userConfirmed: true,
    );
    await expectLater(port.saveChangedFields(
      baseline: stale, changedValues: const {'entries': '[]'},
    ), throwsA(isA<StateError>()));
    expect((await port.loadForDashboardOrWidget()).ledgerRaw,
        contains('newer-entry'));
  });

  test('M67 finance port refuses unactivated source and unexpected fields',
      () async {
    final off = WaffraEncryptedFinanceSession(bridge: bridge());
    await expectLater(off.loadForDashboardOrWidget(),
        throwsA(isA<StateError>()));
    final port = WaffraEncryptedFinanceSession(
      bridge: bridge(), experimentalEnabled: true,
    );
    final witness = await port.loadForDashboardOrWidget();
    await expectLater(port.saveChangedFields(
      baseline: witness, changedValues: const {'waffra_profile': 'secret'},
    ), throwsA(isA<ArgumentError>()));
    await expectLater(port.addSmsHashes(['raw bank SMS']),
        throwsA(isA<ArgumentError>()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(port.loadForDashboardOrWidget(),
        throwsA(isA<StateError>()));
  });

}
