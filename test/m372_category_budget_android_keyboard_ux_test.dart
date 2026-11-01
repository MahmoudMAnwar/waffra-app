import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  final directory = File('lib/waffra_budget_directory.part.dart').readAsStringSync();

  test('M372: main picker creates only main; leaf picker only child', () {
    final picker = source.split('Future<String?> chooseTransactionCategory(').last
      .split('Future<void>')[0];
    expect(picker, contains('if(allowCreate&&!leafLabels)'));
    expect(picker, contains('if(allowCreate&&leafLabels)'));
    expect(picker, contains('waffra-inline-create-main-category'));
    expect(picker, contains('waffra-inline-create-subcategory'));
    expect(picker, contains('waffraKeyboardDialogListHeight(dialogCtx)'));
    expect(picker, isNot(contains('TextField(autofocus:true')));
  });

  test('M372: editing a category never changes its saved budget behind the scenes', () {
    final editor = source.split('Future<BudgetCategory?> categoryDialog(').last
      .split('Future<void> chooseCategoryLevel(').first;
    expect(editor, contains('scrollable:true'));
    expect(editor, contains('budget:initial?.budget??0'));
    expect(editor, contains('budgetLabel:initial?.budgetLabel'));
    expect(editor, contains('budgetActive:initial?.budgetActive??true'));
    expect(editor, isNot(contains('TextField(controller:budget')));
    expect(editor, isNot(contains('TextField(controller:budgetName')));
    expect(editor, contains('Wrap(spacing:12,runSpacing:12'));
  });

  test('M372: one budget dropdown has create/manage, date and no duplicate buttons', () {
    final form = source.split('final result=await showModalBottomSheet<MoneyEntry>(').last
      .split('debounce?.cancel();disposeLater(').first;
    expect(form, contains("'__create_budget__'"));
    expect(form, contains("'__manage_budgets__'"));
    expect(form, contains('SizedBox(width:137,child:dateAction())'));
    expect(form, contains('budgetMenuRevision++'));
    expect(form, isNot(contains("'waffra-entry-search-budgets'")));
    expect(form, isNot(contains("'waffra-entry-create-named-budget'")));
    final assign = form.split('void assignBudgetInsideEditor(').last
      .split('Widget dateAction()').first;
    expect(assign, isNot(contains('selectedParentId=matches.single.parentId')));
    expect(assign, isNot(contains('category=matches.single.name')));
  });

  test('M372: budget directory shows templates without category filters', () {
    expect(directory, contains('waffraBudgetStarterTemplates'));
    expect(directory, contains('refreshFromBudgetDirectory()'));
    expect(directory, isNot(contains('refresh(()=>setState(')));
    expect(directory, isNot(contains("budgetMainCategoryFilter!='all'")));
    expect(directory, isNot(contains("'waffra-budget-directory-category-'")));
    expect(directory, isNot(contains("(parents[b.parentId]??'')+' / '+b.displayName")));
  });

  test('M372: keyboard-sensitive list dialogs share viewport height', () {
    expect(source, contains('media.size.height-media.viewInsets.bottom-'));
    expect(source, contains('waffraKeyboardDialogListHeight(ctx,desired:500)'));
    expect(source, contains('waffraKeyboardDialogListHeight(ctx,desired:470)'));
    expect(source, contains('waffraKeyboardDialogListHeight(ctx,desired:360)'));
    expect(source, contains('waffraKeyboardDialogListHeight(ctx,desired:460)'));
  });
}
