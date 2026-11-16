part of 'main.dart';

/// M944 / #653: source-preserving Home root shell extraction.
/// Owner-verified balance, session gate, footer, fixed + and Snackbar live in
/// the same Dart library; only their widget tree is now separated from State.
/// Never navigate to a different finance source from a presentation build.
extension _WaffraHomeRootShell on _HomeScreenState {
 // M1003: nonfinancial recovery frame for a Home revealed while its
 // authenticated finance source is briefly not ready. No fake balance.
 // M1006: a restore modal blurs and darkens what is behind it. A forest
 // background looked almost black while SQLCipher was reloading Home.
 // Paint a full bright, protected (non-financial) surface instead of any
 // blank/dark frame. Never expose pre-restore balances during verification.
 Widget _m1003FinanceHandoffSurface()=>Scaffold(
  key:const Key('m1006-protected-finance-reload-surface'),
  backgroundColor:const Color(0xFFF8F6EF),
  body:SafeArea(child:Center(child:Padding(
   padding:const EdgeInsets.symmetric(horizontal:24),
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.shield_outlined,color:emerald,size:48),
    const SizedBox(height:16),
    WaffraText(waffraIsEnglish?
     'Verifying encrypted financial data':
     'جارٍ التحقق من البيانات المالية المشفرة',
     textAlign:TextAlign.center,
     style:const TextStyle(color:forest,fontWeight:FontWeight.w600)),
    const SizedBox(height:18),
    const SizedBox(width:28,height:28,
     child:CircularProgressIndicator(strokeWidth:2.5,color:emerald)),
   ])))));
 Widget _m944BuildHome()=>PopScope(
  // Let the root back policy route account/tabs before double-back exit.
  canPop:true,
  child:!ready&&_financeLoadFailure==null?
   (widget.postAuthVisible?
    WaffraFinanceReloadingView(english:waffraIsEnglish):
    _m1003FinanceHandoffSurface()):Stack(children:[Scaffold(
  appBar:AppBar(
   toolbarHeight:_headerCompact?52:64,
   flexibleSpace:const ColoredBox(color:forest),
   leading:accountOpened?IconButton(
    key:const Key('waffra-account-header-back'),
    tooltip:waffraIsEnglish?'Back to home':'العودة للرئيسية',
    icon:const Icon(Icons.arrow_back_rounded),
    onPressed:WaffraHaptics.tap(_consumeHomeBack)):
    goalsOpened?IconButton(tooltip:waffraIsEnglish?'Back to home':'العودة للرئيسية',
    icon:const Icon(Icons.arrow_back),onPressed:WaffraHaptics.tap(()=>setState(()=>goalsOpened=false))):null,
   titleSpacing:12,
   title:Row(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.spa_rounded,color:Colors.white,size:26),
    const SizedBox(width:7),
    Flexible(child:WaffraText(waffraIsEnglish?'Waffra':'وفرة',
     maxLines:1,style:TextStyle(color:Colors.white,
      fontWeight:FontWeight.bold,fontSize:_headerCompact?19:22))),
   ]),
   actions:[
    Tooltip(message:waffraIsEnglish?'Switch to Arabic':'Switch to English',
     child:TextButton(
      onPressed:WaffraHaptics.tap((){
       if(addFabExpanded||_fabPressed)setState((){addFabExpanded=false;_fabPressed=false;});
       widget.onLanguage(waffraIsEnglish?'ar':'en');
      }),
      style:TextButton.styleFrom(
       foregroundColor:Colors.white,minimumSize:const Size(43,37),
       padding:const EdgeInsets.symmetric(horizontal:8),
       backgroundColor:Colors.white.withValues(alpha:.11),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
      child:Text(waffraIsEnglish?'AR':'EN',
       style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))),
    const SizedBox(width:7),
    Tooltip(message:waffraIsEnglish?'Notifications':'الإشعارات',
     child:Semantics(
      button:true,label:waffraIsEnglish?'Open financial notifications':'فتح الإشعارات المالية',
      child:InkWell(
       key:const Key('m549-header-notification-bell'),
       borderRadius:BorderRadius.circular(22),
       onTap:WaffraHaptics.tap(()=>unawaited(_m549OpenNotifications())),
       child:SizedBox(width:48,height:45,child:Stack(
        clipBehavior:Clip.none,children:[
        const Center(child:Icon(Icons.notifications_none_rounded,color:Colors.white,size:27)),
        if(_autoSmsPending.isNotEmpty)PositionedDirectional(
         end:0,top:0,child:Container(
          key:const Key('m549-notification-count-badge'),
          constraints:const BoxConstraints(minWidth:21,minHeight:17),
          padding:const EdgeInsets.symmetric(horizontal:3),
          decoration:BoxDecoration(color:const Color(0xFFE22F37),
           borderRadius:BorderRadius.circular(12)),
          child:Center(child:Text(
           _autoSmsPending.length>999?'+999':_autoSmsPending.length.toString(),
           style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold))),
         )),
       ]))))),
    const SizedBox(width:7),
    Tooltip(message:waffraIsEnglish?'My account and settings':'حسابي والإعدادات',
     child:Semantics(label:waffraIsEnglish?'Open account settings':'فتح إعدادات الحساب',
      button:true,child:InkWell(
       key:const Key('waffra-header-account-entry'),
       onTap:WaffraHaptics.tap(()=>setState((){
        // Device settings might have changed since the previous visit.
        _m528SmsEnabledFuture=null;
        addFabExpanded=false;goalsOpened=false;accountOpened=true;_headerCompact=false;
       })),
       borderRadius:BorderRadius.circular(30),
       child:AnimatedContainer(duration:waffraMotion(260),
        curve:Curves.easeOutCubic,padding:const EdgeInsets.all(3),
        decoration:BoxDecoration(shape:BoxShape.circle,
         border:Border.all(color:accountOpened?const Color(0xFF65E5AD):Colors.transparent,
          width:2),
         color:accountOpened?Colors.white.withValues(alpha:.13):Colors.transparent),
        child:waffraAvatar(widget.profile.gender,widget.profile.avatar,radius:18))))),
    const SizedBox(width:7),
   ]),
  // Instant content swap avoids building/animating the previous heavy tab
  // alongside the next one (the recurring -> savings navigation hitch).
  // No fragment of the Home is visible before owner-verified entries AND
  // account balances have loaded. The root gate above reveals this layout
  // as one complete screen with no fake amount or loading illustration.
  body:_financeLoadFailure!=null?_financialRecoveryScreen():
   Stack(clipBehavior:Clip.none,children:[GestureDetector(
    behavior:HitTestBehavior.translucent,
    onHorizontalDragStart:(_)=>_swipeTravel=0,
    onHorizontalDragUpdate:(details)=>_swipeTravel+=details.delta.dx,
    onHorizontalDragEnd:_swipeBetweenSections,
    child:ValueListenableBuilder<bool>(
     valueListenable:hideWaffraAmounts,
     builder:(context,hidden,_)=>TweenAnimationBuilder<double>(
      key:ValueKey(accountOpened?'waffra-page-account':'waffra-page-$tab'),
      tween:Tween<double>(begin:0,end:1),
      // The first verified Home paints its complete values together; do
      // not make the dashboard fade in for an extra quarter-second.
      duration:tab==0&&!accountOpened?Duration.zero:
       waffraMotion(accountOpened?340:240),curve:Curves.easeOutCubic,
      builder:(ctx,progress,child)=>Opacity(opacity:progress,
       child:Transform.translate(offset:Offset((1-progress)*(waffraIsEnglish?26:-26),0),
        child:Transform.scale(scale:accountOpened?0.985+0.015*progress:1,child:child))),
      child:currentTab()))),
   ]),
  // A fixed 58x58 FAB: pop-up menu is an independent body overlay.
  // Never allow a menu width to change Scaffold's floating geometry.
  floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish),
  floatingActionButtonAnimator:const WaffraStationaryFabAnimator(),
  floatingActionButton:!ready||accountOpened||tab==2?null:CompositedTransformTarget(
   link:_fabOverlayAnchor,child:SizedBox(
   width:58,height:58,
   child:
    Material(
      color:forest,elevation:7,
     shadowColor:Colors.black26,
     shape:const CircleBorder(),
     child:InkWell(
      customBorder:const CircleBorder(),
      onTap:(){
     if(!_acceptFabTap())return;
     HapticFeedback.lightImpact();
     // M474: open immediately, with no 275ms artificial delay.
     setState(()=>addFabExpanded=!addFabExpanded);
    },
    splashFactory:NoSplash.splashFactory,
    highlightColor:Colors.transparent,
    child:AnimatedScale(
     scale:_fabPressed?0.96:1.0,
     duration:waffraMotion(220),
     curve:Curves.easeOutCubic,
     child:SizedBox(width:58,height:58,
      child:AnimatedRotation(
       duration:waffraMotion(320),
       curve:Curves.easeInOutCubic,
       turns:addFabExpanded?0.125:0,
       child:const Icon(Icons.add,color:Colors.white,size:28)))),
     )),
   )),
  // M675: footer height stays invariant. The global + is unchanged.
  // Notice is composited BESIDE its existing anchor, never inside the footer.
  bottomNavigationBar:accountOpened?null:WaffraFooterNavigation(
   selectedIndex:tab,
   english:waffraIsEnglish,
   onSelected:WaffraHaptics.selectionRequired((selected){
    waffraDismissFooterNotice();
    unawaited(selectFooter(selected));
   }),
  ),
  ),
  if(!accountOpened&&ready&&tab!=2)
   WaffraApprovedFixedFabNoticePosition(
    key:const Key('m675-snackbar-beside-unchanged-fab'),
    link:_fabOverlayAnchor,english:waffraIsEnglish,
    // Fill the horizontal run to the stationary FAB, including empty space.
    child:WaffraFooterNoticeHost(expandToAvailableWidth:true,onNoticePresented:(){
     if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
    }),
   ),
  // No '+' is mounted on the account detail route either. Keep the notice
  // at the page bottom there; the other no-FAB tabs retain footer clearance.
  if(accountOpened||tab==2||!ready)
   PositionedDirectional(start:12,end:12,bottom:accountOpened?12:90,
    child:WaffraFooterNoticeHost(expandToAvailableWidth:true)),
  if(addFabExpanded&&!accountOpened)...[
   Positioned.fill(
    key:const Key('waffra-fullscreen-fab-blur'),
    child:GestureDetector(
      behavior:HitTestBehavior.opaque,
      onTap:WaffraHaptics.tap(()=>setState(()=>addFabExpanded=false)),
      // M636: true blur composited only while '+' is expanded.
      child:ClipRect(child:BackdropFilter(
       filter:ui.ImageFilter.blur(sigmaX:6,sigmaY:6),
       child:ColoredBox(color:Colors.black.withValues(alpha:.22))))),
   ),
    if(addFabExpanded&&!accountOpened&&(tab==0||tab==1||tab==3||tab==4||goalsOpened))
     WaffraFabMenuAnchor(
      english:waffraIsEnglish,
      expanded:addFabExpanded,
      link:_fabOverlayAnchor,
      menu:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:waffraIsEnglish?CrossAxisAlignment.end:CrossAxisAlignment.start,
       children:[
        if(tab==0&&!goalsOpened)...[
        _addMenuOption(
         icon:Icons.edit_note_rounded,
         label:waffraIsEnglish?'Add manual transaction':'إضافة عملية يدوية',
         onTap:WaffraHaptics.tapRequired((){
          unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true));
         })),
        ]else if(goalsOpened||tab==3)...[
         _addMenuOption(icon:Icons.add_circle_outline_rounded,
          label:waffraIsEnglish?'New savings goal':'إضافة هدف جديد',
          onTap:WaffraHaptics.tapRequired((){
           unawaited(_launchAddAction(()=>goalDialog(),fromMenu:true));
          })),
         if(goals.isNotEmpty)...[
          const SizedBox(height:7),
          _addMenuOption(icon:Icons.copy_all_outlined,
           label:waffraIsEnglish?'Duplicate an existing goal':'تكرار هدف موجود',
           onTap:WaffraHaptics.tapRequired((){
            unawaited(_launchAddAction(_duplicateGoalFromMenu,fromMenu:true));
           })),
         ],
        ]else if(tab==4)...[
         _addMenuOption(icon:Icons.event_repeat_rounded,
          label:waffraIsEnglish?'New recurring transaction':'إضافة عملية متكررة',
          onTap:WaffraHaptics.tapRequired((){
           unawaited(_launchAddAction(()=>recurringDialog(),fromMenu:true));
          })),
         if(recurring.isNotEmpty)...[
          const SizedBox(height:7),
          _addMenuOption(icon:Icons.copy_all_outlined,
           label:waffraIsEnglish?'Duplicate recurring transaction':'تكرار عملية متكررة موجودة',
           onTap:WaffraHaptics.tapRequired((){
            unawaited(_launchAddAction(_duplicateRecurringFromMenu,fromMenu:true));
           })),
         ],
        ]else...[
         _addMenuOption(icon:Icons.trending_up,
          label:waffraIsEnglish?'Income category':'إضافة قسم دخل',
          onTap:WaffraHaptics.tapRequired((){unawaited(_launchAddAction(()=>chooseCategoryLevel(income:true),fromMenu:true));})),
         const SizedBox(height:7),
         _addMenuOption(icon:Icons.trending_down,
          label:waffraIsEnglish?'Expense category':'إضافة قسم مصروفات',
          onTap:WaffraHaptics.tapRequired((){unawaited(_launchAddAction(()=>chooseCategoryLevel(income:false),fromMenu:true));})),
        ]
       ]),
     ),
   Positioned.fill(
    child:Align(alignment:Alignment.topLeft,
     child:CompositedTransformFollower(
      link:_fabOverlayAnchor,showWhenUnlinked:false,
      targetAnchor:Alignment.topLeft,followerAnchor:Alignment.topLeft,
      child:Material(color:forest,elevation:7,shape:const CircleBorder(),
       child:InkWell(key:const Key('waffra-fab-menu-close'),
        onTap:WaffraHaptics.tap(()=>setState(()=>addFabExpanded=false)),
        customBorder:const CircleBorder(),
        child:const SizedBox(width:58,height:58,
         child:Icon(Icons.close_rounded,color:Colors.white,size:28)))))),
   ),
  ],
  // Outside Scaffold so the loading status never rebuilds the finance list.
  Positioned.fill(child:WaffraSmoothConfirmationOverlay(
   controller:_saveProgress,english:waffraIsEnglish)),
  ]));
}
