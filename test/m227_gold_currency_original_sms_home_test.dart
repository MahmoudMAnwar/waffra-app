import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  test('M227 nominal 1,000 stays 1,000 after changing SAR to EGP', () {
    final selected = WaffraDisplayCurrency.displaySelection('EGP');
    expect(selected.displayOnly, isTrue);
    expect(selected.fromSar(1000), 1000);
    expect(selected.toSar(1000), 1000);
    expect(WaffraDisplayCurrency.displaySelection('SAR').fromSar(1000), 1000);
  });

  test('M227 gold stays accessible through the new inline Tools markets accordion', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains("Key('waffra-home-gold-currency-entry')")));
    expect(source, contains('case 2:return _smartToolsTab();'));
    final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(tools, contains("'waffra-m268-feature-'+id"));
    expect(tools, contains("'markets'"));
    expect(tools, contains('CurrencyConverterPage(embedded:true)'));
    final converter = File('lib/currency_converter.dart').readAsStringSync();
    expect(converter, contains('محوّل العملات وأسعار الذهب العالمية'));
    expect(converter, contains('WaffraGoldMarketSection('));
    expect(converter,contains('WaffraOilMarketSection('));
    expect(converter,contains('waffra-inline-world-markets'));
    final gold = File('lib/waffra_gold_market_section.dart').readAsStringSync();
    expect(gold, contains('أسعار الذهب العالمية'));
    expect(gold, contains('Gold bars'));
  });

  test('M227 full SMS is read from protected vault for details', () {
    final home = File('lib/main.dart').readAsStringSync();
    final bind = File('lib/storage/waffra_production_finance_authority_binding.dart')
        .readAsStringSync();
    final authority = File('lib/storage/waffra_verified_finance_authority.dart')
        .readAsStringSync();
    expect(home, contains('readProtectedOriginalSms(entry.id)'));
    expect(home, contains("if(entry.sourceType=='sms'){"));
    expect(home, contains('protectedOriginalSms:originalBankSms'));
    expect(home, contains("Key('waffra-transaction-personal-notes')"));
    expect(home, contains("Key('waffra-transaction-protected-bank-sms')"));
    expect(home, isNot(contains("entry.sourceType=='sms'&&entry.notes.isEmpty")));
    expect(bind, contains('protectedSmsNotes: const WaffraEncryptedSmsNotesVault()'));
    expect(authority, contains('protectedNotesBeforeLegacyCommit:'));
    expect(authority, contains("'notes': ''"));
    final privacy = File('lib/storage/waffra_home_finance_persistence.dart')
        .readAsStringSync();
    expect(privacy, contains('WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)'));
  });

  test('M227 preserves merged M226 FAB timings', () {
    final home = File('lib/main.dart').readAsStringSync();
    expect(home, contains('await Future<void>.delayed(waffraMotion(165));'));
    expect(home, contains('await Future<void>.delayed(waffraMotion(110));'));
    expect(home, contains('duration:waffraMotion(220)'));
    expect(home, contains('Duration(milliseconds:380)'));
  });
}
