import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 final home=File('lib/main.dart').readAsStringSync();
 final form=File('lib/waffra_account_transaction_form.dart')
  .readAsStringSync();

 test('M662 review removes duplicate type chips and verbose transfer copy',(){
  expect(home,isNot(contains("key:Key('m595-review-type-'+option)")));
  expect(home,isNot(contains('التحويل مش دخل أو مصروف تلقائيًا.')));
  for(final action in [
   "Key('m587-sms-transfer-yes')",
   "Key('m587-sms-transfer-no')",
   "Key('m587-sms-transfer-exclude')",
  ]){expect(home,contains(action));}
  expect(home,contains("Key('m662-unknown-correct-to-'+kind)"));
  expect(home,contains("key:const Key('waffra-sms-original-expand')"));
 });

 test('M662 fresh SMS transfer opens real two-sided editor with original body',(){
  expect(home,contains('await _ensureFinanceBound();'));
  expect(home,contains('initialSmsTransfer:prefill,originalSmsText:body,'));
  expect(home,contains('requireSmsDateConfirmation:needsDateConfirmation'));
  expect(home,contains('await api.transferReviewedSmsWithFee('));
  expect(home,contains('WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
  expect(form,contains("Key('m662-transfer-original-sms-expand')"));
  expect(form,contains("Key('m662-transfer-original-sms-text')"));
  expect(form,contains('SelectableText(widget.originalSmsText!'));
  expect(form,contains('if(widget.initialSmsTransfer!=null&&!smsDateConfirmed)'));
  expect(form,contains('accountField(source,mode==WaffraAccountOperation.transfer?'));
  expect(form,contains('accountField(destination,tr('));
  expect(form,contains('destination==source'));
  expect(form,contains('destination=created.id;'));
  expect(form,contains('source=created.id;'));
 });

 test('M662 manual alternative shows transfer reference without false SMS ACK',(){
  final begin=home.indexOf("}else if(decision=='transfer-manual'&&mounted){");
  final end=home.indexOf("}else if(decision=='yes'&&mounted",begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final segment=home.substring(begin,end);
  expect(segment,contains('reviewedOriginalSms:body'));
  expect(segment,contains("manualIncomeOverride:kind=='income'"));
  expect(segment,isNot(contains('acknowledgeCommitted(')));
  expect(home,contains("Key('m662-manual-correction-original-text')"));
  expect(home,contains('رسالة التحويل ستظل في المراجعة.'));
  expect(home,contains("key:const Key('waffra-entry-original-sms-expand')"));
 });

 test('M662 first new child remains selected after verified refresh',(){
  expect(home,contains('final refreshed=(await api.balances()).where((a)=>!a.archived).toList();'));
  expect(home,contains('chosenManualAccount=id; // Creating a provider also created its first child.'));
  expect(home,contains('final related=groups.where((p)=>'));
  expect(home,contains('if(related.length!=1)throw StateError('));
  expect(home,contains('entryProviders=WaffraRecurringAccountGroups.withBankProviderChoices(refreshed);'));
  expect(home,contains("value:'__create_child__'"));
  expect(home,contains('accountChildMenuRevision++'));
 });

 test('M662 compact savings and paid dues have enough width for SAR',(){
  final a=home.indexOf('Widget _m649SavingsCard(');
  final b=home.indexOf('Future<void> _m647ShowInternalTransfers(',a);
  final card=home.substring(a,b);
  expect(card,contains('WaffraCurrencyAmount(movement.amountMinor/100'));
  expect(card,contains('maxLines:2,overflow:TextOverflow.ellipsis'));
  final c=home.indexOf('Widget compactTransaction(MoneyEntry entry)');
  final d=home.indexOf('Widget _m549HomeFinanceAction(',c);
  final paid=home.substring(c,d);
  expect(paid,contains('Align(alignment:AlignmentDirectional.centerStart,'));
  expect(paid,contains('WaffraCurrencyAmount(entry.income?entry.amount:-entry.amount'));
  expect(paid,isNot(contains('BoxConstraints(maxWidth:119)')));
  expect(paid,contains('future:_m650DueVerifiedAccount(entry)'));
  expect(paid,contains('entry.goalWalletPaidMinor/100'));
 });

 test('M662 non-analytics PDF sections share a page flow',(){
  final a=home.indexOf('final reportSections=<pw.Widget>[];');
  final b=home.indexOf('final bytes=await doc.save();',a);
  expect(a,greaterThan(0));
  final pdf=home.substring(a,b);
  expect(pdf.split('reportSections.addAll(').length-1,3);
  expect(pdf,contains('build:(ctx)=>reportSections'));
  expect(pdf,contains("heading('حركات الادخار'"));
  expect(pdf,contains("heading('التحويلات بين حساباتي'"));
  expect(pdf,contains("heading('تفاصيل العمليات'"));
 });

 test('M662 no piggy-bank icons on app finance cards',(){
  expect(home,isNot(contains('Icons.savings_outlined')));
  expect(home,isNot(contains('Icons.savings_rounded')));
  expect(home,isNot(contains('🐷')));
  expect(home,contains('Icons.account_balance_wallet_outlined'));
 });
 test('M662.8 fresh manual expense and income never preselect expense Other',(){
  final entryStart=home.indexOf(' Future<void> entrySheet({MoneyEntry? initial');
  final entryEnd=home.indexOf(' Future<void> showReceipt(',entryStart);
  expect(entryStart,greaterThan(0));
  final editor=home.substring(entryStart,entryEnd);
  final init=editor.substring(
   editor.indexOf('String category=(smsEditorDraft?'),
   editor.indexOf('String? selectedParentId;'));
  // Existing transaction edits and trusted bank-SMS proposals retain
  // their own category; only a NEW MANUAL expense/income is blank.
  expect(init,contains("initial?.category??(sms?"));
  expect(init,contains("(trustedSms?(editorLearnedCategory??parsedSms.category):'أخرى'):'');"));
  expect(init,isNot(contains("initial?.category??(trustedSms?")));
  expect(editor,contains('String? selectedParentId;'));
  expect(editor,contains("mainCategories.where((c)=>c.id==selectedParentId)"));
  expect(editor,contains("selectedParentId=legacyParent.isEmpty?null:legacyParent.first.id;"));
  expect(editor,contains("'Choose a main category':'اختر القسم الرئيسي'"));
  expect(editor,contains("'Choose or add a subcategory'"));
  expect(editor,contains("onTap:selectedParentId==null?null:"));
  expect(editor,contains("category='';suggestion=null;"));
  final catalog=File('lib/waffra_category_catalog.dart').readAsStringSync();
  expect(catalog,contains("id:'other',name:'أخرى'"));
 });

}
