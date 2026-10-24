import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_cutover_journal.dart';
import 'waffra_encrypted_finance_session.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_home_finance_persistence.dart';
import 'waffra_production_cutover_release_gate.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_production_finance_source_guard.dart';
import 'waffra_verified_encrypted_finance_bridge.dart';
import 'waffra_verified_finance_authority.dart';

/// Owns a single authoritative finance session for either Home or the
/// standalone widget engine. Neither engine is allowed to invent a vault,
/// silently fall back to legacy, or activate an encrypted source.
class WaffraProductionFinanceAuthorityBinding {
  WaffraProductionFinanceAuthorityBinding._({
    required this.authority,
    required this.encrypted,
    WaffraEncryptedStore? store,
  }) : _store = store;

  final WaffraVerifiedFinanceAuthority authority;
  final bool encrypted;
  final WaffraEncryptedStore? _store;

  /// The default shipped call sites intentionally pass no release evidence.
  /// An already-active encrypted source therefore blocks access instead of
  /// being misread as an empty legacy ledger. A future release coordinator
  /// must supply independently authenticated evidence, not UI preferences.
  static Future<WaffraProductionFinanceAuthorityBinding> bind({
    required WaffraHomeFinancePersistence legacy,
    WaffraProductionFinanceSourceGuard sourceGuard =
        const WaffraProductionFinanceSourceGuard(),
    WaffraProductionCutoverEvidence? certifiedEvidence,
    WaffraFinanceRoute startupRoute = WaffraFinanceRoute.appStartup,
    Future<Directory> Function()? directoryProvider,
    Future<String?> Function()? secureKeyReader,
  }) async {
    if (startupRoute != WaffraFinanceRoute.appStartup &&
        startupRoute != WaffraFinanceRoute.widgetStartup) {
      throw ArgumentError('Only Home or widget startup can bind finance.');
    }

    final report = await sourceGuard.inspect();
    if (report.source == WaffraProductionFinanceSource.manualRecoveryRequired) {
      throw StateError('Financial source requires independent recovery.');
    }
    if (report.source == WaffraProductionFinanceSource.guardedLegacy) {
      if (certifiedEvidence != null) {
        throw StateError('Encrypted release evidence cannot select legacy.');
      }
      return WaffraProductionFinanceAuthorityBinding._(
        authority: WaffraVerifiedFinanceAuthority(
          legacy: legacy,
          sourceGuard: sourceGuard,
        ),
        encrypted: false,
      );
    }

    final evidence = certifiedEvidence;
    if (evidence == null) {
      throw StateError(
        'Existing SQLCipher source cannot start without verified release evidence.',
      );
    }
    final decision =
        const WaffraProductionCutoverReleaseGate().inspect(evidence);
    if (!decision.eligibleForHumanReleaseReview ||
        !evidence.routes.verifiedRoutes.contains(startupRoute)) {
      throw StateError('Encrypted source release certification is incomplete.');
    }
    // Even a fully green review NEVER switches a source automatically.
    if (decision.automaticallyActivateSqlCipher) {
      throw StateError('Automatic encrypted cutover must remain disabled.');
    }

    final directory = directoryProvider != null
        ? await directoryProvider()
        : await getApplicationSupportDirectory();
    final path = File(
      directory.path +
          Platform.pathSeparator +
          WaffraEncryptedStore.encryptedDatabaseFilename,
    );
    if (await FileSystemEntity.type(path.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Activated encrypted finance vault is missing.');
    }
    final key = secureKeyReader != null
        ? await secureKeyReader()
        : await const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ).read(key: WaffraEncryptedStore.secureKeyStorageName);
    if (key == null || key.isEmpty) {
      throw StateError('Existing SQLCipher key is not recoverable.');
    }

    // openAt verifies SQLCipher availability and the existing OS key.
    // It is called ONLY for a pre-existing, already-active finance file.
    final store = WaffraEncryptedStore.openAt(path, key: key);
    try {
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: store, experimentalEnabled: true,
      );
      final journal = WaffraEncryptedCutoverJournal(
        store: store, snapshot: snapshot, experimentalEnabled: true,
      );
      final bridge = WaffraVerifiedEncryptedFinanceBridge(
        snapshot: snapshot,
        cutoverJournal: journal,
        writerDirectory: directory,
        allWritersRoutedVerified: true,
        secureKeyVerified: true,
        experimentalEnabled: true,
      );
      final authority = WaffraVerifiedFinanceAuthority(
        legacy: legacy,
        sourceGuard: sourceGuard,
        encryptedSession: WaffraEncryptedFinanceSession(
          bridge: bridge, experimentalEnabled: true,
        ),
        audit: evidence.routes,
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: true,
      );
      // A real source read rechecks both activation witnesses under the
      // shared Home/widget native lock before exposing any balance.
      final startup = await authority.load(route: startupRoute);
      if (startup.encryptedWitness == null) {
        throw StateError('Encrypted startup source witness is missing.');
      }
      startup.finance.requireIntegrity();
      return WaffraProductionFinanceAuthorityBinding._(
        authority: authority, encrypted: true, store: store,
      );
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  Future<void> close() async {
    await _store?.close();
  }
}
