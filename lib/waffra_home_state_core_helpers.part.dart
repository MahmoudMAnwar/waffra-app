part of 'main.dart';

/// M964 / Issue #666: pure Home presentation/session helpers.
/// Same Dart library and exact original logic; no money/SMS writer.
extension _WaffraHomeStatePureHelpers on _HomeScreenState {
 bool _m630SmsSessionCurrent(int epoch)=>
  mounted&&ready&&widget.postAuthVisible&&
  !_m627ClosingSession&&_financeLoadFailure==null&&
  epoch==_m630HomeStartupEpoch;

 String get _m467ChoiceKey{
  final owner=widget.profile.provider+'|'+widget.profile.phone.trim()+
   '|'+widget.profile.email.trim().toLowerCase();
  final hash=sha256.convert(utf8.encode(owner)).toString();
  return 'waffra_home_account_display_'+hash.substring(0,20);
 }

 WaffraFinancePeriodIndex get _m684Periods=>_m940LedgerReads.index(entries);

 String get _smsRuleOwnerKey=>WaffraSmsLocalRuleStore.ownerKey(
  provider:widget.profile.provider,phone:widget.profile.phone,
  email:widget.profile.email);
}
