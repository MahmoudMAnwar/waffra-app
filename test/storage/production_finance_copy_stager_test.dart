import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_copy_stager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late Directory receiptsDir;
  late WaffraEncryptedStore candidate;
  const key = 'm72-disposable-stage-only-sqlcipher-key';
  const archivePassword = 'M72-User-Confirmed-Copy-Test!';

  Map<String, dynamic> record({
    String id = 'transaction-with-photo',
    String? path,
  }) => {
    'id': id,
    'title': 'Groceries',
    'category': 'Shopping',
    'amount': 42.75,
    'income': false,
    'date': '2026-10-22T11:00:00',
    'receiptPath': path,
  };

  WaffraProductionFinanceCopyStager makeStager({
    bool enabled = true,
  }) => WaffraProductionFinanceCopyStager(
    destination: candidate,
    coordinator: WaffraLegacyFinanceWriterCoordinator(
      testDirectory: sandbox,
    ),
    trustedReceiptDirectory: receiptsDir,
    experimentalEnabled: enabled,
  );

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m72-stage-');
    receiptsDir = Directory('${sandbox.path}/receipts');
    await receiptsDir.create();
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_goals_v24': '[]',
      'waffra_categories_v24': '[]',
      'waffra_recurring_v24': '[]',
      'waffra_sms_hashes_v1': <String>['previous-fingerprint'],
      'waffra_custom_goals_v1': <String>['سيارة'],
      'waffra_language': 'ar',
    });
    candidate = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/candidate.sqlite'), key: key,
    );
  });

  tearDown(() async {
    await candidate.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<void> setEntries(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', jsonEncode(entries));
  }

  test('M72 copies confirmed receipt bytes and all finance into SQLCipher; originals unchanged',
      () async {
    final receipt = File('${receiptsDir.path}/invoice.jpg');
    await receipt.writeAsBytes([14, 21, 32, 65], flush: true);
    await setEntries([record(path: receipt.path)]);
    final prefs = await SharedPreferences.getInstance();
    final oldRaw = prefs.getString('entries');
    final staged = await makeStager().stage(
      userChosenBackupPassword: archivePassword,
    );
    expect(staged.transactions, 1);
    expect(staged.receipts, 1);
    expect(staged.receiptBytes, 4);
    expect(staged.targetGeneration, 1);
    expect(await makeStager().sourceStillMatches(staged.sourceDigest), isTrue);
    expect(prefs.getString('entries'), oldRaw);
    expect(prefs.getStringList('waffra_sms_hashes_v1'),
        ['previous-fingerprint']);
    expect(await receipt.readAsBytes(), [14, 21, 32, 65]);

    final stored = await WaffraAtomicFinanceSnapshot(
      store: candidate, experimentalEnabled: true,
    ).read();
    final restored = jsonDecode(stored.values['entries'] as String) as List;
    expect((restored.single as Map)['receiptPath'],
        startsWith('waffra-receipt://'));
    expect(stored.values['waffra_sms_hashes_v1'], ['previous-fingerprint']);
    final images = await WaffraEncryptedReceiptVault(
      store: candidate, experimentalEnabled: true,
    ).readAll('transaction-with-photo');
    expect(images.single.bytes, [14, 21, 32, 65]);
    final goals = await candidate.customSelect(
      'SELECT suggestion FROM fresh_finance_custom_goals '
      'WHERE position=0',
    ).getSingle();
    expect(goals.read<String>('suggestion'), 'سيارة');

    await candidate.close();
    candidate = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/candidate.sqlite'), key: key,
    );
    expect((await WaffraEncryptedReceiptVault(
      store: candidate, experimentalEnabled: true,
    ).readAll('transaction-with-photo')).single.bytes, [14, 21, 32, 65]);
  });

  test('M72 refuses missing or untrusted receipt without modifying legacy',
      () async {
    final missing = '${receiptsDir.path}/no-longer-exists.jpg';
    await setEntries([record(path: missing)]);
    final prefs = await SharedPreferences.getInstance();
    final oldRaw = prefs.getString('entries');
    await expectLater(makeStager().stage(
      userChosenBackupPassword: archivePassword,
    ), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), oldRaw);
  });

  test('M72 refuses relative receipt paths and symlink escaping trusted folder',
      () async {
    await setEntries([record(path: 'relative.jpg')]);
    await expectLater(makeStager().stage(
      userChosenBackupPassword: archivePassword,
    ), throwsA(isA<StateError>()));
    final outside = File('${sandbox.path}/outside.jpg');
    await outside.writeAsBytes([1, 2, 3], flush: true);
    final symlink = Link('${receiptsDir.path}/linked.jpg');
    await symlink.create(outside.path);
    await setEntries([record(path: symlink.path)]);
    await expectLater(makeStager().stage(
      userChosenBackupPassword: archivePassword,
    ), throwsA(isA<StateError>()));
  });

  test('M72 an updated widget transaction invalidates a previously staged source',
      () async {
    await setEntries([record()]);
    final staged = await makeStager().stage(
      userChosenBackupPassword: archivePassword,
    );
    expect(await makeStager().sourceStillMatches(staged.sourceDigest), isTrue);
    await setEntries([record(), record(id: 'new-widget-sms')]);
    expect(await makeStager().sourceStillMatches(staged.sourceDigest), isFalse);
  });

  test('M74 validates finance, catalog and encrypted receipt parity after cold staging',
      () async {
    final receipt = File('${receiptsDir.path}/invoice-verified.jpg');
    await receipt.writeAsBytes([3, 6, 9, 12], flush: true);
    await setEntries([record(path: receipt.path)]);
    final initial = await makeStager().stage(
      userChosenBackupPassword: archivePassword,
    );
    expect(await makeStager().stageStillMatches(initial), isTrue);
    await receipt.writeAsBytes([3, 6, 9, 13], flush: true);
    expect(await makeStager().stageStillMatches(initial), isFalse);
    // Neither false result nor checksum comparison may delete original bytes.
    expect(await receipt.readAsBytes(), [3, 6, 9, 13]);
  });

  test('M74 a custom goal edit cannot pass finance-only staging witness',
      () async {
    final initial = await makeStager().stage(
      userChosenBackupPassword: archivePassword,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(await makeStager().stageStillMatches(initial), isTrue);
    await prefs.setStringList('waffra_custom_goals_v1', ['بيت']);
    // Transaction checksum is unchanged, but the complete audit must fail.
    expect(await makeStager().sourceStillMatches(initial.sourceDigest), isTrue);
    expect(await makeStager().stageStillMatches(initial), isFalse);
  });

  test('M74 SQLCipher generation or direct ledger tamper blocks activation readiness',
      () async {
    await setEntries([record()]);
    final initial = await makeStager().stage(
      userChosenBackupPassword: archivePassword,
    );
    expect(await makeStager().stageStillMatches(initial), isTrue);
    final snapshot = WaffraAtomicFinanceSnapshot(
      store: candidate, experimentalEnabled: true,
    );
    final current = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: current.generation,
      fullFinanceSnapshot: current.values,
    );
    expect(await makeStager().stageStillMatches(initial), isFalse);
    expect((await SharedPreferences.getInstance()).getString('entries'),
        contains('transaction-with-photo'));
  });

  test('M72 requires explicit opt-in, a password, and an empty destination',
      () async {
    await expectLater(makeStager(enabled: false).stage(
      userChosenBackupPassword: archivePassword,
    ), throwsA(isA<StateError>()));
    await expectLater(makeStager().stage(
      userChosenBackupPassword: 'weak',
    ), throwsA(isA<ArgumentError>()));
    await makeStager().stage(userChosenBackupPassword: archivePassword);
    await expectLater(makeStager().stage(
      userChosenBackupPassword: archivePassword,
    ), throwsA(isA<StateError>()));
    expect((await SharedPreferences.getInstance()).getString('entries'), '[]');
  });
}
