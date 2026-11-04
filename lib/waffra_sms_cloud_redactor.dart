/// M421: Redaction BEFORE any cloud transport. No cloud provider is called here.
/// Financial amounts/currency/action are retained; personal identifiers removed.
abstract final class WaffraSmsCloudRedactor {
  static final _otp = RegExp(
    r'\b(?:otp|one.?time.?password|verification.?code|security.?code|'
    r'login.?code|authentication.?code|passcode|password)\b|'
    r'رمز\s*(?:التحقق|التفعيل|الدخول|المرور)|'
    r'كود\s*(?:التحقق|الدخول)|الرمز\s*السري',
    caseSensitive: false);
  static final _action = RegExp(
    r'\b(?:purchase|debited|credited|transfer|refund|salary|'
    r'withdrawal|deposit|payment)\b|'
    r'شراء|خصم|حوالة|تحويل|راتب|سحب|إيداع|ايداع|دفع',
    caseSensitive: false);
  static final _money = RegExp(
    r'\b(?:SAR|SR|AED|JOD|EGP|KWD|BHD|OMR)(?=\b|[0-9٠-٩۰-۹])|'
    r'ريال|درهم|دينار|جنيه|ر\.?\s*س',
    caseSensitive: false);
  static String? redact(String sms) {
    if (sms.length < 18 || sms.length > 1600 || _otp.hasMatch(sms)) {
      return null;
    }
    var data = sms.replaceAll('\u200e', '').replaceAll('\u200f', '');
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    data = data.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (m) {
      final digit = m.group(0)!;
      final value = arabic.indexOf(digit);
      return (value >= 0 ? value : persian.indexOf(digit)).toString();
    });
    data = data.replaceAll(RegExp(
      r'(?:\b(?:to|from|beneficiary|payee|recipient)\s*[:：]\s*|'
      r'(?:إلى|الى|لصالح|المستفيد)\s*[:：]\s*)'
      r'[^\r\n]{2,100}', caseSensitive: false), '[party-redacted]');
    // Mask contiguous and spaced IBAN variants conservatively.
    data = data.replaceAll(RegExp(
      r'\b[A-Z]{2}[0-9]{2}(?:[ -]?[A-Z0-9]){10,}\b',
      caseSensitive: false), '[iban-redacted]');
    data = data.replaceAll(RegExp(
      r'(?:reference|ref(?:erence)?\s*(?:no\.?|number)?|'
      r'الرقم\s*المرجعي|رقم\s*العملية)\s*[:：#]?\s*'
      r'[A-Z0-9-]{6,60}', caseSensitive: false), '[reference-redacted]');
    data = data.replaceAll(RegExp(r'\b\d{8,}\b'), '[identifier-redacted]');
    data = data.replaceAll(RegExp(
      r'\+?\d{2,4}[- ]\d{3}[- ]\d{3,6}\b'), '[identifier-redacted]');
    data = data.trim();
    // After redaction, anything that still looks like an IBAN/full payment
    // identifier fails closed instead of reaching an external model.
    if (RegExp(r'\b[A-Z]{2}[0-9]{2}(?:[ -]?[A-Z0-9]){10,}\b',
       caseSensitive: false).hasMatch(data)) return null;
    if (RegExp(r'\b[0-9]{8,}\b').hasMatch(data)) return null;
    if (data.length < 18 || data.length > 1600 ||
        !_action.hasMatch(data) || !_money.hasMatch(data)) return null;
    return data;
  }
}
