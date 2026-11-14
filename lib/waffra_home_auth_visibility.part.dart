part of 'main.dart';

/// M930 / Issue #633: original verified session/nav method extraction.
extension _WaffraHomeAuthVisibility on _HomeScreenState {
 Future<bool> _m663AwaitVisible(int epoch)async{
  if(widget.postAuthVisible){
   // Actual layout is allowed to finish before optional I/O.
   await WidgetsBinding.instance.endOfFrame;
  }else{
   await _m663FirstInteractiveFrame.future;
  }
  return mounted&&widget.postAuthVisible&&
   epoch==_m630HomeStartupEpoch&&!_m627ClosingSession;
 }
}
