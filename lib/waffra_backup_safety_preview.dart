import 'dart:convert';

/// M1000: UI preview ONLY after password-authenticated decryption.
/// Never repair duplicated IDs or infer that two equal SAR amounts are equal
/// transactions. Actual restore must still pass the existing full crypto,
/// SQLCipher staging, receipt and source-witness preflight.
class WaffraBackupSafetyPreview {
 const WaffraBackupSafetyPreview({
  required this.format,required this.entries,
  required this.accounts,required this.goals,required this.recurring,
  required this.transfers,required this.duplicateIds,
  required this.earliestDay,required this.latestDay,
  required this.receipts,
 });
 final String format;
 final int entries,accounts,goals,recurring,transfers,duplicateIds,receipts;
 final DateTime? earliestDay,latestDay;
 bool get safeToContinue=>duplicateIds==0;
 static WaffraBackupSafetyPreview legacy(Map<String,dynamic> raw){
  if(raw['format']!='waffra-backup'||raw['version']!=24||
     raw['entries'] is! List||raw['goals'] is! List||
     raw['recurring'] is! List||raw['categories'] is! List){
   throw const FormatException('Unsupported authenticated legacy backup.');
  }
  final lines=raw['entries'] as List;
  return inspectEntries(
   format:'V24',entries:lines,accounts:0,transfers:0,receipts:0,
   goals:(raw['goals'] as List).length,
   recurring:(raw['recurring'] as List).length);
 }
 static WaffraBackupSafetyPreview v3({
  required List<dynamic> entries,required int accounts,
  required int transfers,required int goals,required int recurring,
  required int receipts,
 })=>inspectEntries(
  format:'V3',entries:entries,accounts:accounts,
  transfers:transfers,goals:goals,recurring:recurring,
  receipts:receipts);
 static WaffraBackupSafetyPreview inspectEntries({
  required String format,required List<dynamic> entries,
  required int accounts,required int transfers,
  required int goals,required int recurring,required int receipts,
 }) {
  if(entries.length>100000||accounts<0||transfers<0||goals<0||
     recurring<0||receipts<0)throw const FormatException(
      'Backup preview exceeds verified bounds.');
  final seen=<String>{};
  var duplicates=0;
  DateTime? earliest,latest;
  for(final item in entries){
   if(item is! Map)throw const FormatException('Malformed transaction row.');
   final id=item['id'];
   if(id is! String||id.trim().isEmpty) {
    throw const FormatException('Missing immutable transaction ID.');
   }
   if(!seen.add(id))duplicates++;
   final date=item['date'];
   // Legacy V24 date may be ISO; an invalid date must fail closed, not
   // become today's date or be used for reconciliation.
   if(date is! String||DateTime.tryParse(date)==null){
    throw const FormatException('Malformed transaction date.');
   }
   final parsed=DateTime.parse(date);
   if(earliest==null||parsed.isBefore(earliest))earliest=parsed;
   if(latest==null||parsed.isAfter(latest))latest=parsed;
  }
  return WaffraBackupSafetyPreview(
   format:format,entries:entries.length,accounts:accounts,
   goals:goals,recurring:recurring,transfers:transfers,
   duplicateIds:duplicates,receipts:receipts,
   earliestDay:earliest,latestDay:latest);
 }
 String summary(bool english){
  final range=earliestDay==null?'—':
   earliestDay!.toIso8601String().split('T').first+' → '+
   latestDay!.toIso8601String().split('T').first;
  return english
   ?'Archive: '+format+
    '\nTransactions: '+entries.toString()+
    '\nAccounts: '+accounts.toString()+
    '\nGoals: '+goals.toString()+
    '\nRecurring: '+recurring.toString()+
    '\nTransfers: '+transfers.toString()+
    '\nReceipts: '+receipts.toString()+
    '\nDates: '+range+
    '\nDuplicate transaction IDs: '+duplicateIds.toString()+
    '\nNo changes have been made yet.'
   :'نوع النسخة: '+format+
    '\nالعمليات: '+entries.toString()+
    '\nالحسابات: '+accounts.toString()+
    '\nالأهداف: '+goals.toString()+
    '\nالمتكررة: '+recurring.toString()+
    '\nالتحويلات: '+transfers.toString()+
    '\nالمرفقات: '+receipts.toString()+
    '\nالفترة: '+range+
    '\nمعرفات العمليات المكررة: '+duplicateIds.toString()+
    '\nلم نعدّل أي بيانات حتى الآن.';
 }
 static List<dynamic> extractV2Entries(Map<String,Object?> finance){
  final raw=finance['entries'];
  if(raw==null)return const <dynamic>[];
  if(raw is! String)throw const FormatException('Malformed finance entry list.');
  final parsed=jsonDecode(raw);
  if(parsed is! List)throw const FormatException('Malformed finance entry payload.');
  return parsed;
 }
}
