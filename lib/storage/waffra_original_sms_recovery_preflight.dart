import 'dart:convert';

import 'waffra_encrypted_sms_notes_vault.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_runtime_finance_route_contract.dart';
import 'waffra_verified_finance_authority.dart';

/// Read-only inventory of *confirmed* bank SMS originals still recoverable
/// from the OS-keyed encrypted side vault. The ledger is the only authority
/// for IDs: uncommitted staged originals are NEVER counted as saved finance.
///
/// This is NOT an encrypted backup, migration, portable restore or permission
/// to activate SQLCipher. It never exposes raw SMS text in its result.
class WaffraOriginalSmsRecoveryReport {
  const WaffraOriginalSmsRecoveryReport({
    required this.confirmedSmsCount,
    required this.verifiedOriginalCount,
    required this.missingOriginalCount,
    required this.missingHashCount,
  });

  final int confirmedSmsCount;
  final int verifiedOriginalCount;
  final int missingOriginalCount;
  final int missingHashCount;

  bool get allConfirmedOriginalsRecoverable =>
      confirmedSmsCount == verifiedOriginalCount &&
      missingOriginalCount == 0 &&
      missingHashCount == 0;

  /// Original messages are not yet included in cross-device portable backups.
  bool get portableSmsRestoreCertified => false;
  bool get productionCutoverAuthorized => false;
}

/// A staging guard that refuses stale finance witnesses or missing/damaged
/// encrypted original notes without writing a source marker, key, or ledger.
class WaffraOriginalSmsRecoveryPreflight {
  const WaffraOriginalSmsRecoveryPreflight({required this.authority});

  final WaffraVerifiedFinanceAuthority authority;

  Future<WaffraOriginalSmsRecoveryReport> inspect({
    required WaffraFinanceAuthorityRead baseline,
  }) async {
    if (baseline.source != WaffraRuntimeFinanceBackend.guardedLegacy) {
      throw StateError('Side-vault preflight expects guarded-legacy authority.');
    }
    baseline.finance.requireIntegrity();
    final current = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    current.finance.requireIntegrity();
    if (current.source != baseline.source ||
        current.ledgerRaw != baseline.ledgerRaw ||
        current.widgetRevision != baseline.widgetRevision ||
        current.finance.getStringList('waffra_sms_hashes_v1').toString() !=
            baseline.finance.getStringList('waffra_sms_hashes_v1').toString()) {
      throw StateError('Finance changed before original SMS preflight.');
    }

    final raw = current.ledgerRaw;
    final decoded = raw == null ? <dynamic>[] : jsonDecode(raw);
    if (decoded is! List || decoded.length > 50000) {
      throw StateError('Verified source ledger is invalid.');
    }
    final storedHashes =
        current.finance.getStringList('waffra_sms_hashes_v1') ?? <String>[];
    final hashes = storedHashes.toSet();
    if (hashes.length != storedHashes.length ||
        hashes.any((hash) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))) {
      throw StateError('Confirmed SMS dedupe evidence is invalid.');
    }

    final seenIds = <String>{};
    var confirmed = 0, verified = 0, missing = 0, missingHash = 0;
    for (final item in decoded) {
      if (item is! Map) {
        throw StateError('Untrusted finance ledger entry.');
      }
      if (item['sourceType'] != 'sms') continue;
      final id = item['id'];
      if (id is! String || id.trim().isEmpty ||
          id.length > 128 || !seenIds.add(id)) {
        throw StateError('Invalid or duplicate saved bank SMS transaction.');
      }
      // A redacted guarded-legacy ledger must not hold full bank messages.
      if (item['notes'] is String &&
          (item['notes'] as String).isNotEmpty) {
        throw StateError('Sensitive SMS text must not be in legacy finance.');
      }
      confirmed++;
      // The authority first checks this ID against the *current* authoritative
      // finance ledger, then the side-vault verifies its stored SHA-256 hash.
      final original = await authority.readProtectedOriginalSms(id);
      if (original == null) {
        missing++;
        continue;
      }
      final digest = WaffraEncryptedSmsNotesVault.fingerprint(original);
      if (!hashes.contains(digest)) {
        missingHash++;
        continue;
      }
      verified++;
    }

    // Reads may span multiple OS-keyed vault opens. Any finance write during
    // the scan invalidates the snapshot instead of inventing recovery parity.
    final after = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    after.finance.requireIntegrity();
    if (after.source != current.source ||
        after.ledgerRaw != current.ledgerRaw ||
        after.widgetRevision != current.widgetRevision ||
        after.finance.getStringList('waffra_sms_hashes_v1').toString() !=
            current.finance.getStringList('waffra_sms_hashes_v1').toString()) {
      throw StateError('Finance changed during original SMS recovery scan.');
    }
    return WaffraOriginalSmsRecoveryReport(
      confirmedSmsCount: confirmed,
      verifiedOriginalCount: verified,
      missingOriginalCount: missing,
      missingHashCount: missingHash,
    );
  }
}
