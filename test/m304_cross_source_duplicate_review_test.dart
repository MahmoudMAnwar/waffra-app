import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_cross_source_duplicate_review.dart';

void main() {
  bool possible({
    String candidateTitle = 'شراء من كيتا',
    String existingTitle = 'شراء من Keeta',
    String candidateCategory = 'طعام',
    String existingCategory = 'مطاعم',
    String candidateMerchant = 'KEETA',
    String existingMerchant = 'keeta',
    double candidateAmount = 24.50,
    double existingAmount = 24.50,
    bool candidateIncome = false,
    bool existingIncome = false,
    DateTime? candidateDate,
    DateTime? existingDate,
  }) => WaffraCrossSourceDuplicateReview.mightBeSame(
    candidateTitle: candidateTitle,
    candidateCategory: candidateCategory,
    candidateMerchantKey: candidateMerchant,
    candidateAmount: candidateAmount,
    candidateIncome: candidateIncome,
    candidateDate: candidateDate ?? DateTime(2026, 10, 30, 11),
    existingTitle: existingTitle,
    existingCategory: existingCategory,
    existingMerchantKey: existingMerchant,
    existingAmount: existingAmount,
    existingIncome: existingIncome,
    existingDate: existingDate ?? DateTime(2026, 10, 30, 13),
  );

  test('matching merchant/date/amount warns even across categories', () {
    expect(possible(), isTrue);
  });

  test('manual receipt title and category detect repeat without merchant key', () {
    expect(possible(
      candidateTitle: 'إيداع   راتب',
      existingTitle: 'ايداع راتب',
      candidateCategory: 'الدخل',
      existingCategory: 'الدخل',
      candidateMerchant: '',
      existingMerchant: '',
      candidateIncome: true,
      existingIncome: true,
    ), isTrue);
  });

  test('unrelated name and merchant never triggers just on same amount', () {
    expect(possible(
      candidateTitle: 'Restaurant A',
      existingTitle: 'Restaurant B',
      candidateMerchant: 'vendor_a',
      existingMerchant: 'vendor_b',
    ), isFalse);
  });

  test('different transaction directions are not duplicates', () {
    expect(possible(candidateIncome: true, existingIncome: false), isFalse);
  });

  test('same merchant next day does not block valid second purchase', () {
    expect(possible(existingDate: DateTime(2026, 10, 29)), isFalse);
  });

  test('different cent amounts are distinct', () {
    expect(possible(existingAmount: 24.51), isFalse);
  });

  test('sub-cent legacy amounts must not be rounded to match', () {
    expect(possible(candidateAmount: 24.501, existingAmount: 24.50), isFalse);
  });

  test('Arabic Alef and Arabic/Persian digits normalize symmetrically', () {
    expect(possible(
      candidateTitle: 'إيداع ١٢٣',
      existingTitle: 'ايداع ۱۲۳',
      candidateCategory: 'أخرى',
      existingCategory: 'اخري',
      candidateMerchant: '',
      existingMerchant: '',
    ), isTrue);
  });


  test('SMS merchant key matches manual Arabic purchase title', () {
    expect(possible(
      candidateMerchant: 'كيتا',
      existingMerchant: '',
      candidateTitle: 'Bank transaction',
      existingTitle: 'شراء من كيتا',
      candidateCategory: 'أخرى',
      existingCategory: 'طعام',
    ), isTrue);
  });

  test('reverse merchant matching covers English receipt titles', () {
    expect(possible(
      candidateMerchant: '',
      existingMerchant: 'KEETA',
      candidateTitle: 'Purchase at Keeta',
      existingTitle: 'POS purchase',
      candidateCategory: 'Food',
      existingCategory: 'Other',
    ), isTrue);
  });

  test('recognized purchase prefixes match without explicit merchant keys', () {
    expect(possible(
      candidateMerchant: '',
      existingMerchant: '',
      candidateTitle: 'POS Purchase Keeta',
      existingTitle: 'Keeta',
      candidateCategory: 'Shopping',
      existingCategory: 'Food',
    ), isTrue);
  });

  test('do not confuse partial merchant names or lookalike vendors', () {
    expect(possible(
      candidateMerchant: 'KEETA',
      existingMerchant: '',
      candidateTitle: 'Bank transaction',
      existingTitle: 'Purchase at Keeta Mart',
    ), isFalse);
  });

  test('different explicit merchant keys override generic identical titles', () {
    expect(possible(
      candidateMerchant: 'shop A',
      existingMerchant: 'shop B',
      candidateTitle: 'POS Purchase',
      existingTitle: 'POS Purchase',
      candidateCategory: 'Shopping',
      existingCategory: 'Shopping',
    ), isFalse);
  });

  test('prefixed merchant on another day or amount remains independent', () {
    expect(possible(
      candidateMerchant: 'Keeta',
      existingMerchant: '',
      existingTitle: 'Paid to Keeta',
      existingDate: DateTime(2026, 10, 29),
    ), isFalse);
    expect(possible(
      candidateMerchant: 'Keeta',
      existingMerchant: '',
      existingTitle: 'Paid to Keeta',
      existingAmount: 24.51,
    ), isFalse);
  });

  test('live confirm shows advisory with explicit override, no auto discard', () {
    final source = File('lib/main.dart').readAsStringSync();
    final anchor = source.indexOf('if(initial==null&&entries.any((e)=>');
    expect(anchor, greaterThanOrEqualTo(0));
    final snippet = source.substring(anchor, anchor + 1800);
    expect(snippet, contains('WaffraCrossSourceDuplicateReview.mightBeSame'));
    expect(snippet, contains("Navigator.pop(ctx,true)"));
    expect(snippet, contains('if(proceed!=true||!mounted)'));
    expect(snippet, contains('explicitlyApprovedSmsDuplicate=true'));
  });
}
