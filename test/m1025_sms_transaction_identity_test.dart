import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main(){
 final one=List.filled(64,'a').join(),two=List.filled(64,'b').join();
 const message='شراء ببطاقة مدى 85 SAR بتاريخ 16/11/2026 11:30';
 test('M1025 exact Android SMS id is replay-safe, separate IDs remain distinct',(){
  final first=bankSmsHash(message,nativeId:one);
  final same=bankSmsHash(message,nativeId:one);
  final second=bankSmsHash(message,nativeId:two);
  expect(first,same);
  expect(first,isNot(second));
  expect(first,isNot(bankSmsHash(message)));
  expect(first.length,64);
 });
 test('M1025 original body hash remains unchanged for old backups',(){
  expect(bankSmsHash(message),bankSmsHash(message));
  expect(bankSmsHash(message),isNot(bankSmsHash(message,nativeId:one)));
  expect(()=>bankSmsHash(message,nativeId:'invalid'),throwsFormatException);
 });
 test('M1025 old body-hash collision never silently auto ACKs new native candidate',(){
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(worker,contains('bankSmsHash(body,nativeId:id)'));
  expect(worker,contains('if(finalHashesLegacy.contains(bankSmsHash(body)))'));
  expect(worker,contains('await keepForReview(candidate);continue;'));
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('if(hashes.contains(bankSmsHash(body,nativeId:id)))'));
  expect(main,contains("'possibleLegacyDuplicate'"));
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(review,contains('bankSmsHash(body,nativeId:id)'));
  expect(review,contains('reviewedSmsId:id'));
  final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  expect(editor,contains('String? reviewedSmsId'));
  expect(editor,contains('bankSmsHash(message.text,nativeId:reviewedSmsId)'));
 });
}
