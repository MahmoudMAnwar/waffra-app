import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M717: enumerate actual transitive lib imports/parts from production main,
/// not just a text-search of main.dart. Test-only safety helpers stay test-only.
void main(){
 test('M717 retired cloud and AI code cannot be reached from app entrypoint',(){
  final visited=<String>{};
  final queue=<String>['lib/main.dart'];
  final refs=RegExp(r'''(?m)^\s*(?:import|part)\s+['"]([^'"]+)['"]\s*;''');
  while(queue.isNotEmpty){
   final path=queue.removeLast();
   if(!visited.add(path))continue;
   final file=File(path);
   expect(file.existsSync(),isTrue,reason:'Missing registered/imported Dart file $path');
   final source=file.readAsStringSync();
   for(final match in refs.allMatches(source)){
    final uri=match.group(1)!;
    if(uri.startsWith('dart:'))continue;
    if(uri.startsWith('package:')&&!uri.startsWith('package:waffra/'))continue;
    final relative=uri.startsWith('package:waffra/')?
      'lib/'+uri.substring('package:waffra/'.length):
      file.parent.uri.resolve(uri).toFilePath();
    final normalized=File(relative).absolute.path;
    final libRoot=Directory('lib').absolute.path;
    if(!normalized.startsWith(libRoot+'/'))continue;
    final logical='lib/'+normalized.substring(libRoot.length+1).replaceAll('\\','/');
    queue.add(logical);
   }
  }
  for(final obsolete in <String>[
    'lib/waffra_cloudflare_sms_gateway.dart',
    'lib/waffra_sms_cloud_service.dart',
    'lib/waffra_sms_cloud_redactor.dart',
    'lib/waffra_ai_finance_brain.dart',
    'lib/waffra_ai_finance_coach.dart',
    'lib/waffra_ai_recorded_answers.dart',
    'lib/waffra_ask_scope.dart',
  ]){
   expect(visited,not(contains(obsolete)),reason:
    'Retired cloud/AI path must not be compiled into the production app: $obsolete');
  }
 });
 test('M717 retired transport has no HTTP client dependency',(){
  final source=File('lib/waffra_cloudflare_sms_gateway.dart').readAsStringSync();
  expect(source,isNot(contains("import 'package:http/http.dart'")));
  expect(source,isNot(contains('http.Client?')));
  expect(source,contains('static bool get configured => false;'));
  expect(source,contains('}) async => null;'));
 });
}
