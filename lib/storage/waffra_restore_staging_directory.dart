import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Disposable, encrypted restore candidates must live in the app sandbox on
/// mobile. Android's OS-wide Directory.systemTemp can point at /data/local/tmp,
/// which a normal installed APK cannot write. Host-only tests may use the
/// host's private temporary root and explicitly supplied test directories.
abstract final class WaffraRestoreStagingDirectory {
  static Future<Directory> create({
    required String prefix,
    Directory? explicitTestRoot,
  }) async {
    // Prefix is a code-owned stable label, not a user filename or a path.
    if (!RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(prefix)) {
      throw ArgumentError('Invalid internal restore staging prefix.');
    }
    final Directory parent = explicitTestRoot ??
        (Platform.isAndroid || Platform.isIOS
            ? await getTemporaryDirectory()
            : Directory.systemTemp);
    // createTemp uses a randomized suffix, preventing collisions with another
    // app session. The caller MUST close SQLCipher before recursive deletion.
    final directory = await parent.createTemp(prefix);
    return directory;
  }
}
