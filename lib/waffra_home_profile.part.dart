part of 'main.dart';

// M687: exact original profile method in the same library.
extension _WaffraHomeProfileModule on _HomeScreenState {
 Widget profilePage(){
  final p=widget.profile;
  final provider=p.provider.toLowerCase().trim();
  final isGuest=(provider=='محلي'||provider=='local'||provider=='guest')&&
   p.email.trim().isEmpty&&p.phone.trim().isEmpty;
  void edit(){Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>ProfileForm(provider:p.provider,initial:p,onSave:widget.onProfile)));}
  return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'My account':'حسابي',
    subtitle:waffraIsEnglish?'Your profile, preferences and security':
     'بياناتك وإعداداتك وخصوصيتك في مكان واحد.',
    icon:Icons.person_outline_rounded),
   Container(padding:const EdgeInsets.fromLTRB(16,17,16,17),
    decoration:BoxDecoration(
     color:Theme.of(context).cardColor,
     borderRadius:BorderRadius.circular(22),
     border:Border.all(color:Theme.of(context).brightness==Brightness.dark?
      const Color(0xFF375C4A):const Color(0xFFDCEBE2))),
    child:Column(children:[
     InkWell(onTap:WaffraHaptics.tap(edit),child:Stack(alignment:Alignment.bottomRight,children:[
      waffraAvatar(p.gender,p.avatar,radius:42),
      const CircleAvatar(radius:14,backgroundColor:forest,
       child:Icon(Icons.camera_alt,size:16,color:Colors.white)),
     ])),
     const SizedBox(height:12),
     WaffraText(p.name.trim().isEmpty?(waffraIsEnglish?'My account':'حسابي'):p.name,
      textAlign:TextAlign.center,
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     if(p.email.trim().isNotEmpty)...[
      const SizedBox(height:5),
      WaffraText(p.email,textAlign:TextAlign.center),
     ],
     const SizedBox(height:15),
   OutlinedButton.icon(onPressed:WaffraHaptics.tap(edit),icon:const Icon(Icons.edit_outlined),
    label:WaffraText(waffraIsEnglish?'Edit profile':'تعديل حسابي')),
    ])),
   const SizedBox(height:13),
   if(provider=='google'||provider=='apple')...[
    Card(child:Padding(padding:const EdgeInsets.all(13),
     child:Column(children:[
      WaffraText(waffraIsEnglish?
       'Keep your data and switch to mobile + password':
       'احتفظ ببياناتك وانقل الدخول إلى الجوال وكلمة المرور'),
      const SizedBox(height:10),
      FilledButton.icon(
       onPressed:WaffraHaptics.tap(()async{
        await Navigator.push<void>(context,MaterialPageRoute(
         builder:(_)=>WaffraLocalAccountMigration(
          english:waffraIsEnglish,
          onConfirm:(number,password)async{
           // Complete local migration without changing Firebase UID,
           // historical finance, backups or any encrypted receipt.
           final already=await WaffraLocalPhoneCredentials.verify(
            phone:number,password:password);
           if(!already){
            await WaffraLocalPhoneCredentials.register(
             phone:number,password:password);
           }
           await widget.onProfile(Person(
            name:p.name,email:p.email,phone:number,provider:'Phone',
            gender:p.gender,avatar:p.avatar,birthday:p.birthday));
          },
         )));
       }),
       icon:const Icon(Icons.phonelink_lock),
       label:WaffraText(waffraIsEnglish?
        'Migrate local login':'نقل تسجيل الدخول للجوال')),
     ]))),
    const SizedBox(height:13),
   ],
   TextField(key:const Key('waffra-account-settings-search'),onChanged:(value){
    final q=value.trim();
    final groups=<String,String>{
     waffraIsEnglish?'App settings':'إعدادات التطبيق':'language theme appearance system dark light currency exchange بلد دولة عملة جنيه مصري مصر SAR EGP المظهر اللغة الحركة animation',
     waffraIsEnglish?'Security & privacy':'الأمان والخصوصية':'privacy biometric fingerprint حماية بصمة قفل إخفاء PIN screenshots المعاينة',
     waffraIsEnglish?'Bank SMS':'رسائل SMS البنكية':'SMS bank banking الرسائل البنكية السابقة القديمة فحص رسائل غير معروفة إشعارات مديونية اعتماد',
     waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات':'backup restore delete نسخ احتياطي استعادة حذف بيانات',
     waffraIsEnglish?'Financial tools':'الأدوات المالية':'calendar subscriptions currency tools التقويم الاشتراكات الأدوات المالية',
     waffraIsEnglish?'Help & about':'المساعدة وعن وفرة':'tour help about وفرة الجولة المساعدة',
    };
    String? match;
    if(q.isNotEmpty){for(final item in groups.entries){if(waffraSearchAny([item.key,item.value],q)){match=item.key;break;}}}
    setState((){accountSearch=q;_accountOpenSection=match;});
   },decoration:InputDecoration(prefixIcon:const Icon(Icons.search,color:emerald),
    hintText:waffraIsEnglish?'Find a setting':'ابحث داخل إعدادات حسابي')),
   const SizedBox(height:12),
   _accountSection(waffraIsEnglish?'App settings':'إعدادات التطبيق',Icons.settings_outlined,[
    if(WaffraSaudiRelease.userCurrencyChoice)ListTile(
     key:const Key('waffra-app-base-currency-setting'),
     leading:const CircleAvatar(child:Icon(Icons.public_rounded,color:emerald)),
     title:WaffraText(waffraIsEnglish?'App currency by country':'عملة التطبيق حسب الدولة'),
     subtitle:WaffraText(WaffraDisplayCurrency.country.label(waffraIsEnglish)),
     trailing:const Icon(Icons.search_rounded),
     onTap:WaffraHaptics.tap(chooseAppCurrency)),

    ListTile(
     leading:const CircleAvatar(child:Icon(Icons.auto_awesome_outlined,color:emerald)),
     title:WaffraText(waffraIsEnglish?'Animations & effects':'الحركة والتأثيرات',style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:WaffraText(waffraIsEnglish?'Choose motion intensity':'اختر مستوى الحركة في التطبيق'),
     trailing:DropdownButton<String>(value:waffraAnimationLevel.value,underline:const SizedBox.shrink(),
      onChanged:WaffraHaptics.selection((v){if(v!=null)setAnimationLevel(v);}),items:[
       DropdownMenuItem(value:'full',child:WaffraText(waffraIsEnglish?'Full':'كاملة')),
       DropdownMenuItem(value:'balanced',child:WaffraText(waffraIsEnglish?'Balanced':'متوازنة')),
       DropdownMenuItem(value:'reduced',child:WaffraText(waffraIsEnglish?'Reduced':'خفيفة')),
       DropdownMenuItem(value:'off',child:WaffraText(waffraIsEnglish?'Off':'بدون حركة')),
      ])),
    _accountTile(waffraIsEnglish?'App language':'لغة التطبيق',
     waffraIsEnglish?'English':'العربية',Icons.language,
     trailing:SegmentedButton<String>(segments:const [
      ButtonSegment(value:'ar',label:Text('AR')),ButtonSegment(value:'en',label:Text('EN')),
     ],selected:{waffraLanguage.value},showSelectedIcon:false,
     onSelectionChanged:WaffraHaptics.selection((v)async{setState(()=>tab=0);await widget.onLanguage(v.first);}))),
    if(WaffraSaudiRelease.userCountryChoice)ListTile(
     key:const Key('waffra-regional-arabic-setting'),
     leading:const Icon(Icons.public_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Country / Arabic wording':'البلد واللهجة العربية'),
     subtitle:WaffraText(waffraIsEnglish?
      'Country only changes Arabic wording, not your app language or currency.':
      'اختيار البلد يحدد اللهجة العربية فقط، ولا يغيّر لغة التطبيق أو عملته.'),
     trailing:SizedBox(width:145,child:DropdownButton<String>(
      key:const Key('waffra-region-choice'),
      value:WaffraRegionalCopy.countryIso.value,isExpanded:true,
      underline:const SizedBox.shrink(),
      items:WaffraRegionalCopy.supportedRegions.entries.map((item)=>
       DropdownMenuItem<String>(value:item.key,
        child:Text(WaffraRegionalCopy.regionLabel(
          item.key,english:waffraIsEnglish),
          maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
      onChanged:WaffraHaptics.selection((v)async{
       if(v==null)return;
       try{
        await WaffraRegionalCopy.setCountry(v);
        if(mounted)setState((){});
       }catch(_){
        if(mounted)snack(context,waffraIsEnglish?
          'Could not save country preference. Please retry.':
          'ما قدرنا نحفظ اختيار البلد. جرّب مرة ثانية.');
       }
      }),
     )),
    ),
    ListTile(leading:const Icon(Icons.palette_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Appearance':'المظهر'),
     subtitle:WaffraText(widget.appearance=='system'?(waffraIsEnglish?'System default':'حسب إعدادات الجهاز'):
      widget.appearance=='dark'?(waffraIsEnglish?'Dark':'داكن'):(waffraIsEnglish?'Light':'فاتح')),
     trailing:DropdownButton<String>(value:widget.appearance,underline:const SizedBox.shrink(),
      onChanged:WaffraHaptics.selection((value){if(value!=null)widget.onAppearance(value);}),
      items:[
       DropdownMenuItem(value:'system',child:WaffraText(waffraIsEnglish?'System default':'حسب الجهاز')),
       DropdownMenuItem(value:'light',child:WaffraText(waffraIsEnglish?'Light':'فاتح')),
       DropdownMenuItem(value:'dark',child:WaffraText(waffraIsEnglish?'Dark':'داكن')),
      ])),
   ]),
   if(Platform.isAndroid)_accountSection(
    waffraIsEnglish?'Bank SMS':'رسائل SMS البنكية',
    Icons.sms_outlined,[
    _accountTile(
     waffraIsEnglish?'Classification rules':'قواعد تحليل الرسائل',
     waffraIsEnglish?
      'Built-in income/expense rules and custom keyword rules.':
      'قواعد جاهزة للدخل والمصروف وإضافة قواعد بكلمات مفتاحية.',
     Icons.rule_rounded,
     onTap:()=>unawaited(_openSmsRules())),
    _accountTile(
     waffraIsEnglish?'Excluded senders':'المستبعدون',
     waffraIsEnglish?
      'Manage blocked SMS senders and restore them.':
      'إدارة المرسلين المستبعدين وإلغاء الاستبعاد عند الحاجة.',
     Icons.block_rounded,
     onTap:()=>unawaited(_openExcludedSenders())),
    _accountTile(
     waffraIsEnglish?'Scan previous SMS':'فحص رسائل SMS السابقة',
     waffraIsEnglish?
      'Review bank SMS from the first day of the month Waffra was installed.':
      'فحص الرسائل من أول يوم في شهر تثبيت وفرة وحتى الآن.',
     Icons.history_rounded,
     onTap:()=>unawaited(_scanPreviousBankSmsFromSettings())),
    _accountTile(
     waffraIsEnglish?'Unrecognized SMS':'رسائل SMS غير معروفة',
     waffraIsEnglish?
      'Read financial notices that could not be verified as transactions.':
      'عرض الإشعارات المالية التي لم تتأكد كمعاملات.',
     Icons.help_outline_rounded,
     onTap:()=>unawaited(_openUnknownSmsFromSettings())),
   ]),
   _accountSection(waffraIsEnglish?'Security & privacy':'الأمان والخصوصية',Icons.shield_outlined,[
    if(Platform.isAndroid)FutureBuilder<bool>(
     future:_m528SmsEnabled(),builder:(context,snapshot)=>SwitchListTile(
      secondary:const Icon(Icons.sms_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'Automatic bank SMS tracking':'تسجيل الرسائل البنكية تلقائيًا'),
      subtitle:WaffraText(waffraIsEnglish?
       'Save verified SMS transactions and notify you; uncertain messages need review.':
       'تسجيل العمليات المؤكدة وإشعارك بعد الحفظ؛ الرسائل التي تحتاج مراجعة لا تُسجَّل تلقائيًا.'),
      value:snapshot.data==true,
      onChanged:WaffraHaptics.selection((enabled)async{
       if(enabled){
        await Navigator.push<void>(context,MaterialPageRoute(
         builder:(_)=>WaffraAutoSmsConsentPage(
          english:waffraIsEnglish,
          onComplete:()async{if(context.mounted)Navigator.pop(context);},
         )));
       }else{
        await WaffraAutoSms.disable();
       }
       if(mounted)setState((){
        _m528SmsEnabledFuture=WaffraAutoSms.enabled();
       });
      }),
     )),
    if(Platform.isAndroid)FutureBuilder<bool>(
     future:_m528CloudConsent(),
     builder:(context,snapshot)=>SwitchListTile(
      secondary:const Icon(Icons.cloud_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'AI analysis of bank SMS (cloud)':'تحليل الرسائل البنكية بالذكاء الاصطناعي السحابي'),
      subtitle:WaffraText(waffraIsEnglish?
       'Optional. Sends redacted financial SMS to a third-party AI provider.':
       'اختياري. يرسل النص المالي بعد حجب المعرفات لخدمة ذكاء اصطناعي خارجية.'),
      value:snapshot.data==true,
      onChanged:WaffraHaptics.selection((enabled)async{
       if(enabled){
        final accepted=await showWaffraDialog<bool>(context:context,
         builder:(dialog)=>AlertDialog(
          title:WaffraText(waffraIsEnglish?
           'Enable cloud bank SMS analysis?':'تفعيل تحليل الرسائل البنكية السحابي؟'),
          content:WaffraText(waffraIsEnglish?
           'Bank SMS that match financial activity will be redacted locally, then processed by a third-party model through OpenRouter. Some processing may take place outside Saudi Arabia. This is separate from permission to read SMS. You can decline and keep local analysis.':
           'سيتم حجب المعرفات الشخصية من الرسائل البنكية المطابقة محليًا، ثم إرسال البيانات المالية لخدمة ذكاء اصطناعي خارجية عبر OpenRouter. قد تتم المعالجة خارج السعودية. هذه موافقة منفصلة عن صلاحية قراءة الرسائل، ويمكنك رفضها والاستمرار بالتحليل المحلي.'),
          actions:[
           TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
           FilledButton(onPressed:()=>Navigator.pop(dialog,true),
            child:WaffraText(waffraIsEnglish?'I agree':'أوافق')),
          ]));
        if(accepted!=true)return;
       }
       final completed=await WaffraSmsCloudService.setConsent(enabled);
       if(!completed&&mounted){
        snack(context,waffraIsEnglish?
         'Cloud analysis or App Check is unavailable. No SMS was uploaded.':
         'التحليل السحابي أو حماية التطبيق غير متاحة. لم يتم رفع أي رسالة.',
         isError:true);
       }
       if(mounted)setState((){
        _m528CloudConsentFuture=WaffraSmsCloudService.hasConsent();
       });
      }),
     )),
    // Mandatory biometrics: optional PIN settings removed.
    SwitchListTile(secondary:const Icon(Icons.preview_outlined,color:emerald),
     title:WaffraText(waffraIsEnglish?'Protect Recent Apps preview':'حماية معاينة التطبيقات الأخيرة'),
     value:protectRecentApps,onChanged:WaffraHaptics.selection(_setRecentAppProtection)),
    ValueListenableBuilder<bool>(valueListenable:allowWaffraScreenshots,
     builder:(context,allowed,_)=>SwitchListTile(
      secondary:const Icon(Icons.screenshot_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Allow screenshots':'السماح بلقطات الشاشة'),
      subtitle:WaffraText(allowed?(waffraIsEnglish?'Allowed':'مسموح'):(waffraIsEnglish?'Blocked':'ممنوع')),
      value:allowed,onChanged:WaffraHaptics.selection((v)async{await setWaffraScreenshotsAllowed(v);if(mounted)setState((){});}))),
     ValueListenableBuilder<bool>(
      valueListenable:WaffraCrashlyticsOptIn.consent,
      builder:(context,allowed,_)=>SwitchListTile(
       secondary:const Icon(Icons.bug_report_outlined,color:emerald),
       title:WaffraText(waffraIsEnglish?'Share anonymous crash diagnostics':'مشاركة بيانات الأعطال'),
       subtitle:WaffraText(!waffraCrashlyticsReviewed
        ?(waffraIsEnglish?'Available after privacy and release verification':'ستتوفر بعد التحقق من الأمان والخصوصية')
        :(waffraIsEnglish?'Optional and disabled until you agree':'اختياري ولن يعمل إلا بموافقتك')),
       value:allowed&&waffraCrashlyticsReviewed,
       onChanged:WaffraHaptics.selection(waffraCrashlyticsReviewed?(v)async{
        await WaffraCrashlyticsOptIn.setConsent(v);
       }:null))),
   ]),
   _accountSection(waffraIsEnglish?'Financial tools':'الأدوات المالية',Icons.account_balance_wallet_outlined,[
    _accountTile(waffraIsEnglish?'My money accounts':'حساباتي',
      waffraIsEnglish?'Cash, bank accounts and internal transfers':'النقد والحسابات البنكية والتحويلات الداخلية',
      Icons.account_balance_outlined,onTap:WaffraHaptics.tap(openVerifiedAccounts)),
    _accountTile(waffraIsEnglish?'Financial calendar':'التقويم المالي',
     waffraIsEnglish?'Transactions and recurring dates':'المعاملات ومواعيد العمليات المتكررة',
     Icons.calendar_month_outlined,onTap:WaffraHaptics.tap(openFinancialCalendar)),
    _accountTile(waffraIsEnglish?'Subscription insights':'كشف الاشتراكات',
     waffraIsEnglish?'Recurring costs and possible subscriptions':'المدفوعات الدورية والاشتراكات المحتملة',
     Icons.subscriptions_outlined,onTap:WaffraHaptics.tap(openSubscriptionInsights)),
   ]),
   _accountSection(waffraIsEnglish?'Backup & data':'النسخ الاحتياطي والبيانات',Icons.cloud_outlined,[
    _accountTile(waffraIsEnglish?'Encrypted backup & restore':'النسخ الاحتياطي المشفر والاستعادة',
     lastBackupGeneratedAt==null?(waffraIsEnglish?'No encrypted backup generated yet':'لم يتم إنشاء نسخة مشفرة بعد'):
      (waffraIsEnglish?'Last encrypted copy: ':'آخر نسخة مشفرة: ')+dayText(DateTime.tryParse(lastBackupGeneratedAt!)?.toLocal()??DateTime.now())+
       ' • ${((lastBackupBytes??0)/1024).toStringAsFixed(1)} KB',
     Icons.backup_outlined,onTap:WaffraHaptics.tap(backupDialog)),
    _accountTile(waffraIsEnglish?'Delete financial data':'حذف البيانات المالية',
     waffraIsEnglish?'Fingerprint verification and final confirmation required':'يتطلب البصمة وتأكيد الحذف النهائي',
     Icons.delete_forever,tint:Colors.red,onTap:WaffraHaptics.tap(eraseFinancialData)),
    _accountTile(waffraIsEnglish?'Delete account & cloud data':'حذف الحساب وبيانات السحابة',
     waffraAccountDeletionReleased
      ?(waffraIsEnglish?'Fresh Google verification required':'يتطلب إعادة التحقق من Google')
      :(waffraIsEnglish?'Available after deletion verification':'متاح بعد اجتياز اختبارات الحذف الآمن'),
     Icons.person_remove_outlined,tint:Colors.red,
     onTap:WaffraHaptics.tap(()=>Navigator.push<void>(context,MaterialPageRoute(
      builder:(_)=>WaffraAccountDeletionPage(
       english:waffraIsEnglish,onAccountDeleted:widget.onLogout))))),
   ]),
   _accountSection(waffraIsEnglish?'Help & about':'المساعدة وعن وفرة',Icons.help_outline_rounded,[
    _accountTile(waffraIsEnglish?'About Waffra':'عن وفرة',
     waffraIsEnglish?'On-device financial management':'إدارة مالية تحفظ بياناتك محليًا',
     Icons.info_outline,onTap:WaffraHaptics.tap(()=>showAboutDialog(context:context,applicationName:'وفرة | Waffra',
      children:[WaffraText(waffraIsEnglish?'No bank account integration. Your data stays on your device.':
       'لا يوجد ربط بالحسابات البنكية؛ بياناتك محفوظة على جهازك.')])))
   ]),
   const SizedBox(height:15),
   OutlinedButton.icon(style:OutlinedButton.styleFrom(
    foregroundColor:(isGuest)?emerald:Colors.red,
    side:BorderSide(color:(isGuest)?emerald:Colors.red)),
    onPressed:WaffraHaptics.tap(()async{
     if(isGuest){await widget.onLogout();return;}
     // One ordinary confirmation: no password or biometric repair wizard.
     final ok=await showWaffraDialog<bool>(
      context:context,barrierDismissible:false,builder:(dialogCtx)=>
       AlertDialog(
        key:const Key('m513-home-signout-confirmation'),
        title:WaffraText(waffraIsEnglish?
         'Are you sure you want to sign out?':
         'هل أنت متأكد من تسجيل الخروج؟'),
        actions:[
         TextButton(
          key:const Key('m513-home-signout-no'),
          onPressed:()=>Navigator.pop(dialogCtx,false),
          child:WaffraText(waffraIsEnglish?'No':'لا')),
         FilledButton(
          key:const Key('m513-home-signout-yes'),
          onPressed:()=>Navigator.pop(dialogCtx,true),
          child:WaffraText(waffraIsEnglish?'Yes':'نعم')),
        ]));
     if(ok==true&&mounted)await widget.onLogout();
    }),
    icon:Icon((isGuest)?Icons.login:Icons.logout),
    label:WaffraText((isGuest)?
     (waffraIsEnglish?'Sign in':'تسجيل الدخول'):(waffraIsEnglish?'Sign out':'تسجيل الخروج'))),
   const SizedBox(height:13),
   WaffraText(waffraIsEnglish?
    'Your data stays on this device. Make a backup before changing phones or deleting the app.':
    'بياناتك محفوظة على جهازك. احفظ نسخة احتياطية قبل تغيير الجوال أو حذف التطبيق. ما فيه ربط بالحسابات البنكية.',
    textAlign:TextAlign.center,style:const TextStyle(fontSize:11)),
   const SizedBox(height:20),
  ]);
 }
}
