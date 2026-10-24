import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

BudgetCategory sampleCategory(
    String id, String name, bool income, {String parentId = ''}) =>
    BudgetCategory(
      id: id,
      name: name,
      icon: 'category',
      color: 0xFF087A54,
      income: income,
      parentId: parentId,
    );

void main() {
  final expenseParent = sampleCategory('expense', 'المصروفات', false);
  final expenseChild = sampleCategory(
    'cafe', 'مطاعم / قهوة', false, parentId: 'expense');
  final siblingParent = sampleCategory('travel', 'السفر', false);
  final siblingChild = sampleCategory(
    'hotel', 'السفر / فنادق', false, parentId: 'travel');
  final incomeParent = sampleCategory('income', 'الدخل', true);
  final incomeChild = sampleCategory(
    'salary', 'الدخل / راتب', true, parentId: 'income');
  final values = [
    expenseParent, expenseChild,
    siblingParent, siblingChild,
    incomeParent, incomeChild,
  ];

  test('M161 only main category headings appear in the first selector', () {
    expect(
      waffraManualCategoryParents(values, false).map((e) => e.id),
      ['expense', 'travel'],
    );
    expect(
      waffraManualCategoryParents(values, true).map((e) => e.id),
      ['income'],
    );
  });

  test('M161 only the selected parent children appear in the second selector', () {
    expect(
      waffraManualCategoryChildren(values, false, 'expense')
          .map((e) => e.name),
      ['مطاعم / قهوة'],
    );
    expect(
      waffraManualCategoryChildren(values, false, 'travel')
          .map((e) => e.name),
      ['السفر / فنادق'],
    );
    expect(
      waffraManualCategoryChildren(values, true, 'income')
          .map((e) => e.name),
      ['الدخل / راتب'],
    );
    expect(waffraManualCategoryChildren(values, false, null), isEmpty);
  });

  test('M161 manual transaction cannot be saved against any heading', () {
    expect(
      waffraCanAssignManualCategory(values, false, 'expense', 'المصروفات'),
      isFalse,
    );
    expect(
      waffraCanAssignManualCategory(values, false, 'expense', 'مطاعم / قهوة'),
      isTrue,
    );
    expect(
      waffraCanAssignManualCategory(values, false, 'expense', 'السفر / فنادق'),
      isFalse,
    );
    expect(
      waffraCanAssignManualCategory(values, true, 'income', 'الدخل / راتب'),
      isTrue,
    );
    expect(
      waffraCanAssignManualCategory(values, false, 'income', 'الدخل / راتب'),
      isFalse,
    );
    expect(
      waffraCanAssignManualCategory(values, false, null, 'مطاعم / قهوة'),
      isFalse,
    );
  });

  test('M161 deleted parent or child never leaves an assignable category', () {
    expect(
      waffraCanAssignManualCategory(
        values.where((c) => c.id != 'expense'),
        false, 'expense', 'مطاعم / قهوة'),
      isFalse,
    );
    expect(
      waffraCanAssignManualCategory(
        values.where((c) => c.id != 'cafe'),
        false, 'expense', 'مطاعم / قهوة'),
      isFalse,
    );
  });

  test('M161 manual leaf routing retains source-gated SMS hash persistence', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(!sms&&!waffraCanAssignManualCategory('));
    expect(source, contains('selectedParentId'));
    expect(source, contains('leafLabels:true'));
    expect(source, contains(
      'waffraTr(leafLabels?item.displayName:item.name)'));
    // A NEW bank-SMS transaction must atomically persist the entry AND hash
    // through the same native Home/Widget journal. An older two-step writer
    // was vulnerable to power loss between ledger and hash commits.
    final start = source.indexOf('if(pendingHash!=null&&initial==null){');
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf('}else{', start);
    expect(end, greaterThan(start));
    final scoped = source.substring(start, end);
    expect(scoped, contains('_financeAuthority.commitConfirmedSms('));
    expect(scoped, contains('hashes:[pendingHash!]'));
    expect(scoped, contains('allowDuplicateHashes:explicitlyApprovedSmsDuplicate'));
    expect(scoped, contains('if(applied.saved!=1){'));
    expect(scoped, isNot(contains('await _persistSmsHashes(')));
    expect(source, contains('await _persistSmsHashes({pendingHash!});'));
    expect(source, isNot(contains("p.setStringList('waffra_sms_hashes_v1'")));
  });
}
