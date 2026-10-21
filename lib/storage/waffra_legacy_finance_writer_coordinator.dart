import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_experimental_writer_gate.dart';
import 'waffra_live_legacy_finance_guard.dart';

/// Coordinates CURRENT SharedPreferences finance writes from the full Waffra
/// dashboard and the separate Android quick-add Flutter engine.
///
/// This only solves participating-writer overlap. SharedPreferences multi-key
/// writes are NOT transactional, and this does not itself switch to SQLCipher.
/// M46's encrypted patch gateway is still disabled until a verified cutover.
class WaffraLegacyFinanceWriterCoordinator {
  const WaffraLegacyFinanceWriterCoordinator({
    this.testDirectory,
    this.testBypassNativeLock = false,
  }) : assert(!testBypassNativeLock || testDirectory != null);

  /// Injectable ONLY in isolated automated tests.
  final Directory? testDirectory;

  /// For Flutter's FakeAsync widget tests ONLY. OS advisory locks cannot be
  /// driven by fake timers. Production always uses the real native lock;
  /// use a disposable testDirectory and this override only in a UI test.
  final bool testBypassNativeLock;

  /// The exact saved entries value is a stronger witness than the widget's
  /// optional timestamp. If the process was killed between saving entries
  /// and saving widget revision, we still refuse a stale dashboard overwrite.
  static void requireUnchangedLedger(
    SharedPreferences current, {
    required String? expectedRaw,
    required String? expectedWidgetRevision,
  }) {
    if (current.getString('entries') != expectedRaw ||
        current.getString('waffra_widget_last_save_v1') !=
            expectedWidgetRevision) {
      throw StateError('Financial ledger changed; reload before saving.');
    }
  }

  Future<T> withCurrentPreferences<T>(
    Future<T> Function(SharedPreferences current) callback,
  ) async {
    if (testBypassNativeLock) {
      if (testDirectory == null) {
        throw StateError('Test-only lock bypass needs a disposable directory.');
      }
      final prefs = await SharedPreferences.getInstance();
      await const WaffraLiveLegacyFinanceGuard().requireLegacySource(prefs);
      return callback(prefs);
    }
    final directory = testDirectory ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      // The real app may launch in a newly installed application container.
      // Do not create the directory in tests when an explicit path is passed.
      if (testDirectory != null) {
        throw StateError('Test writer lock directory does not exist.');
      }
      await directory.create(recursive: true);
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: directory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      final prefs = await SharedPreferences.getInstance();
      await const WaffraLiveLegacyFinanceGuard()
          .requireLegacySource(prefs);
      return callback(prefs);
    });
  }
}
