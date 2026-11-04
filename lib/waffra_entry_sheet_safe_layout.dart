import 'package:flutter/material.dart';

/// Bottom-sheet layout shared by manual, bank-SMS and OCR transaction review.
///
/// Android three-button navigation and gesture bars expose their bottom area
/// through MediaQuery.padding when the keyboard is hidden. The IME instead
/// appears in viewInsets.bottom. Keep both cases disjoint: SafeArea reserves
/// navigation space; padding lifts the editor ABOVE the keyboard.
///
/// The confirmation action remains fixed above the Android system controls
/// while only the form scrolls. No finance records or field values are touched.
class WaffraEntrySheetSafeLayout extends StatelessWidget {
  const WaffraEntrySheetSafeLayout({
    super.key,
    required this.form,
    required this.footer,
  });

  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      key: const Key('waffra-entry-sheet-android-safe-area'),
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: AnimatedPadding(
        key: const Key('waffra-entry-sheet-keyboard-padding'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: form),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 7),
              child: SizedBox(
                width: double.infinity,
                child: footer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
