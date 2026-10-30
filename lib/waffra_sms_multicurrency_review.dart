/// Read-only, conservative currency discovery for pasted bank SMS.
/// Never performs FX or changes the ledger or display currency.
abstract final class WaffraSmsCurrencies {
  static const supported = <String>{
    'SAR','EGP','USD','EUR','GBP','AED','KWD','QAR','BHD','OMR',
    'JOD','IQD','LBP','MAD','DZD','TND','TRY','INR','PKR','BDT',
    'JPY','CNY','CAD','AUD','CHF','SEK','NOK','DKK','ZAR',
    'SGD','HKD','MYR','IDR','KRW','THB','PHP',
  };

  // Full Arabic currency names independent of the app's display setting.
  // Normalize the names before matching, but never silently convert money.
  static const _arabicNames=<String,String>{
    'ريال سعودي':'SAR','جنيه مصري':'EGP',
    'درهم اماراتي':'AED','دينار كويتي':'KWD',
    'دينار بحريني':'BHD','ريال قطري':'QAR',
    'ريال عماني':'OMR','دينار اردني':'JOD',
    'دينار عراقي':'IQD','ليره لبنانيه':'LBP',
    'درهم مغربي':'MAD','دينار جزائري':'DZD',
    'دينار تونسي':'TND','دولار امريكي':'USD',
    'يورو':'EUR','جنيه استرليني':'GBP',
    'ليره تركيه':'TRY','روبيه هنديه':'INR',
    'روبيه باكستانيه':'PKR','تاكا بنغلاديشي':'BDT',
    'ين ياباني':'JPY','يوان صيني':'CNY',
    'دولار كندي':'CAD','دولار استرالي':'AUD',
    'فرنك سويسري':'CHF','كرونه سويديه':'SEK',
    'كرونه نرويجيه':'NOK','كرونه دنماركيه':'DKK',
    'راند جنوب افريقي':'ZAR','دولار سنغافوري':'SGD',
    'دولار هونغ كونغ':'HKD','رينغيت ماليزي':'MYR',
    'روبيه اندونيسيه':'IDR','وون كوري':'KRW',
    'بات تايلندي':'THB','بيزو فلبيني':'PHP',
  };
  static String _normalizeArabic(String raw)=>raw
    .replaceAll(RegExp(r'[أإآٱ]'),'ا')
    .replaceAll('ى','ي').replaceAll('ة','ه')
    .replaceAll(RegExp(r'[\\u064B-\\u065F\\u0670]'),'');
  static final _namedAlternatives=_arabicNames.keys
      .map(RegExp.escape).join('|');
  static final _namedAdjacentAmount=RegExp(
    r'(?:(?:[0-9][0-9,.]*\\s*(' + _namedAlternatives +
      r'))|(?:(' + _namedAlternatives + r')\\s*[0-9][0-9,.]*))'
  );

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
    // Unknown lowercase words such as "has" are not financial currencies.
    // But genuine unsupported ISO codes in real bank messages must remain
    // UNKNOWN, not slip into the SAR-only ledger as a valid amount.
    const externalIsoCodes=<String>{
      'MXN','BRL','CLP','COP','PEN','ARS','UYU','VES','BOB','PYG',
      'CRC','GTQ','DOP','HNL','NIO','PAB','JMD','TTD','BSD',
      'PLN','CZK','HUF','RON','BGN','RSD','UAH','RUB','GEL','MDL',
      'ILS','NGN','KES','GHS','ETB','UGX','TZS','RWF','XOF','XAF',
      'MUR','SCR','NPR','LKR','MMK','KHR','LAK','MNT','KZT','UZS',
      'AZN','AMD','BAM','MKD','ALL','ISK','HRK','CUP','TWD','VND',
      'BWP','NAD','MZN','AOA','ZMW','MWK','SDG','LYD','SYP','IRR',
    };
    if (RegExp(r'^[A-Za-z]{3}$').hasMatch(original) &&
        !supported.contains(token) && original != token &&
        !externalIsoCodes.contains(token)) return '';
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
        // Named Arabic currencies can contain spaces. Scan their full names
        // beside an amount before the generic ريال/جنيه/درهم token scanner.
        final namedAction=_normalizeArabic(_westernDigits(action));
        for (final match in _namedAdjacentAmount.allMatches(namedAction)) {
          final name=match.group(1)??match.group(2);
          if(name!=null)found.add(_arabicNames[name]??'UNKNOWN');
        }
        // A bare "دينار", "ليرة", etc. remains ambiguous and must not
        // be posted as SAR even if no specific country was readable.
        if (RegExp(r'(?<![\\u0600-\\u06FF])(?:دينار|ليره|دولار|روبيه|'
           r'كرونه|فرنك|راند|رينغيت|يوان|وون|بات|بيزو|تاكا|ين)'
           r'(?![\\u0600-\\u06FF])').hasMatch(namedAction) &&
            RegExp(r'[0-9]').hasMatch(namedAction) &&
            !_namedAdjacentAmount.hasMatch(namedAction)) {
          found.add('UNKNOWN');
        }
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
        if (separator==',' && fraction.length==3 && digits==0 &&
            RegExp(r'^[0-9]{1,3}$').hasMatch(parts.first)) {
          // JPY/KRW cannot represent fractional units. A lone 1,234
          // therefore has one unambiguous interpretation: 1234 units.
          value=parts.first+fraction;
        } else {
          if (fraction.length==3 && (digits<3 || separator==',')) {
            // 1,234 in a fractional currency is locale-ambiguous.
            return null;
          }
          if (fraction.length>digits || digits==0) {
            return null;
          }
          value=parts.first+'.'+fraction;
        }
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
    final normalized=_normalizeArabic(_westernDigits(raw));
    final footer=RegExp(
      r'available balance|remaining balance|current balance|'
      r'\bbalance\b|الرصيد|المتاح|commission|service fee|'
      r'fee amount|رسوم|ضريبة|vat\b',
      caseSensitive:false).firstMatch(normalized);
    final action=footer==null?normalized:normalized.substring(0,footer.start);
    final escaped=currency=='SAR'?
      r'(?:SAR|SR|ريال(?:\s+سعودي)?|ر\.?\s*س\.?|﷼|⃁)':
      currency=='EGP'?
      r'(?:EGP|ج\.م|جنيه(?:\s+مصري)?)':
      currency=='AED'?
      r'(?:AED|د\.إ|درهم(?:\s+إماراتي)?)':
      currency=='EUR'?r'(?:EUR|€)':
      currency=='GBP'?r'(?:GBP|£)':
      currency=='INR'?r'(?:INR|₹)':RegExp.escape(currency);
    final localizedAliases=_arabicNames.entries
        .where((entry)=>entry.value==currency)
        .map((entry)=>RegExp.escape(entry.key)).join('|');
    final acceptedCurrency=localizedAliases.isEmpty?escaped:
        '(?:'+escaped+'|'+localizedAliases+')';
    // Explicit codes only: do not treat a random numeral, card or reference
    // as a financial amount. Currency may touch the number on either side.
    final pattern=r'([0-9][0-9,.]{0,20})(?![0-9,.])';
    final before=RegExp('(?<![A-Za-z])'+acceptedCurrency+r'\s*[:：]?\s*'+pattern,
      caseSensitive:false);
    final after=RegExp(pattern+r'\s*'+acceptedCurrency+r'(?![A-Za-z])',
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
