import 'package:flutter/material.dart';
import 'waffra_account_transaction_form.dart';

class WaffraNewAccountDraft {
 const WaffraNewAccountDraft({
  required this.name,required this.kind,required this.openingMinor,
  this.lastFour,this.providerId,this.subtype,this.customSubtypeLabel,
 });
 final String name,kind;
 final int openingMinor;
 final String? lastFour,providerId,subtype,customSubtypeLabel;
}

/// A form only: the same verified SQLCipher account API authorizes saving.
/// Bank names decorate labels, not trusted financial account provenance.
class WaffraNewAccountDialog extends StatefulWidget {
 const WaffraNewAccountDialog({
  super.key,this.english=false,this.suggestedProviderId,
  this.suggestedSenderName,this.suggestedLastFour,
  this.customSubtypeOptions=const {},
 });
 final bool english;
 final Map<String,List<String>> customSubtypeOptions;
 // A reviewed sender can prefill the exact sender display name; the user
 // still confirms the account and opening balance before any finance write.
 final String? suggestedProviderId,suggestedSenderName,suggestedLastFour;
 @override State<WaffraNewAccountDialog> createState()=>_WaffraNewAccountDialogState();
}

class _WaffraNewAccountDialogState extends State<WaffraNewAccountDialog> {
 final nickname=TextEditingController();
 final opening=TextEditingController(text:'0');
 final smsSuffix=TextEditingController();
 final sessionCustomSubtypes=<String,Set<String>>{};
 int subtypeRevision=0;
 String? customSubtypeLabel;
 String kind='cash';
 String? provider;
 String? subtype='cash';
 String t(String ar,String en)=>widget.english?en:ar;
 static const banks=<String,({String ar,String en})>{
  'rajhi':(ar:'مصرف الراجحي',en:'Al Rajhi Bank'),
  'inma':(ar:'مصرف الإنماء',en:'Alinma Bank'),
  'snb':(ar:'البنك الأهلي السعودي',en:'Saudi National Bank'),
  'riyad':(ar:'بنك الرياض',en:'Riyad Bank'),
  'bilad':(ar:'بنك البلاد',en:'Bank Albilad'),
  'stc':(ar:'STC Bank',en:'STC Bank'),
  'other':(ar:'بنك آخر',en:'Other bank'),
 };
 @override void initState(){
  super.initState();
  // A masked bank SMS suffix is an editable suggestion, not a verified
  // financial account link. Creation still requires explicit approval.
  final suffix=widget.suggestedLastFour;
  if(suffix!=null&&RegExp(r'^[0-9]{4}$').hasMatch(suffix)){
   smsSuffix.text=suffix;
  }
  final suggested=widget.suggestedProviderId;
  if(suggested!=null&&banks.containsKey(suggested)&&suggested!='other'){
   kind='bank';provider=suggested;subtype='current';
   final sender=widget.suggestedSenderName?.trim()??'';
   // SMS sender labels are untrusted text: never inject unbounded control
   // characters or render an arbitrary message body as an account name.
   if(sender.isNotEmpty&&sender.runes.length<=80&&
      !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(sender)){
    nickname.text=sender;
   }
  }
 }
 @override void dispose(){nickname.dispose();opening.dispose();smsSuffix.dispose();super.dispose();}
 int? get openingMinor=>waffraSarAmountMinor(opening.text,allowZero:true);
 String get accountLabel{
  final name=nickname.text.trim();
  if(kind!='bank'||provider==null||provider=='other')return name;
  // On first bank SMS, store exactly the user-approved sender name rather
  // than prepending a second bank name (e.g. «الإنماء - AlinmaPay»).
  if(widget.suggestedSenderName!=null&&name.isNotEmpty)return name;
  final chosen=banks[provider]!;
  final prefix=t(chosen.ar,chosen.en);
  return name.contains(prefix)?name:'$prefix - $name';
 }
 bool get valid{
  final label=accountLabel;
  return nickname.text.trim().isNotEmpty&&label.runes.length<=80&&
   openingMinor!=null&&(kind!='bank'||provider!=null)&&
   subtype!=null&&
   (customSubtypeLabel==null||
    (customSubtypeLabel!.trim().runes.length>=2&&
     customSubtypeLabel!.trim().runes.length<=40&&
     !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(customSubtypeLabel!)))&&
   (smsSuffix.text.trim().isEmpty||
    (kind=='bank'&&RegExp(r'^[0-9]{4}$').hasMatch(smsSuffix.text.trim())));
 }
 Future<void> addCustomSubtype()async{
  // Keep the typed value in the nested dialog state. A locally owned
  // TextEditingController may otherwise be disposed while the reverse route
  // animation still rebuilds its TextField (observed in Flutter widget CI).
  String typed='';
  final chosen=await showDialog<String>(context:context,
   builder:(dialog)=>StatefulBuilder(builder:(dialog,refresh){
     final label=typed.trim();
     final existing={
      ...?widget.customSubtypeOptions[kind],...?sessionCustomSubtypes[kind],
     }.map((value)=>value.toLowerCase());
     final allowed=label.runes.length>=2&&label.runes.length<=40&&
      !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(label)&&
      !existing.contains(label.toLowerCase());
     return AlertDialog(
      title:Text(t('إضافة نوع حساب','Add account subtype')),
      content:TextField(
       key:const Key('m487-custom-account-subtype-input'),
       autofocus:true,maxLength:40,
       onChanged:(value)=>refresh(()=>typed=value),
       decoration:InputDecoration(
        labelText:t('اسم النوع الجديد','New subtype name'),
        helperText:t('اسم وصفي فقط؛ لا يغيّر تصنيف الحساب أو رصيده',
         'Display label; no effect on account classification or balance'),
        border:const OutlineInputBorder())),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:Text(t('إلغاء','Cancel'))),
       FilledButton(key:const Key('m487-custom-account-subtype-save'),
        onPressed:allowed?()=>Navigator.pop(dialog,label):null,
        child:Text(t('إضافة','Add'))),
      ]);
    }));
   if(chosen==null||!mounted)return;
   setState((){
    sessionCustomSubtypes.putIfAbsent(kind,()=><String>{}).add(chosen);
    customSubtypeLabel=chosen;
    subtype=kind=='bank'?'other':'digital';
   });
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  key:const Key('m470-new-account-dialog'),
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
  title:Row(children:[
   const CircleAvatar(backgroundColor:Color(0xFFE6F5EC),
    child:Icon(Icons.account_balance_wallet_outlined,color:Color(0xFF087A54))),
   const SizedBox(width:10),
   Expanded(child:Text(t('إضافة حساب مالي','Add money account'),
    style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700))),
  ]),
  content:SizedBox(width:340,child:SingleChildScrollView(
   child:Column(mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('حدد نوع الحساب ورصيده الافتتاحي.',
     'Choose the account type and opening balance.'),
     style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:14),
    DropdownButtonFormField<String>(
     key:const Key('m470-new-account-kind'),
     initialValue:kind,isExpanded:true,
     decoration:InputDecoration(
      labelText:t('نوع الحساب *','Account type *'),
      border:const OutlineInputBorder()),
     items:[
      DropdownMenuItem(value:'bank',child:Text(t('حساب بنكي','Bank account'))),
      DropdownMenuItem(value:'cash',child:Text(t('نقدي','Cash'))),
      DropdownMenuItem(value:'wallet',child:Text(t('محفظة','Wallet'))),
      DropdownMenuItem(value:'other',child:Text(t('أخرى','Other'))),
     ],
     onChanged:(v){if(v!=null)setState((){
      kind=v;provider=null;customSubtypeLabel=null;
      subtype=kind=='cash'?'cash':kind=='other'?'other':null;
     });},
    ),
    if(kind=='bank')...[
     const SizedBox(height:12),
     DropdownButtonFormField<String>(
      key:const Key('m470-new-account-provider'),
      initialValue:provider,isExpanded:true,
      decoration:InputDecoration(
       labelText:t('البنك أو الجهة *','Bank or provider *'),
       border:const OutlineInputBorder()),
      items:banks.entries.map((bank)=>DropdownMenuItem<String>(
       value:bank.key,child:Text(t(bank.value.ar,bank.value.en),
        overflow:TextOverflow.ellipsis))).toList(),
      onChanged:(v)=>setState(()=>provider=v),
     ),
    ],
    if(kind=='bank'||kind=='wallet')...[
     const SizedBox(height:12),
     KeyedSubtree(
      key:ValueKey('m487-subtype-$kind-${customSubtypeLabel??subtype}-$subtypeRevision'),
      child:DropdownButtonFormField<String>(
       key:const Key('m470-new-account-subtype'),
       initialValue:customSubtypeLabel==null?subtype:
        'custom:$customSubtypeLabel',
       isExpanded:true,
       decoration:InputDecoration(
        labelText:t('نوع الحساب التفصيلي *','Detailed account type *'),
        border:const OutlineInputBorder()),
       items:[
        ...(kind=='bank'?
         <String,({String ar,String en})>{
          'current':(ar:'جاري',en:'Current/checking'),
          'savings':(ar:'ادخار',en:'Savings'),
          'investment':(ar:'استثماري',en:'Investment asset'),
          'deposit':(ar:'وديعة',en:'Term deposit'),
          'other':(ar:'حساب بنكي آخر',en:'Other bank account'),
         }:
         <String,({String ar,String en})>{
          'digital':(ar:'محفظة رقمية',en:'Digital wallet'),
          'prepaid':(ar:'مسبقة الدفع',en:'Prepaid wallet'),
         }).entries.map((entry)=>DropdownMenuItem<String>(
          value:entry.key,child:Text(t(entry.value.ar,entry.value.en),
           overflow:TextOverflow.ellipsis))),
        ...{
         ...?widget.customSubtypeOptions[kind],...?sessionCustomSubtypes[kind],
        }.map((label)=>DropdownMenuItem<String>(
         value:'custom:$label',
         child:Text(label,overflow:TextOverflow.ellipsis))),
        DropdownMenuItem<String>(
         value:'__add_custom__',
         child:Row(children:[
          const Icon(Icons.add_circle_outline,size:18),
          const SizedBox(width:8),
          Flexible(child:Text(t('إضافة نوع حساب','Add account subtype'),
           maxLines:1,overflow:TextOverflow.ellipsis)),
         ])),
       ],
       onChanged:(v){
        if(v=='__add_custom__'){
         // A DropdownRoute is still closing inside onChanged. Opening a
         // second dialog in that build scope can mark detached dropdown
         // descendants dirty (Flutter 'wrong build scope' assertion).
         // Defer the nested route until the dropdown has finished its frame.
         WidgetsBinding.instance.addPostFrameCallback((_)async{
          if(!mounted)return;
          await addCustomSubtype();
          // Re-create the field with its previously committed choice on
          // Cancel; the special menu command is never a saved subtype.
          if(mounted)setState(()=>subtypeRevision++);
         });
         return;
        }
        if(v==null)return;
        setState((){
         customSubtypeLabel=v.startsWith('custom:')?v.substring(7):null;
         subtype=customSubtypeLabel==null?v:
          (kind=='bank'?'other':'digital');
        });
       },
      )),
    ],
    if(kind=='bank')...[
     const SizedBox(height:12),
     TextField(
      key:const Key('m470-new-account-last-four'),
      controller:smsSuffix,
      keyboardType:TextInputType.number,
      maxLength:4,
      onChanged:(_)=>setState((){}),
      decoration:InputDecoration(
       labelText:t('آخر ٤ أرقام للحساب/البطاقة (اختياري)',
        'Last 4 account/card digits (optional)'),
       helperText:t('تُحفظ بعد تأكيدك للربط الآمن بالرسائل البنكية',
        'Stored with consent for verified bank SMS linking'),
       errorText:smsSuffix.text.trim().isNotEmpty&&
        !RegExp(r'^[0-9]{4}$').hasMatch(smsSuffix.text.trim())?
        t('أدخل ٤ أرقام إنجليزية أو اتركه فارغًا',
         'Enter 4 digits or leave blank'):null,
       border:const OutlineInputBorder()),
     ),
    ],
    const SizedBox(height:12),
    TextField(
     key:const Key('m470-new-account-label'),
     controller:nickname,maxLength:80,
     onChanged:(_)=>setState((){}),
     decoration:InputDecoration(
      labelText:t('اسم الحساب *','Account name *'),
      hintText:t('مثال: الجاري أو الادخار','e.g. Current or Savings'),
      border:const OutlineInputBorder()),
    ),
    const SizedBox(height:10),
    TextField(
     key:const Key('m470-new-account-opening'),
     controller:opening,
     keyboardType:const TextInputType.numberWithOptions(decimal:true),
     onChanged:(_)=>setState((){}),
     decoration:InputDecoration(
      labelText:t('الرصيد الافتتاحي بالريال *','Opening balance in SAR *'),
      helperText:t('الرصيد الافتتاحي مش معاملة دخل',
       'Opening balance is not an income transaction'),
      errorText:openingMinor==null
       ?t('أدخل مبلغًا صحيحًا غير سالب','Enter a valid nonnegative amount'):null,
      border:const OutlineInputBorder()),
    ),
   ]))),
  actions:[
   TextButton(onPressed:()=>Navigator.pop(context),
    child:Text(t('إلغاء','Cancel'))),
   FilledButton(
    key:const Key('m470-new-account-save'),
    onPressed:valid?()=>Navigator.pop(context,WaffraNewAccountDraft(
     name:accountLabel,kind:kind,openingMinor:openingMinor!,
     providerId:kind=='bank'?provider:
      kind=='wallet'?'other':'none',
     subtype:subtype,customSubtypeLabel:customSubtypeLabel,
     lastFour:kind=='bank'&&smsSuffix.text.trim().isNotEmpty?
      smsSuffix.text.trim():null)):null,
    child:Text(t('إضافة الحساب','Create account'))),
  ],
 );
}
