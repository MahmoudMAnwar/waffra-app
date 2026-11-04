import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The accepted + button's light-impact strength, reused on app actions.
///
/// Fire only from accepted, enabled action callbacks, never from pointer-down,
/// scroll, drag, text editing or animation. The short coalescing window avoids
/// double impact when a child action forwards the same tap to a parent action.
/// Android/iOS and the user's device settings ultimately control feedback.
abstract final class WaffraHaptics {
  static const int _sameGestureMicros = 28000;
  static int _lastImpactMicros = 0;

  static void impact() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (now - _lastImpactMicros < _sameGestureMicros) return;
    _lastImpactMicros = now;
    HapticFeedback.lightImpact();
  }

  /// Preserve null as disabled; never vibrate for disabled buttons.
  static VoidCallback? tap(VoidCallback? action) =>
      action == null ? null : () {
        impact();
        action();
      };

  /// Required action contract (e.g. InkWell or Semantics callback).
  /// These constructors cannot accept null and must keep strict Dart types.
  static VoidCallback tapRequired(VoidCallback action) => () {
    impact();
    action();
  };

  /// Required selection contract (e.g. navigation destination callback).
  static ValueChanged<T> selectionRequired<T>(ValueChanged<T> action) =>
      (value) {
        impact();
        action(value);
      };

  /// Menu, choice, switch and dropdown selection; NOT TextField.onChanged.
  static ValueChanged<T>? selection<T>(ValueChanged<T>? action) =>
      action == null ? null : (value) {
        impact();
        action(value);
      };

  @visibleForTesting
  static void resetForTesting() => _lastImpactMicros = 0;
}
