import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_amount_formatter.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown((){
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('SAR');
  });

  test('M302 all 36 app currency labels use ISO precision with no FX',(){
    expect(waffraCountryCurrencies.length,36);
    for(final item in waffraCountryCurrencies){
      WaffraDisplayCurrency.active.value=
        WaffraDisplayCurrency.displaySelection(item.code);
      expect(WaffraDisplayCurrency.convert(1234),1234,reason:item.code);
      expect(WaffraDisplayCurrency.toLedgerSar(1234),1234,reason:item.code);
      final precision=waffraCurrencyMinorDigits(item.code);
      final expected=precision==0?'1,234':
          precision==3?'1,234.000':'1,234.00';
      expect(WaffraDisplayCurrency.amount(1234),expected,reason:item.code);
      expect(WaffraDisplayCurrency.money(1234,english:true),
        expected+' '+item.code,reason:item.code);
    }
  });

  test('M302 zero and three decimal currencies display independently',(){
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('JPY');
    expect(WaffraDisplayCurrency.amount(1000),'1,000');
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('KRW');
    expect(WaffraDisplayCurrency.amount(1000),'1,000');
    for(final code in ['JOD','KWD','BHD','OMR','IQD','TND']){
      WaffraDisplayCurrency.active.value=
        WaffraDisplayCurrency.displaySelection(code);
      expect(WaffraDisplayCurrency.amount(198.125),'198.125');
      expect(WaffraDisplayCurrency.toLedgerSar(198.125),198.125);
    }
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('EGP');
    expect(WaffraDisplayCurrency.amount(1000),'1,000.00');
    expect(WaffraDisplayCurrency.convert(1000),1000);
  });
}
