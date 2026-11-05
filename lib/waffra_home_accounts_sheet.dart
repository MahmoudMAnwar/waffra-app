import 'package:flutter/material.dart';
import 'storage/waffra_accounts_repository.dart';

/// Viewing another account NEVER changes the default money source used by
/// manual capture, SMS, goals or recurring payments.
class WaffraHomeAccountChip extends StatelessWidget {
 const WaffraHomeAccountChip({super.key,required this.label,
  required this.english,required this.onTap});
 final String label;final bool english;final VoidCallback onTap;
 @override Widget build(BuildContext context)=>Align(
  alignment:AlignmentDirectional.centerStart,
  child:OutlinedButton.icon(
   key:const Key('m467-home-account-picker'),
   onPressed:onTap,
   icon:const Icon(Icons.keyboard_arrow_down_rounded),
   label:Row(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.account_balance_wallet_outlined,size:18),
    const SizedBox(width:7),
    ConstrainedBox(constraints:const BoxConstraints(maxWidth:200),
     child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis)),
   ]),
   style:OutlinedButton.styleFrom(
    foregroundColor:const Color(0xFF07563B),
    side:const BorderSide(color:Color(0xFF78BC9D),width:1.3),
    padding:const EdgeInsets.symmetric(horizontal:13,vertical:11),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),
  ));
}

class WaffraHomeAccountsSheet extends StatelessWidget{
 const WaffraHomeAccountsSheet({super.key,required this.accounts,
  required this.selected,required this.english});
 final List<WaffraAccountBalance> accounts;
 final String selected;final bool english;
 String t(String ar,String en)=>english?en:ar;
 String sar(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';
 Widget choice(BuildContext context,{required String id,
  required String title,required String caption,required IconData icon}){
  final active=selected==id;
  // ListTile ink must paint on the nearest Material, not behind an
  // opaque DecoratedBox. Preserve the approved selected tint and outline.
  return Padding(
   padding:const EdgeInsets.symmetric(vertical:4),
   child:Material(
    color:active?const Color(0xFFE7F6ED):Theme.of(context).cardColor,
    shape:RoundedRectangleBorder(
     borderRadius:BorderRadius.circular(15),
     side:BorderSide(color:active?
      const Color(0xFF087A54):const Color(0xFFDBEAE1))),
    clipBehavior:Clip.antiAlias,
    child:ListTile(
    key:Key('m467-account-choice-'+id),
    leading:Icon(icon,color:const Color(0xFF087A54)),
    title:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
     style:const TextStyle(fontWeight:FontWeight.w700)),
    subtitle:Text(caption,maxLines:1,overflow:TextOverflow.ellipsis),
    trailing:Icon(active?Icons.check_circle_rounded:Icons.circle_outlined,
     color:active?const Color(0xFF087A54):Colors.grey),
    onTap:()=>Navigator.pop(context,id),
   )));
 }
 @override Widget build(BuildContext context){
  return SafeArea(top:false,child:ConstrainedBox(
   constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.77),
   child:Padding(padding:const EdgeInsets.fromLTRB(14,10,14,16),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     Row(children:[
      const Icon(Icons.account_balance_wallet_outlined,color:Color(0xFF087A54)),
      const SizedBox(width:9),
      Expanded(child:Text(t('اختر الحساب','Choose account'),
       style:Theme.of(context).textTheme.titleLarge)),
      IconButton(tooltip:t('إغلاق','Close'),
       icon:const Icon(Icons.close_rounded),
       onPressed:()=>Navigator.pop(context)),
     ]),
     const SizedBox(height:5),
     Flexible(child:ListView(shrinkWrap:true,children:[
      choice(context,id:'all',title:t('كل الحسابات','All accounts'),
       caption:t('إجمالي الحسابات','All registered accounts'),
       icon:Icons.layers_outlined),
      for(final a in accounts.where((a)=>!a.archived))
       choice(context,id:a.id,title:a.name,caption:sar(a.balanceMinor),
        icon:a.kind=='bank'?Icons.account_balance_rounded:
         a.kind=='cash'?Icons.payments_outlined:
         Icons.account_balance_wallet_outlined),
     ])),
     const SizedBox(height:8),
     OutlinedButton.icon(
      key:const Key('m467-manage-accounts'),
      onPressed:()=>Navigator.pop(context,'manage'),
      icon:const Icon(Icons.settings_outlined),
      label:Text(t('إدارة الحسابات','Manage accounts')),
     ),
    ]),
   )));
 }
}
