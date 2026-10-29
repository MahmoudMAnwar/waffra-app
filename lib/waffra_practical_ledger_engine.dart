/// Pure, read-only financial tools. No access to cloud, bank SMS or stores.
class WaffraPracticalEntry {
  const WaffraPracticalEntry({
    required this.id, required this.title, required this.category,
    required this.amount, required this.income, required this.date,
    this.notes = '', this.hasAttachment = false,
  });
  final String id, title, category, notes;
  final double amount;
  final bool income, hasAttachment;
  final DateTime date;
  int? get minor {
    if (!amount.isFinite || amount < 0 || amount > 1000000000000) return null;
    final cents = amount * 100;
    if ((cents - cents.round()).abs() > 0.000001) return null;
    return cents.round();
  }
}

enum WaffraHealthIssueKind {
  duplicateId, possibleDuplicate, missingCategory, invalidAmount
}
class WaffraHealthIssue {
  const WaffraHealthIssue(this.kind, this.entryId);
  final WaffraHealthIssueKind kind;
  final String entryId;
}

class WaffraDataHealth {
  const WaffraDataHealth._();
  static String normalized(String raw) => raw.trim().toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// These are suggestions only. Nothing is edited, deleted or uploaded.
  static List<WaffraHealthIssue> inspect(Iterable<WaffraPracticalEntry> rows) {
    final issues = <WaffraHealthIssue>[];
    final seenIds = <String>{};
    final candidates = <String, List<WaffraPracticalEntry>>{};
    for (final item in rows) {
      if (item.id.trim().isEmpty || !seenIds.add(item.id)) {
        issues.add(WaffraHealthIssue(WaffraHealthIssueKind.duplicateId, item.id));
      }
      final cents = item.minor;
      if (cents == null) {
        issues.add(WaffraHealthIssue(WaffraHealthIssueKind.invalidAmount, item.id));
      }
      if (normalized(item.category).isEmpty || normalized(item.category) == 'أخرى' ||
          normalized(item.category) == 'uncategorized') {
        issues.add(WaffraHealthIssue(WaffraHealthIssueKind.missingCategory, item.id));
      }
      final name = normalized(item.title);
      if (cents != null && name.isNotEmpty) {
        final key = '$name:$cents:${item.income}';
        final previous = candidates.putIfAbsent(key, () => []);
        if (previous.any((older) => older.id != item.id &&
            older.date.difference(item.date).inHours.abs() <= 48)) {
          issues.add(WaffraHealthIssue(WaffraHealthIssueKind.possibleDuplicate, item.id));
        }
        previous.add(item);
      }
    }
    return List<WaffraHealthIssue>.unmodifiable(issues);
  }
}

class WaffraLedgerSearch {
  const WaffraLedgerSearch._();
  static List<WaffraPracticalEntry> find(
    Iterable<WaffraPracticalEntry> entries, {
    String query = '', DateTime? start, DateTime? end,
    bool? income, bool? attachment, double? minimum, double? maximum,
  }) {
    if ((minimum != null && (!minimum.isFinite || minimum < 0)) ||
        (maximum != null && (!maximum.isFinite || maximum < 0)) ||
        (minimum != null && maximum != null && minimum > maximum)) {
      throw ArgumentError('Invalid search range.');
    }
    final q = WaffraDataHealth.normalized(query);
    final found = <WaffraPracticalEntry>[];
    for (final e in entries) {
      if (income != null && e.income != income) continue;
      if (attachment != null && e.hasAttachment != attachment) continue;
      if (start != null && e.date.isBefore(DateTime(start.year, start.month, start.day))) continue;
      if (end != null && !e.date.isBefore(DateTime(end.year, end.month, end.day + 1))) continue;
      if (minimum != null && e.amount < minimum) continue;
      if (maximum != null && e.amount > maximum) continue;
      if (q.isNotEmpty && ![e.title, e.category, e.notes, e.amount.toStringAsFixed(2)]
          .any((text) => WaffraDataHealth.normalized(text).contains(q))) continue;
      found.add(e);
    }
    found.sort((a, b) => b.date.compareTo(a.date));
    return List<WaffraPracticalEntry>.unmodifiable(found);
  }
}

class WaffraMonthClosePreview {
  const WaffraMonthClosePreview({
    required this.incomeMinor, required this.expenseMinor,
    required this.transactionCount, required this.openingMinor,
  });
  final int incomeMinor, expenseMinor, transactionCount, openingMinor;
  int get netMinor => incomeMinor - expenseMinor;
  int get expectedCloseMinor => openingMinor + netMinor;
  int differenceMinor(int actualCloseMinor) => actualCloseMinor - expectedCloseMinor;
}

/// Preview only: never persist a monthly closure outside verified SQLCipher.
class WaffraMonthlyClose {
  const WaffraMonthlyClose._();
  static WaffraMonthClosePreview preview(
    Iterable<WaffraPracticalEntry> entries, {
    required int year, required int month, required int openingMinor,
  }) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12) {
      throw ArgumentError('Invalid month');
    }
    var income = 0, expense = 0, count = 0;
    for (final e in entries) {
      if (e.date.year != year || e.date.month != month) continue;
      final cents = e.minor;
      if (cents == null) throw StateError('Invalid amount prevents closing.');
      count++;
      if (e.income) { income += cents; } else { expense += cents; }
    }
    return WaffraMonthClosePreview(
      incomeMinor: income, expenseMinor: expense,
      transactionCount: count, openingMinor: openingMinor,
    );
  }
}

class WaffraReceiptReviewDraft {
  const WaffraReceiptReviewDraft({
    required this.amount, required this.merchant, required this.date,
  });
  final double amount;
  final String merchant;
  final DateTime date;
  bool get isValid => amount.isFinite && amount > 0 &&
    amount <= 1000000000000 &&
    ((amount * 100) - (amount * 100).round()).abs() < 0.000001 &&
    merchant.trim().isNotEmpty && merchant.runes.length <= 250;
}
