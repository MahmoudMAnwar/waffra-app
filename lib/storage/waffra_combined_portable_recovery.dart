import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../waffra_secure_backup.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_original_sms_disposable_restore_verifier.dart';
import 'waffra_original_sms_portable_preflight.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';
import 'waffra_restored_finance_receipt_attestor.dart';

/// All component archives are separately authenticated, then *jointly*
/// authenticated under an Argon2id/AES-256-GCM container. This is NOT the
/// production backup format until its app/Widget and account migration ships.
class WaffraCombinedRecoveryPreview {
  const WaffraCombinedRecoveryPreview._({
    required this.financial,
    required this.originals,
    required this.financeArchive,
    required this.originalArchive,
  });

  final WaffraBackupV2Preview financial;
  final WaffraOriginalSmsPortablePreview originals;
  final String financeArchive;
  final String originalArchive;
  bool get activeSourceRestored => false;
  bool get twoPhysicalDevicesAttested => false;
  bool get productionCutoverAuthorized => false;
}

class WaffraCombinedRecoveryReport {
  const WaffraCombinedRecoveryReport({
    required this.transactionCount,
    required this.receiptCount,
    required this.receiptBytes,
    required this.originalSmsCount,
    required this.financeChecksum,
  });

  final int transactionCount;
  final int receiptCount;
  final int receiptBytes;
  final int originalSmsCount;
  final String financeChecksum;

  bool get activeSourceReplaced => false;
  bool get productionCutoverAuthorized => false;
  bool get twoPhysicalDevicesAttested => false;
}

/// QA-only portable financial records + receipt bytes + original SMS bundle.
/// No live path or key parameter is accepted. Both restored SQLCipher vaults
/// are disposable and are removed on every exit path.
class WaffraCombinedPortableRecovery {
  const WaffraCombinedPortableRecovery._();

  static const maxOuterArchiveCharacters = 180 * 1024 * 1024;
  static const _expectedKeys = {
    'format', 'version', 'financeArchive', 'originalArchive',
    'financeChecksum', 'originalSmsLinkDigest', 'receiptCount',
  };

  static List<String> _hashes(WaffraBackupV2Preview preview) {
    final values = preview.financialSnapshot['waffra_sms_hashes_v1'];
    if (values == null) return <String>[];
    if (values is! List<String>) {
      throw StateError('Authenticated finance SMS fingerprints are invalid.');
    }
    return List<String>.unmodifiable(values);
  }

  static Future<WaffraCombinedRecoveryPreview> _verifyParts({
    required String financeArchive,
    required String originalArchive,
    required String password,
  }) async {
    final finances = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: financeArchive, password: password,
    );
    final original = await WaffraOriginalSmsPortablePreflight.verifyAndPreview(
      encryptedArchive: originalArchive,
      password: password,
      expectedLedgerRaw: finances.financialSnapshot['entries'] as String?,
      expectedHashes: _hashes(finances),
    );
    return WaffraCombinedRecoveryPreview._(
      financial: finances,
      originals: original,
      financeArchive: financeArchive,
      originalArchive: originalArchive,
    );
  }

  static Future<String> seal({
    required String encryptedFinanceArchive,
    required String encryptedOriginalSmsArchive,
    required String password,
  }) async {
    if (!WaffraSecureBackup.isValidNewPassword(password)) {
      throw const FormatException('Strong recovery password is required.');
    }
    final checked = await _verifyParts(
      financeArchive: encryptedFinanceArchive,
      originalArchive: encryptedOriginalSmsArchive,
      password: password,
    );
    return WaffraSecureBackup.encryptUserBackup(jsonEncode({
      'format': 'waffra-combined-recovery-candidate',
      'version': 1,
      'financeArchive': encryptedFinanceArchive,
      'originalArchive': encryptedOriginalSmsArchive,
      'financeChecksum': checked.financial.sourceChecksum,
      'originalSmsLinkDigest': checked.originals.financeLinkDigest,
      'receiptCount': checked.financial.receiptCount,
    }), password);
  }

  static Future<WaffraCombinedRecoveryPreview> verifyAndPreview({
    required String encryptedBundle,
    required String password,
  }) async {
    if (encryptedBundle.length > maxOuterArchiveCharacters ||
        !WaffraSecureBackup.hasValidEncryptedHeader(encryptedBundle)) {
      throw const FormatException('Encrypted combined recovery required.');
    }
    final envelope = jsonDecode(encryptedBundle);
    if (envelope is! Map || envelope['version'] != 2) {
      throw const FormatException('Strong recovery envelope required.');
    }
    final clear = await WaffraSecureBackup.decrypt(encryptedBundle, password);
    final data = jsonDecode(clear);
    if (data is! Map || data.keys.toSet().difference(_expectedKeys).isNotEmpty ||
        _expectedKeys.difference(data.keys.toSet()).isNotEmpty ||
        data['format'] != 'waffra-combined-recovery-candidate' ||
        data['version'] != 1 ||
        data['financeArchive'] is! String ||
        data['originalArchive'] is! String ||
        data['financeChecksum'] is! String ||
        data['originalSmsLinkDigest'] is! String ||
        data['receiptCount'] is! int) {
      throw const FormatException('Unrecognized complete finance archive.');
    }
    final checked = await _verifyParts(
      financeArchive: data['financeArchive'] as String,
      originalArchive: data['originalArchive'] as String,
      password: password,
    );
    if (checked.financial.sourceChecksum != data['financeChecksum'] ||
        checked.originals.financeLinkDigest != data['originalSmsLinkDigest'] ||
        checked.financial.receiptCount != data['receiptCount']) {
      throw StateError('Combined financial recovery manifest mismatch.');
    }
    return checked;
  }

  /// Rebuilds financial rows and encrypted receipt bytes in a disposable
  /// SQLCipher file, closes and reopens it, then independently performs the
  /// bank SMS disposable restore verification. Nothing reaches a live source.
  static Future<WaffraCombinedRecoveryReport> verifyDisposableRestore({
    required String encryptedBundle,
    required String password,
  }) async {
    final verified = await verifyAndPreview(
      encryptedBundle: encryptedBundle, password: password,
    );
    final folder = await Directory.systemTemp.createTemp(
      'waffra-complete-disposable-finance-recovery-',
    );
    final random = Random.secure();
    final ephemeralKey = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final file = File('${folder.path}/verified-finance.sqlite');
    WaffraEncryptedStore? destination;
    late WaffraPortableEncryptedRestoreResult result;
    try {
      destination = WaffraEncryptedStore.openAt(
        file, key: ephemeralKey,
      );
      result = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: destination,
        experimentalEnabled: true,
      ).restore(
        encryptedArchive: verified.financeArchive,
        password: password,
      );
      await WaffraRestoredFinanceReceiptAttestor(
        store: destination,
        experimentalEnabled: true,
      ).attest(
        authenticatedArchive: verified.financial,
        reported: result,
      );
      await destination.close();
      destination = null;
      destination = WaffraEncryptedStore.openAt(
        file, key: ephemeralKey,
      );
      await WaffraRestoredFinanceReceiptAttestor(
        store: destination,
        experimentalEnabled: true,
      ).attest(
        authenticatedArchive: verified.financial,
        reported: result,
      );
      final sms = await const WaffraDisposableOriginalSmsRestoreVerifier()
          .inspect(
        encryptedArchive: verified.originalArchive,
        password: password,
        expectedLedgerRaw:
            verified.financial.financialSnapshot['entries'] as String? ?? '[]',
        expectedHashes: _hashes(verified.financial),
      );
      if (!sms.byteExactParityVerified ||
          sms.verifiedAfterColdReopen != verified.originals.originalsById.length) {
        throw StateError('Combined encrypted SMS recovery parity failed.');
      }
    } finally {
      try {
        if (destination != null) await destination.close();
      } finally {
        if (await folder.exists()) await folder.delete(recursive: true);
      }
    }
    return WaffraCombinedRecoveryReport(
      transactionCount: result.transactionCount,
      receiptCount: result.receiptCount,
      receiptBytes: result.receiptBytes,
      originalSmsCount: verified.originals.originalsById.length,
      financeChecksum: result.sourceChecksum,
    );
  }
}
