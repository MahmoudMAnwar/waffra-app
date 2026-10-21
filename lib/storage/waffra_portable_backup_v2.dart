import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../waffra_secure_backup.dart';
import 'legacy_financial_snapshot.dart';
import 'legacy_snapshot_preflight.dart';

/// A receipt represented by its ledger association, never by its device-local
/// filename. Images are packed as ciphertext inside the encrypted backup.
class WaffraReceiptBackupPart {
  const WaffraReceiptBackupPart({
    required this.entryId,
    required this.position,
    required this.bytes,
  });

  final String entryId;
  final int position;
  final List<int> bytes;
}

/// A *verified preview*, not an automatic import or restore operation.
/// Caller must separately implement a safe destination mapping for receipts,
/// conflict handling, source backup, writer freeze and rollback.
class WaffraBackupV2Preview {
  const WaffraBackupV2Preview({
    required this.financialSnapshot,
    required this.receipts,
    required this.sourceChecksum,
  });

  final Map<String, Object?> financialSnapshot;
  final List<WaffraReceiptBackupPart> receipts;
  final String sourceChecksum;
  int get receiptCount => receipts.length;
}

/// Portable, password-encrypted financial snapshot + receipt file bytes.
/// This experiment does not access phone files, SharedPreferences, Firebase
/// or current app records. Callers must explicitly supply the snapshot and
/// all referenced receipt bytes; missing receipts FAIL CLOSED instead of
/// falsely claiming a complete restore.
///
/// The encrypted envelope uses the existing WaffraSecureBackup AES-256-GCM
/// utility for compatibility with the current app. This is deliberately an
/// opt-in prototype, NOT wired into main.dart or an automatic backup service.
class WaffraPortableBackupV2 {
  const WaffraPortableBackupV2._();

  static const maxReceipts = 500;
  static const maxReceiptBytes = 8 * 1024 * 1024;
  static const maxCombinedReceiptBytes = 60 * 1024 * 1024;
  static const maxEncryptedFileCharacters = 125 * 1024 * 1024;
  static const _extraSafeKey = 'waffra_custom_goals_v1';

  static Set<String> get _safeKeys => {
    ...WaffraLegacyPreflight.allKeys,
    _extraSafeKey,
  };

  static void _validateSnapshot(Map<String, Object?> snapshot) {
    if (snapshot.keys.any((key) => !_safeKeys.contains(key))) {
      throw StateError('Unapproved backup snapshot field.');
    }
    final validation = WaffraLegacyPreflight.inspect(snapshot);
    if (!validation.canStage) {
      throw StateError('Corrupt financial snapshot; backup refused.');
    }
    final custom = snapshot[_extraSafeKey];
    if (custom != null &&
        (custom is! List<String> ||
         custom.any((v) => v.trim().isEmpty || v.length > 512))) {
      throw StateError('Invalid custom goal suggestions.');
    }
    // Finance JSON may contain forward-version fields. Reject known private
    // keys explicitly, including fields that the migration preflight may
    // otherwise ignore. Never persist bank access or raw SMS bodies.
    for (final key in WaffraLegacyPreflight.financeListKeys) {
      final raw = snapshot[key];
      if (raw is! String) continue;
      final items = jsonDecode(raw) as List;
      for (final item in items) {
        _checkNoSensitiveFields(item);
      }
    }
  }

  static void _checkNoSensitiveFields(Object? value) {
    const blocked = {
      'rawSms', 'bankAccount', 'bankCredentials', 'password',
      'pin', 'pinHash', 'authToken', 'accessToken', 'accountNumber',
      'iban', 'secretKey',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String || blocked.contains(entry.key)) {
          throw StateError('Private banking/authentication field blocked.');
        }
        _checkNoSensitiveFields(entry.value);
      }
    } else if (value is List) {
      for (final child in value) {
        _checkNoSensitiveFields(child);
      }
    }
  }

  /// Exact expected associations come from original entry receipt ordering,
  /// but no local absolute paths are exposed outside the encrypted payload.
  static Map<String, int> _receiptExpectations(
      Map<String, Object?> snapshot) {
    final expected = <String, int>{};
    final raw = snapshot['entries'];
    if (raw == null) return expected;
    final entries = jsonDecode(raw as String) as List;
    for (final item in entries) {
      final row = Map<String, dynamic>.from(item as Map);
      final id = row['id'] as String;
      final paths =
          WaffraLegacySnapshotInspector.receiptPaths(row['receiptPath']);
      if (paths.isNotEmpty) expected[id] = paths.length;
    }
    return expected;
  }

  static void _validateReceipts(
    Map<String, Object?> snapshot,
    List<WaffraReceiptBackupPart> receipts,
  ) {
    final expected = _receiptExpectations(snapshot);
    final expectedCount =
        expected.values.fold<int>(0, (a, b) => a + b);
    if (expectedCount > maxReceipts || receipts.length != expectedCount) {
      throw StateError('Missing or unexpected receipt bytes.');
    }
    final matched = <String>{};
    var totalBytes = 0;
    for (final part in receipts) {
      final required = expected[part.entryId];
      if (required == null ||
          part.position < 0 || part.position >= required ||
          !matched.add(jsonEncode([part.entryId, part.position]))) {
        throw StateError('Unexpected or duplicate receipt association.');
      }
      if (part.bytes.isEmpty || part.bytes.length > maxReceiptBytes) {
        throw StateError('Receipt file missing or too large.');
      }
      totalBytes += part.bytes.length;
      if (totalBytes > maxCombinedReceiptBytes) {
        throw StateError('Total receipt backup exceeds size limit.');
      }
    }
    if (matched.length != expectedCount) {
      throw StateError('Missing receipt bytes.');
    }
  }

  static Map<String, Object?> _snapshotCopy(
      Map<String, Object?> original) =>
      Map<String, Object?>.from(original);

  static Future<String> create({
    required Map<String, Object?> financialSnapshot,
    required List<WaffraReceiptBackupPart> receipts,
    required String password,
  }) async {
    _validateSnapshot(financialSnapshot);
    _validateReceipts(financialSnapshot, receipts);
    final originalChecksum =
        WaffraLegacyPreflight.inspect(financialSnapshot).sourceSha256;
    final ordered = receipts.toList()
      ..sort((a, b) {
        final entry = a.entryId.compareTo(b.entryId);
        return entry != 0 ? entry : a.position.compareTo(b.position);
      });
    final archive = jsonEncode({
      'format': 'waffra-portable-finance',
      'version': 2,
      'sourceChecksum': originalChecksum,
      'snapshot': financialSnapshot,
      'receiptCount': ordered.length,
      'receipts': ordered.map((receipt) => {
        'entryId': receipt.entryId,
        'position': receipt.position,
        'bytes': base64Encode(receipt.bytes),
        'sha256': sha256.convert(receipt.bytes).toString(),
        'byteLength': receipt.bytes.length,
      }).toList(),
    });
    return WaffraSecureBackup.encrypt(archive, password);
  }

  /// Strictly encrypted input only; unlike the legacy backup importer this
  /// method NEVER accepts a plaintext v1 backup or unencrypted v2 JSON.
  static Future<WaffraBackupV2Preview> verifyAndPreview({
    required String encryptedArchive,
    required String password,
  }) async {
    if (encryptedArchive.length > maxEncryptedFileCharacters) {
      throw const FormatException('Encrypted archive too large.');
    }
    final rawEnvelope = jsonDecode(encryptedArchive);
    if (rawEnvelope is! Map ||
        rawEnvelope['format'] != 'waffra-secure-backup' ||
        rawEnvelope['version'] != 1) {
      throw const FormatException('A password-encrypted backup is required.');
    }
    final clear = await WaffraSecureBackup.decrypt(
      encryptedArchive, password);
    final object = jsonDecode(clear);
    if (object is! Map ||
        object['format'] != 'waffra-portable-finance' ||
        object['version'] != 2 ||
        object['snapshot'] is! Map ||
        object['receipts'] is! List ||
        object['receiptCount'] is! int ||
        object['sourceChecksum'] is! String) {
      throw const FormatException('Unsupported portable financial backup.');
    }
    const expectedKeys = {
      'format', 'version', 'snapshot', 'receiptCount', 'receipts',
      'sourceChecksum',
    };
    if (object.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(object.keys.toSet()).isNotEmpty) {
      throw const FormatException('Unrecognized backup metadata.');
    }

    final snapshot = Map<String, Object?>.from(object['snapshot'] as Map);
    // JSON decode yields List<dynamic>; restore typed list-of-string keys.
    for (final name in [
      ...WaffraLegacyPreflight.financeListOfStringsKeys,
      _extraSafeKey,
    ]) {
      final value = snapshot[name];
      if (value is List) {
        if (value.any((e) => e is! String)) {
          throw const FormatException('Invalid backup list data.');
        }
        snapshot[name] = List<String>.from(value);
      }
    }
    _validateSnapshot(snapshot);
    final checksum = WaffraLegacyPreflight.inspect(snapshot).sourceSha256;
    if (object['sourceChecksum'] != checksum) {
      throw StateError('Financial source checksum mismatch.');
    }
    final receiptRows = object['receipts'] as List;
    if (receiptRows.length != object['receiptCount'] ||
        receiptRows.length > maxReceipts) {
      throw StateError('Receipt backup count mismatch.');
    }
    final attachments = <WaffraReceiptBackupPart>[];
    for (final row in receiptRows) {
      if (row is! Map || row.keys.toSet().difference({
        'entryId', 'position', 'bytes', 'sha256', 'byteLength',
      }).isNotEmpty || row.length != 5 ||
          row['entryId'] is! String || row['position'] is! int ||
          row['bytes'] is! String || row['sha256'] is! String ||
          row['byteLength'] is! int) {
        throw const FormatException('Unrecognized receipt metadata.');
      }
      if ((row['byteLength'] as int) <= 0 ||
          (row['byteLength'] as int) > maxReceiptBytes ||
          (row['bytes'] as String).length >
              ((maxReceiptBytes + 2) ~/ 3) * 4 + 4) {
        throw StateError('Invalid receipt size.');
      }
      final bytes = base64Decode(row['bytes'] as String);
      if (bytes.length != row['byteLength'] ||
          sha256.convert(bytes).toString() != row['sha256']) {
        throw StateError('Receipt integrity mismatch.');
      }
      attachments.add(WaffraReceiptBackupPart(
        entryId: row['entryId'] as String,
        position: row['position'] as int,
        bytes: bytes,
      ));
    }
    _validateReceipts(snapshot, attachments);
    return WaffraBackupV2Preview(
      financialSnapshot: _snapshotCopy(snapshot),
      receipts: List.unmodifiable(attachments),
      sourceChecksum: checksum,
    );
  }
}
