import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';

void main() {
  late Directory sandbox;
  setUp(() async => sandbox = await Directory.systemTemp.createTemp('waffra-projection-'));
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Map<String, Object?> fixture() => {
        'entries': jsonEncode([
          {
            'id': 'tx-1',
            'title': 'قهوة ☕',
            'category': 'مقهى',
            'amount': 15.75,
            'income': false,
            'date': '2026-10-21T22:59:00',
            'receiptPath': jsonEncode(['/receipt/1.png', '/receipt/2.jpg']),
          },
          {
            'id': 'tx-2',
            'title': 'Salary / راتب',
            'category': 'راتب',
            'amount': 4000.50,
            'income': true,
            'date': '2026-10-20T08:00:00',
            'receiptPath': null,
          },
        ]),
        'waffra_categories_v24': jsonEncode([
          {
            'id': 'cat-1',
            'name': 'مقهى',
            'income': false,
            'budget': 80.00,
            'icon': 'coffee',
            'color': 0xFF007F55,
            'parentId': '',
            'alertPercent': 80,
          }
        ]),
        'waffra_goals_v24': jsonEncode([
          {'id': 'goal-1', 'name': 'سيارة', 'target': 25000, 'saved': 400}
        ]),
        'waffra_recurring_v24': jsonEncode([
          {
            'id': 'rec-1',
            'title': 'الإيجار',
            'category': 'سكن',
            'amount': 2000,
            'income': false,
            'day': 26,
            'active': true,
            'startAt': '2026-10-26T00:00:00',
          }
        ]),
        'waffra_challenges_v1': jsonEncode([
          {
            'id': 'c-1',
            'title': 'تحدي 30 يوم',
            'dailyAmount': 5,
            'days': 30,
            'completedDays': 9,
            'lastDone': '2026-10-20T00:00:00',
          }
        ]),
        'waffra_deleted_categories_v1': jsonEncode([
          {
            'category': {
              'id': 'cat-x',
              'name': 'قديم',
              'income': false,
              'budget': 0,
            },
            'deletedAt': '2026-10-21T13:00:00',
          }
        ]),
        'waffra_deleted_goals_v1': jsonEncode([
          {
            'goal': {
              'id': 'goal-x',
              'name': 'القديم',
              'target': 1000,
              'saved': 100,
            },
            'deletedAt': '2026-10-21T13:00:00',
          }
        ]),
        'waffra_deleted_recurring_v1': jsonEncode([
          {
            'recurring': {
              'id': 'rec-x',
              'title': 'قديم',
              'category': 'أخرى',
              'amount': 7,
              'day': 2,
            },
            'deletedAt': '2026-10-21T13:00:00',
          }
        ]),
        'waffra_recurring_postponed_v1':
            jsonEncode({'rec_rec-1_2026-10-26': '2026-10-28T00:00:00'}),
        'waffra_learned_merchants_v1':
            jsonEncode({'مقهى معروف': 'مقهى'}),
        'waffra_sms_hashes_v1': <String>['hash-one', 'hash-two'],
        'waffra_monthly_budget_v1': 2500.50,
        'waffra_monthly_budget_enabled_v1': true,
        'waffra_recurring_reminders_enabled_v1': false,
      };

  test('full snapshot projects atomically and reopens without changing JSON', () async {
    final dbFile = File('${sandbox.path}/finance.db');
    var db = WaffraEncryptedStore.openAt(dbFile,
        key: 'testing-project-funds-not-production-32');
    final raw = fixture();
    final first = await db.stageSnapshot('vault-1', raw);
    final report = await db.buildRelationalProjection('vault-1');
    expect(report.ledgerEntries, 2);
    expect(report.incomeMinor, 400050);
    expect(report.expenseMinor, 1575);
    expect(report.receiptReferences, 2);
    expect(report.stagedSourceRecords, first.recordCount);

    final original = (jsonDecode(raw['entries']! as String) as List)
        .map((x) => jsonEncode(x)).toList();
    expect(await db.readOriginalEntryJson('vault-1'), original);
    final same = await db.buildRelationalProjection('vault-1');
    expect(same.sourceSha256, report.sourceSha256);
    await db.close();

    db = WaffraEncryptedStore.openAt(dbFile,
        key: 'testing-project-funds-not-production-32');
    final reopened = await db.buildRelationalProjection('vault-1');
    expect(reopened.ledgerEntries, 2);
    expect(await db.readOriginalEntryJson('vault-1'), original);
    await db.close();

    // No plaintext SQLite header or transaction title is stored in raw file.
    final bytes = await dbFile.readAsBytes();
    expect(bytes.take(16).toList(), isNot(utf8.encode('SQLite format 3\u0000')));
    expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('قهوة ☕')));
  });

  test('different vaults remain isolated', () async {
    final db = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/multi.db'),
      key: 'testing-project-funds-not-production-32',
    );
    final original = fixture();
    final changed = fixture()
      ..['entries'] = jsonEncode([
        {
          'id': 'guest-tx',
          'title': 'Independent record',
          'category': 'Guest',
          'amount': 4,
          'income': false,
          'date': '2026-10-20T08:00:00',
          'receiptPath': null,
        }
      ]);
    await db.stageSnapshot('guest', original);
    await db.stageSnapshot('signed-in', changed);
    final guest = await db.buildRelationalProjection('guest');
    final signedIn = await db.buildRelationalProjection('signed-in');
    expect(guest.ledgerEntries, 2);
    expect(signedIn.ledgerEntries, 1);
    expect((await db.readOriginalEntryJson('guest')).length, 2);
    expect((await db.readOriginalEntryJson('signed-in')).length, 1);
    await db.close();
  });

  test('projection failure rolls back inserts and journal', () async {
    final db = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/rollback.db'),
      key: 'testing-project-funds-not-production-32',
    );
    final invalid = fixture()
      ..['waffra_deleted_goals_v1'] = jsonEncode([
        {
          'goal': {
            'id': 'goal-x',
            'name': 'bad target',
            'target': 0,
            'saved': 100,
          },
          'deletedAt': '2026-10-21T13:00:00',
        }
      ]);
    await db.stageSnapshot('vault', invalid);
    await expectLater(
      db.buildRelationalProjection('vault'),
      throwsA(isA<Exception>()),
    );
    // Creation and inserts happen inside the same transaction. A failed
    // CHECK constraint must roll back even the projection schema DDL.
    final projected = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='projection_runs'",
    ).get();
    expect(projected, isEmpty);
    await db.close();
  });
}
