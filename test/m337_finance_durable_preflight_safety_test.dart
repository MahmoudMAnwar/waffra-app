import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';

void main(){
 Map<String,Object?> record(String id,{Object? amount=10.50,
   Object? date='2026-10-31T12:00:00',Object? income=false,
   Object? receiptPath})=> <String,Object?>{
   'id':id,'title':'Synthetic purchase','category':'مطاعم / وجبات',
   'amount':amount,'income':income,'date':date,'receiptPath':receiptPath,
  };
 WaffraPreflightResult inspect(List<Map<String,Object?>> entries)=>
   WaffraLegacyPreflight.inspect({'entries':jsonEncode(entries)});

 test('M337 financial preflight rejects duplicate and missing record IDs',(){
  expect(inspect([record('same'),record('same')]).issues
   .any((x)=>x.code=='duplicate_id'),isTrue);
  expect(inspect([record('')]).issues
   .any((x)=>x.code=='missing_id'),isTrue);
 });
 test('M337 finance preflight rejects negative, fractional halala and malformed',(){
  for(final amount in <Object?>[-1,0.001,'10']){
   final checked=inspect([record('amount',amount:amount)]);
   expect(checked.canStage,isFalse,reason:'Bad amount: $amount');
   expect(checked.issues.any((x)=>x.code=='invalid_amount'),isTrue);
  }
  expect(WaffraLegacyPreflight.canRepresentHalalas(double.infinity),isFalse);
  expect(inspect([record('fine',amount:0.01)]).canStage,isTrue);
 });
 test('M337 financial preflight fails closed on invalid dates and direction',(){
  for(final bad in ['not-a-date','2026-13-99','2026-02-30','']){
   final checked=inspect([record('bad',date:bad)]);
   expect(checked.issues.any((x)=>x.code=='invalid_date'),isTrue);
  }
  expect(inspect([record('direction',income:'false')]).issues
   .any((x)=>x.code=='invalid_income_flag'),isTrue);
 });
 test('M337 damaged receipt references cannot pass storage preflight',(){
  final checked=inspect([record('receipt',receiptPath:'["",42]')]);
  expect(checked.issues.any((x)=>x.code=='invalid_receipt_list'),isTrue);
 });
 test('M337 no plaintext raw SMS on the guarded legacy finance writer',(){
  expect(()=>WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes([
   {'notes':'Original bank SMS text','sourceType':'sms'}
  ]),throwsStateError);
  expect(()=>WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes([
   {'notes':'','sourceType':'sms'}
  ]),returnsNormally);
 });
}
