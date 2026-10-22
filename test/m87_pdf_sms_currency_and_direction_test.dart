import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_pdf_text.dart';

/// M87 PDF text presentation tests; financial source text is never mutated.
void main() {
  test('M87 old/new Saudi currency glyphs do not print as broken squares',
      () {
    const raw = 'شراء PoS \uFDFC 84.72 \u20C1 16.50';
    final cleaned = sanitizeWaffraPdfText(raw);
    expect(cleaned, contains('شراء'));
    expect(cleaned, contains('PoS'));
    expect(cleaned, contains('ريال'));
    expect(cleaned, isNot(contains('\uFDFC')));
    expect(cleaned, isNot(contains('\u20C1')));
    expect(cleaned, isNot(contains('\uFFFD')));
  });

  test('M87 invisible RTL overrides and unsupported emoji cannot corrupt PDF',
      () {
    const raw = 'حوالة واردة \u202E 150 SAR 👍';
    final cleaned = sanitizeWaffraPdfText(raw);
    expect(cleaned, contains('حوالة واردة'));
    expect(cleaned, contains('150 SAR'));
    expect(cleaned, isNot(contains('\u202E')));
    expect(cleaned, isNot(contains('👍')));
    expect(cleaned, isNot(contains('\uFFFD')));
  });

  test('M87 mixed Saudi Arabic POS description retains separate Latin runs',
      () {
    const message = 'شراء نقاط بيع PoS مدى SAR 74.50';
    final parts = splitWaffraPdfText(message);
    expect(parts.first.rtl, isTrue);
    expect(parts.any((p) => !p.rtl && p.text.contains('PoS')), isTrue);
    expect(parts.any((p) => p.rtl && p.text.contains('مدى')), isTrue);
    expect(parts.any((p) => !p.rtl && p.text.contains('74.50')), isTrue);
  });

  test('M87 an empty transaction description renders safely', () {
    final segments = splitWaffraPdfText('');
    expect(segments, hasLength(1));
    expect(segments.single.text, 'لا يوجد وصف');
    expect(segments.single.rtl, isTrue);
  });
}
