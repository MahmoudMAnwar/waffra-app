import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_widget_commit_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const journal = WaffraLegacyWidgetCommitJournal();
  const before = '[]';
  const after =
      '[{"id":"tx1","title":"POS","category":"طعام","amount":15.5,'
      '"income":false,"date":"2026-10-21T13:00:00","receiptPath":null}]';
  const hashes = ['hash-01'];
  const revision = '2026-10-21T13:00:00.000';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'entries': before,
      'waffra_sms_hashes_v1': <String>[],
      'waffra_widget_last_save_v1': 'earlier',
    });
  });

  Future<SharedPreferences> prepare() async {
    final prefs = await SharedPreferences.getInstance();
    await journal.prepare(
      prefs: prefs,
      nextEntries: after,
      nextHashes: hashes,
      nextRevision: revision,
    );
    return prefs;
  }

  test('single prepared marker contains complete transaction and hashes',
      () async {
    final prefs = await prepare();
    expect(prefs.getString('entries'), before);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(prefs.getString('waffra_widget_last_save_v1'), 'earlier');
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), true);
    final changed = await journal.recover(prefs);
    expect(changed, true);
    expect(prefs.getString('entries'), after);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), hashes);
    expect(prefs.getString('waffra_widget_last_save_v1'), revision);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), false);
    expect(await journal.recover(prefs), false);
  });

  test('crash after entries persisted repairs hashes and revision',
      () async {
    final prefs = await prepare();
    await prefs.setString('entries', after);
    // Simulates OS termination before updating either other preference key.
    await prefs.reload();
    expect(await journal.recover(prefs), true);
    expect(prefs.getString('entries'), after);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), hashes);
    expect(prefs.getString('waffra_widget_last_save_v1'), revision);
  });

  test('crash after hashes persisted repairs missing revision', () async {
    final prefs = await prepare();
    await prefs.setString('entries', after);
    await prefs.setStringList('waffra_sms_hashes_v1', hashes);
    await prefs.reload();
    expect(await journal.recover(prefs), true);
    expect(prefs.getString('waffra_widget_last_save_v1'), revision);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), false);
  });

  test('unknown new entry change never overwritten by an old journal',
      () async {
    final prefs = await prepare();
    const newer =
      '[{"id":"newer","title":"Salary","category":"Income",'
      '"amount":600,"income":true,"date":"2026-10-21T15:00:00"}]';
    await prefs.setString('entries', newer);
    await expectLater(journal.recover(prefs), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), newer);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), true);
  });

  test('unknown SMS hashes never cleared during journal replay', () async {
    final prefs = await prepare();
    await prefs.setStringList('waffra_sms_hashes_v1', ['newer-hash']);
    await expectLater(journal.recover(prefs), throwsA(isA<StateError>()));
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['newer-hash']);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), true);
  });

  test('tampered journal checksum blocks recovery without deleting it',
      () async {
    final prefs = await prepare();
    final e = jsonDecode(
      prefs.getString(WaffraLegacyWidgetCommitJournal.pendingKey)!,
    ) as Map<String, dynamic>;
    e['checksum'] = List.filled(64, '0').join();
    await prefs.setString(
      WaffraLegacyWidgetCommitJournal.pendingKey, jsonEncode(e),
    );
    await expectLater(journal.recover(prefs), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), before);
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), true);
  });

  test('another commit cannot silently replace unfinished journal', () async {
    final prefs = await prepare();
    await expectLater(journal.prepare(
      prefs: prefs,
      nextEntries: after,
      nextHashes: hashes,
      nextRevision: 'newer',
    ), throwsA(isA<StateError>()));
    expect(await journal.recover(prefs), true);
    expect(prefs.getString('waffra_widget_last_save_v1'), revision);
  });

  test('app writer coordinator replays pending journal under real lock',
      () async {
    final prefs = await prepare();
    await prefs.setString('entries', after);
    final temp = await Directory.systemTemp.createTemp('waffra-journal-test-');
    try {
      final result = await WaffraLegacyFinanceWriterCoordinator(
        testDirectory: temp,
      ).withCurrentPreferences((current) async {
        expect(current.getString('entries'), after);
        expect(current.getStringList('waffra_sms_hashes_v1'), hashes);
        expect(current.getString('waffra_widget_last_save_v1'), revision);
        return 17;
      });
      expect(result, 17);
      expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), false);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('preparation validates invalid finance record before writing marker',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await expectLater(journal.prepare(
      prefs: prefs,
      nextEntries: '[{"id":"invalid","amount":1.005}]',
      nextHashes: hashes,
      nextRevision: revision,
    ), throwsA(isA<StateError>()));
    expect(prefs.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey), false);
    expect(prefs.getString('entries'), before);
  });
}
