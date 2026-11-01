import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M357 named-budget selection follows parent then child hierarchy', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains("categories.where((c)=>!c.income&&!c.isSubcategory)"));
    expect(app, contains('c.isSubcategory&&c.parentId==parent.id'));
    expect(app, contains("'waffra-budget-main-list'"));
    expect(app, contains("'waffra-budget-sub-list'"));
    expect(app, contains("Navigator.pop(ctx,item.id)"));
    expect(app, contains('if(matches.length!=1)return null;'));
    expect(app, contains('await editBudgetForCategory(selected,suggestedName:suggestedName);'));
    expect(app, contains("'waffra-budget-create-subcategory'"));
    expect(app, contains('await addCategory(income:false,parentId:parentId);'));
  });

  test('M357 budget card is collapsible and edit/delete are explicit', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('bool monthlyBudgetDetailsOpen=false;'));
    expect(app, contains("'waffra-month-budget-expand-toggle'"));
    expect(app, contains('if(monthlyBudgetDetailsOpen)...['));
    expect(app, contains("'waffra-budget-create-action'"));
    expect(app, contains("'waffra-month-budget-compact-edit'"));
    expect(app, contains("'waffra-delete-selected-named-budget'"));
    expect(app, contains('deleteNamedBudget(selected)'));
    expect(app, contains("budgetStatusFilter='active'"));
    expect(app, contains("'waffra-budget-status-filter-'"));
    expect(app, contains("'الميزانيات غير الفعّالة'"));
    expect(app, contains("'الميزانيات الفعّالة'"));
    expect(app, contains('if(monthlyBudgetDetailsOpen)...['));
    expect(app, contains('actions:[SizedBox(width:double.maxFinite,child:Row(children:['));
    expect(app, contains('await confirmDeletion('));
    expect(app, contains('entries[j].withBudget(null)'));
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
