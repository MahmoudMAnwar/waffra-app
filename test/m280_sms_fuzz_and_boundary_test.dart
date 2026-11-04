import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

/// Synthetic SMS adversarial fixtures; no phone read permissions.
void main() {
  test('M280 split 100 bank events without losing ordering', () {
    final raw=List.generate(100,(i)=>
       'شراء PoS\nبـ${i+1}.00SR\n12:00 27/10/26').join('\n\n');
    final chunks=splitBankMessages(raw);
    expect(chunks.length,100);
    for(var i=0;i<chunks.length;i++){
      expect(BankParser.parse(chunks[i]).amount,(i+1).toDouble());
      expect(BankParser.parse(chunks[i]).income,false);
    }
  });

  test('M280 equivalent whitespace yields same dedupe identity', () {
    const plain='شراء PoS\nبـ84.72SR\n';
    const noisy='شراء PoS\r\nبـ84.72SR   ';
    expect(bankSmsHash(plain),bankSmsHash(noisy));
  });

  test('M280 declined/OTP messages do not fabricate completed payment', () {
    for(final raw in [
      'OTP\nYour verification code 123456',
      'Transaction Declined\nAmount: 40.00 SAR',
      'Online Pre-Authorization\nAmount: 50 SAR',
      'Failed Transaction\nAmount: 60 SAR',
    ]){
      expect(BankParser.parse(raw).amount,isNull);
    }
  });

  test('M280 amount-only English bank SMS requires review', () {
    const raw='Amount: 1234.56 SAR\nAvailable balance: 4000 SAR';
    expect(BankParser.parse(raw).amount,isNull);
  });

  test('M280 malformed long unicode does not silently create debit', () {
    final raw=List<String>.filled(2500,'🧾✨').join();
    expect(splitBankMessages(raw),hasLength(1));
    expect(BankParser.parse(raw).amount,isNull);
  });

  test('M280 incoming/outgoing direction remains correct', () {
    const incoming='Incoming Transfer\nAmount: 300.25 SAR';
    const outgoing='Outgoing Transfer\nAmount: 90.10 SAR';
    expect(BankParser.parse(incoming).income,true);
    expect(BankParser.parse(incoming).amount,300.25);
    expect(BankParser.parse(outgoing).income,false);
    expect(BankParser.parse(outgoing).amount,90.10);
  });
}
