import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_widget_commit_journal.dart';

/// M97: simulate interrupted widget writes while the real Home SMS writer
/// is active. All data and identities are disposable synthetic fixtures.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraHomeFinancePersistence home;
  const widgetJournal = WaffraLegacyWidgetCommitJournal();

  String hash(int index) => index.toRadixString(16).padLeft(64, '0');
  Map<String, Object?> entry(int i) => {
    'id': 'test-entry-$i',
    'title': 'Synthetic purchase $i',
    'category': 'أخرى',
    'amount': 84.72,
    'income': false,
    'date': '2026-10-22T12:00:00',
    'receiptPath': null,
  };
  List<Map<String, dynamic>> decoded(String raw) =>
      (jsonDecode(raw) as List).map(
        (record) => Map<String, dynamic>.from(record as Map),
      ).toList();

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m97-journal-');
    SharedPreferences.setMockInitialValues({
      'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
    });
    home = WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
      ),
    );
  });
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M97 parallel confirmations for one bank hash persist only one entry',
      () async {
    final outcomes = await Future.wait([
      home.commitConfirmedLegacySms(
        records: [entry(1)], messageHashes: [hash(8)],
        userConfirmed: true,
      ),
      home.commitConfirmedLegacySms(
        records: [entry(2)], messageHashes: [hash(8)],
        userConfirmed: true,
      ),
    ]);
    expect(outcomes.map((item) => item.added).toList(),
        anyOf([1, 0], [0, 1]));
    expect(outcomes.fold<int>(0, (sum, item) => sum + item.skippedDuplicates),
        1);
    final saved = await home.loadWithWitness();
    expect(decoded(saved.ledgerRaw!), hasLength(1));
    expect(saved.finance.getStringList('waffra_sms_hashes_v1'), [hash(8)]);
  });

  test('M97 distinct concurrent Home and widget hashes both survive',
      () async {
    final outcomes = await Future.wait([
      home.commitConfirmedLegacySms(
        records: [entry(11)], messageHashes: [hash(11)],
        userConfirmed: true,
      ),
      home.commitConfirmedLegacySms(
        records: [entry(12)], messageHashes: [hash(12)],
        userConfirmed: true,
      ),
    ]);
    expect(outcomes.map((item) => item.added), everyElement(1));
    final saved = await home.loadWithWitness();
    expect(decoded(saved.ledgerRaw!).map((e) => e['id']).toSet(),
        {'test-entry-11', 'test-entry-12'});
    expect(saved.finance.getStringList('waffra_sms_hashes_v1'),
        [hash(11), hash(12)]);
  });

  test('M97 Home confirmation repairs partial widget journal before append',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final widgetRaw = jsonEncode([entry(33)]);
    await widgetJournal.prepare(
      prefs: prefs,
      nextEntries: widgetRaw,
      nextHashes: [hash(33)],
      nextRevision: 'm97-simulated-widget-save',
    );
    // A crash occurred after widget rows were saved but before hashes.
    await prefs.setString('entries', widgetRaw);
    final homeResult = await home.commitConfirmedLegacySms(
      records: [entry(34)],
      messageHashes: [hash(34)],
      userConfirmed: true,
    );
    expect(homeResult.added, 1);
    expect(decoded(homeResult.savedEntriesRaw).map((e) => e['id']).toSet(),
        {'test-entry-33', 'test-entry-34'});
    expect(homeResult.savedHashes, [hash(33), hash(34)]);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey),
        isFalse);
  });

  test('M97 corrupt pending widget journal blocks Home without losing money',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WaffraLegacyWidgetCommitJournal.pendingKey,
        '{"payload":"forged","checksum":"invalid"}');
    await expectLater(home.commitConfirmedLegacySms(
      records: [entry(2)], messageHashes: [hash(2)],
      userConfirmed: true,
    ), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey),
        isTrue);
  });

  test('M97 late repeated ID rejects whole batch without new hashes',
      () async {
    await home.commitConfirmedLegacySms(
      records: [entry(1)], messageHashes: [hash(1)],
      userConfirmed: true,
    );
    final baseline = await home.loadWithWitness();
    await expectLater(home.commitConfirmedLegacySms(
      records: [entry(2), entry(1)],
      messageHashes: [hash(2), hash(3)],
      userConfirmed: true,
    ), throwsA(isA<StateError>()));
    final latest = await home.loadWithWitness();
    expect(latest.ledgerRaw, baseline.ledgerRaw);
    expect(latest.finance.getStringList('waffra_sms_hashes_v1'), [hash(1)]);
  });

  test('M97 forced duplicate import leaves historical hash without duplication',
      () async {
    await home.commitConfirmedLegacySms(
      records: [entry(1)], messageHashes: [hash(1)],
      userConfirmed: true,
    );
    final forced = await home.commitConfirmedLegacySms(
      records: [entry(2)], messageHashes: [hash(1)],
      userConfirmed: true, allowDuplicateHashes: true,
    );
    expect(forced.added, 1);
    expect(forced.savedHashes, [hash(1)]);
    expect(decoded(forced.savedEntriesRaw), hasLength(2));
  });
}
