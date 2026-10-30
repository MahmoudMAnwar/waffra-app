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
    final originalToken = value.trim();
    final token = originalToken.toUpperCase();
    if (const <String>{'SR','ريال','ريال سعودي','ر.س','﷼','⃁'}
        .contains(token)) return 'SAR';
    if (const <String>{'ج.م','جنيه','جنيه مصري'}.contains(token)) return 'EGP';
    if (const <String>{'د.إ','درهم','درهم إماراتي'}.contains(token)) return 'AED';
    if (token == '€') return 'EUR';
    if (token == '£') return 'GBP';
    if (token == '₹') return 'INR';
    if (token == r'
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
        // Balance/fee text can share the SAME LINE as a real transfer.
        // Keep the action before the boundary, never the following balance.
        final footer = RegExp(
          r'available balance|remaining balance|current balance|'
          r'\bbalance\b|الرصيد|المتاح|saldo disponible|solde disponible|'
          r'commission|رسوم|service fee|fee amount|\bvat\b|ضريبة',
          caseSensitive: false).firstMatch(clause);
        final transactionClause = footer == null
            ? clause : clause.substring(0, footer.start);
        for (final expression in adjacentAmount.allMatches(transactionClause)) {
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

  /// Currency and amount for user-facing verification only: no FX and no
  /// amount is returned to an SAR-only ledger. Reject competing amounts.
  /// Three decimal places are valid for Jordanian dinars, among others.
  static String? originalAmountPreview(String raw) {
    final currencies = currenciesForMessage(raw);
    if (currencies.length != 1 || currencies.contains('UNKNOWN')) return null;
    final code = currencies.single;
    final precision = const <String>{
      'JOD','KWD','BHD','OMR','TND','IQD',
    }.contains(code) ? 3 : (const <String>{'JPY','KRW'}.contains(code) ? 0 : 2);
    final clean = raw.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      const persian = '۰۱۲۳۴۵۶۷۸۹';
      final ch = match.group(0)!;
      final first = arabic.indexOf(ch);
      return (first >= 0 ? first : persian.indexOf(ch)).toString();
    }).replaceAll('٫', '.').replaceAll('٬', ',');
    final footer = RegExp(
      r'available balance|remaining balance|current balance|'
      r'\bbalance\b|الرصيد|المتاح',
      caseSensitive: false,
    ).firstMatch(clean);
    final transaction = footer == null ? clean : clean.substring(0, footer.start);
    final quoted = RegExp.escape(code);
    final number = r'([0-9]{1,9}(?:\.[0-9]{1,3})?)';
    final ahead = RegExp('(?<![A-Za-z])$quoted\\s*[:：]?\\s*$number',
        caseSensitive: false);
    final after = RegExp('$number\\s*$quoted(?![A-Za-z])',
        caseSensitive: false);
    final amounts = <String>[];
    for (final match in ahead.allMatches(transaction)) {
      amounts.add(match.group(1)!);
    }
    for (final match in after.allMatches(transaction)) {
      amounts.add(match.group(1)!);
    }
    if (amounts.length != 1) return null;
    final value = amounts.single;
    final fraction = value.contains('.') ? value.split('.').last.length : 0;
    if (fraction > precision || fraction == 3 && precision != 3) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return '$value $code';
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
) return 'UNKNOWN'; // Ambiguous in many countries
    // Do not misread ordinary English words ("has", "for", "and") as
    // unknown currencies merely because the word follows an amount.
    if (RegExp(r'^[A-Z]{3}
    // Common SMS action codes are NOT currencies even beside an amount.
    if (const <String>{'POS','ATM','OTP','PIN','SMS','REF','TAX','VAT',
      'FEE','BAL','PAY','P2P','ACH'}.contains(token)) return '';
    return token;
  }

  static final RegExp adjacentAmount = RegExp(
    r'(?:(?!(?:POS|ATM|OTP|PIN|SMS|REF|TAX|VAT|FEE|BAL|PAY|P2P|ACH)\b)(?:\b[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
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
      // Split combined SMS lines: "Purchase USD 10; Balance SAR 400".
      // Ignore only the balance/fee clause, never the transaction clause.
      for (final clause in line.split(RegExp(r'[;|]'))) {
        if (RegExp(
          r'available balance|remaining balance|current balance|'
          r'الرصيد|المتاح|saldo disponible|solde disponible|'
          r'commission|رسوم|service fee|fee amount|vat|ضريبة',
          caseSensitive: false).hasMatch(clause)) continue;
        for (final expression in adjacentAmount.allMatches(clause)) {
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
).hasMatch(token) &&
        !supported.contains(token) && originalToken != token) return '';
    if (const <String>{'HAS','FOR','AND','THE','YOU','ONE','NEW','ALL','NOW','NOT'}
        .contains(token)) return '';
    // Common SMS action codes are NOT currencies even beside an amount.
    if (const <String>{'POS','ATM','OTP','PIN','SMS','REF','TAX','VAT',
      'FEE','BAL','PAY','P2P','ACH'}.contains(token)) return '';
    return token;
  }

  static final RegExp adjacentAmount = RegExp(
    r'(?:(?!(?:POS|ATM|OTP|PIN|SMS|REF|TAX|VAT|FEE|BAL|PAY|P2P|ACH)\b)(?:\b[A-Z]{3}\b|SR\b|ريال(?:\s+سعودي)?|ر\.س|﷼|⃁|'
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
      // Split combined SMS lines: "Purchase USD 10; Balance SAR 400".
      // Ignore only the balance/fee clause, never the transaction clause.
      for (final clause in line.split(RegExp(r'[;|]'))) {
        if (RegExp(
          r'available balance|remaining balance|current balance|'
          r'الرصيد|المتاح|saldo disponible|solde disponible|'
          r'commission|رسوم|service fee|fee amount|vat|ضريبة',
          caseSensitive: false).hasMatch(clause)) continue;
        for (final expression in adjacentAmount.allMatches(clause)) {
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
