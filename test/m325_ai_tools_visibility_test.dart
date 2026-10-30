import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_smart_features.dart';

void main(){
 test('M325 tri-state visibility: never installed, active, later deleted',(){
  expect(waffraAiToolsState(modelReady:false,activatedBefore:false),
   WaffraAiToolsState.hidden);
  expect(waffraAiToolsState(modelReady:true,activatedBefore:false),
   WaffraAiToolsState.enabled);
  expect(waffraAiToolsState(modelReady:true,activatedBefore:true),
   WaffraAiToolsState.enabled);
  expect(waffraAiToolsState(modelReady:false,activatedBefore:true),
   WaffraAiToolsState.disabled);
 });

 testWidgets('M325 before first download show model installer but no AI tool',
   (tester)async{
  SharedPreferences.setMockInitialValues(<String,Object>{});
  await tester.pumpWidget(const MaterialApp(home:WaffraSmartFeaturesPage(
   entries:[],goals:[],recurring:[],english:false)));
  await tester.pump();
  expect(find.byKey(const Key('waffra-local-ai-opt-in')),findsOneWidget);
  expect(find.byKey(const Key('waffra-m268-feature-assistant')),findsNothing);
  expect(find.byKey(const Key('waffra-ai-financial-analysis')),findsNothing);
  expect(find.byKey(const Key('waffra-ai-saving-suggestions')),findsNothing);
  expect(find.byKey(const Key('waffra-m268-feature-markets')),findsOneWidget);
  expect(find.byKey(const Key('waffra-m268-feature-analysis')),findsOneWidget);
  expect(find.byKey(const Key('waffra-m268-feature-runway')),findsOneWidget);
 });

 test('M325 deleted model keeps historical AI tile locked and offers reinstall',(){
  final src=File('lib/waffra_smart_features.dart').readAsStringSync();
  final model=File('lib/waffra_ondevice_qwen.dart').readAsStringSync();
  expect(src,contains('if(i==4&&!_aiToolVisible)return null;'));
  expect(src,contains('final aiLocked=i==4&&_aiToolState==WaffraAiToolsState.disabled;'));
  expect(src,contains('onTap:aiLocked?null:'));
  expect(src,contains('enabled:!aiLocked'));
  expect(src,contains('onPressed:ready&&!aiBusy?'));
  expect(src,contains('waffra-local-ai-opt-in'));
  expect(src,contains('loadToolVisibilityHistory()'));
  expect(src,contains('waffra-ai-financial-analysis'));
  expect(src,contains('waffra-ai-saving-suggestions'));
  expect(model,contains('waffra_ai_model_ever_enabled_v1'));
  expect(model,contains('await _recordFirstActivation();'));
  expect(model,contains('Future<void> deleteDownloadedModel()async'));
  final delete=model.substring(model.indexOf('Future<void> deleteDownloadedModel()async'));
  expect(delete,isNot(contains('remove(_everEnabledKey)')));
  expect(delete,isNot(contains('_everEnabled=false')));
 });
}
