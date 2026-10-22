import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_validators.dart';

/// M93 QA on Saudi-only input and mandatory negative cases.
void main() {
  test('M93 mandatory name rejects blank Arabic whitespace and long labels',
      () {
    for (final name in ['', ' ', '\t\n', '   ']) {
      expect(WaffraValidators.requiredText(name), 'required');
    }
    expect(WaffraValidators.requiredText('قسم رئيسي'), isNull);
    expect(WaffraValidators.requiredText('x' * 100), isNull);
    expect(WaffraValidators.requiredText('x' * 101), 'too_long');
  });

  test('M93 valid local Saudi numbers use exactly 05 plus eight digits',
      () {
    for (final number in ['0500000000', '0512345678', '0599999999']) {
      expect(WaffraValidators.mobileNumber(number), isNull, reason: number);
    }
    for (final number in [
      '', '5', '050000000', '05000000000',
      '+966512345678', '966512345678', '00966512345678',
      '0412345678', '1512345678', '05abcdefgh',
    ]) {
      expect(WaffraValidators.mobileNumber(number), 'invalid_mobile',
          reason: number);
    }
  });

  test('M93 invalid financial amounts do not pass mandatory form save',
      () {
    for (final amount in [
      '', ' ', '-0.01', '-5.20', '0', 'abc', 'NaN',
      'Infinity', '--2',
    ]) {
      expect(WaffraValidators.positiveAmount(amount), isNotNull,
          reason: amount);
    }
    expect(WaffraValidators.positiveAmount('84.72'), isNull);
    expect(WaffraValidators.positiveAmount('1,200.50'), isNull);
    expect(WaffraValidators.positiveAmount('١٬٢٠٠٫٥٠'), isNotNull,
        reason: 'a raw Arabic digit string is normalized by the UI formatter');
    expect(WaffraValidators.positiveAmount('', required: false), isNull);
  });

  test('M93 category names must be unique across case and whitespace',
      () {
    expect(WaffraValidators.uniqueCategory('food', ['Food']), 'duplicate');
    expect(WaffraValidators.uniqueCategory('  سفر  ', ['سفر']), 'duplicate');
    expect(WaffraValidators.uniqueCategory('  ', ['تسوّق']), 'required');
    expect(WaffraValidators.uniqueCategory('تعليم', ['سفر']), isNull);
  });

  test('M93 recurring day input must remain within 1-31',
      () {
    for (final day in ['', '0', '32', '-3', 'abc']) {
      expect(WaffraValidators.dayOfMonth(day), 'invalid_day');
    }
    expect(WaffraValidators.dayOfMonth('1'), isNull);
    expect(WaffraValidators.dayOfMonth('31'), isNull);
  });
}
