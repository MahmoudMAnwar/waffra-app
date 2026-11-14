part of 'main.dart';

/// M750 / Issue #633: original source-verified Home finance startup reader.
/// Same-library refactor; no account, encrypted ledger or saved data edits.
extension _WaffraHomeFinanceStartup on _HomeScreenState {
 Future<void> load()async {
  final financeClock=kProfileMode?(Stopwatch()..start()):null;
  final startupEpoch=_m630HomeStartupEpoch;
  void traceHomeStep(String stage){
   if(financeClock==null)return;
   debugPrint('WAFFRA_HOME_LOAD_STEP $stage elapsed_ms='
    '${financeClock.elapsedMilliseconds}');
  }
  // M629: on cold Home, start the independent cheap preference read while
  // binding the verified SQLCipher source. Both must finish BEFORE Home can
  // consume user-specific settings or display any financial balance.
  traceHomeStep('before_sharedPreferences');
  final preferencesLoading=SharedPreferences.getInstance();
  traceHomeStep('before_ensureFinanceBound');
  await _ensureFinanceBound();
  traceHomeStep('after_ensureFinanceBound');
  final bindMs=financeClock?.elapsedMilliseconds;
  final p=await preferencesLoading;
  traceHomeStep('after_sharedPreferences');
  // An authenticated fresh SQLCipher vault is born with an empty snapshot.
  // Add only absent first-run ledger and category fields via the existing
  // atomic SQLCipher writer before displaying Home; never use legacy fallback.
  traceHomeStep('before_catalog_recovery');
  final loadedFinance=await WaffraFreshHomeCatalogRecovery.load(
   authority:_financeAuthority,
   defaultCategoriesJson:await WaffraPublicStartupPrewarm.categoriesJson(),
  );
  traceHomeStep('after_catalog_recovery');
  final verifiedSourceMs=financeClock?.elapsedMilliseconds;
  _lastFinanceAuthorityRead=loadedFinance;
  final financeView=loadedFinance.finance;
  financeView.requireIntegrity();
  final verifiedEncryptedStartup=
   loadedFinance.source==WaffraRuntimeFinanceBackend.verifiedEncrypted;
  if(verifiedEncryptedStartup&&
     financeView.getString('waffra_categories_v24')==null){
   throw StateError('Verified encrypted category source is incomplete.');
  }
  // M622: verified accounts can read while immutable source JSON decodes.
  // Legacy category migration must finish before its account projection.
  traceHomeStep('before_accounts_refresh');
  final Future<void>? accountsLoading=verifiedEncryptedStartup?
   _m467RefreshHomeAccounts():null;
  traceHomeStep('after_accounts_refresh_started');
  _lastWidgetRevision=loadedFinance.widgetRevision;
  _lastLedgerSavedRaw=loadedFinance.ledgerRaw;
  // M633: one batch-decode for immutable, integrity-verified finance JSON.
  // The verified accounts projection started above runs concurrently.
  traceHomeStep('before_batch_json_decode');
  final startupSources=<String,String>{};
  for(final field in <String>[
   'entries',
   'waffra_categories_v24',
   'waffra_named_budgets_v1',
   'waffra_goals_v24',
   'waffra_recurring_v24',
   'waffra_challenges_v1',
   'waffra_deleted_categories_v1',
   'waffra_deleted_goals_v1',
   'waffra_deleted_recurring_v1',
   'waffra_recurring_postponed_v1',
   'waffra_learned_merchants_v1',
  ]){
   final raw=financeView.getString(field);
   if(raw!=null)startupSources[field]=raw;
  }
  final decodedStartup=await WaffraLargeJsonDecode.parseStartupFields(
   startupSources);
  traceHomeStep('after_batch_json_decode');
  _m684InvalidatePeriodRead();
  try{final raw=financeView.getString('entries');if(raw!=null)entries.addAll(await _m593BuildVerifiedEntries((decodedStartup.read('entries')) as List));}catch(e){throw StateError('Saved transactions cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_categories_v24');categories.addAll(raw==null?defaultCategories():(decodedStartup.read('waffra_categories_v24') as List).map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved categories cannot be decoded safely: $e');}
  try{
   final raw=financeView.getString('waffra_named_budgets_v1');
   if(raw!=null)namedBudgets.addAll((decodedStartup.read('waffra_named_budgets_v1') as List).map(
    (x)=>WaffraNamedBudget.fromJson(Map<String,dynamic>.from(x))));
   for(final c in categories.where((c)=>!c.income&&c.budget>0)){
    if(!namedBudgets.any((b)=>b.id==c.id)){
     namedBudgets.add(WaffraNamedBudget.fromLegacy(c));
    }
   }
  }catch(e){throw StateError('Saved independent budgets are invalid: $e');}
  try{final raw=financeView.getString('waffra_goals_v24');if(raw!=null)goals.addAll((decodedStartup.read('waffra_goals_v24') as List).map((x)=>SavingGoal.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_v24');if(raw!=null)recurring.addAll((decodedStartup.read('waffra_recurring_v24') as List).map((x)=>RecurringBill.fromJson(Map<String,dynamic>.from(x))));}catch(e){throw StateError('Saved recurring finance cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_challenges_v1');if(raw!=null)challenges.addAll((decodedStartup.read('waffra_challenges_v1') as List).map((e)=>SavingChallenge.fromJson(Map<String,dynamic>.from(e))));}catch(e){throw StateError('Saved challenges cannot be decoded safely: $e');}
  try{
   final raw=financeView.getString('waffra_deleted_categories_v1');
   if(raw!=null)deletedCategories.addAll((decodedStartup.read('waffra_deleted_categories_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));
  }catch(e){throw StateError('Deleted categories cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_goals_v1');if(raw!=null)deletedGoals.addAll((decodedStartup.read('waffra_deleted_goals_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted goals cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_deleted_recurring_v1');if(raw!=null)deletedRecurring.addAll((decodedStartup.read('waffra_deleted_recurring_v1') as List).map((x)=>Map<String,dynamic>.from(x as Map)));}catch(e){throw StateError('Deleted recurring cannot be decoded safely: $e');}
  try{final raw=financeView.getString('waffra_recurring_postponed_v1');if(raw!=null)recurringPostponed.addAll((decodedStartup.read('waffra_recurring_postponed_v1') as Map).map((k,v)=>MapEntry(k.toString(),v.toString())));}catch(e){throw StateError('Recurring postponements cannot be decoded safely: $e');}
  // The user's device clock cannot purge or hide encrypted SQL tombstones.
  // Deletion/expiry requires independently verified encrypted retention.
  final trashBefore=deletedCategories.length;
  if(!verifiedEncryptedStartup){
   deletedGoals.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
   deletedRecurring.removeWhere((item){final date=DateTime.tryParse('${item['deletedAt']??''}');return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));});
   deletedCategories.removeWhere((item){
    final when=DateTime.tryParse('${item['deletedAt']??''}');
    return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
   });
  }
  // Install catalog once without overwriting custom categories, saved budgets or trash.
  if(!verifiedEncryptedStartup&&
      !(p.getBool('waffra_category_catalog_v2_installed')??false)){
   final discarded=<String>{};
   for(final item in deletedCategories){
    final data=item['category'];
    if(data is Map){
     discarded.add('${data['income']==true}|${data['name']}');
     discarded.add('id|${data['id']}');
    }
   }
   for(final suggestion in defaultCategories()){
    if(discarded.contains('${suggestion.income}|${suggestion.name}')||
       discarded.contains('id|${suggestion.id}'))continue;
    if(categories.any((existing)=>existing.id==suggestion.id||
      (existing.income==suggestion.income&&existing.name==suggestion.name)))continue;
    categories.add(suggestion);
   }
   final committed=await _financeAuthority.installCategoryCatalog(
    version:2,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:true,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  // Incremental catalog update: retain existing user budgets, names and deletions.
  // A subcategory is only added when its main category is present.
  if(!verifiedEncryptedStartup&&
      !(p.getBool('waffra_category_catalog_v3_installed')??false)){
   final deletedIds=<String>{};
   final deletedNames=<String>{};
   for(final record in deletedCategories){
    final raw=record['category'];
    if(raw is Map){
     deletedIds.add('${raw['id']}');
     deletedNames.add('${raw['income']==true}|${raw['name']}');
    }
   }
   var catalogChanged=false;
   for(final suggestion in defaultCategories()){
    if(deletedIds.contains(suggestion.id)||
     deletedNames.contains('${suggestion.income}|${suggestion.name}'))continue;
    if(categories.any((c)=>c.id==suggestion.id||
     (c.income==suggestion.income&&c.name==suggestion.name)))continue;
    if(suggestion.isSubcategory&&
     !categories.any((c)=>c.id==suggestion.parentId))continue;
    categories.add(suggestion);
    catalogChanged=true;
   }
   final committed=await _financeAuthority.installCategoryCatalog(
    version:3,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:catalogChanged,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  // Catalog v4 installs only new leaves, preserving user budgets and trash.
  if(!verifiedEncryptedStartup&&
     !(p.getBool('waffra_category_catalog_v4_installed')??false)){
   final removedIds=<String>{},removedNames=<String>{};
   for(final record in deletedCategories){
    final data=record['category'];
    if(data is Map){
     removedIds.add('${data['id']}');
     removedNames.add('${data['income']==true}|${data['name']}');
    }
   }
   var changed=false;
   for(final suggestion in defaultCategories()){
    if(removedIds.contains(suggestion.id)||
       removedNames.contains('${suggestion.income}|${suggestion.name}'))continue;
    if(categories.any((c)=>c.id==suggestion.id||
      (c.income==suggestion.income&&c.name==suggestion.name)))continue;
    if(suggestion.isSubcategory&&!categories.any(
       (c)=>c.id==suggestion.parentId&&!c.isSubcategory))continue;
    categories.add(suggestion);changed=true;
   }
   final committed=await _financeAuthority.installCategoryCatalog(
    version:4,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:changed,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
    // Catalog v5 installs only new leaves, preserving user budgets and trash.
  if(!verifiedEncryptedStartup&&
     !(p.getBool('waffra_category_catalog_v5_installed')??false)){
   final removedIds=<String>{},removedNames=<String>{};
   for(final record in deletedCategories){
    final data=record['category'];
    if(data is Map){
     removedIds.add('${data['id']}');
     removedNames.add('${data['income']==true}|${data['name']}');
    }
   }
   var changed=false;
   for(final suggestion in defaultCategories()){
    if(removedIds.contains(suggestion.id)||
       removedNames.contains('${suggestion.income}|${suggestion.name}'))continue;
    if(categories.any((c)=>c.id==suggestion.id||
      (c.income==suggestion.income&&c.name==suggestion.name)))continue;
    if(suggestion.isSubcategory&&!categories.any(
       (c)=>c.id==suggestion.parentId&&!c.isSubcategory))continue;
    categories.add(suggestion);changed=true;
   }
   final committed=await _financeAuthority.installCategoryCatalog(
    version:5,
    expectedCatalogRaw:_lastFinanceAuthorityRead?.finance.getString('waffra_categories_v24'),
    nextCatalogRaw:jsonEncode(categories.map((e)=>e.toJson()).toList()),
    catalogChanged:changed,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }
  smsHashes.addAll(financeView.getStringList('waffra_sms_hashes_v1')??const []);
  monthlyBudget=financeView.getDouble('waffra_monthly_budget_v1')??0;
  monthlyBudgetEnabled=financeView.getBool('waffra_monthly_budget_enabled_v1')??(monthlyBudget>0);
  recurringRemindersEnabled=financeView.getBool('waffra_recurring_reminders_enabled_v1')??false;
  lastBackupGeneratedAt=p.getString('waffra_backup_last_exported_v1');
  lastBackupBytes=p.getInt('waffra_backup_last_size_v1');
  protectRecentApps=p.getBool('waffra_protect_recents_v1')??true;
  try{
   final rawRules=financeView.getString('waffra_learned_merchants_v1');
   if(rawRules!=null){
    final data=decodedStartup.read('waffra_learned_merchants_v1');
    if(data is Map){
     learnedMerchantCategories.addAll(data.map((key,value)=>MapEntry(key.toString(),value.toString())));
    }
   }
  }catch(e){throw StateError('Learned merchant rules cannot be decoded safely: $e');}
  if(!verifiedEncryptedStartup&&categories.isEmpty){
   categories.addAll(defaultCategories());
  }
  // Archived categories may still be referenced by historic entries.
  // Never synthesize phantom active categories in SQLCipher.
  if(!verifiedEncryptedStartup)for(final e in entries){
   if(!categories.any((c)=>c.name==e.category&&c.income==e.income)){
    categories.add(BudgetCategory(id:newId(),name:e.category,icon:'category',color:colors[7],income:e.income));
   }
  }
  // Category display no longer shows caps. Keep the original category rows
  // intact until the user-confirmed atomic migration commits BOTH collections.
  if(!mounted)return;
  if(kProfileMode&&financeClock!=null){
   // Timings only. Never log private finance content or account identity.
   debugPrint('WAFFRA_FINANCE_PERF bind_ms=${bindMs??-1} '
    'verified_catalog_ms=${verifiedSourceMs??-1} '
    'decoded_ready_ms=${financeClock.elapsedMilliseconds}');
  }
   // Previously Home painted transaction sums and only afterwards loaded
   // verified bank account balances. Never flash a provisional amount.
   traceHomeStep('before_accounts_await');
   try{
    await (accountsLoading??_m467RefreshHomeAccounts())
     .timeout(const Duration(seconds:15));
   }on TimeoutException{
    traceHomeStep('accounts_timeout');
    // timeout() does not cancel the underlying SQL task: reject late state.
    _m627AccountEpoch++;
    _m468AccountReadInFlight=null;
    _m468AccountReadAgain=false;
    rethrow;
   }
   traceHomeStep('after_accounts_await');
   if(!mounted||_m627ClosingSession)return;
   if(!_m468VerifiedAccountsLoaded){
    throw StateError('Verified financial account balances are unavailable.');
   }
   setState(()=>ready=true);
   // M486 #419: let Home's first interactive frame paint before competing
   // asynchronous widget reads and incoming SMS callbacks begin.
   WidgetsBinding.instance.addPostFrameCallback((_){
    unawaited(()async{
     // First-install preload is intentionally hidden during consent+biometric.
     if(!await _m663AwaitVisible(startupEpoch)||
        !_m630SmsSessionCurrent(startupEpoch))return;
     // Load returns before the retained biometric/login stage is dismissed.
     // Let its FIRST genuinely verified Home frame render before optional I/O.
     await Future<void>.delayed(const Duration(milliseconds:400));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     // M630: these happen after the verified Home frame, not during paint.
     _m621OnFinanceNoticeTap();
     _receiveSharedSms();
     _receiveWidgetAction();
     // Track ALL optional finance operations so signout cannot close the
     // verified SQLCipher source beneath an in-flight widget/recurring read.
     // They remain after Home render, and never post SMS automatically.
     final postFrameFinance=()async{
      try{
       await _refreshWidget();
       if(!_m630SmsSessionCurrent(startupEpoch))return;
       if(!verifiedEncryptedStartup)await applyRecurring();
       if(!_m630SmsSessionCurrent(startupEpoch))return;
       if(recurringRemindersEnabled)await syncRecurringReminders();
      }catch(error){
       debugPrint('Post-frame optional finance: ${error.runtimeType}');
      }
     }();
     _m630PostFrameFinanceWork=postFrameFinance;
     unawaited(()async{
      await postFrameFinance;
      if(identical(_m630PostFrameFinanceWork,postFrameFinance)){
       _m630PostFrameFinanceWork=null;
      }
     }());
    }());
   });
  // An explicit Google onboarding notification consent may be pending;
  // enable reminder scheduling only through the verified finance authority.
  // No reminder OS permission at startup; wait for explicit recurring toggle.
  if(!verifiedEncryptedStartup&&trashBefore!=deletedCategories.length){
   await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  }
 }
}
