/// Home consumes account/tab system-back before app-wide double-back exit.
/// The handler is unregistered when the Home widget is disposed.
abstract final class WaffraBackNavigation {
  static bool Function()? onHomeBack;
}

class WaffraDoubleBackExit {
  WaffraDoubleBackExit({this.window = const Duration(milliseconds: 2500)});
  final Duration window;
  DateTime? _previous;

  bool isExitPress(DateTime now) {
    final earlier = _previous;
    _previous = now;
    if (earlier == null || now.isBefore(earlier) ||
        now.difference(earlier) > window) return false;
    _previous = null;
    return true;
  }

  void reset() => _previous = null;
}
