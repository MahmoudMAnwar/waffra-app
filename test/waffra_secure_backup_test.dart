import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main(){
 test('encrypted backup round trips with a password',()async{
  const content='{"format":"waffra-backup","entries":[{"amount":120.50}]}';
  final encrypted=await WaffraSecureBackup.encrypt(content,'correct horse battery');
  expect(encrypted,contains('waffra-secure-backup'));
  expect(encrypted,doesNot(contains('120.50')));
  expect(await WaffraSecureBackup.decrypt(encrypted,'correct horse battery'),content);
 });
 test('wrong password cannot decrypt',()async{
  final encrypted=await WaffraSecureBackup.encrypt('secret','validpassword');
  await expectLater(WaffraSecureBackup.decrypt(encrypted,'wrongpassword'),throwsA(isA<Exception>()));
 });
 test('a short password is rejected',()async{
  await expectLater(WaffraSecureBackup.encrypt('content','short'),throwsFormatException);
 });
 test('legacy backups can still be imported',()async{
  const backup='{"format":"waffra-backup","entries":[]}';
  expect(await WaffraSecureBackup.decrypt(backup,''),backup);
 });
}
