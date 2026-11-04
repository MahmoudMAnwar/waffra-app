import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M270: native launcher widget uses the same user-approved Riyal PNG',
      () {
    expect(File('assets/Saudi_Riyal_Symbol-1.png').existsSync(), isTrue);
    final source = File('native/WaffraWidget.kt').readAsStringSync();
    expect(source, contains('currency.trim() == "ريال"'));
    expect(source, contains('!hidden && currency.trim()'));
    expect(source, contains('R.id.widget_riyal_icon'));
    expect(source, contains('R.id.widget_currency'));
    expect(source, contains('if (showArabicRiyal) View.VISIBLE else View.GONE'));
    expect(source, contains('if (showArabicRiyal) View.GONE else View.VISIBLE'));

    for (final workflow in [
      '.github/workflows/android.yml',
      '.github/workflows/android-full-smoke.yml',
    ]) {
      final android = File(workflow).readAsStringSync();
      expect(android, contains('android:id="@+id/widget_riyal_icon"'),
          reason: workflow);
      expect(android, contains('@drawable/waffra_sar_symbol'),
          reason: workflow);
      expect(android, contains("riyal=Path('assets/Saudi_Riyal_Symbol-1.png')"),
          reason: workflow);
      expect(android, contains('symbol.write_bytes(riyal.read_bytes())'),
          reason: workflow);
    }
  });
}
