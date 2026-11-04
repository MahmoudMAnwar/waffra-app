/// Saudi-only mobile number rules for all account providers.
/// User input is always the national form 05XXXXXXXX (10 ASCII digits).
/// Existing +9665XXXXXXXX Google records remain readable without migration.
/// Foreign legacy records are never silently rewritten as Saudi numbers.
abstract final class WaffraSaudiMobile {
 static final RegExp nationalPattern=RegExp(r'^05[0-9]{8}$');
 static final RegExp storedE164Pattern=RegExp(r'^\+9665[0-9]{8}$');
 static bool isValidNational(String? text)=>
  nationalPattern.hasMatch((text??'').trim());
 static String inputFromStored(String? stored){
  final value=(stored??'').trim();
  if(isValidNational(value))return value;
  if(storedE164Pattern.hasMatch(value))return '0${value.substring(4)}';
  // Do not prefill non-Saudi legacy values as if they were valid Saudi mobiles.
  return '';
 }
 static String? toE164(String? national){
  final value=(national??'').trim();
  return isValidNational(value)?'+966${value.substring(1)}':null;
 }
 static bool isSupportedStored(String? value)=>
  isValidNational(value)||storedE164Pattern.hasMatch((value??'').trim());
}
