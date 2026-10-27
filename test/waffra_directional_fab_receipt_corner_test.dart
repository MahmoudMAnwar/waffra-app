import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('English plus physically RIGHT, Arabic plus physically LEFT'
      ' across Home, Categories, Goals and Recurring', () {
    for (final tab in <int>[0, 1, 2, 3]) {
      final english = WaffraDirectionalFabLocation.horizontalOffset(
        english: true, scaffoldWidth: 390, fabWidth: 58,
        leftInset: 0, rightInset: 0,
      );
      final arabic = WaffraDirectionalFabLocation.horizontalOffset(
        english: false, scaffoldWidth: 390, fabWidth: 58,
        leftInset: 0, rightInset: 0,
      );
      expect(english, 316, reason: 'English tab $tab must anchor right');
      expect(arabic, 16, reason: 'Arabic tab $tab must anchor left');
    }
  });

  test('plus respects both physical system insets on narrow screens', () {
    expect(WaffraDirectionalFabLocation.horizontalOffset(
      english: true, scaffoldWidth: 320, fabWidth: 58,
      leftInset: 2, rightInset: 22,
    ), 224);
    expect(WaffraDirectionalFabLocation.horizontalOffset(
      english: false, scaffoldWidth: 320, fabWidth: 58,
      leftInset: 25, rightInset: 0,
    ), 41);
  });

  testWidgets('receipt count is INSIDE a clipped corner marker in both languages',
      (tester) async {
    for (final english in <bool>[true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(body: WaffraReceiptCornerBadge(
            count: 6, english: english,
          )),
        ),
      ));
      expect(find.text('6'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      final clip = tester.widget<ClipPath>(
        find.ancestor(
          of: find.text('6'),
          matching: find.byType(ClipPath),
        ).first,
      );
      expect((clip.clipper as WaffraReceiptCornerClipper).english, english);
    }
  });

  test('Design 9 badge is a small folded triangle, not a wide ribbon', () {
    const size=Size(36,30);
    final ar=const WaffraReceiptCornerClipper(english:false).getClip(size);
    final en=const WaffraReceiptCornerClipper(english:true).getClip(size);
    expect(ar.contains(const Offset(33,4)),isTrue);
    expect(ar.contains(const Offset(4,26)),isFalse);
    expect(en.contains(const Offset(4,4)),isTrue);
    expect(en.contains(const Offset(33,26)),isFalse);
  });

  test('goals keep outlined counter, recurring uses compact count badge', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('class WaffraOutlinedItemsCount'));
    expect(source,contains('count:goals.length'));
    expect(source,contains("Key('waffra-recurring-count-badge')"));
    expect(source,contains('nextRecurringDue(nextBill)'));
    expect(source,isNot(contains("WaffraOutlinedItemsCount(label:waffraIsEnglish?'Recurring transactions'")));
    expect(source,contains('width:36,height:30,color:forest'));
  });

  test('all snackbar entry points share one footer-aware presenter', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('enum WaffraSnackKind { success, error, warning, info }'));
    expect(source,contains('class WaffraNoticeContent extends StatelessWidget'));
    expect(source,contains('class WaffraFooterNoticeHost extends StatefulWidget'));
    expect(source,contains('bottomNavigationBar:accountOpened?null:Column(mainAxisSize:MainAxisSize.min,children:['));
    expect(source,contains('if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false)'));
    expect(source,contains('maxLines:2,'));
    expect(source,contains('width:min(MediaQuery.sizeOf(ctx).width*0.87,440.0)'));
    expect(RegExp(r'\.showSnackBar\s*\(').allMatches(source).length,1);
  });


  testWidgets('footer notice pushes financial content up and stays above footer',
      (tester) async {
    final notice=ValueNotifier<WaffraNoticeData?>(null);
    var undos=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:const SizedBox.expand(key:Key('finance-body')),
      bottomNavigationBar:Column(mainAxisSize:MainAxisSize.min,children:[
        WaffraFooterNoticeHost(
          listenable:notice,
          onDismiss:()=>notice.value=null),
        const SizedBox(
          key:Key('waffra-test-footer'),height:90,
          child:ColoredBox(color:Color(0xFF073F31))),
      ]),
    )));
    final oldBottom=tester.getBottomLeft(find.byKey(const Key('finance-body'))).dy;
    notice.value=WaffraNoticeData(
      text:'تم تعديل المعاملة',kind:WaffraSnackKind.success,
      duration:const Duration(seconds:5),requireDismissal:true,
      actionLabel:'تراجع',onAction:()=>undos++);
    await tester.pumpAndSettle();
    final noticeRect=tester.getRect(find.byType(WaffraNoticeContent));
    final footerRect=tester.getRect(find.byKey(const Key('waffra-test-footer')));
    final bodyRect=tester.getRect(find.byKey(const Key('finance-body')));
    expect(noticeRect.bottom,lessThanOrEqualTo(footerRect.top));
    expect(bodyRect.bottom,lessThanOrEqualTo(noticeRect.top),
      reason:'The snackbar must not cover a transaction card.');
    expect(bodyRect.bottom,lessThan(oldBottom),
      reason:'Financial content must reflow above the footer notice.');
    expect(noticeRect.height,lessThanOrEqualTo(66));
    expect(noticeRect.width,lessThanOrEqualTo(440));
    // WaffraText builds an inner Text with identical content, so text-based
    // ancestor matchers find the same button twice. Select its widget type.
    expect(find.byType(TextButton),findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(undos,1);
    expect(find.text('تم تعديل المعاملة'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    notice.dispose();
  });

  testWidgets('warning, error and info keep one footprint above footer', (tester) async {
    final notice=ValueNotifier<WaffraNoticeData?>(null);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:const SizedBox.expand(),
      bottomNavigationBar:Column(mainAxisSize:MainAxisSize.min,children:[
        WaffraFooterNoticeHost(
          listenable:notice,onDismiss:()=>notice.value=null),
        const SizedBox(key:Key('waffra-test-footer'),height:85),
      ]),
    )));
    for(final kind in [
      WaffraSnackKind.error,WaffraSnackKind.warning,WaffraSnackKind.info
    ]){
      notice.value=WaffraNoticeData(
        text:'رسالة اختبار',kind:kind,requireDismissal:true,
        duration:const Duration(seconds:5));
      await tester.pumpAndSettle();
      final panel=tester.getRect(find.byType(WaffraNoticeContent));
      final footer=tester.getRect(find.byKey(const Key('waffra-test-footer')));
      expect(panel.bottom,lessThanOrEqualTo(footer.top));
      expect(panel.height,lessThanOrEqualTo(66));
      expect(find.byWidgetPredicate((w)=>w is WaffraText && w.data=='رسالة اختبار'),findsOneWidget);
    }
    notice.value=null;
    await tester.pumpAndSettle();
    expect(find.text('رسالة اختبار'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    notice.dispose();
  });

  testWidgets('the same footer notice mirrors icon and close in Arabic and English',
      (tester) async {
    final notice=ValueNotifier<WaffraNoticeData?>(
      const WaffraNoticeData(
        text:'رسالة اختبار',kind:WaffraSnackKind.success,
        duration:Duration(seconds:5),requireDismissal:true));
    for(final direction in [TextDirection.rtl,TextDirection.ltr]){
      await tester.pumpWidget(MaterialApp(
        home:Directionality(textDirection:direction,child:Scaffold(
          body:const SizedBox.expand(),
          bottomNavigationBar:Column(mainAxisSize:MainAxisSize.min,children:[
            WaffraFooterNoticeHost(
              listenable:notice,onDismiss:()=>notice.value=null),
            const SizedBox(height:85),
          ]),
        )),
      ));
      await tester.pumpAndSettle();
      final statusX=tester.getCenter(find.byIcon(Icons.check_circle_rounded)).dx;
      final closeX=tester.getCenter(find.byIcon(Icons.close_rounded)).dx;
      expect(direction==TextDirection.rtl?statusX>closeX:statusX<closeX,isTrue,
        reason:'Status icon and close action must follow the current direction.');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    notice.dispose();
  });

  test('attachment corner mirrors with language without increasing row height', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('if(count>0)PositionedDirectional(top:0,start:0'));
    expect(source,contains('if(attachmentCount>0)PositionedDirectional(top:0,start:0'));
    expect(source,isNot(contains('count>0?29:12')));
    expect(source,isNot(contains('attachmentCount>0?29:0')));
    expect(source,contains('Icons.attach_file_rounded,size:10'));
  });

  test('Home, Categories, Goals and Recurring plus actions preserve locale switch, with no fixed-left anchor',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains(
      'floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)',
    ));
    expect(source, contains(
      'floatingActionButtonAnimator:const WaffraStationaryFabAnimator()',
    ));
    expect(source, contains(
      'floatingActionButton:!ready||accountOpened||tab==2?null:SizedBox(',
    ));
    expect(source, contains('width:58,height:58'));
    expect(source, contains('WaffraFabMenuAnchor('));
    expect(source, contains('expanded:addFabExpanded&&!goalsOpened'));
    expect(source, isNot(contains(
      'floatingActionButton:!ready||tab==4?null:Directionality(',
    )));
    expect(source, contains('if(goalsOpened||tab==3){unawaited(_launchAddAction(()=>goalDialog()));return;}'));
    expect(source, contains('if(tab==4){unawaited(_launchAddAction(()=>recurringDialog()));return;}'));
    expect(source, isNot(contains('WaffraPhysicalLeftFab')));
  });

  test('attachment marker is anchored in a card corner and contains its count',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(attachmentCount>0)PositionedDirectional(top:0,start:0'));
    expect(source, contains(
      'WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)',
    ));
    expect(source, contains("onTap:WaffraHaptics.tap(()=>showReceipt(e.receiptPath!)"));
    expect(source, contains('child:WaffraReceiptCornerBadge'));
  });
  testWidgets('expanded menu is above the physical plus on the same side in both languages', (tester) async {
    Widget harness(bool english) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,height: 500,
            child: Stack(children:[
              WaffraFabMenuAnchor(
                english:english,expanded:true,
                menu:Container(key:const Key('menu-anchor-probe'),
                  width:220,height:96,color:Colors.green),
              ),
            ]),
          ),
        ),
      ),
    );
    for (final english in <bool>[true,false]) {
      await tester.pumpWidget(harness(english));
      await tester.pumpAndSettle();
      final rect=tester.getRect(find.byKey(const Key('menu-anchor-probe')));
      expect(rect.width,220);
      expect(rect.height,96);
      expect(rect.left,english?154:16,
        reason:'Menu must be anchored above English-right/Arabic-left FAB');
      expect(rect.right,english?374:236,
        reason:'Menu cannot drift to the opposite physical edge');
      expect(rect.bottom,414,
        reason:'Menu ends 12px above the stable 58px plus');
      expect(tester.takeException(),isNull);
    }
  });

  test('FAB location never animates horizontally on tab or language switch', () {
    const animator=WaffraStationaryFabAnimator();
    const old=Offset(16,500);
    const next=Offset(316,500);
    for (final progress in <double>[0,0.25,0.5,0.75,1]) {
      expect(animator.getOffset(begin:old,end:next,progress:progress),next);
    }
    const incoming=AlwaysStoppedAnimation<double>(0.3);
    expect(animator.getScaleAnimation(parent:incoming).value,1);
    expect(animator.getRotationAnimation(parent:incoming).value,1);
  });

}
