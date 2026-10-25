import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_sms_notes_vault.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _LegacyWitness extends WaffraProductionFinanceSourceGuard {
  const _LegacyWitness();
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'disposable_integration_test_only',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  String? wrappedKey;

  WaffraEncryptedSmsNotesVault protectedVault({
    bool failKeyWrite = false,
  }) => WaffraEncryptedSmsNotesVault(
    directoryProvider: () async => directory,
    keyReader: () async => wrappedKey,
    keyWriter: (value) async {
      if (failKeyWrite) throw StateError('Simulated secure-storage failure');
      wrappedKey = value;
    },
  );

  WaffraVerifiedFinanceAuthority authority(
    WaffraEncryptedSmsNotesVault protected,
  ) => WaffraVerifiedFinanceAuthority(
    protectedSmsNotes: protected,
    sourceGuard: const _LegacyWitness(),
    legacy: WaffraHomeFinancePersistence(
      coordinator: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: directory,
        sourceProbe: (_) async {}, // Never trust synthetic checks in prod.
      ),
    ),
  );

  Map<String, Object?> record(String id, String sms, {bool income = false}) => {
    'id': id, 'title': 'Safe parsed transaction title',
    'category': income ? 'راتب' : 'أخرى',
    'amount': income ? 600.0 : 125.5,
    'income': income,
    'date': '2026-10-25T12:00:00.000Z',
    'receiptPath': null,
    'notes': sms, 'sourceType': 'sms', 'merchantKey': '',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-m226-smoke-');
    wrappedKey = null;
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>[],
    });
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('M226 Home: confirmed real writer commits redacted ledger and exact'
      ' SQLCipher SMS notes with cold-reopen and authenticated ID lookup', () async {
    final first = 'شراء نقاط بيع\nالمبلغ: ١٢٥٫٥٠ ر.س\nالتاريخ: 25/10/2026';
    final second = 'حوالة واردة\n600 SAR\nمن مرسل تجريبي';
    final inputs = [record('expense-one', first), record('income-one', second,
      income: true)];
    final hashes = [first, second]
        .map(WaffraEncryptedSmsNotesVault.fingerprint).toList();
    final service = authority(protectedVault());

    final saved = await service.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: inputs, hashes: hashes, userConfirmed: true,
    );
    expect(saved.saved, 2);
    expect(saved.originalSmsNotesOmittedOnLegacy, isFalse);
    expect(saved.income, 1);
    expect(saved.expenses, 1);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rows = jsonDecode(prefs.getString('entries')!) as List;
    expect(rows.length, 2);
    for (final row in rows) {
      expect(row['notes'], '');
      expect(row['sourceType'], 'sms');
      expect(row['title'], isNot(contains('المبلغ:')));
    }
    expect(prefs.getStringList('waffra_sms_hashes_v1')!.toSet(),
      hashes.toSet());
    for (final k in prefs.getKeys()) {
      final value = prefs.get(k).toString();
      expect(value.contains(first), isFalse, reason: 'leaked into $k');
      expect(value.contains(second), isFalse, reason: 'leaked into $k');
    }

    expect(await service.readProtectedOriginalSms('expense-one'), first);
    expect(await service.readProtectedOriginalSms('income-one'), second);
    expect(await service.readProtectedOriginalSms('not-a-real-entry'), isNull);

    // readProtectedOriginalSms opens a NEW SQLCipher connection after the
    // first stage closed the writer, independently checks note fingerprint.
    final bytes = await File(
      '${directory.path}/${WaffraEncryptedSmsNotesVault.filename}',
    ).readAsBytes();
    for (final sms in [first, second]) {
      expect(String.fromCharCodes(bytes).contains(sms), isFalse);
    }
    expect(String.fromCharCodes(bytes).contains('SQLite format 3'), isFalse);
  });

  test('M226 duplicate skipped under finance lock never stages orphan SMS',
      () async {
    const original = 'شراء تجريبي\\n125.50 SAR\\nREF: SAME-001';
    final hash = WaffraEncryptedSmsNotesVault.fingerprint(original);
    final service = authority(protectedVault());
    final first = await service.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [record('first-unique-id', original)], hashes: [hash],
      userConfirmed: true,
    );
    expect(first.saved, 1);
    final repeated = await service.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [record('second-unused-id', original)], hashes: [hash],
      userConfirmed: true,
    );
    expect(repeated.saved, 0);
    expect(repeated.skippedDuplicates, 1);
    expect(await protectedVault().readVerifiedEntry('first-unique-id'), original);
    expect(await protectedVault().readVerifiedEntry('second-unused-id'), isNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect((jsonDecode(prefs.getString('entries')!) as List).length, 1);
  });

  test('M226 secure-key error aborts BEFORE the legacy finance journal writes',
      () async {
    const original = 'Debit SMS\nAmount: 125.50 SAR\nREF: TEST-001';
    final store = protectedVault(failKeyWrite: true);
    await expectLater(
      authority(store).commitConfirmedSms(
        route: WaffraFinanceRoute.widgetSmsConfirmedSave,
        records: [record('not-committed', original)],
        hashes: [WaffraEncryptedSmsNotesVault.fingerprint(original)],
        userConfirmed: true,
      ),
      throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    await p.reload();
    expect(p.getString('entries'), '[]');
    expect(p.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(wrappedKey, isNull);
  });

  test('M226 tampered bank hash rejects entire amount batch before any'
      ' plaintext, finance or protected-note commit', () async {
    const original = 'Deposit\n600 SAR\nSender: TEST';
    await expectLater(
      authority(protectedVault()).commitConfirmedSms(
        route: WaffraFinanceRoute.bulkSmsConfirmedSave,
        records: [record('tampered', original, income: true)],
        hashes: [List.filled(64, '0').join()],
        userConfirmed: true,
      ),
      throwsStateError,
    );
    final p = await SharedPreferences.getInstance();
    await p.reload();
    expect(p.getString('entries'), '[]');
    expect(p.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(wrappedKey, isNull);
  });
}
