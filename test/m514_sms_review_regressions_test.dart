import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 test('M514 incoming money is income, not owned-account transfer',(){
  for(final sms in [
   'حوالة واردة\nالمبلغ: SAR 120.00\nإلى حساب: **8308',
   'حوالة داخلية واردة\nمن: طرف آخر\nمبلغ: SAR 1.00',
   'Incoming Bank Transfer\nAmount: SAR 90.00',
  ]){
   final fact=WaffraBankSmsFactsParser.parse(sms);
   expect(fact.kind,WaffraBankOperationKind.income,reason:sms);
  }
  const outgoing='عملية حوالة مالية صادرة مقبولة\n'
   'خصمت من محفظة: **8308\n'
   'إيبان: **9288\n'
   'القيمة: SAR 882\nالرسوم: SAR 0.58';
  final fact=WaffraBankSmsFactsParser.parse(outgoing);
  expect(fact.kind,WaffraBankOperationKind.transfer);
  expect(fact.sourceSuffix,'8308');
  expect(fact.destinationSuffix,'9288');
  expect(fact.fee,0.58);
  // Generic credit transfer does not prove direction or ownership.
  expect(WaffraBankSmsFactsParser.parse(
   'Credit Transfer via Alinma Bank\nAmount: SAR 1900').kind,
   WaffraBankOperationKind.transfer);
 });

 test('M514 per-button scanned number is never native history total',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final priorScanned=before?'));
  expect(home,contains('final nowScanned=after?'));
  expect(home,contains('final scanned=(nowScanned-priorScanned)'));
  expect(home,contains('_autoSmsLastRescanScanned=scanned;'));
  expect(home,contains('آخر إعادة فحص: \$_autoSmsLastRescanScanned'));
  expect(home,isNot(contains('إجمالي الرسائل المفحوصة:')));
  expect(home,isNot(contains('عملية غامضة')));
 });

 test('M514 excluded queue items use dedicated encrypted fingerprints',(){
  final flutter=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final platform=File('native/WaffraMainActivity.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(flutter,contains("return _boolCall('excludeAutoBankSms',ids);"));
  expect(platform,contains('"excludeAutoBankSms" -> {'));
  expect(native,contains('excludedMessageBucketPrefix'));
  expect(native,contains('fun excludeMessages(context: Context, ids: Set<String>)'));
  expect(native,contains('isExcludedMessageLocked(context, fingerprint)'));
  expect(native,contains('editor.putString(excludedMessageBucketPrefix + bucket,'));
  expect(home,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(home,contains('WaffraAutoSms.excludeMessages([id])'));
  expect(home,contains("kind:'excluded'"));
 });

 test('M514 source-specific account digits, actionable transfer and verified receipt edit',(){
  final home=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  final authority=File('lib/storage/waffra_verified_finance_authority.dart')
    .readAsStringSync();
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
    .readAsStringSync();
  expect(form,contains('onCreateSmsAccount'));
  expect(form,contains('isDestination'));
  expect(home,contains('suggestedLastFour:proposedSuffix'));
  expect(home,contains('final proposedSuffix=!isDestination'));
  expect(home,contains("appBar:AppBar(title:const WaffraText('مراجعة حوالة بنكية'))"));
  expect(home,contains('final verifiedMinor=sourceAmount==null?0:'));
  expect(home,contains("'attach-verified-existing-receipt'"));
  expect(authority,contains('Future<WaffraFinanceAuthorityRead> attachReceiptsToExisting('));
  expect(bridge,contains('Future<WaffraFinanceSnapshotState> attachReceiptsToExisting('));
  expect(bridge,contains('return snapshot.store.transaction(() async {'));
  expect(bridge,contains('await vault.attachNewBatch(entryId:entryId,images:frozenImages);'));
 });
}
