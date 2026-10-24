import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_migration_coordinator.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-migrate-');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': jsonEncode([
        {
          'id': 'txn-a',
          'title': 'قهوة سرية',
          'category': 'مقهى',
          'amount': 35.25,
          'income': false,
          'date': '2026-10-21T12:00:00',
          'receiptPath': null,
        }
      ]),
      'waffra_categories_v24': '[]',
      'waffra_goals_v24': '[]',
      'waffra_recurring_v24': '[]',
      'waffra_challenges_v1': '[]',
      'waffra_deleted_categories_v1': '[]',
      'waffra_deleted_goals_v1': '[]',
      'waffra_deleted_recurring_v1': '[]',
      'waffra_recurring_postponed_v1': '{}',
      'waffra_learned_merchants_v1': '{}',
      'waffra_sms_hashes_v1': <String>['sms-hash-1'],
      'waffra_monthly_budget_v1': 5000.0,
      'waffra_monthly_budget_enabled_v1': true,
      'waffra_recurring_reminders_enabled_v1': false,
      'waffra_custom_goals_v1': <String>['custom suggestion stays in preferences'],
    });
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('staging and projection leave legacy preferences unmodified', () async {
    final dbFile = File('${sandbox.path}/shadow.db');
    final before = await SharedPreferences.getInstance();
    final original = before.getString('entries');

    var acquired = false, released = false;
    final coordinator = WaffraMigrationCoordinator(
      openEncryptedStore: () async => WaffraEncryptedStore.openAt(
        dbFile, key: 'test-migration-coordinator-key-32-bytes',
      ),
      acquireWriteBarrier: () async { acquired = true; },
      releaseWriteBarrier: () async { released = true; },
    );

    final summary = await coordinator.stageWithBarrier(vaultId: 'guest-vault');
    expect(summary.verified, isTrue);
    expect(summary.entries, 1);
    expect(summary.totalRecords, greaterThan(1));
    expect(acquired, isTrue);
    expect(released, isTrue);
    expect((await SharedPreferences.getInstance()).getString('entries'), original);
    expect((await SharedPreferences.getInstance())
        .getStringList('waffra_custom_goals_v1'), contains('custom suggestion stays in preferences'));
    expect(summary.redactedTelemetry.toString(), isNot(contains('قهوة')));
    expect(summary.redactedTelemetry.toString(), isNot(contains('35.25')));

    final repeat = await coordinator.stageWithBarrier(vaultId: 'guest-vault');
    expect(repeat.sourceChecksum, summary.sourceChecksum);
    expect(repeat.entries, 1);
  });

  test('malformed old entry fails closed and releases write barrier', () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[not-valid-json',
    });
    var released = false;
    var openedDatabase = false;
    final coordinator = WaffraMigrationCoordinator(
      openEncryptedStore: () async {
        openedDatabase = true;
        return WaffraEncryptedStore.openAt(
            File('${sandbox.path}/should-not-exist.db'),
            key: 'test-migration-coordinator-key-32-bytes');
      },
      acquireWriteBarrier: () async {},
      releaseWriteBarrier: () async => released = true,
    );
    await expectLater(coordinator.stageWithBarrier(vaultId: 'v'),
        throwsA(isA<StateError>()));
    expect(released, isTrue);
    expect(openedDatabase, isFalse);
    expect((await SharedPreferences.getInstance()).getString('entries'),
        '[not-valid-json');
  });
}
