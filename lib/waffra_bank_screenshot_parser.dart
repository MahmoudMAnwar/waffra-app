/// Conservative, offline bank-image interpretation. Every recognized action is
/// offered for review, including actions whose amounts cannot be trusted.
/// No OCR result is ever authorized to write to the finance ledger.
import 'waffra_receipt_ocr_parser.dart';

class WaffraOcrBankCandidate {
  const WaffraOcrBankCandidate({
    required this.amount,
    required this.income,
    required this.sourceText,
    this.merchant,
    this.date,
  });

  final double amount;
  final bool income;
  final String sourceText;
  final String? merchant;
  final DateTime? date;
}

/// One action in OCR reading order. [amount] is intentionally nullable: a
/// missing or competing amount must be entered by the user, not guessed.
class WaffraOcrBankReviewItem {
  const WaffraOcrBankReviewItem({
    required this.position,
    required this.sourceLine,
    required this.amount,
    required this.income,
    required this.sourceText,
    this.merchant,
    this.date,
  });

  final int position;
  final int sourceLine;
  final double? amount;
  final bool income;
  final String sourceText;
  final String? merchant;
  final DateTime? date;
  bool get needsAmountReview => amount == null;
}

abstract final class WaffraBankScreenshotParser {
  static final _action = RegExp(
    r'(?:شراء\s*(?:pos|نقاط|عبر|بقيمة)?|\bpos\b|card\s+purchase|'
    r'payment\s+at|purchase\s+at|'
    r'حوالة\s+واردة|تحويل\s+وارد|حوالة\s+صادرة|تحويل\s+صادر|'
    r'إيداع|ايداع|سحب\s+نقدي|تم\s+خصم|'
    r'\bcredit\s+transfer\b|\bdebit\s+transfer\b|'
    r'راتب|salary\s+(?:credit|deposit)|'
    r'استرداد\s+مبلغ|refund\s+received)',
    caseSensitive: false,
  );
  static final _incoming = RegExp(
    r'(حوالة\s+واردة|تحويل\s+وارد|إيداع|ايداع|راتب|salary|'
    r'\bcredit\s+transfer\b|refund\s+received|استرداد\s+مبلغ)',
    caseSensitive: false,
  );
  static final _money = RegExp(
    r'(?<![0-9A-Za-z])(?:SAR|SR|ر\.?\s*س|ريال)\s*[:：]?\s*'
    r'((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,7})(?:[.,][0-9]{1,2})?)(?![0-9.,])'
    r'|(?<![0-9])((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,7})'
    r'(?:[.,][0-9]{1,2})?)(?![0-9.,])\s*(?:SAR|SR|ر\.?\s*س|ريال)',
    caseSensitive: false,
  );
  static final _date = RegExp(
    r'(?<![0-9])([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})(?![0-9])',
  );
  static final _excludedLine = RegExp(
    r'balance|رصيد|رقم\s*البطاقة|رقم\s*المرجع|reference|'
    r'account|حساب|متبقي|available|card\s+number',
    caseSensitive: false,
  );
  static final _excludeMerchant = RegExp(
    r'alrajhibank|rajhi\s*bank|الراجحي|الإنماء|الانماء|البنك|bank|'
    r'sar|رصيد|balance|عبر|بطاقة|مدى|mada|visa|mastercard|'
    r'purchase|شراء|pos|الوقت|التاريخ|yesterday|sender|replies|'
    r'رقم|المرجع|reference|invoice|فاتورة|total|إجمالي|'
    r'حوالة|تحويل|إيداع|ايداع|salary|سحب|خصم',
    caseSensitive: false,
  );

  static bool looksLikeBankScreenshot(String text) {
    final normalized = WaffraReceiptOcrParser.westernDigits(text);
    return _action.hasMatch(normalized) &&
        RegExp(
          r'\b(?:SAR|SR|POS|Mada)\b|ريال|مدى|bank|'
          r'الراجحي|تحويل|حوالة|بطاقة|إيداع|ايداع',
          caseSensitive: false,
        ).hasMatch(normalized);
  }

  /// Tesseract can collapse two SMS bubbles into one OCR line. Split at each
  /// independent action marker without changing the order in the image text.
  /// Positions refer to OCR reading order, not pixel bounding boxes.
  static List<String> _orderedLines(String text) {
    final normalized = WaffraReceiptOcrParser.westernDigits(text)
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');
    final lines = <String>[];
    for (final rawLine in normalized.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final anchors = _action.allMatches(line).toList();
      if (anchors.length < 2) {
        lines.add(line);
        continue;
      }
      final leading = line.substring(0, anchors.first.start).trim();
      if (leading.isNotEmpty) lines.add(leading);
      for (var i = 0; i < anchors.length; i++) {
        final segment = line.substring(
          anchors[i].start,
          i + 1 < anchors.length ? anchors[i + 1].start : line.length,
        ).trim();
        if (segment.isNotEmpty) lines.add(segment);
      }
    }
    return lines;
  }

  /// Keeps even unclear action blocks so the rest of the screenshot does not
  /// silently disappear. A block with two different amounts has no prefill.
  static List<WaffraOcrBankReviewItem> reviewItems(String text) {
    final lines = _orderedLines(text);
    final found = <WaffraOcrBankReviewItem>[];
    for (var i = 0; i < lines.length; i++) {
      if (!_action.hasMatch(lines[i])) continue;
      var end = i + 1;
      while (end < lines.length &&
          end < i + 14 &&
          !_action.hasMatch(lines[end])) {
        end++;
      }
      final chunk = lines.sublist(i, end);
      final amounts = <double>[];
      int? amountAt;
      for (var k = 0; k < chunk.length; k++) {
        final line = chunk[k];
        // Do not use a balance, reference, or account/card number even when
        // OCR has placed a currency token next to it.
        if (_excludedLine.hasMatch(line)) continue;
        for (final match in _money.allMatches(line)) {
          final raw = match.group(1) ?? match.group(2);
          if (raw == null) continue;
          final amount = WaffraReceiptOcrParser.amountFromText(raw);
          if (amount != null) {
            amounts.add(amount);
            amountAt ??= k;
          }
        }
      }

      DateTime? date;
      for (final line in chunk) {
        final match = _date.firstMatch(line);
        if (match == null) continue;
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        var year = int.tryParse(match.group(3)!);
        if (day == null || month == null || year == null) continue;
        if (year < 100) year += 2000;
        if (year < 2010 || year > DateTime.now().year + 1) continue;
        final candidate = DateTime(year, month, day);
        if (candidate.year == year &&
            candidate.month == month &&
            candidate.day == day) {
          date = candidate;
          break;
        }
      }

      String? merchant;
      for (var k = (amountAt ?? 0) + 1; k < chunk.length; k++) {
        final line = chunk[k];
        if (line.length > 80 ||
            line.length < 3 ||
            _excludeMerchant.hasMatch(line) ||
            _date.hasMatch(line) ||
            RegExp(r'[0-9]{3,}').hasMatch(line) ||
            !RegExp(r'[A-Za-z\u0600-\u06FF]{3}').hasMatch(line)) {
          continue;
        }
        merchant = line;
        break;
      }
      found.add(WaffraOcrBankReviewItem(
        position: found.length + 1,
        sourceLine: i + 1,
        amount: amounts.length == 1 ? amounts.single : null,
        income: _incoming.hasMatch(chunk.first),
        merchant: merchant,
        date: date,
        sourceText: chunk.join('\n'),
      ));
      i = end - 1;
    }
    return List<WaffraOcrBankReviewItem>.unmodifiable(found);
  }

  /// Backwards-compatible API: only returns single-unambiguous-amount rows.
  static List<WaffraOcrBankCandidate> candidates(String text) =>
      List<WaffraOcrBankCandidate>.unmodifiable(
        reviewItems(text).where((item) => item.amount != null).map(
          (item) => WaffraOcrBankCandidate(
            amount: item.amount!,
            income: item.income,
            sourceText: item.sourceText,
            merchant: item.merchant,
            date: item.date,
          ),
        ),
      );
}
