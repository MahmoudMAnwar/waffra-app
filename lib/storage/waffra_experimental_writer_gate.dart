import 'dart:io';

/// Advisory cross-isolate/process file lock: only protects writers that choose
/// to participate. NEVER assume this stops an unmodified Android widget or
/// older installed app. A real activation must route all writers through it.
class WaffraExperimentalWriterGate {
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

    // The directory must be app-private and must have a trusted, sole owner.
    // File locks are OS advisory locks; they are NOT a database transaction.
    final handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      // Recheck after acquisition. Prevent accidentally continuing if the
      // lock file was replaced while acquisition waited.
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Writer lock file was replaced.');
      }
      return await operation();
    } finally {
      try {
        await handle.unlock();
      } finally {
        await handle.close();
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
