import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// An immutable checkpoint in an OFFLINE recovery rehearsal.
/// SHA-256 detects accidental corruption, not an attacker who can rewrite the
/// journal. Never use this record to authorize a live financial cutover.
class WaffraRecoveryCheckpoint {
  const WaffraRecoveryCheckpoint({
    required this.phase,
    required this.sourceChecksum,
    required this.entries,
    required this.receipts,
    required this.previousDigest,
    required this.digest,
  });

  final int phase;
  final String sourceChecksum;
  final int entries;
  final int receipts;
  final String previousDigest;
  final String digest;
}

/// Append-only phase journal for a caller-provided EMPTY disposable directory.
/// No code here interacts with active receipt folders, SQLite, SharedPreferences
/// or Firebase; a crash/incomplete checkpoint forces a full sandbox discard.
class WaffraDisposableRecoveryJournal {
  const WaffraDisposableRecoveryJournal({
    required this.directory,
    this.experimentalEnabled = false,
  });

  final Directory directory;
  final bool experimentalEnabled;

  static const phases = [
    'archive_authenticated',
    'receipt_bytes_audited',
    'encrypted_ledger_verified',
  ];
  static final _checksumPattern = RegExp(r'^[0-9a-f]{64}$');

  String _filename(int phase) =>
      '${phase.toString().padLeft(2, '0')}_${phases[phase]}.json';

  Future<List<WaffraRecoveryCheckpoint>> inspect() async {
    if (!experimentalEnabled) {
      throw StateError('Recovery journal is disabled by default.');
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('Recovery journal requires a real directory.');
    }
    final entities = await directory.list(followLinks: false).toList();
    if (entities.length > phases.length) {
      throw StateError('Unexpected recovery journal artifacts.');
    }
    final filenames = entities.map((f) => f.uri.pathSegments.last).toSet();
    if (filenames.length != entities.length) {
      throw StateError('Duplicate recovery journal files.');
    }
    for (var i = 0; i < entities.length; i++) {
      if (!filenames.contains(_filename(i))) {
        // An interrupted .pending write is never interpreted as completed.
        throw StateError('Recovery journal interrupted or out of order.');
      }
    }
    final checkpoints = <WaffraRecoveryCheckpoint>[];
    for (var i = 0; i < entities.length; i++) {
      final file = File('${directory.path}${Platform.pathSeparator}${_filename(i)}');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Journal checkpoint must be a regular file.');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded.keys.toSet().difference({
        'format', 'phase', 'name', 'sourceChecksum',
        'entries', 'receipts', 'previousDigest', 'digest',
      }).isNotEmpty || decoded.length != 8 ||
          decoded['format'] != 'waffra-disposable-recovery-journal-v1' ||
          decoded['phase'] != i ||
          decoded['name'] != phases[i] ||
          decoded['sourceChecksum'] is! String ||
          decoded['entries'] is! int ||
          decoded['receipts'] is! int ||
          decoded['previousDigest'] is! String ||
          decoded['digest'] is! String) {
        throw StateError('Corrupted recovery checkpoint structure.');
      }
      final sourceChecksum = decoded['sourceChecksum'] as String;
      final entries = decoded['entries'] as int;
      final receipts = decoded['receipts'] as int;
      final parent = decoded['previousDigest'] as String;
      final digest = decoded['digest'] as String;
      if (!_checksumPattern.hasMatch(sourceChecksum) ||
          entries < 0 || receipts < 0 ||
          parent != (i == 0 ? '' : checkpoints.last.digest)) {
        throw StateError('Recovery journal checksum/parent mismatch.');
      }
      if (i > 0 &&
          (checkpoints.first.sourceChecksum != sourceChecksum ||
           checkpoints.first.entries != entries ||
           checkpoints.first.receipts != receipts)) {
        throw StateError('Recovery journal source was changed.');
      }
      final core = _record(
        i, sourceChecksum, entries, receipts, parent);
      if (sha256.convert(utf8.encode(jsonEncode(core))).toString() != digest) {
        throw StateError('Recovery checkpoint failed integrity check.');
      }
      checkpoints.add(WaffraRecoveryCheckpoint(
        phase: i,
        sourceChecksum: sourceChecksum,
        entries: entries,
        receipts: receipts,
        previousDigest: parent,
        digest: digest,
      ));
    }
    return List.unmodifiable(checkpoints);
  }

  Map<String, Object> _record(
    int phase, String checksum, int entries, int receipts, String parent,
  ) => {
    'format': 'waffra-disposable-recovery-journal-v1',
    'phase': phase,
    'name': phases[phase],
    'sourceChecksum': checksum,
    'entries': entries,
    'receipts': receipts,
    'previousDigest': parent,
  };

  /// Record the NEXT verified phase. Callers must validate that phase using
  /// the actual archive, filesystem and encrypted DB before calling this.
  /// Single-writer only; the disposable folder must not be shared.
  Future<WaffraRecoveryCheckpoint> appendVerifiedPhase({
    required int phase,
    required String sourceChecksum,
    required int entries,
    required int receipts,
  }) async {
    final prior = await inspect();
    if (phase != prior.length || phase >= phases.length || phase < 0 ||
        !_checksumPattern.hasMatch(sourceChecksum) ||
        entries < 0 || receipts < 0 ||
        (prior.isNotEmpty &&
            (prior.first.sourceChecksum != sourceChecksum ||
             prior.first.entries != entries ||
             prior.first.receipts != receipts))) {
      throw StateError('Out-of-order or inconsistent recovery phase.');
    }
    final parent = prior.isEmpty ? '' : prior.last.digest;
    final core = _record(phase, sourceChecksum, entries, receipts, parent);
    final digest = sha256.convert(utf8.encode(jsonEncode(core))).toString();
    final finalFile = File(
      '${directory.path}${Platform.pathSeparator}${_filename(phase)}');
    final pending = File('${finalFile.path}.pending');
    // A preexisting target or orphan pending file is an interrupted journal
    // and MUST NOT be overwritten.
    if (await finalFile.exists() || await pending.exists()) {
      throw StateError('Recovery checkpoint already exists or was interrupted.');
    }
    await pending.writeAsString(
      jsonEncode({...core, 'digest': digest}), flush: true);
    await pending.rename(finalFile.path);
    final inspected = await inspect();
    if (inspected.length != phase + 1 ||
        inspected.last.digest != digest) {
      throw StateError('Written recovery journal failed read-back.');
    }
    return inspected.last;
  }
}
