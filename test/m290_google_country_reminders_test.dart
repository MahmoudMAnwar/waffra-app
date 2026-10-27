import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_country_first_run_page.dart';
import 'package:waffra/waffra_country_suggestion.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M290 Egypt, Saudi Arabia and other countries map to supported currency', () {
    expect(WaffraCountrySuggestion.currencyForIsoCountry('EG'), 'EGP');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('sa'), 'SAR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('AE'), 'AED');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('FR'), 'EUR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('??'), isNull);
    expect(WaffraCountrySuggestion.currencyForIsoCountry(null), isNull);
    for (final currency in WaffraCountrySuggestion.byIsoCountry.values) {
      expect(waffraCountryCurrencies.any((c) => c.code == currency), isTrue);
    }
  });

  test('M290 first-run gate only after completed real Google profile', () {
    Person profile({
      String provider = 'Google', String phone = '0512345678',
      String gender = 'ذكر', String email = 'fixture@example.com',
    }) => Person(
      name: 'Test account', provider: provider, phone: phone,
      email: email, gender: gender, avatar: 'person',
      birthday: DateTime(2000),
    );
    expect(waffraGoogleProfileReadyForCountrySetup(profile()), isTrue);
    expect(waffraGoogleProfileReadyForCountrySetup(profile(phone: '')), isFalse);
    expect(waffraGoogleProfileReadyForCountrySetup(profile(gender: '')), isFalse);
    expect(waffraGoogleProfileReadyForCountrySetup(profile(email: '')), isFalse);
    expect(waffraGoogleProfileReadyForCountrySetup(
      profile(provider: 'Local')), isFalse);
    expect(waffraGoogleProfileReadyForCountrySetup(null), isFalse);
    expect(waffraCountrySetupKey(profile()),
      waffraCountrySetupKey(profile(email: 'FIXTURE@EXAMPLE.COM')));
    expect(waffraCountrySetupKey(profile()),
      isNot(contains('fixture@example.com')));
    expect(waffraCountrySetupKey(profile()),
      isNot(waffraCountrySetupKey(profile(email: 'other@example.com'))));
  });

  testWidgets('M290 location rationale appears before OS prompt and Egyptian currency suggested',
      (tester) async {
    WaffraDisplayCurrency.active.value =
        WaffraDisplayCurrency.displaySelection('SAR');
    addTearDown(() => WaffraDisplayCurrency.active.value =
        WaffraDisplayCurrency.displaySelection('SAR'));
    var detectionCalls = 0;
    String? completedCurrency;
    await tester.pumpWidget(MaterialApp(
      home: WaffraCountryFirstRunPage(
        english: false,
        detectCountry: () async {
          detectionCalls++;
          return 'EG';
        },
        onComplete: (currency) async => completedCurrency = currency,
      ),
    ));
    await tester.pumpAndSettle();
    expect(detectionCalls, 0, reason:
      'Showing a rationale must not silently call the OS location prompt.');
    expect(find.textContaining('مرة واحدة'), findsWidgets);
    expect(find.byKey(const Key('m290-detect-country')), findsOneWidget);
    expect(find.byKey(const Key('m290-recurring-notification-toggle')),
      findsNothing, reason: 'Notification consent belongs to Recurring.');
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(detectionCalls, 1);
    expect(find.textContaining('مصر'), findsWidgets);
    expect(find.byKey(const Key('m290-country-feedback')), findsOneWidget);
    expect(WaffraDisplayCurrency.country.code, 'SAR',
      reason: 'Location never silently changes app display preference.');
    await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(completedCurrency, 'EGP');
  });

  testWidgets('M290 country detection is optional: denial and skip never block app',
      (tester) async {
    WaffraDisplayCurrency.active.value =
        WaffraDisplayCurrency.displaySelection('SAR');
    var detectionCalls = 0;
    String? completedCurrency;
    await tester.pumpWidget(MaterialApp(
      home: WaffraCountryFirstRunPage(
        english: true,
        detectCountry: () async {
          detectionCalls++;
          return null;
        },
        onComplete: (currency) async => completedCurrency = currency,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable or denied'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('m290-setup-skip')));
    await tester.tap(find.byKey(const Key('m290-setup-skip')));
    await tester.pumpAndSettle();
    expect(detectionCalls, 1);
    expect(completedCurrency, 'SAR');
  });

  testWidgets('M290 skip without location access never invokes country provider',
      (tester) async {
    var calls = 0;
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: WaffraCountryFirstRunPage(
        english: false,
        detectCountry: () async { calls++; return 'SA'; },
        onComplete: (code) async => chosen = code,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('m290-setup-skip')));
    await tester.tap(find.byKey(const Key('m290-setup-skip')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(chosen, isNotNull);
  });

  test('M290 permission sources never request broad location or media access at boot', () {
    final main = File('lib/main.dart').readAsStringSync();
    final onboarding = File('lib/waffra_country_first_run_page.dart')
        .readAsStringSync();
    final country = File('lib/waffra_country_suggestion.dart')
        .readAsStringSync();
    final reminders = File('lib/waffra_reminders.dart')
        .readAsStringSync();
    expect(main, contains('googleFirstRunSetup?WaffraCountryFirstRunPage('));
    expect(main, contains('waffraGoogleProfileReadyForCountrySetup(u)'));
    expect(main, contains('waffraCountrySetupKey('));
    expect(main, contains('await WaffraDisplayCurrency.setCurrency(selectedCurrency)'));
    expect(main, contains('await WaffraReminders.requestPermission()'));
    expect(main, contains('_financeAuthority.setRecurringReminderPreference(enabled)'));
    expect(onboarding, contains('WaffraCountrySuggestion.detectCountry()'));
    expect(onboarding, isNot(contains('WaffraReminders.requestPermission()')));
    expect(onboarding, isNot(contains('askNotificationPermission')));
    expect(country, contains('Geolocator.requestPermission()'));
    expect(country, isNot(contains('LocationAccuracy.best')));
    expect(country, isNot(contains('LocationAccuracy.high')));
    expect(reminders, contains('FlutterTimezone.getLocalTimezone()'));
    expect(reminders, contains('tz.getLocation(identifier)'));
    expect(reminders, isNot(contains("tz.getLocation('Asia/Riyadh')")));
  });
}
