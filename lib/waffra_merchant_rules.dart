/// Extracts a conservative merchant identifier from pasted Saudi bank SMS.
/// We learn ONLY after the user manually changes a transaction's category.
/// No message data is uploaded: rules remain in local SharedPreferences.
String? waffraMerchantKey(String raw) {
  final text = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final patterns = <RegExp>[
    RegExp(r'(?:sar|sr|ريال)\s*[0-9]+(?:[.,][0-9]{1,2})?\s+([a-z][a-z\s&._-]{2,32})',
      caseSensitive: false),
    RegExp(r'([a-z][a-z\s&._-]{2,32})\s+(?:sar|sr|ريال)',
      caseSensitive: false),
    RegExp(r'(?:متجر|لدى|عند)\s*[:：]?\s*([\u0621-\u064A][\u0621-\u064A\s]{2,32})'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    var candidate = (match.group(1) ?? '').trim();
    candidate = candidate.replaceAll(RegExp(r'\s+'), ' ');
    final words = candidate.split(' ');
    candidate = words.take(3).join(' ').trim();
    if (candidate.length < 3) continue;
    if (const {'pos', 'mada', 'sar', 'sr', 'عند', 'متجر'}.contains(candidate)) continue;
    return candidate;
  }
  return null;
}
