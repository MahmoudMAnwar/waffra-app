import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show defaultCategories;
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
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
      // Reproduce the *actual* first-Home startup that was missing in M440.
      // Only a verified, real Android fresh SQLCipher origin may add the two
      // absent defaults; neither the source key nor user finance is replaced.
      final catalog = jsonEncode(
        defaultCategories().map((category) => category.toJson()).toList(),
      );
      final source = await WaffraFreshHomeCatalogRecovery.load(
        authority: home.authority,
        defaultCategoriesJson: catalog,
      );
      expect(source.ledgerRaw, '[]');
      expect(source.finance.getString('waffra_categories_v24'), catalog);
      expect(jsonDecode(source.ledgerRaw!), isEmpty);
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
      final catalogAfter = read.finance.getString('waffra_categories_v24');
      expect(catalogAfter, isNotNull);
      expect((jsonDecode(catalogAfter!) as List).length,
        defaultCategories().length);
      expect((await SharedPreferences.getInstance()).containsKey('entries'),isFalse);
      expect((await SharedPreferences.getInstance())
        .containsKey('waffra_categories_v24'),isFalse);
    } finally { await reopened.close(); }
  });
}
