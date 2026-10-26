import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_market_accordion.dart';

void main(){
 testWidgets('opening another market closes the previous market', (tester)async {
  var opened='currency';
  await tester.pumpWidget(MaterialApp(home:StatefulBuilder(
   builder:(context,setState)=>Scaffold(body:ListView(children:[
    for(final id in ['currency','gold','oil'])
     WaffraMarketAccordionCard(id:id,title:id,subtitle:'market',
      icon:Icons.currency_exchange,
      accent:Colors.green,expanded:opened==id,
      onPressed:()=>setState(()=>opened=opened==id?'':id),
      child:Text('content-'+id,key:Key('content-'+id))),
   ])))));
  expect(find.byKey(const Key('content-currency')),findsOneWidget);
  expect(find.byKey(const Key('content-oil')),findsNothing);
  await tester.tap(find.byKey(const Key('waffra-market-toggle-oil')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('content-currency')),findsNothing);
  expect(find.byKey(const Key('content-oil')),findsOneWidget);
  await tester.tap(find.byKey(const Key('waffra-market-toggle-oil')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('content-oil')),findsNothing);
 });
}
