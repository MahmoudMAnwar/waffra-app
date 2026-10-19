/// Text prepared for embedding with Waffra's Tajawal PDF fonts.
///
/// Bank SMS can include the old rial ligature (U+FDFC), the newer Saudi
/// rial sign (U+20C1), invisible direction markers, and emoji/private-use
/// glyphs. These can render as black squares in a generated PDF.
/// This affects PDF presentation only; stored transaction data is unchanged.
String sanitizeWaffraPdfText(String input) {
  final buffer = StringBuffer();
  for (final code in input.runes) {
    if (code == 0x20C1 || code == 0xFDFC) {
      buffer.write(' ريال ');
    } else if (code == 0x066B) {
      buffer.write('.');
    } else if (code == 0x066C) {
      buffer.write(',');
    } else if (code == 0x2013 || code == 0x2014 || code == 0x2212) {
      buffer.write(' - ');
    } else if (code == 0x2018 || code == 0x2019) {
      buffer.write("'");
    } else if (code == 0x201C || code == 0x201D) {
      buffer.write('"');
    } else if (code == 0x2026) {
      buffer.write('...');
    } else if (code == 0x060C || code == 0x061B || code == 0x061F) {
      buffer.writeCharCode(code);
    } else if ((code >= 0x20 && code <= 0x7E) ||
        (code >= 0x0621 && code <= 0x064A) ||
        (code >= 0x0660 && code <= 0x0669) ||
        (code >= 0x06F0 && code <= 0x06F9) ||
        code == 0x0671) {
      buffer.writeCharCode(code);
    } else {
      // Strip control characters, unsupported currency/ligature symbols,
      // emoji, presentation-form glyphs and bidirectional controls.
      buffer.write(' ');
    }
  }
  // Bank templates sometimes glue Latin bank codes, Arabic currency
  // abbreviations and digits into one run (e.g. SARر, من9288, ر15.50).
  // Add safe boundaries before passing text to the RTL PDF renderer.
  var clean = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  clean = clean.replaceAllMapped(
    RegExp(r'([A-Za-z])([\u0621-\u064A\u0671])'),
    (m) => m[1]! + ' ' + m[2]!);
  clean = clean.replaceAllMapped(
    RegExp(r'([\u0621-\u064A\u0671])([A-Za-z])'),
    (m) => m[1]! + ' ' + m[2]!);
  clean = clean.replaceAllMapped(
    RegExp(r'([\u0621-\u064A\u0671])([0-9])'),
    (m) => m[1]! + ' ' + m[2]!);
  clean = clean.replaceAllMapped(
    RegExp(r'([0-9])([\u0621-\u064A\u0671])'),
    (m) => m[1]! + ' ' + m[2]!);
  clean = clean.replaceAllMapped(
    RegExp(r'(^|[\s:;,])ر(?=\s|[0-9]|$)'),
    (m) => m[1]! + 'ريال ');
  // Do not print the same currency twice when the SMS contains SAR and ر.
  clean = clean.replaceAllMapped(
    RegExp(r'\b(SAR|SR)\s+ريال\b',caseSensitive:false),(m)=>m[1]!);
  return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One script-direction-safe line/paragraph of a bank transaction description.
class WaffraPdfTextSegment {
  final String text;
  final bool rtl;
  const WaffraPdfTextSegment(this.text, this.rtl);
}

/// Produce separate widgets for alternating Arabic and Latin / numeric runs.
///
/// The PDF renderer does not consistently display long SMS containing both
/// Arabic and Latin inside one RTL Text widget; direction-per-run fixes that.
List<WaffraPdfTextSegment> splitWaffraPdfText(String raw) {
  final text = sanitizeWaffraPdfText(raw);
  if (text.isEmpty) return const [WaffraPdfTextSegment('لا يوجد وصف', true)];

  final segments = <WaffraPdfTextSegment>[];
  final arabicLetter = RegExp(r'[\u0621-\u064A\u0671]');
  final latinLetter = RegExp(r'[A-Za-z]');
  final numericToken = RegExp(r'^[0-9٠-٩۰-۹][0-9٠-٩۰-۹:/.,+-]*$');

  String current = '';
  bool? currentRtl;
  void emit() {
    if (current.isNotEmpty) {
      segments.add(WaffraPdfTextSegment(current, currentRtl ?? true));
      current = '';
    }
  }

  for (final token in text.split(' ')) {
    if (token.isEmpty) continue;
    final bool rtl;
    if (arabicLetter.hasMatch(token)) {
      rtl = true;
    } else if (latinLetter.hasMatch(token) || numericToken.hasMatch(token)) {
      rtl = false;
    } else {
      rtl = currentRtl ?? true;
    }
    if (currentRtl != null && currentRtl != rtl) emit();
    current = current.isEmpty ? token : '$current $token';
    currentRtl = rtl;
  }
  emit();
  return segments;
}
