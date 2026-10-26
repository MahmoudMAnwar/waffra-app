import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M239 standalone widget refuses malformed persisted finance '
      'without displaying a fake balance or allowing an SMS save', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': '{this-is-not-a-finance-ledger}',
      'waffra_sms_hashes_v1': <String>[],
      'waffra_language': 'ar',
    });
    final folder = Directory.systemTemp.createTempSync('waffra-m239-bad-finance-');
    addTearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });
    await tester.binding.setSurfaceSize(const Size(430, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(WaffraWidgetCaptureApp(
      testWriterDirectory: folder,
      testBypassNativeLock: true,
      testSourceProbe: () async {},
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر فتح البيانات المحلية'), findsOneWidget);
    expect(find.text('تأكيد إضافة العمليات'), findsNothing);
  });

  test('M239 production Widget independently validates both widgetRead '
      'snapshots before category selection and SMS commit', () {
    final code = File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    final startup = code.indexOf(' Future<void> _loadSettings()async{');
    final save = code.indexOf(' Future<void> _commitWidgetSms()async{');
    final endSave = code.indexOf(' @override void dispose()', save);
    expect(startup, greaterThan(0));
    expect(save, greaterThan(startup));
    expect(endSave, greaterThan(save));
    final opening = code.substring(startup, save);
    final committing = code.substring(save, endSave);
    expect(opening, contains('loaded.finance.requireIntegrity();'));
    expect(opening, contains('Encrypted widget ledger is missing.'));
    final initial = committing.indexOf('loaded.finance.requireIntegrity();');
    final switchGuard = committing.indexOf('_legacySource!=');
    final categories = committing.indexOf(
      "loaded.finance.getString('waffra_categories_v24')");
    final commit = committing.indexOf('_financeAuthority.commitConfirmedSms(');
    expect(initial, greaterThan(0));
    expect(switchGuard, greaterThan(initial));
    expect(categories, greaterThan(switchGuard));
    expect(commit, greaterThan(categories));
    expect(committing, contains('Encrypted widget ledger/category catalog is missing.'));
    expect(committing, contains('No verified encrypted category for this transaction.'));
    expect(committing, contains('Widget finance source changed; reload required.'));
    expect(committing, contains('route:WaffraFinanceRoute.widgetSmsConfirmedSave'));
    expect(committing, contains('route:WaffraFinanceRoute.widgetBalanceRefresh'));
  });
}
