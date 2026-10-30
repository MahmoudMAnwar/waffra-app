import 'package:flutter/services.dart';

/// Formats money as 10,000.00 while editing, preserving the caret position.
/// Stored values remain numeric; commas are for presentation only.
class WaffraAmountFormatter extends TextInputFormatter {
 const WaffraAmountFormatter({this.decimalPlaces=2})
   : assert(decimalPlaces>=0&&decimalPlaces<=6);
 final int decimalPlaces;
 @override
 TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
  final normalized=newValue.text.replaceAll('٫','.').replaceAll('٬',',').replaceAllMapped(RegExp('[٠-٩۰-۹]'),(m){
   const arabic='٠١٢٣٤٥٦٧٨٩',persian='۰۱۲۳۴۵۶۷۸۹';
   final c=m.group(0)!;final a=arabic.indexOf(c);
   return (a>=0?a:persian.indexOf(c)).toString();
  });
  final caret=newValue.selection.extentOffset.clamp(0,normalized.length).toInt();
  // Invalid pastes must not silently change e.g. -100 into +100.
  // Preserve invalid input for field-level validation after confirmation.
  final permitted=RegExp(r'^[0-9,.]*$').hasMatch(normalized);
  final decimalPoints='.'.allMatches(normalized).length;
  final grouping=normalized.contains(',')
      ?RegExp(r'^[0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]*)?$')
          .hasMatch(normalized)
      :true;
  if(!permitted||decimalPoints>1||!grouping) {
    return TextEditingValue(text:normalized,
      selection:TextSelection.collapsed(offset:caret));
  }
  final before=normalized.substring(0,caret).replaceAll(RegExp(r'[^0-9.]'),'').length;
  final filtered=normalized.replaceAll(RegExp(r'[^0-9.]'),'');
  final dot=filtered.indexOf('.');
  var integer=(dot<0?filtered:filtered.substring(0,dot)).replaceFirst(RegExp(r'^0+(?=\d)'),'');
  if(integer.isEmpty&&dot>=0)integer='0';
  final fractional=dot<0?'':filtered.substring(dot+1).replaceAll('.','');
  final grouped=integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',');
  final text=grouped+(dot>=0?'.'+(fractional.length>decimalPlaces?fractional.substring(0,decimalPlaces):fractional):'');
  var offset=0,seen=0;
  if(before>0){
   while(offset<text.length&&seen<before){
    if(RegExp(r'[0-9.]').hasMatch(text[offset]))seen++;
    offset++;
   }
  }
  return TextEditingValue(text:text,selection:TextSelection.collapsed(offset:offset));
 }
}

String formatWaffraMoney(num amount) {
 final fixed=amount.toDouble().isFinite?amount.toStringAsFixed(2):'0.00';
 final parts=fixed.split('.');
 return '${parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',')}.${parts.last}';
}
