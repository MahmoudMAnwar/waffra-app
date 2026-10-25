import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_android_owner_keystore_signer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('waffra/account_owner');
  const signer = WaffraAndroidOwnerKeystoreSigner(channel: channel);
  final validMac = List<String>.filled(64, 'a').join();
  final sourceSha = List<String>.filled(64, '1').join();

  Uint8List challenge({
    String uid = 'synthetic-firebase-principal',
    String vault = 'test-vault',
    String? checksum,
  }) => Uint8List.fromList(utf8.encode(jsonEncode(<String>[
        'waffra-profile-owner-v1', vault, checksum ?? sourceSha, uid,
      ])));

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('M219 verifies Android owner MAC and transmits bytes only',
      () async {
    Uint8List? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'signExistingOwnerChallenge');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      sent = args['challenge'] as Uint8List?;
      return validMac;
    });
    final raw = challenge();
    expect(await signer.signExistingChallenge(raw), validMac);
    expect(sent, orderedEquals(raw));
  });

  test('M219 refuses missing native MethodChannel implementation',
      () async {
    await expectLater(signer.signExistingChallenge(challenge()),
        throwsStateError);
  });

  test('M219 refuses an absent non-enrolled OS owner key', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'OWNER_PROOF_UNAVAILABLE', message: 'Synthetic key missing',
      );
    });
    await expectLater(signer.signExistingChallenge(challenge()),
        throwsStateError);
  });

  test('M219 refuses a null or malformed native HMAC', () async {
    for (final value in <String?>[null, '', 'not-a-mac', 'abc']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => value);
      await expectLater(signer.signExistingChallenge(challenge()),
          throwsStateError);
    }
  });

  test('M219 blocks malformed JSON before calling the native key', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return validMac;
    });
    for (final raw in <List<int>>[
      utf8.encode('garbled'),
      utf8.encode('{"name":"user"}'),
      utf8.encode('["waffra-profile-owner-v1","v"]'),
    ]) {
      await expectLater(signer.signExistingChallenge(raw), throwsStateError);
    }
    expect(calls, 0);
  });

  test('M219 blocks non-profile HMAC purpose without a native call',
      () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return validMac;
    });
    final request = utf8.encode(jsonEncode([
      'waffra-other-purpose', 'test-vault', sourceSha, 'principal',
    ]));
    await expectLater(signer.signExistingChallenge(request), throwsStateError);
    expect(calls, 0);
  });

  test('M219 rejects missing UID, vault and malformed source digest',
      () async {
    for (final input in <Uint8List>[
      challenge(uid: ''),
      challenge(vault: ''),
      challenge(checksum: 'not-a-sha'),
    ]) {
      await expectLater(signer.signExistingChallenge(input), throwsStateError);
    }
  });

  test('M219 rejects oversized challenge and out-of-range byte',
      () async {
    await expectLater(
      signer.signExistingChallenge(List<int>.filled(2049, 65)),
      throwsStateError,
    );
    await expectLater(signer.signExistingChallenge(<int>[-1, 1]),
        throwsStateError);
  });

  test('M219 refuses non-canonical JSON before OS signing', () async {
    final request = utf8.encode(
      '["waffra-profile-owner-v1", "test-vault", "$sourceSha", "uid"]',
    );
    await expectLater(signer.signExistingChallenge(request), throwsStateError);
  });

  test('M219 raw owner key is never a response or protocol parameter',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args.keys, <String>['challenge']);
      expect(args.containsKey('secretKey'), isFalse);
      expect(args.containsKey('pin'), isFalse);
      return validMac;
    });
    expect(await signer.signExistingChallenge(challenge()), validMac);
  });
}
