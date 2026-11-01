import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_category_merge_safety.dart';

void main(){
 const categories=[
  WaffraCategoryIdentity('shopping','تسوّق','',false),
  WaffraCategoryIdentity('fuel','وقود','car',false,hasBudget:true),
  WaffraCategoryIdentity('gas','بنزين','car',false),
  WaffraCategoryIdentity('car','السيارة','',false),
  WaffraCategoryIdentity('salary','راتب','',true),
 ];
 test('M342 safe merge preview keeps transactions untouched',(){
  final result=WaffraCategoryMergeSafety.propose(
   sourceId:'fuel',targetId:'gas',categories:categories,
   transactions:[const WaffraCategoryAssignment('txn-1','fuel')],
   recurring:[const WaffraCategoryAssignment('rec-1','fuel')]);
  expect(result.transactionIds,['txn-1']);
  expect(result.recurringIds,['rec-1']);
  expect(result.budgetReviewRequired,isTrue);
 });
 test('M342 prohibit merging income with expense',(){
  expect(()=>WaffraCategoryMergeSafety.propose(
   sourceId:'salary',targetId:'shopping',categories:categories,
   transactions:[],recurring:[]),throwsStateError);
 });
 test('M342 prohibit parent with children and hierarchy mismatch',(){
  expect(()=>WaffraCategoryMergeSafety.propose(
   sourceId:'car',targetId:'shopping',categories:categories,
   transactions:[],recurring:[]),throwsStateError);
  expect(()=>WaffraCategoryMergeSafety.propose(
   sourceId:'fuel',targetId:'shopping',categories:categories,
   transactions:[],recurring:[]),throwsStateError);
 });
 test('M342 missing or duplicate financial references fail',(){
  expect(()=>WaffraCategoryMergeSafety.propose(
   sourceId:'fuel',targetId:'gas',categories:categories,
   transactions:[
    const WaffraCategoryAssignment('txn-1','fuel'),
    const WaffraCategoryAssignment('txn-1','gas'),
   ],recurring:[]),throwsStateError);
  expect(()=>WaffraCategoryMergeSafety.propose(
   sourceId:'fuel',targetId:'gas',categories:categories,
   transactions:[const WaffraCategoryAssignment('txn-1','deleted')],
   recurring:[]),throwsStateError);
 });
}
