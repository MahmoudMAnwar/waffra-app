import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_riyal_symbol.dart';

void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  testWidgets('Arabic amount uses the original approved Riyal PNG',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraText('1,234.50 ريال')),
    ));
    final images = find.byType(Image);
    expect(images, findsOneWidget);
    final image = tester.widget<Image>(images);
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, waffraRiyalAsset);
  });

  testWidgets('English money writes SAR without rendering a Riyal icon',
      (tester) async {
    waffraLanguage.value = 'en';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraText('1,234.50 ريال')),
    ));
    expect(find.byType(Image), findsNothing);
    final rich = tester.widget<Text>(find.byType(Text).last);
    expect(rich.textSpan!.toPlainText(), contains('SAR'));
    expect(rich.textSpan!.toPlainText(), isNot(contains('ريال')));
  });

  testWidgets('Ordinary prose is not changed into a money icon',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraText('كل ريال تحسب له حساب')),
    ));
    expect(find.byType(Image), findsNothing);
    expect(find.byWidgetPredicate((widget) =>
        widget is Text && widget is! WaffraText &&
        widget.data == 'كل ريال تحسب له حساب'), findsOneWidget);
  });

  testWidgets('Other currencies keep their own unit in either language',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Column(children: [
        WaffraText('250 EGP'),
        WaffraCurrencyMark(
            english: false, currencyCode: 'EGP', arabicLabel: 'ج.م'),
      ])),
    ));
    expect(find.byType(Image), findsNothing);
    expect(find.text('ج.م'), findsOneWidget);
  });

  testWidgets('Direct Arabic Riyal mark is the user-approved asset',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraCurrencyMark(english: false)),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect((tester.widget<Image>(find.byType(Image)).image as AssetImage)
        .assetName, waffraRiyalAsset);
  });
}
