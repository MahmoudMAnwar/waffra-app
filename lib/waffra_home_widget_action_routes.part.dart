part of 'main.dart';

/// M930 / Issue #633: original verified session/nav method extraction.
extension _WaffraHomeWidgetActionRoutes on _HomeScreenState {
 void _returnToHome(){if(mounted)setState((){_tabBackStack.clear();tab=0;accountOpened=false;goalsOpened=false;addFabExpanded=false;});}
 void _receiveWidgetAction(){
  // New pre-auth barrier. Preserve the original owner/action guard below
  // because existing Widgets/source regressions depend on its semantics.
  if(!mounted||!ready||!widget.postAuthVisible)return;
  if(!mounted||!ready||waffraWidgetAction.value!='add')return;
  waffraWidgetAction.value=null;
  setState((){tab=0;goalsOpened=false;addFabExpanded=false;});
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(entrySheet());});
 }
}
