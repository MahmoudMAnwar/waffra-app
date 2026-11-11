import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smart_features.dart';

void main(){
 test('M636 Tools no longer exposes AI model download, Ask, or installer',(){
  final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
  expect(tools,isNot(contains('WaffraOnDeviceQwen')));
  expect(tools,isNot(contains('waffra-local-ai-opt-in')));
  expect(tools,isNot(contains('waffra-ai-financial-analysis')));
  expect(tools,isNot(contains('waffra-ai-saving-suggestions')));
  expect(tools,isNot(contains("'assistant',")));
  expect(tools,contains("'runway','subscription','simulation','guardian'"));
 });
 testWidgets('M636 real finance Tools remain usable without any model',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:WaffraSmartFeaturesPage(
   entries:[],goals:[],recurring:[],english:false)));
  await tester.pump();
  expect(find.byKey(const Key('waffra-local-ai-opt-in')),findsNothing);
  expect(find.byKey(const Key('waffra-m268-feature-assistant')),findsNothing);
  expect(find.byKey(const Key('waffra-m268-feature-analysis')),findsOneWidget);
  expect(find.byKey(const Key('waffra-m268-feature-markets')),findsOneWidget);
 });
}
