import 'package:flutter/services.dart';

/// Formats money as 10,000.00 while editing, preserving the caret position.
/// Stored values remain numeric; commas are for presentation only.
class WaffraAmountFormatter extends TextInputFormatter {
 const WaffraAmountFormatter({this.decimalPlaces=2,this.truncateExcess=true})
   : assert(decimalPlaces>=0&&decimalPlaces<=6);
 final int decimalPlaces;
 /// Keep overprecision visible for tools that must reject it, rather than
 /// silently changing the number while the user types or pastes it.
 final bool truncateExcess;
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
  if(!truncateExcess&&fractional.length>decimalPlaces){
   return TextEditingValue(text:normalized,
    selection:TextSelection.collapsed(offset:caret));
  }
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

/// Strict UI number parsing for tools. Never reinterpret malformed grouping
/// (such as 1,2) as a different financial value by stripping punctuation.
/// This helper does NOT change or authorize any encrypted ledger write.
double? waffraStrictNumericInput(
  String input, {
  int decimalPlaces=2,
  bool allowZero=false,
  double? maxValue,
}) {
 if(decimalPlaces<0||decimalPlaces>6)throw ArgumentError.value(
  decimalPlaces,'decimalPlaces','Expected 0..6');
 const arabic='٠١٢٣٤٥٦٧٨٩',persian='۰۱۲۳۴۵۶۷۸۹';
 final normalized=input.trim()
  .replaceAll('٫','.').replaceAll('٬',',')
  .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'),(match){
   final ch=match.group(0)!;
   final n=arabic.indexOf(ch);
   return (n>=0?n:persian.indexOf(ch)).toString();
  });
 final decimal=decimalPlaces==0?'':r'(?:\.[0-9]{1,'+
  decimalPlaces.toString()+r'})?';
 final pattern=RegExp(
  r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)'+decimal+r'
 final fixed=amount.toDouble().isFinite?amount.toStringAsFixed(2):'0.00';
 final parts=fixed.split('.');
 return parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',')+
  (decimalPlaces==0?'':'.'+parts.last);
}
);
 if(!pattern.hasMatch(normalized))return null;
 final value=double.tryParse(normalized.replaceAll(',',''));
 if(value==null||!value.isFinite||value<0||
    (!allowZero&&value==0)||
    (maxValue!=null&&value>maxValue))return null;
 return value;
}

/// ISO 4217 minor-unit presentation for explicit FX/commodity conversions.
/// Does not alter display-only app currency or underlying ledger amounts.
int waffraCurrencyMinorDigits(String code) {
 if(const {'JPY','KRW'}.contains(code))return 0;
 if(const {'BHD','KWD','OMR','TND','JOD','IQD'}.contains(code))return 3;
 return 2;
}

String formatWaffraMoney(num amount,{int decimalPlaces=2}) {
 if(decimalPlaces<0||decimalPlaces>6)throw ArgumentError.value(
  decimalPlaces,'decimalPlaces','Expected 0..6');
 final fallback=decimalPlaces==0?'0':'0.'+List.filled(decimalPlaces,'0').join();
 final fixed=amount.toDouble().isFinite
   ?amount.toStringAsFixed(decimalPlaces):fallback;
 final parts=fixed.split('.');
 return '${parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',')}.${parts.last}';
}
