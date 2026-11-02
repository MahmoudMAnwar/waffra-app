import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_budget_template_catalog.dart';

void main() {
  test('M359: 24 independent budget templates have unique names without category links', () {
    expect(waffraBudgetStarterTemplates.length, 24);
    final namesAr = <String>{};
    final namesEn = <String>{};
    for (final template in waffraBudgetStarterTemplates) {
      expect(template.nameAr.trim(), isNotEmpty);
      expect(template.nameEn.trim(), isNotEmpty);
      expect(namesAr.add(template.nameAr), isTrue);
      expect(namesEn.add(template.nameEn), isTrue);
      expect(template.nameAr, isNot(contains(' / ')));
      expect(template.nameEn, isNot(contains(' / ')));
    }
  });

  test('M359: budget templates do not assign user money or post a transaction', () {
    final source = File('lib/waffra_budget_template_catalog.dart').readAsStringSync();
    expect(source, isNot(contains('MoneyEntry(')));
    expect(source, isNot(contains('monthlyLimit:')));
    expect(source, isNot(contains('budget:')));
    expect(source, isNot(contains('mainCategoryId')));
    expect(source, isNot(contains('subcategoryAr')));
  });

  test('M359: My Budgets is separate from income/expense category filters', () {
    final source = File('lib/waffra_budget_directory.part.dart').readAsStringSync();
    final categories = File('lib/waffra_categories_page.part.dart').readAsStringSync();
    expect(categories, contains('()=>this.budgetsDirectory()'));
    expect(source, contains("'waffra-my-budgets-panel'"));
    expect(source, contains("'waffra-budget-directory-search'"));
    expect(source, contains("budgetStatusFilter=='active'"));
    expect(source, contains("budgetStatusFilter=='inactive'"));
    expect(source, isNot(contains("budgetMainCategoryFilter!='all'")));
    expect(source, isNot(contains("'waffra-budget-directory-category-'")));
    expect(source, contains("budgetSort=='spent'"));
    expect(source, contains('waffraSearchAny('));
    expect(source, contains('waffraNamedBudgetSpent('));
    expect(source, contains('editBudgetForCategory(b)'));
    expect(source, contains('setNamedBudgetActive(b,!b.budgetActive)'));
    expect(source, contains('deleteNamedBudget(b)'));
    expect(source, contains('waffraBudgetStarterTemplates'));
    expect(source, contains('suggestedName:t.name(waffraIsEnglish)'));
    expect(source, isNot(contains('suggestedSubcategory:t.subcategoryAr')));
  });

  test('M359: overall budget is computed, transaction review can create budget', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('final overallLimit=allBudgets.fold<double>'));
    expect(app, contains('final overallSpent=monthEntries.where('));
    expect(app, contains("'الميزانية الشهرية العامة'"));
    expect(app, contains("'__create_budget__'"));
    expect(app, contains('final id=await chooseBudgetCategory();'));
    expect(app, contains('assignBudgetInsideEditor(b.single.id)'));
    expect(app, contains('if(b.length==1)assignBudgetInsideEditor'));
    expect(app, contains('WaffraNamedBudget('));
    expect(app, contains('final allBudgets=namedBudgets.where((b)=>b.budget>0&&!b.deleted)'));
  });
}
