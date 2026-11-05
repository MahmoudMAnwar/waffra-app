import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_finance_domain_supplement.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_schema.dart';

void main() {
  late Directory directory;
  late WaffraEncryptedStore source, destination;
  const secret = 'm365-disposable-sqlcipher-key-123456789000';
  const password = 'Test-only-M365-strong-password-2026';

  Future<void> init(WaffraEncryptedStore db) async {
    await WaffraFreshEncryptedVaultBootstrap(
      store:db,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  }

  WaffraFinanceDomainSupplement backup(WaffraEncryptedStore db,
    {bool enabled=true}) => WaffraFinanceDomainSupplement(
      store:db,experimentalEnabled:enabled);

  Future<int> count(WaffraEncryptedStore db,String table) async {
    return (await db.customSelect(
      'SELECT count(*) AS n FROM '+table,
    ).getSingle()).read<int>('n');
  }

  Future<void> category(WaffraEncryptedStore db) async {
    // M452: construct a real two-level hierarchy. The backup under test
    // deliberately omits category transfer, not the source parent itself.
    await db.customStatement(
      'INSERT INTO fresh_finance_categories '
      '(category_id,name,parent_id,is_income,budget_minor,source_json) '
      'VALUES (?,?,?,?,?,?)',
      ['transport','Transport','',0,0,jsonEncode({
        'id':'transport','name':'Transport','income':false,
        'parentId':'','budget':0,
      })],
    );
    await db.customStatement(
      'INSERT INTO fresh_finance_categories '
      '(category_id,name,parent_id,is_income,budget_minor,source_json) '
      'VALUES (?,?,?,?,?,?)',
      ['fuel','Fuel','transport',0,0,jsonEncode({
        'id':'fuel','name':'Fuel','income':false,
        'parentId':'transport','budget':0,
      })],
    );
  }

  Future<void> savedBudget(WaffraEncryptedStore db) async {
    await db.customStatement(
      'INSERT INTO fresh_finance_named_budgets '
      '(budget_id,name,category_id,monthly_limit_minor,is_active,'
      'alert_percent,created_at_iso,source_json) VALUES (?,?,?,?,?,?,?,?)',
      ['fuel-2026','ميزانية الوقود','fuel',20000,0,80,
       '2026-11-01T12:00:00','{}'],
    );
  }

  setUp(() async {
    directory=await Directory.systemTemp.createTemp('m365-domain-');
    source=WaffraEncryptedStore.openAt(
      File(directory.path+'/source.sqlite'),key:secret);
    destination=WaffraEncryptedStore.openAt(
      File(directory.path+'/destination.sqlite'),key:secret);
    await init(source);
    await init(destination);
  });
  tearDown(() async {
    await source.close();
    await destination.close();
    if(await directory.exists())await directory.delete(recursive:true);
  });

  test('M365 all 13 SQLCipher tables roundtrip empty with no fabricated rows',
      () async {
    final encrypted=await backup(source).export(
      password:password,explicitlyApproved:true);
    expect(encrypted,contains('waffra-secure-backup'));
    expect(encrypted,isNot(contains('waffra-sqlcipher-domain-supplement')));
    await backup(destination).restore(
      encryptedArchive:encrypted,password:password,explicitlyApproved:true);
    for(final table in WaffraFreshFinanceDomainSchema.domainTables) {
      expect(await count(destination,table),0,reason:table);
    }
  });

  test('M365 preserve paused budgets, saved plans, AI history and no overwrite',
      () async {
    await category(source);
    await category(destination);
    await savedBudget(source);
    await source.customStatement(
      'INSERT INTO fresh_finance_saved_scenarios '
      '(scenario_id,kind,name,payload_json,saved_at_iso) VALUES (?,?,?,?,?)',
      ['scenario','before_spend','Test scenario','{"price":10}',
       '2026-11-01T13:00:00'],
    );
    await source.customStatement(
      'INSERT INTO fresh_finance_ai_threads '
      '(thread_id,title,user_opted_in,created_at_iso) VALUES (?,?,1,?)',
      ['thread','Saved opt-in Q&A','2026-11-01T12:00:00'],
    );
    await source.customStatement(
      'INSERT INTO fresh_finance_ai_messages '
      '(message_id,thread_id,role,content,occurred_at_iso) '
      'VALUES (?,?,?,?,?)',
      ['message','thread','user','كم مصروفي؟',
       '2026-11-01T12:01:00'],
    );
    final encrypted=await backup(source).export(
      password:password,explicitlyApproved:true);
    expect(encrypted,isNot(contains('ميزانية الوقود')));
    expect(encrypted,isNot(contains('كم مصروفي؟')));
    await expectLater(backup(destination).restore(
      encryptedArchive:encrypted,password:'definitely-wrong-password',
      explicitlyApproved:true),throwsA(isA<Exception>()));
    expect(await count(destination,'fresh_finance_named_budgets'),0);
    await backup(destination).restore(
      encryptedArchive:encrypted,password:password,explicitlyApproved:true);
    for(final table in WaffraFreshFinanceDomainSchema.domainTables) {
      expect(await count(destination,table),await count(source,table),
        reason:table);
    }
    final row=await destination.customSelect(
      "SELECT is_active FROM fresh_finance_named_budgets "
      "WHERE budget_id='fuel-2026'",
    ).getSingle();
    expect(row.read<int>('is_active'),0);
    await expectLater(backup(destination).restore(
      encryptedArchive:encrypted,password:password,explicitlyApproved:true),
      throwsA(isA<StateError>()),
      reason:'Never silently overwrite an existing budget or AI thread');
  });

  test('M365 missing referenced categories roll back all restored records',
      () async {
    await category(source);
    await savedBudget(source);
    await source.customStatement(
      'INSERT INTO fresh_finance_saved_scenarios '
      '(scenario_id,kind,name,payload_json,saved_at_iso) VALUES (?,?,?,?,?)',
      ['scenario','before_spend','Plan','{}','2026-11-01T13:00:00'],
    );
    final encrypted=await backup(source).export(
      password:password,explicitlyApproved:true);
    await expectLater(backup(destination).restore(
      encryptedArchive:encrypted,password:password,explicitlyApproved:true),
      throwsA(isA<StateError>()));
    for(final table in WaffraFreshFinanceDomainSchema.domainTables) {
      expect(await count(destination,table),0,reason:table);
    }
  });

  test('M365 refuses another vault with same IDs but different owner ledger',
      () async {
    await category(source);
    await category(destination);
    await savedBudget(source);
    await destination.customStatement(
      "UPDATE fresh_finance_categories SET name='Different owner' "
      "WHERE category_id='fuel'",
    );
    final encrypted=await backup(source).export(
      password:password,explicitlyApproved:true);
    await expectLater(backup(destination).restore(
      encryptedArchive:encrypted,password:password,explicitlyApproved:true),
      throwsA(isA<StateError>()),
      reason:'Matching identifiers are not sufficient account ownership proof');
    expect(await count(destination,'fresh_finance_named_budgets'),0);
  });

  test('M365 consent, strong password and experimental activation are required',
      () async {
    await expectLater(backup(source).export(
      password:password,explicitlyApproved:false),
      throwsA(isA<StateError>()));
    await expectLater(backup(source,enabled:false).export(
      password:password,explicitlyApproved:true),
      throwsA(isA<StateError>()));
    await expectLater(backup(source).export(
      password:'short',explicitlyApproved:true),
      throwsA(isA<FormatException>()));
  });
}
