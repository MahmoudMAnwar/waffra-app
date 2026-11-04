import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M400 new standalone budget form does not repeat visible help text', () {
    final src=File('lib/main.dart').readAsStringSync();
    final create=src.split('Future<String?> chooseBudgetCategory(').last
        .split('void refreshFromBudgetDirectory()').first;
    expect(create,contains("'waffra-independent-budget-create'"));
    expect(create,contains("'اسم الميزانية *'"));
    expect(create,isNot(contains('ميزانيتك مستقلة، مش محتاج تختار أي قسم.')));
    expect(create,isNot(contains('Create a budget without selecting any category.')));
  });

  test('M400 deletion copy is readable; deletion still requires confirmation', () {
    final src=File('lib/main.dart').readAsStringSync();
    expect(src,contains('وفواتيرها إلى المحذوفات لمدة 30 يومًا؟'));
    expect(src,isNot(contains('وفواتيرها المشفرة إلى المحذوفات لمدة 30 يومًا؟')));
    expect(src,contains('if(approved!=true||!mounted)return;'));
  });
}
