part of 'main.dart';

/// M719 / #633: original SMS/manual entry sheet UI and verified finance
/// save logic extracted verbatim. No writer, account source or field changed.
extension _WaffraHomeEntrySheetModule on _HomeScreenState {
 Future<void> entrySheet({MoneyEntry? initial,bool sms=false,String? initialSms,
  String? reviewedSender,bool? reviewedIncomeOverride,bool? manualIncomeOverride,
  String? reviewedOriginalSms})async {
  // A paid goal due is an immutable verified two-source settlement.
  // There is no independent edit path that can rewrite its wallet/bank split.
  if(initial?.sourceType=='goal_due'){
   await _m665ExplainLinkedGoalEdit(paid:true);
   return;
  }
  // Cold-start money selection needs a verified, non-Home-header account list.
  if(!_m468VerifiedAccountsLoaded){
   await _m467RefreshHomeAccounts();
   if(!mounted)return;
  }
  // #420: a legacy-only entry is NOT treated as successfully migrated.
  WaffraVerifiedAccountsApi? editAccountLinkApi;
  bool canLinkExistingAccount=false;
  String? originalLinkedAccountId;
  if(initial!=null){
   try{
    await _ensureFinanceBound();
    final bridge=_financeBinding?.accountsBridge;
    if(bridge!=null){
     final api=WaffraVerifiedAccountsApi(bridge:bridge);
     final found=await api.readExistingEntryAccount(entryId:initial.id);
     if(found.exists){
      canLinkExistingAccount=true;
      originalLinkedAccountId=found.accountId;
      editAccountLinkApi=api;
     }
    }
   }catch(error){
    debugPrint('M500 edit-account read unavailable: ${error.runtimeType}');
   }
   if(!mounted)return;
  }
  // Restore an unfinished bank SMS editor after one-step Back. No money or
  // SMS acknowledgement happens until a separate verified commit.
  final smsEditorDraftKey=sms&&initial==null&&initialSms!=null?
   bankSmsHash(initialSms):null;
  final smsEditorDraft=smsEditorDraftKey==null?
   null:_m492SmsEditorDrafts[smsEditorDraftKey];
  // M485 / #403 #404: correction of a detected SMS is still a reviewed
  // bank-SMS transaction, not a new unrelated manual entry. Use parsed
  // values only when source amount, SAR, direction and status agree.
  final parsedSms=sms&&initialSms!=null?BankParser.parse(initialSms):null;
  final factsSms=sms&&initialSms!=null?
   WaffraBankSmsFactsParser.parse(initialSms):null;
  final sourceAmount=sms&&initialSms!=null?
   WaffraSmsCurrencies.originalAmount(initialSms):null;
  // Direct SMS corrections and native review use the same latest offline
  // category rules. Never infer a money account or post without approval.
  var editorRules=<WaffraSmsLocalRule>[];
  if(sms&&initialSms!=null&&_smsRuleOwnerKey.isNotEmpty){
   try{editorRules=await const WaffraSmsLocalRuleStore()
    .read(_smsRuleOwnerKey);}catch(_){/* Editable review still available. */}
  }
  if(!mounted)return;
  final editorMatchedRule=sms&&initialSms!=null&&factsSms!=null?
   WaffraSmsLocalRules.resolve(body:initialSms,
    sender:reviewedSender??'',bankKind:factsSms.kind,
    custom:editorRules):null;
  final editorLearnedCategory=editorMatchedRule!=null&&
   categories.any((c)=>c.isSubcategory&&
    c.income==editorMatchedRule.income&&
    c.name==editorMatchedRule.category&&
    waffraCategoryAvailableForNewEntry(categories,c))?
     editorMatchedRule.category:null;
  final trustedSms=parsedSms!=null&&factsSms!=null&&!factsSms.pending&&
   (factsSms.kind==WaffraBankOperationKind.income||
    factsSms.kind==WaffraBankOperationKind.expense)&&
   parsedSms.amount!=null&&parsedSms.amount!>0&&
   !parsedSms.requiresCurrencyReview&&
   sourceAmount!=null&&sourceAmount.currency=='SAR'&&
   (sourceAmount.amount-parsedSms.amount!).abs()<0.00001&&
   parsedSms.income==(factsSms.kind==WaffraBankOperationKind.income);
  final suggestedSmsTitle=trustedSms?
   (RegExp(r'شحن\s*(?:جوال|هاتف|رصيد)|top[ -]?up',
    caseSensitive:false).hasMatch(initialSms!)?
     (waffraIsEnglish?'Mobile top-up':'شحن الجوال'):
     parsedSms.title):'';
  final title=TextEditingController(text:
   (smsEditorDraft?['title'] as String?)??initial?.title??
   suggestedSmsTitle);
  final notes=TextEditingController(text:
   (smsEditorDraft?['notes'] as String?)??
   (initial?.sourceType=='sms'?initial?.personalNotes:initial?.notes)??'');
  final value=TextEditingController(text:
   (smsEditorDraft?['amount'] as String?)??(initial!=null?
   formatWaffraEditAmount(initial.amount):
   trustedSms?formatWaffraMoney(parsedSms.amount??0):''));
  final message=TextEditingController(text:initialSms??'');
  // Explicit compact correction outranks an OLD uncommitted SMS draft.
  // Ordinary manual/receipt editing still preserves previous precedence.
  bool income=reviewedIncomeOverride??(smsEditorDraft?['income'] as bool?)??
   initial?.income??manualIncomeOverride??
   (trustedSms?(parsedSms.income):false),
   analyzing=false,hasParsed=initialSms!=null;
  bool submitTapped=false;
  // M662.8: manual new entry must have NO default parent/category.
  // 'أخرى' exists as an expense parent but not as an income parent; using
  // it here silently selected expense/Other before the owner chose a category.
  // Keep existing edit categories and previously-approved SMS suggestions.
  String category=(smsEditorDraft?['category'] as String?)??
   initial?.category??(sms?
    (trustedSms?(editorLearnedCategory??parsedSms.category):'أخرى'):'');
  String? selectedParentId;
  String? selectedBudgetId=(smsEditorDraft?['budget'] as String?)??initial?.budgetId;
  var entryAccounts=_m467Accounts.where((a)=>!a.archived).toList();
  var entryProviders=WaffraRecurringAccountGroups.withBankProviderChoices(entryAccounts);
  String? chosenManualProvider=smsEditorDraft?['provider'] as String?;
  String? chosenManualAccount=smsEditorDraft?['account'] as String?;
  // The sender identifies a bank/provider only, NEVER a financial account.
  // Prefer a matching existing bank/wallet group; otherwise show the bank
  // catalog entry, allowing the user to create a linked account directly.
  if(sms&&initial==null&&chosenManualProvider==null&&
     reviewedSender!=null){
   final bank=WaffraSmsAccountLearning.bankGroup(reviewedSender);
   if(bank!=null){
    final existing=entryProviders.where((group)=>
     group.id.endsWith(':institution:$bank')&&
     group.accounts.isNotEmpty).toList();
    final catalog=entryProviders.where((group)=>
     group.id=='bank:institution:$bank').toList();
    if(existing.length==1)chosenManualProvider=existing.single.id;
    else if(catalog.length==1)chosenManualProvider=catalog.single.id;
   }
  }
  if(initial!=null&&canLinkExistingAccount&&originalLinkedAccountId!=null){
   final matched=entryProviders.where((p)=>p.accounts.any(
    (a)=>a.id==originalLinkedAccountId)).toList();
   if(matched.length==1){
    chosenManualProvider=matched.single.id;
    chosenManualAccount=originalLinkedAccountId;
   }
  }
  String? chosenManualProviderCategory=chosenManualProvider==null?null:
   WaffraSaudiFinancialProviders.categoryForGroup(chosenManualProvider);
  int budgetMenuRevision=0; // reset action-only dropdown selections
  int accountProviderMenuRevision=0,accountChildMenuRevision=0;
  int transferSourceProviderRevision=0,transferTargetProviderRevision=0;
  int transferSourceChildRevision=0,transferTargetChildRevision=0;
  {
   // All reviewed transactions, including SMS, must use a real child category.
   final matchingLeaf=categories.where((c)=>c.income==income&&
    c.isSubcategory&&c.name==category).toList();
   if(matchingLeaf.isNotEmpty&&categories.any((c)=>!c.isSubcategory&&
      c.income==income&&c.id==matchingLeaf.first.parentId)){
    selectedParentId=matchingLeaf.first.parentId;
   }else{
    final legacyParent=categories.where((c)=>c.income==income&&
     !c.isSubcategory&&c.name==category).toList();
    selectedParentId=legacyParent.isEmpty?null:legacyParent.first.id;
    category='';
   }
  }
  if(smsEditorDraft!=null){
   final savedParent=smsEditorDraft['parent'] as String?;
   final savedCategory=smsEditorDraft['category'] as String?;
   if(savedParent!=null&&categories.any((c)=>c.id==savedParent&&
      !c.isSubcategory&&c.income==income)){
    selectedParentId=savedParent;
    if(savedCategory!=null&&categories.any((c)=>c.isSubcategory&&
       c.parentId==savedParent&&c.income==income&&c.name==savedCategory)){
     category=savedCategory;
    }
   }
   if(chosenManualAccount!=null&&
       !entryAccounts.any((a)=>a.id==chosenManualAccount)){
    chosenManualAccount=null;
    chosenManualProvider=null;
   }
  }
  // Unknown original SMS timestamp requires an explicit calendar pick.
  final originalSmsDate=sms&&initialSms!=null?
   bankSmsDate(initialSms,referenceDate:DateTime.now()):null;
  var smsDateConfirmed=initial!=null||
   smsEditorDraft?['dateConfirmed']==true||originalSmsDate!=null;
  DateTime date=(smsEditorDraft?['date'] as DateTime?)??
   initial?.date??originalSmsDate??DateTime.now();
   String? suggestion,pendingHash,receiptPath=initial?.receiptPath;
   final stagedReceiptCopies=<String>[];
   // All three modes share the SAME manual bottom sheet. Transfers never
   // enter a categorized income/expense ledger or an attachment writer.
   bool transferSelected=false,transferSaving=false,transferCommitted=false;
   WaffraVerifiedAccountsApi? transferApi;
   List<WaffraAccountBalance> transferAccounts=<WaffraAccountBalance>[];
   String? transferSource,transferDestination,transferError;
   String? transferSourceProvider,transferDestinationProvider;
   String? transferSourceCategory,transferDestinationCategory;
   DateTime transferDate=DateTime.now();
   final transferAmount=TextEditingController();
   final transferNote=TextEditingController();
   final transferRequestId='m466-'+DateTime.now().microsecondsSinceEpoch.toString();
   bool attempted=false;
   bool explicitlyApprovedSmsDuplicate=false;
  Timer? debounce;
  final result=await showModalBottomSheet<MoneyEntry>(
   context:context,isScrollControlled:true,showDragHandle:true,
   useSafeArea:true,
   builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,update){
    void parseNow(String text) {
     debounce?.cancel();
      if(text.trim().isEmpty){update((){hasParsed=false;analyzing=false;suggestion=null;});return;}
     update(()=>analyzing=true);
     debounce=Timer(const Duration(milliseconds:300),(){
      if(!sheetContext.mounted)return;
      final p=BankParser.parse(text);
      final merchant=waffraMerchantKey(text);
      final learned=merchant==null?null:learnedMerchantCategories[merchant];
      update((){
       income=p.income;
       category=learned!=null&&categories.any((c)=>c.income==p.income&&c.name==learned)
        ?learned:p.suggestedCategory!=null&&categories.any((c)=>c.income==p.income&&c.name==p.suggestedCategory)
        ?p.suggestedCategory!:p.category;
       title.text=p.title;value.text=p.amount==null?'':formatWaffraMoney(p.amount!);
       suggestion=p.suggestedCategory!=null&&!categories.any((c)=>c.income==p.income&&c.name==p.suggestedCategory)
        ?p.suggestedCategory:null;
       final matching=categories.where((c)=>c.income==income&&
        c.isSubcategory&&c.name==category).toList();
       if(matching.isNotEmpty){
        selectedParentId=matching.first.parentId;
       }else{
        final parent=categories.where((c)=>c.income==income&&
          !c.isSubcategory&&c.name==category).toList();
        selectedParentId=parent.isEmpty?null:parent.first.id;
        category='';
       }
       selectedBudgetId=null;
       hasParsed=true;analyzing=false;
      });
     });
    }
    final available=forType(income);
    final mainCategories=waffraManualCategoryParents(available,income);
    final selectedMain=mainCategories.where((c)=>c.id==selectedParentId).toList();
    final subcategories=waffraManualCategoryChildren(available,income,selectedParentId);
    final selectedSub=subcategories.where((c)=>c.name==category).toList();
    void assignBudgetInsideEditor(String? pickedId){
     // Only child-category budgets may receive NEW allocations. An existing
     // legacy parent budget is visible for history, never silently migrated.
     if(pickedId==null){selectedBudgetId=null;return;}
     final matches=namedBudgets.where((b)=>b.id==pickedId&&
      b.budget>0&&b.budgetActive&&!b.deleted).toList();
     if(matches.length!=1)return;
     // Budget allocation is independent of the user's chosen category.
     selectedBudgetId=pickedId;
    }
    Widget dateAction()=>OutlinedButton.icon(
      key:const Key('waffra-entry-date-action'),
      onPressed:WaffraHaptics.tap(()async {
       final d=await waffraPickDateWithToday(english:waffraIsEnglish,
        context:sheetContext,initialDate:date,
        firstDate:DateTime(2000),lastDate:DateTime.now());
       if(d==null||!sheetContext.mounted)return;
       if(sms){
        // Bank SMS corrections need deliberate date AND hour/minute;
        // accepting only a calendar date would silently set midnight.
        final time=await showTimePicker(
         context:sheetContext,initialTime:TimeOfDay.fromDateTime(date));
        if(time==null||!sheetContext.mounted)return;
        final confirmed=DateTime(d.year,d.month,d.day,time.hour,time.minute);
        if(confirmed.isAfter(DateTime.now())){
         snack(sheetContext,waffraIsEnglish?
          'Transaction date and time cannot be in the future.':
          'تاريخ ووقت العملية لا يمكن أن يكونا في المستقبل.',isError:true);
         return;
        }
        update((){
         date=confirmed;
         smsDateConfirmed=true;
        });
       }else{
        update(()=>date=d);
       }
      }),
      icon:const Icon(Icons.calendar_month,size:19),
      label:WaffraText(sms&&!smsDateConfirmed?
       (waffraIsEnglish?'Select date and time':'اختر التاريخ والوقت'):
       sms?
        dayText(date)+' '+date.hour.toString().padLeft(2,'0')+':'+
         date.minute.toString().padLeft(2,'0'):
        dayText(date),maxLines:1));
    Future<void> createAccountInsideEntryDropdown({required bool mainProvider,
      bool forTransfer=false,bool transferTarget=false})async{
     // #405/#416: Add inside either dropdown opens the account FORM directly,
     // not a second My Accounts page. No finance write occurs until Save.
     final selectedProviderBefore=forTransfer?
       (transferTarget?transferDestinationProvider:transferSourceProvider):
       chosenManualProvider;
     try{
      await _ensureFinanceBound();
      final bridge=_financeBinding?.accountsBridge;
      if(bridge==null)throw StateError('Verified finance source unavailable');
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      final before=await api.balances(); // establish a fresh writer witness
      if(!sheetContext.mounted)return;
      final selectedParent=mainProvider?'':selectedProviderBefore??'';
      final catalogId=selectedParent.split(':').last;
      final selectedCatalog=WaffraSaudiFinancialProviders.byId(catalogId);
      final expectedBank=selectedCatalog!=null&&
       selectedCatalog.groupId==selectedParent?selectedCatalog.id:null;
      // A masked account suffix from an Android SMS is a suggestion ONLY
      // when the reviewed sender's bank matches the selected provider.
      // Never inherit a suffix from a different bank or an uncertain SMS.
      final bankFromSender=WaffraSmsAccountLearning.bankGroup(
       reviewedSender??'');
      final bankFacts=initialSms!=null?
       WaffraBankSmsFactsParser.parse(initialSms):null;
      final proposedSuffix=trustedSms&&expectedBank!=null&&
       expectedBank==bankFromSender&&bankFacts!=null&&
       bankFacts.canAutoPostAsIncomeExpense?
       WaffraSmsAccountLearning.suffix4(
        bankFacts.kind==WaffraBankOperationKind.income?
         bankFacts.destinationSuffix:bankFacts.sourceSuffix):null;
      final customOptions=<String,List<String>>{
       for(final kind in const ['bank','wallet'])
        kind:before.where((a)=>!a.archived&&a.kind==kind&&
         a.customSubtypeLabel!=null)
         .map((a)=>a.customSubtypeLabel!).toSet().toList()..sort(),
      };
      final draft=await showWaffraDialog<WaffraNewAccountDraft>(
       context:sheetContext,builder:(dialog)=>WaffraNewAccountDialog(
        english:waffraIsEnglish,suggestedProviderId:expectedBank,
        suggestedLastFour:proposedSuffix,
        customSubtypeOptions:customOptions));
      if(draft==null||!sheetContext.mounted)return;
      // Bank child creation must stay under the selected real institution;
      // never silently convert a specific bank group into another provider.
      if(expectedBank!=null&&
         (draft.kind!=(selectedCatalog!.category==WaffraSaudiFinancialProviders.wallet?
          'wallet':'bank')||draft.providerId!=expectedBank)){
       snack(sheetContext,waffraIsEnglish?
        'The linked account must belong to the selected bank.':
        'الحساب التابع لازم يكون لنفس البنك المختار.',isError:true);
       return;
      }
      final id='m492-inline-'+DateTime.now().microsecondsSinceEpoch.toString();
      await api.createTypedAccountWithIdentity(
       id:id,name:draft.name,kind:draft.kind,
       providerId:draft.providerId??'none',
       subtype:draft.subtype??'other',
       openingMinor:draft.openingMinor,
       createdIso:DateTime.now().toUtc().toIso8601String(),
       lastFour:draft.lastFour,
       customSubtypeLabel:draft.customSubtypeLabel,
       userConfirmed:true);
      // Read the authoritative SQLCipher result directly. A concurrent
      // Home refresh can lag behind this route, leaving both dropdowns empty.
      final refreshed=(await api.balances()).where((a)=>!a.archived).toList();
      if(!sheetContext.mounted)return;
      unawaited(_m467RefreshHomeAccounts());
      final created=refreshed.where((a)=>a.id==id).toList();
      if(created.length!=1)throw StateError(
       'Account creation has no verified refreshed balance');
      final groups=WaffraRecurringAccountGroups.fromAccounts(refreshed);
      // Account creation invalidates its old optimistic witness; refresh it
      // before handing the same verified API back to the transfer editor.
      if(forTransfer)await api.balances();
      final related=groups.where((p)=>
       p.accounts.any((a)=>a.id==id)).toList();
      if(related.length!=1)throw StateError(
       'New account group is not uniquely verified');
      update((){
       entryAccounts=refreshed;
       entryProviders=WaffraRecurringAccountGroups.withBankProviderChoices(refreshed);
       if(forTransfer){
        transferAccounts=refreshed;
        transferApi=api;
        if(transferTarget){
         transferDestinationProvider=related.single.id;
         transferDestinationCategory=related.single.category;
         transferDestination=mainProvider?null:id;
        }else{
         transferSourceProvider=related.single.id;
         transferSourceCategory=related.single.category;
         transferSource=mainProvider?null:id;
        }
        transferError=null;
       }else if(mainProvider){
        chosenManualProvider=related.single.id;
        chosenManualProviderCategory=related.single.category;
        chosenManualAccount=id; // Creating a provider also created its first child.
       }else if(related.single.id==selectedProviderBefore){
        chosenManualProviderCategory=related.single.category;
        chosenManualAccount=id;
       }else{
        chosenManualProvider=related.single.id;
        chosenManualProviderCategory=related.single.category;
        chosenManualAccount=id;
       }
      });
     }catch(error){
      if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
       'Could not confirm account creation. Review the form and try again.':
       'تعذر تأكيد إنشاء الحساب. راجع البيانات وأعد المحاولة.',
       isError:true);
     }
    }
    Widget operationPicker(){
     // Manual income/expense selected from SMS: one template, no three-mode switch.
     if(manualIncomeOverride!=null&&initial==null&&!sms){
      return const SizedBox.shrink();
     }
     if(initial!=null||sms){
      return SegmentedButton<bool>(
       segments:const [
        ButtonSegment(value:true,label:WaffraText('دخل')),
        ButtonSegment(value:false,label:WaffraText('مصروف'))],
       selected:{income},
       onSelectionChanged:initial?.sourceType=='goal_due'?null:
        WaffraHaptics.selection((v)=>update((){
         income=v.first;selectedParentId=null;selectedBudgetId=null;
         category='';suggestion=null;
        })));
     }
     return SegmentedButton<WaffraAccountOperation>(
      key:const Key('waffra-manual-three-modes'),
      showSelectedIcon:false,
      segments:[
       ButtonSegment(value:WaffraAccountOperation.income,
        label:WaffraText(waffraIsEnglish?'Income':'دخل')),
       ButtonSegment(value:WaffraAccountOperation.expense,
        label:WaffraText(waffraIsEnglish?'Expense':'مصروف')),
       ButtonSegment(value:WaffraAccountOperation.transfer,
        label:WaffraText(waffraIsEnglish?'Transfer':'تحويل'))],
      selected:{transferSelected?WaffraAccountOperation.transfer:
       income?WaffraAccountOperation.income:WaffraAccountOperation.expense},
      onSelectionChanged:transferSaving?null:
       WaffraHaptics.selection((choice)async{
       final selected=choice.first;
       if(selected!=WaffraAccountOperation.transfer){
        update((){
         transferSelected=false;
         income=selected==WaffraAccountOperation.income;
         selectedParentId=null;selectedBudgetId=null;category='';suggestion=null;
        });
        return;
       }
       update(()=>transferSelected=true);
       if(transferApi!=null)return;
       try{
        await _ensureFinanceBound();
        final bridge=_financeBinding?.accountsBridge;
        if(bridge==null)throw StateError('Verified money accounts unavailable');
        final api=WaffraVerifiedAccountsApi(bridge:bridge);
        final accounts=await api.balances();
        if(!sheetContext.mounted)return;
        update((){
         transferApi=api;
         transferAccounts=accounts.where((a)=>!a.archived).toList();
         transferError=null; // The disabled confirm already conveys missing accounts.
        });
       }catch(error){
        if(sheetContext.mounted)update(()=>transferError=waffraIsEnglish?
         'Verified accounts unavailable. Reopen My Accounts.':
         'الحسابات الموثقة غير متاحة. راجع حساباتي.');
       }
      }));
    }
    if(transferSelected){
     Widget accountChoice({required String label,required String? value,
      required ValueChanged<String?> onChange,String? exclude,bool target=false}){
      final providers=WaffraRecurringAccountGroups.withBankProviderChoices(transferAccounts);
      String? group=target?transferDestinationProvider:transferSourceProvider;
      if(group==null&&value!=null){
       for(final provider in providers){
        if(provider.accounts.any((a)=>a.id==value)){group=provider.id;break;}
       }
      }
      final groups=providers.where((p)=>p.id==group).toList();
      final options=groups.isEmpty?const <WaffraAccountBalance>[]:
       groups.single.accounts.where((a)=>a.id!=exclude).toList();
      final parentRevision=target?transferTargetProviderRevision:transferSourceProviderRevision;
      final childRevision=target?transferTargetChildRevision:transferSourceChildRevision;
      String? groupCategory=target?transferDestinationCategory:transferSourceCategory;
      groupCategory??=group==null?null:
       WaffraSaudiFinancialProviders.categoryForGroup(group);
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m638-transfer-type-${target?'to':'from'}-$parentRevision'),
        initialValue:groupCategory,isExpanded:true,
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Institution type':'نوع الجهة',
         border:const OutlineInputBorder()),
        items:[
         for(final type in const [
          WaffraSaudiFinancialProviders.local,
          WaffraSaudiFinancialProviders.digital,
          WaffraSaudiFinancialProviders.wallet,
          WaffraSaudiFinancialProviders.other,
         ])DropdownMenuItem<String>(value:type,
          child:WaffraText(WaffraSaudiFinancialProviders.labelAr(type))),
        ],
        onChanged:transferSaving?null:(value)=>update((){
         if(target){
          transferDestinationCategory=value;
          transferDestinationProvider=null;transferDestination=null;
         }else{
          transferSourceCategory=value;
          transferSourceProvider=null;transferSource=null;
         }
         transferError=null;
        }),
       ),
       const SizedBox(height:9),
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m470-home-transfer-'+(target?'target':'source')+
         '-provider-'+(group??'none')+'-$parentRevision'),
        isExpanded:true,initialValue:group,
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Bank or provider':'الجهة أو البنك',
         border:const OutlineInputBorder()),
        items:[
         ...providers.where((p)=>p.category==groupCategory)
          .map((p)=>DropdownMenuItem<String>(
           value:p.id,child:WaffraText(p.labelAr,maxLines:1))),
         DropdownMenuItem<String>(value:'__create_transfer_provider__',
          child:WaffraText(waffraIsEnglish?'Add bank / provider':'إضافة جهة أو بنك')),
        ],
        onChanged:transferSaving||groupCategory==null?null:(v)async{
         if(v=='__create_transfer_provider__'){
          await createAccountInsideEntryDropdown(
           mainProvider:true,forTransfer:true,transferTarget:target);
          if(sheetContext.mounted)update((){
           if(target)transferTargetProviderRevision++;
           else transferSourceProviderRevision++;
          });
          return;
         }
         if(sheetContext.mounted)update((){
          if(target){transferDestinationProvider=v;transferDestination=null;}
          else{transferSourceProvider=v;transferSource=null;}
          transferError=null;
         });
        },
       ),
       const SizedBox(height:9),
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m470-home-transfer-'+(target?'target':'source')+
         '-account-'+(group??'none')+'-$childRevision'),
        isExpanded:true,
        initialValue:options.any((a)=>a.id==value)?value:null,
        decoration:InputDecoration(labelText:label,
         border:const OutlineInputBorder()),
        items:[
         ...options.map((a)=>DropdownMenuItem<String>(value:a.id,
          child:WaffraText(a.name,maxLines:1))),
         if(group!=null)DropdownMenuItem<String>(
          value:'__create_transfer_child__',
          child:WaffraText(waffraIsEnglish?'Add linked account':'إضافة حساب تابع')),
        ],
        onChanged:transferSaving||group==null?null:(v)async{
         if(v=='__create_transfer_child__'){
          await createAccountInsideEntryDropdown(
           mainProvider:false,forTransfer:true,transferTarget:target);
          if(sheetContext.mounted)update((){
           if(target)transferTargetChildRevision++;
           else transferSourceChildRevision++;
          });
          return;
         }
         if(sheetContext.mounted)onChange(v);
        }),
      ]);
     }
     return WaffraEntrySheetSafeLayout(
      form:SingleChildScrollView(
       padding:const EdgeInsets.fromLTRB(18,10,18,8),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
         WaffraText(waffraIsEnglish?'Manual transaction':'عملية يدوية',
          style:Theme.of(sheetContext).textTheme.titleLarge),
         const SizedBox(height:12),
         operationPicker(),
         const SizedBox(height:18),
         TextField(key:const Key('m466-transfer-amount'),controller:transferAmount,
          onChanged:(_)=>update((){}),
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
          decoration:InputDecoration(
           labelText:waffraIsEnglish?'Amount (SAR)':'المبلغ (ر.س)',
           border:const OutlineInputBorder())),
         const SizedBox(height:12),
         accountChoice(label:waffraIsEnglish?'From account':'من حساب',
          value:transferSource,onChange:(v)=>update((){
           transferSource=v;
           if(transferDestination==v)transferDestination=null;
           transferError=null;
          })),
         const SizedBox(height:12),
         accountChoice(label:waffraIsEnglish?'To account':'إلى حساب',
          value:transferDestination,exclude:transferSource,target:true,
          onChange:(v)=>update((){
           transferDestination=v;transferError=null;
          })),
         const SizedBox(height:12),
         OutlinedButton.icon(
          key:const Key('m506-transfer-date'),
          onPressed:transferSaving?null:WaffraHaptics.tap(()async{
           final picked=await waffraPickDateWithToday(
            english:waffraIsEnglish,context:sheetContext,
            initialDate:transferDate,firstDate:DateTime(2000),
            lastDate:DateTime.now());
           if(picked!=null&&sheetContext.mounted){
            update(()=>transferDate=picked);
           }
          }),
          icon:const Icon(Icons.calendar_month_outlined),
          label:WaffraText(waffraIsEnglish?
           'Transfer date: ${dayText(transferDate)}':
           'تاريخ التحويل: ${dayText(transferDate)}')),
         const SizedBox(height:12),
         TextField(key:const Key('m466-transfer-note'),controller:transferNote,
          maxLength:2000,maxLines:3,minLines:1,
          decoration:InputDecoration(
           labelText:waffraIsEnglish?'Transfer note':'ملاحظة التحويل',
           border:const OutlineInputBorder())),
         if(transferError!=null)
          WaffraText(transferError!,style:TextStyle(
           color:Theme.of(sheetContext).colorScheme.error)),
        ])),
      footer:FilledButton(
       key:const Key('m466-confirm-transfer'),
       onPressed:transferSaving||transferApi==null||
        transferAccounts.length<2?null:WaffraHaptics.tap(()async{
        final amount=waffraSarAmountMinor(transferAmount.text);
        if(amount==null||transferSource==null||
           transferDestination==null||
           transferSource==transferDestination){
         update(()=>transferError=waffraIsEnglish?
          'Enter a valid amount and two different accounts.':
          'أدخل مبلغًا صحيحًا وحسابَي مصدر ووجهة مختلفين.');
         return;
        }
        update((){transferSaving=true;transferError=null;});
        try{
         // Inline account creation, another widget writer or a previously
         // attempted transfer can invalidate the optimistic witness. Read a
         // FRESH verified snapshot before user-confirmed posting, and refuse
         // to infer any missing account from provider labels.
         final latest=await transferApi!.balances();
         if(!latest.any((a)=>a.id==transferSource&&!a.archived)||
            !latest.any((a)=>a.id==transferDestination&&!a.archived)){
          throw StateError('m506_transfer_account_missing_or_archived');
         }
         if(sheetContext.mounted)update(()=>transferAccounts=latest);
         final committed=await transferApi!.transfer(
          id:transferRequestId,fromAccountId:transferSource!,
          toAccountId:transferDestination!,amountMinor:amount,
          occurredIso:transferDate.toIso8601String(),
          note:transferNote.text.trim(),userConfirmed:true);
         if(!committed)throw StateError('m506_transfer_not_committed');
         transferCommitted=true;
         try{await _learnManualTransferPreference();}catch(_){}
         if(sheetContext.mounted)Navigator.pop(sheetContext);
        }catch(error){
         debugPrint('M506 transfer rejected: ${error.runtimeType}');
         if(sheetContext.mounted)update(()=>transferError=waffraIsEnglish?
          'Transfer was not confirmed. Check both accounts and retry.':
          'لم يتأكد التحويل. راجع حسابَي المصدر والوجهة وحاول تاني.');
        }finally{
         if(sheetContext.mounted)update(()=>transferSaving=false);
        }
       }),
       child:WaffraText(transferSaving?
        (waffraIsEnglish?'Saving…':'جارٍ الحفظ…'):
        (waffraIsEnglish?'Confirm transfer':'تأكيد التحويل'))),
     );
    }
     // Keep save above Android navigation controls and the keyboard.
     // Fields scroll independently while the confirmation remains visible.
     return WaffraEntrySheetSafeLayout(
      form:SingleChildScrollView(
       key:const Key('waffra-entry-form-scroll'),
       padding:const EdgeInsets.fromLTRB(18,10,18,8),
       child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(initial!=null?'تعديل العملية':sms?'إضافة رسالة بنكية':'إضافة عملية',
       style:Theme.of(sheetContext).textTheme.titleLarge),
      if(initial!=null)...[
       const SizedBox(height:9),
       Container(
        key:const Key('waffra-entry-edit-source'),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
        decoration:BoxDecoration(
         color:Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
         borderRadius:BorderRadius.circular(12)),
        child:Row(children:[
         Icon(initial.sourceType=='sms'?Icons.sms_outlined:
          Icons.edit_note_outlined,color:emerald,size:19),
         const SizedBox(width:9),
         Expanded(child:WaffraText(
          WaffraTransactionDetailsDialog.sourceLabel(
           initial.sourceType,waffraIsEnglish),
          style:const TextStyle(fontWeight:FontWeight.bold))),
        ])),
       if(initial.sourceType=='manual')Padding(
        padding:const EdgeInsets.only(top:7),
        child:WaffraText(waffraIsEnglish?
         'Added manually. No original SMS exists.':
         'أُضيفت العملية يدويًا ولا توجد لها رسالة SMS أصلية.',
         style:const TextStyle(fontSize:12))),
       if(initial.sourceType=='sms')Padding(
        padding:const EdgeInsets.only(top:7),
        child:WaffraText(waffraIsEnglish?
         'The protected original SMS is in transaction details.':
         'الرسالة البنكية الأصلية المحمية موجودة في تفاصيل المعاملة.',
         style:const TextStyle(fontSize:12))),
      ],
      if(!sms&&reviewedOriginalSms!=null)...[
       Card(child:ExpansionTile(
        key:const Key('m662-manual-correction-original-expand'),
        initiallyExpanded:true,
        title:WaffraText(waffraIsEnglish?
         'Original transfer message (reference only)':
         'نص رسالة التحويل الأصلية (للمراجعة فقط)'),
        children:[Padding(padding:const EdgeInsets.all(12),
         child:SelectableText(reviewedOriginalSms,
          key:const Key('m662-manual-correction-original-text'),
          textAlign:TextAlign.start))],
       )),
       const SizedBox(height:10),
       WaffraText(waffraIsEnglish?
        'This is a separate manual entry; the transfer SMS stays in Review.':
        'هذه عملية يدوية منفصلة؛ رسالة التحويل ستظل في المراجعة.',
        style:const TextStyle(fontSize:12,color:emerald)),
       const SizedBox(height:10),
      ],
      if(sms&&initialSms==null)...[
       TextField(controller:message,minLines:3,maxLines:6,
        // Reviewed Android SMS provenance must remain byte-for-byte original.
        // Users correct amount/category/title, not the source message itself.
        readOnly:initialSms!=null,
        onChanged:(v){parseNow(v);update((){});},
        decoration:InputDecoration(labelText:waffraIsEnglish?'Bank SMS *':'الرسالة البنكية *',
         hintText:waffraTr('أول ما تلصقها نحلّلها تلقائيًا'),
         errorText:attempted&&message.text.trim().isEmpty?waffraRequiredFieldMessage:null,
         border:OutlineInputBorder())),
       const SizedBox(height:8),
       if(analyzing)const LinearProgressIndicator(),
       if(hasParsed)WaffraText(
        BankParser.parse(message.text).requiresCurrencyReview
         ?(waffraIsEnglish?
          'Foreign currency: check the original amount and enter a verified SAR value manually. No automatic FX conversion.':
          'عملة أجنبية: راجع المبلغ وأدخل قيمته المؤكدة بالريال يدويًا. لا يوجد تحويل تلقائي.')
         :value.text.isEmpty?
          (waffraIsEnglish?'Amount unclear: enter it manually.':'المبلغ غير واضح؛ أدخله يدويًا.')
         :(waffraIsEnglish?'Smart analysis suggested fields. Review before saving.':
          'التحليل الذكي اقترح بيانات. راجعها قبل الحفظ.'),
        style:const TextStyle(color:emerald)),
       const SizedBox(height:12),
      ],
      operationPicker(),
      const SizedBox(height:12),
      if(initial==null||canLinkExistingAccount)...[
       if(initial!=null)Padding(
        padding:const EdgeInsets.only(bottom:9),
        child:WaffraText(originalLinkedAccountId!=null?
         (waffraIsEnglish?
          'Already linked; editing details cannot move it to another account.':
          'العملية مربوطة بحساب بالفعل، وتعديل التفاصيل مش هينقلها لحساب آخر.'):
         (waffraIsEnglish?
          'Link this older transaction without posting a second income or expense.':
          'اربط العملية القديمة بحساب دون إضافة دخل أو مصروف مرة ثانية.'),
         style:const TextStyle(fontSize:12,color:emerald))),
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m638-home-manual-institution-type-${chosenManualProviderCategory??'none'}'),
        isExpanded:true,initialValue:chosenManualProviderCategory,
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Institution type *':'نوع الجهة *',
         border:const OutlineInputBorder()),
        items:[
         for(final type in const [
          WaffraSaudiFinancialProviders.local,
          WaffraSaudiFinancialProviders.digital,
          WaffraSaudiFinancialProviders.wallet,
          WaffraSaudiFinancialProviders.other,
         ])DropdownMenuItem<String>(value:type,
          child:WaffraText(WaffraSaudiFinancialProviders.labelAr(type))),
        ],
        onChanged:initial!=null&&originalLinkedAccountId!=null?null:(type)=>update((){
         chosenManualProviderCategory=type;
         chosenManualProvider=null;
         chosenManualAccount=null;
        }),
       ),
       const SizedBox(height:10),
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m470-home-manual-provider-'+(chosenManualProvider??'none')+
         '-$accountProviderMenuRevision'),
        isExpanded:true,initialValue:chosenManualProvider,
        decoration:InputDecoration(labelText:waffraIsEnglish?
         'Bank or provider *':'الجهة أو البنك *',border:const OutlineInputBorder()),
        items:[
         ...entryProviders.where((p)=>p.category==chosenManualProviderCategory)
          .map((p)=>DropdownMenuItem<String>(
           value:p.id,child:WaffraText(p.labelAr,maxLines:1))),
         DropdownMenuItem<String>(value:'__create_provider__',
          child:Row(children:[
           const Icon(Icons.add_circle_outline,color:emerald,size:19),
           const SizedBox(width:8),
           Expanded(child:WaffraText(waffraIsEnglish?
            'Add bank / provider':'إضافة جهة أو بنك',maxLines:1)),
          ])),
        ],
        onChanged:chosenManualProviderCategory==null||
         (initial!=null&&originalLinkedAccountId!=null)?null:(provider)async{
         if(provider=='__create_provider__'){
          await createAccountInsideEntryDropdown(mainProvider:true);
          // Synthetic Add must not replace a chosen provider on cancel.
          if(sheetContext.mounted)update(()=>accountProviderMenuRevision++);
          return;
         }
         if(sheetContext.mounted)update((){
          chosenManualProvider=provider;
          chosenManualAccount=null; // A parent alone is not a money account.
         });
        },
       ),
       const SizedBox(height:10),
       WaffraCenteredDropdownFormField<String>(
        key:ValueKey('m470-home-manual-account-'+(chosenManualProvider??'none')+
         '-'+(chosenManualAccount??'none')+'-$accountChildMenuRevision'),
        isExpanded:true,initialValue:chosenManualAccount,
        decoration:InputDecoration(labelText:waffraIsEnglish?
         'Linked money account *':'الحساب المالي التابع *',
         errorText:attempted&&initial==null&&!sms&&chosenManualAccount==null
           ?waffraRequiredFieldMessage:null,
          border:const OutlineInputBorder()),
        items:[
         ...entryProviders.where((p)=>p.id==chosenManualProvider)
          .expand((p)=>p.accounts).map((account)=>DropdownMenuItem<String>(
           value:account.id,child:WaffraText(account.name,maxLines:1))),
         if(chosenManualProvider!=null)
          DropdownMenuItem<String>(value:'__create_child__',
           child:Row(children:[
            const Icon(Icons.add_circle_outline,color:emerald,size:19),
            const SizedBox(width:8),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Add linked account':'إضافة حساب تابع',maxLines:1)),
           ])),
        ],
        onChanged:chosenManualProvider==null||
         (initial!=null&&originalLinkedAccountId!=null)?null:(id)async{
         if(id=='__create_child__'){
          await createAccountInsideEntryDropdown(mainProvider:false);
          if(sheetContext.mounted)update(()=>accountChildMenuRevision++);
          return;
         }
         if(sheetContext.mounted)update(()=>chosenManualAccount=id);
        },
       ),
       const SizedBox(height:12),
      ],
      TextField(controller:title,onChanged:(_)=>update((){}),minLines:1,maxLines:5,
       decoration:InputDecoration(labelText:waffraIsEnglish?'Transaction name *':'اسم العملية *',
        errorText:attempted&&!waffraTransactionTitleAllowed(title.text,
         oldTitle:initial?.title)
         ?(title.text.trim().isEmpty?waffraRequiredFieldMessage:
           (waffraIsEnglish?'Maximum 250 characters for a new name.':
            'اسم العملية الجديد لا يزيد عن 250 حرفًا.')):null,
        border:OutlineInputBorder())),
      const SizedBox(height:10),
      if(!sms)...[
       TextField(controller:notes,onChanged:(_)=>update((){}),minLines:1,maxLines:4,
        decoration:InputDecoration(labelText:waffraIsEnglish?'Notes':'ملاحظات',
         errorText:attempted&&!waffraTransactionNotesAllowed(notes.text,oldNotes:initial?.notes)
          ?(waffraIsEnglish?'Notes cannot exceed 2,000 characters.':
            'الملاحظات لا تتجاوز 2000 حرف.'):null,
         border:const OutlineInputBorder())),
       const SizedBox(height:12),
      ]else ...[
       WaffraText(waffraIsEnglish?
        'The original bank message is stored separately from your notes.':
        'نص الرسالة البنكية الأصلية يُحفظ منفصلًا عن ملاحظاتك.',
        style:const TextStyle(fontSize:12,color:emerald)),
       const SizedBox(height:7),
       // #409: readable, read-only original SMS while editing; verification
       // and pending SMS remain hidden to avoid exposing private codes.
       ExpansionTile(
        initiallyExpanded:true,
        key:const Key('waffra-entry-original-sms-expand'),
        tilePadding:const EdgeInsets.symmetric(horizontal:9),
        title:WaffraText(waffraIsEnglish?
         'View original bank SMS':'عرض الرسالة البنكية الأصلية'),
        children:[Padding(
         padding:const EdgeInsets.fromLTRB(12,4,12,12),
         child:WaffraBankSmsFactsParser.parse(initialSms??message.text).pending?
          WaffraText(waffraIsEnglish?
           'Verification or pending message content is hidden.':
           'محتوى رسالة التحقق أو العملية المعلقة مخفي لحمايتك.'):
          SelectableText(initialSms??message.text,
           key:const Key('waffra-entry-original-sms-text'),
           textDirection:Directionality.of(sheetContext),
           textAlign:TextAlign.start),
        )],
       ),
       const SizedBox(height:12),
       TextField(
        key:const Key('m506-sms-personal-notes'),
        controller:notes,minLines:1,maxLines:3,
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Your notes (optional)':
          'ملاحظاتك الشخصية (اختياري)',
         helperText:waffraIsEnglish?
          'Original bank SMS is stored separately.':
          'الرسالة البنكية الأصلية منفصلة عن ملاحظاتك.',
         border:const OutlineInputBorder())),
       const SizedBox(height:12),
      ],
      TextField(controller:value,readOnly:initial?.sourceType=='goal_due',
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(value.text):null,
        border:OutlineInputBorder())),
      const SizedBox(height:12),
      ...[
       InkWell(onTap:WaffraHaptics.tap(()async{
        final picked=await chooseTransactionCategory(
         sheetContext,mainCategories,
         selectedMain.isEmpty?'':selectedMain.first.name,
         allowCreate:true,typeIncome:income,parentId:selectedParentId,
         suggested:suggestion);
        if(picked==null||!sheetContext.mounted)return;
        final roots=categories.where((c)=>c.income==income&&
         !c.isSubcategory&&c.name==picked).toList();
        final leaves=categories.where((c)=>c.income==income&&
         c.isSubcategory&&c.name==picked).toList();
        if(roots.length==1){
         update((){
          if(selectedParentId!=roots.single.id){
           selectedParentId=roots.single.id;
           category='';
           selectedBudgetId=null;
          }
         });
        }else if(leaves.length==1){
         update((){
          selectedParentId=leaves.single.parentId;
          category=leaves.single.name;
          selectedBudgetId=null;
          suggestion=null;
         });
        }
       }),child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Main category *':'القسم الرئيسي *',
        errorText:attempted&&selectedMain.isEmpty?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),
        suffixIcon:const Icon(Icons.arrow_drop_down_rounded)),
        child:WaffraText(selectedMain.isEmpty?
         (waffraIsEnglish?'Choose a main category':'اختر القسم الرئيسي'):
         selectedMain.first.displayName,maxLines:2))),
       const SizedBox(height:10),
       InkWell(key:const Key('m470-entry-subcategory-picker'),
        onTap:selectedParentId==null?null:WaffraHaptics.tap(()async{
        final selectedParentAtTap=selectedParentId;
        if(selectedParentAtTap==null){
         snack(sheetContext,waffraIsEnglish?
          'Choose a main category first.':'اختر القسم الرئيسي أولًا.');
         return;
        }
        // After Back or refresh, use current parent-scoped children instead
        // of an old list captured by a former sheet build.
        final picked=await chooseTransactionCategory(
         sheetContext,
         waffraManualCategoryChildren(categories,income,selectedParentAtTap),
         selectedSub.isEmpty?'':selectedSub.first.name,
         leafLabels:true,allowCreate:true,typeIncome:income,
         parentId:selectedParentAtTap,suggested:suggestion);
        if(picked==null||!sheetContext.mounted||
           selectedParentId!=selectedParentAtTap)return;
        final leaves=waffraManualCategoryChildren(
         categories,income,selectedParentAtTap)
         .where((c)=>c.name==picked).toList();
        if(leaves.length==1){
         update((){
          category=leaves.single.name;
          selectedParentId=leaves.single.parentId;
          selectedBudgetId=null;
          suggestion=null;
         });
        }
       }),child:InputDecorator(decoration:InputDecoration(
        labelText:waffraIsEnglish?'Subcategory *':'القسم الفرعي *',
        enabled:selectedParentId!=null,
        errorText:attempted&&selectedSub.isEmpty?waffraRequiredFieldMessage:null,
        border:const OutlineInputBorder(),
        suffixIcon:const Icon(Icons.arrow_drop_down_rounded)),
        child:WaffraText(selectedSub.isEmpty?
         (waffraIsEnglish?'Choose or create a subcategory':'اختر أو أضف قسمًا فرعيًا'):
         selectedSub.first.displayName,maxLines:2))),
       if(selectedMain.isNotEmpty&&subcategories.isEmpty)
        Padding(padding:const EdgeInsets.only(top:7),child:WaffraText(
         waffraIsEnglish?
          'No subcategories yet. Open the list to add one.':
          'لا توجد أقسام فرعية؛ افتح القائمة لإضافة قسم.',
         style:const TextStyle(color:Colors.deepOrange,fontSize:12))),
      ],
      Padding(padding:const EdgeInsets.symmetric(vertical:12),
       child:Row(children:[
        // M478 #418: date uses 100% width without an optional budget.
        Expanded(child:dateAction()),
        if(!income&&waffraHasSelectableBudget(namedBudgets))...[
         const SizedBox(width:8),
         // If a budget is displayed, it shares the row 50/50 with date.
         Expanded(child:WaffraCenteredDropdownFormField<String>(
         key:ValueKey('waffra-entry-budget-'+(selectedBudgetId??'unlinked')+'-$budgetMenuRevision'),
         menuMaxHeight:min(340.0,MediaQuery.sizeOf(sheetContext).height*.48),
         initialValue:namedBudgets.any((b)=>b.budget>0&&
          !b.deleted&&(b.budgetActive||
           (initial!=null&&initial.budgetId==b.id))&&
          b.id==selectedBudgetId)?selectedBudgetId:'unlinked',
         isExpanded:true,
         decoration:InputDecoration(
          labelText:waffraIsEnglish?'Transaction budget':'ميزانية العملية',
          border:const OutlineInputBorder()),
         items:[
          DropdownMenuItem(value:'unlinked',child:WaffraText(
           waffraIsEnglish?'Without a budget':'بدون ميزانية',maxLines:1)),
          ...namedBudgets.where((b)=>b.budget>0&&b.budgetActive&&!b.deleted)
           .map((c)=>DropdownMenuItem(value:c.id,child:WaffraText(
            c.budgetLabel??'ميزانية '+c.displayName,maxLines:1))),
          if(initial?.budgetId!=null)
           ...namedBudgets.where((b)=>b.id==initial!.budgetId&&
            (b.deleted||!b.budgetActive)).map(
             (c)=>DropdownMenuItem(value:c.id,enabled:false,
              child:WaffraText(
               (c.budgetLabel??'ميزانية '+c.displayName)+
               (waffraIsEnglish?' (previous)':' (ارتباط قديم)'),maxLines:1))),
          DropdownMenuItem(value:'__create_budget__',
           child:Row(children:[
            const Icon(Icons.add_circle_outline_rounded,color:emerald,size:19),
            const SizedBox(width:8),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Create a new budget':'إنشاء ميزانية جديدة',maxLines:1)),
           ])),
          DropdownMenuItem(value:'__manage_budgets__',
           child:Row(children:[
            const Icon(Icons.settings_outlined,color:emerald,size:19),
            const SizedBox(width:8),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Manage / delete budgets':'إدارة / حذف الميزانيات',maxLines:1)),
           ])),
         ],
         onChanged:WaffraHaptics.selection((v)async{
          if(v=='__create_budget__'){
           final id=await chooseBudgetCategory();
           if(!sheetContext.mounted)return;
           final b=namedBudgets.where((x)=>x.id==id&&
            x.budgetActive&&!x.deleted).toList();
           update((){
            budgetMenuRevision++;
            if(b.length==1)assignBudgetInsideEditor(b.single.id);
           });
           return;
          }
          if(v=='__manage_budgets__'){
           await showBudgetsDirectorySheet();
           if(sheetContext.mounted)update(()=>budgetMenuRevision++);
           return;
          }
          if(sheetContext.mounted)update(
           ()=>assignBudgetInsideEditor(v=='unlinked'?null:v));
         }),
       
         )),
        ],
       ])),
      const SizedBox(height:12),
      Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
        // The native camera permission is requested only when this action
        // launches the OS camera; never request it during login or startup.
        try{
         final draft=(title:title.text,amount:value.text,notes:notes.text,
          category:category,parent:selectedParentId,budget:selectedBudgetId,
          income:income);
         final file=await WaffraExternalMediaSession.runPicker(()=>
          ImagePicker().pickImage(source:ImageSource.camera,imageQuality:80));
         if(file==null)return;
         final path=await saveReceipt(file);
         stagedReceiptCopies.add(path);
         if(sheetContext.mounted)update((){
          title.text=draft.title;value.text=draft.amount;notes.text=draft.notes;
          category=draft.category;selectedParentId=draft.parent;
          selectedBudgetId=draft.budget;income=draft.income;
          receiptPath=waffraEncodeReceipts(
           [...waffraReceiptPaths(receiptPath),path]);
         });
        }catch(_){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Camera unavailable or permission denied. Review camera access in Settings.':
          'تعذر فتح الكاميرا أو تم رفض الإذن. راجع إذن الكاميرا من إعدادات الهاتف.');
        }
       }),icon:const Icon(Icons.camera_alt_outlined),label:const WaffraText('تصوير فاتورة'))),
       const SizedBox(width:8),
       Expanded(child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
        // Use OS limited-photo access only after the user taps Attach.
        try{
         final draft=(title:title.text,amount:value.text,notes:notes.text,
          category:category,parent:selectedParentId,budget:selectedBudgetId,
          income:income);
         final files=await WaffraExternalMediaSession.runPicker(()=>
          ImagePicker().pickMultiImage(imageQuality:80));
         if(files.isEmpty)return;
         final paths=<String>[...waffraReceiptPaths(receiptPath)];
         for(final file in files){
          final copied=await saveReceipt(file);
          stagedReceiptCopies.add(copied);paths.add(copied);
         }
         if(sheetContext.mounted)update((){
          title.text=draft.title;value.text=draft.amount;notes.text=draft.notes;
          category=draft.category;selectedParentId=draft.parent;
          selectedBudgetId=draft.budget;income=draft.income;
          receiptPath=waffraEncodeReceipts(paths);
         });
        }catch(_){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Could not open photos. Please check photo selection access.':
          'تعذر اختيار الصور. راجع صلاحية الوصول للصور المختارة.');
        }
       }),icon:const Icon(Icons.attach_file),label:const WaffraText('إرفاق صورة'))),
      ]),
      Padding(padding:const EdgeInsets.only(top:5),
       child:WaffraText(waffraIsEnglish?
        'Camera and photo access is requested only when you choose to use it.':
        'نطلب صلاحية الكاميرا أو اختيار الصور وقت استخدامها فقط.',
        style:const TextStyle(fontSize:11,color:emerald))),
      if(waffraReceiptPaths(receiptPath).isNotEmpty)...[
       for(final path in waffraReceiptPaths(receiptPath))
        ListTile(dense:true,
         title:WaffraText(WaffraReceiptFilename.displayName(path),maxLines:2),
         leading:const Icon(Icons.image,color:emerald),
         trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(
           key:Key('waffra-attachment-rename-'+waffraReceiptPaths(receiptPath).indexOf(path).toString()),
           tooltip:waffraIsEnglish?'Rename attachment':'تعديل اسم المرفق',
           icon:const Icon(Icons.drive_file_rename_outline,color:emerald),
           onPressed:WaffraHaptics.tap(()async{
            final name=await _promptReceiptLabel(sheetContext,path);
            if(name==null||!sheetContext.mounted)return;
            try{
             final directory=Directory(
              '${(await getApplicationDocumentsDirectory()).path}/receipts');
             final renamed=await WaffraReceiptFilename.stageCopyWithName(
              sourcePath:path,appReceiptsDirectory:directory.path,
              proposedLabel:name);
             stagedReceiptCopies.add(renamed);
             if(!sheetContext.mounted)return;
             update((){
              final paths=waffraReceiptPaths(receiptPath);
              final index=paths.indexOf(path);
              if(index>=0)paths[index]=renamed;
              receiptPath=waffraEncodeReceipts(paths);
             });
            }catch(_){
             if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
              'Could not rename attachment. The original image is unchanged.':
              'تعذر تغيير اسم المرفق. الصورة الأصلية لم تتغير.');
            }
           })),
          IconButton(
           tooltip:waffraIsEnglish?'Remove attachment':'إزالة المرفق',
           icon:const Icon(Icons.close),
           onPressed:WaffraHaptics.tap(()=>update((){
            receiptPath=waffraEncodeReceipts([...waffraReceiptPaths(receiptPath)]..remove(path));
           }))),
         ]),
         onTap:WaffraHaptics.tap(()=>showReceipt(receiptPath!,initialIndex:waffraReceiptPaths(receiptPath).indexOf(path),entryId:initial?.id))),
      ],
       ])),
      footer:FilledButton(
       key:const Key('waffra-entry-confirm-save'),
       onPressed:WaffraHaptics.tap(analyzing||submitTapped?null:
        (!waffraTransactionTitleAllowed(title.text,oldTitle:initial?.title)||
         !waffraTransactionNotesAllowed(notes.text,
          oldNotes:initial?.sourceType=='sms'?initial?.personalNotes:initial?.notes)||
         waffraAmountFieldError(value.text)!=null||
         (sms?amountOf(value.text):amountOfDisplay(value.text))==null||
         !waffraCanAssignManualCategory(categories,income,selectedParentId,category)||
         ((initial==null||(canLinkExistingAccount&&originalLinkedAccountId==null))&&
          chosenManualAccount==null)||
         (sms&&!smsDateConfirmed))?null:()async {
       if(submitTapped)return;
       update(()=>attempted=true);
       final n=sms?amountOf(value.text):amountOfDisplay(value.text);
       if(!waffraTransactionTitleAllowed(title.text,oldTitle:initial?.title)||
        !waffraTransactionNotesAllowed(notes.text,oldNotes:
         initial?.sourceType=='sms'?initial?.personalNotes:initial?.notes)||
        waffraAmountFieldError(value.text)!=null||n==null)return;
       // A settled goal payment is coupled to a debited earmark. Edits
       // may change its category/budget/notes, but not the money or type.
       if(initial?.sourceType=='goal_due'&&
        (WaffraRecurringPolicy.toHalalas(n)!=
         WaffraRecurringPolicy.toHalalas(initial!.amount)||
         income!=initial.income)){
        snack(sheetContext,waffraIsEnglish?
         'Goal payment amount/type cannot be changed without reversing the wallet.':
         'مبلغ ونوع استحقاق الهدف ثابتان لحماية رصيد محفظة الهدف.');
        return;
       }
       if(!waffraCanAssignManualCategory(categories,
        income,selectedParentId,category))return;
       if(!income&&selectedBudgetId!=null&&
          !namedBudgets.any((b)=>b.id==selectedBudgetId&&
            b.budget>0&&!b.deleted&&
            (b.budgetActive||(initial!=null&&initial.budgetId==b.id)))){
        if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
         'This budget is currently paused. Pick another budget or choose Unassigned.':
         'الميزانية دي متوقفة حاليًا. اختار ميزانية مفعّلة أو خلّي العملية بدون ربط.');
        return;
       }
       if(initial!=null&&canLinkExistingAccount&&
          originalLinkedAccountId==null&&chosenManualAccount!=null&&
          !entryProviders.any((p)=>p.id==chosenManualProvider&&
           p.accounts.any((a)=>a.id==chosenManualAccount))){
        snack(sheetContext,waffraIsEnglish?
         'Choose a verified child account of the selected bank.':
         'اختار حسابًا موثقًا تابعًا للجهة المختارة.',isError:true);
        return;
       }
       if(initial==null&&!sms&&
          (chosenManualAccount==null||
           !entryProviders.any((p)=>p.id==chosenManualProvider&&
            p.accounts.any((a)=>a.id==chosenManualAccount)))){
        snack(sheetContext,waffraIsEnglish?
         'Choose the bank and its linked money account before saving.':
         'اختار الجهة والحساب المالي التابع لها قبل الحفظ.',isError:true);
        return;
       }
       // Historical entries can predate creation of their money account.
       // Confirm the balance impact instead of silently treating an opening
       // balance entered today as a pre-history opening balance.
       if(initial!=null&&canLinkExistingAccount&&
          originalLinkedAccountId==null&&chosenManualAccount!=null){
        final approved=await showWaffraDialog<bool>(
         context:sheetContext,builder:(dialog)=>AlertDialog(
         title:WaffraText(waffraIsEnglish?
          'Confirm historical account link':'تأكيد ربط العملية القديمة'),
         content:WaffraText(waffraIsEnglish?
          'This will attribute the existing transaction to the selected account and affect its calculated balance. If the opening balance already represents today’s balance, review that opening balance first to avoid counting old money twice. The original transaction will not be added again.':
          'ربط العملية القديمة هيؤثر على رصيد الحساب المحسوب. لو الرصيد الافتتاحي اللي أدخلته هو رصيدك الحالي، راجعه الأول عشان العمليات القديمة ما تتحسبش مرتين. مش هنضيف عملية جديدة.'),
         actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
           child:WaffraText(waffraIsEnglish?'Back':'العودة')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
           child:WaffraText(waffraIsEnglish?'Confirm link':'تأكيد الربط')),
         ]));
        if(approved!=true||!sheetContext.mounted)return;
       }
       if(!income&&selectedBudgetId==null&&
          waffraHasSelectableBudget(namedBudgets)){
        final confirmed=await waffraConfirmUnlinkedBudgetSave(
         context:sheetContext);
        if(!confirmed||!sheetContext.mounted)return;
       }
       if(sms){
        if(message.text.trim().isEmpty)return;
        if(!smsDateConfirmed){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Choose the real bank transaction date from the calendar before saving.':
          'اختار تاريخ العملية البنكية الصحيح من التقويم قبل الحفظ.',isError:true);
         return;
        }
        // The display-country setting cannot convert a bank SMS into SAR.
        // The durable finance record must never inherit an unverified
        // foreign amount from the manual SMS review screen.
        if(WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)){
         if(sheetContext.mounted)snack(sheetContext,waffraIsEnglish?
          'Foreign or unknown currency: no transaction was saved as SAR. Verify the source amount and FX first.':
          'عملة الرسالة أجنبية أو غير مؤكدة؛ لم نحفظ العملية بالريال. يلزم التحقق من المبلغ وسعر الصرف أولًا.');
         return;
        }
        final h=sha256.convert(utf8.encode(digits(message.text).replaceAll(RegExp(r'\s+'),' ').trim().toLowerCase())).toString();
        if(smsHashes.contains(h)){
         final proceed=await showWaffraDialog<bool>(context:sheetContext,builder:(dialogContext)=>AlertDialog(
          title:const WaffraText('⚠️ الرسالة مكررة'),
          content:const WaffraText('هذي الرسالة البنكية أضفتها قبل كذا. ودّك تضيفها مرة ثانية؟'),
          actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,false)),child:const WaffraText('إلغاء')),
           FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,true)),child:const WaffraText('إضافة على أي حال'))]));
         if(proceed!=true||!sheetContext.mounted)return;
         explicitlyApprovedSmsDuplicate=true;
        }
        pendingHash=h;
       }
       submitTapped=true; // Synchronous gate: rapid taps cannot post twice.
       Navigator.pop(sheetContext,MoneyEntry(id:initial?.id??newId(),
        title:title.text.trim(),
        notes:sms?message.text:
         initial?.sourceType=='sms'?initial!.notes:notes.text,
        personalNotes:sms||initial?.sourceType=='sms'?notes.text:'',
        category:category,amount:n,
        income:income,date:date,receiptPath:receiptPath,
        sourceType:initial?.sourceType??(sms?'sms':'manual'),
        merchantKey:initial?.merchantKey??
         (sms?(waffraMerchantKey(message.text)??''):''),
        goalWalletPaidMinor:initial?.goalWalletPaidMinor??0,
        budgetId:income?null:(namedBudgets.any((b)=>b.id==selectedBudgetId&&
         !b.deleted&&b.budget>0&&
         (b.budgetActive||(initial!=null&&initial.budgetId==b.id)))
          ?selectedBudgetId:null)));
      }),child:const WaffraText('تأكيد وحفظ العملية')),
     );
   }));
  // Capture before disposing controllers. Dismissing this sheet by Android
  // Back, swipe or Later must retain a user-edited form for the SAME SMS.
  if(smsEditorDraftKey!=null&&mounted){
   if(!_m492SmsEditorDrafts.containsKey(smsEditorDraftKey)&&
      _m492SmsEditorDrafts.length>=8){
    _m492SmsEditorDrafts.remove(_m492SmsEditorDrafts.keys.first);
   }
   _m492SmsEditorDrafts[smsEditorDraftKey]={
    'dateConfirmed':smsDateConfirmed,
    'title':title.text,'notes':notes.text,'amount':value.text,
    'income':income,'parent':selectedParentId,'category':category,
    'budget':selectedBudgetId,'provider':chosenManualProvider,
    'account':chosenManualAccount,'date':date,
   };
  }
  debounce?.cancel();disposeLater([title,value,notes,message,transferAmount,transferNote]);
  if(result==null||!mounted){
   if(transferCommitted&&mounted){
    unawaited(_m467RefreshHomeAccounts());
    snackSuccess(context,waffraIsEnglish?
     'Transfer recorded in verified accounts.':
     'تم تسجيل التحويل بين الحسابات.');
   }
   for(final copy in stagedReceiptCopies){
    try{final file=File(copy);if(await file.exists())await file.delete();}catch(_){}
   }
   return;
  }
  // Compare manual and SMS entries across source types before commit.
  // This is an advisory warning: same-day equal purchases are legitimate.
  if(initial==null&&entries.any((e)=>
    WaffraCrossSourceDuplicateReview.mightBeSame(
      candidateTitle:result.title,candidateCategory:result.category,
      candidateMerchantKey:result.merchantKey,
      candidateAmount:result.amount,candidateIncome:result.income,
      candidateDate:result.date,existingTitle:e.title,
      existingCategory:e.category,existingMerchantKey:e.merchantKey,
      existingAmount:e.amount,existingIncome:e.income,
      existingDate:e.date))){
   final proceed=await showWaffraDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'⚠️ Possible duplicate':'⚠️ عملية مكررة'),
    content:WaffraText(waffraIsEnglish?
     'A similar ${result.income?'income':'expense'} was recorded on the same day for the same amount. Add it again?':
     'يبدو إنك أضفت نفس ${result.income?'الدخل':'المصروف'} من قبل. ودّك تضيفه مرة ثانية؟'),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
      child:WaffraText(waffraIsEnglish?'Add anyway':'إضافة على أي حال'))]));
   if(proceed!=true||!mounted){
    // The duplicate was refused *before* any finance write. Remove only
    // image copies staged in this sheet; never the original user image.
    for(final copy in stagedReceiptCopies){
     try{final file=File(copy);if(await file.exists())await file.delete();}catch(_){}
    }
    return;
   }
   // The writer still verifies the bank SMS hash under the source lock.
   // Confirmation here only permits the user's explicitly reviewed overlap.
   if(pendingHash!=null)explicitlyApprovedSmsDuplicate=true;
  }
  // M514 #451: editing an EXISTING reviewed SMS with its FIRST receipt
  // must not use the legacy whole-ledger optimistic editor. That path
  // cannot atomically attach encrypted image bytes to the typed SQL row.
  // This dedicated verified writer only adds receipts; it never posts again.
  if(initial!=null&&
     (initial.sourceType=='sms'||initial.sourceType=='manual')&&
     waffraReceiptPaths(initial.receiptPath).isEmpty&&
     stagedReceiptCopies.isNotEmpty){
   Future<void> discardStagedReceipts()async{
    for(final staged in stagedReceiptCopies){
     try{final file=File(staged);if(await file.exists())await file.delete();}
     catch(_){}
    }
   }
   final beforeEdit=Map<String,Object?>.from(initial.toJson())
    ..remove('receiptPath');
   final afterEdit=Map<String,Object?>.from(result.toJson())
    ..remove('receiptPath');
   if(jsonEncode(beforeEdit)!=jsonEncode(afterEdit)){
    if(mounted)snack(context,waffraIsEnglish?
     'Please attach the receipt separately from other changes to this entry.':
     'أضف المرفق وحده أولًا؛ تعديل بيانات العملية يحتاج حفظًا منفصلًا.',
     isError:true);
    await discardStagedReceipts();
    return;
   }
   try{
    final images=<Uint8List>[];
    for(final path in waffraReceiptPaths(result.receiptPath)){
     images.add(await File(path).readAsBytes());
    }
    if(images.isEmpty)throw StateError('No verified receipt bytes.');
    final current=await _saveProgress.track(
     'attach-verified-existing-receipt',
     ()=>_financeAuthority.attachReceiptsToExisting(
      entryId:initial.id,expectedOriginal:initial.toJson(),
      images:images,userConfirmed:true));
    final raw=await WaffraLargeJsonDecode.parse(current.ledgerRaw??'[]');
    if(raw is! List)throw StateError('Verified receipt edit ledger missing.');
    final verified=raw.map((item)=>MoneyEntry.fromJson(
     Map<String,dynamic>.from(item as Map))).toList();
    if(!verified.any((item)=>item.id==initial.id&&
      waffraReceiptPaths(item.receiptPath).length==images.length)){
     throw StateError('Verified receipt was not associated with entry.');
    }
    if(mounted)setState((){
     entries..clear()..addAll(verified);
     _lastFinanceAuthorityRead=current;
     _lastLedgerSavedRaw=current.ledgerRaw;
     _lastWidgetRevision=current.widgetRevision;
    });
    if(smsEditorDraftKey!=null)_m492SmsEditorDrafts.remove(smsEditorDraftKey);
    await discardStagedReceipts();
    if(mounted){
     snackSuccess(context,waffraIsEnglish?
      'Receipt attached without recording the transaction again.':
      'تم حفظ المرفق دون تسجيل العملية أو الخصم مرة تانية.');
     unawaited(_refreshWidget());
    }
   }catch(error){
    debugPrint('M514 verified existing receipt rejected: ${error.runtimeType}');
    await discardStagedReceipts();
    if(mounted){
     await _refreshFromVerifiedFinance();
     if(mounted)snack(context,waffraIsEnglish?
      'Receipt not saved. Your financial transaction is unchanged.':
      'تعذر حفظ المرفق؛ العملية المالية الأصلية لم تتغير.',
      isError:true);
    }
   }
   return;
  }
  final linkedBudget=namedBudgets.where((b)=>b.id==result.budgetId&&!b.deleted).toList();
  final previousSpent=linkedBudget.isEmpty?0.0:waffraNamedBudgetSpent(
    entries.where((e)=>e.id!=result.id),categories,linkedBudget.single,result.date);
  if(pendingHash!=null&&initial==null){
   final reviewedAccount=await reviewSmsAccountLinks([result],
     smsSender:reviewedSender??'',
     initialSelectedIds:chosenManualAccount==null?null:[chosenManualAccount]);
   if(reviewedAccount==null){
    for(final staged in stagedReceiptCopies){
     try{final file=File(staged);if(await file.exists())await file.delete();}
     catch(_){}
    }
    return;
   }
   try{
   // Preserve attachments only as bytes inside the same SQLCipher
   // transaction as the reviewed SMS and its deduplication fingerprint.
   final smsReceiptImages=<Uint8List>[];
   for(final attachment in waffraReceiptPaths(result.receiptPath)){
    smsReceiptImages.add(await File(attachment).readAsBytes());
   }
   final smsRecord=Map<String,Object?>.from(result.toJson());
   smsRecord['receiptPath']=null;
   // A single reviewed bank SMS must commit both its transaction and
   // fingerprint atomically under the same Home/Widget source and journal.
   // The writer independently checks duplicates again after taking the lock.
   final applied=await _saveProgress.track(
    'commit-confirmed-bank-sms',()=>_financeAuthority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
    records:[smsRecord],
    hashes:[pendingHash!],
    reviewedSmsReceiptImages:smsReceiptImages.isEmpty?
     null:smsReceiptImages,
    userConfirmed:true,
    allowDuplicateHashes:explicitlyApprovedSmsDuplicate,
    selectedAccountIds:reviewedAccount.ids,
    expectedAccountGeneration:reviewedAccount.generation,
   ));
   if(applied.saved!=1){
    if(mounted)snack(context,waffraIsEnglish?
     'This bank transaction was already saved. Review before retrying.':
     'العملية البنكية محفوظة بالفعل. راجعها قبل المحاولة مجددًا.');
    return;
   }
   final parsedLedger=await WaffraLargeJsonDecode.parse(
    applied.current.ledgerRaw??'[]');
   if(parsedLedger is! List)throw StateError(
    'Confirmed bank SMS ledger is invalid.');
   final verified=parsedLedger.map((item)=>MoneyEntry.fromJson(
    Map<String,dynamic>.from(item as Map))).toList();
   if(!mounted)return;
   setState((){
    entries..clear()..addAll(verified);
    smsHashes..clear()..addAll(
     applied.current.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
    _lastFinanceAuthorityRead=applied.current;
    _lastLedgerSavedRaw=applied.current.ledgerRaw;
    _lastWidgetRevision=applied.current.widgetRevision;
   });
   if(smsEditorDraftKey!=null)_m492SmsEditorDrafts.remove(smsEditorDraftKey);
   // No -> edit learns a confirmed sender+last-four bank identity only
   // after SQLCipher saved this exact reviewed SMS and its fingerprint.
   // This learning is not a finance write and cannot debit an account.
   if(reviewedSender!=null&&reviewedSender.trim().isNotEmpty){
    unawaited(_recordConfirmedSmsAccountAssociation(
     record:result,sender:reviewedSender,
     accountId:reviewedAccount.ids?.single));
   }
   // The expense/income learner applies only AFTER an authoritative commit,
   // and uses user-approved description/category, not the raw SMS body.
   try{await _learnManualCategoryPreference(result);}catch(_){}
   // SMS classification must not compete with the next page's first
   // frame after a verified money save. Review reads new rules on opening;
   // native intake / exact confirmed ACK remains the source of truth.
   for(final staged in stagedReceiptCopies){
    try{final file=File(staged);if(await file.exists())await file.delete();}
    catch(_){}
   }
   unawaited(_refreshWidget());
   if(applied.originalSmsNotesOmittedOnLegacy&&mounted){
    snack(context,waffraIsEnglish?
     'Transaction saved; original bank SMS text was NOT stored.':
     'تم حفظ بيانات العملية دون نص الرسالة البنكية الأصلي.',isError:false);
   }
   }catch(e){
    debugPrint('M506 confirmed SMS save rejected: ${e.runtimeType}');
    for(final staged in stagedReceiptCopies){
     try{final file=File(staged);if(await file.exists())await file.delete();}
     catch(_){}
    }
    // One rejected source-authorized bank commit must never leave the
    // user looking at a success screen or an unhandled Flutter exception.
    if(mounted)snack(context,waffraIsEnglish?
     'Could not confirm bank transaction save. Review before retrying.':
     'تعذر تأكيد حفظ المعاملة البنكية. راجعها قبل إعادة المحاولة.');
    return;
   }
  }else{
   // An account is selected from the same verified source only for a NEW
   // manually posted entry. Editing an existing entry never silently moves
   // that entry to a different financial account.
   final chosenManual=initial==null
    ?await reviewSmsAccountLinks([result],
      initialSelectedIds:chosenManualAccount==null?null:[chosenManualAccount]):null;
   if(initial==null&&chosenManual==null){
    for(final copy in stagedReceiptCopies){
     try{final staged=File(copy);if(await staged.exists())await staged.delete();}
     catch(_){}
    }
    return;
   }
   // M457: confirmed manual additions use the same atomic Home/Widget
   // SQLCipher append writer as reviewed bank SMS. Do NOT reserialize or
   // replace pre-existing ledger rows from a cached Home screen.
   // The same source writer handles manual money WITH or WITHOUT photos.
   // The source is reverified under lock; guarded legacy cannot fabricate
   // an account or silently fall back to a whole-ledger optimistic rewrite.
   if(initial==null&&result.sourceType=='manual'){
    try{
     await _saveProgress.track<void>(
      'commit-confirmed-manual',()=>_financialWriteQueue.submit(
       <String,Object>{'record':jsonEncode(result.toJson()),
        'receiptPaths':List<String>.of(waffraReceiptPaths(result.receiptPath))},
       (captured)async{
        // Read staged picker paths before committing; only bytes enter SQLCipher.
        // Invalid/missing files must abort BEFORE any money is posted.
        final paths=List<String>.from(captured['receiptPaths'] as List);
        final images=<Uint8List>[];
        for(final path in paths){
         images.add(await File(path).readAsBytes());
        }
        await _ensureFinanceBound();
        final safeRecord=Map<String,Object?>.from(
         jsonDecode(captured['record'] as String) as Map);
        safeRecord['receiptPath']=null;
        final committed=await _financeAuthority.commitConfirmedManual(
         route:WaffraFinanceRoute.manualTransactionSave,
         record:safeRecord,
         userConfirmed:true,
         manualReceiptImages:images.isEmpty?null:images,
         selectedAccountId:chosenManual?.ids?.single,
         expectedAccountGeneration:chosenManual?.ids?.single==null?
          null:chosenManual?.generation,
        );
        final raw=committed.ledgerRaw;
        if(raw==null)throw StateError('Confirmed manual ledger missing.');
        final decoded=await WaffraLargeJsonDecode.parse(raw);
        if(decoded is! List)throw StateError('Confirmed manual ledger invalid.');
        final verified=await _m593BuildVerifiedEntries(decoded);
        if(!verified.any((item)=>item.id==result.id)){
         throw StateError('Confirmed manual entry absent from verified ledger.');
        }
        _lastFinanceAuthorityRead=committed;
        _lastLedgerSavedRaw=raw;
        _lastWidgetRevision=committed.widgetRevision;
        if(mounted){
         setState((){entries..clear()..addAll(verified);});
         unawaited(_refreshWidget());
        }
       },
      ),
     );
     // Once encrypted storage has the bytes, remove only images staged by
     // this editor. Never delete originals or existing transaction receipts.
     for(final copy in stagedReceiptCopies){
      try{final staged=File(copy);if(await staged.exists())await staged.delete();}
      catch(_){}
     }
     // A preference failure cannot retry an already-committed debit.
     try{await _learnManualCategoryPreference(result);}catch(_){}
     // Don't decrypt and reclassify up to 1000 SMS while the manual
     // finance confirmation is transitioning. Review refreshes on entry.
    }catch(error){
     // A write may have committed before a later source read failed. Never
     // claim 'previous data unchanged' or let a retry create a ghost debit.
     debugPrint('M457 manual commit rejected: ${error.runtimeType}');
     if(mounted){
      await _refreshFromVerifiedFinance();
      if(mounted)snack(context,waffraIsEnglish?
       'Manual save could not be confirmed. Verified records were refreshed before retry. (M457)':
       'لم يتأكد حفظ العملية اليدوية. تم تحديث البيانات المحفوظة قبل إعادة المحاولة. (M457)');
     }
     for(final copy in stagedReceiptCopies){
      try{final file=File(copy);if(await file.exists())await file.delete();}
      catch(_){}
     }
     return;
    }
   }else{
   // Optimistic in-memory edits must roll back if durable save is rejected.
   // A spinner is NOT proof of a completed financial write.
   final previousEntries=List<MoneyEntry>.of(entries);
   final previousLearned=Map<String,String>.of(learnedMerchantCategories);
   setState((){
    _m684InvalidatePeriodRead();
    final i=entries.indexWhere((e)=>e.id==result.id);
    if(i>=0)entries[i]=result;else entries.insert(0,result);
    // Learn only explicit corrections made by the user, not assumptions
    // generated by bank message parsing.
    if(initial!=null&&initial.category!=result.category){
     final merchant=initial.merchantKey.isNotEmpty?
      initial.merchantKey:waffraMerchantKey(initial.title,income:initial.income);
     if(merchant!=null&&merchant.isNotEmpty){
      learnedMerchantCategories[merchant]=result.category;
     }
    }
   });
   try{
    // No success message or persisted balance is claimed before the
    // source-aware writer has acknowledged the commit.
    await persist(route:initial==null
     ?WaffraFinanceRoute.manualTransactionSave
     :WaffraFinanceRoute.transactionEdit,
     userConfirmed:initial==null,
     selectedAccountId:initial==null?chosenManual?.ids?.single:null);
    if(initial==null&&result.sourceType=='manual'){
     try{await _learnManualCategoryPreference(result);}catch(_){}
    }
   }catch(e){
    if(mounted){
     setState((){
      entries..clear()..addAll(previousEntries);
      learnedMerchantCategories..clear()..addAll(previousLearned);
     });
     snack(context,waffraIsEnglish?
      'Could not save the transaction. Your previous data is unchanged.':
      'تعذر حفظ المعاملة. بياناتك السابقة لم تتغير.');
    }
    // Cleanup must also run if the route disposed while persistence awaited.
    // These files were created by this editor; never delete original photos.
    for(final copy in stagedReceiptCopies){
     try{
      final staged=File(copy);
      if(await staged.exists())await staged.delete();
     }catch(error){
      debugPrint('Could not clean staged receipt after finance rejection: $error');
     }
    }
    return;
   }
   if(pendingHash!=null){
    // Existing transaction edits still need independent receipt/SMS review.
    try{await _persistSmsHashes({pendingHash!});}
    catch(e){
     if(mounted)snack(context,waffraIsEnglish?
      'Transaction saved, but the SMS fingerprint needs verification.':
      'تم حفظ المعاملة، لكن بصمة الرسالة تحتاج مراجعة.');
     return;
    }
   }
   }
  }
  bool linkedHistoricalAccountInThisEdit=false;
  // #420: witnessed idempotent association for the existing entry;
  // never append another income or expense.
  if(initial!=null&&canLinkExistingAccount&&
     originalLinkedAccountId==null&&chosenManualAccount!=null){
   try{
    final api=editAccountLinkApi;
    if(api==null)throw StateError('Verified entry link API unavailable');
    await api.balances();
    await api.linkUnassignedEntry(entryId:initial.id,
     accountId:chosenManualAccount!,userConfirmed:true);
    linkedHistoricalAccountInThisEdit=true;
    if(mounted)await _m467RefreshHomeAccounts();
   }catch(error){
    debugPrint('M500 historical link failed: ${error.runtimeType}');
    if(mounted)snack(context,waffraIsEnglish?
     'Details may be saved, but account linking was not confirmed. Check Unassigned transactions.':
     'قد يكون تعديل العملية اتحفظ، لكن ربط الحساب لم يتأكد. راجع عمليات بدون حساب.',isError:true);
    return;
   }
  }
  if(mounted)await budgetAlert(result,previousSpent);
  if(mounted)unawaited(_m467RefreshHomeAccounts());
  if(initial!=null&&mounted){
   snack(context,linkedHistoricalAccountInThisEdit?
     (waffraIsEnglish?'Transaction updated and linked to account':'تم تعديل العملية وربطها بالحساب'):
     (waffraIsEnglish?'Transaction updated':'تم تعديل المعاملة'),
    isError:false,duration:const Duration(seconds:5),
    // Existing legacy Undo reverts only metadata, not a confirmed bank link.
    // Do not offer a misleading Undo after money attribution is committed.
    actionLabel:linkedHistoricalAccountInThisEdit?null:(waffraIsEnglish?'Undo':'تراجع'),
    onAction:linkedHistoricalAccountInThisEdit?null:()async{
     if(!mounted)return;
     final index=entries.indexWhere((e)=>e.id==initial.id);
     if(index<0)return;
     _m684InvalidatePeriodRead();
     setState(()=>entries[index]=initial);
     if(!await _persistModuleOrReload(
      WaffraFinanceRoute.transactionEdit,
      operation:'transaction-edit-undo'))return;
     if(mounted)snackSuccess(context,waffraIsEnglish?
      'Transaction change reverted':'تم التراجع عن تعديل المعاملة');
    });
  }
 }
}
