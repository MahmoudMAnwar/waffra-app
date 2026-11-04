import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_today_picker.dart';

void main() {
  test('M399 historical dates clamp only for display; valid dates unchanged', () {
    final first=DateTime(2026,1,1,15);
    final last=DateTime(2026,12,31,16);
    expect(waffraBoundedCalendarInitialDate(
      DateTime(2025,12,31),first,last),DateTime(2026,1,1));
    expect(waffraBoundedCalendarInitialDate(
      DateTime(2027,1,1),first,last),DateTime(2026,12,31));
    expect(waffraBoundedCalendarInitialDate(
      DateTime(2026,4,20,18,30),first,last),DateTime(2026,4,20));
    expect(waffraBoundedCalendarInitialDate(
      DateTime(2026,4,20),last,first),isNull);
  });

  testWidgets('M399 out-of-window old transaction can cancel without edit',
      (tester) async {
    DateTime? result;
    var finished=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Builder(builder:(context)=>ElevatedButton(
        onPressed:()async {
          result=await waffraPickDateWithToday(
            context:context,english:true,
            initialDate:DateTime(2020,1,1),
            firstDate:DateTime(2026,1,1),
            lastDate:DateTime(2026,12,31),
          );
          finished=true;
        },
        child:const Text('Open calendar'),
      )),
    )));
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-datepicker-confirm')),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(finished,isTrue);
    expect(result,isNull);
  });

  testWidgets('M399 out-of-window selection requires explicit Confirm',
      (tester) async {
    DateTime? result;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Builder(builder:(context)=>ElevatedButton(
        onPressed:()async {
          result=await waffraPickDateWithToday(
            context:context,english:true,
            initialDate:DateTime(2028,2,1),
            firstDate:DateTime(2026,1,1),
            lastDate:DateTime(2026,12,31),
          );
        },
        child:const Text('Select date'),
      )),
    )));
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    expect(result,isNull);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const Key('waffra-datepicker-confirm')));
    await tester.pumpAndSettle();
    expect(result,DateTime(2026,12,31));
  });
}
