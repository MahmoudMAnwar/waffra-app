import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Encryption primitive for future opt-in Firestore sync. Not enabled in app.
/// The key is provided by a separate, not-yet-approved key recovery system.
class WaffraCloudCipher {
  WaffraCloudCipher() : _aes = AesGcm.with256bits();

  final AesGcm _aes;

  Future<SecretKey> newRandomVaultKey() => _aes.newSecretKey();

  Future<WaffraEncryptedCloudRecord> encrypt({
    required SecretKey vaultKey,
    required String vaultId,
    required String kind,
    required String recordId,
    required String deviceId,
    required String mutationId,
    required int localVersion,
    required Map<String, dynamic> record,
  }) async {
    _requireMetadata(vaultId, kind, recordId, deviceId, mutationId, localVersion);
    final cleaned = WaffraCloudSanitizer.sanitize(kind, record);
    if (cleaned.containsKey('id') && cleaned['id'] != recordId) {
      throw StateError('Record ID does not match encrypted record identity.');
    }
    final plaintext = utf8.encode(jsonEncode(cleaned));
    final box = await _aes.encrypt(plaintext,
      secretKey: vaultKey,
      aad: _aad(vaultId, kind, recordId, deviceId, mutationId, localVersion),
    );
    return WaffraEncryptedCloudRecord(
      kind: kind, recordId: recordId, deviceId: deviceId,
      mutationId: mutationId, localVersion: localVersion,
      ciphertext: base64Encode(box.cipherText),
      nonce: base64Encode(box.nonce),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<Map<String, dynamic>> decrypt({
    required SecretKey vaultKey,
    required String vaultId,
    required WaffraEncryptedCloudRecord envelope,
  }) async {
    _requireMetadata(vaultId, envelope.kind, envelope.recordId,
      envelope.deviceId, envelope.mutationId, envelope.localVersion);
    if (envelope.encryptionVersion != 1) {
      throw StateError('Unsupported cloud encryption version.');
    }
    final box = SecretBox(
      base64Decode(envelope.ciphertext),
      nonce: base64Decode(envelope.nonce),
      mac: Mac(base64Decode(envelope.mac)),
    );
    final clear = await _aes.decrypt(box, secretKey: vaultKey,
      aad: _aad(vaultId, envelope.kind, envelope.recordId,
        envelope.deviceId, envelope.mutationId, envelope.localVersion),
    );
    final value = jsonDecode(utf8.decode(clear));
    if (value is! Map) throw const FormatException('Cloud payload is not JSON object');
    return WaffraCloudSanitizer.sanitize(
      envelope.kind, Map<String, dynamic>.from(value));
  }

  static List<int> _aad(
    String vaultId, String kind, String recordId,
    String deviceId, String mutationId, int localVersion,
  ) => utf8.encode(jsonEncode([
    'waffra-cloud-record', 1, vaultId, kind,
    recordId, deviceId, mutationId, localVersion,
  ]));

  static void _requireMetadata(
    String vaultId, String kind, String recordId,
    String deviceId, String mutationId, int localVersion,
  ) {
    if ([vaultId, kind, recordId, deviceId, mutationId].any((s) => s.trim().isEmpty) ||
        localVersion <= 0 ||
        [recordId, deviceId, mutationId].any((s) => s.length > 128)) {
      throw ArgumentError('Invalid encrypted cloud record metadata.');
    }
  }
}

class WaffraEncryptedCloudRecord {
  const WaffraEncryptedCloudRecord({
    required this.kind,
    required this.recordId,
    required this.deviceId,
    required this.mutationId,
    required this.localVersion,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    this.encryptionVersion = 1,
  });

  final String kind, recordId, deviceId, mutationId;
  final int localVersion, encryptionVersion;
  final String ciphertext, nonce, mac;

  /// Caller adds Firestore serverTimestamp as updatedAt. No plaintext data.
  Map<String, Object> toFirestoreDocument({bool deleted = false}) => {
    'kind': kind,
    'ciphertext': ciphertext,
    'nonce': nonce,
    'mac': mac,
    'encryptionVersion': encryptionVersion,
    'deviceId': deviceId,
    'mutationId': mutationId,
    'localVersion': localVersion,
    'deleted': deleted,
  };

  WaffraEncryptedCloudRecord copyWith({
    String? recordId, String? deviceId, String? mutationId,
    String? ciphertext, String? nonce, String? mac, int? localVersion,
  }) => WaffraEncryptedCloudRecord(
    kind: kind, recordId: recordId ?? this.recordId,
    deviceId: deviceId ?? this.deviceId,
    mutationId: mutationId ?? this.mutationId,
    localVersion: localVersion ?? this.localVersion,
    ciphertext: ciphertext ?? this.ciphertext,
    nonce: nonce ?? this.nonce,
    mac: mac ?? this.mac,
    encryptionVersion: encryptionVersion,
  );
}

class WaffraCloudSanitizer {
  const WaffraCloudSanitizer._();

  static const allowedFields = <String, Set<String>>{
    'entry': {'id','title','category','amount','income','date'},
    'category': {'id','name','icon','color','income','parentId','budget','alertPercent'},
    'goal': {'id','name','target','saved'},
    'recurring': {'id','title','category','amount','income','day','active','startAt'},
    'challenge': {'id','title','dailyAmount','days','completedDays','lastDone'},
    'postponement': {'entryId','postponedTo'},
    'merchant_rule': {'merchantKey','category'},
    'setting': {'key','value'},
    'tombstone': {'entityKind','entityId','deletedAt'},
    // The recovery index contains ONLY encrypted record pointers. The list
    // is ciphertext; no IDs, merchant names or balances are in Firestore.
    'manifest': {'id', 'records'},
  };

  static const excludedLocalOnly = <String>{
    'receiptPath', // Receipt bytes remain local unless separately opted in.
  };

  static Map<String, dynamic> sanitize(String kind, Map<String, dynamic> record) {
    final allowed = allowedFields[kind];
    if (allowed == null) throw ArgumentError.value(kind, 'kind');
    final copied = Map<String, dynamic>.of(record);
    for (final key in excludedLocalOnly) {
      copied.remove(key);
    }
    for (final key in copied.keys) {
      if (!allowed.contains(key)) {
        // Fails closed on future app fields: no automatic account info,
        // bank details, raw SMS, authentication or local file paths.
        throw StateError('Unapproved field in cloud financial record.');
      }
    }
    if (kind == 'setting' &&
        !{'monthlyBudget', 'monthlyBudgetEnabled', 'recurringRemindersEnabled'}
            .contains(copied['key'])) {
      throw StateError('This setting must never be synchronized.');
    }
    if (kind == 'manifest') {
      if (copied.keys.toSet().length != 2 ||
          copied['id'] != 'finance-index' ||
          copied['records'] is! List ||
          (copied['records'] as List).length > 1000) {
        throw StateError('Invalid encrypted recovery index.');
      }
      final seen = <String>{};
      const allowedKinds = {
        'entry','category','goal','recurring','challenge',
        'postponement','merchant_rule','setting','tombstone',
      };
      for (final item in copied['records'] as List) {
        if (item is! Map ||
            item.keys.toSet().difference({
              'kind','id','mutationId','version','deleted',
            }).isNotEmpty ||
            item.length != 5 ||
            item['kind'] is! String ||
            !allowedKinds.contains(item['kind']) ||
            item['id'] is! String ||
            (item['id'] as String).trim().isEmpty ||
            (item['id'] as String).length > 128 ||
            item['mutationId'] is! String ||
            (item['mutationId'] as String).trim().isEmpty ||
            (item['mutationId'] as String).length > 128 ||
            item['version'] is! int ||
            (item['version'] as int) <= 0 ||
            item['deleted'] is! bool ||
            !seen.add(jsonEncode([item['kind'], item['id']]))) {
          throw StateError('Invalid or duplicate encrypted index record.');
        }
      }
    }
    if (kind == 'entry' && copied['id'] is! String) {
      throw StateError('Financial record ID is missing.');
    }
    return copied;
  }
}
