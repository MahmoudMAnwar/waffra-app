import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_validators.dart';

void main(){
 group('Mandatory field negative scenarios',(){
  test('rejects missing or whitespace-only name',(){
   expect(WaffraValidators.requiredText(''), 'required');
   expect(WaffraValidators.requiredText('    '), 'required');
   expect(WaffraValidators.requiredText('مواصلات'), isNull);
  });
  test('rejects overly long name',(){
   expect(WaffraValidators.requiredText('a'.padRight(101, 'a')), 'too_long');
  });
  test('rejects missing, zero, negative, nonnumeric amount',(){
   for(final v in ['', '   ', '0', '-10', 'abc', 'NaN']){
    expect(WaffraValidators.positiveAmount(v), isNotNull, reason:'amount $v');
   }
   expect(WaffraValidators.positiveAmount('1,200.50'), isNull);
   expect(WaffraValidators.positiveAmount('',required:false), isNull);
  });
  test('rejects duplicate category regardless of casing or whitespace',(){
   expect(WaffraValidators.uniqueCategory(' تسوّق ',['تسوّق']), 'duplicate');
   expect(WaffraValidators.uniqueCategory('Food',['food']), 'duplicate');
   expect(WaffraValidators.uniqueCategory('نقل',['تسوّق']), isNull);
  });
  test('rejects out of range recurring days',(){
   for(final v in ['','0','32','hi']) {
    expect(WaffraValidators.dayOfMonth(v), 'invalid_day');
   }
   expect(WaffraValidators.dayOfMonth('31'), isNull);
  });
  test('requires 05 and exactly 10 mobile digits',(){
   for(final v in ['', '05555', '971512345678', '05123456789']) {
    expect(WaffraValidators.mobileNumber(v), 'invalid_mobile');
   }
   expect(WaffraValidators.mobileNumber('0512345678'), isNull);
  });
 });
}
