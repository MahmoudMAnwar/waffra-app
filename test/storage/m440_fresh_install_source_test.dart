import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      expect((await store.customSelect('PRAGMA legacy').getSingle()).data.values.single,4);
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
}
