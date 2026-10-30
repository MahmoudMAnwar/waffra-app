/// Advisory duplicate matcher across a manually entered transaction,
/// a receipt scan and a bank-SMS transaction. A candidate is NEVER discarded
/// automatically: the person must confirm whether two similar purchases are
/// independent transactions.
abstract final class WaffraCrossSourceDuplicateReview {
  static String _identity(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    return text.toLowerCase()
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
          final character = match.group(0)!;
          final ar = arabic.indexOf(character);
          return (ar >= 0 ? ar : persian.indexOf(character)).toString();
        })
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool mightBeSame({
    required String candidateTitle,
    required String candidateCategory,
    required String candidateMerchantKey,
    required double candidateAmount,
    required bool candidateIncome,
    required DateTime candidateDate,
    required String existingTitle,
    required String existingCategory,
    required String existingMerchantKey,
    required double existingAmount,
    required bool existingIncome,
    required DateTime existingDate,
  }) {
    if (candidateIncome != existingIncome ||
        candidateDate.year != existingDate.year ||
        candidateDate.month != existingDate.month ||
        candidateDate.day != existingDate.day ||
        !candidateAmount.isFinite || !existingAmount.isFinite ||
        candidateAmount <= 0 || existingAmount <= 0) return false;

    // Both sides must hold valid two-decimal stored ledger amounts. Do not
    // silently turn two distinct sub-cent values into the same purchase.
    final firstMinor = (candidateAmount * 100).round();
    final otherMinor = (existingAmount * 100).round();
    if ((candidateAmount * 100 - firstMinor).abs() > 1e-7 ||
        (existingAmount * 100 - otherMinor).abs() > 1e-7 ||
        firstMinor != otherMinor) return false;

    final candidateMerchant = _identity(candidateMerchantKey);
    final existingMerchant = _identity(existingMerchantKey);
    if (candidateMerchant.isNotEmpty && existingMerchant.isNotEmpty &&
        candidateMerchant == existingMerchant) return true;

    final candidateName = _identity(candidateTitle);
    final existingName = _identity(existingTitle);
    return candidateName.isNotEmpty && candidateName == existingName &&
        _identity(candidateCategory) == _identity(existingCategory);
  }
}
