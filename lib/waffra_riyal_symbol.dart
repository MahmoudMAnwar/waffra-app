import 'package:flutter/material.dart';

/// Presentation only: the original user-approved Saudi Riyal PNG.
const String waffraRiyalAsset = 'assets/Saudi_Riyal_Symbol-1.png';

/// Never replace foreign-currency units with the Saudi mark.
class WaffraCurrencyMark extends StatelessWidget {
  const WaffraCurrencyMark({
    super.key,
    required this.english,
    this.currencyCode = 'SAR',
    this.arabicLabel = 'ريال',
    this.size = 16,
    this.color,
  });

  final bool english;
  final String currencyCode;
  final String arabicLabel;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    if (currencyCode != 'SAR') {
      return Text(english ? currencyCode : arabicLabel,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: size * .7,
              fontWeight: FontWeight.w700, color: effectiveColor));
    }
    return Image.asset(waffraRiyalAsset, width: size, height: size,
        fit: BoxFit.contain, color: effectiveColor,
        colorBlendMode: BlendMode.srcIn,
        semanticLabel: 'رمز الريال السعودي',
        errorBuilder: (_, __, ___) => Text('ريال',
            style: TextStyle(fontFamily: 'Tajawal',
                fontSize: size * .7, color: effectiveColor)));
  }
}

/// Inline money displays only. Preserve SMS/parser/storage/API originals.
/// Every recognized SAR display amount is an indivisible LTR visual run:
/// official Saudi symbol, a gap, then the signed numeral. This is the same
/// physical left-of-value order in Arabic RTL and English LTR contexts.
List<InlineSpan>? waffraMoneyCurrencySpans(String input, {
  required bool english, required TextStyle style,
}) {
  const number = r'[+\-−]?[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.٬٫]*';
  const unit = r'(?:SAR|SR|ر\.\s*س\.?|ر\s+س\.?|ريال(?:\s+سعودي)?|﷼|⃁)';
  // Currency must be adjacent to a numeral. Whole-word matching is critical:
  // SMS counters such as "497 رسائل" must NEVER become currency amounts.
  final matches = RegExp(
    '(?<!\\p{L})(?:($number)\\s*($unit)|($unit)\\s*($number))(?!\\p{L})',
    caseSensitive: false, unicode: true,
  ).allMatches(input);
  final result = <InlineSpan>[];
  var from = 0;
  for (final match in matches) {
    final numeric = (match.group(1) ?? match.group(4))!.trim();
    if (match.start > from) {
      result.add(TextSpan(text: input.substring(from, match.start)));
    }
    final size = style.fontSize ?? 16;
    result.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          WaffraCurrencyMark(
            english: english, size: size * .9, color: style.color),
          SizedBox(width: size * .24),
          Text(numeric, textDirection: TextDirection.ltr, style: style),
        ]),
      ),
    ));
    from = match.end;
  }
  if (result.isEmpty) return null;
  if (from < input.length) result.add(TextSpan(text: input.substring(from)));
  return result;
}
