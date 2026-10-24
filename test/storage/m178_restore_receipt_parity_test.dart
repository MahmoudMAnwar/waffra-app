import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_restored_finance_parity.dart';

void main() {
  final source = <String, dynamic>{
    'id': 'synthetic-1',
    'amount': 12.25,
    'income': false,
    'date': '2026-10-24T00:00:00.000Z',
    'title': 'Synthetic transaction',
    'receiptPath': '/old-phone/receipt.jpg',
  };
  final migrated = <String, dynamic>{
    ...source,
    'receiptPath': 'waffra-receipt://opaque-id/0',
  };

  test('M178 accepts only receipt reference remapping on identical rows', () {
    WaffraRestoredFinanceParity.requireExactTransactionFields(
      original: source, restored: migrated);
  });

  test('M178 rejects injected, missing or altered transaction fields', () {
    for (final attack in <Map<String, dynamic>>[
      {...migrated, 'unexpected': 'injected'},
      {...migrated}..remove('title'),
      {...migrated, 'amount': 99.99},
    ]) {
      expect(() => WaffraRestoredFinanceParity.requireExactTransactionFields(
          original: source, restored: attack), throwsStateError);
    }
  });

  test('M178 accepts exact finance key set and separately stored suggestions', () {
    WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: <String, Object?>{
        'entries': '[]',
        'waffra_sms_hashes_v1': <String>[],
        'waffra_custom_goals_v1': <String>['Synthetic goal'],
      },
      restored: <String, Object?>{
        'entries': '[]',
        'waffra_sms_hashes_v1': <String>[],
      },
    );
  });

  test('M178 refuses missing, extra and unsupported restore keys', () {
    expect(() => WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: <String, Object?>{
        'entries': '[]',
        'waffra_goals_v24': '[]',
      },
      restored: <String, Object?>{'entries': '[]'},
    ), throwsStateError);
    expect(() => WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: <String, Object?>{'entries': '[]'},
      restored: <String, Object?>{
        'entries': '[]',
        'waffra_recurring_v24': '[]',
      },
    ), throwsStateError);
    expect(() => WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: <String, Object?>{
        'entries': '[]',
        'owner_secret': 'not-a-finance-key',
      },
      restored: <String, Object?>{'entries': '[]'},
    ), throwsStateError);
  });
}
