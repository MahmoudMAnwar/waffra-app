/// M448 account-context rules. All accounting uses integer halalas; changing a
/// selected account is a VIEW decision, never a journal write.
enum WaffraAccountView { all, selected, unassigned }

class WaffraScopedEntry {
  const WaffraScopedEntry({
    required this.id,
    required this.amountMinor,
    required this.income,
    this.accountId,
    this.budgetId,
  });
  final String id;
  final int amountMinor;
  final bool income;
  final String? accountId;
  final String? budgetId;
}

class WaffraBudgetUse {
  const WaffraBudgetUse({
    required this.globalSpentMinor,
    required this.selectedAccountSpentMinor,
    required this.limitMinor,
  });
  final int globalSpentMinor;
  final int selectedAccountSpentMinor;
  final int limitMinor;
  // Alerts MUST use the global numerator, including unassigned expenses.
  bool reached(int percent) =>
      percent > 0 && percent <= 100 &&
      globalSpentMinor * 100 >= limitMinor * percent;
}

class WaffraGoalSource {
  const WaffraGoalSource({
    required this.movementId,
    required this.accountId,
    required this.amountMinor,
    required this.isRelease,
  });
  final String movementId, accountId;
  final int amountMinor;
  final bool isRelease;
}

enum WaffraRecurringAccountChange { thisPaymentOnly, futurePayments }

class WaffraRecurringAccountResolution {
  const WaffraRecurringAccountResolution(this.paymentAccountId,
      this.nextDefaultAccountId);
  final String? paymentAccountId, nextDefaultAccountId;
}

class WaffraSmsAccountDecision {
  const WaffraSmsAccountDecision(this.accountId, this.confident);
  final String? accountId;
  final bool confident;
}

/// Pure rules shared by UI, storage review and regression tests. No fallback
/// to a dashboard header selection is allowed for bank-SMS or recurring posts.
abstract final class WaffraAccountContextPolicy {
  static bool visible(WaffraScopedEntry entry, WaffraAccountView view,
      {String? selectedAccountId}) {
    switch (view) {
      case WaffraAccountView.all:
        return true;
      case WaffraAccountView.unassigned:
        return entry.accountId == null;
      case WaffraAccountView.selected:
        if (selectedAccountId == null || selectedAccountId.isEmpty) {
          throw ArgumentError('Selected account is required.');
        }
        return entry.accountId == selectedAccountId;
    }
  }

  static int balanceDelta(WaffraScopedEntry entry, String accountId) =>
      entry.accountId != accountId
          ? 0
          : (entry.income ? entry.amountMinor : -entry.amountMinor);

  static WaffraBudgetUse budget({
    required Iterable<WaffraScopedEntry> entries,
    required String budgetId,
    required int limitMinor,
    String? selectedAccountId,
  }) {
    if (limitMinor <= 0) throw ArgumentError('Budget limit must be positive.');
    var total = 0, selected = 0;
    for (final entry in entries) {
      if (entry.budgetId != budgetId || entry.income) continue;
      if (entry.amountMinor <= 0) throw StateError('Invalid budget posting.');
      total += entry.amountMinor;
      if (entry.accountId == selectedAccountId &&
          selectedAccountId != null) {
        selected += entry.amountMinor;
      }
    }
    return WaffraBudgetUse(globalSpentMinor: total,
        selectedAccountSpentMinor: selected, limitMinor: limitMinor);
  }

  /// Only an actual, account-sourced goal funding/release affects the bank.
  /// Creating the goal or paying from its already-funded wallet does not.
  static int goalContribution(Iterable<WaffraGoalSource> movements,
      String accountId) {
    var amount = 0;
    final seen = <String>{};
    for (final movement in movements) {
      if (!seen.add(movement.movementId)) {
        throw StateError('A goal movement was counted twice.');
      }
      if (movement.amountMinor <= 0) {
        throw StateError('Invalid goal wallet movement.');
      }
      if (movement.accountId == accountId) {
        amount += movement.isRelease
            ? -movement.amountMinor
            : movement.amountMinor;
      }
    }
    return amount;
  }

  static WaffraRecurringAccountResolution recurringAccount({
    required String? savedDefaultAccountId,
    required String? chosenAccountId,
    required WaffraRecurringAccountChange change,
  }) =>
      WaffraRecurringAccountResolution(
        chosenAccountId,
        change == WaffraRecurringAccountChange.futurePayments
            ? chosenAccountId
            : savedDefaultAccountId,
      );

  static String? _fourDigits(String? source) {
    if (source == null) return null;
    const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
    final normalized = source.runes.map((rune) {
      final ch = String.fromCharCode(rune);
      final a = arabic.indexOf(ch), p = persian.indexOf(ch);
      return a >= 0 ? a.toString() : p >= 0 ? p.toString() : ch;
    }).join();
    return RegExp(r'^[0-9]{4}$').hasMatch(normalized)
        ? normalized : null;
  }

  /// Verified suffixes are explicitly associated with user-created accounts.
  /// Without an exact UNIQUE match, return unassigned. Neither the current
  /// header nor a mere bank name establishes a trustworthy account identity.
  static WaffraSmsAccountDecision matchBankSms({
    required String? sourceSuffix,
    required String? destinationSuffix,
    required bool incoming,
    required bool classifiedIncomeOrExpense,
    required Map<String, String> verifiedSuffixByAccount,
  }) {
    if (!classifiedIncomeOrExpense) {
      return const WaffraSmsAccountDecision(null, false);
    }
    final suffix = _fourDigits(incoming ? destinationSuffix : sourceSuffix);
    if (suffix == null) return const WaffraSmsAccountDecision(null, false);
    final matching = verifiedSuffixByAccount.entries.where(
      (item) => _fourDigits(item.value) == suffix,
    ).toList(growable: false);
    if (matching.length != 1) {
      return const WaffraSmsAccountDecision(null, false);
    }
    return WaffraSmsAccountDecision(matching.single.key, true);
  }
}
