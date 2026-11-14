part of 'main.dart';

/// M703 / #633: original bank-SMS transfer review and verified SQLCipher
/// fee/acknowledgment flow extracted from Home State without changing logic.
extension _WaffraHomeSmsTransferReview on _HomeScreenState {
 /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.
 /// No SMS becomes income/expense or selects bank accounts by guessing.
 Future<void> _reviewSmsAccountTransfer({
  required Map<String,Object?> item,
  required WaffraBankSmsFacts facts,
 })async{
  final id=item['id'],body=item['body'];
  if(id is! String||body is! String||
     facts.kind!=WaffraBankOperationKind.transfer)return;
  // Verify the main transfer amount independently from fees/balances.
  // Never use a fee's currency as proof of a SAR account transfer.
  final sourceAmount=WaffraSmsCurrencies.originalAmount(body);
  if((sourceAmount!=null&&sourceAmount.currency!='SAR')||
     WaffraSmsCurrencies.requiresReviewForSarLedger(body)){
   if(mounted)snack(context,
    'مبلغ التحويل الأساسي أو عملته غير مؤكد من الرسالة. '
    'لن تُسجّل الرسوم أو عملة مجهولة كتحويل.',isError:true);
   return;
  }
  final verifiedMinor=facts.pending||sourceAmount==null?0:
   (waffraSarAmountMinor(sourceAmount.amount.toStringAsFixed(2))??0);
  final feeTotalMinor=facts.fee==null?null:
   WaffraBankSmsFactsParser.extraDebitMinor(
    principalMinor:verifiedMinor,feeSar:facts.fee);
  // No confirmed principal means an EMPTY editable field, never the fee.
  // The verified form refuses zero amounts on submit.
  // The first reviewed transfer on a clean install must bootstrap the same
  // verified finance bridge used by manual entry, before showing the form.
  await _ensureFinanceBound();
  if(!mounted)return;
  final bridge=_financeBinding?.accountsBridge;
  if(bridge==null){
   if(mounted)snack(context,'الحسابات الموثقة غير متاحة.',
    isError:true);
   return;
  }
  try{
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   final accounts=await api.balances();
   if(!mounted)return;
   final arrived=DateTime.fromMillisecondsSinceEpoch(
    item['receivedAt'] is int?item['receivedAt'] as int:
     DateTime.now().millisecondsSinceEpoch);
   // M597: received-at is only a picker hint, never a fabricated bank
   // transaction timestamp. Unknown dates require an explicit day AND time.
   final smsDate=bankSmsDate(body,referenceDate:arrived);
   final needsDateConfirmation=smsDate==null||
    bankSmsHasUnverifiedTimestamp(body);
   // Open the transfer form immediately. A received-at fallback is only a
   // visible hint: the editor refuses commit until the user picks a date.
   final date=needsDateConfirmation?arrived:smsDate;
   final prefill=WaffraInternalTransferDraft(
    // Native fingerprint includes sender, body AND receivedAt; two distinct
    // identical-body SMS must not share a single SQLCipher transfer ID.
    requestId:WaffraAutoSms.transferIdForMessage(id),
    fromId:'',toId:'',amountMinor:verifiedMinor,
    occurredIso:date.toIso8601String(),memo:'تحويل من رسالة بنكية');
   var saved=false,ack=false;
   await Navigator.of(context).push<void>(MaterialPageRoute(
    builder:(route)=>Scaffold(
     appBar:AppBar(title:const WaffraText('مراجعة حوالة بنكية')),
     body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),
       child:WaffraText('من الحساب: '+
        (facts.sourceSuffix==null?'غير معروف':'••••'+facts.sourceSuffix!)+
        '  إلى الحساب: '+
        (facts.destinationSuffix==null?'غير معروف':
         '••••'+facts.destinationSuffix!))),
      if(facts.fee!=null&&facts.fee!>0)
       Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
        child:WaffraText(
         'المبلغ الأساسي: ${(verifiedMinor/100).toStringAsFixed(2)} ريال • '
         'رسوم البنك: ${facts.fee!.toStringAsFixed(2)} ريال • '
         'إجمالي الخصم عند احتساب الرسوم منفصلة: '+
         (feeTotalMinor==null?'يحتاج مراجعة':
          (feeTotalMinor/100).toStringAsFixed(2)+' ريال')+
         '. عند التأكيد ستختار هل الرسوم ضمن الخصم أو منفصلة؛ '
         'التحويل والرسوم وبصمة الرسالة يُحفظوا معًا بأمان.',
         style:const TextStyle(color:emerald,fontSize:12))),
      Expanded(child:WaffraAccountTransactionForm(
       accounts:accounts,english:waffraIsEnglish,
       initialSmsTransfer:prefill,originalSmsText:body,
       requireSmsDateConfirmation:needsDateConfirmation,
       onCreateSmsAccount:(group,createProvider,isDestination)async{
        // #416: never infer transfer source or destination from SMS sender.
        final existing=await api.balances();
        if(!mounted)return null;
        final bank=RegExp(r'^bank:institution:(rajhi|inma|snb|riyad|bilad|stc)$')
         .firstMatch(createProvider?'':group??'')?.group(1);
        final custom=<String,List<String>>{
         for(final kind in const ['bank','wallet'])
          kind:existing.where((a)=>!a.archived&&a.kind==kind&&
           a.customSubtypeLabel!=null).map((a)=>a.customSubtypeLabel!)
           .toSet().toList()..sort(),
        };
        // Each proposed suffix comes from its own source/destination field,
        // never copied from the opposite side or inferred from a sender.
        // This remains editable and requires an explicit owned-account save.
        final detectedBank=WaffraSmsAccountLearning.bankGroup(
         item['sender'] is String?item['sender'] as String:'');
        final suggestedBank=bank??(createProvider?detectedBank:null);
        final proposedSuffix=isDestination?
         WaffraSmsAccountLearning.suffix4(facts.destinationSuffix):
         (bank==null||bank==detectedBank)?
          WaffraSmsAccountLearning.suffix4(facts.sourceSuffix):null;
        final choice=await showWaffraDialog<WaffraNewAccountDraft>(
         context:context,builder:(ctx)=>WaffraNewAccountDialog(
          english:waffraIsEnglish,suggestedProviderId:suggestedBank,
          suggestedLastFour:proposedSuffix,
          customSubtypeOptions:custom));
        if(choice==null||!mounted)return null;
        if(bank!=null&&(choice.kind!='bank'||choice.providerId!=bank)){
         throw StateError('Child account changed bank group');
        }
        final createdId='m499-sms-transfer-'+
         DateTime.now().microsecondsSinceEpoch.toString();
        await api.createTypedAccountWithIdentity(
         id:createdId,name:choice.name,kind:choice.kind,
         providerId:choice.providerId??'none',
         subtype:choice.subtype??'other',openingMinor:choice.openingMinor,
         createdIso:DateTime.now().toUtc().toIso8601String(),
         lastFour:choice.lastFour,customSubtypeLabel:choice.customSubtypeLabel,
         userConfirmed:true);
        final refreshed=await api.balances();
        final created=refreshed.where((a)=>a.id==createdId&&!a.archived).toList();
        if(created.length!=1)throw StateError('Created account not verified');
        unawaited(_m467RefreshHomeAccounts());
        return created.single;
       },
       onConfirmTransfer:(draft)async{
        // M597: a positive source-bank fee is an independent expense.
        // Do not post the principal first, or ACK the message before both
        // the principal and fee survive one verified SQLCipher transaction.
        final fee=facts.fee;
        if(fee!=null&&fee>0){
         final fullDebit=WaffraBankSmsFactsParser.extraDebitMinor(
          principalMinor:draft.amountMinor,feeSar:fee);
         final feeMinor=fullDebit==null?null:
          fullDebit-draft.amountMinor;
         if(feeMinor==null||feeMinor<=0||fullDebit==null||!mounted){
          throw StateError('Ambiguous SAR bank fee must be reviewed.');
         }
         final selected=await showWaffraDialog<String>(
          context:context,builder:(dialog)=>AlertDialog(
           title:WaffraText(waffraIsEnglish?
            'Confirm bank transfer fee':'تأكيد رسوم التحويل'),
           content:WaffraText(waffraIsEnglish?
            'Principal: ${(draft.amountMinor/100).toStringAsFixed(2)} SAR. '
            'Bank fee: ${(feeMinor/100).toStringAsFixed(2)} SAR. '
            'If separately charged, the source pays '
            '${(fullDebit/100).toStringAsFixed(2)} SAR and the other '
            'account receives the principal. If included in the shown '
            'debit, the other account receives the principal less the fee. '
            'Choose only what your statement confirms.':
            'المبلغ: ${(draft.amountMinor/100).toStringAsFixed(2)} ريال، '
            'والرسوم: ${(feeMinor/100).toStringAsFixed(2)} ريال. '
            'لو الرسوم منفصلة، المصدر يُخصم منه '
            '${(fullDebit/100).toStringAsFixed(2)} ريال والمستلم يستلم '
            'المبلغ الأساسي. لو الرسوم ضمن المبلغ المخصوم، '
            'المستلم يستلم المبلغ بعد خصم الرسوم. '
            'اختار فقط الحالة اللي متأكد منها من كشف البنك.'),
           actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog),
             child:WaffraText(waffraIsEnglish?'Back':'عودة')),
            OutlinedButton(
             onPressed:()=>Navigator.pop(dialog,'included'),
             child:WaffraText(waffraIsEnglish?
              'Fee included':'الرسوم ضمن الخصم')),
            FilledButton(
             onPressed:()=>Navigator.pop(dialog,'separate'),
             child:WaffraText(waffraIsEnglish?
              'Separate charge':'الرسوم منفصلة')),
           ]));
         if(selected!='included'&&selected!='separate'){
          throw StateError('Fee confirmation was not granted.');
         }
         // Re-observe the signed-in, activated SQLCipher accounts before
         // submitting. The writer checks this generation under its lock.
         final latest=await api.balances();
         if(!latest.any((a)=>a.id==draft.fromId&&!a.archived)||
            !latest.any((a)=>a.id==draft.toId&&!a.archived)){
          throw StateError('Selected transfer accounts changed.');
         }
         await api.transferReviewedSmsWithFee(
          transferId:draft.requestId,
          fromAccountId:draft.fromId,toAccountId:draft.toId,
          principalMinor:draft.amountMinor,feeMinor:feeMinor,
          feeIncludedInDebit:selected=='included',
          occurredIso:draft.occurredIso,messageHash:id,
          feeCategory:'خدمات مالية / رسوم تحويل',
          userConfirmed:true);
        }else{
         await api.transfer(id:draft.requestId,
          fromAccountId:draft.fromId,toAccountId:draft.toId,
          amountMinor:draft.amountMinor,occurredIso:draft.occurredIso,
          note:draft.memo,userConfirmed:true);
        }
        saved=true;
        // The transfer is already committed. Queue-only ACK would replay
        // this SMS on historical rescan; use a separate durable marker.
        ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id]);
        if(route.mounted)Navigator.of(route).pop();
       })),
     ]),
    )));
   if(!mounted||!saved)return;
   try{await _learnSafeSmsRule(body:body,
    sender:item['sender'] is String?item['sender'] as String:'',
    kind:'transfer');}catch(_){}
   if(ack){
    setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
    snackSuccess(context,'تم تسجيل التحويل بين الحسابات.');
   }else{
    snack(context,'التحويل اتسجل لكن تأكيد إزالة الرسالة فشل. '
     'معرّف العملية يمنع الخصم مرتين.',isError:true);
   }
   // M597: the SQLCipher fee entry and two account balances are committed.
   // Refresh verified Home and Widget projections off the tap/route frame,
   // never by recalculating an unverified optimistic balance on the UI thread.
   unawaited(()async{
    try{
     await _refreshFromVerifiedFinance();
     if(mounted)await _m467RefreshHomeAccounts();
     await _refreshWidget();
    }catch(e){
     debugPrint('Post-transfer verified refresh: ${e.runtimeType}');
    }
   }());
   unawaited(_refreshAutoSmsInbox());
  }catch(_){
   if(mounted)snack(context,'تعذر تسجيل التحويل؛ الرسالة ما زالت للمراجعة.',
    isError:true);
  }
 }
}
