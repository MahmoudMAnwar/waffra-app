import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_entry_sheet_safe_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openForm(
    WidgetTester tester, {
    required Size size,
    required double navBarInset,
    double keyboardInset = 0,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final keyboardOpen = keyboardInset > 0;
    final media = MediaQueryData(
      size: size,
      viewPadding: EdgeInsets.only(bottom: navBarInset),
      padding: EdgeInsets.only(bottom: keyboardOpen ? 0 : navBarInset),
      viewInsets: EdgeInsets.only(bottom: keyboardInset),
      textScaler: TextScaler.linear(textScale),
    );
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(data: media, child: child!),
      home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('open-review'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => WaffraEntrySheetSafeLayout(
                form: SingleChildScrollView(
                  key: const Key('waffra-entry-form-scroll'),
                  child: Column(
                    children: [
                      for (var i = 0; i < 13; i++)
                        SizedBox(height: 64,child: Text('Input $i')),
                    ],
                  ),
                ),
                footer: FilledButton(
                  key: const Key('waffra-entry-confirm-save'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('تأكيد وحفظ العملية'),
                ),
              ),
            ),
            child: const Text('Open manual transaction'),
          ),
        )),
      ),
    ));
    await tester.tap(find.byKey(const Key('open-review')));
    await tester.pumpAndSettle();
  }

  for (final config in <({
    String name,Size size,double nav,double ime,double font,
  })>[
    (name:'Android 3-button nav / short handset',
     size:const Size(360,640),nav:48,ime:0,font:1),
    (name:'Android gesture bar',
     size:const Size(412,915),nav:24,ime:0,font:1),
    (name:'Android 3-button nav while keyboard open',
     size:const Size(360,740),nav:48,ime:300,font:1),
    (name:'Android large accessibility font',
     size:const Size(390,780),nav:48,ime:0,font:1.6),
  ]) {
    testWidgets('M354 confirm remains above OS navigation: '+config.name,
      (tester) async {
      await openForm(tester, size:config.size, navBarInset:config.nav,
        keyboardInset:config.ime,textScale:config.font);
      final footer=find.byKey(const Key('waffra-entry-confirm-save'));
      final scroll=find.byKey(const Key('waffra-entry-form-scroll'));
      expect(footer,findsOneWidget);
      expect(scroll,findsOneWidget);
      final before=tester.getBottomLeft(footer).dy;
      final limit=config.size.height-
        (config.ime>0?config.ime:config.nav);
      expect(before,lessThan(limit),
        reason:'Confirm button must not overlap navigation or keyboard');
      // The long form moves; the confirmation is pinned independently.
      await tester.drag(scroll,const Offset(0,-210));
      await tester.pumpAndSettle();
      final after=tester.getBottomLeft(footer).dy;
      expect((after-before).abs(),lessThan(2.0));
      expect(after,lessThan(limit));
      expect(tester.takeException(),isNull);
    });
  }

  test('M354 actual manual/SMS/OCR route uses safe pinned footer',(){
    final home=File('lib/main.dart').readAsStringSync();
    final start=home.indexOf('final result=await showModalBottomSheet<MoneyEntry>(');
    final end=home.indexOf(
      'debounce?.cancel();disposeLater([title,value,notes,message]);',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final route=home.substring(start,end);
    expect(route,contains('useSafeArea:true'));
    expect(route,contains('return WaffraEntrySheetSafeLayout('));
    expect(route,contains("key:const Key('waffra-entry-form-scroll')"));
    expect(route,contains("key:const Key('waffra-entry-confirm-save')"));
    expect(route,contains('footer:FilledButton('));
    expect(route,contains("Navigator.pop(sheetContext,MoneyEntry("));
    expect(route,isNot(contains('viewInsets.bottom+20')));
  });
}
