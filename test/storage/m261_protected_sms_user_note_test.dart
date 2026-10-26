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

class _SafeLegacy extends WaffraProductionFinanceSourceGuard {
  const _SafeLegacy();
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
        source: WaffraProductionFinanceSource.guardedLegacy,
        reasonCode: 'synthetic_m261_only',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  String? wrappedKey;

  WaffraVerifiedFinanceAuthority service() {
    final vault = WaffraEncryptedSmsNotesVault(
      directoryProvider: () async => sandbox,
      keyReader: () async => wrappedKey,
      keyWriter: (key) async => wrappedKey = key,
    );
    return WaffraVerifiedFinanceAuthority(
      sourceGuard: const _SafeLegacy(),
      protectedSmsNotes: vault,
      legacy: WaffraHomeFinancePersistence(
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: sandbox,
          sourceProbe: (_) async {},
        ),
      ),
    );
  }

  Map<String, Object?> sms(String id, String original) => {
        'id': id,
        'title': 'شراء تجريبي',
        'category': 'أخرى',
        'amount': 84.72,
        'income': false,
        'date': '2026-10-26T13:00:00.000Z',
        'receiptPath': null,
        'notes': original,
        'sourceType': 'sms',
        'merchantKey': '',
      };

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m261-notes-');
    wrappedKey = null;
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>[],
    });
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('bank original and edited user note survive SQLCipher cold reopen'
      ' without plaintext legacy leakage', () async {
    const original = 'شراء PoS\nبـ84.72SAR\nلـمتجر تجريبي';
    const customNote = 'المعاملة دي اختبار\nتعليق خاص من المستخدم';
    final first = service();
    final saved = await first.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms('entry-1', original)],
      hashes: [WaffraEncryptedSmsNotesVault.fingerprint(original)],
      userConfirmed: true,
    );
    expect(saved.saved, 1);
    expect(await first.readProtectedOriginalSms('entry-1'), original);
    expect(await first.readProtectedSmsUserNote('entry-1'), '');
    await first.updateProtectedSmsUserNote(
      entryId: 'entry-1', expectedNote: '', nextNote: customNote,
    );
    // Fresh authority means a new native SQLCipher open, not a cached UI.
    final reopened = service();
    expect(await reopened.readProtectedOriginalSms('entry-1'), original);
    expect(await reopened.readProtectedSmsUserNote('entry-1'), customNote);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final savedLedger = jsonDecode(prefs.getString('entries')!) as List;
    expect(savedLedger.length, 1);
    expect((savedLedger.single as Map)['notes'], '');
    for (final key in prefs.getKeys()) {
      final text = prefs.get(key).toString();
      expect(text.contains(original), isFalse, reason: 'raw SMS in $key');
      expect(text.contains(customNote), isFalse, reason: 'annotation in $key');
    }
    final rawBytes = await File(
      '${sandbox.path}/${WaffraEncryptedSmsNotesVault.filename}',
    ).readAsBytes();
    final databaseBytes = String.fromCharCodes(rawBytes);
    expect(databaseBytes.contains(original), isFalse);
    expect(databaseBytes.contains(customNote), isFalse);
    expect(databaseBytes.contains('SQLite format 3'), isFalse);
  });

  test('stale note writes fail closed without changing protected original',
      () async {
    const original = 'حوالة واردة\n225 SAR\nتجربة';
    final auth = service();
    await auth.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms('entry-2', original)],
      hashes: [WaffraEncryptedSmsNotesVault.fingerprint(original)],
      userConfirmed: true,
    );
    await auth.updateProtectedSmsUserNote(
      entryId: 'entry-2', expectedNote: '', nextNote: 'أ',
    );
    await expectLater(
      auth.updateProtectedSmsUserNote(
        entryId: 'entry-2', expectedNote: '', nextNote: 'تعديل قديم',
      ),
      throwsStateError,
    );
    expect(await auth.readProtectedSmsUserNote('entry-2'), 'أ');
    expect(await auth.readProtectedOriginalSms('entry-2'), original);
    await auth.updateProtectedSmsUserNote(
      entryId: 'entry-2', expectedNote: 'أ', nextNote: '',
    );
    expect(await auth.readProtectedSmsUserNote('entry-2'), '');
    expect(await auth.readProtectedOriginalSms('entry-2'), original);
  });

  test('unsaved or missing SMS IDs, oversized notes and source downgrade'
      ' cannot write an encrypted annotation', () async {
    final auth = service();
    await expectLater(
      auth.updateProtectedSmsUserNote(
        entryId: 'uncommitted', expectedNote: '', nextNote: 'تحايل',
      ),
      throwsStateError,
    );
    expect(await auth.readProtectedSmsUserNote('uncommitted'), isNull);

    const original = 'شراء\n2 SAR\nتجربة';
    await auth.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms('entry-3', original)],
      hashes: [WaffraEncryptedSmsNotesVault.fingerprint(original)],
      userConfirmed: true,
    );
    await expectLater(
      auth.updateProtectedSmsUserNote(
        entryId: 'entry-3', expectedNote: '',
        nextNote: List.filled(2001, 'x').join(),
      ),
      throwsArgumentError,
    );
    expect(await auth.readProtectedSmsUserNote('entry-3'), '');
    expect(await auth.readProtectedOriginalSms('entry-3'), original);
  });

  test('unrelated financial edit may not copy user annotations to notes',
      () async {
    const original = 'شراء عبر نقاط بيع\n84.72 SAR';
    final auth = service();
    await auth.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms('entry-4', original)],
      hashes: [WaffraEncryptedSmsNotesVault.fingerprint(original)],
      userConfirmed: true,
    );
    await auth.updateProtectedSmsUserNote(
      entryId: 'entry-4', expectedNote: '', nextNote: 'س',
    );
    final baseline = await auth.load(route: WaffraFinanceRoute.dashboardRead);
    final ledger = jsonDecode(baseline.ledgerRaw!) as List;
    final changed = Map<String, Object?>.from(ledger.single as Map);
    changed['title'] = 'عنوان جديد';
    // Editing description or category must keep financial SMS notes redacted.
    changed['notes'] = '';
    await auth.saveCaptured(
      route: WaffraFinanceRoute.transactionEdit,
      baseline: baseline,
      captured: {'entries': jsonEncode([changed])},
    );
    final again = await auth.load(route: WaffraFinanceRoute.dashboardRead);
    final row = (jsonDecode(again.ledgerRaw!) as List).single as Map;
    expect(row['title'], 'عنوان جديد');
    expect(row['notes'], '');
    expect(await auth.readProtectedOriginalSms('entry-4'), original);
    expect(await auth.readProtectedSmsUserNote('entry-4'), 'س');
  });
}
