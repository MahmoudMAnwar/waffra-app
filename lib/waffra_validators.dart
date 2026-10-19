/// Shared form validation rules for Waffra.
class WaffraValidators {
  const WaffraValidators._();

  static String? requiredText(String? raw, {int maxLength=100}) {
    final text=(raw??'').trim();
    if(text.isEmpty) return 'required';
    if(text.length>maxLength) return 'too_long';
    return null;
  }

  static String? positiveAmount(String? raw, {bool required=true}) {
    final text=(raw??'').trim().replaceAll(',', '').replaceAll('٬','').replaceAll('٫','.');
    if(text.isEmpty) return required?'required':null;
    final parsed=double.tryParse(text);
    if(parsed==null || !parsed.isFinite || parsed<=0) return 'invalid_amount';
    return null;
  }

  static String? mobileNumber(String? raw) {
    return RegExp(r'^05[0-9]{8}$').hasMatch((raw??'').trim())?null:'invalid_mobile';
  }

  static String? dayOfMonth(String? raw) {
    final day=int.tryParse((raw??'').trim());
    return day==null || day<1 || day>31?'invalid_day':null;
  }

  static String? uniqueCategory(String? value, Iterable<String> existing) {
    final text=(value??'').trim().toLowerCase();
    if(text.isEmpty)return 'required';
    return existing.any((v)=>v.trim().toLowerCase()==text)?'duplicate':null;
  }
}
