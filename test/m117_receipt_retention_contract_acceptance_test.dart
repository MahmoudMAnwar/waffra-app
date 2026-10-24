import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// This contract deliberately does not delete a single byte. It prevents
/// accidental introduction of an unsafe receipt deletion/undo implementation
/// while a separate retention journal and device recovery remain unverified.
void main() {
  final authority = File(
    'lib/storage/waffra_verified_finance_authority.dart',
  ).readAsStringSync();
  final vault = File(
    'lib/storage/waffra_encrypted_receipt_vault.dart',
  ).readAsStringSync();
  final bridge = File(
    'lib/storage/waffra_verified_encrypted_finance_bridge.dart',
  ).readAsStringSync();
  final entryProjection = File(
    'lib/storage/waffra_encrypted_entry_projection_guard.dart',
  ).readAsStringSync();

  test('M117: receipt replacement has expected digest CAS and no delete', () {
    expect(vault, contains('replaceExistingImage('));
    expect(vault, contains('expectedSha256'));
    expect(vault, contains('old[position].sha256Hex != expectedSha256'));
    expect(vault, contains('Unrelated encrypted receipt changed.'));
    expect(vault, isNot(contains('DELETE FROM fresh_finance_receipt_blobs')));
    expect(vault, isNot(contains('DROP TABLE fresh_finance_receipt_blobs')));
  });

  test('M117: finance source authority requires encrypted receipt witness', () {
    expect(authority, contains('replaceEncryptedReceiptImage('));
    expect(authority, contains('backend != WaffraRuntimeFinanceBackend.verifiedEncrypted'));
    expect(authority, contains('loadEncryptedReceiptImages('));
    expect(bridge, contains('await _requireActivatedUnderLock();'));
    expect(bridge, contains('await vault.replaceExistingImage('));
  });

  test('M117: transaction edit must not change receipt owner or reference', () {
    expect(entryProjection, contains("changed['receiptPath'] != original['receiptPath']"));
    expect(entryProjection, contains('Transaction add/delete needs its dedicated atomic encrypted writer.'));
  });

  test('M117: deleting or restoring attachments remains release-blocked', () {
    expect(authority, isNot(contains('deleteEncryptedReceipt(')));
    expect(authority, isNot(contains('restoreDeletedEncryptedReceipt(')));
    expect(bridge, isNot(contains('deleteVerifiedReceipt(')));
    expect(bridge, isNot(contains('restoreVerifiedReceipt(')));
    expect(vault, isNot(contains('purgeReceipt(')));
    expect(vault, isNot(contains('removeReceipt(')));
  });
}
