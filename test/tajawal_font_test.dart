import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tajawal regular, medium and bold fonts are bundled offline', () async {
    for (final filename in [
      'Tajawal-Regular.ttf',
      'Tajawal-Medium.ttf',
      'Tajawal-Bold.ttf',
    ]) {
      final bytes = await rootBundle.load('assets/fonts/$filename');
      expect(bytes.lengthInBytes, greaterThan(20000),
          reason: 'Missing or invalid bundled font: $filename');
    }
  });
}
