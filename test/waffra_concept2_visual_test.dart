import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Concept-2 headers remain visible at 320px in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          useMaterial3: true,
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: brightness == Brightness.dark
              ? const Color(0xFF0B241C)
              : const Color(0xFFF4FAF7),
        ),
        home: const Scaffold(
          body: SafeArea(child: SingleChildScrollView(
            child: Column(children: [
              WaffraPageHero(
                title: 'أهداف الادخار',
                subtitle: 'تابع أهدافك بخطوات بسيطة',
                icon: Icons.flag_outlined,
              ),
              WaffraPageHero(
                title: 'العمليات المتكررة',
                subtitle: 'تابع مواعيد الدفع بوضوح',
                icon: Icons.repeat,
              ),
            ]),
          )),
        ),
      ));

      expect(find.text('أهداف الادخار'), findsWidgets);
      expect(find.text('العمليات المتكررة'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
