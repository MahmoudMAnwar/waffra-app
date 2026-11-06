import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart' show snack, snackSuccess;

import 'storage/waffra_account_context_repository.dart';
import 'storage/waffra_accounts_repository.dart';
import 'storage/waffra_verified_accounts_api.dart';
import 'waffra_recurring_account_groups.dart';

/// Explicit account configuration only. Never posts a transaction, changes
/// a reminder or inherits the currently displayed Home account.
class WaffraAccountContextSettings extends StatefulWidget {
 const WaffraAccountContextSettings({
  super.key,required this.api,required this.accounts,this.english=false,
 });
 final WaffraVerifiedAccountsApi api;
 final List<WaffraAccountBalance> accounts;
 final bool english;
 @override
 State<WaffraAccountContextSettings> createState()=>
  _WaffraAccountContextSettingsState();
}

class _WaffraAccountContextSettingsState
 extends State<WaffraAccountContextSettings> {
 late Future<List<WaffraRecurringAccountTemplate>> templates;
 String t(String ar,String en)=>widget.english?en:ar;
 @override
 void initState(){super.initState();_reload();}
 void _reload(){templates=widget.api.recurringAccountTemplates();}
 void _notify(String ar,String en,{bool success=false}){
  if(!mounted)return;
  final text=t(ar,en);
  if(success){snackSuccess(context,text);}else{snack(context,text);}
 }

 Future<void> _editRecurring(WaffraRecurringAccountTemplate item)async{
  final active=widget.accounts.where((a)=>!a.archived).toList();
  final providers=WaffraRecurringAccountGroups.fromAccounts(active);
  if(providers.isEmpty){
   _notify('أضف حسابًا ماليًا أولًا قبل ربط العملية المتكررة.',
    'Add a money account before configuring a recurring payment.');
   return;
  }
  // A missing or archived default never falls back to the Home header.
  String? selectedProvider;
  String? chosen;
  for(final provider in providers){
   if(provider.accounts.any((a)=>a.id==item.accountId)){
    selectedProvider=provider.id;
    chosen=item.accountId;
    break;
   }
  }
  final selection=await showDialog<String>(context:context,
   builder:(dialog)=>StatefulBuilder(builder:(dialog,update){
    final matching=providers.where((p)=>p.id==selectedProvider).toList();
    final linked=matching.isEmpty?
     const <WaffraAccountBalance>[]:matching.single.accounts;
    return AlertDialog(
     title:Text(t('حساب العملية المتكررة','Recurring money account')),
     content:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
       Text(item.title),
       const SizedBox(height:12),
       DropdownButtonFormField<String>(
        key:ValueKey('m470-recurring-provider-'+(selectedProvider??'none')),
        initialValue:selectedProvider,isExpanded:true,
        decoration:InputDecoration(
         labelText:t('الجهة أو البنك','Provider or bank'),
         border:const OutlineInputBorder()),
        items:providers.map((provider)=>DropdownMenuItem<String>(
         value:provider.id,
         child:Text(t(provider.labelAr,provider.labelEn),
          maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(value)=>update((){
         selectedProvider=value;
         chosen=null; // Never imply the account from a provider alone.
        }),
       ),
       const SizedBox(height:12),
       DropdownButtonFormField<String>(
        key:ValueKey('m470-recurring-account-'+(selectedProvider??'none')),
        initialValue:chosen,isExpanded:true,
        decoration:InputDecoration(
         labelText:t('الحساب المرتبط بالجهة','Linked money account'),
         border:const OutlineInputBorder()),
        items:linked.map((account)=>DropdownMenuItem<String>(
         value:account.id,child:Text(account.name,
          maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:selectedProvider==null?null:
         (value)=>update(()=>chosen=value),
       ),
       const SizedBox(height:12),
       Text(t('الحساب إجباري للدفعات القادمة. لن يتغير سجل المدفوعات السابقة أو التذكيرات.',
        'A money account is mandatory for future payments. Previous transactions and reminders are unchanged.')),
      ])),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(dialog),
       child:Text(t('إلغاء','Cancel'))),
      FilledButton(
       key:const Key('m470-recurring-default-save'),
       onPressed:chosen!=null&&linked.any((a)=>a.id==chosen)
        ?()=>Navigator.pop(dialog,chosen):null,
       child:Text(t('حفظ','Save'))),
     ],
    );
   }));
  if(selection==null||!mounted)return;
  if(!active.any((a)=>a.id==selection))return;
  try{
   // Revalidate the current finance witness inside the encrypted writer.
   await widget.api.balances();
   await widget.api.setRecurringDefaultAccount(
    recurringId:item.id,accountId:selection,userConfirmed:true);
   if(mounted)setState(_reload);
   _notify('تم تحديث الحساب للدفعات القادمة.',
    'Future payment default saved.',success:true);
  }catch(_){
   _notify('تعذر حفظ حساب المتكررة. راجع الحسابات.',
    'Could not save recurring account. Refresh and retry.');
  }
 }

 Future<void> _verifySmsBank()async{
  final banks=widget.accounts.where((a)=>
   !a.archived&&a.kind=='bank').toList();
  if(banks.isEmpty)return;
  final digitsController=TextEditingController();
  String? selected;
  String digits='';
  var suffixLoading=false;
  var suffixReadError=false;
  var lookupRevision=0;
  List<String>? result;
  try{
   result=await showDialog<List<String>>(
    context:context,builder:(dialog)=>StatefulBuilder(
     builder:(dialog,update)=>AlertDialog(
      title:Text(t('تأكيد حساب الرسائل البنكية','Verify SMS bank account')),
      content:SingleChildScrollView(child:Column(
       mainAxisSize:MainAxisSize.min,children:[
        Text(t('اختر الحساب البنكي لمراجعة آخر 4 أرقام محفوظة أو تعديلها. '
          'الرسائل غير المتطابقة تتطلب اختيار الحساب يدويًا.',
          'Choose a bank account to review or correct its saved last four digits. '
          'Unmatched messages require an explicit account choice.')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(
         key:ValueKey('m481-verified-bank-select-'+(selected??'none')),
         initialValue:selected,isExpanded:true,
         decoration:InputDecoration(labelText:t('الحساب البنكي','Bank account'),
          border:const OutlineInputBorder()),
         items:banks.map((a)=>DropdownMenuItem<String>(
          value:a.id,child:Text(a.name))).toList(),
         onChanged:(v)async{
          final request=++lookupRevision;
          update((){
           selected=v;
           digitsController.clear();
           digits='';
           suffixLoading=v!=null;
           suffixReadError=false;
          });
          if(v==null)return;
          try{
           // Only a verified SQLCipher read may populate these digits.
           final saved=await widget.api.verifiedBankSuffix(v);
           if(!dialog.mounted||request!=lookupRevision||selected!=v)return;
           update((){
            digits=saved??'';
            digitsController.text=digits;
            suffixLoading=false;
           });
          }catch(_){
           if(!dialog.mounted||request!=lookupRevision)return;
           update((){
            suffixLoading=false;
            suffixReadError=true;
           });
          }
         },
        ),
        const SizedBox(height:10),
        if(suffixLoading)const LinearProgressIndicator(),
        if(suffixReadError)Padding(
         padding:const EdgeInsets.only(bottom:8),
         child:Text(t('تعذر قراءة آخر 4 أرقام بشكل موثّق. '
           'أعد اختيار الحساب قبل التأكيد.',
           'Could not verify the saved digits. Select the account again.'),
          style:TextStyle(color:Theme.of(dialog).colorScheme.error))),
        TextField(
         key:const Key('m481-bank-suffix-editor'),
         controller:digitsController,
         enabled:selected!=null&&!suffixLoading&&!suffixReadError,
         keyboardType:TextInputType.number,
         inputFormatters:[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
         ],
         maxLength:4,
         onChanged:(v)=>update(()=>digits=v),
         decoration:InputDecoration(
          labelText:t('آخر 4 أرقام محفوظة','Saved last four digits'),
          border:const OutlineInputBorder()),
        ),
       ])),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:Text(t('إلغاء','Cancel'))),
       FilledButton(
        onPressed:selected!=null&&!suffixLoading&&!suffixReadError&&
           RegExp(r'^[0-9]{4}$').hasMatch(digits)
         ?()=>Navigator.pop(dialog,[selected!,digits]):null,
        child:Text(t('تأكيد','Verify'))),
      ],
     )));
  }finally{
   digitsController.dispose();
  }
  if(result==null||!mounted)return;
  try{
   // Revalidate live account membership before updating saved suffix.
   final latest=await widget.api.balances();
   if(!latest.any((a)=>a.id==result![0]&&!a.archived&&a.kind=='bank')){
    throw StateError('Bank account was archived or changed.');
   }
   await widget.api.registerVerifiedBankSuffix(
    accountId:result[0],lastFour:result[1],userConfirmed:true);
   _notify('تم حفظ آخر 4 أرقام للحساب داخل قاعدة البيانات المشفرة.',
    'Verified account suffix securely updated.',success:true);
  }catch(_){
   _notify('تعذر تأكيد الحساب البنكي. راجع البيانات وحاول مرة أخرى.',
    'Bank mapping could not be verified. Refresh and retry.');
  }
 }

 @override
 Widget build(BuildContext context) {
  final labels={for(final a in widget.accounts)a.id:a.name};
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   if(widget.accounts.any((a)=>!a.archived&&a.kind=='bank'))
    Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
     child:OutlinedButton.icon(
      icon:const Icon(Icons.verified_user_outlined),
      onPressed:_verifySmsBank,
      label:Text(t('ربط حساب بالرسائل البنكية','Verify SMS bank account')))),
   FutureBuilder<List<WaffraRecurringAccountTemplate>>(
    future:templates,builder:(ctx,state){
     if(state.hasError)return Padding(
      padding:const EdgeInsets.all(12),
      child:Text(t('تعذر قراءة حسابات المتكررة المشفرة.',
       'Recurring account settings are unavailable.')));
     if(!state.hasData||state.data!.isEmpty)return const SizedBox.shrink();
     return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.all(12),child:Text(
       t('الحسابات الافتراضية للمتكررة','Recurring default accounts'),
       style:Theme.of(context).textTheme.titleMedium)),
      ...state.data!.map((item)=>Card(child:ListTile(
       title:Text(item.title),
       subtitle:Text(item.accountId==null
        ?t('الحساب غير محدد — اختر حسابًا قبل الدفع',
          'No account configured — choose before payment')
        :labels[item.accountId]??t('حساب غير متاح','Unavailable account')),
       trailing:const Icon(Icons.edit_outlined),
       onTap:()=>_editRecurring(item),
      ))),
     ]);
    }),
  ]);
 }
}
