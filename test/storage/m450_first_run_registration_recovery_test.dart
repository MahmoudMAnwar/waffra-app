import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M450 aborted registration resumes only with same secure identity', () async {
    const phone='0501234567', pass='CorrectPass2026!';
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:pass,testSalt:List<int>.filled(32,17),
    );
    final stored=jsonEncode(record);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(
      stored,phone:phone,password:pass),isTrue);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(
      stored,phone:phone,password:'DifferentPass2026!'),isFalse);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(
      stored,phone:'0599999999',password:pass),isFalse);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(
      '{"version":2}',phone:phone,password:pass),isFalse);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(
      'not-json',phone:phone,password:pass),isFalse);
  });

  test('M450 second registration step never overwrites completed identity', () {
    final main=File('lib/main.dart').readAsStringSync();
    final save=main.substring(
      main.indexOf(' Future<void> save()async {',main.indexOf('class ProfileForm')),
      main.indexOf(' void _nextPhoneRegistrationStep(){'),
    );
    expect(save,contains("prefs.getString('waffra_registered_profile')!=null"));
    expect(save,contains('WaffraLocalPhoneCredentials.registerOrResume('));
    expect(save,contains('local_profile_already_completed'));
    expect(save,isNot(contains('WaffraLocalPhoneCredentials.register(')));
    final verifier=File('lib/waffra_local_phone_credentials.dart').readAsStringSync();
    expect(verifier,contains('if(await canResumeRecord(saved,phone:phone,password:password))return;'));
    expect(verifier,contains("throw StateError('local_credentials_already_exist');"));
  });

  group('M450 fresh-encrypted account metadata-only authority', () {
    late Directory directory;
    String? key;

    Future<WaffraFreshInstallSource?> install() =>
      WaffraFreshInstallSource.prepareIn(
        directory,
        readKey:() async => key,
        writeKey:(value) async {key=value;},
      );

    Future<void> saveName(String name) =>
      WaffraFreshInstallSource.withVerifiedProfilePreferences(
        (prefs) async {
          await prefs.setString('waffra_profile',name);
        },
        testDirectory:directory,
        secureKeyReader:() async => key,
      );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      directory=await Directory.systemTemp.createTemp('waffra-m450-profile-');
      key=null;
    });
    tearDown(() async {await directory.delete(recursive:true);});

    test('verified already-active fresh vault permits profile metadata save', () async {
      final source=await install();
      expect(source,isNotNull);
      await saveName('synthetic profile');
      final prefs=await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString('waffra_profile'),'synthetic profile');
      // No finance keys are written by the tested metadata callback.
      expect(prefs.getString('entries'),isNull);
    });

    test('missing active source proof refuses profile changes', () async {
      await expectLater(saveName('must not save'),throwsStateError);
      final prefs=await SharedPreferences.getInstance();
      expect(prefs.getString('waffra_profile'),isNull);
    });

    test('wrong encryption key refuses without clearing saved credentials', () async {
      await install();
      final realKey=key;
      key='wrong-physical-device-key';
      await expectLater(saveName('must not save'),throwsStateError);
      key=realKey;
      await saveName('real verified account');
      final prefs=await SharedPreferences.getInstance();
      expect(prefs.getString('waffra_profile'),'real verified account');
    });

    test('altered external install witness refuses and does not write', () async {
      await install();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString(WaffraFreshInstallSource.receiptKey,'tampered');
      await expectLater(saveName('must not save'),throwsStateError);
      expect(prefs.getString('waffra_profile'),isNull);
    });

    test('pending activation refuses account profile write', () async {
      await install();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('waffra_finance_cutover_pending_v1','malformed');
      await expectLater(saveName('must not save'),throwsStateError);
    });

    test('M450 profile/save/logout route uses only verified existing authority', () {
      final code=File('lib/storage/waffra_live_account_write_authority.dart')
          .readAsStringSync();
      expect(code,contains('WaffraFreshInstallSource.withVerifiedProfilePreferences(change)'));
      expect(code,contains('return coordinator.withCurrentPreferences(change);'));
      expect(code,contains('Future<void> signOut() => _withVerifiedAccountPreferences('));
    });
  });
}
