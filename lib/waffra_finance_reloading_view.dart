import 'package:flutter/material.dart';

/// Visible progress only when an authenticated Home is re-verifying its
/// financial source after a recoverable failure. The first login/biometric
/// handoff remains offstage until owner-verified balances have loaded.
///
/// This surface must never interpolate a balance, create sample records or
/// authorize a write. The existing financial recovery screen handles failure.
class WaffraFinanceReloadingView extends StatelessWidget {
  const WaffraFinanceReloadingView({
    super.key,
    required this.english,
  });

  final bool english;

  @override
  Widget build(BuildContext context) {
    final message = english
        ? 'Verifying your saved financial data…'
        : 'جارٍ التحقق من بياناتك المالية المحفوظة…';
    final progressLabel = english
        ? 'Financial verification in progress'
        : 'جارٍ التحقق من البيانات المالية';

    return Scaffold(
      key: const Key('m1006-visible-finance-retry-surface'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child:Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 44, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  CircularProgressIndicator(
                    key: const Key('m1006-finance-retry-progress'),
                    semanticsLabel: progressLabel,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
