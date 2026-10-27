/// Read-only, conservative currency discovery for pasted bank SMS.
/// Never performs FX or changes the ledger or display currency.
abstract final class WaffraSmsCurrencies {
  static const supported = <String>{
    'SAR','EGP','USD','EUR','GBP','AED','KWD','QAR','BHD','OMR',
    'JOD','IQD','LBP','MAD','DZD','TND','TRY','INR','PKR','BDT',
    'JPY','CNY','CAD','AUD','CHF','SEK','NOK','DKK','ZAR',
    'SGD','HKD','MYR','IDR','KRW','THB','PHP',
  };

  static String codeFor(String value) {
    final token = value.trim().toUpperCase();
    if (const <String>{'SR','ريال','ريال سعودي','ر.س','﷼','⃁'}
        .contains(token)) return 'SAR';
    if (const <String>{'ج.م','جنيه','جنيه مصري'}.contains(token)) return 'EGP';
    if (const <String>{'د.إ','درهم','درهم إماراتي'}.contains(token)) return 'AED';
    if (token == '€') return 'EUR';
    if (token == '£') return 'GBP';
    if (token == '₹') return 'INR';
    if (token == r'$') return 'UNKNOWN'; // Ambiguous in many countries
    return token;
  }

  static final RegExp adjacentAmount = RegExp(
    r'(?:(?:\b[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹])'
    r'\s*[:：]?\s*[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.\u066B\u066C]*)'
    r'|(?:[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.\u066B\u066C]*\s*'
    r'(?:\b[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹]))',
    caseSensitive: false);

  static final RegExp currencyToken = RegExp(
    r'\b[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹]',
    caseSensitive: false);

  static Set<String> currenciesForMessage(String raw) {
    final found = <String>{};
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      if (RegExp(
        r'available balance|remaining balance|current balance|'
        r'الرصيد|المتاح|saldo disponible|solde disponible|'
        r'commission|رسوم|service fee|fee amount|vat|ضريبة',
        caseSensitive: false).hasMatch(line)) continue;
      for (final expression in adjacentAmount.allMatches(line)) {
        for (final token in currencyToken.allMatches(expression.group(0)!)) {
          final code = codeFor(token.group(0)!);
          if (supported.contains(code) || code == 'UNKNOWN') {
            found.add(code);
          } else if (RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
            found.add('UNKNOWN');
          }
        }
      }
    }
    return found;
  }

  static bool requiresReviewForSarLedger(String raw) {
    final currencies = currenciesForMessage(raw);
    return currencies.length > 1 || currencies.any((code) => code != 'SAR');
  }

  static WaffraSmsCurrencyBatch summarize(List<String> messages) {
    final counts = <String, int>{};
    for (final message in messages) {
      for (final currency in currenciesForMessage(message)) {
        counts[currency] = (counts[currency] ?? 0) + 1;
      }
    }
    return WaffraSmsCurrencyBatch(Map<String, int>.unmodifiable(counts));
  }
}

class WaffraSmsCurrencyBatch {
  const WaffraSmsCurrencyBatch(this.counts);
  final Map<String, int> counts;
  bool get hasMixedCurrencies => counts.keys.length > 1;
  bool get needsCurrencyReview => counts.keys.any((code) => code != 'SAR');
  String get summary => (counts.entries.toList()
    ..sort((a,b) => a.key.compareTo(b.key)))
    .map((item) => item.key + ': ' + item.value.toString()).join(' • ');
}
