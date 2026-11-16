import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show bankSmsDate, bankSmsHash;
import 'package:waffra/waffra_auto_sms.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

/// M1011 / #728: synthetic source/provenance regression; physical Android
/// ACK, owner/session identity, SQLCipher restore still require device UAT.
void main(){
 const bill='سداد فاتورة\n'
  'بمبلغ SAR 116.06\n'
  'إلى السعودية للبطاقة\n'
  'الخدمة:POST\n'
  'رقم الفاتورة:30171391867\n'
  'بتاريخ 318-11-2026 02:27';

 test('M1011 Arabic bill-payment is expense only after safe user review',(){
  final parsed=WaffraBankSmsFactsParser.parse(bill);
  expect(parsed.kind,WaffraBankOperationKind.expense);
  expect(parsed.pending,isFalse);
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(bill),isFalse);
  expect(WaffraBankSmsFactsParser.parse(
   'سداد فاتورة SAR 116.06 العملية فشلت').pending,isTrue);
 });

 test('M1011 malformed three-digit date cannot silently become 18th',(){
  expect(bankSmsDate(bill),isNull);
  expect(bankSmsDate('سداد فاتورة SAR 116.06\\nبتاريخ 18-11-2026 02:27'),
   DateTime(2026,11,18,2,27));
 });

 test('M1011 money fingerprint differs when amount or invoice changes',(){
  final changed=bill.replaceFirst('116.06','178.45');
  final another=bill.replaceFirst('30171391867','30171391868');
  expect(bankSmsHash(bill),isNot(bankSmsHash(changed)));
  expect(bankSmsHash(bill),isNot(bankSmsHash(another)));
  expect(bankSmsHash(bill),bankSmsHash(bill));
 });

 test('M1011 exact native transfer ID is stable and not body-only',(){
  const nativeId='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  expect(WaffraAutoSms.transferIdForMessage(nativeId),'sms-transfer-$nativeId');
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  expect(form,contains('widget.smsTransferRequestId??'));
 });

 test('M1011 reviewed correction commits original SMS and hash BEFORE native ACK',(){
  final source=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final helper=source.split(' Future<void> _m1011SaveReviewedSmsKind({')[1]
    .split('  Future<void> _m983OpenSmsTypedTemplate({')[0];
  final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final direct=source.split('  Future<void> _m983OpenSmsTypedTemplate({')[1]
    .split(' Future<void> _reviewAutoSmsCandidates({')[0];
  expect(helper,contains('WaffraSmsStructuredBankContext.multipleEvents(body)'));
  expect(helper,contains('facts.pending'));
  expect(helper,contains('WaffraBankSmsFactsParser.isVerificationChallenge(body)'));
  expect(helper,contains('await entrySheet(sms:true,initialSms:body,'));
  expect(helper,contains('reviewedIncomeOverride:income'));
  expect(helper,contains("e.sourceType=='sms'"));
  expect(helper,contains('bankSmsHash(e.notes)==hash'));
  expect(helper,contains('if(!smsHashes.contains(hash)||committed.isEmpty)return;'));
  expect(helper,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(helper.indexOf('if(!smsHashes.contains(hash)||committed.isEmpty)return;'),
   lessThan(helper.indexOf('await WaffraAutoSms.acknowledgeCommitted([id])')));
  expect(helper,contains("setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id))"));
  expect(helper,isNot(contains('commitConfirmedManual(')));
  expect(direct,contains('await _m1011SaveReviewedSmsKind('));
  expect(editor,contains('notes:sms?message.text:'));
  expect(editor,contains("sourceType:initial?.sourceType??(sms?'sms':'manual')"));
  expect(editor,contains("hashes:[pendingHash!]"));
  expect(editor,contains('_financeAuthority.commitConfirmedSms('));
  expect(editor,contains('if(pendingHash!=null&&initial==null){'));
 });

 test('M1011 all correction routes use the same safe SMS writer',(){
  final source=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final review=source.split(' Future<void> _reviewAutoSmsCandidates({')[1];
  final correct=review.split("if(decision=='correct-type'&&mounted&&reviewType!=null)")[1]
   .split("else if(decision=='exclude'&&mounted)")[0];
  final mismatch=review.split("}else if(decision=='transfer-manual'&&mounted){")[1]
   .split("}else if(decision=='yes'&&mounted")[0];
  expect(correct,contains('await _m1011SaveReviewedSmsKind('));
  expect(mismatch,contains('await _m1011SaveReviewedSmsKind('));
  expect(correct,isNot(contains('entrySheet(manualIncomeOverride:')));
  expect(mismatch,isNot(contains('entrySheet(manualIncomeOverride:')));
  expect(correct,contains('openReviewedSmsManualTransfer(id:id,body:body,sender:sender)'));
 });

 test('M1011 internal transfer correction stores encrypted original and native ACK',(){
  final route=File('lib/waffra_home_verified_account_flows.part.dart')
   .readAsStringSync();
  final view=File('lib/waffra_home_verified_transfer_cards.part.dart')
   .readAsStringSync();
  final ledger=File('lib/storage/waffra_accounts_repository.dart')
   .readAsStringSync();
  expect(route,contains('smsTransferRequestId:stableTransferId'));
  expect(route,contains('WaffraAutoSms.transferIdForMessage(id)'));
  expect(route,contains('await api.transfer(id:stableTransferId'));
  expect(route,contains('acknowledged=await WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
  expect(route,contains('if(acknowledged&&mounted)'));
  expect(route,contains('نص الرسالة البنكية الأصلية:'));
  expect(view,contains("Key('m1011-transfer-original-'+t.id)"));
  expect(view,contains('SelectableText(originalSms)'));
  expect(ledger,contains('Transfer ID reused with different money.'));
  expect(ledger,contains('note.runes.length>2000'));
 });

 test('M1011 fee-aware internal transfer preserves message in ONE writer',(){
  final review=File('lib/waffra_home_sms_transfer_review.part.dart')
   .readAsStringSync();
  final api=File('lib/storage/waffra_verified_accounts_api.dart')
   .readAsStringSync();
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
   .readAsStringSync();
  final writer=File('lib/storage/waffra_unified_finance_writer.dart')
   .readAsStringSync();
  expect(review,contains('originalSmsText:body,userConfirmed:true'));
  expect(api,contains('originalSmsText:originalSmsText'));
  expect(bridge,contains('originalSmsText: originalSmsText'));
  expect(writer,contains('final protectedTransferNote=originalSmsText==null?'));
  expect(writer,contains('note: protectedTransferNote'));
  expect(writer,contains("'notes': originalSmsText ?? ''"));
  expect(writer,contains("transferRows.single.read<String>('note') != protectedTransferNote"));
  expect(writer,contains('withExclusiveAccess(() async {'));
  expect(writer,contains('snapshot.store.transaction(() async {'));
  expect(writer,contains('Existing transfer must never be double charged.'));
  expect(review.indexOf('await api.transferReviewedSmsWithFee('),
   lessThan(review.indexOf('ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id])')));
 });
}
