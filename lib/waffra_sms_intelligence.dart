import 'dart:math' as math;
import 'waffra_sms_multicurrency_review.dart';

/// Small no-cost, fully offline, *trained* multinomial Bayes intent model.
/// Its training examples are synthetic (never users' SMS); it is not a
/// general-purpose LLM and must abstain on ambiguous/pending notifications.
/// No bank login, API key, network, private SMS storage or text telemetry.
enum WaffraSmsIntent { incoming, outgoing, uncertain }

class WaffraSmsMlSuggestion {
  const WaffraSmsMlSuggestion({
    required this.intent, required this.confidence,
    this.amount, this.currency, this.requiresCurrencyReview = false,
  });
  final WaffraSmsIntent intent;
  final double confidence;
  final double? amount;
  final String? currency;
  final bool requiresCurrencyReview;
  bool get canAutoSuggestSar =>
      intent != WaffraSmsIntent.uncertain && amount != null &&
      amount! > 0 && currency == 'SAR' && !requiresCurrencyReview;
}

abstract final class WaffraSmsIntelligence {
  // Training dataset contains deliberately varied templates from multiple
  // global markets and languages. False generality is avoided with abstain.
  static const _incomeSamples = <String>[
    'Incoming transfer received from another account',
    'Transfer received your account is credited',
    'A bank transfer has arrived in your account',
    'You received money from a contact',
    'Funds credited to your account today',
    'Your salary has been deposited',
    'Payroll payment received',
    'Salary credit processed',
    'Direct deposit has been received',
    'Refund credited after merchant return',
    'Cash deposit was successful',
    'Incoming ACH deposit received',
    'Wire transfer incoming payment',
    'Credit advice funds received',
    'A payment was received into your wallet',
    'Deposit successful credited your balance',
    'حوالة واردة الى حسابك',
    'تم ايداع مبلغ الى حسابك',
    'استلام تحويل بنكي وارد',
    'تم اضافة راتب الى حسابك',
    'استرداد مبلغ عملية شراء',
    'تم ايداع الراتب الشهري',
    'رصيدك تم ايداع مبلغ فيه',
    'استلمت حوالة من حساب اخر',
    'تحويل وارد تم استلامه',
    'ايداع نقدي تم بنجاح',
    'Virement reçu sur votre compte',
    'Vous avez reçu un paiement',
    'Votre compte a été crédité',
    'Salaire versé sur votre compte',
    'Remboursement reçu sur le compte',
    'Transfert entrant reçu',
    'Transferencia recibida en tu cuenta',
    'Has recibido dinero en tu cuenta',
    'Depósito recibido exitosamente',
    'Tu cuenta ha sido abonada',
    'Reembolso recibido por compra',
    'Nómina abonada en tu cuenta',
    'تم استلام تحويل مالي في المحفظة',
    'Incoming NEFT transfer credited',
    'UPI received from another bank',
    'Money added by bank deposit',
    'Transferencia recibida pago recibido',
    'Abono recibido transferencia entrante',
    'Ingreso de dinero recibido a cuenta',
    'Virement reçu dépôt crédité',
    'Your transfer incoming successfully credited',
  ];
  static const _expenseSamples = <String>[
    'Debit card purchase completed',
    'Payment to merchant was successful',
    'You paid a bill with your card',
    'Your account was debited',
    'Funds debited to another account',
    'Outgoing money transfer sent',
    'Bank transfer to another person completed',
    'Card charged for purchase',
    'Cash withdrawal from ATM',
    'Online purchase paid successfully',
    'Direct debit payment completed',
    'Standing order outgoing transfer',
    'Withdrawal processed from account',
    'You sent money through bank transfer',
    'Transfer to merchant has been completed',
    'Outgoing ACH payment completed',
    'تم سحب مبلغ من الحساب',
    'عملية شراء ناجحة بالبطاقة',
    'تم خصم المبلغ من حسابك',
    'دفع فاتورة من الحساب',
    'حوالة صادرة الى مستفيد',
    'تم تحويل مبلغ الى حساب اخر',
    'شراء من نقاط البيع',
    'سداد ناجح للفاتورة',
    'عملية دفع ناجحة',
    'تم ارسال حوالة صادرة',
    'Virement émis de votre compte',
    'Votre compte a été débité',
    'Paiement par carte effectué',
    'Retrait au distributeur effectué',
    'Achat en ligne payé',
    'Transfert sortant effectué',
    'Transferencia enviada a otro banco',
    'Pago realizado correctamente',
    'Compra con tarjeta aprobada',
    'Retiro de efectivo en cajero',
    'Tu cuenta ha sido debitada',
    'Dinero enviado desde tu cuenta',
    'UPI payment sent successfully',
    'NEFT transfer sent to beneficiary',
    'Card payment charged your bank account',
    'تم خصم عملية بطاقة من الرصيد',
    'Transferencia enviada dinero enviado',
    'Débito tarjeta compra aprobada',
    'Paiement effectué virement émis',
    'Your account spent USD amount',
    'You spent money on a card purchase',
    'Card spending charge completed',
    'تم سحب المبلغ بنجاح',
    'سحب من الحساب الآن',
  ];

  static final _model = _TinySmsIntentBayes(
    incoming: _incomeSamples, outgoing: _expenseSamples);

  static String normalize(String text) => text.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll('\u00a0', ' ');

  static bool isPendingOrUnconfirmed(String raw) {
    final s = normalize(raw);
    return RegExp(
      r'\b(?:otp|one.time.password|verification.code|authorization.hold|pre.?auth|declined|rejected|failed|pending|unsuccessful|cancelled|canceled)\b'
      r'|رمز التحقق|رمز تفعيل|كلمه المرور|معلقه|معلق|مرفوض|فشلت|فاشله|غير ناجحه|لم تتم',
      caseSensitive: false).hasMatch(s);
  }

  static WaffraSmsMlSuggestion classify(String raw) {
    if (raw.trim().isEmpty || isPendingOrUnconfirmed(raw)) {
      return const WaffraSmsMlSuggestion(
        intent: WaffraSmsIntent.uncertain, confidence: 0);
    }
    final text = normalize(raw);
    final header = text.split(RegExp(r'[\r\n]')).first.trim();
    // Limit classification to the actual action, never remaining balance,
    // customer service disclaimers, or a second unrelated transaction.
    final action = header.length > 220 ? header.substring(0, 220) : header;
    final hasAction = RegExp(
      r'(?:credited|received|deposit|refund|reversal|salary|payroll|inbound|incoming|'
      r'debited|withdrawal|purchase|spent|payment|transfer|sent|outgoing|charge|paid|'
      r'حوال|تحويل|سحب|ايداع|شراء|خصم|راتب|استلام|استرداد|دفع|وارد|صادر|'
      r'virement|reçu|recu|crédité|credite|débité|debite|paiement|retrait|'
      r'transferencia|recibida|enviada|abonada|debitada|deposito|depósito|pago|compra|retiro|'
      r'upi|neft)',
      caseSensitive: false).hasMatch(action);
    if (!hasAction) {
      return const WaffraSmsMlSuggestion(
        intent: WaffraSmsIntent.uncertain, confidence: 0);
    }

    // Opposing verbs in one header (e.g. "transfer from ... to ...") must
    // not be guessed into a ledger transaction based on word probabilities.
    final outgoing = RegExp(
      r'\b(?:sent|outgoing|debited|withdrawal|purchase|paid|payment|charged|'
      r'enviada|débitée|debite|pago|compra)\b'
      r'|حواله صاد|تحويل صادر|تم الخصم|سحب|شراء|دفع').hasMatch(action);
    final incoming = RegExp(
      r'\b(?:received|incoming|credited|deposit|refund|salary|payroll|'
      r'recibida|crédité|credite|abonada|reçu|recu)\b'
      r'|حواله وارد|تحويل وارد|تم الايداع|راتب|استلام').hasMatch(action);
    if (incoming && outgoing) {
      return const WaffraSmsMlSuggestion(
        intent: WaffraSmsIntent.uncertain, confidence: 0);
    }

    final score = _model.score(action);
    final confidence = math.max(score.incomingProbability,
        1 - score.incomingProbability);
    final recognized = confidence >= 0.84 &&
        score.logOdds.abs() >= 1.6;
    final intent = !recognized
        ? WaffraSmsIntent.uncertain
        : score.incomingProbability > 0.5
          ? WaffraSmsIntent.incoming : WaffraSmsIntent.outgoing;
    final suggestion = _extractMoney(raw);
    return WaffraSmsMlSuggestion(
      intent: intent, confidence: confidence,
      amount: suggestion?.$1, currency: suggestion?.$2,
      // Global currencies are deliberately NOT stored under a SAR label.
      requiresCurrencyReview: suggestion != null && suggestion.$2 != 'SAR',
    );
  }

  static String _englishDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    return input.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
      final digit = match.group(0)!;
      final ar = arabic.indexOf(digit);
      return (ar >= 0 ? ar : persian.indexOf(digit)).toString();
    }).replaceAll('٫', '.').replaceAll('٬', ',');
  }

  static String? _currencyFor(String text) {
    final upper = text.toUpperCase();
    final named = RegExp(
      r'\b(?:SAR|SR|USD|EUR|GBP|AED|EGP|KWD|QAR|BHD|OMR|INR|JPY|CAD|AUD)\b'
      r'|ريال(?:\s+سعودي)?|ر\.?\s?س|جنيه(?:\s+مصري)?|درهم(?:\s+اماراتي)?',
      caseSensitive: false).firstMatch(upper);
    if (named != null) {
      final v = named.group(0)!;
      if (v.contains('ريال') || v.contains('ر.س')) return 'SAR';
      if (v.contains('جنيه')) return 'EGP';
      if (v.contains('درهم')) return 'AED';
      return v.toUpperCase() == 'SR' ? 'SAR' : v.toUpperCase();
    }
    if (text.contains('€')) return 'EUR';
    if (text.contains('£')) return 'GBP';
    if (text.contains('₹')) return 'INR';
    if (text.contains(r'$')) return 'USD'; // Unmarked $ is only a suggestion.
    return null;
  }

  static double? _parseAmount(String raw) {
    var s = _englishDigits(raw).replaceAll(RegExp(r'\s'), '');
    final comma = s.lastIndexOf(','), dot = s.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      s = comma > dot
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (comma >= 0) {
      s = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)
          ? s.replaceAll(',', '') : s.replaceAll(',', '.');
    } else if (dot >= 0 &&
        RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      if (s.split('.').length == 2) return null;
      s = s.replaceAll('.', '');
    }
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(s)) return null;
    final result = double.tryParse(s);
    if (result == null || !result.isFinite || result <= 0 ||
        result > 1000000000) return null;
    return (result * 100).round() / 100;
  }

  static (double, String)? _extractMoney(String text) {
    // Shared ISO codes/precision: trained intent and SMS review must agree.
    final strict=WaffraSmsCurrencies.originalAmount(text);
    if(strict!=null)return (strict.amount,strict.currency);
    final discovered=WaffraSmsCurrencies.currenciesForMessage(text);
    // Only a single explicit Amount SAR line may bypass an overly strict
    // generic lexer; never guess currency from merchant, balance or card ID.
    final labelled=RegExp(
      r'^\s*(?:Amount|Amt)\s*[:：]?\s*SAR\s+([0-9]{1,9}(?:\.[0-9]{1,2})?)\s*$',
      multiLine:true,caseSensitive:false,
    ).allMatches(_englishDigits(text)).toList();
    if(labelled.length==1&&!discovered.any((code)=>code!='SAR')&&
        !RegExp(r'\b(?:USD|AED|EUR|EGP|GBP|JOD|KWD|QAR|BHD|OMR)\b',
          caseSensitive:false).hasMatch(text)){
      final verified=_parseAmount(labelled.single.group(1)!);
      if(verified!=null)return (verified,'SAR');
    }
    if(discovered.isNotEmpty)return null;
    final clean = _englishDigits(text);
    final pattern = RegExp(
      r'(?:\b(?:SAR|SR|USD|EUR|GBP|AED|EGP|KWD|QAR|BHD|OMR|INR|JPY|CAD|AUD)\b|[$€£₹]|ريال|جنيه|درهم)'
      r'\s*[:：]?\s*([0-9][0-9,.]{0,16})'
      r'|([0-9][0-9,.]{0,16})\s*(?:\b(?:SAR|SR|USD|EUR|GBP|AED|EGP|KWD|QAR|BHD|OMR|INR|JPY|CAD|AUD)\b|[$€£₹]|ريال|جنيه|درهم)',
      caseSensitive: false);
    for (final line in clean.split(RegExp(r'[\r\n]+'))) {
      final lower = normalize(line);
      if (RegExp(
        r'balance|available|الرصيد|رصيدك|المتاح|fee\b|رسوم|ضريبه|tax\b|vat\b|'
        r'saldo\s+(?:disponible|actual)|solde\s+(?:disponible|actuel)',
      ).hasMatch(lower)) continue;
      for (final match in pattern.allMatches(line)) {
        final number = _parseAmount(match.group(1) ?? match.group(2) ?? '');
        final currency = _currencyFor(match.group(0)!);
        if (number != null && currency != null) return (number, currency);
      }
    }
    return null;
  }
}

class _TinySmsIntentBayes {
  _TinySmsIntentBayes({
    required List<String> incoming,
    required List<String> outgoing,
  }) {
    for (final sample in incoming) _learn(sample, true);
    for (final sample in outgoing) _learn(sample, false);
  }

  final _positive = <String, int>{};
  final _negative = <String, int>{};
  var _positiveTerms = 0, _negativeTerms = 0;
  static const _stopwords = <String>{
    'your','account','with','from','into','today','been','has','the',
    'bank','another','tu','cuenta','de','en','por','sur','votre','vous',
    'compte','une','des','dans','من','علي','حسابك','حساب','مبلغ','الى',
    'تم','بنجاح','عبر','عملية','المالي','dinero','virement','transferencia',
  };
  static const _actionWords = <String>{
    'received','incoming','credited','deposit','refund','salary','payroll',
    'credit','استلام','وارد','ايداع','راتب','استرداد',
    'reçu','recu','crédité','credite','recibida','abonada','ingreso','abono',
    'sent','outgoing','debited','withdrawal','purchase','paid','payment',
    'spent','charge','charged','خصم','سحب','شراء','صادر','دفع',
    'enviada','debitada','compra','pago','débitée','debite','retrait','émis',
  };
  Set<String> _features(String sentence) {
    return RegExp(r'[a-zà-ÿ\u0600-\u06FF]+')
        .allMatches(WaffraSmsIntelligence.normalize(sentence))
        .map((m) => m.group(0)!)
        .where((w) => w.length >= 3)
        .toSet();
  }

  void _learn(String sample, bool positive) {
    for (final word in _features(sample)) {
      final map = positive ? _positive : _negative;
      map[word] = (map[word] ?? 0) + 1;
      if (positive) { _positiveTerms++; } else { _negativeTerms++; }
    }
  }

  ({double logOdds, double incomingProbability}) score(String sentence) {
    final terms = _features(sentence);
    final vocabSize = <String>{..._positive.keys, ..._negative.keys}.length;
    double logOdds = 0;
    for (final word in terms) {
      // Ignore generic bank metadata, proper nouns and unseen merchants.
      // Direction-bearing verbs are learned signals with greater weight.
      if (_stopwords.contains(word) ||
          (!_positive.containsKey(word) && !_negative.containsKey(word))) continue;
      final pos = (_positive[word] ?? 0) + 1;
      final neg = (_negative[word] ?? 0) + 1;
      final learnedEvidence = math.log(pos / (_positiveTerms + vocabSize)) -
          math.log(neg / (_negativeTerms + vocabSize));
      logOdds += (_actionWords.contains(word) ? 2.8 : 1) * learnedEvidence;
    }
    final incomingProbability = logOdds > 40 ? 1.0 :
        logOdds < -40 ? 0.0 : 1 / (1 + math.exp(-logOdds));
    return (logOdds: logOdds, incomingProbability: incomingProbability);
  }
}
,
      multiLine:true,caseSensitive:false).allMatches(_englishDigits(text)).toList();
    if(labelled.length==1&&
       !discovered.any((code)=>code!='SAR')&&
       !RegExp(r'\b(?:USD|AED|EUR|EGP|GBP|JOD|KWD|QAR|BHD|OMR)\b',
          caseSensitive:false).hasMatch(text)){
      final verified=_parseAmount(labelled.single.group(1)!);
      if(verified!=null)return (verified,'SAR');
    }
    if(discovered.isNotEmpty)return null;
    final clean = _englishDigits(text);
    final pattern = RegExp(
      r'(?:\b(?:SAR|SR|USD|EUR|GBP|AED|EGP|KWD|QAR|BHD|OMR|INR|JPY|CAD|AUD)\b|[$€£₹]|ريال|جنيه|درهم)'
      r'\s*[:：]?\s*([0-9][0-9,.]{0,16})'
      r'|([0-9][0-9,.]{0,16})\s*(?:\b(?:SAR|SR|USD|EUR|GBP|AED|EGP|KWD|QAR|BHD|OMR|INR|JPY|CAD|AUD)\b|[$€£₹]|ريال|جنيه|درهم)',
      caseSensitive: false);
    for (final line in clean.split(RegExp(r'[\r\n]+'))) {
      final lower = normalize(line);
      if (RegExp(
        r'balance|available|الرصيد|رصيدك|المتاح|fee\b|رسوم|ضريبه|tax\b|vat\b|'
        r'saldo\s+(?:disponible|actual)|solde\s+(?:disponible|actuel)',
      ).hasMatch(lower)) continue;
      for (final match in pattern.allMatches(line)) {
        final number = _parseAmount(match.group(1) ?? match.group(2) ?? '');
        final currency = _currencyFor(match.group(0)!);
        if (number != null && currency != null) return (number, currency);
      }
    }
    return null;
  }
}

class _TinySmsIntentBayes {
  _TinySmsIntentBayes({
    required List<String> incoming,
    required List<String> outgoing,
  }) {
    for (final sample in incoming) _learn(sample, true);
    for (final sample in outgoing) _learn(sample, false);
  }

  final _positive = <String, int>{};
  final _negative = <String, int>{};
  var _positiveTerms = 0, _negativeTerms = 0;
  static const _stopwords = <String>{
    'your','account','with','from','into','today','been','has','the',
    'bank','another','tu','cuenta','de','en','por','sur','votre','vous',
    'compte','une','des','dans','من','علي','حسابك','حساب','مبلغ','الى',
    'تم','بنجاح','عبر','عملية','المالي','dinero','virement','transferencia',
  };
  static const _actionWords = <String>{
    'received','incoming','credited','deposit','refund','salary','payroll',
    'credit','استلام','وارد','ايداع','راتب','استرداد',
    'reçu','recu','crédité','credite','recibida','abonada','ingreso','abono',
    'sent','outgoing','debited','withdrawal','purchase','paid','payment',
    'spent','charge','charged','خصم','سحب','شراء','صادر','دفع',
    'enviada','debitada','compra','pago','débitée','debite','retrait','émis',
  };
  Set<String> _features(String sentence) {
    return RegExp(r'[a-zà-ÿ\u0600-\u06FF]+')
        .allMatches(WaffraSmsIntelligence.normalize(sentence))
        .map((m) => m.group(0)!)
        .where((w) => w.length >= 3)
        .toSet();
  }

  void _learn(String sample, bool positive) {
    for (final word in _features(sample)) {
      final map = positive ? _positive : _negative;
      map[word] = (map[word] ?? 0) + 1;
      if (positive) { _positiveTerms++; } else { _negativeTerms++; }
    }
  }

  ({double logOdds, double incomingProbability}) score(String sentence) {
    final terms = _features(sentence);
    final vocabSize = <String>{..._positive.keys, ..._negative.keys}.length;
    double logOdds = 0;
    for (final word in terms) {
      // Ignore generic bank metadata, proper nouns and unseen merchants.
      // Direction-bearing verbs are learned signals with greater weight.
      if (_stopwords.contains(word) ||
          (!_positive.containsKey(word) && !_negative.containsKey(word))) continue;
      final pos = (_positive[word] ?? 0) + 1;
      final neg = (_negative[word] ?? 0) + 1;
      final learnedEvidence = math.log(pos / (_positiveTerms + vocabSize)) -
          math.log(neg / (_negativeTerms + vocabSize));
      logOdds += (_actionWords.contains(word) ? 2.8 : 1) * learnedEvidence;
    }
    final incomingProbability = logOdds > 40 ? 1.0 :
        logOdds < -40 ? 0.0 : 1 / (1 + math.exp(-logOdds));
    return (logOdds: logOdds, incomingProbability: incomingProbability);
  }
}
