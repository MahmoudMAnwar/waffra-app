part of 'main.dart';

/// M926 #633: exact UI-only scroll/motion settings; no financial state.
extension _WaffraHomePresentationControls on _HomeScreenState {
 void _handleDashboardScroll(){
  if(!mounted||tab!=0||goalsOpened||!_dashboardScrollController.hasClients)return;
  final compact=_dashboardScrollController.offset>96;
  if(compact==_headerCompact)return;
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(mounted&&tab==0&&compact!=_headerCompact)setState(()=>_headerCompact=compact);
  });
 }
 Future<void> setAnimationLevel(String next)async {
  if(!{'full','balanced','reduced','off'}.contains(next))return;
  waffraAnimationLevel.value=next;
  if(mounted)setState((){});
  final p=await SharedPreferences.getInstance();
  await p.setString('waffra_animation_level',next);
 }
}
