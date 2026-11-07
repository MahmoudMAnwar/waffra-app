import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 testWidgets('M510 first clean install shows exactly two explicit auth choices',
  (tester) async {
   var created=0;
   var signedIn=0;
   await tester.pumpWidget(MaterialApp(home:IntroScreen(
    onStart:() async {created++;},
    onLogin:() async {signedIn++;},
   )));
   final create=find.byKey(const Key('waffra-auth-choice-create'));
   final login=find.byKey(const Key('waffra-auth-choice-sign-in'));
   expect(find.byKey(const Key('waffra-first-run-auth-choice')),findsOneWidget);
   expect(create,findsOneWidget);
   expect(login,findsOneWidget);
   // WaffraText can render the same label in multiple text descendants;
   // the two distinct clickable choice keys are the authoritative controls.
   expect(find.text('إنشاء حساب'),findsWidgets);
   expect(find.text('تسجيل الدخول'),findsWidgets);
   expect(find.byKey(const Key('waffra-register-single-page')),findsNothing);
   expect(find.byKey(const Key('waffra-register-phone')),findsNothing);
   await tester.tap(create);
   await tester.pump();
   expect(created,1);
   expect(signedIn,0);
   await tester.tap(login);
   await tester.pump();
   expect(created,1);
   expect(signedIn,1);
   expect(tester.takeException(),isNull);
 });

 test('M510 clean-install gates both forms behind an explicit choice, while old device keeps login',(){
  final src=File('lib/main.dart').readAsStringSync();
  final section=src.substring(
   src.indexOf('class LoginScreen extends StatefulWidget {'),
   src.indexOf('class ProfileForm extends StatefulWidget {'));
  expect(section,contains("if(_freshSignup&&_firstInstallChoice==null)return IntroScreen("));
  expect(section,contains("onStart:()async{if(mounted)setState(()=>_firstInstallChoice='create');}"));
  expect(section,contains("onLogin:()async{if(mounted)setState(()=>_firstInstallChoice='login');}"));
  expect(section,contains("if(_freshSignup&&_firstInstallChoice=='create')"));
  expect(section,contains("onBack:()=>setState(()=>_firstInstallChoice=null)"));
  expect(section,contains("(_freshSignup&&_firstInstallChoice=='login')"));
  expect(section,contains("signInMode=oldUser?.provider.toLowerCase()=='phone'"));
  expect(section,contains("returnAfterLogout=signedOut;"));
  expect(section,contains("!hasOldProfile&&!hasLegacyVerifier&&"));
  expect(section,contains("!hasSecureVerifier;"));
  expect(section,isNot(contains("if(_freshSignup)return ProfileForm(")));
  // Do not introduce an account or persistence write on a pure choice tap.
  final start=src.substring(
   src.indexOf('class IntroScreen extends StatefulWidget {'),
   src.indexOf('class LoginScreen extends StatefulWidget {'));
  expect(start,isNot(contains('saveProfile(')));
  expect(start,isNot(contains('SharedPreferences.getInstance()')));
 });

 test('M510 one-screen existing phone registration and safe Back are retained',(){
  final src=File('lib/main.dart').readAsStringSync();
  final section=src.substring(
   src.indexOf('class ProfileForm extends StatefulWidget {'),
   src.indexOf('class HomeScreen extends StatefulWidget {'));
  expect(section,contains("key:const Key('waffra-register-single-page')"));
  expect(section,contains("key:const Key('waffra-register-name')"));
  expect(section,contains("key:const Key('waffra-register-phone')"));
  // The two stable keys are attached by a conditional ChoiceChip key.
  expect(section,contains(
    "key:Key(g=='ذكر'?'waffra-register-gender-male':'waffra-register-gender-female')"));
  expect(section,contains("onPressed:WaffraHaptics.tap(widget.onBack)"));
 });
}
