import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_i18n.dart';

/// Flutter layout emulation of OS view insets, not physical-device certification.
/// The footer and notice are the real production widgets; content is synthetic.
/// iOS device deployment still requires a native Runner and Apple-device QA.
class _Device {
  final String name;
  final double width;
  final double height;
  final double top;
  final double bottom;
  final TargetPlatform platform;
  const _Device(this.name, this.width, this.height, this.top, this.bottom,
      this.platform);
  EdgeInsets get safe => EdgeInsets.only(top: top, bottom: bottom);
}

const _devices = <_Device>[
  _Device('Android compact gesture', 320, 568, 24, 24,
      TargetPlatform.android),
  _Device('Android 3-button navigation', 360, 740, 24, 48,
      TargetPlatform.android),
  _Device('Android gesture navigation', 360, 740, 24, 24,
      TargetPlatform.android),
  _Device('Android immersive full-screen', 393, 852, 0, 0,
      TargetPlatform.android),
  _Device('Android modern tall', 393, 852, 28, 24,
      TargetPlatform.android),
  _Device('Android large display', 412, 915, 28, 24,
      TargetPlatform.android),
  _Device('Android landscape', 740, 360, 24, 24,
      TargetPlatform.android),
  _Device('Android foldable outer display', 360, 800, 26, 24,
      TargetPlatform.android),
  _Device('Android unfolded display', 600, 960, 24, 24,
      TargetPlatform.android),
  _Device('iPhone with Home button', 375, 667, 20, 0,
      TargetPlatform.iOS),
  _Device('iPhone notch and Home Indicator', 390, 844, 59, 34,
      TargetPlatform.iOS),
  _Device('iPhone large Dynamic Island', 430, 932, 62, 34,
      TargetPlatform.iOS),
  _Device('iPhone immersive full-screen', 430, 932, 0, 0,
      TargetPlatform.iOS),
  _Device('iPhone landscape with gesture bar', 844, 390, 0, 21,
      TargetPlatform.iOS),
];

Widget _page({
  required _Device device,
  required bool english,
  required int selected,
  required ValueChanged<int> onSelected,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  WaffraNoticeData? notice,
  ValueListenable<WaffraNoticeData?>? noticeListenable,
}) {
  final media = MediaQueryData(
    size: Size(device.width, device.height),
    padding: device.safe,
    viewPadding: device.safe,
    textScaler: TextScaler.linear(textScale),
    systemGestureInsets: EdgeInsets.only(
      bottom: device.bottom > 0 ? device.bottom : 0),
  );
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      useMaterial3: true,
      platform: device.platform,
      fontFamily: 'Tajawal',
    ),
    home: MediaQuery(
      data: media,
      child: Directionality(
        textDirection: english ? TextDirection.ltr : TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Waffra', key: Key('m278-header-title')),
          ),
          body: ListView.builder(
            key: Key('m278-page-' + selected.toString()),
            itemCount: 40,
            itemBuilder: (context, index) => ListTile(
              key: Key('m278-row-' + index.toString()),
              title: Text('Test entry ' + index.toString()),
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice != null)
                WaffraFooterNoticeHost(
                  listenable: noticeListenable,
                  onDismiss: () {
                    if (noticeListenable is ValueNotifier<WaffraNoticeData?>) {
                      noticeListenable.value = null;
                    }
                  },
                ),
              WaffraFooterNavigation(
                selectedIndex: selected,
                english: english,
                onSelected: onSelected,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, _Device device) {
  tester.view.physicalSize = Size(device.width, device.height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _assertSafeAreas(WidgetTester tester, _Device device) {
  final footer = tester.getRect(
      find.byKey(const Key('waffra-modern-footer')));
  final heading = tester.getRect(
      find.byKey(const Key('m278-header-title')));
  final body = tester.getRect(
      find.byKey(findSelectedBodyKey(tester)));

  expect(footer.left, greaterThanOrEqualTo(-1));
  expect(footer.right, lessThanOrEqualTo(device.width + 1));
  expect(footer.bottom, closeTo(device.height, 1),
      reason: 'Footer background should reach the OS bottom edge');
  expect(heading.top, greaterThanOrEqualTo(device.top - 1),
      reason: 'App header must remain below status icons and notch');
  expect(body.top, greaterThanOrEqualTo(device.top - 1));
  expect(body.bottom, lessThanOrEqualTo(footer.top + 1),
      reason: 'Content must not draw under bottom navigation');

  for (var tab = 0; tab < 5; tab++) {
    final target = tester.getRect(find.byKey(Key('waffra-nav-' + tab.toString())));
    expect(target.left, greaterThanOrEqualTo(-1));
    expect(target.right, lessThanOrEqualTo(device.width + 1));
    expect(target.bottom, lessThanOrEqualTo(
        device.height - device.bottom + 1),
        reason: 'Tap target must clear home-indicator/gesture/3-button area');
    expect(target.height, greaterThanOrEqualTo(48));
  }
}

Key findSelectedBodyKey(WidgetTester tester) {
  for (var i = 0; i < 5; i++) {
    final key = Key('m278-page-' + i.toString());
    if (find.byKey(key).evaluate().isNotEmpty) return key;
  }
  throw StateError('No visible page');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    waffraLanguage.value = 'ar';
  });
  tearDown(() => waffraLanguage.value = 'ar');

  for (final device in _devices) {
    for (final english in <bool>[false, true]) {
      testWidgets(
        'M278 ' + device.name + ': safe status bar, footer, '
        'five pages and taps (english=' + english.toString() + ')',
        (tester) async {
          _setViewport(tester, device);
          var selected = 0;
          await tester.pumpWidget(StatefulBuilder(
            builder: (context, update) => _page(
              device: device,
              english: english,
              selected: selected,
              onSelected: (next) => update(() => selected = next),
            ),
          ));
          await tester.pumpAndSettle();
          _assertSafeAreas(tester, device);

          for (var i = 0; i < 5; i++) {
            await tester.tap(find.byKey(Key('waffra-nav-' + i.toString())));
            await tester.pumpAndSettle();
            expect(selected, i);
            expect(find.byKey(Key('m278-page-' + i.toString())),
                findsOneWidget);
            _assertSafeAreas(tester, device);
            expect(tester.takeException(), isNull,
                reason: 'No Flutter overflow/layout exceptions across tabs');
          }
          final viewport = find.byKey(Key('m278-page-' + selected.toString()));
          await tester.drag(viewport, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final device in <_Device>[
    _devices[1], _devices[3], _devices[10], _devices[11],
  ]) {
    testWidgets('M278 error notice reserves space above gesture/nav bar: '
        + device.name, (tester) async {
      _setViewport(tester, device);
      final notices = ValueNotifier<WaffraNoticeData?>(
        WaffraNoticeData(
          text: 'هذا الحقل مطلوب',
          kind: WaffraSnackKind.error,
          duration: const Duration(seconds: 5),
          requireDismissal: true,
        ),
      );
      addTearDown(notices.dispose);
      var selected = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, update) => _page(
          device: device,
          english: false,
          textScale: 1.5,
          brightness: Brightness.dark,
          selected: selected,
          notice: notices.value,
          noticeListenable: notices,
          onSelected: (next) => update(() => selected = next),
        ),
      ));
      await tester.pumpAndSettle();
      final notice = find.byType(WaffraNoticeContent);
      expect(notice, findsOneWidget);
      final noticeRect = tester.getRect(notice);
      final footerRect = tester.getRect(
          find.byKey(const Key('waffra-modern-footer')));
      expect(noticeRect.bottom, lessThanOrEqualTo(footerRect.top + 1));
      expect(noticeRect.left, greaterThanOrEqualTo(-1));
      expect(noticeRect.right, lessThanOrEqualTo(device.width + 1));
      _assertSafeAreas(tester, device);
      await tester.tap(find.byKey(const Key('waffra-nav-4')));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('M278 OS system-bar changes without losing selected tab',
      (tester) async {
    const normal = _Device('system UI shown', 393, 852, 28, 48,
        TargetPlatform.android);
    const immersive = _Device('immersive', 393, 852, 0, 0,
        TargetPlatform.android);
    _setViewport(tester, normal);
    final mode = ValueNotifier<_Device>(normal);
    addTearDown(mode.dispose);
    var selected = 0;
    await tester.pumpWidget(ValueListenableBuilder<_Device>(
      valueListenable: mode,
      builder: (context, device, _) => StatefulBuilder(
        builder: (context, update) => _page(
          device: device,
          english: true,
          selected: selected,
          onSelected: (next) => update(() => selected = next),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('waffra-nav-3')));
    await tester.pumpAndSettle();
    expect(selected, 3);
    _assertSafeAreas(tester, normal);
    mode.value = immersive;
    await tester.pumpAndSettle();
    expect(selected, 3);
    _assertSafeAreas(tester, immersive);
    mode.value = normal;
    await tester.pumpAndSettle();
    expect(selected, 3);
    _assertSafeAreas(tester, normal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M278 200%-text smallest Android: footer and status remain safe',
      (tester) async {
    const device = _Device('very small', 320, 568, 24, 48,
        TargetPlatform.android);
    _setViewport(tester, device);
    await tester.pumpWidget(_page(
      device: device,
      english: false,
      textScale: 2,
      selected: 0,
      onSelected: (_) {},
    ));
    await tester.pumpAndSettle();
    _assertSafeAreas(tester, device);
    expect(tester.takeException(), isNull);
  });
}
