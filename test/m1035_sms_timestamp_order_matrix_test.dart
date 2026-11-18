import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show bankSmsDate, bankSmsHasUnverifiedTimestamp;

/// M1035: owner-provided real banking templates, with personal names,
/// financial account suffixes and reference numbers anonymized.
void main() {
 final transfer = [
  'حوالة داخلية صادرة',
  'من: مرسل تجريبي',
  'مبلغ:SAR 1.00',
  'الى: مستفيد تجريبي',
  'حساب:**0000',
  'رسوم:0',
  'الرقم المرجعي: FT00000TEST',
  'في:15:08 2026-11-02',
 ].join('\n');
 final purchase = [
  'شراء عبر نقاط البيع',
  'بطاقة: **0000 MADA',
  'مبلغ: 75 SAR',
  'لدى: BK',
  'في: 2026-11-07 16:06',
  'الرصيد المتبقي: ريال 627.43',
 ].join('\n');

 test('M1035 original outgoing wallet SMS: HH:mm YYYY-MM-DD', () {
  expect(bankSmsDate(transfer), DateTime(2026, 11, 2, 15, 8));
  expect(bankSmsHasUnverifiedTimestamp(transfer), isFalse);
 });

 test('M1035 POS ISO date-first remains recognized', () {
  expect(bankSmsDate(purchase), DateTime(2026, 11, 7, 16, 6));
  expect(bankSmsHasUnverifiedTimestamp(purchase), isFalse);
 });

 test('M1035 all four full-year layouts and all date separators', () {
  final expected=DateTime(2026,11,2,15,8);
  for (final separator in ['-', '/', '.']) {
   final iso=['2026','11','02'].join(separator);
   final dmy=['02','11','2026'].join(separator);
   for (final stamp in [
    '$iso 15:08', '15:08 $iso',
    '$dmy 15:08', '15:08 $dmy',
   ]) {
    final sms='حوالة صادرة\nمبلغ SAR 1.00\nفي: $stamp';
    expect(bankSmsDate(sms),expected,reason:stamp);
    expect(bankSmsHasUnverifiedTimestamp(sms),isFalse,reason:stamp);
   }
  }
 });

 test('M1035 time-first year-first accepts seconds and normal whitespace', () {
  const sms='في: 15:08:49\n2026-11-02';
  expect(bankSmsDate(sms),DateTime(2026,11,2,15,8,49));
  expect(bankSmsHasUnverifiedTimestamp(sms),isFalse);
 });

 test('M1035 Arabic Persian digits and invisible Android text controls', () {
  for (final sms in [
   'في:١٥:٠٨ ٢٠٢٦-١١-٠٢',
   'في:۱۵:۰۸ ۲۰۲۶-۱۱-۰۲',
   'في:\u200f15:08\u2069\u202f2026-11-02\u200e',
  ]) {
   expect(bankSmsDate(sms),DateTime(2026,11,2,15,8),reason:sms);
   expect(bankSmsHasUnverifiedTimestamp(sms),isFalse,reason:sms);
  }
 });

 test('M1035 adjacent time and ISO date labels can be split', () {
  for (final sms in [
   'حوالة صادرة\nالوقت:15:08\nالتاريخ:2026-11-02',
   'Time: 15:08\nDate: 2026-11-02',
   'الساعة 15:08\nتاريخ 2026-11-02',
  ]) {
   expect(bankSmsDate(sms),DateTime(2026,11,2,15,8),reason:sms);
   expect(bankSmsHasUnverifiedTimestamp(sms),isFalse,reason:sms);
  }
 });

 test('M1035 malformed full-year time-first dates fail closed', () {
  for (final stamp in [
   '15:08 2026-02-30',
   '15:08 2027-02-29',
   '24:08 2026-11-02',
   '15:60 2026-11-02',
   '15:08:60 2026-11-02',
   '15:08 2026-13-02',
  ]) {
   final sms='حوالة صادرة\nفي:$stamp';
   expect(bankSmsDate(sms),isNull,reason:stamp);
   expect(bankSmsHasUnverifiedTimestamp(sms),isTrue,reason:stamp);
  }
 });

 test('M1035 preserve old ambiguous date and missing-date policy', () {
  const unknown='حوالة صادرة\nمبلغ SAR 1.00';
  expect(bankSmsDate(unknown),isNull);
  expect(bankSmsHasUnverifiedTimestamp(unknown),isFalse);
  const ambiguous='حوالة صادرة 26/10/25 12:34';
  final anchor=DateTime(2026,10,31);
  expect(bankSmsDate(ambiguous,referenceDate:anchor),isNull);
  expect(bankSmsHasUnverifiedTimestamp(ambiguous,referenceDate:anchor),isTrue);
 });

 test('M1035 review, editor and background use shared date verification', () {
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final background=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(review,contains('final originalDate=bankSmsDate(body);'));
  expect(review,contains('bankSmsHasUnverifiedTimestamp(body)'));
  expect(editor,contains('bankSmsDate(manualReviewBody,'));
  expect(background,contains('bankSmsDate(body,referenceDate:arrived)'));
  expect(background,contains('bankSmsHasUnverifiedTimestamp(body,referenceDate:'));
 });
}
