import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_disposable_recovery_journal.dart';

void main() {
  late Directory root;
  late WaffraDisposableRecoveryJournal journal;
  final digest = 'a' * 64;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-journal-');
    journal = WaffraDisposableRecoveryJournal(
      directory: root, experimentalEnabled: true);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> add(int phase) async {
    await journal.appendVerifiedPhase(
      phase: phase, sourceChecksum: digest, entries: 2, receipts: 1);
  }

  test('immutable ordered journal survives re-opening and verifies chain',
      () async {
    await add(0);
    await add(1);
    await add(2);
    final recovered = await WaffraDisposableRecoveryJournal(
      directory: root, experimentalEnabled: true).inspect();
    expect(recovered.map((x) => x.phase).toList(), [0, 1, 2]);
    expect(recovered.last.entries, 2);
    expect(recovered.last.receipts, 1);
    expect(recovered.last.previousDigest, recovered[1].digest);
    expect(recovered.first.previousDigest, isEmpty);
    expect(await root.list().toList(), hasLength(3));
  });

  test('disabled journal rejects all operations', () async {
    final off = WaffraDisposableRecoveryJournal(directory: root);
    await expectLater(off.inspect(), throwsA(isA<StateError>()));
    await expectLater(off.appendVerifiedPhase(
      phase: 0, sourceChecksum: digest, entries: 2, receipts: 1),
      throwsA(isA<StateError>()));
    expect(await root.list().toList(), isEmpty);
  });

  test('cannot skip phases or append a prior phase again', () async {
    await expectLater(add(1), throwsA(isA<StateError>()));
    await add(0);
    await expectLater(add(0), throwsA(isA<StateError>()));
    await expectLater(add(2), throwsA(isA<StateError>()));
    expect((await journal.inspect()).length, 1);
  });

  test('cannot switch financial archive or counts between phases', () async {
    await add(0);
    await expectLater(journal.appendVerifiedPhase(
      phase: 1, sourceChecksum: 'b' * 64, entries: 2, receipts: 1),
      throwsA(isA<StateError>()));
    await expectLater(journal.appendVerifiedPhase(
      phase: 1, sourceChecksum: digest, entries: 3, receipts: 1),
      throwsA(isA<StateError>()));
    expect((await journal.inspect()).length, 1);
  });

  test('modified checkpoint is detected, never used as resume authority',
      () async {
    await add(0);
    final file = File('${root.path}/00_archive_authenticated.json');
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    data['entries'] = 55;
    await file.writeAsString(jsonEncode(data));
    await expectLater(journal.inspect(), throwsA(isA<StateError>()));
  });

  test('power loss orphan pending file fails closed', () async {
    await add(0);
    final interrupted = File(
      '${root.path}/01_receipt_bytes_audited.json.pending');
    await interrupted.writeAsString('incomplete');
    await expectLater(journal.inspect(), throwsA(isA<StateError>()));
    expect(await interrupted.readAsString(), 'incomplete');
  });

  test('extra unexpected file is not deleted or accepted', () async {
    await add(0);
    final existing = File('${root.path}/private.txt');
    await existing.writeAsString('keep');
    await expectLater(journal.inspect(), throwsA(isA<StateError>()));
    expect(await existing.readAsString(), 'keep');
  });

  test('path-like invalid source checksum cannot begin a journal', () async {
    await expectLater(journal.appendVerifiedPhase(
      phase: 0, sourceChecksum: '../outside', entries: 2, receipts: 1),
      throwsA(isA<StateError>()));
    expect(await root.list().toList(), isEmpty);
  });

  test('refuses a symlinked journal directory', () async {
    final link = Link('${root.parent.path}/waffra-journal-link-test');
    if (await link.exists()) await link.delete();
    try {
      await link.create(root.path);
      final unsafe = WaffraDisposableRecoveryJournal(
        directory: Directory(link.path), experimentalEnabled: true);
      await expectLater(unsafe.inspect(), throwsA(isA<StateError>()));
    } finally {
      if (await link.exists()) await link.delete();
    }
  });
}
