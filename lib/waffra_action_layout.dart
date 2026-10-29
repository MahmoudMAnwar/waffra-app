import 'package:flutter/material.dart';

/// Shared minimum tap target and safe text/icon inset for Waffra actions.
///
/// ThemeData applies these to bordered text, outlined and filled buttons
/// across Arabic/English screens. A minimum (not a fixed height) lets
/// two-line labels grow without being clipped by their border.
abstract final class WaffraActionLayout {
  static const Size minimumSize = Size(0, 48);
  static const EdgeInsets contentPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  static const BorderRadius borderRadius =
      BorderRadius.all(Radius.circular(16));
}
