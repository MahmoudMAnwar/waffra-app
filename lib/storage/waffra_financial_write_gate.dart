import 'dart:async';

/// A cooperative write barrier for a FUTURE unified financial repository.
///
/// Writers MUST call [runWrite] for every ledger mutation; migration uses
/// [freeze] and always releases the lease in a finally block. This class is not
/// wired into main.dart, widgets, SMS bulk import or recurring jobs yet. It
/// cannot protect a legacy caller which bypasses this gate.
///
/// A freeze waits for in-flight work to finish, then blocks NEW financial
/// writes until explicitly released. The actual financial transaction and
/// outbox enqueue must still be atomic in the encrypted repository.
class WaffraFinancialWriteGate {
  final Object _zoneKey = Object();

  int _activeWriters = 0;
  Completer<void>? _resume;
  Completer<void>? _drained;

  bool get isFrozen => _resume != null;

  /// Executes a financial write that has entered the gate. Writes can run
  /// concurrently until migration freezes the gate. This is not a mutex or
  /// database transaction, and callers must enforce their own row-level order.
  ///
  /// Nested guarded writes are rejected, rather than deadlocking if a freeze
  /// occurs between a parent write and its nested child.
  Future<T> runWrite<T>(FutureOr<T> Function() operation) async {
    if (Zone.current[_zoneKey] == true) {
      throw StateError('Nested financial writes are not permitted.');
    }
    while (_resume != null) {
      final resume = _resume!;
      await resume.future;
    }
    _activeWriters++;
    try {
      return await runZoned<FutureOr<T>>(
        operation, zoneValues: {_zoneKey: true});
    } finally {
      _activeWriters--;
      if (_activeWriters == 0) {
        final drained = _drained;
        _drained = null;
        if (drained != null && !drained.isCompleted) drained.complete();
      }
    }
  }

  /// Rejects recursive or simultaneous freezes. A caller MUST await the lease
  /// before taking the migration snapshot, and MUST release it in finally.
  Future<WaffraWriteFreeze> freeze() async {
    if (Zone.current[_zoneKey] == true) {
      throw StateError('Cannot freeze inside an active financial write.');
    }
    if (_resume != null) {
      throw StateError('A financial migration freeze is already active.');
    }
    final resume = Completer<void>();
    _resume = resume; // Synchronous barrier against ALL new guarded writes.
    if (_activeWriters != 0) {
      final drained = Completer<void>();
      _drained = drained;
      await drained.future;
    }
    return WaffraWriteFreeze._(this, resume);
  }

  void _unfreeze(Completer<void> token) {
    if (!identical(_resume, token)) {
      throw StateError('Write-freeze lease is no longer active.');
    }
    _resume = null;
    token.complete();
  }
}

class WaffraWriteFreeze {
  WaffraWriteFreeze._(this._gate, this._token);

  final WaffraFinancialWriteGate _gate;
  final Completer<void> _token;
  bool _released = false;

  bool get isReleased => _released;

  /// Idempotent release. Wakes waiting writers, which re-check the gate in
  /// case a new migration froze it while they were awaiting the old lease.
  void release() {
    if (_released) return;
    _gate._unfreeze(_token);
    _released = true;
  }
}
