import 'dart:async';

/// Coalesce overlapping user pull-to-refresh gestures into one awaited read.
///
/// Never supplies cached finance data, retries an unverified read, or turns a
/// source error into a successful refresh. The caller retains the authoritative
/// source gate, integrity check and fail-closed recovery UI.
class WaffraVerifiedRefreshSingleFlight {
  Future<void>? _active;

  bool get isRefreshing => _active != null;

  Future<void> run(Future<void> Function() refresh) {
    final active = _active;
    if (active != null) return active;

    // Install the in-flight witness BEFORE invoking the callback so even a
    // reentrant refresh cannot start a competing read.
    final result = Completer<void>();
    _active = result.future;
    Future<void>.sync(refresh).then(
      (_) {
        _active = null;
        result.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        _active = null;
        result.completeError(error, stackTrace);
      },
    );
    return result.future;
  }
}
