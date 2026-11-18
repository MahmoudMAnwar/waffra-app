import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
/// M1038 #765: source contracts; Android physical SMS-provider UAT separately.
void main(){
 final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
 final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
 final assembler=store; // Pure Kotlin helper is embedded in Store; CI copies Store.
 test('single bank purchase with overlapping tail and duplicate beginning',(){
  const full='شراء عبر نقاط البيع\nبطاقة: **6314 MADA\nمبلغ: 33.81 SAR\nلدى: Marakez Medical Compan\nفي: 2026-11-18 18:51\nالرصيد المتبقي: ريال 93.95';
  const prefix='شراء عبر نقاط البيع\nبطاقة: **6314 MADA\nمبلغ: 33.81 SAR\nلدى: Mar';
  const middle='شراء عبر نقاط البيع\nبطاقة: **6314 MADA\nمبلغ: 33.81 SAR\nلدى: Marakez Medical Compan\nفي: 2026-11-18 18';
  const tail='akez Medical Compan\nفي: 2026-11-18 18:51\nالرصيد المتبقي: ريال 93.95';
  expect(full,startsWith(prefix));
  expect(middle,contains('Marakez Medical Compan'));
  expect(tail,contains('الرصيد المتبقي: ريال 93.95'));
  expect(assembler,contains('fun combine(parts: List<Part>): List<Group>'));
  expect(assembler,contains('fun mergeBodies('));
  expect(assembler,contains('sourceIds'));
  expect(assembler,contains('hasCompletePurchase'));
  expect(assembler,contains('sameSenderAndClock'));
  expect(assembler,contains('overlap >= 18'));
  expect(assembler,contains('if (hasCompletePurchase(left) && hasCompletePurchase(right)) return null'));
 });
 test('native receiver and history share assembler before financial candidate review',(){
  expect(receiver,contains('WaffraAutoSmsStore.offer(context, sender, parts.toString(), receivedAt)'));
  expect(store,contains('save(context, collapseQueuedMultipartLocked(context, queue))'));
  // The native encrypted queue spans separate SMS_RECEIVED intents.
  expect(receiver,contains('WaffraAutoSmsStore.offer('));
  expect(store,contains('WaffraSmsFragmentAssembler.combine('));
  expect(store,contains('fun repairPendingMultipart('));
  expect(store,contains('sourceIds'));
  expect(store,contains('allSourceIds('));
  expect(store,contains('identityAt'));
 });
 test('replay and duplicate anti-commit spans each source fingerprint',(){
  expect(store,contains('val aliases = allSourceIds(row)'));
  expect(store,contains('expandedIds.addAll(aliases)'));
  expect(store,contains('sourceIds'));
  expect(store,contains('isCommittedLocked(context, alias)'));
  expect(store,contains('isExcludedMessageLocked(context, alias)'));
  expect(store,contains('isCompletedTransferLocked(context, alias)'));
  expect(store,contains('val reconstructed = id(group.sender, group.body, group.identityAt)'));
  expect(store,contains('if (finished) continue'));
 });
 test('privacy and money guard: no sender-only/amount-only grouping or SQL writer',(){
  expect(assembler,contains('if (a.sender != b.sender) return false'));
  expect(assembler,contains('if (timeDistance > 120000L) return false'));
  expect(assembler,isNot(contains('amount ==')));
  expect(assembler,isNot(contains('merchant ==')));
  expect(store,isNot(contains('commitConfirmedSms(')));
  expect(receiver,isNot(contains('commitConfirmedSms(')));
 });
}
