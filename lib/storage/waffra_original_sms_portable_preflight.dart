import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../waffra_secure_backup.dart';
import 'waffra_encrypted_sms_notes_vault.dart';
import 'waffra_original_sms_recovery_preflight.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_verified_finance_authority.dart';

/// Authenticated but strictly read-only original-SMS recovery candidate.
/// The returned text is only held in app memory for an independently staged
/// restore. It must never go to logs, plaintext files or the clipboard.
class WaffraOriginalSmsPortablePreview {
  const WaffraOriginalSmsPortablePreview({
    required this.originalsById,
    required this.financeLinkDigest,
  });

  final Map<String, String> originalsById;
  final String financeLinkDigest;

  /// A decryptable staging preview is NOT a verified source swap or backup.
  bool get activeFinanceRestored => false;
  bool get portableFinanceBackupComplete => false;
  bool get productionCutoverAuthorized => false;
}

/// Temporary sealed archive for the OS-keyed *legacy side-vault* notes.
/// The separate approved financial backup must independently certify all
/// transaction fields and receipt bytes; this candidate does not replace it.
class WaffraOriginalSmsPortablePreflight {
  const WaffraOriginalSmsPortablePreflight._();
  static const maxSms = 10000;
  static const maxCombinedCharacters = 8000000;

  static Map<String, Map<String, Object?>> _confirmedLinks(String? ledgerRaw) {
    final decoded = jsonDecode(ledgerRaw ?? '[]');
    if (decoded is! List || decoded.length > 50000) {
      throw StateError('Untrusted original SMS ledger.');
    }
    final links = <String, Map<String, Object?>>{};
    for (final raw in decoded) {
      if (raw is! Map) throw StateError('Untrusted ledger row.');
      if (raw['sourceType'] != 'sms') continue;
      final id = raw['id'];
      if (id is! String || id.trim().isEmpty || id.length > 128 ||
          raw['amount'] is! num ||
          raw['income'] is! bool ||
          raw['date'] is! String ||
          raw['category'] is! String ||
          links.containsKey(id)) {
        throw StateError('Invalid original SMS ledger identity.');
      }
      links[id] = <String, Object?>{
        'id': id, 'amount': raw['amount'],
        'income': raw['income'], 'date': raw['date'],
        'category': raw['category'],
      };
      if (links.length > maxSms) throw StateError('Too many protected SMS.');
    }
    return links;
  }

  /// Stable financial link proof unaffected by receipt file-path remapping.
  static String financeLinkDigest(String? ledgerRaw) {
    final links = _confirmedLinks(ledgerRaw);
    final ids = links.keys.toList()..sort();
    return sha256.convert(utf8.encode(
      jsonEncode(ids.map((id) => links[id]).toList()),
    )).toString();
  }

  static Future<String> exportCandidate({
    required WaffraVerifiedFinanceAuthority authority,
    required WaffraFinanceAuthorityRead baseline,
    required String password,
  }) async {
    if (!WaffraSecureBackup.isValidNewPassword(password)) {
      throw const FormatException('A strong archive password is required.');
    }
    final parity = await WaffraOriginalSmsRecoveryPreflight(
      authority: authority).inspect(baseline: baseline);
    if (!parity.allConfirmedOriginalsRecoverable) {
      throw StateError('Bank original-note recovery parity is incomplete.');
    }
    final links = _confirmedLinks(baseline.ledgerRaw);
    final sorted = links.keys.toList()..sort();
    final records = <Map<String, String>>[];
    var total = 0;
    final hashes = (baseline.finance.getStringList('waffra_sms_hashes_v1') ??
        <String>[]).toSet();
    for (final id in sorted) {
      final message = await authority.readProtectedOriginalSms(id);
      if (message == null || message.trim().isEmpty ||
          message.runes.length > 16000) {
        throw StateError('Confirmed SMS original changed during export.');
      }
      total += message.length;
      if (total > maxCombinedCharacters) {
        throw StateError('Original note archive exceeds safety limit.');
      }
      final hash = WaffraEncryptedSmsNotesVault.fingerprint(message);
      if (!hashes.contains(hash)) {
        throw StateError('Original SMS fingerprint changed during export.');
      }
      records.add({'id': id, 'hash': hash, 'original': message});
    }
    final after = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    if (after.source != baseline.source ||
        after.ledgerRaw != baseline.ledgerRaw ||
        after.widgetRevision != baseline.widgetRevision ||
        jsonEncode(after.finance.getStringList('waffra_sms_hashes_v1')) !=
          jsonEncode(baseline.finance.getStringList('waffra_sms_hashes_v1'))) {
      throw StateError('Source changed during original note archive.');
    }
    // Argon2id + AES-256-GCM: the only serialized output is ciphertext.
    return WaffraSecureBackup.encryptUserBackup(jsonEncode({
      'format': 'waffra-original-sms-staging',
      'version': 1,
      'financeLinkDigest': financeLinkDigest(baseline.ledgerRaw),
      'records': records,
    }), password);
  }

  /// Authenticated decryption only; never writes to either live source.
  /// A future restoration coordinator must freeze writers, verify owner,
  /// validate receipts and commit originals with the verified finance vault.
  static Future<WaffraOriginalSmsPortablePreview> verifyAndPreview({
    required String encryptedArchive,
    required String password,
    required String? expectedLedgerRaw,
    required List<String> expectedHashes,
  }) async {
    if (encryptedArchive.length > 35000000) {
      throw const FormatException('Protected SMS archive too large.');
    }
    // decrypt() has a legacy plaintext-backup compatibility path; do NOT
    // allow that path for any bank SMS recovery archive.
    if (!WaffraSecureBackup.hasValidEncryptedHeader(encryptedArchive)) {
      throw const FormatException('Only password encrypted notes are accepted.');
    }
    final envelope = jsonDecode(encryptedArchive);
    if (envelope is! Map || envelope['version'] != 2) {
      throw const FormatException('Strong encrypted notes archive required.');
    }
    final clear = await WaffraSecureBackup.decrypt(encryptedArchive, password);
    final payload = jsonDecode(clear);
    if (payload is! Map ||
        payload.keys.toSet().difference({
          'format', 'version', 'financeLinkDigest', 'records',
        }).isNotEmpty ||
        payload.length != 4 ||
        payload['format'] != 'waffra-original-sms-staging' ||
        payload['version'] != 1 ||
        payload['financeLinkDigest'] is! String ||
        payload['records'] is! List) {
      throw const FormatException('Unsupported original SMS archive.');
    }
    final links = _confirmedLinks(expectedLedgerRaw);
    final digest = financeLinkDigest(expectedLedgerRaw);
    if (payload['financeLinkDigest'] != digest) {
      throw StateError('SMS archive does not match authenticated finance.');
    }
    final expected = expectedHashes.toSet();
    if (expected.length != expectedHashes.length ||
        expected.any((x) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(x))) {
      throw StateError('Original SMS dedupe witness is invalid.');
    }
    final rows = payload['records'] as List;
    if (rows.length != links.length || rows.length > maxSms) {
      throw StateError('Original SMS archive is incomplete.');
    }
    final notes = <String, String>{};
    var size = 0;
    for (final row in rows) {
      if (row is! Map ||
          row.keys.toSet().difference({'id', 'hash', 'original'}).isNotEmpty ||
          row.length != 3 ||
          row['id'] is! String || row['hash'] is! String ||
          row['original'] is! String ||
          !links.containsKey(row['id']) ||
          notes.containsKey(row['id'])) {
        throw StateError('Unexpected archived original SMS identity.');
      }
      final message = row['original'] as String;
      if (message.trim().isEmpty || message.runes.length > 16000 ||
          WaffraEncryptedSmsNotesVault.fingerprint(message) != row['hash'] ||
          !expected.contains(row['hash'])) {
        throw StateError('Original SMS archive integrity mismatch.');
      }
      size += message.length;
      if (size > maxCombinedCharacters) {
        throw StateError('Original SMS archive size exceeds limit.');
      }
      notes[row['id'] as String] = message;
    }
    return WaffraOriginalSmsPortablePreview(
      originalsById: Map<String, String>.unmodifiable(notes),
      financeLinkDigest: digest,
    );
  }
}
