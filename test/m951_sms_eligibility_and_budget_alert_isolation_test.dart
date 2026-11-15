import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_auto_sms_policy.dart';
import 'package:waffra/waffra_budget_alert_once.dart';

/// M951: new independent financial eligibility/alert scope decisions.
/// Every SMS sample is synthetic and never posts to a real bank/ledger.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const purchase='Card Purchase: SAR 75.00 at TEST FUEL station';
 final arrived=DateTime(2026,11,3,8,50);
 WaffraAutoSmsDecision decide({
  String sender='ALRAJHI',String sms=purchase,double? amount=75,
  bool income=false,bool foreign=false,bool accountLinked=true,
  bool categoryActive=true,DateTime? date,
 })=>WaffraAutoSmsPolicy.decide(
  sender:sender,sms:sms,parsedAmount:amount,parsedIncome:income,
  foreignCurrency:foreign,arrived:arrived,verifiedDate:date,
  accountLinked:accountLinked,categoryActive:categoryActive);

 setUp(()=>SharedPreferences.setMockInitialValues({
  'm951_financial_data_never_changed':'KEEP_ORIGINAL',
 }));

 test('M951-A01 untrusted alphabetic sender cannot post valid completed bank purchase',(){
  final result=decide(sender:'PERSONAL FRIEND');
  expect(result.canPost,false);
  expect(result.reason,'untrusted_sender');
 });
 test('M951-A02 fake BANK label with long phone digits is untrusted despite bank substring',(){
  final result=decide(sender:'BANK123456789');
  expect(result.canPost,false);
  expect(result.reason,'untrusted_sender');
 });
 test('M951-A03 foreign currency flag blocks otherwise valid Saudi purchase',(){
  final result=decide(foreign:true);
  expect(result.canPost,false);
  expect(result.reason,'currency_not_verified');
 });
 test('M951-A04 missing verified account link blocks posting even with bank sender',(){
  final result=decide(accountLinked:false);
  expect(result.canPost,false);
  expect(result.reason,'new_account_mapping_required');
 });
 test('M951-A05 inactive user category rejects valid-looking card expense',(){
  final result=decide(categoryActive:false);
  expect(result.canPost,false);
  expect(result.reason,'category_unavailable');
 });
 test('M951-A06 source date exactly two days ahead stays within supported window',(){
  final result=decide(date:arrived.add(const Duration(days:2)));
  expect(result.canPost,true);
  expect(result.reason,'verified');
 });
 test('M951-A07 source date two days plus one second ahead requires manual review',(){
  final result=decide(date:arrived.add(const Duration(days:2,seconds:1)));
  expect(result.canPost,false);
  expect(result.reason,'invalid_source_date');
 });
 test('M951-A08 source date exactly 365 days before arrival is still eligible',(){
  final result=decide(date:arrived.subtract(const Duration(days:365)));
  expect(result.canPost,true);
  expect(result.reason,'verified');
 });
 test('M951-A09 source date older than 365 days by one second needs review',(){
  final result=decide(date:arrived.subtract(const Duration(days:365,seconds:1)));
  expect(result.canPost,false);
  expect(result.reason,'stale_source_date');
 });
 test('M951-A10 missing extracted money amount is not a zero-valued posting',(){
  final result=decide(amount:null);
  expect(result.canPost,false);
  expect(result.reason,'amount_not_verified');
 });
 test('M951-A11 parsed fractional halala is rejected without automatic rounding',(){
  final result=decide(amount:75.001);
  expect(result.canPost,false);
  expect(result.reason,'amount_not_verified');
 });
 test('M951-A12 parsed amount beyond one-million SAR threshold must be reviewed',(){
  final result=decide(amount:1000000.01);
  expect(result.canPost,false);
  expect(result.reason,'amount_not_verified');
 });
 test('M951-A13 verified expense cannot silently become income when parser direction conflicts',(){
  final result=decide(income:true);
  expect(result.canPost,false);
  expect(result.reason,'direction_not_verified');
 });
 test('M951-A14 missing verified bank and paused category are not bypassed together',(){
  final result=decide(accountLinked:false,categoryActive:false);
  expect(result.canPost,false);
  expect(result.reason,'new_account_mapping_required');
 });
 test('M951-A15 blank SMS is ignored before sender or money validation',(){
  final result=decide(sms:' \n  ');
  expect(result.canPost,false);
  expect(result.reason,'not_confirmed');
 });
 test('M951-A16 oversized SMS above review allowance is ignored before financial posting',(){
  final result=decide(sms:purchase+List.filled(1600,'!').join());
  expect(result.canPost,false);
  expect(result.reason,'not_confirmed');
 });

 Future<bool> alert(String owner,String id,DateTime month,List<int> stages)=>
  WaffraBudgetAlertOnce.claim(
   owner:owner,budgetId:id,month:month,crossedStages:stages);

 test('M951-B01 two budgets under same owner do not share a threshold token',()async{
  final at=DateTime(2026,11,15);
  expect(await alert('person','food',at,[75]),true);
  expect(await alert('person','rent',at,[75]),true);
  expect(await alert('person','food',at,[75]),false);
 });
 test('M951-B02 two owners of the same budget have independent alert history',()async{
  final at=DateTime(2026,11,15);
  expect(await alert('person-a','food',at,[80]),true);
  expect(await alert('person-b','food',at,[80]),true);
  expect(await alert('person-a','food',at,[80]),false);
 });
 test('M951-B03 changing calendar day inside same month does not repeat warning',()async{
  expect(await alert('person','food',DateTime(2026,11,1),[60]),true);
  expect(await alert('person','food',DateTime(2026,11,30),[60]),false);
 });
 test('M951-B04 same month next year receives a new independent alert threshold',()async{
  expect(await alert('person','food',DateTime(2026,11,1),[80]),true);
  expect(await alert('person','food',DateTime(2027,11,1),[80]),true);
 });
 test('M951-B05 blank owner never persists invalid notification history',()async{
  final at=DateTime(2026,11,1);
  expect(await alert('  ','food',at,[50]),false);
  expect(await alert('valid','food',at,[50]),true);
 });
 test('M951-B06 blank budget identifier never claims another budget warning',()async{
  final at=DateTime(2026,11,1);
  expect(await alert('owner','  ',at,[75]),false);
  expect(await alert('owner','groceries',at,[75]),true);
 });
 test('M951-B07 invalid progress stages cannot create owner notification',()async{
  final at=DateTime(2026,11,1);
  expect(await alert('owner','rent',at,[-1,0,101]),false);
  expect(await alert('owner','rent',at,[50]),true);
 });
 test('M951-B08 repeated percentage values in one batch count as a single stage',()async{
  final at=DateTime(2026,11,1);
  expect(await alert('owner','rent',at,[70,70,70]),true);
  expect(await alert('owner','rent',at,[70]),false);
 });
 test('M951-B09 out-of-order threshold jump marks earlier crossed levels as already used',()async{
  final at=DateTime(2026,11,1);
  expect(await alert('owner','food',at,[90,50,30]),true);
  expect(await alert('owner','food',at,[30]),false);
  expect(await alert('owner','food',at,[50]),false);
 });
 test('M951-B10 simultaneous alerts for different budget owners each survive isolation',()async{
  final at=DateTime(2026,11,1);
  final results=await Future.wait([
   alert('owner','food',at,[50]),alert('owner','rent',at,[50]),
   alert('another-owner','food',at,[50]),
  ]);
  expect(results,[true,true,true]);
  final prefs=await SharedPreferences.getInstance();
  expect(prefs.getString('m951_financial_data_never_changed'),'KEEP_ORIGINAL');
 });
}
