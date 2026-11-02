import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_country_first_run_page.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_google_phone_field.dart';
import 'package:waffra/waffra_phone_country_codes.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M315 country search accepts Arabic hamza/ya variants and dialing code',(){
  final jordan=WaffraInternationalPhone.byIso('JO');
  final saudi=WaffraInternationalPhone.byIso('SA');
  final egypt=WaffraInternationalPhone.byIso('EG');
  expect(WaffraInternationalPhone.matchesQuery(jordan,'الاردن'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(jordan,'الأُرْدُن'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(jordan,'Jordan'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(jordan,'+962'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(saudi,'السعوديه'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(egypt,'EG'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(egypt,'+20'),isTrue);
  expect(WaffraInternationalPhone.matchesQuery(jordan,'قطر'),isFalse);
  expect(WaffraInternationalPhone.matchesQuery(jordan,' '),isTrue);
  // Searching cannot modify the active app display currency.
  final previous=WaffraDisplayCurrency.country.code;
  WaffraInternationalPhone.matchesQuery(jordan,'الاردن');
  expect(WaffraDisplayCurrency.country.code,previous);
 });

 test('M318 national trunk prefixes do not corrupt E.164 country codes',(){
  final jordan=WaffraInternationalPhone.byIso('JO');
  final british=WaffraInternationalPhone.byIso('GB');
  final italy=WaffraInternationalPhone.byIso('IT');
  final philippines=WaffraInternationalPhone.byIso('PH');
  expect(WaffraInternationalPhone.e164(jordan,'0791234567'),
    '+962791234567');
  expect(WaffraInternationalPhone.e164(jordan,'791234567'),
    '+962791234567');
  expect(WaffraInternationalPhone.e164(british,'07123456789'),
    '+447123456789');
  expect(WaffraInternationalPhone.e164(italy,'0212345678'),
    '+390212345678',
    reason:'Italian fixed line zero is part of the international number');
  expect(WaffraInternationalPhone.e164(philippines,'09171234567'),
    '+639171234567');
  expect(WaffraInternationalPhone.e164(jordan,'00962791234567'),
    isNull,reason:'Do not accept 00 international dialing as local');
 });

 test('M301 Saudi/Egypt/Jordan dialing codes are independent of currency',(){
  final sa=WaffraInternationalPhone.byIso('SA');
  final eg=WaffraInternationalPhone.byIso('EG');
  final jo=WaffraInternationalPhone.byIso('JO');
  expect(sa.flag,'🇸🇦');
  expect(eg.dial,'+20');
  expect(jo.dial,'+962');
  expect(WaffraInternationalPhone.e164(sa,'0512345678'),'+966512345678');
  expect(WaffraInternationalPhone.e164(sa,'512345678'),'+966512345678');
  expect(WaffraInternationalPhone.e164(eg,'01234567890'),'+201234567890');
  expect(WaffraInternationalPhone.e164(jo,'791234567'),'+962791234567');
  expect(WaffraInternationalPhone.e164(sa,'12345'),isNull);
  expect(WaffraInternationalPhone.e164(eg,'501234567'),isNull);
  expect(WaffraInternationalPhone.e164(sa,'+966512345678'),isNull);
  expect(WaffraInternationalPhone.fromStored('+201234567890').country.iso,'EG');
  expect(WaffraInternationalPhone.fromStored('+201234567890').local,'1234567890');
  expect(WaffraInternationalPhone.fromStored('0512345678').country.iso,'SA');
 });

 test('M416 Saudi display ignores phone prefix and retains dormant global selection',()async{
  SharedPreferences.setMockInitialValues({
   'waffra_display_country_currency_v1':'JOD',
  });
  await WaffraDisplayCurrency.initialize();
  expect(WaffraDisplayCurrency.country.code,'SAR');
  expect(WaffraInternationalPhone.e164(
   WaffraInternationalPhone.byIso('SA'),'512345678'),'+966512345678');
  expect(WaffraDisplayCurrency.country.code,'SAR');
  await expectLater(WaffraDisplayCurrency.setCurrency('JOD'),throwsStateError);
  final prefs=await SharedPreferences.getInstance();
  expect(prefs.getString('waffra_display_country_currency_v1'),'JOD');
  expect(WaffraDisplayCurrency.displaySelection('JOD').code,'JOD');
 });

 testWidgets('M301 previously persisted currency survives different GPS country',(tester)async{
  SharedPreferences.setMockInitialValues({
   'waffra_display_country_currency_v1':'JOD',
  });
  await WaffraDisplayCurrency.initialize();
  expect(WaffraDisplayCurrency.country.code,'SAR');
  expect(WaffraDisplayCurrency.hasSavedPreference,isTrue);
  String? saved;
  await tester.pumpWidget(MaterialApp(home:WaffraCountryFirstRunPage(
   english:true,
   detectCountry:()async=>'SA',
   onComplete:(currency)async{saved=currency;},
  )));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m290-detect-country')));
  await tester.pumpAndSettle();
  expect(find.textContaining('manual selection is preserved'),findsWidgets);
  await tester.scrollUntilVisible(
   find.byKey(const Key('m290-setup-confirm')),160,
   scrollable:find.byType(Scrollable).first);
  await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m290-setup-confirm')));
  await tester.pumpAndSettle();
  expect(saved,'SAR');
  final prefs=await SharedPreferences.getInstance();
  expect(prefs.getString('waffra_display_country_currency_v1'),'JOD');
  WaffraDisplayCurrency.hasSavedPreference=false;
 });

 testWidgets('M301 manual currency survives later location detection',(tester)async{
  WaffraDisplayCurrency.active.value=
   WaffraDisplayCurrency.displaySelection('SAR');
  String? saved;
  await tester.pumpWidget(MaterialApp(home:WaffraCountryFirstRunPage(
   english:false,
   detectCountry:()async=>'SA',
   onComplete:(code)async{saved=code;},
  )));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m290-currency-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('مصر').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m290-detect-country')));
  await tester.pumpAndSettle();
  expect(find.textContaining('احتفظنا بعملتك'),findsWidgets);
  await tester.scrollUntilVisible(
   find.byKey(const Key('m290-setup-confirm')),160,
   scrollable:find.byType(Scrollable).first);
  await tester.ensureVisible(find.byKey(const Key('m290-setup-confirm')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m290-setup-confirm')));
  await tester.pumpAndSettle();
  expect(saved,'EGP');
 });

 testWidgets('M416 Google Saudi phone is plain 05 ten-digit input without flag or code',
 (tester)async{
  final controller=TextEditingController(text:'0512345678');
  final sa=WaffraInternationalPhone.byIso('SA');
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
   child:WaffraGooglePhoneField(
    controller:controller,country:sa,english:false,
    onChanged:(_){},onCountryChanged:(_){fail('Country picker must be disabled');})))));
  await tester.pumpAndSettle();
  expect(find.text('🇸🇦'),findsNothing);
  expect(find.text('+966'),findsNothing);
  expect(find.byKey(const Key('waffra-google-phone-country-picker')),findsNothing);
  expect(find.byKey(const Key('waffra-google-country-search')),findsNothing);
  final input=find.byKey(const Key('waffra-profile-mobile-number'));
  expect(input,findsOneWidget);
  expect(tester.widget<TextField>(input).decoration!.hintText,'05XXXXXXXX');
  await tester.enterText(input,'05123456789');
  await tester.pump();
  expect(controller.text,'0512345678',
   reason:'A Saudi mobile field must accept at most ten digits.');
  expect(tester.takeException(),isNull);
  controller.dispose();
 });
}
