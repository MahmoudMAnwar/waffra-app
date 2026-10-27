import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

/// Retain actual Flutter engine timing summaries from a profile-mode run.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) {
      throw StateError('M276 profile data was not produced by the Flutter engine');
    }
    final out = File('build/performance/m276_android_profile_frames.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(data) + '\n');
    if (!data.containsKey('m276_footer_nav_frames') ||
        !data.containsKey('m276_1000_row_scroll_frames')) {
      throw StateError('M276 Android trace missing expected frame summaries');
    }
  },
);
