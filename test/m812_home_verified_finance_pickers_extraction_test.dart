import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M812 verified SMS account chooser and optional budget picker are actual registered source',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_verified_finance_pickers.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_verified_finance_pickers.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeVerifiedFinancePickers on _HomeScreenState'));
  expect(main,isNot(contains(' Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(')));
  for(final proof in <String>[
   'reviewSmsAccountLinks(',
   'reviewSmsBudgetLinks(',
   'readVerifiedAccounts()',
   'createdFromSmsAccountId',
   'WaffraSmsAccountLearning',
   'waffraConfirmUnlinkedBudgetSave(',
   'userConfirmed:true',
  ]) {
   expect(part,contains(proof),reason:proof);
  }
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
 });
 test('M812 all old verified bank/SAR and budget QA still read exact money picker source',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' /// Read a single authoritative SQLCipher account witness immediately');
  final end=full.indexOf(' // M636: Manual paste/review sheet retired.',start);
  final part=File('lib/waffra_home_verified_finance_pickers.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' /// Read a single authoritative SQLCipher account witness immediately'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}
