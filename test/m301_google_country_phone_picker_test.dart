import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_country_first_run_page.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_google_phone_field.dart';
import 'package:waffra/waffra_phone_country_codes.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

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

 test('M301 saved display currency is not derived from phone prefix',()async{
  SharedPreferences.setMockInitialValues({});
  await WaffraDisplayCurrency.initialize();
  await WaffraDisplayCurrency.setCurrency('JOD');
  expect(WaffraDisplayCurrency.country.code,'JOD');
  expect(WaffraInternationalPhone.e164(
   WaffraInternationalPhone.byIso('SA'),'512345678'),'+966512345678');
  expect(WaffraDisplayCurrency.country.code,'JOD');
  await WaffraDisplayCurrency.initialize();
  expect(WaffraDisplayCurrency.country.code,'JOD');
  WaffraDisplayCurrency.active.value=
   WaffraDisplayCurrency.displaySelection('SAR');
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
  await tester.tap(find.byKey(const Key('m290-setup-confirm')));
  await tester.pumpAndSettle();
  expect(saved,'EGP');
 });

 testWidgets('M301 Google mobile shows flag inside same field and searchable countries',
 (tester)async{
  final controller=TextEditingController(text:'512345678');
  WaffraPhoneCountry country=WaffraInternationalPhone.byIso('SA');
  await tester.pumpWidget(StatefulBuilder(builder:(context,rebuild)=>
   MaterialApp(home:Scaffold(body:Center(child:
    WaffraGooglePhoneField(
     controller:controller,country:country,english:false,
     onChanged:(_){},
     onCountryChanged:(selected)=>rebuild(()=>country=selected)))))));
  await tester.pumpAndSettle();
  expect(find.text('🇸🇦'),findsOneWidget);
  expect(find.text('+966'),findsOneWidget);
  await tester.tap(find.byKey(const Key('waffra-google-phone-country-picker')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('waffra-google-country-search')),'Jordan');
  await tester.pumpAndSettle();
  expect(find.text('🇯🇴'),findsOneWidget);
  await tester.tap(find.byKey(const Key('waffra-phone-country-JO')));
  await tester.pumpAndSettle();
  expect(country.iso,'JO');
  expect(find.text('+962'),findsOneWidget);
  expect(tester.takeException(),isNull);
  controller.dispose();
 });
}
