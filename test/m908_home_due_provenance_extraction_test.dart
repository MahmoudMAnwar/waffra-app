import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('M908 original due account provenance is registered and read only',(){
  final m=File('lib/main.dart').readAsStringSync(),p=File('lib/waffra_home_due_account_provenance.part.dart').readAsStringSync();
  expect(m.split("part 'waffra_home_due_account_provenance.part.dart';").length,2);
  expect(p,startsWith("part of 'main.dart';"));
  expect(m,isNot(contains(' Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){')));
  for(final x in ['entry.goalWalletPaidMinor>=','WaffraRecurringPolicy.toHalalas(entry.amount)',
   'readExistingEntryAccount(entryId:entry.id)',
   'if(!link.exists||link.accountId==null||_m627ClosingSession)return null;',
   'return null; // Archived/missing account identity must not be invented.']){
    expect(p,contains(x),reason:x);
  }
  expect(p,isNot(contains('saveCaptured(')));
  expect(p,isNot(contains('commitConfirmedSms(')));
 });
 test('M908 strict source QA reconstructs unchanged original due provenance',(){
  final full=readWaffraMainSourceForContracts(),p=File('lib/waffra_home_due_account_provenance.part.dart').readAsStringSync();
  final a=full.indexOf(' Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){');
  final b=full.indexOf(' String? _m652ActivityAccountKey;',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(full.substring(a,b),p.substring(p.indexOf(' Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){'),p.lastIndexOf('\n}')+1));
 });
}
