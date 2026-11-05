/// Immutable, non-posting policies shared by the SMS and recurring review UI.
/// A selected header tab is NEVER a substitute for an explicit account choice.

class WaffraBankAccountEvidence {
  const WaffraBankAccountEvidence({
    required this.accountId, required this.bankMarker,required this.lastFour,
  });
  final String accountId,bankMarker,lastFour;
}

class WaffraBankSmsAccountResolution {
  const WaffraBankSmsAccountResolution(this.suggestedAccountId);
  /// Null means "Without account" until the user expressly chooses one.
  final String? suggestedAccountId;
  bool get confidentlyMatched=>suggestedAccountId!=null;
}

abstract final class WaffraBankSmsAccountPolicy {
  static WaffraBankSmsAccountResolution resolve({
    required String smsText,
    required Iterable<WaffraBankAccountEvidence> knownAccounts,
    String? currentlyOpenAccountId,
  }) {
    // The header is intentionally ignored. A bank name by itself, a vague
    // sender, or the final digits by themselves is not ownership evidence.
    final normalized=smsText.toLowerCase();
    final candidates=knownAccounts.where((a) {
      final bank=a.bankMarker.trim().toLowerCase();
      final last=a.lastFour.trim();
      if(bank.isEmpty || last.length!=4 ||
          !RegExp(r'^[0-9]{4}$').hasMatch(last) ||
          a.accountId.trim().isEmpty || !normalized.contains(bank)) {
        return false;
      }
      return RegExp('(?:^|[^0-9])${RegExp.escape(last)}(?![0-9])')
          .hasMatch(normalized);
    }).map((a)=>a.accountId).toSet();
    return WaffraBankSmsAccountResolution(
      candidates.length==1?candidates.single:null,
    );
  }
}

enum WaffraRecurringAccountChangeScope { thisPaymentOnly, futurePayments }

class WaffraRecurringAccountDecision {
  const WaffraRecurringAccountDecision({
    required this.paymentAccountId,required this.nextDefaultAccountId,
  });
  final String? paymentAccountId,nextDefaultAccountId;
}

abstract final class WaffraRecurringAccountPolicy {
  /// The stored recurring default wins over an unrelated header tab.
  /// Changing the reminder never calls this method or moves money.
  static WaffraRecurringAccountDecision decide({
    required String? storedDefaultAccountId,
    required String? explicitlyChosenAccountId,
    required WaffraRecurringAccountChangeScope scope,
    required bool userConfirmed,
  }) {
    if(!userConfirmed)throw StateError('Recurring payment needs approval.');
    if(explicitlyChosenAccountId!=null &&
       explicitlyChosenAccountId.trim().isEmpty) {
      throw ArgumentError('Invalid recurring account.');
    }
    if(storedDefaultAccountId!=null &&
       storedDefaultAccountId.trim().isEmpty) {
      throw StateError('Stored recurring account is invalid.');
    }
    final payment=explicitlyChosenAccountId??storedDefaultAccountId;
    return WaffraRecurringAccountDecision(
      paymentAccountId:payment,
      nextDefaultAccountId:
        scope==WaffraRecurringAccountChangeScope.futurePayments
        ?payment:storedDefaultAccountId,
    );
  }

  /// Persist with the verified recurring finance snapshot + SQL projection,
  /// not with an isolated SharedPreferences write.
  static Map<String,Object?> withNextDefault(
      Map<String,Object?> schedule,WaffraRecurringAccountDecision decision) {
    return Map<String,Object?>.from(schedule)
      ..['defaultAccountId']=decision.nextDefaultAccountId;
  }
}

abstract final class WaffraGoalAccountDebitPolicy {
  /// Account balances are debited only by the current-cash portion of one
  /// verified goal due. Wallet-funded portions are already in the goal wallet.
  static int cashDebitMinor({
    required int totalDueMinor,required int goalWalletPaidMinor,
  }) {
    if(totalDueMinor<0 || goalWalletPaidMinor<0 ||
       goalWalletPaidMinor>totalDueMinor) {
      throw ArgumentError('Invalid goal wallet settlement.');
    }
    return totalDueMinor-goalWalletPaidMinor;
  }
}
