import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scope-only guard. Full Flutter, PDF rendering and Android ARM64 CI must
/// separately succeed before this branch is eligible for review or merge.
void main() {
  test('Waffra approved PDF analytics keeps chart content and real data together', () {
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains('final chartPanels=parts.skip(1).toList(growable:false)'));
    expect(app,contains('dataTable(valueHeaders,periodValues)'));
    expect(app,contains('smartData.weeklySpend.length'));
    expect(app,contains('top.map((e)=><String>['));
    expect(app,contains('children:english?orderedCells:orderedCells.reversed.toList()'));
    expect(app,contains("['المبلغ (ريال)','الوصف','القسم','النوع','التاريخ','رقم المعاملة']"));
  });

  test('Recurring section has count chip, compact reminders and nearest bill', () {
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains("Key('waffra-recurring-count-badge')"));
    expect(app,contains('nextRecurringDue(nextBill)'));
    expect(app,contains('Switch.adaptive(value:recurringRemindersEnabled'));
    expect(app,contains("المحذوفة ("));
    expect(app,contains('Financial calendar'));
  });

  test('Currency converter searchable currencies, directional swap, financial tools', () {
    final app=File('lib/main.dart').readAsStringSync();
    final converter=File('lib/currency_converter.dart').readAsStringSync();
    expect(app,contains("Financial tools':'الأدوات المالية'"));
    expect(app,contains("builder:(_)=>const CurrencyConverterPage()"));
    expect(converter,contains("Key('waffra-currency-swap')"));
    expect(converter,contains('void swapCurrencies()'));
    expect(converter,contains('unawaited(convert())'));
    expect(converter,contains('selectCurrency(bool source)'));
    for(final currency in ['SAR','EGP','USD','EUR','GBP','AED','KWD','BHD','OMR','QAR','JOD','JPY','CAD','TRY']){
      expect(converter,contains("'$currency':"));
    }
  });

  test('M207 SMS plaintext rejection remains enabled in the active legacy writer', () {
    final writer=File('lib/storage/waffra_home_finance_persistence.dart').readAsStringSync();
    expect(writer,contains('WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)'));
    expect(writer,contains('WaffraLegacySmsNotesPrivacyGate.rejectNewOrModifiedSmsNotes('));
    expect(writer,contains('version != 2 && version != 3 && version != 4'));
    final bridge=File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    expect(bridge,contains("return Map<String, Object?>.unmodifiable({...record, 'notes': ''});"));
    expect(bridge,contains('originalSmsNotesOmittedOnLegacy'));
    final release=File('lib/storage/waffra_production_cutover_release_gate.dart').readAsStringSync();
    expect(release,contains('bool get automaticallyActivateSqlCipher => false;'));
  });
}
