import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_footer.dart';

/// Actual Android engine/emulator smoke. This does not impersonate iOS hardware
/// and cannot certify every OEM's system gesture navigation implementation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M278 Android: real system bars, full-screen and restored footer '
      'all permit navigation without status/nav overlap', (tester) async {
    expect(Platform.isAndroid, isTrue);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var selected = 0;

    Future<void> assertSafeAndTap(int target) async {
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(builder: (context, update) => Scaffold(
          appBar: AppBar(title: const Text('Waffra',
            key: Key('m278-real-os-app-title'))),
          body: const Center(child: Text('System UI responsive smoke')),
          bottomNavigationBar: WaffraFooterNavigation(
            selectedIndex: selected,
            english: false,
            onSelected: (next) => update(() => selected = next),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      final window = tester.view;
      final size = window.physicalSize / window.devicePixelRatio;
      final devicePadding = MediaQueryData.fromView(window).padding;
      final footer = tester.getRect(
        find.byKey(const Key('waffra-modern-footer')));
      final title = tester.getRect(
        find.byKey(const Key('m278-real-os-app-title')));
      final targetRect = tester.getRect(
        find.byKey(Key('waffra-nav-' + target.toString())));
      expect(footer.bottom, closeTo(size.height, 2),
          reason: 'The footer background must fill to the OS bottom edge');
      expect(title.top, greaterThanOrEqualTo(devicePadding.top - 2));
      expect(targetRect.bottom,
          lessThanOrEqualTo(size.height - devicePadding.bottom + 2),
          reason: 'Tap target must not be obscured by the system navigation area');
      await tester.tap(find.byKey(Key('waffra-nav-' + target.toString())));
      await tester.pumpAndSettle();
      expect(selected, target);
      expect(tester.takeException(), isNull);
    }

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await tester.pump(const Duration(milliseconds: 250));
      await assertSafeAndTap(2);

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await tester.pump(const Duration(milliseconds: 350));
      await assertSafeAndTap(4);

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await tester.pump(const Duration(milliseconds: 250));
      await assertSafeAndTap(0);
    } finally {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  });
}
