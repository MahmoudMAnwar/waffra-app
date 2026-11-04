import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 final reference=DateTime(2026,10,31);
 test('M337 transfer year-first only when independently unambiguous',(){
  expect(bankSmsDate('حوالة واردة 26/10/17 12:34',
    referenceDate:reference),DateTime(2026,10,17,12,34));
  expect(bankSmsDate('حوالة صادرة 30/10/26 23:49',
    referenceDate:reference),DateTime(2026,10,30,23,49));
  expect(bankSmsDate('شراء POS 30/10/26 23:49',
    referenceDate:reference),DateTime(2026,10,30,23,49));
  expect(bankSmsDate('Credit Transfer 2026-10-22 23:39',
    referenceDate:reference),DateTime(2026,10,22,23,39));
 });
 test('M337 ambiguous or malformed source dates cannot auto-post as today',(){
  expect(bankSmsDate('حوالة واردة 26/10/25 12:34',
    referenceDate:reference),isNull);
  expect(bankSmsHasUnverifiedTimestamp('حوالة واردة 26/10/25 12:34',
    referenceDate:reference),isTrue);
  expect(bankSmsHasUnverifiedTimestamp('حوالة واردة 2026-02-30 12:34',
    referenceDate:reference),isTrue);
  expect(bankSmsHasUnverifiedTimestamp('حوالة واردة 26/10/17 12:34',
    referenceDate:reference),isFalse);
  expect(bankSmsHasUnverifiedTimestamp('شراء SAR 10\nبدون تاريخ',
    referenceDate:reference),isFalse);
 });
 test('M337 bulk date gate is before parsing, category assignment and commit',(){
  final main=File('lib/main.dart').readAsStringSync();
  final from=main.indexOf('Future<void> saveParsedMessages(');
  final end=main.indexOf('Future<void> prepare(',from);
  final section=from>=0?main.substring(from):
    main.substring(main.indexOf('Future<void> bulkSmsSheet('));
  final date=section.indexOf('found.where(bankSmsHasUnverifiedTimestamp)');
  final commit=section.indexOf('_financeAuthority.commitConfirmedSms(');
  expect(date,greaterThan(0));
  expect(commit,greaterThan(date));
  expect(section,contains('لم تُحفظ معاملات'));
 });
}
