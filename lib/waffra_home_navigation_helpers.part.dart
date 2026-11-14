part of 'main.dart';

/// M830 / Issue #633: original Home category/summary/footer/back navigation helpers.
/// No design, ledger, verified account or FAB changes.
extension _WaffraHomeNavigationHelpers on _HomeScreenState {
 Widget categoriesPage()=>categoriesPageV2();
 Widget _summaryBox(String heading,String number,IconData icon,Color color)=>Container(
  padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(
   color:Theme.of(context).cardColor,
   borderRadius:BorderRadius.circular(18),
   border:Border.all(color:color.withValues(alpha:.16))),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[Icon(icon,color:color,size:20),const SizedBox(width:7),
    Expanded(child:WaffraText(heading,style:const TextStyle(fontSize:12)))]),
   const SizedBox(height:8),
   FittedBox(fit:BoxFit.scaleDown,alignment:AlignmentDirectional.centerStart,
    child:WaffraText(number,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
  ]));
 Widget _filterChip(String label,bool selected,VoidCallback onTap)=>
  ChoiceChip(label:WaffraText(label),selected:selected,onSelected:WaffraHaptics.selection((_)=>onTap()),
   showCheckmark:selected,
   side:WaffraSubtleSelection.border(selected,Theme.of(context).brightness),
   selectedColor:Theme.of(context).brightness==Brightness.dark
    ?const Color(0xFF28533C):waffraMint,
   labelStyle:TextStyle(
    color:selected?(Theme.of(context).brightness==Brightness.dark
     ?const Color(0xFFD9FFE9):forest):null,
    fontWeight:selected?FontWeight.bold:FontWeight.normal));
 // M711: original Home goal workflows live in the registered goal-actions part.
 // M689: all goal actions stay available by tapping the compact card.
 // The card itself has no redundant "View" or oversized quick-actions row.
 // M711: goal action sheet implementation lives in the goal-actions part.
 // M707: approved Goals and Recurring pages moved to registered Home part.
 // M721: original Home calendar, backup and account tools moved to registered same-library part.
 Widget currentTab(){
  if(accountOpened)return profilePage();
  if(tab==1||tab==3||tab==4){
   return RefreshIndicator(
    onRefresh:()=>_refreshAndSettle(
     tab==1?_categoryScrollController:
     tab==3?_goalsScrollController:_recurringScrollController,tab),
    child:ScrollConfiguration(
     behavior:ScrollConfiguration.of(context).copyWith(
      physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
      overscroll:false),
     child:_currentTabContents()));
  }
  return _currentTabContents();
 }
 Widget _currentTabContents(){
  switch(tab){
   case 0:return goalsOpened?goalsPage():dashboard();
   case 1:return categoriesPage();
   case 2:return _smartToolsTab();
   case 3:return goalsPage();
   case 4:return recurringPage();
   default:return dashboard();
  }
 }
 void _swipeBetweenSections(DragEndDetails details){
  if(!ready||goalsOpened||accountOpened)return;
  final velocity=details.primaryVelocity??0;
  final dx=_swipeTravel.abs()>50?_swipeTravel:velocity/10;
  if(dx.abs()<65)return;
  final forward=waffraIsEnglish?dx>0:dx<0;
  final target=(tab+(forward?1:-1)).clamp(0,WaffraFooterNavigation.itemCount-1);
  if(target!=tab)unawaited(selectFooter(target));
 }
 Future<void> selectFooter(int target)async {
  if(target<0||target>=WaffraFooterNavigation.itemCount||!mounted||
    (target==tab&&!accountOpened&&!goalsOpened&&!addFabExpanded))return;
  setState((){
   if(target!=tab){
    _tabBackStack.add(tab);
    if(_tabBackStack.length>20)_tabBackStack.removeAt(0);
   }
   tab=target;accountOpened=false;goalsOpened=false;
   addFabExpanded=false;_headerCompact=false;
  });
 }
 bool _consumeHomeBack(){
  if(!mounted||!widget.postAuthVisible)return false;
  // Go back one UI layer at a time, without rebuilding earlier forms.
  if(addFabExpanded){setState(()=>addFabExpanded=false);return true;}
  if(accountOpened){
   // Existing product rule: Account back always returns to Home.
   setState((){
    accountOpened=false;goalsOpened=false;tab=0;
    _tabBackStack.clear();_headerCompact=false;
   });
   return true;
  }
  if(goalsOpened){setState(()=>goalsOpened=false);return true;}
  if(tab!=0){
   setState((){
    tab=_tabBackStack.isNotEmpty?_tabBackStack.removeLast():0;
    _headerCompact=false;
   });
   return true;
  }
  return false;
 }
}
