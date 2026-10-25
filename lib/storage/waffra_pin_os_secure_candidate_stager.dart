import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M216: NON-DESTRUCTIVE, disabled-by-default migration of the existing
/// salted? NO: legacy SHA-256 PIN verifier into Android protected storage.
/// SHA-256 of a short PIN is still low entropy; this copy is *not* a substitute
/// for rate limiting, biometric verification or independent device QA.
///
/// No PIN text, Google token or SQLCipher key is read or stored here.
/// This must never be activated as a UI feature by a test flag.
class WaffraPinOsSecureCandidateStager {
  const WaffraPinOsSecureCandidateStager({
    required this.readLegacyHash,
    required this.readSecureHash,
    required this.writeSecureHash,
    this.experimentalEnabled = false,
  });

  final Future<String?> Function() readLegacyHash;
  final Future<String?> Function() readSecureHash;
  final Future<void> Function(String) writeSecureHash;
  final bool experimentalEnabled;

  static const legacyKey = 'waffra_pin_sha256';
  static const secureKey = 'waffra_pin_sha256_secure_candidate_v1';

  /// Uses device-protected storage; no cloud PIN sync, no automatic clearing
  /// of the original preference, no premature change to the live unlock flow.
  factory WaffraPinOsSecureCandidateStager.androidCandidate({
    bool experimentalEnabled = false,
  }) {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return WaffraPinOsSecureCandidateStager(
      experimentalEnabled: experimentalEnabled,
      readLegacyHash: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        return prefs.getString(legacyKey);
      },
      readSecureHash: () => storage.read(key: secureKey),
      writeSecureHash: (value) => storage.write(key: secureKey, value: value),
    );
  }

  static bool _validHash(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  /// Mirrors only the existing verifier. The old verifier remains in place
  /// until a separate, physically tested app unlock cutover can remove it.
  /// If secure storage fails, the operation throws and does NOT claim
  /// migration success; it never falls back to a synthetic PIN.
  Future<WaffraPinCandidateStageResult> stage() async {
    if (!experimentalEnabled) {
      throw StateError('PIN secure candidate migration is disabled.');
    }
    final legacy = await readLegacyHash();
    final previouslyStaged = await readSecureHash();
    if (legacy == null) {
      if (previouslyStaged != null) {
        throw StateError('Secure PIN verifier has no verified legacy owner.');
      }
      return const WaffraPinCandidateStageResult(
        hasLegacyPin: false, verifiedSecureCopy: false,
      );
    }
    if (!_validHash(legacy) ||
        (previouslyStaged != null && !_validHash(previouslyStaged))) {
      throw StateError('Existing PIN verifier has an invalid representation.');
    }
    if (previouslyStaged != null && previouslyStaged != legacy) {
      throw StateError('Protected PIN verifier differs from its source.');
    }
    if (previouslyStaged == null) {
      await writeSecureHash(legacy);
    }
    final verified = await readSecureHash();
    if (verified != legacy) {
      throw StateError('Protected PIN verifier roundtrip failed.');
    }
    // Recheck legacy after the OS write. Concurrent user PIN changes must
    // never be accepted as a successful copy of the current PIN.
    if (await readLegacyHash() != legacy) {
      throw StateError('PIN changed during protected candidate staging.');
    }
    return const WaffraPinCandidateStageResult(
      hasLegacyPin: true, verifiedSecureCopy: true,
    );
  }
}

/// No PIN verifier, raw PIN or personal information is returned or logged.
class WaffraPinCandidateStageResult {
  const WaffraPinCandidateStageResult({
    required this.hasLegacyPin,
    required this.verifiedSecureCopy,
  });

  final bool hasLegacyPin;
  final bool verifiedSecureCopy;
}
