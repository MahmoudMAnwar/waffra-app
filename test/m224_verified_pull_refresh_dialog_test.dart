import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M224 pulls verified finance data instead of repainting stale UI', () {
    final code=File('lib/main.dart').readAsStringSync();
    expect(code,contains('Future<void> _refreshFromVerifiedFinance()async'));
    expect(code,contains('await _financialWriteQueue.drain()'));
    expect(code,contains('view.requireIntegrity()'));
    expect(code,contains('route:WaffraFinanceRoute.dashboardRead'));
    // M258 wraps the original verified read so the scroll position settles
    // only after successful finance loading; no stale UI read is introduced.
    expect(code,contains('refresh:_refreshFromVerifiedFinance'));
    expect(code,contains('onRefresh:()=>_refreshAndSettle('));
    expect(code,contains('isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null'));
    expect(code,contains('ScrollConfiguration.of(context).copyWith('));
    expect(code,contains('if(tab>0&&tab<4)'));
    expect(code,contains('Refreshed financial data could not be verified'));
    expect(code,contains('لم تُحذف أي معاملات'));
  });

  test('M224 recurring due reminder shows RTL-safe independent fields and equal-width actions', () {
    final code=File('lib/main.dart').readAsStringSync();
    expect(code,contains("'هل تم الدفع، أم ترغب في تأجيل الاستحقاق؟'"));
    expect(code,contains("Directionality(textDirection:TextDirection.ltr,"));
    expect(code,contains("actions:[SizedBox(width:min(330.0"));
    expect(code,contains("Expanded(child:FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'paid'))"));
    expect(code,contains("Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'postpone'))"));
    expect(code,contains("Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'later'))"));
  });

  test('M224 currency converter refresh invalidates FX and forces gold reload', () {
    final code=File('lib/currency_converter.dart').readAsStringSync();
    expect(code,contains('body:RefreshIndicator(onRefresh:_pullRefresh'));
    expect(code,contains("ValueKey('gold-refresh-"));
    expect(code,contains("if(amount.text.trim().isNotEmpty)await convert()"));
  });

  test('M224 original SMS legacy storage ban remains unchanged', () {
    final code=File('lib/main.dart').readAsStringSync();
    expect(code,contains('if(applied.originalSmsNotesOmittedOnLegacy)'));
    expect(code,contains('التخزين المشفر غير مفعّل'));
    expect(code,contains('notes:raw,sourceType:'));
  });
}
