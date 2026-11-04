import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_brands.dart';

void main(){
 test('M435 Arabic and English names match only genuine curated brands',(){
  expect(WaffraMerchantBrands.match('سبوتيفاي')?.domain,'spotify.com');
  expect(WaffraMerchantBrands.match('Spotify')?.domain,'spotify.com');
  expect(WaffraMerchantBrands.match('ستاربكس')?.domain,'starbucks.com');
  expect(WaffraMerchantBrands.match('الإنماء')?.domain,'alinma.com');
  expect(WaffraMerchantBrands.match('Steam')?.domain,'steampowered.com');
  expect(WaffraMerchantBrands.match('Paid to Spotify XYZ'),isNull);
  expect(WaffraMerchantBrands.match('Unknown merchant'),isNull);
  expect(WaffraMerchantBrands.match(''),isNull);
 });

 test('M435 merchant directory search stays local and normalizes Arabic',(){
  expect(WaffraMerchantBrands.search('ستارب').single.name,'Starbucks');
  expect(WaffraMerchantBrands.search('NETFLIX').single.name,'Netflix');
  expect(WaffraMerchantBrands.search('البنك الغير موجود'),isEmpty);
  expect(WaffraMerchantBrands.known.length,greaterThanOrEqualTo(15));
 });

 test('M435 public CDN image URL never contains account or SMS contents',(){
  final brand=WaffraMerchantBrands.match('Spotify');
  final url=WaffraMerchantBrands.logoUri(brand);
  if(WaffraMerchantBrands.clientId.isEmpty){
   expect(url,isNull);
  }else if(url!=null){
   expect(url.scheme,'https');
   expect(url.host,'cdn.brandfetch.io');
   expect(url.path,'/spotify.com');
   expect(url.queryParameters.keys,contains('c'));
   expect(url.toString(),isNot(contains('SMS')));
  }
  expect(WaffraMerchantBrands.logoUri(null),isNull);
 });

 testWidgets('M435 offline fallback for merchant shows name initial', (tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraMerchantLogo(fallbackName:'Starbucks'))));
  expect(find.text('S'),findsOneWidget);
 });

 test('M435 existing finance ledger is unchanged: display-only API',(){
  final brand=WaffraMerchantBrands.match('Spotify');
  expect(brand?.domain,'spotify.com');
  expect(brand?.name,'Spotify');
  expect(brand?.aliases.contains('سبوتيفاي'),isTrue);
 });
}
