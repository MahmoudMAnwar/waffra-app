import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  final directory = File('lib/waffra_budget_directory.part.dart')
      .readAsStringSync();

  test('M398: My Budgets can be opened again without restoring root tile state', () {
    expect(directory, contains('showModalBottomSheet<void>('));
    expect(directory, contains('DraggableScrollableSheet('));
    expect(directory, contains('controller:scroll'));
    expect(directory, contains('showDragHandle:true'));
    // The sheet itself scrolls. Never nest the entire panel in another
    // persisted ExpansionTile: that state survived closing/reopening.
    expect(directory, isNot(contains('waffra-my-budgets-directory-sheet')));
    expect(directory, contains('child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:['));
    expect(directory, contains('var directoryScope=\'all\';'));
    expect(directory, contains('refreshFromBudgetDirectory();'));
  });

  test('M398: My added budgets filter excludes unadded suggestions only', () {
    expect(directory, contains("'waffra-budget-directory-scope-'"));
    expect(directory, contains("'Budgets I added'"));
    expect(directory, contains("'ميزانياتي المضافة بواسطتي'"));
    expect(directory, contains("if(scope!='mine')ExpansionTile("));
    expect(directory, contains('final saved=namedBudgets.where((b)=>!b.deleted).toList()'));
    expect(directory, contains('onScopeChanged:(value)=>refresh(()=>directoryScope=value)'));
    // Status and query continue filtering real persisted budgets.
    expect(directory, contains("budgetStatusFilter=='active'"));
    expect(directory, contains("budgetStatusFilter=='inactive'"));
    expect(directory, contains('waffraSearchAny('));
  });

  test('M398: saved and migrated budgets remain user-owned financial records', () {
    final owned = WaffraNamedBudget(
      id: 'budget:owned', name: 'الوقود', budget: 200,
    );
    final legacy = WaffraNamedBudget.fromLegacy(BudgetCategory(
      id: 'category-old', name: 'الأكل', icon: 'restaurant',
      color: 0xFF087A54, income: false, budget: 300,
    ));
    expect(WaffraNamedBudget.fromJson(owned.toJson()).id, 'budget:owned');
    expect(WaffraNamedBudget.fromJson(legacy.toJson()).id, 'category-old');
    expect(WaffraNamedBudget.fromJson(legacy.toJson()).budget, 300);
    expect(owned.toJson().containsKey('categoryId'), isFalse);
    expect(legacy.toJson().containsKey('categoryId'), isFalse);
  });

  test('M398: manual editor retains budget actions and adjacent date', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains("'__create_budget__'"));
    expect(app, contains("'__manage_budgets__'"));
    expect(app, contains('SizedBox(width:137,child:dateAction())'));
    expect(app, contains('budgetMenuRevision++'));
    final inset = File('lib/waffra_entry_sheet_safe_layout.dart')
      .readAsStringSync();
    expect(inset, contains('MediaQuery.viewInsetsOf(context).bottom'));
    expect(inset, contains('SafeArea('));
    expect(inset, contains('child: footer,'));
  });
}
