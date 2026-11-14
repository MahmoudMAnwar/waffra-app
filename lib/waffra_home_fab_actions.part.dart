part of 'main.dart';

/// M930 / Issue #633: original verified session/nav method extraction.
extension _WaffraHomeFabActions on _HomeScreenState {
 Future<void> _launchAddAction(Future<void> Function() action,{bool fromMenu=false})async{
  if(_addActionOpening)return;
  _addActionOpening=true;
  if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
  try{
   // Allow the menu to finish collapsing before presenting a sheet.
   // M474: open sheet promptly after closing the menu.
   if(mounted)await action();
  }finally{_addActionOpening=false;}
 }
 bool _acceptFabTap(){
  final now=DateTime.now();
  if(_addActionOpening||(_lastFabTapAt!=null&&
   now.difference(_lastFabTapAt!)<const Duration(milliseconds:380)))return false;
  _lastFabTapAt=now;
  return true;
 }
}
