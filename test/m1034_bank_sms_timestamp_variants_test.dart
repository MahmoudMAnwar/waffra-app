import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show bankSmsDate, bankSmsHasUnverifiedTimestamp;

void main() {
  final expected = DateTime(2026, 11, 15, 10, 14);

  test('M1034 screenshot: date-first AlinmaPay timestamp is verified', () {
    const sms = 'حوالة داخلية صادرة\n'
        'مبلغ: SAR 60.00\n'
        'حساب:**8647\n'
        'الرقم المرجعي: FT26319QPRW3\n'
        'في:15-11-2026 10:14';
    expect(bankSmsDate(sms), expected);
    expect(bankSmsHasUnverifiedTimestamp(sms), isFalse);
  });

  test('M1034 Android bidi isolates and nonbreaking spaces do not hide date', () {
    const sms = 'مبلغ: SAR 60.00\n'
        '\u200fفي:\u206715\u200e-11-2026\u2069\u202f10:14\u200f';
    expect(bankSmsDate(sms), expected);
    expect(bankSmsHasUnverifiedTimestamp(sms), isFalse);
  });

  test('M1034 Arabic and Persian digits are normalized', () {
    const arabic = 'في:١٥-١١-٢٠٢٦ ١٠:١٤';
    const persian = 'في:۱۵-۱۱-۲۰۲۶ ۱۰:۱۴';
    expect(bankSmsDate(arabic), expected);
    expect(bankSmsDate(persian), expected);
    expect(bankSmsHasUnverifiedTimestamp(arabic), isFalse);
  });

  test('M1034 date and labeled time may occupy adjacent SMS lines', () {
    const sms = 'حوالة صادرة\nفي:15-11-2026\r\nالوقت:10:14';
    expect(bankSmsDate(sms), expected);
    expect(bankSmsHasUnverifiedTimestamp(sms), isFalse);
    expect(bankSmsDate('Date: 15/11/2026\ntime: 10:14'), expected);
  });

  test('M1034 time-first with labeled full-year date is verified', () {
    const sms = 'حوالة صادرة\nالوقت:10:14\nالتاريخ:15-11-2026';
    expect(bankSmsDate(sms), expected);
    expect(bankSmsHasUnverifiedTimestamp(sms), isFalse);
  });

  test('M1034 supports dot separators and ISO T with seconds', () {
    expect(bankSmsDate('في:15.11.2026 10:14'), expected);
    expect(bankSmsDate('at 2026-11-15T10:14:35'),
        DateTime(2026, 11, 15, 10, 14, 35));
    expect(bankSmsHasUnverifiedTimestamp('at 2026-11-15T10:14:35'), isFalse);
  });

  test('M1034 never accepts impossible or malformed source timestamps', () {
    for (final sms in <String>[
      'في:31-02-2026 10:14',
      'في:15-11-2026 25:14',
      'في:15-11-2026 10:60',
      'at 2026-11-15T10:14:99',
    ]) {
      expect(bankSmsDate(sms), isNull, reason: sms);
      expect(bankSmsHasUnverifiedTimestamp(sms), isTrue, reason: sms);
    }
  });

  test('M1034 cannot fabricate a date from receipt time or ambiguous YY', () {
    expect(bankSmsDate('حوالة صادرة\nمبلغ: SAR 60.00'), isNull);
    expect(bankSmsHasUnverifiedTimestamp('حوالة صادرة\nمبلغ: SAR 60.00'),
        isFalse);
    expect(bankSmsDate('حوالة صادرة 26/10/25 12:34',
        referenceDate: DateTime(2026, 10, 31)), isNull);
    expect(bankSmsHasUnverifiedTimestamp('حوالة صادرة 26/10/25 12:34',
        referenceDate: DateTime(2026, 10, 31)), isTrue);
  });

  test('M1034 review and editor retain the same verified SMS extractor', () {
    final review = File('lib/waffra_home_sms_confirmation.part.dart')
        .readAsStringSync();
    final editor = File('lib/waffra_home_entry_sheet.part.dart')
        .readAsStringSync();
    expect(review, contains('final originalDate=bankSmsDate(body);'));
    expect(review, contains('bankSmsHasUnverifiedTimestamp(body)'));
    expect(editor, contains('bankSmsHasUnverifiedTimestamp(manualReviewBody)'));
    expect(editor, contains('bankSmsDate(manualReviewBody,'));
  });
}
