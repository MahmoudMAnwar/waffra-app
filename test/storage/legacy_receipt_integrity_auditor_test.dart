import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_receipt_integrity_auditor.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory receiptsDir;

  WaffraLegacyReceiptIntegrityAuditor auditor({
    bool enabled = true,
    List<Directory>? roots,
  }) => WaffraLegacyReceiptIntegrityAuditor(
    coordinator: WaffraLegacyFinanceWriterCoordinator(testDirectory: root),
    trustedRoots: roots ?? [receiptsDir],
    experimentalEnabled: enabled,
  );

  String financeWithReceipts(List<String> receiptPaths) => jsonEncode([
    {
      'id': 'receipt-transaction',
      'title': 'شراء',
      'category': 'مشتريات',
      'amount': 45,
      'income': false,
      'date': '2026-10-21T17:00:00',
      'receiptPath': receiptPaths.length == 1
          ? receiptPaths.single
          : receiptPaths.isEmpty
              ? null
              : jsonEncode(receiptPaths),
    },
  ]);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('waffra-receipt-audit-');
    receiptsDir = await Directory('${root.path}/private-receipts').create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('no receipt references returns empty verified read-only report',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([]),
    });
    final result = await auditor().audit();
    expect(result.referenceCount, 0);
    expect(result.totalBytes, 0);
    expect(result.receipts, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), financeWithReceipts([]));
  });

  test('single file returns correct SHA-256 and preserves source bytes',
      () async {
    final receipt = File('${receiptsDir.path}/old-receipt.png');
    await receipt.writeAsBytes([1, 15, 25, 35, 45], flush: true);
    final old = financeWithReceipts([receipt.path]);
    SharedPreferences.setMockInitialValues({
      'entries': old,
      'waffra_goals_v24': '[]',
    });
    final report = await auditor().audit();
    expect(report.referenceCount, 1);
    expect(report.totalBytes, 5);
    expect(report.receipts.single.transactionId, 'receipt-transaction');
    expect(report.receipts.single.byteLength, 5);
    expect(report.receipts.single.sha256Hex,
        sha256.convert([1, 15, 25, 35, 45]).toString());
    expect(await receipt.readAsBytes(), [1, 15, 25, 35, 45]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), old);
    expect(prefs.getString('waffra_goals_v24'), '[]');
  });

  test('receipt lists audit every reference without dropping images',
      () async {
    final first = File('${receiptsDir.path}/first.jpg');
    final second = File('${receiptsDir.path}/second.jpg');
    await first.writeAsBytes([10, 20], flush: true);
    await second.writeAsBytes([30, 40, 50], flush: true);
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([first.path, second.path]),
    });
    final report = await auditor().audit();
    expect(report.referenceCount, 2);
    expect(report.totalBytes, 5);
    expect(report.receipts.map((r) => r.sha256Hex).toSet(), {
      sha256.convert([10, 20]).toString(),
      sha256.convert([30, 40, 50]).toString(),
    });
  });

  test('missing receipt blocks claiming migration is ready', () async {
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts(
        ['${receiptsDir.path}/missing.jpg'],
      ),
    });
    await expectLater(auditor().audit(), throwsA(isA<StateError>()));
  });

  test('untrusted existing receipt outside app folder is rejected',
      () async {
    final outside = File('${root.path}/outside.jpg');
    await outside.writeAsBytes([1, 2, 3]);
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([outside.path]),
    });
    await expectLater(auditor().audit(), throwsA(isA<StateError>()));
    expect(await outside.readAsBytes(), [1, 2, 3]);
  });

  test('empty receipt bytes are not accepted as a valid copy', () async {
    final empty = File('${receiptsDir.path}/empty.jpg');
    await empty.writeAsBytes([]);
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([empty.path]),
    });
    await expectLater(auditor().audit(), throwsA(isA<StateError>()));
  });

  test('malformed legacy finance blocks receipt inspection', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"invalid","amount":1.005}]',
    });
    await expectLater(auditor().audit(), throwsA(isA<StateError>()));
  });

  test('unknown activation marker blocks old receipt read', () async {
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([]),
      WaffraLiveLegacyFinanceGuard.pendingKey: true,
    });
    await expectLater(auditor().audit(), throwsA(isA<StateError>()));
  });

  test('feature is off unless explicitly enabled', () async {
    SharedPreferences.setMockInitialValues({
      'entries': financeWithReceipts([]),
    });
    await expectLater(
      auditor(enabled: false).audit(),
      throwsA(isA<StateError>()),
    );
  });
}
