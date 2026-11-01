import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_budget_template_catalog.dart';
import 'package:waffra/waffra_category_catalog.dart';

void main() {
  test('M359: 24 optional templates have unique names and real expense leaves', () {
    expect(waffraBudgetStarterTemplates.length, 24);
    final namesAr = <String>{};
    final namesEn = <String>{};
    for (final template in waffraBudgetStarterTemplates) {
      expect(template.nameAr.trim(), isNotEmpty);
      expect(template.nameEn.trim(), isNotEmpty);
      expect(namesAr.add(template.nameAr), isTrue);
      expect(namesEn.add(template.nameEn), isTrue);
      final root = waffraCategoryCatalog.singleWhere(
        (g) => g.id == template.mainCategoryId,
      );
      expect(root.income, isFalse);
      expect(root.subcategories, contains(template.subcategoryAr));
    }
  });

  test('M359: budget templates do not assign user money or post a transaction', () {
    final source = File('lib/waffra_budget_template_catalog.dart').readAsStringSync();
    expect(source, isNot(contains('MoneyEntry(')));
    expect(source, isNot(contains('monthlyLimit:')));
    expect(source, isNot(contains('budget:')));
  });

  test('M359: My Budgets is separate from income/expense category filters', () {
    final source = File('lib/waffra_budget_directory.part.dart').readAsStringSync();
    final categories = File('lib/waffra_categories_page.part.dart').readAsStringSync();
    expect(categories, contains('()=>this.budgetsDirectory()'));
    expect(source, contains("'waffra-my-budgets-panel'"));
    expect(source, contains("'waffra-budget-directory-search'"));
    expect(source, contains("budgetStatusFilter=='active'"));
    expect(source, contains("budgetStatusFilter=='inactive'"));
    expect(source, contains("budgetMainCategoryFilter!='all'"));
    expect(source, contains("'waffra-budget-directory-category-'"));
    expect(source, contains("'All main categories'"));
    expect(source, contains("budgetSort=='spent'"));
    expect(source, contains('waffraSearchAny('));
    expect(source, contains('waffraNamedBudgetSpent('));
    expect(source, contains('editBudgetForCategory(b)'));
    expect(source, contains('setNamedBudgetActive(b,!b.budgetActive)'));
    expect(source, contains('deleteNamedBudget(b)'));
    expect(source, contains('waffraBudgetStarterTemplates'));
    expect(source, contains('suggestedParentId:t.mainCategoryId'));
    expect(source, contains('suggestedSubcategory:t.subcategoryAr'));
  });

  test('M359: overall budget is computed, transaction review can create budget', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('final overallLimit=allBudgets.fold<double>'));
    expect(app, contains('final overallSpent=monthEntries.where('));
    expect(app, contains("'الميزانية الشهرية العامة'"));
    expect(app, contains("'waffra-entry-create-named-budget'"));
    expect(app, contains('final id=await chooseBudgetCategory();'));
    expect(app, contains('selectedBudgetId=match.single.id;'));
    expect(app, contains('if(match.length!=1)return;'));
    expect(app, contains('if(selected.budget>0){'));
    expect(app, contains('final allBudgets=categories.where((c)=>!c.income&&c.budget>0)'));
  });
}
