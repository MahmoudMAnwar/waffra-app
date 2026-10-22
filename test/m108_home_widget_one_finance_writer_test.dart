import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M108 both live widget and dashboard call one verified SMS journal', () {
    final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    final home=File('lib/main.dart').readAsStringSync();
    final journal=File('lib/storage/waffra_home_finance_persistence.dart')
        .readAsStringSync();

    expect(widget, contains('_financePersistence.commitConfirmedLegacySms('));
    expect(home, contains('_homeFinancePersistence.commitConfirmedLegacySms('));
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

    expect(widget, contains('requireSafeLegacyStartup'));
    expect(widget, isNot(contains('FirebaseFirestore.instance')));
    expect(main, contains('requireSafeLegacyStartup'));
  });
}
