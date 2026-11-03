import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_saudi_mobile.dart';
import 'package:waffra/main.dart' show
 waffraMobileFieldError,waffraGoogleProfilePhoneError;

void main(){
 group('M416 Saudi mobile number for all signup providers',(){
  test('only ten national digits beginning 05 are accepted as user input',(){
   for(final value in ['0501234567','0512345678','0599999999']){
    expect(WaffraSaudiMobile.isValidNational(value),isTrue,reason:value);
    expect(waffraMobileFieldError(value),isNull,reason:value);
   }
   for(final value in [
    '', '512345678','050123456','05012345678','0412345678',
    '+966512345678','00966512345678','+201234567890',
    '0112345678','05ABC45678',
   ]){
    expect(WaffraSaudiMobile.isValidNational(value),isFalse,reason:value);
    expect(waffraMobileFieldError(value),isNotNull,reason:value);
   }
  });
  test('legacy Saudi +966 Google records display as 05 without migration',(){
   expect(WaffraSaudiMobile.inputFromStored('+966512345678'),'0512345678');
   expect(WaffraSaudiMobile.inputFromStored('0512345678'),'0512345678');
   expect(WaffraSaudiMobile.toE164('0512345678'),'+966512345678');
   expect(WaffraSaudiMobile.toE164('512345678'),isNull);
   expect(WaffraSaudiMobile.isSupportedStored('+966512345678'),isTrue);
   expect(waffraGoogleProfilePhoneError('+966512345678'),isNull,
    reason:'Stored Saudi E.164 is compatible, despite UI showing only 05.');
  });
  test('legacy foreign Google number is not reinterpreted as Saudi',(){
   for(final value in ['+201234567890','+971501234567','+962791234567']){
    expect(WaffraSaudiMobile.inputFromStored(value),isEmpty,reason:value);
    expect(WaffraSaudiMobile.isSupportedStored(value),isFalse,reason:value);
    expect(waffraGoogleProfilePhoneError(value),isNotNull,reason:value);
   }
   expect(WaffraSaudiMobile.inputFromStored(null),isEmpty);
  });
 });
}