import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source contracts supplement, not replace, real widget/device acceptance.
/// No test in this file writes to the user financial SQLCipher ledger.
void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final accountPage =
      File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
  final mark = File('lib/waffra_riyal_symbol.dart').readAsStringSync();
  final dashboard = main.split(' Widget dashboard(){')[1]
      .split(' List<MoneyEntry> get analysisEntries')[0];
  final transfer = main.split(' Widget _m647TransferCard(')[1]
      .split(' Widget _m649SavingsCard(')[0];
  final savings = main.split(' Widget _m649SavingsCard(')[1]
      .split(' Future<void> _m647ShowInternalTransfers(')[0];
  final compact = main.split(' Widget compactTransaction(')[1]
      .split(' Widget _m549HomeFinanceAction(')[0];

  test('M677 only one financial activity type chip row remains', () {
    const choices = "['الكل','الدخل','المصروفات','التحويلات','الادخار','الاستحقاقات']";
    expect(choices.allMatches(dashboard).length, 1);
    expect(dashboard, contains("Key('waffra-activity-single-filter-chips')"));
    expect(dashboard, contains('spacing:10,runSpacing:12'));
    expect(dashboard, contains('const SizedBox(height:14)'));
    expect(dashboard, isNot(contains("for(final choice in $choices")));
    expect(dashboard, contains('if(showTransactionFilters)...['));
    expect(dashboard, contains('showAllTransactions=false;'));
    expect(dashboard, contains('typeFilter=choice;categoryFilter='));
    expect(dashboard, contains("Key('waffra-financial-activity-toggle')"));
    expect(dashboard.indexOf('if(financialActivityExpanded)...['),
        lessThan(dashboard.indexOf('future:_m652UnifiedActivities(')));
    expect(dashboard,
        isNot(contains("WaffraText(waffraIsEnglish?'Income':'الدخل'")));
  });

  test('M672 transfer arrow points source to destination in Arabic and English', () {
    expect(transfer, contains('t.fromAccountId'));
    expect(transfer, contains('t.toAccountId'));
    expect(transfer, contains("'من الحساب'"));
    expect(transfer, contains("'إلى الحساب'"));
    expect(transfer, contains('waffraIsEnglish?Icons.arrow_forward_rounded:'));
    expect(transfer, contains('Icons.arrow_back_rounded,textDirection:TextDirection.ltr'));
    expect(transfer, contains("Key('m647-verified-transfer-'"));
    expect(transfer, isNot(contains('commitConfirmedManual(')));
    expect(transfer, isNot(contains('api.transfer(')));
  });

  test('M682 activity cards are compact without dropping amount labels', () {
    expect(transfer, contains('BoxConstraints(minHeight:98)'));
    expect(savings, contains('BoxConstraints(minHeight:96)'));
    expect(compact, contains('BoxConstraints(minHeight:98)'));
    for(final card in <String>[transfer,savings,compact]){
      expect(card, isNot(contains('BoxConstraints(minHeight:144)')));
      expect(card, contains("'Amount':'المبلغ'"));
    }
    expect(compact, contains("'Total goal due':'إجمالي الاستحقاق'"));
    expect(compact, contains("entry.income?entry.amount:-entry.amount"));
    expect(transfer, contains('_m467SelectedAccount==t.fromAccountId'));
    expect(transfer, contains('_m467SelectedAccount==t.toAccountId'));
  });

  test('M673 shared official SAR mark is adjusted without changing parser', () {
    expect(mark, contains("waffraRiyalAsset = 'assets/Saudi_Riyal_Symbol-1.png'"));
    expect(mark, contains('Transform.translate('));
    expect(mark, contains('offset: Offset(0, -size * .09)'));
    expect(mark, contains('colorBlendMode: BlendMode.srcIn'));
    expect(mark, contains('currencyCode != \'SAR\''));
    expect(mark, contains('WaffraCurrencyMark('));
  });

  test('M675 delete refreshes witness after approval and keeps Home visible', () {
    final deleting = main.split(' Future<void> _deleteVerifiedEntry(')[1]
        .split(' Future<void> _undoVerifiedDeletedEntry(')[0];
    expect(deleting, contains('if(approved!=true||!mounted)return;'));
    final afterApproval =
        deleting.split('if(approved!=true||!mounted)return;')[1];
    expect(afterApproval, contains('final current=await _financeAuthority.load('));
    expect(afterApproval,
        contains('WaffraVerifiedTransactionUiGuard.requireUnchangedSelected('));
    expect(afterApproval, contains('expectedImageHashes:receipt.imageSha256,'));
    expect(afterApproval, contains('_publishVerifiedTransactionLedger(committed);'));
    expect(afterApproval, contains('unawaited(_refreshFromVerifiedFinance());'));
    expect(afterApproval, isNot(contains('unawaited(_loadFinanceSafely());')));
    expect(afterApproval, contains('onAction:(){if(mounted)unawaited(_undoVerifiedDeletedEntry(entry.id));}'));
  });

  test('M678 direct accessible account edit retains verified writer and exact IDs', () {
    expect(accountPage, contains("Key('waffra-edit-account-details-'+a.id)"));
    expect(accountPage, contains("t('تعديل بيانات الحساب','Edit account details')"));
    expect(accountPage, contains('onPressed:a.archived?null:()=>rename(a)'));
    expect(accountPage, contains("Key('waffra-account-edit-name')"));
    expect(accountPage, contains("Key('waffra-account-edit-last-four')"));
    expect(accountPage, contains("RegExp(r'^[0-9]{4}\$')"));
    expect(accountPage, contains('FilteringTextInputFormatter.digitsOnly'));
    expect(accountPage, contains('final latest=await verified.balances();'));
    expect(accountPage, contains('await verified.verifiedBankSuffix(item.id)!=savedSuffix'));
    expect(accountPage, contains('await verified.renameAccountWithSuffix('));
    expect(accountPage, contains('id:item.id,name:edited.name,lastFour:edited.lastFour!,'));
    expect(accountPage, contains('userConfirmed:true'));
    expect(accountPage, contains('reload();'));
    expect(accountPage, isNot(contains('createAccount('
      'id:item.id,name:edited.name')));
  });
}
