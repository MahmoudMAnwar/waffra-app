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

  /// A pure currency precision table shared by display, FX and SMS parsing.
  /// This does not authorize money to be posted to a financial ledger.
  static int minorDigits(String currency) {
    if (const <String>{'JPY','KRW'}.contains(currency)) return 0;
    if (const <String>{'BHD','KWD','OMR','TND','JOD','IQD'}
        .contains(currency)) return 3;
    return 2;
  }

  static String _westernDigits(String source) {
    const ar='٠١٢٣٤٥٦٧٨٩', fa='۰۱۲۳۴۵۶۷۸۹';
    return source.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'),(match){
      final ch=match.group(0)!;
      final i=ar.indexOf(ch);
      return (i>=0?i:fa.indexOf(ch)).toString();
    }).replaceAll('٫','.').replaceAll('٬',',');
  }

  /// Never turn an ambiguous 1,234 into 1.234 (or vice versa).
  /// Decimal punctuation is normalized only when grouping is unambiguous.
  static String? _canonicalMoney(String raw,int digits) {
    var value=_westernDigits(raw);
    if (!RegExp(r'^[0-9][0-9,.]*$').hasMatch(value)) return null;
    final comma=value.lastIndexOf(','),dot=value.lastIndexOf('.');
    if (comma>=0 && dot>=0) {
      final separator=comma>dot?',':'.';
      final groups=separator==','?'.':',';
      final pieces=value.split(separator);
      if (pieces.length!=2 ||
          !RegExp(r'^[0-9]{1,3}(?:[,.][0-9]{3})+$').hasMatch(pieces.first) ||
          !RegExp(r'^[0-9]{1,3}$').hasMatch(pieces.last) ||
          !pieces.first.contains(groups)) return null;
      final integer=pieces.first.replaceAll(groups,'');
      value=integer+'.'+pieces.last;
    } else if (comma>=0 || dot>=0) {
      final separator=comma>=0?',':'.';
      final parts=value.split(separator);
      if(parts.length>2) {
        if (!RegExp('^[0-9]{1,3}('+RegExp.escape(separator)+r'[0-9]{3})+$')
            .hasMatch(value)) return null;
        value=parts.join('');
      } else {
        final fraction=parts.last;
        if (fraction.length==3 && digits<3) {
          // A grouping marker may mean 1000, but we cannot prove it.
          return null;
        }
        if (fraction.length>digits || digits==0) {
          // A single comma grouping (1,234) is acceptable only with
          // unmistakable grouped digits. Otherwise require manual input.
          return null;
        }
        value=parts.first+'.'+fraction;
      }
    }
    if(!RegExp(r'^[0-9]{1,12}(?:\.[0-9]{1,3})?$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  /// Returns the sole action amount in source units, or null when there is
  /// insufficient evidence. Never includes a balance, fee or second amount.
  /// This parser is a *suggestion* and must not write into the SAR ledger.
  static ({double amount,String currency,String formatted})? originalAmount(
      String raw) {
    final found=currenciesForMessage(raw);
    if(found.length!=1 || found.contains('UNKNOWN'))return null;
    final currency=found.single;
    final scale=minorDigits(currency);
    final normalized=_westernDigits(raw);
    final footer=RegExp(
      r'available balance|remaining balance|current balance|'
      r'\bbalance\b|الرصيد|المتاح|commission|service fee|'
      r'fee amount|رسوم|ضريبة|vat\b',
      caseSensitive:false).firstMatch(normalized);
    final action=footer==null?normalized:normalized.substring(0,footer.start);
    final escaped=RegExp.escape(currency);
    // Explicit codes only: do not treat a random numeral, card or reference
    // as a financial amount. Currency may touch the number on either side.
    final pattern=r'([0-9][0-9,.]{0,20})(?![0-9,.])';
    final before=RegExp('(?<![A-Za-z])'+escaped+r'\s*[:：]?\s*'+pattern,
      caseSensitive:false);
    final after=RegExp(pattern+r'\s*'+escaped+r'(?![A-Za-z])',
      caseSensitive:false);
    final matches=<String>[
      ...before.allMatches(action).map((m)=>m.group(1)!),
      ...after.allMatches(action).map((m)=>m.group(1)!),
    ];
    if(matches.length!=1)return null;
    final canonical=_canonicalMoney(matches.single,scale);
    if(canonical==null)return null;
    final amount=double.tryParse(canonical);
    if(amount==null||!amount.isFinite||amount<=0||amount>1e9)return null;
    final factor=scale==3?1000:scale==0?1:100;
    final minor=amount*factor;
    if((minor-minor.round()).abs()>0.000001)return null;
    return (amount:amount,currency:currency,formatted:canonical+' '+currency);
  }

  static String? originalAmountPreview(String raw)=>originalAmount(raw)?.formatted;

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
