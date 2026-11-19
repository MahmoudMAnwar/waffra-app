import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart'
    show BudgetCategory, defaultCategories, bankSmsDate,
      bankSmsHasUnverifiedTimestamp,
      waffraResolveSmsReviewCategory, waffraValidateSmsEditorReviewedCategory;

void main() {
  const electricityBill='سداد فاتورة\n'
    'بمبلغ SAR 116.06\n'
    'إلى السعودية للبطاقة\n'
    'الخدمة:POST\n'
    'رقم الفاتورة:30171391867\n'
    'بتاريخ 318-11-2026 02:27';

  BudgetCategory c(String id,String name,{String parentId='',
      bool income=false,bool active=true})=>
    BudgetCategory(id:id,name:name,parentId:parentId,
     income:income,icon:'category',color:0xFF087A54,categoryActive:active);

  test('M1044 real 116.06 SAR electricity SMS never silently repairs day 318', () {
    expect(bankSmsDate(electricityBill), isNull);
    expect(bankSmsHasUnverifiedTimestamp(electricityBill), isTrue);
    expect(bankSmsDate(electricityBill.replaceFirst('318-11', '18-11')),
      DateTime(2026,11,18,2,27));
  });

  test('M1044 exact reviewed active electricity leaf ID survives editor prefill', () {
    final categories=defaultCategories();
    final review=waffraResolveSmsReviewCategory(categories,
       income:false,proposed:'فواتير / كهرباء');
    expect(review.parent?.name,'فواتير');
    expect(review.leaf?.name,'فواتير / كهرباء');
    final chosen=waffraValidateSmsEditorReviewedCategory(categories,
      income:false,parentId:review.parent?.id,leafId:review.leaf?.id);
    expect(chosen.parent?.id, review.parent?.id);
    expect(chosen.leaf?.id,review.leaf?.id);
    expect(chosen.leaf?.parentId,chosen.parent?.id);
  });

  test('M1044 refuses stale, disabled, wrong-direction or ambiguous reviewed leaf', () {
    final categories=<BudgetCategory>[
      c('bills','فواتير'),
      c('bill-elec','فواتير / كهرباء',parentId:'bills'),
      c('other','أخرى'),
      c('other-elec','فواتير / كهرباء',parentId:'other'),
      c('inactive','فواتير / متوقف',parentId:'bills',active:false),
      c('salary','راتب',income:true),
      c('salary-leaf','راتب / أساسي',parentId:'salary',income:true),
    ];
    ({BudgetCategory? parent,BudgetCategory? leaf}) choose({
        required bool income, String? parentId, String? leafId})=>
      waffraValidateSmsEditorReviewedCategory(categories,
        income:income,parentId:parentId,leafId:leafId);
    expect(choose(income:false,parentId:'bills',leafId:'bill-elec').leaf,isNull,
      reason:'Same persisted leaf name cannot identify two parents in ledger');
    categories.removeWhere((c)=>c.id=='other-elec');
    expect(choose(income:false,parentId:'bills',leafId:'bill-elec').leaf?.id,'bill-elec');
    expect(choose(income:false,parentId:'other',leafId:'bill-elec').leaf,isNull);
    expect(choose(income:true,parentId:'bills',leafId:'bill-elec').leaf,isNull);
    expect(choose(income:false,parentId:'bills',leafId:'inactive').leaf,isNull);
    expect(choose(income:false,parentId:'bills',leafId:null).leaf,isNull);
  });

  test('M1044 review hands owner-selected category to SMS editor, not an independent guess', () {
    final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
    final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
    expect(review,contains('reviewedCategoryParentId:reviewedCategoryParentId'));
    expect(review,contains('reviewedCategoryLeafId:reviewCategoryValid?'));
    expect(review,contains('reviewedCategoryLeafId=unambiguous?chosen.id:null'));
    expect(editor,contains('waffraValidateSmsEditorReviewedCategory('));
    expect(editor,contains('reviewedSmsCategoryParentId'));
    expect(editor,contains('reviewedSmsCategoryLeafId'));
    expect(editor,contains('waffraCanAssignManualCategory('));
    expect(editor,contains('reviewedSmsAccountId'));
    expect(editor,contains('!a.archived'));
    expect(review,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  });

  test('M1044 date picker must require day AND time and disclose provenance', () {
    final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
    final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
    expect(editor,contains("Key('m1044-sms-date-provenance')"));
    expect(editor,contains('showTimePicker('));
    expect(editor,contains('smsDateConfirmed=true;'));
    expect(editor,contains('!smsDateConfirmed'));
    expect(editor,contains('savedManualDate'));
    expect(editor,contains('تاريخ ووقت الرسالة الأصلية غير مؤكدين'));
    expect(editor,contains('تم تأكيدهما يدويًا'));
    expect(editor,contains('DateTime.now()'));
    expect(editor,contains("waffra-entry-date-action"));
    expect(review,contains('e.notes==body'));
    expect(review,contains('acknowledgeCommitted([id])'));
  });
}
