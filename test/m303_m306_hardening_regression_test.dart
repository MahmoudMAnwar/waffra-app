import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_authoritative_widget_balance.dart';
import 'package:waffra/waffra_receipt_filename.dart';
import 'package:waffra/waffra_recurring_policy.dart';
import 'package:waffra/waffra_secure_backup.dart';

/// M303-M306: focused protections of live routes plus synthetic acceptance
/// fixtures. Source checks alone are NOT a physical-phone or runtime cutover
/// certification; the existing M280 SQLCipher and M277 UI suites run in CI.
void main() {
  final mainSource = File('lib/main.dart').readAsStringSync();

  String method(String opening, String endMarker) {
    final start = mainSource.indexOf(opening);
    final end = mainSource.indexOf(endMarker, start + opening.length);
    expect(start, greaterThanOrEqualTo(0),
        reason: 'Expected production route not found: $opening');
    expect(end, greaterThan(start));
    return mainSource.substring(start, end);
  }

  test('01 rapid manual confirmation is synchronously single-submit', () {
    final route = method(
      'Future<void> entrySheet(', 'Future<String?> chooseTransactionCategory(');
    expect(route, contains('if(submitTapped)return'));
    expect(route, contains('submitTapped=true'));
    expect(route, contains('commitConfirmedSms('));
  });

  test('02 locked finance persistence stays source-authoritative', () {
    final route = method('Future<void> persist(', 'Future<bool> _persistModuleOrReload(');
    expect(route, contains('_financialWriteQueue.submit('));
    expect(route, contains('_financeAuthority.saveCaptured('));
    expect(route, contains('baseline:baseline'));
  });

  test('03 corrupted encrypted backup header is refused', () {
    const invalid = '{"format":"waffra-secure-backup","version":2,'
        '"kdf":"argon2id","cipher":"aes-256-gcm","salt":"",'
        '"nonce":"","data":"AA==","mac":""}';
    expect(WaffraSecureBackup.hasValidEncryptedHeader(invalid), isFalse);
  });

  test('04 account logout must not silently destroy a finance source', () {
    final source = File('lib/storage/waffra_live_account_write_authority.dart')
        .readAsStringSync();
    final signOut = source.substring(source.indexOf('Future<void> signOut()'));
    expect(signOut, contains("remove('waffra_profile')"));
    expect(signOut, contains('waffra_signed_out_explicitly'));
    expect(signOut, isNot(contains("remove('entries')")));
    // Account A -> B isolation must still pass separate identity/device tests.
  });

  test('05 fractional halalah must not be rounded into widget balance', () {
    String ledger(num amount) => jsonEncode([{
      'id': 'synthetic-1', 'income': false, 'amount': amount,
    }]);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(ledger(1.25)), -125);
    expect(() => WaffraAuthoritativeWidgetBalance.netHalalas(ledger(1.005)),
        throwsStateError);
    expect(() => WaffraAuthoritativeWidgetBalance.netHalalas(ledger(0.001)),
        throwsStateError);
  });

  test('06 duplicate finance IDs refuse widget report as corrupted', () {
    final raw = jsonEncode([
      {'id': 'same', 'income': true, 'amount': 100.10},
      {'id': 'same', 'income': false, 'amount': 20},
    ]);
    expect(() => WaffraAuthoritativeWidgetBalance.netHalalas(raw),
        throwsStateError);
  });

  test('07 paid and postponed recurring writes reload on rejection', () {
    final route = method('Future<void> applyRecurring(', 'double sum(');
    expect(route, contains('userConfirmed:true'));
    expect(route, contains('await _loadFinanceSafely()'));
    expect(route, contains("operation:'recurring-postpone'"));
    expect(WaffraRecurringPolicy.entryId('rent', DateTime(2026, 10, 31)),
        WaffraRecurringPolicy.entryId('rent', DateTime(2026, 10, 1)));
  });

  test('08 receipt labels reject path traversal and control characters', () {
    expect(WaffraReceiptFilename.validateLabel('rent/../receipt'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('name\\receipt'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('a\u0000b'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('October rent'), isNull);
  });

  test('09 income minus expense is exact in widget and recurring policy', () {
    final raw = jsonEncode([
      {'id':'income','income':true,'amount':0.10},
      {'id':'income2','income':true,'amount':0.20},
      {'id':'expense','income':false,'amount':0.30},
    ]);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(raw), 0);
    expect(WaffraRecurringPolicy.netHalalas([0.10, 0.20], [0.30]), 0);
    expect(WaffraLegacyPreflight.canRepresentHalalas(0.001), isFalse);
  });

  test('10 rejected transaction delete, edit undo and budget save fail closed', () {
    final deletion = method('Future<void> deleteEntry(', 'Widget stat(');
    final budget = method('Future<void> editMonthlyBudget(', 'Future<void> editTransactionFilters(');
    final editor = method('Future<void> entrySheet(', 'Future<String?> chooseTransactionCategory(');
    expect(deletion, contains("operation:'transaction-delete'"));
    expect(deletion, contains("operation:'transaction-undo'"));
    expect(budget, contains("operation:'monthly-budget-save'"));
    expect(editor, contains("operation:'transaction-edit-undo'"));
  });

  test('11 smooth overlay has fail-safe completion and isolated repaints', () {
    final source = File('lib/waffra_smooth_confirmation.dart').readAsStringSync();
    expect(source, contains('finally {'));
    expect(source, contains('RepaintBoundary('));
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
  });

  test('12 OS permissions are requested on demand, not at startup', () {
    final reminders = method('Future<void> toggleRecurringReminders(',
        'Future<void> applyRecurring(');
    final editor = method('Future<void> entrySheet(',
        'Future<String?> chooseTransactionCategory(');
    expect(reminders, contains('WaffraReminders.requestPermission()'));
    expect(editor, contains('source:ImageSource.camera'));
    expect(editor, contains('pickMultiImage('));
  });
}
