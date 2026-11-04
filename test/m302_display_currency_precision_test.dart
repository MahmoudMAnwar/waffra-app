import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_amount_formatter.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown((){
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('SAR');
  });

  test('M416 Saudi app fixes SAR while preserving all 36 Global currency descriptors and ledger precision',(){
    expect(waffraCountryCurrencies.length,36);
    for(final item in waffraCountryCurrencies){
      WaffraDisplayCurrency.active.value=
        WaffraDisplayCurrency.displaySelection(item.code);
      expect(WaffraDisplayCurrency.convert(1234),1234,reason:item.code);
      expect(WaffraDisplayCurrency.toLedgerSar(1234),1234,reason:item.code);
      final precision=waffraCurrencyMinorDigits(item.code);
      expect(precision,inInclusiveRange(0,3),reason:item.code);
      expect(WaffraDisplayCurrency.amount(1234),'1,234.00',reason:item.code);
      expect(WaffraDisplayCurrency.money(1234,english:true),
        '1,234.00 SAR',reason:'Saudi app display for '+item.code);
      expect(WaffraDisplayCurrency.country.code,'SAR');
    }
  });

  test('M416 dormant Global selection cannot change SAR app units or stored cents',(){
    for(final code in ['JPY','KRW']){
      WaffraDisplayCurrency.active.value=
        WaffraDisplayCurrency.displaySelection(code);
      expect(WaffraDisplayCurrency.amount(1000.25),'1,000.25',reason:code);
      expect(WaffraDisplayCurrency.amount(-20.50),'-20.50',reason:code);
      expect(WaffraDisplayCurrency.amount(1000),'1,000.00',reason:code);
      expect(WaffraDisplayCurrency.toLedgerSar(1000.25),1000.25,
        reason:'Label-only selection must not recalculate the ledger');
    }
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('EGP');
    expect(WaffraDisplayCurrency.amount(1000.25),'1,000.25');
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('JOD');
    expect(WaffraDisplayCurrency.amount(1000.25),'1,000.25');
  });

  test('M416 Saudi display retains precise fractions without silent FX',(){
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('JPY');
    expect(WaffraDisplayCurrency.amount(1000),'1,000.00');
    WaffraDisplayCurrency.active.value=
      WaffraDisplayCurrency.displaySelection('KRW');
    expect(WaffraDisplayCurrency.amount(1000),'1,000.00');
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
