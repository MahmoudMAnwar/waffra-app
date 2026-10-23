import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build is labeled in app and signed APK archive name is unique', () {
    final app=File('lib/main.dart').readAsStringSync();
    final ci=File('.github/workflows/android.yml').readAsStringSync();
    expect(app,contains("String.fromEnvironment("));
    expect(app,contains("'WAFFRA_BUILD_STAMP'"));
    expect(app,contains('رقم البيلد: '));
    expect(app,contains('applicationVersion:waffraBuildStamp'));
    expect(ci,contains('--dart-define="WAFFRA_BUILD_STAMP=Run-'));
    expect(ci,contains('Waffra-Run-'));
    expect(ci,contains('BUILD-INFO.txt'));
    expect(ci,contains('sha256sum'));
  });

  test('PIN has only digits on a built-in pad, without a system keyboard', () {
    final app=File('lib/main.dart').readAsStringSync();
    final a=app.indexOf(' Future<String?> _askForPin(');
    final b=app.indexOf(' Future<void> configurePin()',a);
    expect(a,greaterThanOrEqualTo(0));
    expect(b,greaterThan(a));
    final pin=app.substring(a,b);
    expect(pin,contains("Key('waffra-pin-input')"));
    expect(pin,contains('readOnly:true,showCursor:false'));
    expect(pin,contains('enableInteractiveSelection:false'));
    expect(pin,contains('waffra-pin-key-'));
    expect(pin,contains("'1','2','3'"));
    expect(pin,contains('FilteringTextInputFormatter.digitsOnly'));
    expect(pin,contains('if(autoAdvance&&value.length==4'));
    expect(pin,contains('if(!autoAdvance)FilledButton('));
    expect(pin,contains("waffraIsEnglish?'Cancel':'إلغاء'"));
  });

  test('No regression of approved red trash, file backup or category hierarchy', () {
    final app=File('lib/main.dart').readAsStringSync();
    final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
    final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    expect(app,contains('class WaffraDeletedItemsButton extends StatelessWidget'));
    expect(app,contains('const Color(0xFFB42332)'));
    expect(categories,contains('WaffraDeletedItemsButton('));
    expect(app,contains('الأهداف المحذوفة ('));
    expect(app,contains('العمليات المتكررة المحذوفة ('));
    expect(app,contains('onPressed:showWaffraFinancialCalendar'));
    expect(app,contains('WaffraBackupFiles.saveEncryptedArchive(encrypted)'));
    expect(app,contains('waffraCanAssignManualCategory(categories,'));
    expect(widget,isNot(contains('trailing:record.duplicate?const Icon(Icons.copy')));
  });
}
