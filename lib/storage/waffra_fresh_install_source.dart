import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_cutover_journal.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';
import 'waffra_live_legacy_finance_guard.dart';

/// Installation receipt for a vault born encrypted. Migrated vaults use
/// the separate migration binder and cannot acquire this receipt on reopen.
class WaffraFreshInstallSource {
  const WaffraFreshInstallSource._(this.id);
  final String id;
  static const _receipt = 'waffra_fresh_sqlcipher_install_v1';
  static const receiptKey = _receipt;
  static const _prefix = 'fresh-sqlcipher-v1:';
  static const _active = WaffraLiveLegacyFinanceGuard.activeKey;
  static const _pending = WaffraLiveLegacyFinanceGuard.pendingKey;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String get digest => sha256.convert(utf8.encode('$_prefix$id')).toString();

  static Future<WaffraFreshInstallSource?> prepare() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return prepareIn(directory, readKey: () => _storage.read(key: WaffraEncryptedStore.secureKeyStorageName),
      writeKey: (value) => _storage.write(key: WaffraEncryptedStore.secureKeyStorageName,value:value));
  }

  static String _random() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
  }

  static Future<WaffraFreshInstallSource?> prepareIn(Directory directory, {
    required Future<String?> Function() readKey,
    required Future<void> Function(String) writeKey,
  }) => WaffraExperimentalWriterGate(disposableDirectory:directory,experimentalEnabled:true)
      .withExclusiveAccess(() async {
    // POSIX advisory file locks may be shared by Flutter engines in the
    // same process. A SQLite write reservation also serializes those engines.
    final mutex = sqlite3.open('${directory.path}/waffra-install-lock.sqlite');
    try {
      mutex.execute('PRAGMA busy_timeout=10000');
      mutex.execute('BEGIN IMMEDIATE');
      return await _prepareLocked(directory,readKey,writeKey);
    } finally {
      mutex.close();
    }
  });

  static Future<WaffraFreshInstallSource?> _prepareLocked(Directory directory,
    Future<String?> Function() readKey, Future<void> Function(String) writeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = prefs.get(_pending);
    final installed = prefs.getString(_receipt);
    if (pending == null && installed != null) {
      if (prefs.getBool(_active) != true) throw StateError('Missing encrypted install pointer.');
      return WaffraFreshInstallSource._(installed);
    }
    final resuming = pending is String && pending.startsWith(_prefix);
    if (!resuming && (pending != null || prefs.containsKey(_active))) return null;
    final file = File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}');
    final type = await FileSystemEntity.type(file.path,followLinks:false);
    var key = await readKey();
    if (!resuming) {
      if (type != FileSystemEntityType.notFound || key != null) return null;
      final decision = const WaffraFirstRunClassifier().decide(
        existingPreferences:{for(final name in prefs.getKeys()) name:prefs.get(name)},
        encryptedVaultFileExists:false,activationMarkerExists:false);
      if (decision != WaffraFirstRunDecision.freshCandidate) return null;
    }
    final id = pending is String && pending.startsWith(_prefix) ? pending.substring(_prefix.length) : _random();
    if (!RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(id) ||
        (installed != null && installed != id)) throw StateError('Invalid encrypted install receipt.');
    final source = WaffraFreshInstallSource._(id);
    if (!resuming && !await prefs.setString(_pending,'$_prefix$id')) {
      throw StateError('Could not reserve fresh installation.');
    }
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file) {
      throw StateError('Invalid vault path.');
    }
    if (type == FileSystemEntityType.file && key == null ||
        prefs.containsKey(_active) && (key == null || type != FileSystemEntityType.file)) {
      throw StateError('Incomplete encrypted installation.');
    }
    if (key == null) {
      final proposed = WaffraEncryptedStore.freshSqlCipherKeyPrefix + _random();
      await writeKey(proposed);
      key = await readKey();
      if (key != proposed) throw StateError('Installation key was not persisted.');
    }
    if (key == null || !key.startsWith(WaffraEncryptedStore.freshSqlCipherKeyPrefix)) {
      throw StateError('Unexpected fresh-install cipher key format.');
    }
    final store = WaffraEncryptedStore.openAt(file,key:key);
    try {
      final snapshot = WaffraAtomicFinanceSnapshot(store:store,experimentalEnabled:true);
      final journal = WaffraEncryptedCutoverJournal(store:store,snapshot:snapshot,experimentalEnabled:true);
      await store.transaction(() async {
        final tables = await store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'fresh_finance_%'").get();
        if (tables.isEmpty) {
          await WaffraFreshEncryptedVaultBootstrap(store:store,experimentalEnabled:true)
              .initialize(decision:WaffraFirstRunDecision.freshCandidate);
          await WaffraAccountsSchema.install(store);
          final initial = await snapshot.initializeEmpty();
          await store.customStatement('CREATE TABLE fresh_install_origin(id TEXT PRIMARY KEY NOT NULL)');
          await store.customStatement('INSERT INTO fresh_install_origin VALUES (?)',[id]);
          await journal.prepare(sourceDigest:source.digest,targetDigest:initial.digest,now:DateTime.now());
          await journal.verify(now:DateTime.now());
        }
        await source.verify(store);
        if ((await journal.read())?.sourceDigest != source.digest) throw StateError('Wrong installation journal.');
      });
      if (!await prefs.setString(_receipt,id) || !await prefs.setBool(_active,true)) {
        throw StateError('Could not persist encrypted install pointer.');
      }
      await prefs.reload();
      if(prefs.getBool(_active)!=true || prefs.getString(_receipt)!=id) {
        throw StateError('Encrypted install pointer did not persist.');
      }
      await journal.acknowledgeExternalActivation(externalMarkerVerified:true,allWritersRouted:true,now:DateTime.now());
      if (!await prefs.remove(_pending)) throw StateError('Installation completion failed.');
      return source;
    } finally { await store.close(); }
  }

  /// Guarded NON-FINANCIAL account/PIN preferences for an already-activated
  /// fresh SQLCipher installation. The legacy writer must never touch it.
  /// No vault/key/receipt creation; verify BOTH source witnesses under the
  /// common Home/Widget native lock before touching only account metadata.
  static Future<T> withVerifiedProfilePreferences<T>(
    Future<T> Function(SharedPreferences prefs) write, {
    Directory? testDirectory,
    Future<String?> Function()? secureKeyReader,
  }) async {
    assert(secureKeyReader == null || testDirectory != null);
    final directory = testDirectory ?? await getApplicationSupportDirectory();
    return WaffraExperimentalWriterGate(
      disposableDirectory: directory, experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final id = prefs.getString(_receipt);
      if (id == null || !RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(id) ||
          prefs.getBool(_active) != true || prefs.containsKey(_pending)) {
        throw StateError('Fresh encrypted account source is not active.');
      }
      final path = File(
        '${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}',
      );
      if (await FileSystemEntity.type(path.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Fresh encrypted finance vault is unavailable.');
      }
      final key = await (secureKeyReader != null
          ? secureKeyReader()
          : _storage.read(key: WaffraEncryptedStore.secureKeyStorageName));
      if (key == null ||
          !key.startsWith(WaffraEncryptedStore.freshSqlCipherKeyPrefix)) {
        throw StateError('Fresh encrypted OS key is unavailable.');
      }
      final store = WaffraEncryptedStore.openAt(path, key: key);
      try {
        final source = WaffraFreshInstallSource._(id);
        await source.verify(store);
        final snapshot = WaffraAtomicFinanceSnapshot(
          store: store, experimentalEnabled: true,
        );
        final journal = WaffraEncryptedCutoverJournal(
          store: store, snapshot: snapshot, experimentalEnabled: true,
        );
        final checkpoint = await journal.read();
        if (checkpoint == null ||
            checkpoint.phase != WaffraCutoverPhase.active ||
            checkpoint.sourceDigest != source.digest) {
          throw StateError('Fresh encrypted source digest is unverified.');
        }
        return await write(prefs);
      } finally {
        await store.close();
      }
    });
  }

  Future<void> verify(WaffraEncryptedStore store) async {
    final rows = await store.customSelect('SELECT id FROM fresh_install_origin').get();
    if (rows.length != 1 || rows.single.read<String>('id') != id) {
      throw StateError('Encrypted install identity mismatch.');
    }
  }
}
