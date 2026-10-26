import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M238 encrypted Home receipt delete is only visible on encrypted source',
      () {
    final code = File('lib/main.dart').readAsStringSync();
    final begin = code.indexOf(' Future<void> transactionActions(MoneyEntry entry)async {');
    final end = code.indexOf(' Widget _transactionActionTile(', begin);
    expect(begin, greaterThan(0));
    expect(end, greaterThan(begin));
    final menu = code.substring(begin, end);
    expect(menu, contains(
      "case 'receiptRecycle':await _recycleVerifiedReceiptBatch(entry);break;"));
    final gatedAction = menu.indexOf(
      "if(_lastFinanceAuthorityRead?.source==");
    final open = menu.indexOf(
      "Navigator.pop(ctx,'receiptRecycle')");
    expect(gatedAction, greaterThan(0));
    expect(open, greaterThan(gatedAction));
  });

  test('M238 destructive receipt update requires active SQL witnesses and approval',
      () {
    final code = File('lib/main.dart').readAsStringSync();
    final start = code.indexOf(
      ' Future<void> _recycleVerifiedReceiptBatch(MoneyEntry entry)async{');
    final finish = code.indexOf(
      ' Future<void> transactionActions(', start);
    expect(start, greaterThan(0));
    expect(finish, greaterThan(start));
    final source = code.substring(start, finish);
    expect(source, contains('WaffraFinanceRoute.receiptView'));
    expect(source, contains('screen.load(entry.id)'));
    expect(source, contains('owner.single[\'receiptPath\']!=entry.receiptPath'));
    expect(source, contains('baseline.images.length!=waffraReceiptPaths'));
    expect(source, contains('confirmDeletion('));
    expect(source, contains('screen.moveToRecycle('));
    expect(source, contains('userConfirmed:true'));
    expect(source, contains('screen.restore('));
    expect(source, contains('WaffraFinanceRoute.dashboardRead'));
    expect(source, contains('No transaction was erased.'));
  });
}
