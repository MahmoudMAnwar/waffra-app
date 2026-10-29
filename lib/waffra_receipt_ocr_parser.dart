/// Deterministic, offline receipt-text interpretation. No persistence or network.
/// Suggestions must be reviewed before any user-confirmed finance action.
class WaffraReceiptOcrFields {
  const WaffraReceiptOcrFields({
    required this.rawText, this.merchant, this.amount, this.date,
  });

  final String rawText;
  final String? merchant;
  final double? amount;
  final DateTime? date;

  bool get hasSuggestions =>
      merchant != null || amount != null || date != null;
}

abstract final class WaffraReceiptOcrParser {
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String westernDigits(String input) {
    return input.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
      final character = match.group(0)!;
      final arabic = _arabicDigits.indexOf(character);
      final index = arabic >= 0 ? arabic : _persianDigits.indexOf(character);
      return index.toString();
    });
  }

  static double? amountFromText(String source) {
    var value = westernDigits(source)
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();

    final dot = value.lastIndexOf('.');
    final comma = value.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      final decimalIsDot = dot > comma;
      value = decimalIsDot
          ? value.replaceAll(',', '')
          : value.replaceAll('.', '').replaceAll(',', '.');
    } else if (comma >= 0) {
      value = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(value)
          ? value.replaceAll(',', '')
          : value.replaceAll(',', '.');
    } else if (dot >= 0 &&
        RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(value)) {
      // Reject ambiguous one-group .000 values; preserve thousands with
      // two or more grouping separators, never invent receipt decimals.
      if (value.split('.').length == 2) return null;
      value = value.replaceAll('.', '');
    }

    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
    final number = double.tryParse(value);
    if (number == null || !number.isFinite || number <= 0 || number > 1e9) {
      return null;
    }
    final cents = number * 100;
    if ((cents - cents.round()).abs() > 0.00001) return null;
    return cents.round() / 100;
  }

  static DateTime? _date(String source) {
    final text = westernDigits(source);
    final matches = RegExp(r'(?<!\d)(\d{1,4})[\/.\-](\d{1,2})[\/.\-](\d{2,4})(?!\d)')
        .allMatches(text);
    for (final match in matches) {
      final first = int.parse(match.group(1)!);
      final middle = int.parse(match.group(2)!);
      final last = int.parse(match.group(3)!);
      int year, month, day;
      if (match.group(1)!.length == 4) {
        year = first; month = middle; day = last;
      } else {
        day = first; month = middle;
        year = last < 100 ? 2000 + last : last;
        if (month > 12 && day <= 12) {
          final swap = month; month = day; day = swap;
        }
      }
      if (year < 2010 || year > DateTime.now().year + 1 ||
          month < 1 || month > 12 || day < 1 || day > 31) continue;
      final candidate = DateTime(year, month, day);
      if (candidate.year == year && candidate.month == month &&
          candidate.day == day) {
        return candidate;
      }
    }
    return null;
  }

  static bool _hasAny(String text, List<String> tokens) =>
      tokens.any(text.contains);

  static WaffraReceiptOcrFields parse(String recognizedText) {
    final raw = recognizedText.trim();
    final lines = raw.split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return WaffraReceiptOcrFields(rawText: raw);

    // Bank screenshot ≠ one receipt. Never select a phone/card ID as the
    // invoice amount or the bank sender as the merchant. A separate bank
    // screenshot review flow can segment and review individual messages.
    final bankAction = RegExp(
      r'شراء\\s*(?:pos|نقاط)|\\bpos\\b|card\\s+purchase|'
      r'حوالة\\s+واردة|تحويل\\s+وارد|salary\\s+credit',
      caseSensitive: false).hasMatch(raw);
    final bankContext = RegExp(
      r'\\b(?:SAR|SR|Bank|Mada)\\b|ريال|مدى|الراجحي',
      caseSensitive: false).hasMatch(raw);
    if (bankAction && bankContext) {
      return WaffraReceiptOcrFields(rawText: raw);
    }

    DateTime? date;
    for (final line in lines) {
      date ??= _date(line);
    }

    String? merchant;
    for (final original in lines.take(9)) {
      final line = original.replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = line.toLowerCase();
      if (line.length < 3 || line.length > 95 ||
          !RegExp(r'[A-Za-z\u0600-\u06FF]{2}').hasMatch(line) ||
          RegExp(r'^\W*\d').hasMatch(westernDigits(line)) ||
          _hasAny(lower, [
            'فاتورة', 'ضريبية', 'الرقم الضريبي', 'الرقم المرجعي',
            'رقم السجل', 'المجموع', 'الإجمالي', 'المبلغ', 'الصافي',
            'receipt', 'invoice', 'vat', 'tax ', 'total', 'date',
            'time:', 'cashier', 'order no', 'رقم الطلب', 'سعر',
            'bank', 'الراجحي', 'البنك', 'مصرف', 'account', 'sender',
          ])) {
        continue;
      }
      merchant = line;
      break;
    }

    double? bestAmount;
    var bestScore = -100000;
    final candidatePattern = RegExp(
        r'\d{1,9}(?:[,.]\d{3})*(?:[,.]\d{1,2})?');
    for (var i = 0; i < lines.length; i++) {
      final rawLine = westernDigits(lines[i])
          .replaceAll('٫', '.').replaceAll('٬', ',');
      final lower = rawLine.toLowerCase();
      final total = _hasAny(lower, [
        'الإجمالي', 'الاجمالي', 'المجموع', 'الصافي', 'المستحق',
        'المبلغ المطلوب', 'المدفوع', 'total', 'amount due',
        'amount paid', 'paid amount', 'grand total',
      ]);
      final nonTotal = _hasAny(lower, [
        'subtotal', 'sub total', 'قبل الضريبة', 'ضريبة',
        'tax', 'vat', 'خصم', 'discount', 'الرقم الضريبي',
        'رقم الفاتورة', 'invoice number', 'invoice no',
        'رقم الطلب', 'order number', 'change', 'الباقي',
      ]);
      if (!total && _date(rawLine) != null) continue;
      // Without a TOTAL label we cannot safely distinguish an invoice
      // price from account numbers, receipt references or phone numbers.
      final score = (total ? 100 : -100) - (nonTotal ? 130 : 0);
      if (score < 0) continue;
      for (final match in candidatePattern.allMatches(rawLine)) {
        if (match.start > 0 &&
            (rawLine[match.start - 1] == '-' ||
             rawLine[match.start - 1] == '−')) continue;
        final value = amountFromText(match.group(0)!);
        if (value == null) continue;
        // Invoice IDs and prices alike are guesses without total labels.
        // Prefer the last explicit total, then a plausible largest price.
        if (score > bestScore ||
            (score == bestScore && (bestAmount == null ||
                (total ? true : value > bestAmount)))) {
          bestScore = score;
          bestAmount = value;
        }
      }
    }

    return WaffraReceiptOcrFields(
      rawText: raw, merchant: merchant, amount: bestAmount, date: date);
  }
}
