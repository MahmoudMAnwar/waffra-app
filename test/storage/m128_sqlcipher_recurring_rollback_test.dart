import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M128 SQL string', () {
    const statement = "UPDATE fresh_finance_recurring SET due_day=30 WHERE recurring_id='rent'";
    expect(statement, contains('due_day'));
  });
}
