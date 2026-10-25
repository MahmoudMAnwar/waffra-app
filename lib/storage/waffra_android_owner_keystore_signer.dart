import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// M219: call an EXISTING Android Keystore HMAC owner key from the native
/// activity. No new keys are enrolled and no raw secret or PIN is exposed.
///
/// The native implementation additionally checks the signed challenge UID
/// against the non-anonymous FirebaseAuth Android session. Production still
/// needs device-specific key enrollment, account recovery and physical QA.
class WaffraAndroidOwnerKeystoreSigner {
  const WaffraAndroidOwnerKeystoreSigner({
    this.channel = const MethodChannel('waffra/account_owner'),
  });

  final MethodChannel channel;

  static const _ownerDomain = 'waffra-profile-owner-v1';

  /// Adapter for M218's signOwnerChallenge callback.
  Future<String?> signExistingChallenge(List<int> challenge) async {
    if (challenge.isEmpty || challenge.length > 2048 ||
        challenge.any((byte) => byte < 0 || byte > 255)) {
      throw StateError('Invalid Android owner proof challenge.');
    }
    Object? document;
    try {
      document = jsonDecode(utf8.decode(challenge, allowMalformed: false));
    } catch (_) {
      throw StateError('Owner challenge must be valid canonical UTF-8 JSON.');
    }
    if (document is! List<dynamic> ||
        document.length != 4 ||
        document[0] != _ownerDomain ||
        document[1] is! String ||
        (document[1] as String).trim().isEmpty ||
        document[2] is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(document[2] as String) ||
        document[3] is! String ||
        (document[3] as String).trim().isEmpty ||
        jsonEncode(document) != utf8.decode(challenge)) {
      throw StateError('Owner challenge is not an approved account proof.');
    }

    String? result;
    try {
      result = await channel.invokeMethod<String>(
        'signExistingOwnerChallenge',
        <String, Object?>{'challenge': Uint8List.fromList(challenge)},
      );
    } on MissingPluginException {
      throw StateError('Native owner key service is unavailable.');
    } on PlatformException {
      // Never log OS Keystore details, principals or sensitive challenge.
      throw StateError('Native account owner proof was refused.');
    }
    if (result == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
      throw StateError('Native owner MAC is missing or unverified.');
    }
    return result;
  }
}
