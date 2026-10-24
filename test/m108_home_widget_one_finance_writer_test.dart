import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M108 both live widget and dashboard call one verified SMS journal', () {
    final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    final home=File('lib/main.dart').readAsStringSync();
    final journal=File('lib/storage/waffra_home_finance_persistence.dart')
        .readAsStringSync();

    // M109 additionally sends the widget through the SAME verified source
    // authority that dispatches to the M108 legacy journal until SQLCipher
    // has all 24 production route and cross-engine witness proofs.
    final router=File('lib/storage/waffra_verified_finance_authority.dart')
        .readAsStringSync();
    expect(widget, contains('_financeAuthority.commitConfirmedSms('));
    expect(widget, contains('WaffraFinanceRoute.widgetSmsConfirmedSave'));
    expect(router, contains('legacy.commitConfirmedLegacySms('));
    expect(router, contains('sourceGuard.inspect()'));
    expect(router, contains('encryptedSession!.appendConfirmed('));
    expect(home, isNot(contains('_homeFinancePersistence.commitConfirmedLegacySms(')));
    expect(home, contains('_financeAuthority.commitConfirmedSms('));
    expect(home, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
    // Widget cannot introduce a second custom transaction/journal
    // algorithm whose view of the ledger races against the main app.
    expect(widget, isNot(contains('journal.prepare(')));
    expect(widget, isNot(contains('journal.recover(')));
    expect(widget, isNot(contains('WaffraLegacyWidgetCommitJournal()')));
    expect(widget, isNot(contains('withLegacyWriter(')));

    expect(journal, contains('coordinator.withCurrentPreferences((prefs) async {'));
    expect(journal, contains('final existingHashes ='));
    expect(journal, contains('await journal.prepare('));
    expect(journal, contains('await journal.recover(prefs);'));
  });

  test('M108 no unsupported encrypted activation, Firebase or bank link', () {
    final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    final main=File('lib/main.dart').readAsStringSync();

    final binding=File('lib/storage/waffra_production_finance_authority_binding.dart')
        .readAsStringSync();
    // The new shared source guard supersedes the legacy-only widget startup.
    // It still must reject missing/ambiguous SQLCipher evidence and must never
    // silently switch to empty legacy data or a new encrypted vault.
    expect(widget, contains('WaffraProductionFinanceAuthorityBinding.bind('));
    expect(widget, contains('WaffraFinanceRoute.widgetStartup'));
    expect(main, contains('await _ensureFinanceBound();'));
    expect(binding, contains('sourceGuard.inspect()'));
    expect(binding, contains('WaffraProductionFinanceSource.manualRecoveryRequired'));
    expect(binding, contains('if (evidence == null)'));
    expect(binding, isNot(contains('WaffraEncryptedStore.openShadow(')));
    expect(widget, isNot(contains('FirebaseFirestore.instance')));
    expect(main, contains('requireSafeLegacyStartup'));
  });
}
