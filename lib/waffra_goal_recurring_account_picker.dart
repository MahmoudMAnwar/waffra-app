
import 'package:flutter/material.dart';

import 'storage/waffra_accounts_repository.dart';
import 'waffra_recurring_account_groups.dart';
import 'waffra_saudi_financial_providers.dart';

/// M641: same verified institution -> child money-account picker for recurring
/// and savings goals. Provider names alone never authorize a money write.
class WaffraGoalRecurringAccountPicker extends StatefulWidget {
 const WaffraGoalRecurringAccountPicker({
  super.key,required this.accounts,required this.onChanged,
  required this.onCreateAccount,required this.onError,this.selectedAccountId,
  this.english=false,this.idPrefix='m641',
 });
 final List<WaffraAccountBalance> accounts;
 final String? selectedAccountId,idPrefix;
 final bool english;
 final ValueChanged<String?> onChanged;
 final Future<WaffraAccountBalance?> Function(String? providerGroupId) onCreateAccount;
 final ValueChanged<String> onError;
 @override State<WaffraGoalRecurringAccountPicker> createState()=>
  _WaffraGoalRecurringAccountPickerState();
}

class _WaffraGoalRecurringAccountPickerState
    extends State<WaffraGoalRecurringAccountPicker> {
 final _created=<String,WaffraAccountBalance>{};
 String? category,groupId,accountId;
 bool creating=false;
 String label(String ar,String en)=>widget.english?en:ar;
 List<WaffraAccountBalance> get accounts{
  final all=<String,WaffraAccountBalance>{
   for(final a in widget.accounts)if(!a.archived)a.id:a,
   for(final a in _created.values)if(!a.archived)a.id:a,
  };
  return all.values.toList(growable:false);
 }
 List<WaffraRecurringAccountGroup> get groups=>
  WaffraRecurringAccountGroups.withBankProviderChoices(accounts);
 @override void initState(){
  super.initState();
  accountId=widget.selectedAccountId;
  _restoreGroup();
 }
 @override void didUpdateWidget(WaffraGoalRecurringAccountPicker old){
  super.didUpdateWidget(old);
  if(old.selectedAccountId!=widget.selectedAccountId){
   accountId=widget.selectedAccountId;
   _restoreGroup();
  }
 }
 void _restoreGroup(){
  if(accountId==null)return;
  for(final group in groups){
   if(group.accounts.any((a)=>a.id==accountId)){
    groupId=group.id;category=group.category;return;
   }
  }
  accountId=null;groupId=null;
 }
 void _chooseCategory(String? next){
  setState((){category=next;groupId=null;accountId=null;});
  widget.onChanged(null);
 }
 void _chooseProvider(String? next){
  setState((){groupId=next;accountId=null;});
  widget.onChanged(null);
 }
 void _chooseAccount(String? next){
  setState(()=>accountId=next);
  widget.onChanged(next);
 }
 Future<void> _create()async{
  if(creating)return;
  setState(()=>creating=true);
  try{
   final created=await widget.onCreateAccount(groupId);
   if(!mounted||created==null)return;
   final previousAccount=accountId;
   _created[created.id]=created;
   final related=WaffraRecurringAccountGroups.fromAccounts(accounts)
    .where((g)=>g.accounts.any((a)=>a.id==created.id)).toList();
   if(related.length!=1)throw StateError(
    'New financial account was not uniquely verified.');
   setState((){
    category=related.single.category;
    groupId=related.single.id;
    accountId=created.id;
   });
   if(previousAccount!=created.id)widget.onChanged(created.id);
  }catch(_){
   if(mounted){
    widget.onError(label('تعذر إضافة الحساب أو التحقق منه. حاول مرة أخرى.',
     'Account creation could not be verified. Try again.'));
   }
  }finally{
   if(mounted)setState(()=>creating=false);
  }
 }
 @override Widget build(BuildContext context){
  final allGroups=groups;
  final matching=allGroups.where((g)=>g.category==category).toList();
  final group=matching.where((g)=>g.id==groupId).toList();
  final linked=group.isEmpty?const <WaffraAccountBalance>[]:group.single.accounts;
  final chosenAccount=linked.any((a)=>a.id==accountId)?accountId:null;
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,
   mainAxisSize:MainAxisSize.min,children:[
   DropdownButtonFormField<String>(
    key:ValueKey(widget.idPrefix.toString()+'-category-'+(category??'none')),
    initialValue:category,isExpanded:true,
    decoration:InputDecoration(
     labelText:label('نوع الجهة *','Institution type *'),
     border:const OutlineInputBorder()),
    items:const [
     DropdownMenuItem(value:WaffraSaudiFinancialProviders.local,
      child:Text('بنوك محلية')),
     DropdownMenuItem(value:WaffraSaudiFinancialProviders.digital,
      child:Text('بنوك رقمية')),
     DropdownMenuItem(value:WaffraSaudiFinancialProviders.wallet,
      child:Text('محافظ رقمية')),
     DropdownMenuItem(value:WaffraSaudiFinancialProviders.other,
      child:Text('نقدي / أخرى')),
    ],
    onChanged:_chooseCategory,
   ),
   const SizedBox(height:10),
   DropdownButtonFormField<String>(
    key:ValueKey(widget.idPrefix.toString()+'-provider-'+(groupId??'none')),
    initialValue:matching.any((g)=>g.id==groupId)?groupId:null,
    isExpanded:true,
    decoration:InputDecoration(
     labelText:label('البنك أو الجهة الأساسية *','Bank or primary institution *'),
     border:const OutlineInputBorder()),
    items:matching.map((g)=>DropdownMenuItem<String>(
     value:g.id,child:Text(widget.english?g.labelEn:g.labelAr,
      overflow:TextOverflow.ellipsis))).toList(),
    onChanged:category==null?null:_chooseProvider,
   ),
   const SizedBox(height:10),
   DropdownButtonFormField<String>(
    key:ValueKey(widget.idPrefix.toString()+'-account-'+(chosenAccount??'none')),
    initialValue:chosenAccount,isExpanded:true,
    decoration:InputDecoration(
     labelText:label('الحساب المالي التابع *','Linked financial account *'),
     border:const OutlineInputBorder()),
    items:linked.map((a)=>DropdownMenuItem<String>(
     value:a.id,child:Text(a.name,overflow:TextOverflow.ellipsis))).toList(),
    onChanged:groupId==null||linked.isEmpty?null:_chooseAccount,
   ),
   const SizedBox(height:8),
   OutlinedButton.icon(
    key:ValueKey(widget.idPrefix.toString()+'-add-account'),
    onPressed:creating?null:_create,
    icon:const Icon(Icons.add_circle_outline_rounded),
    label:Text(groupId==null?
     label('إضافة حساب','Add account'):
     label('إضافة حساب تابع','Add linked account')),
   ),
  ]);
 }
}
