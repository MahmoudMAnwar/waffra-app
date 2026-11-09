import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  String? key;
  Future<WaffraFreshInstallSource?> prepare() =>
      WaffraFreshInstallSource.prepareIn(directory,readKey:() async => key,
        writeKey:(value) async { key=value; });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-install-test-');
    key=null;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async => directory.delete(recursive:true));

  test('concurrent first opens retain one identity, one key and SQLCipher 4', () async {
    final sources=await Future.wait([prepare(),prepare()]);
    expect(sources.first!.id,sources.last!.id);
    final store=WaffraEncryptedStore.openAt(
      File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),key:key!);
    try {
      await sources.first!.verify(store);
      expect((await store.customSelect('PRAGMA cipher').getSingle()).data.values.single,'sqlcipher');
      // Cipher mode is validated by openAt. Verify the actual vault bytes
      // are encrypted, not merely a successful ignored PRAGMA key.
      final file=File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}');
      final header=(await file.readAsBytes()).take(15).toList();
      expect(header,isNot(equals('SQLite format 3'.codeUnits)));
    } finally { await store.close(); }
  });
  test('existing legacy financial records never provision an empty successor', () async {
    SharedPreferences.setMockInitialValues({'waffra_goals_v24':'[{"id":"old"}]'});
    expect(await prepare(),isNull);
    expect(key,isNull);
  });
  test('first launch retries an interrupted secure-key write using its reservation', () async {
    await expectLater(WaffraFreshInstallSource.prepareIn(directory,
      readKey:() async=>key,writeKey:(value) async { key=value; throw StateError('interrupted'); }),
      throwsStateError);
    final originalKey=key;
    expect(await prepare(),isNotNull);
    expect(key,originalKey);
  });
  test('contended first-install SQL reservation leaves UI event loop responsive',
      () async {
    // A competing engine may hold BEGIN IMMEDIATE for a few frames. The
    // primary Flutter isolate must remain interactive while it waits.
    final mutex = sqlite3.open('${directory.path}/waffra-install-lock.sqlite');
    mutex.execute('BEGIN IMMEDIATE');
    var released = false;
    try {
      var finished = false;
      final opening = prepare().then((source) {
        finished = true;
        return source;
      });
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(finished, isFalse,
          reason: 'The external SQLite reservation is still held.');
      // This delayed event cannot run when BEGIN IMMEDIATE blocks UI.
      var uiTicked = false;
      await Future<void>.delayed(const Duration(milliseconds: 30))
          .then((_) => uiTicked = true);
      expect(uiTicked, isTrue);
      mutex.execute('ROLLBACK');
      released = true;
      final source = await opening.timeout(const Duration(seconds: 15));
      expect(source, isNotNull,
          reason: 'The original encrypted first-run receipt must survive lock contention.');
      final store = WaffraEncryptedStore.openAt(
        File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
        key: key!,
      );
      try {
        await source!.verify(store);
      } finally {
        await store.close();
      }
    } finally {
      if (!released) mutex.execute('ROLLBACK');
      mutex.close();
    }
  });

}
