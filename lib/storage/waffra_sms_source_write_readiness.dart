/// UI-only fail-closed precondition for a bank SMS confirmation.
///
/// This does NOT select or attest SQLCipher. The native finance writer must
//// independently validate the current source and expected generation under
//// its Home/Widget lock. It prevents a lingering SMS sheet from offering a
//// write while the dashboard is in a protected recovery state.
bool waffraCanConfirmSmsWithFinanceSource({
  required bool dashboardReady,
  required bool hasVerifiedRead,
  required bool recoveryActive,
}) =>
    dashboardReady && hasVerifiedRead && !recoveryActive;
