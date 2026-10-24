/// Strict, non-sensitive diagnostic event boundary for future opt-in
/// Crashlytics. Does NOT initialize Firebase, send a report or access a user
/// account. Shipping builds default OFF until user controls and native SDK
/// collection suppression are both independently verified.
///
/// Do not add freeform error messages or exception stack traces here: they
/// may include pasted bank SMS, receipt file paths or personal identifiers.
enum WaffraSafeDiagnosticCode {
  appStartupBlocked,
  financeWitnessMismatch,
  encryptedVaultCannotOpen,
  widgetJournalRecoveryNeeded,
  cloudRevisionConflict,
  receiptIntegrityFailure,
  reportRenderFailed,
}

class WaffraSafeDiagnosticEvent {
  const WaffraSafeDiagnosticEvent(this.code);
  final WaffraSafeDiagnosticCode code;

  /// The only external representation. It cannot contain user-provided text.
  String get safeTag => 'waffra_${code.name}';
}

typedef WaffraSafeDiagnosticSender = Future<void> Function(
  WaffraSafeDiagnosticEvent event,
);

/// The sender is injected after independently proven user consent. No sender
/// may be constructed from a bank message or dynamic user account state.
class WaffraPrivateDiagnostics {
  const WaffraPrivateDiagnostics({
    this.userConsented = false,
    this.releaseConfigurationVerified = false,
    required this.sender,
  });

  final bool userConsented;
  final bool releaseConfigurationVerified;
  final WaffraSafeDiagnosticSender sender;

  Future<bool> report(WaffraSafeDiagnosticCode code) async {
    if (!userConsented || !releaseConfigurationVerified) return false;
    await sender(WaffraSafeDiagnosticEvent(code));
    return true;
  }
}
