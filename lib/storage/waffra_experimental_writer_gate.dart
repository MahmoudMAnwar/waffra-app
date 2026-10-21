import 'dart:async';
import 'dart:io';

/// Advisory cross-isolate/process file lock: only protects writers that choose
/// to participate. NEVER assume this stops an unmodified Android widget or
/// older installed app. A real activation must route all writers through it.
class WaffraExperimentalWriterGate {
  static final Map<String, Future<void>> _localTails = {};
  const WaffraExperimentalWriterGate({
    required this.disposableDirectory,
    this.experimentalEnabled = false,
  });

  final Directory disposableDirectory;
  final bool experimentalEnabled;

  Future<T> withExclusiveAccess<T>(Future<T> Function() operation) async {
    if (!experimentalEnabled) {
      throw StateError('Cross-writer gate is disabled by default.');
    }
    if (await FileSystemEntity.type(
          disposableDirectory.path, followLinks: false,
        ) != FileSystemEntityType.directory) {
      throw StateError('Writer-gate folder must be a real directory.');
    }
    final lockFile = File(
      '${disposableDirectory.path}${Platform.pathSeparator}.waffra-writer.lock',
    );
    final before = await FileSystemEntity.type(
      lockFile.path, followLinks: false,
    );
    if (before != FileSystemEntityType.notFound &&
        before != FileSystemEntityType.file) {
      throw StateError('Writer lock path cannot be a link or directory.');
    }

    // The local future tail serializes callbacks even on OSes where file
    // locks from the SAME process are advisory/per-process rather than per-FD.
    // The native OS lock then coordinates DIFFERENT participating processes.
    final key = lockFile.absolute.path;
    final previous = _localTails[key] ?? Future<void>.value();
    final done = Completer<void>();
    _localTails[key] = done.future;
    await previous;
    RandomAccessFile? handle;
    try {
      // The directory must be private with one trusted owner.
      handle = await lockFile.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Writer lock file was replaced.');
      }
      return await operation();
    } finally {
      try {
        if (handle != null) {
          try {
            await handle.unlock();
          } finally {
            await handle.close();
          }
        }
      } finally {
        if (identical(_localTails[key], done.future)) {
          _localTails.remove(key);
        }
        done.complete();
      }
    }
  }
}

/// A revision guard to be used while holding WaffraExperimentalWriterGate.
/// This must be read from the authoritative source each time under lock,
/// never from a stale in-memory widget/dashboard snapshot.
class WaffraWriterRevisionGuard {
  const WaffraWriterRevisionGuard();

  int nextRevision({
    required int expectedRevision,
    required int authoritativeRevision,
  }) {
    if (expectedRevision < 0 || authoritativeRevision < 0 ||
        expectedRevision != authoritativeRevision ||
        expectedRevision >= 9223372036854775806) {
      throw StateError('Finance writer is stale; reload before saving.');
    }
    return expectedRevision + 1;
  }
}
