import 'dart:io';

/// Reassemble the real Dart-part methods at their original line-order markers,
/// solely for preexisting source-based regression expectations.
String _method(String path,String marker){
 final c=File(path).readAsStringSync();
 final a=c.indexOf(marker),b=c.lastIndexOf('\n}');
 if(a<0||b<=a)throw StateError('Missing extracted method in $path');
 return c.substring(a,b);
}
String readWaffraMainSourceForContracts(){
 var s=File('lib/main.dart').readAsStringSync();
 const p=' // M687: PDF exporter moved to a same-library State extension.\n';
 const q=' // M687: Profile page moved to a same-library State extension.\n';
 if(s.split(p).length!=2||s.split(q).length!=2){
  throw StateError('Missing or duplicated Dart part marker');
 }
 s=s.replaceFirst(p,_method('lib/waffra_home_pdf_reports.part.dart',
  ' Future<void> exportEntriesPdf('));
 s=s.replaceFirst(q,_method('lib/waffra_home_profile.part.dart',' Widget profilePage(){'));
 return s;
}
