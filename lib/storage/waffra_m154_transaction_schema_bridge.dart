import 'dart:convert';

/// Lossless M153 transaction shape adapter for an upcoming SQLCipher cutover.
///
/// The existing encrypted vault is NOT activated by this file. A staged
/// migration must preserve every historical field including legacy bank SMS
/// descriptions (which may exceed the new editor's 250-character limit).
/// Caller-supplied finance records are never mutated.
class WaffraM154TransactionSchemaBridge {
 const WaffraM154TransactionSchemaBridge._();

 static Map<String,dynamic> captureLossless(Map<String,dynamic> input){
  final id=input['id'],title=input['title'],category=input['category'];
  final amount=input['amount'],income=input['income'];
  if(id is! String||id.isEmpty||title is! String||title.trim().isEmpty||
   category is! String||category.trim().isEmpty||
   amount is! num||!amount.toDouble().isFinite||amount<=0||
   income is! bool)throw const FormatException('Invalid finance entry');
  final date=input['date'];
  if(date is! String||DateTime.tryParse(date)==null){
   throw const FormatException('Invalid finance entry date');
  }
  for(final field in ['receiptPath','notes','sourceType','merchantKey']){
   if(input.containsKey(field)&&input[field]!=null&&input[field] is! String){
    throw const FormatException('Invalid optional transaction metadata');
   }
  }
  // Preserve all other forward-compatible keys and avoid lossy mapping.
  final copy=jsonDecode(jsonEncode(input));
  if(copy is! Map)throw const FormatException('Invalid normalized entry');
  return Map<String,dynamic>.from(copy);
 }

 static String canonicalList(List<Map<String,dynamic>> values) =>
  jsonEncode(values.map(captureLossless).toList());
}
