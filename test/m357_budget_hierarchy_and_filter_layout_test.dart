import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M373 named-budget selection is independent of category hierarchy', () {
    final app=File('lib/main.dart').readAsStringSync();
    final create=app.split('Future<String?> chooseBudgetCategory(').last
     .split('void refreshFromBudgetDirectory()').first;
    expect(create,contains("'waffra-independent-budget-create'"));
    expect(create,contains('namedBudgets.add(WaffraNamedBudget('));
    expect(create,isNot(contains("'waffra-budget-create-subcategory'")));
    expect(create,isNot(contains('categoryId')));
    expect(create,isNot(contains('chooseTransactionCategory(')));
  });

  test('M357 budget card is collapsible and edit/delete are explicit', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('bool monthlyBudgetDetailsOpen=false;'));
    expect(app, contains("'waffra-month-budget-expand-toggle'"));
    expect(app, contains('if(monthlyBudgetDetailsOpen)...['));
    expect(app, contains("'waffra-budget-create-action'"));
    expect(app, isNot(contains("'waffra-month-budget-compact-edit'")));
    final directory =
        File('lib/waffra_budget_directory.part.dart').readAsStringSync();
    expect(directory, contains("'waffra-my-budgets-panel'"));
    expect(directory, contains('editBudgetForCategory(b)'));
    expect(app, isNot(contains("'waffra-delete-selected-named-budget'")));
    expect(app, isNot(contains("'waffra-named-budget-enabled-switch'")));
    expect(directory, contains("'waffra-budget-quick-actions-'"));
    expect(directory, contains('deleteNamedBudget(b)'));
    expect(directory, contains('setNamedBudgetActive(b,!b.budgetActive)'));
    expect(app, contains("budgetStatusFilter='active'"));
    expect(app, contains("'waffra-budget-status-filter-'"));
    expect(app, contains("'الميزانيات غير الفعّالة'"));
    expect(app, contains("'الميزانيات الفعّالة'"));
    expect(app, contains('if(monthlyBudgetDetailsOpen)...['));
    expect(app, contains('actions:[SizedBox(width:double.maxFinite,child:Row(children:['));
    expect(app, contains('await confirmDeletion('));
    expect(app, contains("operation:'standalone-budget-soft-delete'"));
  });

  test('M357 category filter controls do not clip on phone width', () {
    final categoryPage =
        File('lib/waffra_categories_page.part.dart').readAsStringSync();
    expect(categoryPage, contains('layout.maxWidth<560'));
    expect(categoryPage, contains('Wrap(spacing:12,runSpacing:16'));
    expect(categoryPage, contains('childrenPadding:const EdgeInsets.fromLTRB(16,8,16,18)'));
    expect(categoryPage, contains('floatingLabelBehavior:FloatingLabelBehavior.auto'));
    expect(categoryPage, contains('isExpanded:true'));
  });
}
