import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';

/// Run in Android PROFILE mode with disposable synthetic rows.
/// Measures real build + raster FrameTiming, not flutter_test fake frames.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M276 profile: navigation and long-list scrolling', (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal'),
      home: StatefulBuilder(builder: (context, update) => Scaffold(
        body: CustomScrollView(
          key: const Key('m276_scroll'),
          slivers: [
            SliverPersistentHeader(delegate: WaffraBalanceHeader(
              balance: 1234.50, english: false,
              refreshVerifiedWidgetBalance: () async {},
            )),
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, index) => ListTile(
                key: ValueKey('transaction-$index'),
                title: Text('عملية تجريبية $index'),
                subtitle: const Text('بدون بيانات عملاء حقيقيين'),
                trailing: Text('${index + 1}.25'),
              ),
              childCount: 1000,
            )),
          ],
        ),
        bottomNavigationBar: WaffraFooterNavigation(
          selectedIndex: selected, english: false,
          onSelected: (i) => update(() => selected = i),
        ),
      )),
    ));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      for (final i in [1, 2, 3, 4, 0, 2, 0, 1, 0]) {
        await tester.tap(find.byKey(Key('waffra-nav-$i')));
        await tester.pump(const Duration(milliseconds: 130));
      }
      await tester.pumpAndSettle();
    }, reportKey: 'm276_footer_nav_frames');
    expect(selected, 0);

    await binding.watchPerformance(() async {
      for (var i = 0; i < 8; i++) {
        await tester.fling(find.byKey(const Key('m276_scroll')),
            const Offset(0, -450), 1200);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'm276_1000_row_scroll_frames');

    expect(tester.takeException(), isNull);
    // Both reports are produced by Flutter's engine FrameTiming summarizer.
    expect(binding.reportData, contains('m276_footer_nav_frames'));
    expect(binding.reportData, contains('m276_1000_row_scroll_frames'));
  });
}
