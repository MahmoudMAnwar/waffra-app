import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_pin_os_secure_candidate_stager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hash = List<String>.filled(64, 'a').join();
  final different = List<String>.filled(64, 'b').join();

  late String? legacy;
  late String? secure;
  late int writes;
  late bool secureFails;
  late bool secureCorrupts;
  late bool legacyChangesDuringWrite;

  WaffraPinOsSecureCandidateStager candidate({bool enabled = true}) =>
      WaffraPinOsSecureCandidateStager(
        experimentalEnabled: enabled,
        readLegacyHash: () async => legacy,
        readSecureHash: () async => secure,
        writeSecureHash: (value) async {
          writes++;
          if (secureFails) throw StateError('OS secure storage write failed.');
          secure = secureCorrupts ? different : value;
          if (legacyChangesDuringWrite) legacy = different;
        },
      );

  setUp(() {
    legacy = hash;
    secure = null;
    writes = 0;
    secureFails = false;
    secureCorrupts = false;
    legacyChangesDuringWrite = false;
  });

  test('M216 disabled by default cannot stage a legacy PIN', () async {
    await expectLater(candidate(enabled: false).stage(), throwsStateError);
    expect(writes, 0);
    expect(secure, isNull);
  });

  test('M216 valid verifier is copied and independently roundtrip verified',
      () async {
    final result = await candidate().stage();
    expect(result.hasLegacyPin, isTrue);
    expect(result.verifiedSecureCopy, isTrue);
    expect(secure, hash);
    expect(legacy, hash);
    expect(writes, 1);
  });

  test('M216 matching protected verifier is idempotent', () async {
    secure = hash;
    final result = await candidate().stage();
    expect(result.verifiedSecureCopy, isTrue);
    expect(writes, 0);
  });

  test('M216 missing legacy and secure verifier creates no PIN', () async {
    legacy = null;
    final result = await candidate().stage();
    expect(result.hasLegacyPin, isFalse);
    expect(result.verifiedSecureCopy, isFalse);
    expect(writes, 0);
  });

  test('M216 orphan protected verifier requires independent recovery',
      () async {
    legacy = null;
    secure = hash;
    await expectLater(candidate().stage(), throwsStateError);
    expect(writes, 0);
  });

  test('M216 malformed plaintext-like legacy verifier is rejected',
      () async {
    legacy = '1234';
    await expectLater(candidate().stage(), throwsStateError);
    expect(secure, isNull);
    expect(writes, 0);
  });

  test('M216 mismatched protected verifier cannot overwrite other PIN',
      () async {
    secure = different;
    await expectLater(candidate().stage(), throwsStateError);
    expect(secure, different);
    expect(writes, 0);
  });

  test('M216 secure OS writer failure never reports a verified copy',
      () async {
    secureFails = true;
    await expectLater(candidate().stage(), throwsStateError);
    expect(legacy, hash);
    expect(secure, isNull);
  });

  test('M216 corrupt protected roundtrip cannot pass', () async {
    secureCorrupts = true;
    await expectLater(candidate().stage(), throwsStateError);
    expect(legacy, hash);
    expect(secure, different);
  });

  test('M216 concurrent legacy PIN replacement rejects stale protected copy',
      () async {
    legacyChangesDuringWrite = true;
    await expectLater(candidate().stage(), throwsStateError);
    expect(legacy, different);
    expect(secure, hash);
  });
}
