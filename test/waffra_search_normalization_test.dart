import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_search.dart';

void main() {
 group('Waffra search orthography in all selectors', () {
  test('Arabic hamza and bare alif work in both directions', () {
   expect(waffraSearchMatches('دينار أردني', 'دينار اردني'), isTrue);
   expect(waffraSearchMatches('دينار اردني', 'دينار أردني'), isTrue);
   expect(waffraSearchMatches('إدارة الأقسام', 'اداره الاقسام'), isTrue);
   expect(waffraSearchMatches('آمال', 'امال'), isTrue);
   expect(waffraSearchMatches('ٱسم', 'اسم'), isTrue);
  });
  test('harakat, tatweel, alef maqsura, ya, Persian forms and spaces', () {
   expect(waffraSearchMatches('إِدَّخَار', 'ادخار'), isTrue);
   expect(waffraSearchMatches('على', 'علي'), isTrue);
   expect(waffraSearchMatches('کارت', 'كارت'), isTrue);
   expect(waffraSearchMatches('دِيناَر   أُردُني', 'دينار اردني'), isTrue);
  });
  test('no false matching of other currencies or empty lists', () {
   expect(waffraSearchMatches('دينار كويتي', 'دينار اردني'), isFalse);
   expect(waffraSearchMatches('Jordanian dinar', 'dinAR'), isTrue);
   expect(waffraSearchMatches('دينار أردني', '  '), isTrue);
   expect(waffraSearchAny(['SAR','دينار أردني'], 'دينار اردني'), isTrue);
  });
  test('search does not modify source content', () {
   const label='دينار أردني';
   expect(waffraSearchMatches(label,'دينار اردني'), isTrue);
   expect(label,'دينار أردني');
  });
 });
}
