import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart' as app;

void main(){
 test('M403 old category JSON remains enabled and round trips pause',(){
  final old=app.BudgetCategory.fromJson({'id':'old','name':'Old','icon':'category','color':0xFF087A54,'income':false});
  expect(old.categoryActive,isTrue);
  final paused=old.copy(categoryActive:false);
  expect(app.BudgetCategory.fromJson(paused.toJson()).categoryActive,isFalse);
  expect(paused.budgetActive,old.budgetActive);
 });
 test('M403 paused parent prevents new leaf postings, retains category metadata',(){
  final parent=app.BudgetCategory(id:'p',name:'Parent',icon:'category',color:0xFF087A54,income:false,categoryActive:false);
  final child=app.BudgetCategory(id:'c',name:'Child',icon:'category',color:0xFF087A54,income:false,parentId:'p');
  expect(app.waffraCategoryAvailableForNewEntry([parent,child],child),isFalse);
  expect(app.waffraCanAssignManualCategory([parent,child],false,'p','Child'),isFalse);
  expect(app.waffraCategoryNameAvailableForPosting([parent,child],false,'Child'),isFalse);
  final enabled=parent.copy(categoryActive:true);
  expect(app.waffraCanAssignManualCategory([enabled,child],false,'p','Child'),isTrue);
 });
 test('M405 standalone named budget copy remains covariant and independent',(){
  final budget=app.WaffraNamedBudget(
   id:'budget-1',name:'Fuel',budget:200,budgetActive:true);
  final app.BudgetCategory polymorphic=budget;
  final modified=polymorphic.copy(categoryActive:false,budgetActive:false);
  expect(modified,isA<app.WaffraNamedBudget>());
  expect(modified.budgetActive,isFalse);
  expect(modified.categoryActive,isTrue);
  expect((modified as app.WaffraNamedBudget).deleted,isFalse);
  expect(modified.budget,200);
 });
 test('M403 quick action toggles are available on both category levels',(){
  final source=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(source,contains('waffra-root-category-active-'));
  expect(source,contains('waffra-subcategory-active-'));
  expect(source,contains('setCategoryActive(root,v)'));
  expect(source,contains('setCategoryActive(sub,v)'));
 });
}
