/// M220: an in-memory, ordered review of bank messages which were not
/// durably persisted. No bank message content is logged or stored here.
enum WaffraSmsNotSavedReason {
  amountUnrecognized,
  categoryUnresolved,
  alreadySaved,
}

class WaffraSmsNotSavedMessage {
  const WaffraSmsNotSavedMessage({
    required this.sourceIndex,
    required this.message,
    required this.reason,
  });

  final int sourceIndex;
  final String message;
  final WaffraSmsNotSavedReason reason;
}

class WaffraSmsPartialSaveRecovery {
  const WaffraSmsPartialSaveRecovery({
    required this.saved,
    required this.unsaved,
  });

  final int saved;
  final List<WaffraSmsNotSavedMessage> unsaved;

  /// Match actual *persisted* entry IDs against the exact proposals sent to
  /// the locked finance writer. This avoids treating pre-parse rejection and
  /// writer-detected duplicates as the same thing or claiming all messages
  /// were saved when a batch only partially succeeded.
  ///
  /// Original bank SMS is retained only in the active, in-memory import UI.
  /// Do not copy it into SharedPreferences while SQLCipher is not live.
  static WaffraSmsPartialSaveRecovery reconcile({
    required List<String> discovered,
    required Map<int, WaffraSmsNotSavedReason> rejectedBeforeCommit,
    required List<int> proposedSourceIndexes,
    required List<String> proposedIds,
    required Set<String> persistedIds,
  }) {
    if (discovered.isEmpty || discovered.length > 100 ||
        proposedIds.length != proposedSourceIndexes.length ||
        proposedIds.toSet().length != proposedIds.length) {
      throw StateError('SMS import reconciliation cannot prove exact scope.');
    }
    final accounted = <int>{};
    final missed = <WaffraSmsNotSavedMessage>[];
    for (final item in rejectedBeforeCommit.entries) {
      if (item.key < 0 || item.key >= discovered.length ||
          !accounted.add(item.key)) {
        throw StateError('SMS pre-commit rejection has duplicate source.');
      }
      missed.add(WaffraSmsNotSavedMessage(
        sourceIndex: item.key,
        message: discovered[item.key],
        reason: item.value,
      ));
    }
    var saved = 0;
    for (var i = 0; i < proposedIds.length; i++) {
      final sourceIndex = proposedSourceIndexes[i];
      if (sourceIndex < 0 || sourceIndex >= discovered.length ||
          !accounted.add(sourceIndex) || proposedIds[i].trim().isEmpty) {
        throw StateError('SMS proposed entry cannot be traced to its source.');
      }
      if (persistedIds.contains(proposedIds[i])) {
        saved++;
      } else {
        missed.add(WaffraSmsNotSavedMessage(
          sourceIndex: sourceIndex,
          message: discovered[sourceIndex],
          reason: WaffraSmsNotSavedReason.alreadySaved,
        ));
      }
    }
    if (accounted.length != discovered.length ||
        saved + missed.length != discovered.length) {
      throw StateError('SMS saved/unsaved totals do not reconcile.');
    }
    missed.sort((a, b) => a.sourceIndex.compareTo(b.sourceIndex));
    return WaffraSmsPartialSaveRecovery(
      saved: saved,
      unsaved: List<WaffraSmsNotSavedMessage>.unmodifiable(missed),
    );
  }
}
