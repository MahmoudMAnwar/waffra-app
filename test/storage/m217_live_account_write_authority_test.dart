import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_live_account_write_authority.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late bool rejectSource;

  const legacyLedger = '[]';
  const legacyRecord = '{"name":"Safe user","email":"test@example.invalid",'
      '"provider":"Google","gender":"","avatar":"person","phone":"0500000000",'
      '"birthday":"2000-01-01T00:00:00.000"}';

  WaffraLiveAccountWriteAuthority authority() =>
      WaffraLiveAccountWriteAuthority(
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: sandbox,
          testBypassNativeLock: true,
          sourceProbe: (_) async {
            if (rejectSource) {
              throw StateError('Encrypted SQL source already selected.');
            }
          },
        ),
      );

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('m217-account-source-');
    rejectSource = false;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': legacyLedger,
      'waffra_categories_v24': '[]',
      'waffra_language': 'ar',
      'waffra_pin_sha256': List<String>.filled(64, 'a').join(),
      'waffra_registered_profile': legacyRecord,
    });
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M217 guarded live saveUser keeps existing finances untouched', () async {
    await authority().saveProfile(
      profileJson: legacyRecord,
      registeredProfileJson: legacyRecord,
      loginMethod: 'Google',
      email: 'test@example.invalid',
      phone: '0500000000',
    );
    final p = await SharedPreferences.getInstance();
    expect(jsonDecode(p.getString('waffra_profile')!)['name'], 'Safe user');
    expect(p.getString('waffra_registered_profile'), legacyRecord);
    expect(p.getString('waffra_last_login_method'), 'Google');
    expect(p.getString('waffra_last_login_phone'), '0500000000');
    expect(p.getString('entries'), legacyLedger);
    expect(p.getString('waffra_categories_v24'), '[]');
    expect(p.getString('waffra_pin_sha256'),
        List<String>.filled(64, 'a').join());
  });

  test('M217 guarded logout preserves registration and finance', () async {
    await authority().saveProfile(
      profileJson: legacyRecord,
      loginMethod: 'Phone',
    );
    await authority().signOut();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_profile'), isNull);
    expect(p.getBool('waffra_signed_out_explicitly'), isTrue);
    expect(p.getString('waffra_registered_profile'), legacyRecord);
    expect(p.getString('entries'), legacyLedger);
  });

  test('M217 guarded PIN replace and remove keeps finance untouched',
      () async {
    final next = List<String>.filled(64, 'b').join();
    await authority().replacePinVerifier(next);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_pin_sha256'), next);
    await authority().replacePinVerifier(null);
    expect(p.getString('waffra_pin_sha256'), isNull);
    expect(p.getString('entries'), legacyLedger);
  });

  test('M217 malformed PIN verifier fails before any preferences change',
      () async {
    await expectLater(
      authority().replacePinVerifier('1234'), throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_pin_sha256'),
        List<String>.filled(64, 'a').join());
  });

  test('M217 malformed or unapproved profile fields fail closed',
      () async {
    for (final payload in <String>[
      '{broken',
      '{"name":"Person","token":"not-permitted"}',
      '["not a person"]',
    ]) {
      await expectLater(
        authority().saveProfile(
          profileJson: payload, loginMethod: 'Google',
        ),
        throwsStateError,
      );
    }
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_profile'), isNull);
  });

  test('M217 incorrect login method fails before native write', () async {
    await expectLater(
      authority().saveProfile(
        profileJson: legacyRecord, loginMethod: 'Unknown',
      ),
      throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_profile'), isNull);
  });

  test('M217 SQLCipher source disagreement blocks user save', () async {
    rejectSource = true;
    await expectLater(
      authority().saveProfile(
        profileJson: legacyRecord, loginMethod: 'Google',
      ),
      throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_profile'), isNull);
    expect(p.getString('entries'), legacyLedger);
  });

  test('M217 SQLCipher source disagreement blocks logout', () async {
    rejectSource = true;
    await expectLater(authority().signOut(), throwsStateError);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('waffra_signed_out_explicitly'), isNull);
    expect(p.getString('waffra_registered_profile'), legacyRecord);
  });

  test('M217 SQLCipher source disagreement blocks PIN mutation', () async {
    rejectSource = true;
    await expectLater(
      authority().replacePinVerifier(List<String>.filled(64, 'c').join()),
      throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getString('waffra_pin_sha256'),
        List<String>.filled(64, 'a').join());
  });

  test('M217 external active source flag blocks all old account writes',
      () async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    await expectLater(
      authority().saveProfile(
        profileJson: legacyRecord, loginMethod: 'Phone',
      ),
      throwsStateError,
    );
    await expectLater(authority().signOut(), throwsStateError);
    await expectLater(
      authority().replacePinVerifier(null), throwsStateError,
    );
    expect(p.getString('waffra_profile'), isNull);
    expect(p.getBool('waffra_signed_out_explicitly'), isNull);
    expect(p.getString('waffra_pin_sha256'),
        List<String>.filled(64, 'a').join());
  });

  test('M217 pending cutover blocks all legacy account changes', () async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(
      authority().saveProfile(
        profileJson: legacyRecord, loginMethod: 'Google',
      ),
      throwsStateError,
    );
    await expectLater(authority().signOut(), throwsStateError);
    await expectLater(
      authority().replacePinVerifier(null), throwsStateError,
    );
    expect(p.getString('waffra_profile'), isNull);
    expect(p.getString('waffra_pin_sha256'), isNotNull);
  });
}
