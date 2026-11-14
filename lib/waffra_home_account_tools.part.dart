part of 'main.dart';

/// M721 / #633: unmodified secure backup, calendar, PIN, account tools.
extension _WaffraHomeAccountTools on _HomeScreenState {
 Future<void> showWaffraFinancialCalendar()async{
  DateTime selected=DateTime.now();
  await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
   final monthEvents=recurring.where((r)=>r.active&&
    !WaffraRecurringPolicy.dueDate(selected.year,selected.month,r.day).isBefore(DateTime(r.startAt.year,r.startAt.month,r.startAt.day))).toList();
   return AlertDialog(title:WaffraText(waffraIsEnglish?'Financial calendar':'التقويم المالي'),
    content:SizedBox(width:380,height:waffraKeyboardDialogListHeight(ctx,desired:460),child:Column(children:[
     CalendarDatePicker(key:ValueKey('recurring-calendar-'+selected.toIso8601String()),initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100),
      onDateChanged:(date)=>refresh(()=>selected=date)),
     if(!waffraCalendarIsToday(selected))
      Align(alignment:AlignmentDirectional.centerEnd,child:TextButton.icon(
       key:const Key('waffra-recurring-calendar-today'),
       onPressed:WaffraHaptics.tap(()=>refresh(()=>selected=DateUtils.dateOnly(DateTime.now()))),
       icon:const Icon(Icons.today_rounded,size:17),
       label:WaffraText(waffraIsEnglish?'Today':'اليوم'))),
     const Divider(),
     Expanded(child:ListView(children:monthEvents.map((r){
      final due=WaffraRecurringPolicy.dueDate(selected.year,selected.month,r.day);
      final id=WaffraRecurringPolicy.entryId(r.id,due);
      final paid=entries.any((e)=>e.id==id);
      final postponed=DateTime.tryParse(recurringPostponed[id]??'');
      return ListTile(dense:true,leading:Icon(paid?Icons.check_circle:Icons.schedule,color:paid?emerald:Colors.orange),
       title:WaffraText(r.title),subtitle:WaffraText('${dayText(postponed??due)} • ${paid?(waffraIsEnglish?'Paid':'مدفوعة'):(waffraIsEnglish?'Pending':'معلقة')}'),trailing:WaffraText(cash(r.amount)));
     }).toList()))])),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
  }));
 }
 String exportBackup({WaffraFinanceAuthorityRead? fromSource}) {
  // A real backup must reflect a single immutable, verified finance source,
  // not a cached Home list after a simultaneous Android widget save.
  final finance=fromSource?.finance;
  Object listValue(String key,Object fallback)=>
   finance==null?fallback:jsonDecode(finance.getString(key)??'[]');
  Object mapValue(String key,Object fallback)=>
   finance==null?fallback:jsonDecode(finance.getString(key)??'{}');
  final sourceBudget=finance?.getDouble('waffra_monthly_budget_v1')??0;
  final payload={
   'format':'waffra-backup','version':24,
   'exportedAt':DateTime.now().toIso8601String(),
   'entries':listValue('entries',entries.map((e)=>e.toJson()).toList()),
   'categories':listValue('waffra_categories_v24',categories.map((e)=>e.toJson()).toList()),
   'namedBudgets':listValue('waffra_named_budgets_v1',
    namedBudgets.map((b)=>b.toJson()).toList()),
   'goals':listValue('waffra_goals_v24',goals.map((e)=>e.toJson()).toList()),
   'recurring':listValue('waffra_recurring_v24',recurring.map((e)=>e.toJson()).toList()),
   'challenges':listValue('waffra_challenges_v1',challenges.map((e)=>e.toJson()).toList()),
   'deletedCategories':listValue('waffra_deleted_categories_v1',deletedCategories),
   'deletedGoals':listValue('waffra_deleted_goals_v1',deletedGoals),
   'deletedRecurring':listValue('waffra_deleted_recurring_v1',deletedRecurring),
   'recurringPostponed':mapValue('waffra_recurring_postponed_v1',recurringPostponed),
   'monthlyBudget':finance==null?monthlyBudget:sourceBudget,
   'monthlyBudgetEnabled':finance==null?monthlyBudgetEnabled:
    (finance.getBool('waffra_monthly_budget_enabled_v1')??(sourceBudget>0)),
   'learnedMerchants':mapValue('waffra_learned_merchants_v1',learnedMerchantCategories),
   'smsHashes':(List<String>.from(
    finance?.getStringList('waffra_sms_hashes_v1')??smsHashes.toList())..sort()),
   'profile':widget.profile.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
 }
 Future<bool> _authorizeSensitiveAction(String operation)async{
  if(!await WaffraBiometrics.isAvailable()){
   if(mounted)await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Fingerprint required':'بصمة الجهاز مطلوبة'),
    content:WaffraText(waffraIsEnglish?'Enable fingerprint in phone settings before $operation. App PIN cannot replace it.':'يجب تسجيل بصمة على هاتفك أولاً لحماية هذه العملية. لن يسمح وفرة باستخدام رمز التطبيق بدلاً منها.'),
    actions:[OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   return false;
  }
  final allowed=await WaffraBiometrics.unlock();
  if(!allowed&&mounted)snack(context,waffraIsEnglish?'Biometric verification required to continue':'يلزم التحقق ببصمة الجهاز للمتابعة');
  return allowed;
 }
 Future<void> _setRecentAppProtection(bool enabled)async{
  final p=await SharedPreferences.getInstance();
  await p.setBool('waffra_protect_recents_v1',enabled);
  if(mounted)setState(()=>protectRecentApps=enabled);
  if(Platform.isAndroid){
   try{await _privacyChannel.invokeMethod<void>('setProtectRecents',enabled);}
   on PlatformException catch(e){debugPrint('Recents privacy: $e');}
  }
 }
 Future<void> backupDialog()async {
  if(!await _authorizeSensitiveAction('backing up or restoring data')||!mounted)return;
  await _ensureFinanceBound();
  final secret=TextEditingController(),restoreSecret=TextEditingController();
  String? stagedBackup,backupError,restoreError,restorePasswordError;
  var attempted=false,restoring=false,exporting=false;
  int? mode;
  bool advanced=false;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Secure backup':'نسختك الاحتياطية الآمنة',
    style:const TextStyle(fontWeight:FontWeight.bold)),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    WaffraText(waffraIsEnglish?'Your data. Your password.':
     'بياناتك محفوظة بتشفير قوي. أنت وحدك تملك كلمة المرور.',
      textAlign:TextAlign.center),
    const SizedBox(height:15),
    if(mode==null)...[
     OutlinedButton.icon(key:const Key('waffra-backup-choose-export'),
      onPressed:WaffraHaptics.tap(()=>update(()=>mode=0)),
      icon:const Icon(Icons.file_download_rounded),
      label:WaffraText(waffraIsEnglish?'Save encrypted backup':'حفظ نسخة مشفّرة')),
     const SizedBox(height:10),
     OutlinedButton.icon(key:const Key('waffra-backup-choose-restore'),
      onPressed:WaffraHaptics.tap(()=>update(()=>mode=1)),
      icon:const Icon(Icons.restore_page_outlined),
      label:WaffraText(waffraIsEnglish?'Restore from my device':'استعادة من الجهاز')),
     const SizedBox(height:8),
     Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.lock_outline,color:Colors.grey,size:15),
      const SizedBox(width:5),
      Flexible(child:WaffraText(waffraIsEnglish?'Encrypted • No bank connection':
       'مشفّرة • بدون ربط بالحسابات البنكية',style:const TextStyle(fontSize:11))),
     ]),
    ]else ...[
     TextButton.icon(onPressed:WaffraHaptics.tap(()=>update(()=>mode=null)),
      icon:const Icon(Icons.arrow_back_ios_new_rounded,size:14),
      label:WaffraText(waffraIsEnglish?'Back':'رجوع')),
    ],
    if(mode==0)...[
    const SizedBox(height:10),
    TextField(key:const Key('waffra-new-backup-password'),controller:secret,obscureText:true,
     inputFormatters:[LengthLimitingTextInputFormatter(256)],
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Backup password (12+ characters) *':'كلمة مرور النسخة (12 حرفًا على الأقل) *',
      errorText:backupError,errorMaxLines:3,border:const OutlineInputBorder())),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:WaffraHaptics.tap(exporting?null:()async {
     if(!WaffraSecureBackup.isValidNewPassword(secret.text)){
      update(()=>backupError=waffraIsEnglish?'Use 12 to 256 characters for your backup password.':
       'استخدم كلمة مرور من 12 إلى 256 حرفًا للنسخة الاحتياطية.');return;
     }
     update(()=>exporting=true);
     try{
      // Drain in-process saves, then snapshot the latest authoritative
      // finance after any standalone Widget commit under the shared lock.
      await _financialWriteQueue.drain();
      final current=await _financeAuthority.load(
       route:WaffraFinanceRoute.backupExport);
      final String encrypted;
      if(current.encryptedWitness!=null){
       final bridge=_financeBinding?.accountsBridge;
       if(bridge==null)throw StateError('Encrypted backup source unavailable.');
       encrypted=await bridge.exportPortableBackup(secret.text);
      }else{
       final authoritativePayload=exportBackup(fromSource:current);
       encrypted=await compute(waffraEncryptBackupInIsolate,<String,String>{
        'payload':authoritativePayload,'password':secret.text,
       });
      }
      // Persist the encrypted archive only after system document picker confirms.
      // Never copy it to the system clipboard on export.
      final saved=await WaffraBackupFiles.saveEncryptedArchive(encrypted);
      if(!saved)return;
      final generatedAt=DateTime.now().toIso8601String();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('waffra_backup_last_exported_v1',generatedAt);
      await prefs.setInt('waffra_backup_last_size_v1',utf8.encode(encrypted).length);
      if(mounted)setState((){lastBackupGeneratedAt=generatedAt;lastBackupBytes=utf8.encode(encrypted).length;});
      if(ctx.mounted)snackSuccess(ctx,waffraIsEnglish?
       'Encrypted .waffra backup file saved. Keep its password safe.':
       'تم حفظ ملف .waffra المشفّر بنجاح. احتفظ بكلمة المرور بأمان.');
     }catch(_){
      if(ctx.mounted)update(()=>backupError=waffraIsEnglish?
       'Could not save encrypted backup file. Please retry.':
       'تعذر حفظ ملف النسخة الاحتياطية المشفّر. حاول مرة أخرى.');
     }finally{
      if(ctx.mounted)update(()=>exporting=false);
     }
    }),icon:const Icon(Icons.file_download_outlined),label:WaffraText(waffraIsEnglish?
      'Save encrypted .waffra file':'حفظ ملف .waffra المشفّر')),
    ],
    if(mode==1)...[
    const SizedBox(height:10),
    WaffraText(waffraIsEnglish?'Select a Waffra file, then enter its password.':
     'اختر ملف وفرة، ثم أدخل كلمة مروره.',textAlign:TextAlign.center),
    const SizedBox(height:10),
    WaffraText(waffraIsEnglish?'Restore an encrypted backup file':'استعادة ملف نسخة احتياطية مشفّر',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:10),
    TextField(controller:restoreSecret,key:const Key('waffra-existing-backup-password'),
     obscureText:true,
     inputFormatters:[LengthLimitingTextInputFormatter(256)],
     onChanged:(_)=>update(()=>restorePasswordError=null),
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Backup password *':'كلمة مرور النسخة *',
      errorText:restorePasswordError,errorMaxLines:3,
      border:const OutlineInputBorder())),
    const SizedBox(height:10),
    // Select previously exported archives with Android's SAF document picker.
    // Contents remain hidden and are never copied to the clipboard on export.
    OutlinedButton.icon(key:const Key('waffra-open-backup-file'),
     onPressed:WaffraHaptics.tap(restoring?null:()async{
      try{
       final selected=await WaffraBackupFiles.openArchive();
       if(!ctx.mounted||selected==null)return;
       update((){
        stagedBackup=selected;
        restoreError=null;
        attempted=false;
       });
      }catch(_){
       if(ctx.mounted)update(()=>restoreError=waffraIsEnglish?
        'File verification failed. Please choose a valid Waffra backup.':
        'فشل التحقق من صحة الملف. يرجى اختيار نسخة احتياطية صحيحة من وفرة والمحاولة مرة أخرى.');
      }
     }),icon:const Icon(Icons.file_open_outlined),
     label:WaffraText(waffraIsEnglish?'Choose .waffra file':'اختيار ملف .waffra من الجهاز')),
    // Backward compatibility ONLY: opt-in reading of previously exported
    // clipboard-only text. New exports never put archive data on clipboard.
    TextButton.icon(onPressed:WaffraHaptics.tap(()=>update(()=>advanced=!advanced)),
     icon:Icon(advanced?Icons.expand_less:Icons.expand_more),
     label:WaffraText(waffraIsEnglish?'Advanced options':'خيارات متقدمة')),
    if(advanced)TextButton.icon(key:const Key('waffra-import-legacy-text'),
     onPressed:WaffraHaptics.tap(restoring?null:()async{
      final old=await Clipboard.getData(Clipboard.kTextPlain);
      if(!ctx.mounted)return;
      final text=old?.text?.trim()??'';
      if(text.isEmpty||text.length>WaffraBackupFiles.maxArchiveBytes){
       update(()=>restoreError=waffraIsEnglish?
        'No valid older backup text in clipboard.':
        'لا يوجد نص نسخة احتياطية قديمة صالح في الحافظة.');
       return;
      }
      update((){
       stagedBackup=text;
       restoreError=null;
       attempted=false;
      });
     }),icon:const Icon(Icons.history_outlined,size:18),
     label:WaffraText(waffraIsEnglish?
      'Import older copied backup (legacy)':'استيراد نسخة نصية قديمة (للتوافق فقط)')),
    if(stagedBackup!=null)...[
     const SizedBox(height:8),
     ListTile(dense:true,leading:const Icon(Icons.check_circle_outline,color:Colors.green),
      title:WaffraText(waffraIsEnglish?'Backup file loaded. Ready to verify.':'تم تحميل النسخة الاحتياطية وجاهزة للتحقق.'),
      trailing:IconButton(icon:const Icon(Icons.close),
       tooltip:waffraIsEnglish?'Clear backup':'إزالة النسخة الملصوقة',
       onPressed:WaffraHaptics.tap(restoring?null:()=>update((){
        stagedBackup=null;restoreError=null;attempted=false;
       })))),
    ],
    if(attempted&&stagedBackup==null)
     WaffraText(restoreError??(waffraIsEnglish?'Choose a backup file first.':'اختر ملف نسخة احتياطية أولًا.'),
      style:const TextStyle(color:Colors.red)),
    if(restoreError!=null&&stagedBackup!=null)
     WaffraText(restoreError!,style:const TextStyle(color:Colors.red)),
    if(restoring)const LinearProgressIndicator(),
    ],
   ])),
   actions:[
    TextButton(onPressed:WaffraHaptics.tap(restoring?null:()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Close':'إغلاق')),
    if(mode==1)FilledButton(key:const Key('waffra-confirm-backup-restore'),
     onPressed:WaffraHaptics.tap(restoring?null:()async {
     update(()=>attempted=true);
     if(restoreSecret.text.isEmpty){
      update(()=>restorePasswordError=waffraIsEnglish?
       'Enter the original backup password.':'أدخل كلمة مرور النسخة الأصلية.');
      return;
     }
     if(stagedBackup==null||stagedBackup!.isEmpty)return;
     update(()=>restoring=true);
     var backupDecrypted=false;
     var sqlcipherRestoreCommitted=false;
     var restoreStage='AUTH';
     List<dynamic>? authenticatedLegacyRows;
     // M622: reuse the already-selected encrypted source. The independent
     // preflight re-reads its generation/digest before approving any write.
     WaffraFinanceAuthorityRead? inspectedRestoreSource;
     try{
      var restoreArchive=stagedBackup!;
      var raw=await compute(waffraDecodeBackupInIsolate,<String,String>{
       'payload':restoreArchive,'password':restoreSecret.text,
      });
      backupDecrypted=true;
      restoreStage='SOURCE';
      var omittedLegacyReceiptCount=0;
      // Old V24 password-authenticated exports use legacy finance JSON, not
      // the account-aware SQLCipher V3 layout. Build a disposable encrypted V3
      // candidate; the existing rescue/preflight/atomic restore then applies.
      // An in-place upgrade on legacy storage continues down its old route.
      if(raw['format']=='waffra-backup'&&raw['version']==24){
       final source=await _financeAuthority.load(
        route:WaffraFinanceRoute.backupRestore);
       if(source.encryptedWitness!=null){
        inspectedRestoreSource=source;
        authenticatedLegacyRows=List<dynamic>.of(raw['entries'] as List);
        final unavailable=
         WaffraLegacyV24SqlCipherConverter.unavailableReceiptCount(raw);
        if(unavailable>0){
         final approvedMissing=await confirm(
          waffraIsEnglish?'Unavailable old receipt images':
           'مرفقات غير موجودة داخل النسخة',
          waffraIsEnglish?
           'This old backup contains $unavailable receipt image reference(s) but not the image bytes. Restoring transactions will omit these unavailable photos. Amounts, dates and other records stay unchanged. Do you explicitly agree to continue without those images?':
           'النسخة القديمة فيها $unavailable مرفق صورة محفوظ كمسار فقط، بدون ملف الصورة نفسه. عند الاستعادة ستبقى العمليات والمبالغ والتواريخ، لكن الصور دي لن تنتقل. هل توافق صراحةً على الاستعادة بدون المرفقات دي؟');
         if(approvedMissing!=true||!ctx.mounted||!mounted)return;
        }
        restoreStage='V24_STAGING';
        final candidate=await WaffraLegacyV24SqlCipherConverter.prepare(
         payload:raw,password:restoreSecret.text,
         userApprovedMissingReceipts:true);
        omittedLegacyReceiptCount=candidate.unavailableReceiptCount;
        restoreArchive=candidate.encryptedV3;
        raw=<String,dynamic>{
         'format':WaffraAccountsPortableBackupV3.format,
        };
       }
      }
      if(raw['format']==WaffraAccountsPortableBackupV3.format){
       final source=inspectedRestoreSource??
        await _financeAuthority.load(route:WaffraFinanceRoute.backupRestore);
       if(source.encryptedWitness==null){
        if(ctx.mounted)update(()=>restoreError=waffraIsEnglish?
         'This file requires an active SQLCipher vault.':
         'استعادة هذا الملف تتطلب تفعيل قاعدة SQLCipher.');
        return;
       }
       restoreStage='SQL_PREFLIGHT';
       final result=await WaffraVerifiedActiveRestorePreflight(
        authority:_financeAuthority,experimentalEnabled:true,
       ).inspect(selectedSource:source,encryptedArchive:restoreArchive,
        password:restoreSecret.text,userConfirmed:true,accountArchive:true);
       if(!ctx.mounted||!mounted)return;
       final approved=await confirm(
        waffraIsEnglish?'Replace encrypted finance?':'استبدال البيانات المالية؟',
        waffraIsEnglish
         ?'Restore ${result.transactionCount} transactions and ${result.receiptCount} receipts?'
         :'هل تريد استعادة ${result.transactionCount} معاملة و${result.receiptCount} مرفق؟');
       if(approved!=true||!mounted||!ctx.mounted)return;
       if(!await _authorizeSensitiveAction('replacing encrypted finance')||
          !mounted||!ctx.mounted)return;
       // Neither the file chooser nor the biometric prompt holds the native
       // writer lock; the final commit compares the preflight source witness.
       await _financialWriteQueue.drain();
       final bridge=_financeBinding?.accountsBridge;
       if(bridge==null)throw StateError('Active finance source is unavailable.');
       restoreStage='SQL_APPLY';
       final applied=await bridge.applyVerifiedV3Restore(
        baseline:source.encryptedWitness!,
        encryptedArchive:restoreArchive,password:restoreSecret.text,
        preflightChecksum:result.archiveChecksum,
        userConfirmed:true);
       sqlcipherRestoreCommitted=true;
       restoreStage='HOME_REFRESH';
       if(!mounted)return;
       // The authoritative encrypted snapshot, not a decoded backup in
       // memory, becomes the source for Home and widget after one commit.
       await _loadFinanceSafely();
       if(authenticatedLegacyRows!=null&&mounted){
        // M620: preflight attests an isolated candidate; verify live SQLCipher
        // AGAIN after the transaction and compare stable IDs, money and dates.
        restoreStage='CANONICAL_PARITY';
        final verified=await _financeAuthority.load(
         route:WaffraFinanceRoute.dashboardRead);
        verified.finance.requireIntegrity();
        final canonicalRaw=verified.ledgerRaw;
        if(canonicalRaw==null){
         throw StateError('M620_MISSING_CANONICAL_LEDGER');
        }
        final canonicalRows=await WaffraLargeJsonDecode.parse(canonicalRaw);
        if(canonicalRows is! List){
         throw StateError('M620_INVALID_CANONICAL_LEDGER');
        }
        WaffraRestoredLedgerIdentityGuard.verify(
         authenticatedSource:authenticatedLegacyRows,
         verifiedSnapshot:canonicalRows);
        restoreStage='HOME_PARITY';
        try{
         WaffraRestoredLedgerIdentityGuard.verify(
          authenticatedSource:authenticatedLegacyRows,
          verifiedSnapshot:entries.map((e)=>e.toJson()).toList());
        }on StateError{
         // Correct a stale presentation from ONE VERIFIED canonical source.
         // Never delete same-looking entries from a financial database.
         final exact=await _m593BuildVerifiedEntries(canonicalRows);
         if(!mounted)return;
         setState((){entries..clear()..addAll(exact);});
         WaffraRestoredLedgerIdentityGuard.verify(
          authenticatedSource:authenticatedLegacyRows,
          verifiedSnapshot:entries.map((e)=>e.toJson()).toList());
        }
       }
       if(mounted)await _refreshWidget();
       if(mounted)await syncRecurringReminders();
       if(ctx.mounted)Navigator.pop(ctx);
       if(mounted)snackSuccess(context,waffraIsEnglish
        ?'Encrypted restore verified: ${applied.transactionCount} transactions and ${applied.receiptCount} receipts. '
          '${omittedLegacyReceiptCount>0?"Warning: "+omittedLegacyReceiptCount.toString()+" old receipt image(s) were unavailable in this backup and were not restored. ":""}'
          ''
        :'اكتملت استعادة ${applied.transactionCount} معاملة و${applied.receiptCount} مرفق. '
         '${omittedLegacyReceiptCount>0?"تنبيه: "+omittedLegacyReceiptCount.toString()+" من صور المرفقات القديمة غير موجودة داخل الباكب ولم تُستعد. ":""}'
         '');
       return;
      }
      if(raw['format']!='waffra-backup'||raw['entries'] is! List||
        raw['categories'] is! List||raw['goals'] is! List||raw['recurring'] is! List){
       throw const FormatException('Invalid backup');
      }
      final newEntries=(raw['entries'] as List).map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x))).toList();
      final newCategories=(raw['categories'] as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))).toList();
      if(raw.containsKey('namedBudgets')&&raw['namedBudgets'] is! List){
       throw const FormatException('Invalid independent budget backup.');
      }
      final newNamedBudgets=(raw['namedBudgets'] as List? ??const [])
       .map((x)=>WaffraNamedBudget.fromJson(Map<String,dynamic>.from(x)))
       .toList();
      // V24 archives without namedBudgets are intentionally supported.
      for(final c in newCategories.where((c)=>!c.income&&c.budget>0)){
       if(!newNamedBudgets.any((b)=>b.id==c.id)){
        newNamedBudgets.add(WaffraNamedBudget.fromLegacy(c));
       }
      }
      final newGoals=(raw['goals'] as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))).toList();
      final newRecurring=(raw['recurring'] as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))).toList();
      final newChallenges=raw['challenges'] is List?(raw['challenges'] as List).map((x)=>SavingChallenge.fromJson(Map<String,dynamic>.from(x))).toList():<SavingChallenge>[];
      final newDeletedRecurring=raw['deletedRecurring'] is List?(raw['deletedRecurring'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      final newDeletedGoals=raw['deletedGoals'] is List?(raw['deletedGoals'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      final newPostponed=raw['recurringPostponed'] is Map?(raw['recurringPostponed'] as Map).map((k,v)=>MapEntry(k.toString(),v.toString())):<String,String>{};
      final newTrash=raw['deletedCategories'] is List?
       (raw['deletedCategories'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList():<Map<String,dynamic>>[];
      if(newCategories.isEmpty)throw const FormatException('Empty categories');
      final restoredBudget=raw['monthlyBudget'] is num?
       (raw['monthlyBudget'] as num).toDouble():monthlyBudget;
      final restoredRules=<String,String>{};
      if(raw['learnedMerchants'] is Map){
       final rules=raw['learnedMerchants'] as Map;
       restoredRules.addAll(rules.map((key,value)=>MapEntry(key.toString(),value.toString())));
      }
      if(!mounted)return;
      final ok=await confirm(
       waffraIsEnglish?'Confirm backup restore':'تأكيد الاستعادة',
       waffraIsEnglish?'Restore this backup?':'هل تريد استعادة النسخة الاحتياطية؟');
      if(ok!=true||!mounted)return;
      if(!await _authorizeSensitiveAction('restoring data')||!mounted)return;
      // Build the complete restored finance image without mutating Home
      // state. A rejected source witness or interrupted writer must NOT
      // show transactions that were never durably committed.
      final hashesPayload=raw['smsHashes'];
      if(hashesPayload!=null&&(hashesPayload is! List||
        hashesPayload.length>100000||
        hashesPayload.any((value)=>value is! String||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)))){
       throw const FormatException('Invalid restored SMS fingerprints');
      }
      final restoredHashes=<String>{...?((hashesPayload as List?)?.cast<String>())};
      final restoredBudgetEnabled=raw['monthlyBudgetEnabled'] is bool?
       raw['monthlyBudgetEnabled'] as bool:restoredBudget>0;
      final restoreSnapshot=<String,Object>{
       'entries':jsonEncode(newEntries.map((e)=>e.toJson()).toList()),
       'waffra_categories_v24':jsonEncode(newCategories.map((c)=>
        c.budget>0&&newNamedBudgets.any((b)=>b.id==c.id)?
         c.copy(budget:0,clearBudget:true).toJson():c.toJson()).toList()),
       'waffra_named_budgets_v1':jsonEncode(
        newNamedBudgets.map((b)=>b.toJson()).toList()),
       'waffra_goals_v24':jsonEncode(newGoals.map((e)=>e.toJson()).toList()),
       'waffra_recurring_v24':jsonEncode(newRecurring.map((e)=>e.toJson()).toList()),
       'waffra_challenges_v1':jsonEncode(newChallenges.map((e)=>e.toJson()).toList()),
       'waffra_deleted_categories_v1':jsonEncode(newTrash),
       'waffra_deleted_goals_v1':jsonEncode(newDeletedGoals),
       'waffra_deleted_recurring_v1':jsonEncode(newDeletedRecurring),
       'waffra_recurring_postponed_v1':jsonEncode(newPostponed),
       'waffra_monthly_budget_v1':restoredBudget,
       'waffra_monthly_budget_enabled_v1':restoredBudgetEnabled,
       'waffra_learned_merchants_v1':jsonEncode(restoredRules),
       'waffra_sms_hashes_v1':restoredHashes.toList()..sort(),
      };
      // Re-read the latest authority inside the Home write queue. Both
      // backends MUST pass source selection before a single journaled
      // legacy batch / verified SQLCipher transaction is accepted.
      // The SQLCipher bridge currently rejects backupRestore rather than
      // falling back to plaintext until encrypted restore is certified.
      await _financialWriteQueue.submit(restoreSnapshot,(captured)async{
       final baseline=await _financeAuthority.load(
        route:WaffraFinanceRoute.backupRestore);
       final committed=await _financeAuthority.saveCaptured(
        route:WaffraFinanceRoute.backupRestore,
        baseline:baseline,captured:captured);
       _lastFinanceAuthorityRead=committed;
       _lastLedgerSavedRaw=committed.ledgerRaw;
       _lastWidgetRevision=committed.widgetRevision;
      });
      if(!mounted)return;
      // Only publish the restored view after the source reports a durable
      // commit. Never optimistically replace in-memory money on error.
      setState((){
       entries..clear()..addAll(newEntries);
       categories..clear()..addAll(newCategories);
       namedBudgets..clear()..addAll(newNamedBudgets);
       goals..clear()..addAll(newGoals);
       recurring..clear()..addAll(newRecurring);
       challenges..clear()..addAll(newChallenges);
       deletedCategories..clear()..addAll(newTrash);
       deletedGoals..clear()..addAll(newDeletedGoals);
       deletedRecurring..clear()..addAll(newDeletedRecurring);
       recurringPostponed..clear()..addAll(newPostponed);
       monthlyBudget=restoredBudget;
       monthlyBudgetEnabled=restoredBudgetEnabled;
       learnedMerchantCategories..clear()..addAll(restoredRules);
       smsHashes..clear()..addAll(restoredHashes);
      });
      unawaited(_refreshWidget());
      await syncRecurringReminders();
      if(ctx.mounted)Navigator.pop(ctx);
      if(mounted)snackSuccess(context,'تمت استعادة البيانات بنجاح');
     }catch(e){
      // Once the AEAD archive decrypted successfully, a later schema or
      // SQLCipher failure is NOT a bad password. Keep detailed errors in QA
      // logs only; never echo secrets or user finance values in UI.
      debugPrint('Waffra restore failed: stage='+restoreStage+
        ' authenticated='+backupDecrypted.toString()+
        ' type='+e.runtimeType.toString());
      if(ctx.mounted)update(() {
       // Additional phase is populated only by the authenticated SQLCipher
       // staging validator; never include exception text or user records.
       final safeStage=e is WaffraRestorePreflightStageError
        ? 'SQL_PREFLIGHT/${e.stage}' : restoreStage;
       restoreError=sqlcipherRestoreCommitted?
       (waffraIsEnglish
        ?'The restore was committed, but the transaction ID parity or Home refresh needs review. Do NOT delete transactions. Keep the rescue and reopen Waffra.'
        :'تم حفظ الاستعادة، لكن مطابقة معرّفات العمليات أو تحديث الشاشة يحتاج مراجعة. لا تحذف أي عملية، واحتفظ بنسخة الأمان وأعد فتح وفرة.'):
       backupDecrypted?
       (waffraIsEnglish
        ?'The backup password was accepted, but the data could not be migrated safely. Inspect the current records and keep the encrypted rescue copy.'
        :'كلمة مرور النسخة صحيحة، لكن تعذر ترحيل البيانات بأمان. راجع البيانات الحالية واحتفظ بنسخة الأمان المشفرة.'):
       (waffraIsEnglish
        ?'Could not authenticate this encrypted backup. Check its original password and file integrity.'
        :'تعذر التحقق من تشفير النسخة. راجع كلمة مرور النسخة الأصلية وسلامة الملف.');
       // Privacy-safe code for support: no password, paths, sender or amounts.
       restoreError='${restoreError ?? ''} [R616:$safeStage]';
      });
     }finally{
      if(ctx.mounted)update(()=>restoring=false);
     }
    }),child:WaffraText(waffraIsEnglish?'Restore':'استعادة')),
   ])));
  disposeLater([secret,restoreSecret]);
 }
 // System credentials are never saved in plain text. A new PIN must be
 // entered twice; keep support for checking older 4-8-digit PINs on disable.
 Future<String?> _askForPin({
  required String title,required String fieldLabel,bool existing=false,
  bool autoAdvance=false,bool Function(String)? verify,String? verifyError,
 })async{
  final input=TextEditingController();
  var attempted=false;String? fieldError;
  try{
   return await showWaffraDialog<String>(context:context,
    builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,update)=>
     Theme(data:Theme.of(dialogContext).copyWith(brightness:Brightness.dark,
      colorScheme:ColorScheme.fromSeed(seedColor:emerald,brightness:Brightness.dark)),
      child:AlertDialog(
       backgroundColor:forest,
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
        side:waffraDialogOutline(Brightness.dark)),
       title:Column(mainAxisSize:MainAxisSize.min,children:[
        const CircleAvatar(radius:26,backgroundColor:emerald,
         child:Icon(Icons.lock_outline,color:Colors.white,size:28)),
        const SizedBox(height:12),
        WaffraText(title,textAlign:TextAlign.center,
         style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
       ]),
       content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
         WaffraText(fieldLabel,textAlign:TextAlign.center,
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),
         const SizedBox(height:12),
         // In-app digits-only keypad avoids Samsung's punctuation keyboard.
         TextField(key:const Key('waffra-pin-input'),controller:input,
          autofocus:false,readOnly:true,showCursor:false,
          enableInteractiveSelection:false,
          textDirection:TextDirection.ltr,textAlign:TextAlign.center,
          keyboardType:TextInputType.number,
          inputFormatters:[FilteringTextInputFormatter.digitsOnly,
           LengthLimitingTextInputFormatter(existing?8:4)],
          obscureText:true,
          style:const TextStyle(color:Color(0xFF12382D),fontWeight:FontWeight.bold),
          decoration:InputDecoration(
           filled:true,fillColor:Colors.white,
           hintText:'••••',hintStyle:const TextStyle(color:Colors.black38),
           errorText:fieldError??
            (attempted?waffraPinFieldError(input.text,existing:existing):null),
           errorMaxLines:3,
           border:const OutlineInputBorder())),
         const SizedBox(height:10),
         for(final keys in const <List<String>>[
          ['1','2','3'],['4','5','6'],['7','8','9'],['','0','back']
         ])Padding(padding:const EdgeInsets.only(bottom:5),child:Row(textDirection:TextDirection.ltr,
          children:[for(final digit in keys)Expanded(child:Padding(
           padding:const EdgeInsets.symmetric(horizontal:3),
           child:digit.isEmpty?const SizedBox(height:42):OutlinedButton(
            key:Key('waffra-pin-key-$digit'),
            style:OutlinedButton.styleFrom(
             minimumSize:const Size(0,42),
             padding:EdgeInsets.zero,foregroundColor:Colors.white,
             side:BorderSide(color:Colors.white.withValues(alpha:.23)),
             shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
            onPressed:WaffraHaptics.tap((){
             if(digit=='back'){
              if(input.text.isEmpty)return;
              input.text=input.text.substring(0,input.text.length-1);
              update(()=>fieldError=null);
              return;
             }
             if(input.text.length>=(existing?8:4))return;
             final value=input.text+digit;
             input.text=value;
             update(()=>fieldError=null);
             if(autoAdvance&&value.length==4&&waffraPinFieldError(value)==null){
              WidgetsBinding.instance.addPostFrameCallback((_){
               if(dialogContext.mounted&&input.text==value){
                Navigator.pop(dialogContext,value);
               }
              });
             }
            }),
            child:digit=='back'
             ?const Icon(Icons.backspace_outlined,size:20)
             :Text(digit,style:const TextStyle(fontFamily:'Tajawal',
               fontSize:19,fontWeight:FontWeight.bold))),
          ))])),
        ])),
       actions:[
        TextButton(
         style:TextButton.styleFrom(foregroundColor:Colors.white,
          backgroundColor:Colors.white.withValues(alpha:.12)),
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext)),
         child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        if(!autoAdvance)FilledButton(
         style:FilledButton.styleFrom(backgroundColor:emerald,
          foregroundColor:Colors.white),
         onPressed:WaffraHaptics.tap((){
          final code=input.text.trim();
          update(()=>attempted=true);
          if(waffraPinFieldError(code,existing:existing)!=null)return;
          if(verify!=null&&!verify(code)){
           update(()=>fieldError=verifyError??
            (waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح'));
           return;
          }
          Navigator.pop(dialogContext,code);
         }),
         child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
       ],
      ))));
  }finally{disposeLater([input]);}
 }
 Future<void> configurePin()async {
  if(widget.pinEnabled){
   final prefs=await SharedPreferences.getInstance();
   final hash=prefs.getString('waffra_pin_sha256');
   final oldPin=await _askForPin(
    title:waffraIsEnglish?'Disable app lock':'إلغاء رمز القفل',
    fieldLabel:waffraIsEnglish?'Current PIN':'أدخل الرمز الحالي',
    existing:true,verify:(code)=>sha256.convert(utf8.encode(code)).toString()==hash,
    verifyError:waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح');
   if(oldPin==null||!mounted)return;
   await widget.onSetPin(null);
   if(mounted)snackSuccess(context,waffraIsEnglish?'App lock disabled':'تم إلغاء القفل');
   return;
  }
  final firstPin=await _askForPin(
   title:waffraIsEnglish?'Create a new PIN':'إنشاء رمز قفل',
   fieldLabel:waffraIsEnglish?'Enter a 4-digit PIN':'أدخل رمز القفل من 4 أرقام',
    autoAdvance:true);
  if(firstPin==null||!mounted)return;
  while(mounted){
   final repeated=await _askForPin(
    title:waffraIsEnglish?'Confirm PIN':'تأكيد رمز القفل',
    fieldLabel:waffraIsEnglish?'Re-enter the same 4 digits':'أدخل رمز القفل المكوّن من 4 أرقام مرة ثانية',
    verify:(code)=>code==firstPin,
    verifyError:waffraIsEnglish?'PINs do not match':'رمزا PIN غير متطابقين');
   if(repeated==null||!mounted)return;
   if(firstPin==repeated){
    // The existing onSetPin stores only SHA-256 of the confirmed PIN.
    await widget.onSetPin(firstPin);
    if(mounted)snackSuccess(context,waffraIsEnglish?'App lock enabled':'تم تفعيل قفل التطبيق');
    return;
   }
  }
 }
 Future<void> changePin()async {
  if(!widget.pinEnabled)return;
  final p=await SharedPreferences.getInstance();
  final hash=p.getString('waffra_pin_sha256');
  final previous=await _askForPin(title:waffraIsEnglish?'Current PIN':'رمز القفل الحالي',
   fieldLabel:waffraIsEnglish?'Enter PIN':'أدخل رمز القفل',existing:true,
   verify:(code)=>sha256.convert(utf8.encode(code)).toString()==hash,
   verifyError:waffraIsEnglish?'Incorrect PIN':'رمز القفل غير صحيح');
  if(previous==null||!mounted)return;
  final next=await _askForPin(title:waffraIsEnglish?'New PIN':'رمز جديد',
   fieldLabel:waffraIsEnglish?'4 digits':'أربعة أرقام');
  if(next==null||!mounted)return;
  final again=await _askForPin(title:waffraIsEnglish?'Confirm PIN':'تأكيد الرمز',
   fieldLabel:waffraIsEnglish?'Repeat PIN':'أعد إدخال الرمز',
   verify:(code)=>code==next,
   verifyError:waffraIsEnglish?'PINs do not match':'الرمزان غير متطابقين');
  if(again==null||!mounted)return;
  await widget.onSetPin(next);
  if(mounted)snackSuccess(context,waffraIsEnglish?'PIN changed':'تم تغيير الرمز بنجاح');
 }
 Future<void> eraseFinancialData()async {
  if(!await _authorizeSensitiveAction('deleting financial data')||!mounted)return;
  final ok=await confirmDeletion(
   waffraIsEnglish?'Permanently delete financial data?':'حذف البيانات المالية نهائيًا',
   waffraIsEnglish?'This deletes transactions, categories, budgets, goals and recurring schedules. It cannot be undone. Your profile and app settings stay.':
    'سيتم حذف المعاملات والأقسام والميزانيات والأهداف والجدولة المتكررة نهائيًا. لا يمكن التراجع. سيبقى الملف الشخصي وإعدادات التطبيق.');
  if(ok!=true||!mounted)return;
  final cleanCategories=defaultCategories();
  // Every recognized financial field is reset through ONE crash-recoverable
  // journal. SMS hashes must NOT be cleared independently before finance
  // persistence, and non-finance profile/app settings must remain intact.
  final clean=<String,Object>{
   'entries':'[]',
   'waffra_categories_v24':jsonEncode(cleanCategories.map((e)=>e.toJson()).toList()),
   'waffra_named_budgets_v1':'[]',
   'waffra_goals_v24':'[]',
   'waffra_recurring_v24':'[]',
   'waffra_challenges_v1':'[]',
   'waffra_deleted_categories_v1':'[]',
   'waffra_deleted_goals_v1':'[]',
   'waffra_deleted_recurring_v1':'[]',
   'waffra_recurring_postponed_v1':'{}',
   'waffra_monthly_budget_v1':0.0,
   'waffra_monthly_budget_enabled_v1':false,
   'waffra_learned_merchants_v1':'{}',
   'waffra_sms_hashes_v1':<String>[],
   'waffra_recurring_reminders_enabled_v1':false,
  };
  try{
   final baseline=_lastFinanceAuthorityRead;
   await _financialWriteQueue.submit(clean,(captured)async{
    if(baseline==null)throw StateError('Finance reset source baseline unavailable.');
    final committed=await _financeAuthority.saveCaptured(
     route:WaffraFinanceRoute.fullFinanceReset,
     baseline:baseline,captured:captured,
    );
    _lastFinanceAuthorityRead=committed;
    _lastLedgerSavedRaw=committed.ledgerRaw;
    _lastWidgetRevision=committed.widgetRevision;
   });
   if(!mounted)return;
   setState((){
    _m684InvalidatePeriodRead();
    entries.clear();
    categories..clear()..addAll(cleanCategories);
    namedBudgets.clear();
    goals.clear();challenges.clear();recurring.clear();
    deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();
    recurringPostponed.clear();smsHashes.clear();learnedMerchantCategories.clear();
    monthlyBudget=0;monthlyBudgetEnabled=false;recurringRemindersEnabled=false;
   });
   unawaited(_refreshWidget());
   try{await WaffraReminders.clear();}catch(e){
    debugPrint('Could not clear old recurring reminders: $e');
   }
   if(mounted)snackSuccess(context,waffraIsEnglish?'Financial data deleted':'تم حذف البيانات المالية');
  }catch(e){
   debugPrint('Financial erase was not fully confirmed: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be verified. Reload before retrying.':
    'تعذر تأكيد حذف البيانات. أعد التحميل قبل المحاولة مجددًا.');
  }
 }
 Widget _accountTile(String label,String subtitle,IconData icon,{VoidCallback? onTap,Widget? trailing,Color tint=emerald})=>
  ListTile(
   leading:CircleAvatar(backgroundColor:tint.withValues(alpha:.12),child:Icon(icon,color:tint,size:21)),
   title:WaffraText(label,style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),
   trailing:trailing??(onTap==null?null:const Icon(Icons.chevron_left)),onTap:WaffraHaptics.tap(onTap));
 Widget _accountSection(String heading,IconData icon,List<Widget> children) {
  final q=accountSearch.trim().toLowerCase();
  if(q.isNotEmpty&&_accountOpenSection!=heading)return const SizedBox.shrink();
  final opened=_accountOpenSection==heading;
  final dim=Theme.of(context).brightness==Brightness.dark;
  return Card(margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(20),
   side:BorderSide(color:dim?const Color(0xFF456855):const Color(0xFFDCEAE1))),
   child:Column(children:[
    InkWell(onTap:WaffraHaptics.tap(()=>setState(()=>_accountOpenSection=opened?null:heading)),
     borderRadius:BorderRadius.circular(20),
     child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[
      CircleAvatar(radius:20,backgroundColor:emerald.withValues(alpha:.12),child:Icon(icon,color:emerald,size:21)),
      const SizedBox(width:10),Expanded(child:WaffraText(heading,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
      AnimatedRotation(turns:opened?0.5:0.0,duration:waffraMotion(200),child:const Icon(Icons.keyboard_arrow_down_rounded)),
     ]))),
    AnimatedSize(duration:waffraMotion(220),curve:Curves.easeInOutCubic,
     child:opened?Column(children:[
      const Divider(height:1),for(var i=0;i<children.length;i++)...[
       children[i],if(i<children.length-1)const Divider(height:1,indent:14,endIndent:14),
      ],
     ]):const SizedBox(width:double.infinity,height:0)),
   ]));
 }
 List<WaffraCalendarItem> get financialCalendarItems=>[
  ...entries.map((e)=>WaffraCalendarItem(e.date,e.title,e.amount,e.income)),
  ...recurring.where((r)=>r.active).map((r)=>WaffraCalendarItem(
   DateTime(DateTime.now().year,DateTime.now().month,r.day.clamp(1,28).toInt()),
   r.title,r.amount,r.income,scheduled:true)),
 ];
 // The third footer tab owns the tool accordion. Finance is read-only:
 // freeze verified snapshots and never read original SMS or modify the ledger.
 Widget _smartToolsTab(){
  if(!ready||_financeBinding==null||_lastFinanceAuthorityRead==null){
   return Center(child:WaffraText(waffraIsEnglish?
    'Financial source not ready':'مصدر البيانات المالية غير جاهز'));
  }
  // Budget linking is explicit, never inferred from category labels.
  final liveBudgetIds=namedBudgets.where((b)=>!b.deleted).map((b)=>b.id).toSet();
  return WaffraSmartFeaturesPage(
   key:const Key('waffra-m268-footer-page'),
   embedded:true,english:waffraIsEnglish,
   onNotice:(message)=>snack(context,message),
   analysisBuilder:(_)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[smartAnalysisEntryCard(),const SizedBox(height:10),smartMoneyInsightsCard()]),
   entries:List<WaffraSmartEntry>.unmodifiable(entries.map((e)=>WaffraSmartEntry(
    id:e.id,title:e.title,category:e.category,amount:e.amount,
    income:e.income,date:e.date,notes:e.notes,
    hasAttachment:e.receiptPath?.isNotEmpty??false,
    unassignedNamedBudget:!e.income&&e.budgetId==null,
    orphanBudgetLink:e.budgetId!=null&&!liveBudgetIds.contains(e.budgetId)))),
   goals:List<WaffraSmartGoal>.unmodifiable(goals.map((g)=>
    WaffraSmartGoal(g.name,g.target,g.saved))),
   budgets:List<WaffraSmartBudget>.unmodifiable(
    namedBudgets.where((b)=>!b.deleted&&b.budget>0).map((b)=>
     WaffraSmartBudget(b.id,b.budgetLabel??b.name,b.budget,
      waffraNamedBudgetSpent(entries,categories,b,DateTime.now()),b.budgetActive))),
   recurring:List<WaffraSmartRecurring>.unmodifiable(recurring.where((r)=>r.active).map((r)=>
    WaffraSmartRecurring(r.title,r.amount,r.day,r.income))),
  );
 }
 void openSmartFeatures(){
  if(!ready||_financeBinding==null||_lastFinanceAuthorityRead==null){
   snack(context,waffraIsEnglish?'Financial source not ready':'مصدر البيانات المالية غير جاهز');
   return;
  }
  unawaited(selectFooter(2));
 }
 void openFinancialCalendar()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraFinancialCalendar(items:financialCalendarItems,english:waffraIsEnglish)));
 void openSubscriptionInsights()=>Navigator.push<void>(context,MaterialPageRoute(
  builder:(_)=>WaffraSubscriptionScreen(
   items:financialCalendarItems,english:waffraIsEnglish,
   onAddRecurring:(candidate)=>recurringDialog(
    suggestedTitle:candidate.title,suggestedAmount:candidate.estimatedMonthly))));
 Future<void> chooseAppCurrency()async{
  if(!WaffraSaudiRelease.userCurrencyChoice)return;
  final searchController=TextEditingController();
  String query='';
  try{
   final chosen=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
     final visible=waffraCountryCurrencies.where((country)=>
      waffraSearchAny([country.countryAr,country.countryEn,country.nameAr,
       country.nameEn,country.code],query)).toList();
     return AlertDialog(
      title:WaffraText(waffraIsEnglish?'Application currency':'العملة الأساسية للتطبيق'),
      content:SizedBox(width:420,height:410,child:Column(children:[
       TextField(key:const Key('waffra-country-currency-search'),
        controller:searchController,autofocus:true,
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
         hintText:waffraIsEnglish?'Find country or currency':'ابحث عن دولة أو عملة'),
        onChanged:(v)=>update(()=>query=v)),
       const SizedBox(height:9),
       Expanded(child:ListView.builder(itemCount:visible.length,
        itemBuilder:(context,index){
         final option=visible[index];
         return ListTile(
          key:Key('waffra-country-currency-${option.code}'),
          selected:WaffraDisplayCurrency.country.code==option.code,
          leading:Text(waffraCurrencyFlag(option.code),
           style:const TextStyle(fontSize:27)),
          title:WaffraText(option.label(waffraIsEnglish)),
          trailing:WaffraDisplayCurrency.country.code==option.code?
           const Icon(Icons.check_circle,color:emerald):null,
          onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,option.code)));
        })),
      ])),
      actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
     );
    }));
   if(chosen==null||!mounted)return;
   try{
    await WaffraDisplayCurrency.setCurrency(chosen);
    if(!mounted)return;
    setState((){});
    await _refreshWidget();
    if(mounted)snackSuccess(context,waffraIsEnglish?
      'Display currency changed; numbers stay exactly the same.':
      'تم تغيير عملة العرض مع الحفاظ على قيمة الأرقام كما هي.');
   }catch(error){
    debugPrint('App country currency rejected safely: $error');
    if(mounted)snack(context,waffraIsEnglish?
      'Could not save display currency; no financial amount was modified.':
      'تعذّر حفظ عملة العرض، ولم يتم تعديل أي مبلغ مالي.');
   }
  }finally{searchController.dispose();}
 }
 // M687: Profile page moved to a same-library State extension.
// Build only the selected tab; constructing all six tabs on every frame
 // caused avoidable work and visible transition lag on Android.
 Widget _addMenuOption({
  required IconData icon,required String label,required VoidCallback onTap,
 })=>Material(
  color:Theme.of(context).brightness==Brightness.dark?const Color(0xFF087A54):Colors.white,
  elevation:7,shadowColor:Colors.black12,
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(25),side:BorderSide(color:Theme.of(context).brightness==Brightness.dark?const Color(0xFF89E0BB):forest,width:1.2)),
  child:InkWell(
   onTap:WaffraHaptics.tap(onTap),
   borderRadius:BorderRadius.circular(25),
   child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
     Icon(icon,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest,size:21),
     const SizedBox(width:10),
     WaffraText(label,style:TextStyle(
      fontSize:15,fontWeight:FontWeight.bold,color:Theme.of(context).brightness==Brightness.dark?Colors.white:forest)),
    ]))));
 Widget _borderedMenuChoice({
  Key? key,required Widget title,Widget? subtitle,Widget? leading,
  required VoidCallback? onTap,
 })=>Padding(
  key:key,padding:const EdgeInsets.symmetric(vertical:5),
  child:Material(
   color:Theme.of(context).cardColor,
   shape:RoundedRectangleBorder(
    borderRadius:BorderRadius.circular(14),
    side:BorderSide(color:emerald.withValues(alpha:.35))),
   clipBehavior:Clip.antiAlias,
   child:ListTile(
    title:title,subtitle:subtitle,leading:leading,
    onTap:onTap,contentPadding:const EdgeInsets.symmetric(
     horizontal:12,vertical:7))));
 Future<void> _duplicateGoalFromMenu()async {
  if(goals.isEmpty)return;
  final chosen=await showWaffraDialog<SavingGoal>(
   context:context,builder:(dialogCtx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose a goal to duplicate':'اختر هدفًا لتكراره'),
    content:SizedBox(width:350,height:min(420,MediaQuery.sizeOf(dialogCtx).height*.55),
     child:ListView.builder(itemCount:goals.length,itemBuilder:(ctx,index){
      final item=goals[index];
      return _borderedMenuChoice(
       leading:const Icon(Icons.copy_all_outlined,color:emerald),
       title:WaffraText(item.name),
       subtitle:WaffraText(item.target<=0
        ?(waffraIsEnglish?'Open-ended savings':'ادخار مفتوح')
        :cash(item.target)),
       onTap:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,item)));
     })),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
   ));
  if(chosen!=null&&mounted)await goalDialog(duplicate:chosen);
 }
 Future<void> _duplicateRecurringFromMenu()async {
  if(recurring.isEmpty)return;
  // Existing linked goal bills are *not* re-linked to the original goal.
  // A duplicate always gets its own new ID and editable finance fields.
  final chosen=await showWaffraDialog<RecurringBill>(
   context:context,builder:(dialogCtx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose a recurring transaction':'اختر عملية متكررة لتكرارها'),
    content:SizedBox(width:350,height:min(420,MediaQuery.sizeOf(dialogCtx).height*.55),
     child:ListView.builder(itemCount:recurring.length,itemBuilder:(ctx,index){
      final item=recurring[index];
      return _borderedMenuChoice(
       leading:const Icon(Icons.copy_all_outlined,color:emerald),
       title:WaffraText(item.title),
       subtitle:WaffraText(cash(item.amount)),
       onTap:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx,item)));
     })),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
   ));
  if(chosen!=null&&mounted)await recurringDialog(duplicate:chosen);
 }
}
