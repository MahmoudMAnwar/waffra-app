import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'waffra_encrypted_store.dart';

/// Production SQLCipher SIDE VAULT for original confirmed bank SMS notes only.
///
/// This is deliberately a separate file and OS-wrapped key from the 24-route
/// finance database. It does NOT activate/switch the financial ledger source.
/// Legacy finance may hold the non-sensitive transaction projection, but the
/// original message never appears in SharedPreferences or its write journal.
/// A confirmed transaction may be displayed only after its ledger ID exists.
///
/// No silent data loss: if secure storage or SQLCipher is unavailable,
/// the stage operation fails BEFORE any legacy transaction is committed.
/// A crash between staging and finance commit can leave an *encrypted*
/// unreferenced note, never a plaintext note or an invented finance record.
class WaffraEncryptedSmsNotesVault {
  const WaffraEncryptedSmsNotesVault({
    this.directoryProvider,
    this.keyReader,
    this.keyWriter,
  });

  final Future<Directory> Function()? directoryProvider;
  final Future<String?> Function()? keyReader;
  final Future<void> Function(String) ? keyWriter;

  static const filename = 'waffra_bank_sms_notes_v1.sqlite';
  static const keyName = 'waffra_bank_sms_notes_key_v1';
  static const _table = 'waffra_protected_original_sms_notes';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String fingerprint(String message) {
    const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
    final normalized = message.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'), (match) {
        final char = match.group(0)!;
        final index = arabic.indexOf(char);
        return (index >= 0 ? index : persian.indexOf(char)).toString();
      },
    ).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<String?> _readKey() => keyReader == null
      ? _secure.read(key: keyName) : keyReader!();

  Future<void> _writeKey(String key) => keyWriter == null
      ? _secure.write(key: keyName, value: key) : keyWriter!(key);

  Future<T> _withEncryptedStore<T>(
      Future<T> Function(WaffraEncryptedStore store) action,
      {required bool allowFirstCreate}) async {
    final directory = directoryProvider == null
        ? await getApplicationSupportDirectory() : await directoryProvider!();
    await directory.create(recursive: true);
    final lockPath = File('${directory.path}/.waffra_sms_notes.lock');
    final lock = await lockPath.open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      final file = File('${directory.path}/$filename');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw StateError('Unsafe encrypted bank note vault location.');
      }
      final present = type == FileSystemEntityType.file;
      var key = await _readKey();
      if (present != (key != null && key.isNotEmpty)) {
        throw StateError('Bank note key/vault mismatch: recovery required.');
      }
      if (!present) {
        if (!allowFirstCreate) {
          throw StateError('Encrypted bank SMS note vault is not initialized.');
        }
        final bytes = List<int>.generate(
            32, (_) => Random.secure().nextInt(256));
        final generated = base64UrlEncode(bytes);
        await _writeKey(generated);
        key = await _readKey();
        if (key != generated) {
          throw StateError('Android secure bank note key was not persisted.');
        }
      }
      final store = WaffraEncryptedStore.openAt(file, key: key!);
      try {
        // SQLCipher PRAGMA is fail-closed in openAt. Neither sensitive note
        // content nor its key is printed or sent to any network service.
        await store.customStatement('''
          CREATE TABLE IF NOT EXISTS $_table (
            entry_id TEXT PRIMARY KEY,
            message_hash TEXT NOT NULL,
            original_sms TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');
        return await action(store);
      } finally {
        await store.close();
      }
    } finally {
      try { await lock.unlock(); } finally { await lock.close(); }
    }
  }

  /// Stage all original SMS strings as ONE SQLCipher transaction before
  /// the regular Home/widget finance journal sees redacted records.
  /// An existing ID may be retried only with byte-exact identical content.
  Future<void> stage({
    required List<Map<String, Object?>> records,
    required List<String> hashes,
  }) async {
    if (records.isEmpty || records.length > 100 ||
        records.length != hashes.length) {
      throw StateError('Invalid encrypted SMS batch length.');
    }
    final validated = <(String, String, String)>[];
    final ids = <String>{};
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final id = record['id'];
      final note = record['notes'];
      final hash = hashes[i];
      if (record['sourceType'] != 'sms' ||
          id is! String || id.trim().isEmpty || id.length > 128 ||
          !ids.add(id) || note is! String ||
          note.trim().isEmpty || note.runes.length > 16000 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
          fingerprint(note) != hash) {
        throw StateError('Invalid original SMS content or transaction link.');
      }
      validated.add((id, hash, note));
    }
    await _withEncryptedStore((store) async {
      await store.transaction(() async {
        for (final (id, hash, original) in validated) {
          final existing = await store.customSelect(
            'SELECT message_hash,original_sms FROM $_table WHERE entry_id=?',
            variables: [Variable.withString(id)],
          ).get();
          if (existing.isEmpty) {
            await store.customStatement(
              'INSERT INTO $_table(entry_id,message_hash,original_sms,'
              'created_at_ms) VALUES(?,?,?,?)',
              [id, hash, original, DateTime.now().toUtc().millisecondsSinceEpoch],
            );
          } else if (existing.length != 1 ||
              existing.single.read<String>('message_hash') != hash ||
              existing.single.read<String>('original_sms') != original) {
            throw StateError('Conflicting encrypted original bank SMS link.');
          }
          final verified = await store.customSelect(
            'SELECT message_hash,original_sms FROM $_table WHERE entry_id=?',
            variables: [Variable.withString(id)],
          ).get();
          if (verified.length != 1 ||
              verified.single.read<String>('message_hash') != hash ||
              verified.single.read<String>('original_sms') != original) {
            throw StateError('Original SMS did not round-trip in SQLCipher.');
          }
        }
      });
    }, allowFirstCreate: true);
  }

  /// Caller MUST first verify this entry ID is an existing SMS transaction
  /// in the authoritative ledger; no listing or search of bank messages.
  Future<String?> readVerifiedEntry(String entryId) async {
    if (entryId.trim().isEmpty || entryId.length > 128) {
      throw ArgumentError('Invalid bank SMS transaction ID.');
    }
    try {
      return await _withEncryptedStore((store) async {
        final rows = await store.customSelect(
          'SELECT message_hash,original_sms FROM $_table WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (rows.isEmpty) return null;
        if (rows.length != 1) {
          throw StateError('Duplicate original SMS attachment.');
        }
        final original = rows.single.read<String>('original_sms');
        if (fingerprint(original) != rows.single.read<String>('message_hash')) {
          throw StateError('Encrypted SMS note integrity mismatch.');
        }
        return original;
      }, allowFirstCreate: false);
    } on StateError catch (error) {
      if (error.message == 'Encrypted bank SMS note vault is not initialized.') {
        return null; // Old installations, never fabricate an original SMS.
      }
      rethrow;
    }
  }
}
