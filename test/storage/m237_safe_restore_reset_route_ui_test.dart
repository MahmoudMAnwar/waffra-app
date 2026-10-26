import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String home() => File('lib/main.dart').readAsStringSync();

  test('M237 active restore verifies authenticated archive in disposable vault',
      () {
    final source = home();
    final start = source.indexOf(' Future<void> backupDialog()async {');
    final finish = source.indexOf(' Future<void> eraseFinancialData()async {');
    expect(start, greaterThan(0));
    expect(finish, greaterThan(start));
    final dialog = source.substring(start, finish);
    final probe = dialog.indexOf(
      'WaffraFinanceRoute.backupRestore');
    final preflight = dialog.indexOf(
      'WaffraVerifiedActiveRestorePreflight(');
    final jsonLegacy = dialog.indexOf(
      'final raw=await compute(waffraDecodeBackupInIsolate');
    expect(probe, greaterThan(0));
    expect(preflight, greaterThan(probe));
    expect(jsonLegacy, greaterThan(preflight));
    expect(dialog, contains(
      'source.source==WaffraRuntimeFinanceBackend.verifiedEncrypted'));
    expect(dialog, contains('experimentalEnabled:true).inspect('));
    expect(dialog, contains('Your current data was not changed.'));
  });

  test('M237 encrypted full reset cannot go through legacy preference writer',
      () {
    final source = home();
    final start = source.indexOf(
      ' Future<void> eraseFinancialData()async {');
    final end = source.indexOf(' Widget _accountTile(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final reset = source.substring(start, end);
    final gate = reset.indexOf(
      'route:WaffraFinanceRoute.fullFinanceReset');
    final cancel = reset.indexOf(
      'if(current.source==WaffraRuntimeFinanceBackend.verifiedEncrypted)');
    final legacyBatch = reset.indexOf(
      "final clean=<String,Object>{");
    expect(gate, greaterThan(0));
    expect(cancel, greaterThan(gate));
    expect(legacyBatch, greaterThan(cancel));
    expect(reset, contains('Your data is unchanged.'));
  });

  test('M237 no green CI test can authorize automatic source activation', () {
    expect(const WaffraProductionCutoverDecision([])
        .automaticallyActivateSqlCipher, isFalse);
  });
}
