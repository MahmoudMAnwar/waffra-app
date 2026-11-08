import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level regression guards for the M547 migration. These tests cannot
/// prove UI frame times or Android provider/Keystore performance; release/profile
/// Android device traces and finance SMS end-to-end checks are still mandatory.
void main() {
 test('M547 historical SMS import has 1000 review slots and atomic cursor/queue persistence', () {
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final history=native.split('fun importConsentMonth(')[1]
   .split('/** Claim each review notification once')[0];
  expect(native,contains('private const val maxCandidates = 1000'));
  expect(native,contains('"capacity" to maxCandidates'));
  expect(native,contains('"initialComplete" to prefs.getBoolean(historyInitialCompleted, false)'));
  expect(history,contains('val queue = read(context)'));
  expect(history,contains('val excluded = readExcluded(context)'));
  expect(history,contains('val existingIds = HashSet<String>'));
  expect(history,contains('rows.size <= maxRead'));
  expect(history,contains('if (queue.length() >= maxCandidates)'));
  expect(history,contains('if (accepted > 0)'));
  expect(history,contains('editor.putString(queueName, seal(queue.toString()))'));
  expect(history,contains('.putLong(historyCursorAt, nextAt)'));
  expect(history,contains('.putLong(historyCursorId, nextId)'));
  expect(history,contains('.putBoolean(historyComplete, complete)'));
  expect(history,contains('if (!editor.commit())'));
  expect(history,isNot(contains('offer(context, sender, body')));
 });

 test('M547 new-only rescans never clear a previously completed cursor', () {
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final main=File('lib/main.dart').readAsStringSync();
  final restart=native.split(
   'fun restartCompletedHistory(context: Context): Boolean')[1]
   .split('private data class HistoricalSmsRow')[0];
  final rescan=main.split('Future<void> _rescanAutoSmsInbox()async{')[1]
   .split('Future<void>? _autoSmsRefreshInFlight;')[0];
  expect(restart,isNot(contains('.remove(historyCursorAt)')));
  expect(restart,isNot(contains('.remove(historyCursorId)')));
  expect(rescan,isNot(contains('restartCompletedHistory()')));
  expect(rescan,contains('final before=await WaffraAutoSms.scanProgress();'));
  expect(rescan,contains('final after=await WaffraAutoSms.scanProgress();'));
  expect(rescan,contains('final scanned=(nowScanned-priorScanned)'));
  expect(rescan,contains('final added=(current-previous)'));
  expect(rescan,contains("before?['initialComplete']!=true"));
  expect(rescan,contains('استكمال الفحص الأول'));
 });

 test('M547 only an explicit rescan fetches historical pages during UI interactions', () {
  final main=File('lib/main.dart').readAsStringSync();
  final resume=main.split('void _m468OnResume(){')[1]
   .split('@override void initState()')[0];
  final open=main.split('Future<void> _openAutoSmsInbox()async{')[1]
   .split('// Every bank sender gets one group.')[0];
  expect(resume,contains('unawaited(_refreshAutoSmsInbox());'));
  expect(resume,isNot(contains('importMonth:')));
  expect(open,contains('await _refreshAutoSmsInbox();'));
  expect(open,isNot(contains('importMonth:true')));
  final manual=main.split('// The expense/income learner applies only AFTER')[1]
   .split('for(final staged in stagedReceiptCopies')[0];
  expect(manual,isNot(contains('_refreshAutoSmsInbox(importMonth:true)')));
  expect(main,contains('void _receiveAutoSmsNotice()'));
  expect(main,contains('if(mounted&&ready)unawaited(_refreshAutoSmsInbox());'));
  expect(main,contains('smsHashes.contains(bankSmsHash(body))'));
  expect(main,contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
 });
}
