/// A bounded recheck for a transient, non-mutating finance refresh read.
///
/// A failed source read (including its integrity/cutover validation) never
/// becomes a displayed result. The same authoritative read and full validator
/// must succeed again, or the caller's existing fail-closed recovery UI wins.
///
/// This is NOT automatic recovery of an invalid vault, a retry of a write,
/// or permission to switch between SQLCipher and legacy preferences.
class WaffraVerifiedRefreshReadRecheck {
  const WaffraVerifiedRefreshReadRecheck._();

  static Future<T> read<T>({
    required Future<T> Function() load,
    required void Function(T) verify,
    Future<void> Function()? beforeRetry,
  }) async {
    try {
      final first = await load();
      verify(first);
      return first;
    } catch (_) {
      // Only a read is repeated: do not return cached/stale finance values.
      // Any second failure propagates to the financial recovery screen.
    }
    if (beforeRetry != null) await beforeRetry();
    final second = await load();
    verify(second);
    return second;
  }
}
