import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_country_first_run_page.dart';
import 'package:waffra/waffra_country_suggestion.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M290 Egypt, Saudi, UAE and eurozone suggest supported currencies', () {
    expect(WaffraCountrySuggestion.currencyForIsoCountry('EG'), 'EGP');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('sa'), 'SAR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('AE'), 'AED');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('FR'), 'EUR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('??'), isNull);
    expect(WaffraCountrySuggestion.currencyForIsoCountry(null), isNull);
    for (final value in WaffraCountrySuggestion.byIsoCountry.values) {
      expect(waffraCountryCurrencies.any((c) => c.code == value), isTrue);
    }
  });

  test('M290 shows location setup only for completed Google profiles', () {
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

  test('M290 Google phone supports Egypt and Saudi international numbers', () {
    expect(waffraGoogleProfilePhoneError('+201234567890'), isNull);
    expect(waffraGoogleProfilePhoneError('+966512345678'), isNull);
    expect(waffraGoogleProfilePhoneError('0512345678'), isNull);
    expect(waffraGoogleProfilePhoneError(''), isNotNull);
    expect(waffraGoogleProfilePhoneError('12345'), isNotNull);
    expect(waffraGoogleProfilePhoneError('++201234567890'), isNotNull);
    expect(waffraMobileFieldError('+201234567890'), isNotNull,
      reason: 'Non-Google local phone login still uses approved 05 format.');
  });

  testWidgets('M290 reason shown first; only tapping location starts detection',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    addTearDown(() => WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR'));
    var gpsCalls = 0;
    String? savedCurrency;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: false,
      detectCountry: () async { gpsCalls++; return 'EG'; },
      onComplete: (currency) async { savedCurrency = currency; },
    )));
    await tester.pumpAndSettle();
    expect(gpsCalls, 0);
    expect(find.textContaining('الموقع'), findsWidgets);
    expect(find.byKey(const Key('m290-recurring-notification-toggle')),
      findsNothing, reason: 'Login never prompts for notifications.');
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(gpsCalls, 1);
    expect(find.textContaining('مصر'), findsWidgets);
    expect(WaffraDisplayCurrency.country.code, 'SAR',
      reason: 'Detection is a recommendation, not an automatic currency switch.');
    await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(savedCurrency, 'EGP');
  });

  testWidgets('M290 denying location leaves manual currency and Skip usable',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    String? chosen;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: true,
      detectCountry: () async { calls++; return null; },
      onComplete: (currency) async { chosen = currency; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('unavailable or denied'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('m290-setup-skip')));
    await tester.tap(find.byKey(const Key('m290-setup-skip')));
    await tester.pumpAndSettle();
    expect(chosen, 'SAR');
  });

  testWidgets('M290 Skip does not access GPS or notifications',
      (tester) async {
    var locationCalls = 0;
    String? chosen;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: true,
      detectCountry: () async { locationCalls++; return 'SA'; },
      onComplete: (currency) async { chosen = currency; },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('m290-setup-skip')));
    await tester.tap(find.byKey(const Key('m290-setup-skip')));
    await tester.pumpAndSettle();
    expect(locationCalls, 0);
    expect(chosen, isNotNull);
  });

  test('M290 permissions are triggered only by the relevant user action', () {
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
    expect(main, contains('WaffraDisplayCurrency.setCurrency(selectedCurrency)'));
    expect(main, contains('WaffraReminders.requestPermission()'));
    expect(main, contains('_financeAuthority.setRecurringReminderPreference(enabled)'));
    expect(main, isNot(contains('_applyApprovedGoogleReminderSetup()')));
    expect(onboarding, contains('WaffraCountrySuggestion.detectCountry()'));
    expect(onboarding, isNot(contains('askNotificationPermission')));
    expect(onboarding, isNot(contains('WaffraReminders.requestPermission()')));
    expect(country, contains('Geolocator.requestPermission()'));
    expect(country, contains('LocationAccuracy.low'));
    expect(reminders, contains('FlutterTimezone.getLocalTimezone()'));
    expect(reminders, contains('tz.getLocation(identifier)'));
    expect(reminders, isNot(contains("tz.getLocation('Asia/Riyadh')")));
    expect(main, contains('source:ImageSource.camera,imageQuality:80'));
    expect(main, contains('await ImagePicker().pickMultiImage(imageQuality:80)'));
    expect(main, contains('نطلب صلاحية الكاميرا')); // consent wording in UI
  });
}
