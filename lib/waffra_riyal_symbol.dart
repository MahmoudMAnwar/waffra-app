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
    if (english || currencyCode != 'SAR') {
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

/// Inline money displays only. Do not modify ordinary prose, bank SMS,
/// stored strings, editable fields or currency codes used in API requests.
List<InlineSpan>? waffraMoneyCurrencySpans(String input, {
  required bool english, required TextStyle style,
}) {
  final matches = RegExp(
      r'(?:SAR|SR|ر\.?\s*س\.?|ريال(?:\s+سعودي)?|﷼|⃁)',
      caseSensitive: false).allMatches(input);
  final result = <InlineSpan>[];
  var from = 0;
  var converted = false;
  for (final match in matches) {
    final before = input.substring(0, match.start);
    final after = input.substring(match.end);
    // Must be adjacent to the displayed amount; a sentence such as
    // "كل ريال تحسب له حساب" is not an amount and stays untouched.
    final followsAmount = RegExp(
        r'[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.٬٫]*\s*$').hasMatch(before);
    final precedesAmount = RegExp(
        r'^\s*[+\-]?[0-9٠-٩۰-۹]').hasMatch(after);
    if (!followsAmount && !precedesAmount) continue;
    if (match.start > from) {
      result.add(TextSpan(text: input.substring(from, match.start)));
    }
    result.add(english
        ? const TextSpan(text: 'SAR')
        : WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: WaffraCurrencyMark(
                english: false,
                size: (style.fontSize ?? 16) * .9,
                color: style.color)));
    from = match.end;
    converted = true;
  }
  if (!converted) return null;
  if (from < input.length) result.add(TextSpan(text: input.substring(from)));
  return result;
}
