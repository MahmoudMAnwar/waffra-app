import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 group('Saudi bank SMS import', () {
  test('POS message with blank lines stays one entry and reads attached SR', () {
   const raw='شراء PoS\n\nمن2912;مدى-mada Pay (Atheer)\n\nبـ84.72SR\nمن Pe 288\n00:43 16/10/26';
   final messages=splitBankMessages(raw);
   expect(messages.length,1);
   final parsed=BankParser.parse(messages.single);
   expect(parsed.amount,84.72);
   expect(parsed.income,false);
   expect(parsed.category,'تسوّق');
  });
  test('outgoing transfer parses correctly', () {
   const raw='حوالة داخلية صادرة بـ60 SR\nمن 9288\nلـ4643;عبدالله العتوم\n12:34 26/10/17';
   final parsed=BankParser.parse(raw);
   expect(parsed.amount,60);
   expect(parsed.income,false);
   expect(parsed.category,'تحويلات');
  });
  test('multiple bank SMS messages split by bank headings', () {
   const raw='شراء PoS\nبـ84.72SR\n00:43 16/10/26\n\nحوالة داخلية صادرة بـ60 SR\n12:34 26/10/17';
   final messages=splitBankMessages(raw);
   expect(messages.length,2);
   expect(BankParser.parse(messages[0]).amount,84.72);
   expect(BankParser.parse(messages[1]).amount,60.0);
  });
  test('bank message hash stable across line break variations', () {
   expect(bankSmsHash('شراء PoS\nبـ84.72SR'),bankSmsHash('شراء PoS  بـ84.72SR'));
  });
 });
}
