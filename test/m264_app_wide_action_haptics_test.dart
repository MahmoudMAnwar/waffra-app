import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_haptic_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final impacts=<MethodCall>[];

  setUp(() {
    WaffraHaptics.resetForTesting();
    impacts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') impacts.add(call);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    WaffraHaptics.resetForTesting();
  });

  testWidgets('enabled button produces accepted light impact and action',
      (tester) async {
    var fired=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:TextButton(
        onPressed:WaffraHaptics.tap((){fired++;}),
        child:const Text('Enable'),
      ),
    ))));
    await tester.tap(find.text('Enable'));
    await tester.pump();
    expect(fired,1);
    expect(impacts.map((c)=>c.arguments).toList(),
        ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('disabled action remains disabled and has no haptic',
      (tester) async {
    expect(WaffraHaptics.tap(null),isNull);
    expect(WaffraHaptics.selection<String>(null),isNull);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:TextButton(
        onPressed:WaffraHaptics.tap(null),
        child:const Text('Disabled'),
      ),
    ))));
    await tester.tap(find.text('Disabled'));
    await tester.pump();
    expect(impacts,isEmpty);
  });

  testWidgets('same gesture nested actions do not double vibrate',
      (tester) async {
    var first=0, second=0;
    final inside=WaffraHaptics.tap((){second++;})!;
    final outside=WaffraHaptics.tap((){first++;inside();})!;
    outside();
    await tester.pump();
    expect(first,1);
    expect(second,1);
    expect(impacts.length,1);
    expect(impacts.single.arguments,'HapticFeedbackType.lightImpact');
  });

  testWidgets('menu/dropdown selection vibrates, not typing',
      (tester) async {
    String? value;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Column(
      children:[
        DropdownButton<String>(
          key:const Key('haptic-dropdown'),
          value:value,
          hint:const Text('Select'),
          items:const [DropdownMenuItem(value:'SAR',child:Text('SAR'))],
          onChanged:WaffraHaptics.selection<String?>(
            (next){value=next;},
          ),
        ),
        const TextField(key:Key('typing-is-not-an-action')),
      ],
    ))));
    await tester.enterText(find.byKey(const Key('typing-is-not-an-action')),
        'note typing');
    await tester.pump();
    expect(impacts,isEmpty);
    final cb=WaffraHaptics.selection<String>((next){value=next;})!;
    cb('SAR');
    await tester.pump();
    expect(value,'SAR');
    expect(impacts.length,1);
  });

  test('all major UI surfaces use the common accepted action wrapper', () {
    const paths=[
      'lib/main.dart',
      'lib/currency_converter.dart',
      'lib/waffra_categories_page.part.dart',
      'lib/waffra_deleted_item_card.part.dart',
      'lib/waffra_financial_tools.dart',
      'lib/waffra_footer.dart',
      'lib/waffra_gold_market_section.dart',
      'lib/waffra_oil_market_section.dart',
      'lib/waffra_market_accordion.dart',
      'lib/waffra_pdf_reader.dart',
      'lib/waffra_recurring_trash.part.dart',
      'lib/waffra_smart_analysis.part.dart',
      'lib/waffra_verified_receipt_panel.dart',
      'lib/waffra_widget_capture.part.dart',
      'lib/waffra_account_deletion.dart',
    ];
    var taps=0;
    for(final path in paths){
      final s=File(path).readAsStringSync();
      expect(s.contains('WaffraHaptics.tap(')
          || s.contains('WaffraHaptics.selection('),isTrue,
          reason:'$path has not been connected to the haptic action');
      taps+=RegExp(r'WaffraHaptics\.(?:tap|selection)\(')
          .allMatches(s).length;
    }
    expect(taps,greaterThan(250));
    final main=File('lib/main.dart').readAsStringSync();
    expect(main,contains('if(!_acceptFabTap())return;'));
    expect(main,contains('HapticFeedback.lightImpact();'));
    expect(main,contains('onChanged:(_)=>setState('),
        reason:'text editing remains ordinary non-vibrating typing');
    expect(main,isNot(contains('onTap:WaffraHaptics.tap(()async{\n     if(!_acceptFabTap())')));
  });
}
