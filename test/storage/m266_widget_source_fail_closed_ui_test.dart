import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

/// M266: real widget UI regression with disposable storage. A green result
/// establishes fail-closed UI behavior, not production SQLCipher activation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openWidget(
    WidgetTester tester, {
    required Directory directory,
    required Future<void> Function() sourceProbe,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(WaffraWidgetCaptureApp(
      testWriterDirectory: directory,
      testBypassNativeLock: true,
      testSourceProbe: sourceProbe,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('failed source verification hides SMS input and leaves ledger intact',
      (tester) async {
    const original = '[{"id":"synthetic-previous","amount":25}]';
    SharedPreferences.setMockInitialValues({
      'entries': original,
      'waffra_language': 'ar',
      'waffra_sms_hashes_v1': <String>['original-hash'],
    });
    final folder = Directory.systemTemp.createTempSync('waffra-m266-fail-');
    addTearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });
    await openWidget(tester, directory: folder, sourceProbe: () async {
      throw StateError('disposable source check failed');
    });
    expect(find.textContaining('تعذر فتح البيانات المحلية'), findsOneWidget);
    expect(find.byKey(const Key('waffra-widget-bank-message')), findsNothing);
    expect(find.text('تأكيد إضافة العمليات'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), original);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['original-hash']);
  });

  testWidgets('pending cutover refuses widget capture before user confirms',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"synthetic-ledger"}]',
      WaffraLiveLegacyFinanceGuard.pendingKey: true,
      'waffra_language': 'ar',
    });
    final folder = Directory.systemTemp.createTempSync('waffra-m266-pending-');
    addTearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });
    // A harmless test probe does not bypass the guarded legacy coordinator.
    await openWidget(tester, directory: folder, sourceProbe: () async {});
    expect(find.textContaining('تعذر فتح البيانات المحلية'), findsOneWidget);
    expect(find.byKey(const Key('waffra-widget-bank-message')), findsNothing);
    expect(find.text('تأكيد إضافة العمليات'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[{"id":"synthetic-ledger"}]');
    expect(prefs.getBool(WaffraLiveLegacyFinanceGuard.pendingKey), isTrue);
  });

  test('production widget authority is never a pre-bind legacy fallback', () {
    final source = File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    expect(source, contains("throw StateError('Widget finance source has not been verified.')"));
    expect(source, contains('if(widget.testSourceProbe!=null){'));
    expect(source, contains('if(!_sourceReady||_saving||_analyzing||_selected.isEmpty)return;'));
    expect(source, isNot(contains('_financeBinding?.authority??')));
  });
}
