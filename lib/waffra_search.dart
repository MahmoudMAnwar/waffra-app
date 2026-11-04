/// Canonical search spelling across all Waffra search fields.
///
/// Only matching changes. Original labels, financial amounts, bank messages,
/// persisted records and user input must NEVER be rewritten or normalized.
String waffraSearchKey(String value) => value
  .trim()
  .toLowerCase()
  .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
  .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
  .replaceAll('ى', 'ي')
  .replaceAll('ی', 'ي')
  .replaceAll('ئ', 'ي')
  .replaceAll('ؤ', 'و')
  .replaceAll('ة', 'ه')
  .replaceAll('ک', 'ك')
  .replaceAll(RegExp(r'\s+'), ' ');

/// Substring lookup works the same for أ, إ, آ and ا.
/// Empty queries show all items; does not alter returned display text.
bool waffraSearchMatches(String value, String query) {
  final needle = waffraSearchKey(query);
  return needle.isEmpty || waffraSearchKey(value).contains(needle);
}

bool waffraSearchAny(Iterable<String> fields, String query) =>
  fields.any((field) => waffraSearchMatches(field, query));
