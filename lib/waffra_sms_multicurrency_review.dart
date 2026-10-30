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
    final original = value.trim();
    final token = original.toUpperCase();
    if (const <String>{'SR','ريال','ريال سعودي','ر.س','﷼','⃁'}
        .contains(token)) return 'SAR';
    if (const <String>{'ج.م','جنيه','جنيه مصري'}.contains(token)) return 'EGP';
    if (const <String>{'د.إ','درهم','درهم إماراتي'}.contains(token)) return 'AED';
    if (token == '€') return 'EUR';
    if (token == '£') return 'GBP';
    if (token == '₹') return 'INR';
    if (token == r'$') return 'UNKNOWN'; // Ambiguous in many countries
    // An English verb such as "has" is not an ISO currency code.
    if (RegExp(r'^[A-Za-z]{3}$').hasMatch(original) &&
        !supported.contains(token) && original != token) return '';
    if (const <String>{'HAS','FOR','AND','THE','YOU','NEW','NOW','NOT'}
        .contains(token)) return '';
    // Common SMS action codes are NOT currencies even beside an amount.
    if (const <String>{'POS','ATM','OTP','PIN','SMS','REF','TAX','VAT',
      'FEE','BAL','PAY','P2P','ACH'}.contains(token)) return '';
    return token;
  }

  static final RegExp adjacentAmount = RegExp(
    r'(?:(?!(?:POS|ATM|OTP|PIN|SMS|REF|TAX|VAT|FEE|BAL|PAY|P2P|ACH)\b)(?:\b[A-Z]{3}(?=\s*[:：]?\s*[0-9٠-٩۰-۹])|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹])'
    r'\s*[:：]?\s*[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.\u066B\u066C]*)'
    r'|(?:[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.\u066B\u066C]*\s*'
    r'(?:[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹]))',
    caseSensitive: false);

  static final RegExp currencyToken = RegExp(
    r'[A-Z]{3}(?![A-Za-z])|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
    r'ج\.م|جنيه(?:\s+مصري)?|د\.إ|درهم(?:\s+إماراتي)?|[$€£₹]',
    caseSensitive: false);

  static Set<String> currenciesForMessage(String raw) {
    final found = <String>{};
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      // Split combined SMS lines: "Purchase USD 10; Balance SAR 400".
      // Ignore only the balance/fee clause, never the transaction clause.
      for (final clause in line.split(RegExp(r'[;|]'))) {
        final footer = RegExp(
          r'available balance|remaining balance|current balance|'
          r'\bbalance\b|الرصيد|المتاح|saldo disponible|solde disponible|'
          r'commission|رسوم|service fee|fee amount|\bvat\b|ضريبة',
          caseSensitive:false).firstMatch(clause);
        final action = footer==null?clause:clause.substring(0,footer.start);
        for (final expression in adjacentAmount.allMatches(action)) {
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
    }
    return found;
  }

  /// Safe preview only. Does not authorize a finance write, FX or a debit.
  static String? originalAmountPreview(String raw) {
    final found=currenciesForMessage(raw);
    if(found.length!=1||found.contains('UNKNOWN'))return null;
    final currency=found.single;
    final scale=const <String>{'JOD','IQD','KWD','BHD','OMR','TND'}
      .contains(currency)?3:(const <String>{'JPY','KRW'}.contains(currency)?0:2);
    const ar='٠١٢٣٤٥٦٧٨٩', fa='۰۱۲۳۴۵۶۷۸۹';
    final normalized=raw.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'),(m){
      final d=m.group(0)!;
      final i=ar.indexOf(d);
      return (i>=0?i:fa.indexOf(d)).toString();
    }).replaceAll('٫','.').replaceAll('٬',',');
    final footer=RegExp(
      r'available balance|remaining balance|current balance|'
      r'\bbalance\b|الرصيد|المتاح',
      caseSensitive:false).firstMatch(normalized);
    final action=footer==null?normalized:normalized.substring(0,footer.start);
    final code=RegExp.escape(currency);
    const moneyPattern=r'([0-9]{1,9}(?:\.[0-9]{1,3})?)';
    final starts=RegExp('(?<![A-Za-z])'+code+r'\s*[:：]?\s*'+moneyPattern,
      caseSensitive:false);
    final ends=RegExp(moneyPattern+r'\s*'+code+r'(?![A-Za-z])',
      caseSensitive:false);
    final amounts=<String>[
      ...starts.allMatches(action).map((e)=>e.group(1)!),
      ...ends.allMatches(action).map((e)=>e.group(1)!),
    ];
    if(amounts.length!=1)return null;
    final original=amounts.single;
    final digits=original.contains('.')?original.split('.').last.length:0;
    final amount=double.tryParse(original);
    if(digits>scale||amount==null||!amount.isFinite||amount<=0)return null;
    return original+' '+currency;
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
