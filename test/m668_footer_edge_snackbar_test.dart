import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

/// Owner-approved M668 concept #3. Test pixels/geometry as well as the
/// centralized presenter contract; no finance or user data is involved.
void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  const edgeColors = <WaffraSnackKind, Color>{
    WaffraSnackKind.success: Color(0xFF0C7957),
    WaffraSnackKind.error: Color(0xFFE67B81),
    WaffraSnackKind.warning: Color(0xFFB7791F),
    WaffraSnackKind.info: Color(0xFF2B6CB0),
  };
  const lightSurface = Color(0xFFFFFFFF);
  const darkSurface = Color(0xFF1D2B25);

  for (final english in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      for (final kind in WaffraSnackKind.values) {
        testWidgets('M668 ${english ? "LTR" : "RTL"} '
            '${dark ? "dark" : "light"} ${kind.name}: card and physical '
            'leading status stripe above footer', (tester) async {
          tester.view.physicalSize = const Size(320, 750);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          waffraLanguage.value = english ? 'en' : 'ar';
          final notice = ValueNotifier<WaffraNoticeData?>(
            WaffraNoticeData(
              text: english ? 'Transaction saved' : 'تم حفظ العملية',
              kind: kind, duration: const Duration(seconds: 5),
              requireDismissal: true,
            ),
          );
          addTearDown(notice.dispose);
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              useMaterial3: true,
            ),
            home: Directionality(
              textDirection: english ? TextDirection.ltr : TextDirection.rtl,
              child: Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WaffraFooterNoticeHost(
                      listenable: notice, onDismiss: () => notice.value = null),
                    const SizedBox(
                      key: Key('m668-footer'), height: 72,
                      child: ColoredBox(color: Color(0xFF073F31)),
                    ),
                  ],
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          final card = find.byType(WaffraNoticeEdgeBody);
          final stripe = find.byKey(const Key('waffra-snackbar-edge'));
          expect(card, findsOneWidget);
          expect(stripe, findsOneWidget);
          expect(tester.widget<Container>(stripe).color, edgeColors[kind]);
          final ancestorMaterials = tester.widgetList<Material>(
            find.ancestor(of: card, matching: find.byType(Material)));
          expect(ancestorMaterials.any(
            (material) => material.color ==
                (dark ? darkSurface : lightSurface)), isTrue,
            reason: 'The notice card, not the entire route, is neutral');
          final outer = tester.getRect(card);
          final bar = tester.getRect(stripe);
          expect(bar.width, 5);
          if (english) {
            expect((bar.left - outer.left).abs(), lessThanOrEqualTo(1));
          } else {
            expect((bar.right - outer.right).abs(), lessThanOrEqualTo(1));
          }
          expect(outer.bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const Key('m668-footer'))).top + 1),
            reason: 'Reserved footer must not be covered by the card');
          expect(find.byType(WaffraNoticeContent), findsOneWidget);
          expect(find.byKey(const Key('waffra-snackbar-close')), findsNothing,
            reason: 'M670 removes X from every notice, not just the footer');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('M670 Undo fires exactly once and notices never show X',
      (tester) async {
    var undoCalls = 0;
    final notice = ValueNotifier<WaffraNoticeData?>(
      WaffraNoticeData(
        text: 'تم تعديل المعاملة', kind: WaffraSnackKind.success,
        duration: const Duration(seconds: 5), requireDismissal: true,
        actionLabel: 'تراجع', onAction: () => undoCalls++,
      ),
    );
    addTearDown(notice.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: WaffraFooterNoticeHost(
          listenable: notice,
          onDismiss: () => notice.value = null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final undo = find.byKey(const Key('waffra-snackbar-action'));
    expect(undo, findsOneWidget);
    expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(undoCalls, 1);
    expect(notice.value, isNull);
    expect(find.byType(WaffraNoticeEdgeBody), findsNothing);

    notice.value = const WaffraNoticeData(
      text: 'راجع المبلغ', kind: WaffraSnackKind.warning,
      duration: Duration(seconds: 5), requireDismissal: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-snackbar-close')), findsNothing);
    expect(find.text('راجع المبلغ'), findsOneWidget);
    notice.value = null;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('M668 fallback uses same neutral edge card without Home footer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => snack(context, 'خطأ في الإدخال',
          kind: WaffraSnackKind.error),
        child: const Text('Show notice'),
      ))),
    ));
    await tester.tap(find.text('Show notice'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(WaffraNoticeEdgeBody), findsOneWidget);
    final material = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(material.backgroundColor, lightSurface);
    expect(tester.widget<Container>(
      find.byKey(const Key('waffra-snackbar-edge'))).color,
      edgeColors[WaffraSnackKind.error]);
    expect(tester.takeException(), isNull);
  });

  test('M668 single global presenter, preserve four severities and timing', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('enum WaffraSnackKind { success, error, warning, info }'));
    expect(source, contains('void waffraDismissFooterNotice()'));
    expect(source, contains('Timer(notice.duration,()'));
    expect(source, contains('if(!notice.requireDismissal)'));
    expect(source, contains('notice.onAction?.call()'));
    expect(source, contains('WaffraFooterNoticeHost'));
    expect(source, contains('content:WaffraNoticeEdgeBody('));
    expect(RegExp(r'\.showSnackBar\s*\(').allMatches(source).length, 1);
    expect(RegExp(r'\bSnackBar\s*\(').allMatches(source).length, 1);
  });
}
