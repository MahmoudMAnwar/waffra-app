import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_receipt_ocr_parser.dart';

void main(){
  const actualThree='''Yesterday • 11:48 pm
شراء PoS
عبر:7678;مدى-مدى باي
SAR 4.50
Joanna Sa
23:49 30/10/26
شراء PoS
عبر:7678;مدى-مدى باي
SAR 10
Joanna Sa
00:01 30/10/26
شراء PoS
عبر:7678;مدى-مدى باي
SAR 4
Joanna Sa
14:44 30/10/26''';
  const foreign='AED debited from account 136.00 ending with 1001 '
    'at SARAYA HALAB RESTAURAN ABU DHABI AE. Balance: 4857.96 AED';

  test('M335 actual Al Rajhi OCR evidence: three expenses, not six',(){
    final candidates=WaffraBankScreenshotParser.reviewItems(actualThree);
    expect(candidates.length,3);
    expect(candidates.map((x)=>x.amount).toList(),[4.5,10.0,4.0]);
    expect(candidates.every((x)=>!x.income),isTrue);
    expect(candidates.fold<double>(0,(n,x)=>n+x.amount!),18.5);
    final receipt=WaffraReceiptOcrParser.parse(actualThree);
    expect(receipt.amount,isNull);
    expect(receipt.merchant,isNull);
  });

  test('M335 AED debited verb before amount: do not treat as SAR',(){
    expect(WaffraSmsCurrencies.currenciesForMessage(foreign),{'AED'});
    final original=WaffraSmsCurrencies.originalAmount(foreign);
    expect(original?.currency,'AED');
    expect(original?.amount,136);
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(foreign),isTrue);
    final parsed=BankParser.parse(foreign);
    expect(parsed.amount,isNull);
    expect(parsed.requiresCurrencyReview,isTrue);
    expect(parsed.income,isFalse);
    expect(WaffraReceiptOcrParser.parse(foreign).amount,isNull);
    expect(WaffraReceiptOcrParser.parse(foreign).merchant,isNull);
  });

  test('M636 automatic SMS editor retains category validation',(){
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains('waffraManualCategoryParents('));
    expect(app,contains('waffraManualCategoryChildren('));
    expect(app,contains('waffraCanAssignManualCategory('));
    expect(app,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
    expect(app,isNot(contains('Future<void> bulkSmsSheet(')));
  });

  test('M636 real SMS remains deterministic without Qwen',(){
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,isNot(contains('WaffraOnDeviceQwen')));
    expect(app,isNot(contains('_reviewAiPastedBankMessages')));
    expect(app,contains('WaffraSmsCurrencies.originalAmount('));
    expect(app,contains('await WaffraAutoSms.acknowledgeCommitted([id]);'));
  });
}
