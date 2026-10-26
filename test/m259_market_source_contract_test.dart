import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('FX, gold, oil accordion all wired and refresh clamped',(){
  final src=File('lib/currency_converter.dart').readAsStringSync();
  for(final id in ['currency','gold','oil']){
   expect(src,contains("id:'"+id+"'"));
   expect(src,contains("onPressed:WaffraHaptics.tapRequired(()=>toggleMarket('"+id+"'))"));
  }
  expect(src,contains("String? _openMarket='currency'"));
  expect(src,contains('WaffraGoldMarketSection('));
  expect(src,contains('WaffraGoldCalculatorPage('));
  expect(src,contains('WaffraOilMarketSection('));
  expect(src,contains('ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics())'));
  expect(src,contains('body:RefreshIndicator(onRefresh:_pullRefresh'));
 });
 test('No static invented oil quotes and no finance persistence',(){
  final oil=File('lib/waffra_oil_market_section.dart').readAsStringSync();
  final source=File('lib/waffra_oil_market_data.dart').readAsStringSync();
  expect(oil,contains('quote==null?'));
  expect(source,contains("fred.stlouisfed.org"));
  expect(source,contains("parseFredCsv("));
  expect(source.contains('SharedPreferences'),false);
  expect(source.contains('FirebaseFirestore'),false);
  expect(source.contains('waffra_finance'),false);
 });
}
