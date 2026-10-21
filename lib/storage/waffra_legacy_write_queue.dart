import 'dart:async';

/// Per-application-instance sequencer for EXISTING SharedPreferences finance
/// writes. It does NOT convert legacy preferences to encrypted SQLite, cannot
/// make a multi-key write atomic, and cannot coordinate an Android widget or
/// another isolate/process. Those remain release blockers for M9 cutover.
///
/// Captures the exact serialized values synchronously at submission time.
/// The next batch cannot overtake a previous batch, even if a previous
/// individual preference write fails.
class WaffraLegacyWriteQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  int get pendingBatches => _pending;

  Future<void> submit(
    Map<String, Object> currentSnapshot,
    Future<void> Function(Map<String, Object> captured) save,
  ) {
    final captured = Map<String, Object>.unmodifiable(currentSnapshot);
    _pending++;
    // The previous batch's outcome is already handled in _tail so a failure
    // never poisons later saves. The *calling* operation still gets its error.
    final task = _tail.then((_) => save(captured));
    _tail = task.then<void>(
      (_) { _pending--; },
      onError: (Object _, StackTrace __) { _pending--; },
    );
    return task;
  }

  /// Used by future migration writers to wait for known *in-process* batches.
  /// Not a cross-isolate barrier and not safe as the only cutover guard.
  Future<void> drain() => _tail;
}
