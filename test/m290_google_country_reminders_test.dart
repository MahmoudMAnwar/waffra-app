import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_country_first_run_page.dart';
import 'package:waffra/waffra_country_suggestion.dart';
import 'package:waffra/waffra_display_currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M290 Egypt, Saudi Arabia, Gulf and eurozone map to suggested currency', () {
    expect(WaffraCountrySuggestion.currencyForIsoCountry('EG'), 'EGP');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('sa'), 'SAR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('AE'), 'AED');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('FR'), 'EUR');
    expect(WaffraCountrySuggestion.currencyForIsoCountry('??'), isNull);
    expect(WaffraCountrySuggestion.currencyForIsoCountry(null), isNull);
    expect(WaffraCountrySuggestion.currencyForIsoCountry(''), isNull);
  });

  test('M290 supported countries always map to a supported display unit', () {
    for (final currency in WaffraCountrySuggestion.byIsoCountry.values) {
      expect(waffraCountryCurrencies.any((c) => c.code == currency), isTrue,
        reason: 'Unsupported proposed currency $currency');
    }
  });

  testWidgets('M290 explicit location consent suggests Egyptian pounds without changing ledger',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    addTearDown(() => WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR'));
    var detectionCalls = 0, permissionCalls = 0;
    String? completedCurrency;
    bool? reminders;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: false,
      detectCountry: () async {
        detectionCalls++;
        return 'EG';
      },
      askNotificationPermission: () async {
        permissionCalls++;
        return true;
      },
      onComplete: (currency, enabled) async {
        completedCurrency = currency;
        reminders = enabled;
      },
    )));
    await tester.pumpAndSettle();
    expect(detectionCalls, 0);
    expect(permissionCalls, 0);
    expect(find.byKey(const Key('m290-detect-country')), findsOneWidget);
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(detectionCalls, 1);
    expect(find.textContaining('مصر'), findsWidgets);
    expect(find.byKey(const Key('m290-country-feedback')), findsOneWidget);
    expect(WaffraDisplayCurrency.country.code, 'SAR',
      reason: 'Detecting location must never silently re-label finance.');
    await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(completedCurrency, 'EGP');
    expect(reminders, false);
    expect(permissionCalls, 0);
  });

  testWidgets('M290 notification opt-in prompts only after user accepts',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    var locationCalls = 0, notificationCalls = 0;
    bool? granted;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: true,
      detectCountry: () async {
        locationCalls++;
        return 'SA';
      },
      askNotificationPermission: () async {
        notificationCalls++;
        return true;
      },
      onComplete: (currency, notifications) async {
        granted = notifications;
        expect(currency, 'SAR');
      },
    )));
    await tester.pumpAndSettle();
    expect(locationCalls, 0);
    expect(notificationCalls, 0);
    await tester.ensureVisible(
      find.byKey(const Key('m290-recurring-notification-toggle')));
    await tester.tap(find.byKey(
      const Key('m290-recurring-notification-toggle')));
    await tester.pumpAndSettle();
    expect(notificationCalls, 0);
    await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(notificationCalls, 1);
    expect(granted, true);
    expect(locationCalls, 0);
  });

  testWidgets('M290 denied location still allows skipping onboarding',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    var notificationCalls = 0;
    String? choice;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: false,
      detectCountry: () async => null,
      askNotificationPermission: () async {
        notificationCalls++;
        return false;
      },
      onComplete: (currency, reminders) async { choice = currency; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('m290-detect-country')));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحديد البلد'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('m290-setup-skip')));
    await tester.tap(find.byKey(const Key('m290-setup-skip')));
    await tester.pumpAndSettle();
    expect(choice, 'SAR');
    expect(notificationCalls, 0);
  });

  testWidgets('M290 denied notifications do not enable recurring payments',
      (tester) async {
    WaffraDisplayCurrency.active.value =
      WaffraDisplayCurrency.displaySelection('SAR');
    var completed = false;
    await tester.pumpWidget(MaterialApp(home: WaffraCountryFirstRunPage(
      english: true,
      askNotificationPermission: () async => false,
      onComplete: (_, __) async { completed = true; },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('m290-recurring-notification-toggle')));
    await tester.tap(find.byKey(
      const Key('m290-recurring-notification-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(completed, false);
    expect(find.textContaining('Notifications not permitted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('m290-setup-confirm')));
    await tester.pumpAndSettle();
    expect(completed, true);
  });

  test('M290 Google gate and reminder authority stay linked to verified source', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('googleFirstRunSetup?WaffraCountryFirstRunPage('));
    expect(main, contains("'waffra_google_country_setup_completed_v1'"));
    expect(main, contains('WaffraDisplayCurrency.setCurrency(selectedCurrency)'));
    expect(main, contains('await toggleRecurringReminders(true)'));
    expect(main, contains('_financeAuthority.setRecurringReminderPreference(enabled)'));
    final reminders = File('lib/waffra_reminders.dart').readAsStringSync();
    expect(reminders, contains('FlutterTimezone.getLocalTimezone()'));
    expect(reminders, contains('tz.getLocation(identifier)'));
    expect(reminders, isNot(contains("tz.getLocation('Asia/Riyadh')")));
  });
}
