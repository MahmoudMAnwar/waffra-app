import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M486 #410 sender picker stays below SMS review/editor',(){
  final source=File('lib/main.dart').readAsStringSync();
  final inboxStart=source.indexOf('Future<void> _openAutoSmsInbox()async{');
  final cardStart=source.indexOf('Widget _autoSmsReviewCard(){',inboxStart);
  expect(inboxStart,greaterThanOrEqualTo(0));
  expect(cardStart,greaterThan(inboxStart));
  final inbox=source.substring(inboxStart,cardStart);

  // The sender picker is an owned route and must remain mounted while
  // nested SMS review, transfer, correction or account creation is shown.
  expect(inbox,contains('await showModalBottomSheet<void>('));
  expect(inbox,contains('await _reviewAutoSmsCandidates(targetId:id);'));
  expect(inbox,contains('openingReviewId=null;'));
  expect(inbox,contains('refresh(()=>selectedSender=null);'));
  expect(inbox,contains('if(selectedSender==null){Navigator.pop(ctx);}'));
  expect(inbox,contains('if(!_autoSmsPending.any((row)=>row[\'id\']==id))'));
  expect(inbox,contains('selectedIds.remove(id);'));
  expect(inbox,contains('The sender inbox route remains beneath the message review.'));

  // The old bug popped the picker before opening the next screen.
  expect(inbox, isNot(contains('Navigator.pop(ctx,id)')));
  expect(inbox, isNot(contains('WidgetsBinding.instance.addPostFrameCallback((_){')));
 });

 test('M486 #410 canceling nested editor cannot acknowledge bank SMS',(){
  final source=File('lib/main.dart').readAsStringSync();
  final detailStart=source.indexOf('Future<void> _reviewAutoSmsCandidates(');
  final end=source.indexOf('void _receiveSharedSms()',detailStart);
  expect(detailStart,greaterThanOrEqualTo(0));
  expect(end,greaterThan(detailStart));
  final detail=source.substring(detailStart,end);
  expect(detail,contains('await entrySheet(sms:true,initialSms:body);'));
  expect(detail,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(detail,contains('await WaffraAutoSms.acknowledge([id]);'));
  expect(detail,contains('A failed Android acknowledgement must retain the review row.'));
  expect(detail,contains('if(acknowledged&&mounted){'));
  expect(detail,contains('_autoSmsReviewOpen=false;'));
 });
 test('M488 #416 cancelled inline Add retains prior financial selector',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> entrySheet({MoneyEntry? initial');
  final end=source.indexOf('if(selectedMain.isNotEmpty&&subcategories.isEmpty)',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final editor=source.substring(start,end);
  expect(editor,contains('accountProviderMenuRevision'));
  expect(editor,contains('accountChildMenuRevision'));
  expect(editor,contains('update(()=>accountProviderMenuRevision++);'));
  expect(editor,contains('update(()=>accountChildMenuRevision++);'));
  expect(editor,contains('chosenManualAccount=null; // A parent alone'));
 });

 test('M492 #410 Back stores only an ephemeral matching SMS editor draft',(){
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Future<void> entrySheet({MoneyEntry? initial');
  final end=src.indexOf('if(selectedMain.isNotEmpty&&subcategories.isEmpty)',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final editor=src.substring(start,end);
  expect(src,contains('final Map<String,Map<String,Object?>> _m492SmsEditorDrafts={}'));
  expect(editor,contains('bankSmsHash(initialSms)'));
  expect(editor,contains('_m492SmsEditorDrafts[smsEditorDraftKey]'));
  for(final field in ["'title'","'amount'","'income'","'parent'",
      "'category'","'budget'","'provider'","'account'","'date'"]){
   expect(src,contains(field+':'),reason:'stored $field');
  }
  expect(src,contains('_m492SmsEditorDrafts.length>=8'));
  expect(src,contains('if(smsEditorDraftKey!=null)_m492SmsEditorDrafts.remove(smsEditorDraftKey);'));
  expect(src,contains('debounce?.cancel();disposeLater([title,value,notes,message,transferAmount,transferNote]);'));
 });

 test('M494 #405 #416 inline creation is verified and preserves editor',(){
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Future<void> createAccountInsideEntryDropdown(');
  final end=src.indexOf('Widget operationPicker(){',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final section=src.substring(start,end);
  expect(section,contains('showWaffraDialog<WaffraNewAccountDraft>'));
  expect(section,contains('suggestedProviderId:expectedBank'));
  expect(section,contains('await api.balances()'));
  expect(section,contains('await api.createTypedAccountWithIdentity('));
  expect(section,contains('await _m467RefreshHomeAccounts()'));
  expect(section,contains('chosenManualAccount=id'));
  expect(section,isNot(contains('await openVerifiedAccounts()')));
 });

 test('M494 #409 original SMS visible in editor but OTP guarded',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains("Key('waffra-entry-original-sms-expand')"));
  expect(src,contains("Key('waffra-entry-original-sms-text')"));
  expect(src,contains('WaffraBankSmsFactsParser.parse(initialSms??message.text).pending?'));
  expect(src,contains('SelectableText(initialSms??message.text,'));
  expect(src,contains('readOnly:initialSms!=null,'));
 });

 test('M494 #417 failed bulk exclusion retains the selected sender sheet',(){
  final src=File('lib/main.dart').readAsStringSync();
  final from=src.indexOf('// Explicit queue removal first, followed by a SEPARATE sender opt-in.');
  final to=src.indexOf('Widget _autoSmsReviewCard(){',from);
  expect(from,greaterThanOrEqualTo(0));
  expect(to,greaterThan(from));
  final bulk=src.substring(from,to);
  expect(bulk,contains("if(choice==null||choice=='back'||!ctx.mounted)return;"));
  expect(bulk,contains('if(!failed&&ctx.mounted)Navigator.pop(ctx);'));
  expect(bulk,contains('selectedIds.removeAll(done);'));
  expect(bulk,contains('if(failed)snack(context,'));
  expect(bulk,contains('senderBlockChoices.contains'));
 });

}
