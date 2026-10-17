import 'package:flutter/material.dart';

/// Shared visual background for the welcome and PIN-lock screens.
class WaffraWelcomeBackground extends StatelessWidget {
  final Widget child;
  const WaffraWelcomeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/waffra_welcome.jpg', fit: BoxFit.cover,
        alignment: Alignment.center, filterQuality: FilterQuality.high),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xB800392D), Color(0x2200392D), Color(0xE600392D)],
        stops: [0, .55, 1],
      ))),
      child,
    ],
  );
}
