import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_sms_notes_vault.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_original_sms_recovery_preflight.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _LegacyOnlySource extends WaffraProductionFinanceSourceGuard {
  const _LegacyOnlySource();
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'm231_disposable_only',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  String? key;

  WaffraEncryptedSmsNotesVault notes() => WaffraEncryptedSmsNotesVault(
    directoryProvider: () async => root,
    keyReader: () async => key,
    keyWriter: (next) async => key = next,
  );

  WaffraVerifiedFinanceAuthority authority() =>
      WaffraVerifiedFinanceAuthority(
        sourceGuard: const _LegacyOnlySource(),
        protectedSmsNotes: notes(),
        legacy: WaffraHomeFinancePersistence(
          coordinator: WaffraLegacyFinanceWriterCoordinator(
            testDirectory: root,
            sourceProbe: (_) async {},
          ),
        ),
      );

  Map<String, Object?> entry(String id) => <String, Object?>{
    'id': id,
    'title': 'Sanitized POS',
    'category': 'أخرى',
    'amount': 13.25,
    'income': false,
    'date': '2026-10-26T00:00:00.000Z',
    'receiptPath': null,
    'notes': '',
    'sourceType': 'sms',
    'merchantKey': '',
  };

  Future<void> install(List<String> ids, List<String> originals,
      {bool stage = true, bool dedupe = true}) async {
    final hashes = originals.map(
      WaffraEncryptedSmsNotesVault.fingerprint).toList();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': jsonEncode(ids.map(entry).toList()),
      'waffra_sms_hashes_v1': dedupe ? hashes : <String>[],
    });
    if (stage && originals.isNotEmpty) {
      await notes().stage(
        records: List.generate(ids.length, (i) => <String, Object?>{
          'id': ids[i],
          'sourceType': 'sms',
          'notes': originals[i],
        }),
        hashes: hashes,
      );
    }
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m231-notes-');
    key = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M231 counts real original SMS recovered after encrypted cold open',
      () async {
    await install(['a', 'b'], ['شراء\\n13.25 SAR', 'حوالة واردة\\n800 SAR']);
    final service = authority();
    final initial = await service.load(
      route: WaffraFinanceRoute.dashboardRead);
    final report = await WaffraOriginalSmsRecoveryPreflight(
      authority: service).inspect(baseline: initial);
    expect(report.confirmedSmsCount, 2);
    expect(report.verifiedOriginalCount, 2);
    expect(report.missingOriginalCount, 0);
    expect(report.allConfirmedOriginalsRecoverable, isTrue);
    expect(report.portableSmsRestoreCertified, isFalse);
    expect(report.productionCutoverAuthorized, isFalse);
  });

  test('M231 missing side vault is reported, never silently fabricated',
      () async {
    await install(['a'], ['شراء 13.25 SAR'], stage: false);
    final service = authority();
    final initial = await service.load(route: WaffraFinanceRoute.dashboardRead);
    final report = await WaffraOriginalSmsRecoveryPreflight(
      authority: service).inspect(baseline: initial);
    expect(report.missingOriginalCount, 1);
    expect(report.allConfirmedOriginalsRecoverable, isFalse);
    expect(key, isNull);
    expect(await File('${root.path}/${WaffraEncryptedSmsNotesVault.filename}')
        .exists(), isFalse);
  });

  test('M231 dedupe hash mismatch refuses recoverability claim', () async {
    await install(['a'], ['شراء 13.25 SAR'], dedupe: false);
    final service = authority();
    final initial = await service.load(route: WaffraFinanceRoute.dashboardRead);
    final report = await WaffraOriginalSmsRecoveryPreflight(
      authority: service).inspect(baseline: initial);
    expect(report.missingHashCount, 1);
    expect(report.verifiedOriginalCount, 0);
    expect(report.allConfirmedOriginalsRecoverable, isFalse);
  });

  test('M231 damaged OS key is rejected, not treated as missing note',
      () async {
    await install(['a'], ['شراء 13.25 SAR']);
    final service = authority();
    final initial = await service.load(route: WaffraFinanceRoute.dashboardRead);
    key = null; // key lost while ciphertext file remains
    await expectLater(WaffraOriginalSmsRecoveryPreflight(
      authority: service).inspect(baseline: initial), throwsStateError);
  });

  test('M231 stale ledger preflight refuses mismatched finance witness',
      () async {
    await install(['a'], ['شراء 13.25 SAR']);
    final service = authority();
    final initial = await service.load(route: WaffraFinanceRoute.dashboardRead);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', jsonEncode([entry('a'), entry('new')]));
    await expectLater(WaffraOriginalSmsRecoveryPreflight(
      authority: service).inspect(baseline: initial), throwsStateError);
  });
}
