import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_lifecycle_evidence.dart';

void main(){
 test('M989 pending then posted same reference and account suggests settlement',(){
  final index=WaffraSmsRelatedEventIndex();
  final pending=WaffraSmsLifecycleEvidence.inspect(
   'Pending Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  final posted=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  expect(pending.stage,WaffraSmsLifecycleStage.pending);
  expect(posted.stage,WaffraSmsLifecycleStage.posted);
  expect(index.inspectAndRemember(pending),WaffraSmsRelatedEvent.none);
  expect(index.inspectAndRemember(posted),
   WaffraSmsRelatedEvent.possibleSettlement);
 });
 test('M989 exact same reference and account flags possible duplicate only',(){
  final index=WaffraSmsRelatedEventIndex();
  final a=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  expect(index.inspectAndRemember(a),WaffraSmsRelatedEvent.none);
  expect(index.inspectAndRemember(a),
   WaffraSmsRelatedEvent.possibleDuplicate);
 });
 test('M989 same amount different account or reference not duplicate',(){
  final index=WaffraSmsRelatedEventIndex();
  final a=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  final b=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **5678\nRef: ABC12345',
   sender:'AlRajhi');
  final c=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234\nRef: OTHER0123',
   sender:'AlRajhi');
  index.inspectAndRemember(a);
  expect(index.inspectAndRemember(b),WaffraSmsRelatedEvent.none);
  expect(index.inspectAndRemember(c),WaffraSmsRelatedEvent.none);
 });
 test('M989 unrecognized sender or missing bank reference cannot link',(){
  final a=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234',sender:'Unknown Sender');
  expect(a.relationKey,isNull);
 });
 test('M989 reversal and refund always get separate human-review stage',(){
  final reversed=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card reversed 50 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  final refunded=WaffraSmsLifecycleEvidence.inspect(
   'Refund received 50 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  expect(reversed.stage,WaffraSmsLifecycleStage.reversed);
  expect(refunded.stage,WaffraSmsLifecycleStage.refunded);
 });
 test('M989 2000 indexed row lookups do not require quadratic scan',(){
  final index=WaffraSmsRelatedEventIndex();
  for(var i=0;i<2000;i++){
   final ref='REF${100000+i}';
   final event=WaffraSmsLifecycleEvidence.inspect(
    'Purchase Card 20 SAR\nAccount: **1234\nRef: $ref',
    sender:'AlRajhi');
   expect(index.inspectAndRemember(event),WaffraSmsRelatedEvent.none);
  }
 });
}
