import 'package:flutter/material.dart';

/// Read-only on-device notices; never infer a payment from an invoice ID.
class WaffraUnknownFinancialSmsPage extends StatelessWidget {
 const WaffraUnknownFinancialSmsPage({
  super.key,required this.english,required this.messages,
  required this.onCreateManual,
 });
 final bool english;
 final List<Map<String,Object?>> messages;
 final Future<void> Function() onCreateManual;
 static const Color emerald=Color(0xFF087A54);
 bool _debt(Map<String,Object?> x)=>x['kind']=='debt_notice';
 String _date(Object? v)=>v is int?
  DateTime.fromMillisecondsSinceEpoch(v).toLocal().toString().substring(0,16):'';

 Future<void> _openMessage(BuildContext context,Map<String,Object?> item)async{
  final text=(item['body'] as String?)??'';
  final sender=(item['sender'] as String?)??'';
  final debt=_debt(item);
  final manual=await showModalBottomSheet<bool>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(sheet)=>SafeArea(child:Padding(
    padding:EdgeInsets.fromLTRB(20,8,20,18+MediaQuery.viewInsetsOf(sheet).bottom),
    child:ConstrainedBox(
     constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheet).height*.77),
     child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Text(sender,style:Theme.of(sheet).textTheme.titleLarge),
       Text(_date(item['receivedAt']),style:Theme.of(sheet).textTheme.bodySmall),
       const SizedBox(height:12),
       Text(debt?(english?'Debt notice — not a completed payment':
        'إشعار مديونية — لا يثبت حدوث عملية دفع'):
        (english?'Financial-looking SMS, not verified as a transaction':
         'رسالة ذات صلة مالية لم تتأكد كمعاملة')),
       const SizedBox(height:12),
       Flexible(child:SingleChildScrollView(child:SelectableText(text))),
       const SizedBox(height:18),
       FilledButton.icon(
        key:const Key('waffra-unknown-sms-create-manual'),
        onPressed:()=>Navigator.pop(sheet,true),
        icon:const Icon(Icons.add_circle_outline),
        label:Text(english?'Create transaction manually':'إنشاء معاملة يدويًا')),
       TextButton(onPressed:()=>Navigator.pop(sheet,false),
        child:Text(english?'Close':'إغلاق')),
      ]),
    ),
   )),
  );
  // Only the user's separate, blank transaction form may write finance.
  if(manual==true&&context.mounted)await onCreateManual();
 }

 @override Widget build(BuildContext context){
  final debtCount=messages.where(_debt).length;
  return Scaffold(
   appBar:AppBar(title:Text(english?'Unrecognized SMS':'رسائل SMS غير معروفة')),
   body:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(16,10,16,12),
     child:Container(
      width:double.infinity,padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:emerald.withValues(alpha:.08),
       borderRadius:BorderRadius.circular(16)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(messages.length.toString()+(english?' messages to review':
        ' رسائل للمراجعة'),style:Theme.of(context).textTheme.titleMedium),
       const SizedBox(height:6),
       Text(english?
        'Only potential financial notices from your activation month appear. '
        'Debt notices are not recorded expenses. No SMS is uploaded or saved '
        'as a transaction automatically.':
        'نعرض الإشعارات المالية المحتملة من شهر التفعيل فقط. '
        'عدد إشعارات المديونية: '+debtCount.toString()+
        '. لا نرسل هذه الرسائل للسحابة ولا نسجل منها مصروفًا تلقائيًا.',
        style:Theme.of(context).textTheme.bodySmall),
      ]))),
    Expanded(child:messages.isEmpty?
     Center(child:Text(english?'No unrecognized financial SMS found.':
      'ما لقينا رسائل مالية غير معروفة في فترة الفحص.',
      textAlign:TextAlign.center)):
     ListView.separated(
      key:const Key('waffra-unknown-sms-list'),
      padding:const EdgeInsets.fromLTRB(14,0,14,24),
      itemCount:messages.length,
      separatorBuilder:(_,__)=>const SizedBox(height:8),
      itemBuilder:(ctx,index){
       final item=messages[index],debt=_debt(item);
       return Card(child:InkWell(
        key:Key('waffra-unknown-sms-row-$index'),
        borderRadius:BorderRadius.circular(14),
        onTap:()=>_openMessage(context,item),
        child:Padding(padding:const EdgeInsets.all(14),
         child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
           const Icon(Icons.sms_outlined,color:emerald,size:22),
           const SizedBox(width:10),
           Expanded(child:Text((item['sender'] as String?)??'',
            style:const TextStyle(fontWeight:FontWeight.w700))),
           Text(_date(item['receivedAt']),
            style:Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height:10),
          Text((item['body'] as String?)??'',maxLines:4,
           overflow:TextOverflow.ellipsis),
          const SizedBox(height:10),
          Row(children:[
           Icon(debt?Icons.info_outline:Icons.help_outline,size:16,
            color:debt?Colors.orange:emerald),
           const SizedBox(width:6),
           Expanded(child:Text(debt?
            (english?'Not a completed transaction':
             'ليست معاملة مالية مكتملة'):
            (english?'Requires manual review':'تحتاج مراجعة يدوية'),
            style:Theme.of(context).textTheme.bodySmall)),
           const Icon(Icons.chevron_left),
          ]),
         ]),
        ),
       ));
      },
     )),
   ])),
  );
 }
}
