import 'package:flutter/material.dart';
import 'waffra_biometrics.dart';

/// M424: Mandatory biometric gate, deliberately independent of legacy PIN.
///
/// No local PIN/password shortcut, no remembered unlock and no network
/// requests. Every new gate instance must be verified through the OS.
abstract final class WaffraBiometricSessionGuard {
  // Android may briefly emit inactive for a screenshot, notification shade,
  // overlay or its own biometric prompt without actually backgrounding Waffra.
  // Lock only when the activity leaves the foreground for real. Keep the
  // existing OS biometric gate mandatory after every true background event.
  static bool mustLockOn(AppLifecycleState state) =>
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.detached;

  static bool canReveal({
    required bool authenticated,
    required bool inForeground,
  }) => authenticated && inForeground;
}

class WaffraMandatoryBiometricGate extends StatefulWidget {
  const WaffraMandatoryBiometricGate({
    super.key,
    required this.english,
    required this.onVerified,
    required this.onSignOut,
    this.checkAvailable = WaffraBiometrics.isAvailable,
    this.authenticate = WaffraBiometrics.unlockMandatory,
    this.cancelAuthentication = WaffraBiometrics.cancelMandatory,
  });

  final bool english;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;
  final Future<bool> Function() checkAvailable;
  final Future<bool> Function() authenticate;
  final Future<void> Function() cancelAuthentication;

  @override
  State<WaffraMandatoryBiometricGate> createState() =>
      _WaffraMandatoryBiometricGateState();
}

class _WaffraMandatoryBiometricGateState
    extends State<WaffraMandatoryBiometricGate> with WidgetsBindingObserver {
  bool _busy = false;
  bool _signingOut = false;
  int _authGeneration = 0;
  bool _attempted = false;
  bool _available = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _authenticateAutomatically();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A native system biometric prompt can itself briefly make Flutter
    // inactive. Never start two OS prompts; a cancelled attempt needs a tap.
    if (state == AppLifecycleState.resumed && !_attempted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticateAutomatically();
      });
    }
  }

  void _authenticateAutomatically() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      _tryUnlock();
    }
  }

  Future<void> _tryUnlock() async {
    if (_busy || _signingOut) return;
    final generation = ++_authGeneration;
    setState(() {
      _busy = true;
      _attempted = true;
      _message = null;
    });
    bool available = false;
    try {
      available = await widget.checkAvailable();
    } catch (_) {
      available = false;
    }
    if (!mounted || _signingOut || generation != _authGeneration) return;
    if (!available) {
      setState(() {
        _busy = false;
        _available = false;
        _message = widget.english
            ? 'Set up fingerprint or face recognition in your phone settings, then retry.'
            : 'سجّل البصمة أو التعرّف على الوجه من إعدادات الهاتف ثم حاول مرة أخرى.';
      });
      return;
    }
    _available = true;
    bool ok = false;
    try {
      ok = await widget.authenticate();
    } catch (_) {
      ok = false;
    }
    if (!mounted || _signingOut || generation != _authGeneration) return;
    setState(() => _busy = false);
    if (ok) {
      // Parent must ALSO confirm foreground and current session generation;
      // this callback alone cannot authorize opening any financial screen.
      widget.onVerified();
    } else {
      setState(() {
        _message = widget.english
            ? 'Biometric verification was not completed. Try again.'
            : 'لم يكتمل التحقق بالبصمة. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _requestSignOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _authGeneration++; // Ignore a late successful fingerprint result.
      _attempted = true;
      _message = null;
    });
    try {
      // The sign-out escape must work while the native OS challenge is busy.
      if (_busy) await widget.cancelAuthentication();
      await widget.onSignOut();
      if (mounted) {
        setState(() => _message = widget.english
          ? 'Sign-out did not complete. Please retry; your data is unchanged.'
          : 'لم يكتمل تسجيل الخروج. حاول مرة أخرى؛ بياناتك محفوظة.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = widget.english
          ? 'Could not sign out securely. Please retry.'
          : 'تعذر تسجيل الخروج بأمان. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF064D3B),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fingerprint, size: 80, color: Colors.white),
            const SizedBox(height: 18),
            Text(widget.english ? 'Unlock Waffra' : 'فتح وفرة بالبصمة',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal',
                fontSize: 25, fontWeight: FontWeight.bold)),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFD9D9),
                  fontFamily: 'Tajawal', fontSize: 14)),
            ],
            const SizedBox(height: 25),
            if (_busy || _signingOut)
              const CircularProgressIndicator(color: Colors.white)
            else
              FilledButton.icon(
                key: const Key('waffra-mandatory-biometric-retry'),
                onPressed: _tryUnlock,
                icon: Icon(_available ? Icons.fingerprint : Icons.settings),
                label: Text(widget.english ? 'Verify biometric' : 'التحقق بالبصمة'),
              ),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('waffra-mandatory-biometric-signout'),
              onPressed: _signingOut ? null : _requestSignOut,
              child: Text(widget.english ? 'Sign out' : 'تسجيل الخروج',
                style: const TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      ),
    ),
  );
}
