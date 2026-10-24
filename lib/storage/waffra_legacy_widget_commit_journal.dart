import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';

/// Crash-recoverable bridge for the CURRENT SharedPreferences-based widget.
///
/// Must be called only while holding the real app/widget finance file lock.
/// A single pending JSON marker is persisted before changing any of the
/// existing finance keys. Interrupted commits can then be replayed after
/// restarting either Flutter engine, with strict before/after conflict checks.
/// This does not activate the experimental SQLCipher source.
class WaffraLegacyWidgetCommitJournal {
  const WaffraLegacyWidgetCommitJournal();

  static const pendingKey = 'waffra_widget_finance_commit_pending_v1';
  static const _version = 1;
  static const maxJournalCharacters = 12 * 1024 * 1024;

  static void _validateEntries(String raw, List<String> hashes) {
    final report = WaffraLegacyPreflight.inspect({
      'entries': raw,
      'waffra_sms_hashes_v1': hashes,
    });
    if (!report.canStage) {
      throw StateError('Widget finance data failed validation.');
    }
  }

  static void _validateHashes(List<String> hashes) {
    if (hashes.length > 200000 ||
        hashes.any((hash) => hash.trim().isEmpty || hash.length > 512)) {
      throw StateError('Invalid widget finance deduplication hashes.');
    }
  }

  /// FIRST STEP ONLY. A caller must follow it with recover(), still under
  /// the same writer lock. On app death, the next finance reader replays it.
  Future<void> prepare({
    required SharedPreferences prefs,
    required String nextEntries,
    required List<String> nextHashes,
    required String nextRevision,
  }) async {
    if (prefs.containsKey(pendingKey)) {
      throw StateError('An older widget finance commit needs recovery first.');
    }
    if (nextRevision.trim().isEmpty || nextRevision.length > 128) {
      throw ArgumentError('Invalid widget finance revision.');
    }
    _validateHashes(nextHashes);
    _validateEntries(nextEntries, nextHashes);
    final beforeEntries = prefs.getString('entries');
    final beforeHashes = prefs.getStringList('waffra_sms_hashes_v1');
    final beforeRevision = prefs.getString('waffra_widget_last_save_v1');
    _validateHashes(beforeHashes ?? const []);
    if (beforeEntries != null) {
      _validateEntries(beforeEntries, beforeHashes ?? const []);
    }
    final payload = jsonEncode({
      'version': _version,
      'beforeEntries': beforeEntries,
      'beforeHashes': beforeHashes,
      'beforeRevision': beforeRevision,
      'nextEntries': nextEntries,
      'nextHashes': nextHashes,
      'nextRevision': nextRevision,
    });
    final envelope = jsonEncode({
      'payload': payload,
      'checksum': sha256.convert(utf8.encode(payload)).toString(),
    });
    if (envelope.length > maxJournalCharacters) {
      throw StateError('Widget finance commit journal is too large.');
    }
    if (!await prefs.setString(pendingKey, envelope)) {
      throw StateError('Widget finance commit preparation was not persisted.');
    }
  }

  static bool _equalList(List<String>? one, List<String>? other) =>
      one == null
          ? other == null
          : other != null &&
              one.length == other.length &&
              List.generate(one.length, (i) => i)
                  .every((i) => one[i] == other[i]);

  /// Replay only recognized partially committed states. If another writer
  /// touched any of the three keys, do not overwrite it or discard journal.
  Future<bool> recover(SharedPreferences prefs) async {
    final envelopeRaw = prefs.getString(pendingKey);
    if (envelopeRaw == null) {
      if (prefs.containsKey(pendingKey)) {
        throw StateError('Widget finance journal has an invalid storage type.');
      }
      return false;
    }
    if (envelopeRaw.length > maxJournalCharacters) {
      throw StateError('Widget finance journal exceeds size limit.');
    }
    Map<String, dynamic> envelope;
    Map<String, dynamic> content;
    try {
      final e = jsonDecode(envelopeRaw);
      if (e is! Map<String, dynamic> ||
          e.keys.toSet().difference({'payload', 'checksum'}).isNotEmpty ||
          e.length != 2 ||
          e['payload'] is! String ||
          e['checksum'] is! String ||
          sha256.convert(utf8.encode(e['payload'] as String)).toString() !=
              e['checksum']) {
        throw const FormatException('Invalid widget finance envelope.');
      }
      envelope = e;
      final decoded = jsonDecode(envelope['payload'] as String);
      if (decoded is! Map<String, dynamic> ||
          decoded.keys.toSet().difference({
            'version', 'beforeEntries', 'beforeHashes', 'beforeRevision',
            'nextEntries', 'nextHashes', 'nextRevision',
          }).isNotEmpty ||
          decoded.length != 7 ||
          decoded['version'] != _version ||
          (decoded['beforeEntries'] != null &&
              decoded['beforeEntries'] is! String) ||
          (decoded['beforeHashes'] != null &&
              decoded['beforeHashes'] is! List) ||
          (decoded['beforeRevision'] != null &&
              decoded['beforeRevision'] is! String) ||
          decoded['nextEntries'] is! String ||
          decoded['nextHashes'] is! List ||
          decoded['nextRevision'] is! String) {
        throw const FormatException('Invalid widget finance payload.');
      }
      content = decoded;
    } catch (e) {
      throw StateError('Cannot safely recover the widget finance journal: $e');
    }
    List<String>? castHashes(Object? data) {
      if (data == null) return null;
      if (data is! List || data.any((e) => e is! String)) {
        throw StateError('Journal hashes are corrupt.');
      }
      return data.cast<String>();
    }
    final oldEntries = content['beforeEntries'] as String?;
    final oldHashes = castHashes(content['beforeHashes']);
    final oldRevision = content['beforeRevision'] as String?;
    final newEntries = content['nextEntries'] as String;
    final newHashes = castHashes(content['nextHashes'])!;
    final newRevision = content['nextRevision'] as String;
    _validateHashes(newHashes);
    _validateEntries(newEntries, newHashes);
    if (oldEntries != null) {
      _validateEntries(oldEntries, oldHashes ?? const []);
    }

    final currentEntries = prefs.getString('entries');
    final currentHashes = prefs.getStringList('waffra_sms_hashes_v1');
    final currentRevision = prefs.getString('waffra_widget_last_save_v1');
    if (currentEntries != oldEntries && currentEntries != newEntries) {
      throw StateError('Newer entries conflict with interrupted widget save.');
    }
    if (!_equalList(currentHashes, oldHashes) &&
        !_equalList(currentHashes, newHashes)) {
      throw StateError('Newer SMS hashes conflict with interrupted widget save.');
    }
    if (currentRevision != oldRevision && currentRevision != newRevision) {
      throw StateError('Newer widget revision conflicts with interrupted save.');
    }

    if (currentEntries != newEntries &&
        !await prefs.setString('entries', newEntries)) {
      throw StateError('Could not finish widget transaction ledger.');
    }
    if (!_equalList(currentHashes, newHashes) &&
        !await prefs.setStringList('waffra_sms_hashes_v1', newHashes)) {
      throw StateError('Could not finish widget SMS hashes.');
    }
    if (currentRevision != newRevision &&
        !await prefs.setString('waffra_widget_last_save_v1', newRevision)) {
      throw StateError('Could not finish widget revision.');
    }
    final removed = await prefs.remove(pendingKey);
    if (!removed) {
      throw StateError('Widget journal not cleared; recovery must replay.');
    }
    return true;
  }
}
