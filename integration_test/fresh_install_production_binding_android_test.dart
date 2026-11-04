import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_finance_authority_binding.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('clean Android install and widget reopen the same production vault', (_) async {
    Future<WaffraProductionFinanceAuthorityBinding> bind(WaffraFinanceRoute route) =>
        WaffraProductionFinanceAuthorityBinding.bind(installedApp:true,
          legacy:const WaffraHomeFinancePersistence(),startupRoute:route);
    final home = await bind(WaffraFinanceRoute.appStartup);
    try {
      expect(home.encrypted,isTrue);
      final source = await home.authority.load(route:WaffraFinanceRoute.dashboardRead);
      expect(jsonDecode(source.ledgerRaw ?? '[]'),isEmpty);
    } finally { await home.close(); }
    final widget = await bind(WaffraFinanceRoute.widgetStartup);
    try {
      expect(widget.encrypted,isTrue);
      final posted = await widget.authority.commitConfirmedSms(
        route:WaffraFinanceRoute.widgetSmsConfirmedSave,userConfirmed:true,
        records:[{'id':'fresh-widget','title':'QA','category':'Food','amount':12.34,
          'income':false,'date':'2026-11-04T12:00:00','receiptPath':null,'sourceType':'sms','notes':''}],
        hashes:[List.filled(64,'a').join()]);
      expect(posted.expenseMinor,1234);
    } finally { await widget.close(); }
    final reopened = await bind(WaffraFinanceRoute.appStartup);
    try {
      final read = await reopened.authority.load(route:WaffraFinanceRoute.dashboardRead);
      final row = (jsonDecode(read.ledgerRaw!) as List).single as Map;
      expect(row['id'],'fresh-widget');
      expect(row['amount'],12.34);
      expect((await SharedPreferences.getInstance()).containsKey('entries'),isFalse);
    } finally { await reopened.close(); }
  });
}
