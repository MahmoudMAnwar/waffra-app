import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';
import 'package:waffra/waffra_sms_fx_review.dart';

void main() {
  const key = 'm293-ephemeral-sqlcipher-qa-key-32';
  final quoteAt = DateTime.utc(2026, 10, 27, 9);
  final approvedAt = DateTime.utc(2026, 10, 28);
  late Directory temp;
  late WaffraEncryptedStore vault;

  WaffraFreshLedgerRepository repository() =>
      WaffraFreshLedgerRepository(store: vault, experimentalEnabled: true);

  WaffraSmsFxReview approvedUsdToSar() {
    final quote = WaffraSmsFxQuote.fromUsdRates({
      'result': 'success',
      'time_last_update_unix': quoteAt.millisecondsSinceEpoch ~/ 1000,
      'rates': {'USD': 1.0, 'SAR': 3.75},
    }, originalCurrency: 'USD', targetCurrency: 'SAR', now: approvedAt);
    return WaffraSmsFxReview.approve(
      originalAmount: 100,
      quote: quote,
      userConfirmed: true,
      now: approvedAt,
    );
  }

  WaffraFreshLedgerEntry entry(WaffraSmsFxReview fx,
      {int amountMinor = 37500}) => WaffraFreshLedgerEntry(
    id: 'usd-purchase',
    title: 'International purchase',
    categorySnapshot: 'Shopping',
    amountMinor: amountMinor,
    isIncome: false,
    occurredIso: '2026-10-27T18:30:00',
    fxReview: fx,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waffra-m293-fx-');
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/finance.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  });
  tearDown(() async {
    await vault.close();
    await temp.delete(recursive: true);
  });

  test('approved original USD and SAR conversion survive SQLCipher cold reopen',
      () async {
    final fx = approvedUsdToSar();
    await repository().add(entry(fx));
    final raw = await vault.customSelect(
      "SELECT amount_minor,source_json FROM fresh_finance_entries "
      "WHERE entry_id='usd-purchase'",
    ).getSingle();
    expect(raw.read<int>('amount_minor'), 37500);
    final payload = jsonDecode(raw.read<String>('source_json')) as Map;
    expect(payload['amount'], 375);
    expect(payload['waffra_fx_provenance_v1']['originalMinor'], 10000);
    expect(payload['waffra_fx_provenance_v1']['originalCurrency'], 'USD');
    expect(payload['waffra_fx_provenance_v1']['convertedMinor'], 37500);
    expect(payload['waffra_fx_provenance_v1']['convertedCurrency'], 'SAR');

    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/finance.sqlite'), key: key,
    );
    final saved = (await repository().list()).single;
    expect(saved.fxReview!.toProvenanceJson(), fx.toProvenanceJson());
    expect((await repository().totals()).expenseMinor, 37500);
  });

  test('foreign amount without corresponding exact SAR value is rejected',
      () async {
    final fx = approvedUsdToSar();
    expect(() => WaffraFreshLedgerRepository.validateExperimentalEntry(
      entry(fx, amountMinor: 10000)), throwsArgumentError);
    await expectLater(repository().add(entry(fx, amountMinor: 10000)),
        throwsArgumentError);
    expect((await repository().list()), isEmpty);
  });

  test('FX edit and delete require future audited Undo + backup parity',
      () async {
    final fx = approvedUsdToSar();
    await repository().add(entry(fx));
    await expectLater(repository().replace(entry(fx)),
        throwsStateError);
    await expectLater(repository().remove('usd-purchase'),
        throwsStateError);
    expect((await repository().list()), hasLength(1));
    expect((await repository().totals()).expenseMinor, 37500);
  });

  test('corrupt FX witness is rejected; no silent converted amount shown',
      () async {
    final fx = approvedUsdToSar();
    await repository().add(entry(fx));
    final row = await vault.customSelect(
      "SELECT source_json FROM fresh_finance_entries "
      "WHERE entry_id='usd-purchase'",
    ).getSingle();
    final data = jsonDecode(row.read<String>('source_json')) as Map<String, dynamic>;
    final witness = data['waffra_fx_provenance_v1'] as Map<String, dynamic>;
    witness['convertedMinor'] = 1;
    await vault.customStatement(
      'UPDATE fresh_finance_entries SET source_json=? WHERE entry_id=?',
      [jsonEncode(data), 'usd-purchase'],
    );
    await expectLater(repository().list(), throwsFormatException);
    expect((await repository().totals()).expenseMinor, 37500,
        reason: 'Unsafe witness must not rewrite authoritative integer SQL');
  });
}
