import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'waffra_phone_country_codes.dart';

/// One accessible input border, with a compact flag+dial selector. This
/// never requests GPS or changes currency/payment preferences.
class WaffraGooglePhoneField extends StatefulWidget {
 const WaffraGooglePhoneField({
  super.key, required this.controller, required this.country,
  required this.onCountryChanged, required this.onChanged,
  required this.english, this.errorText,
 });
 final TextEditingController controller;
 final WaffraPhoneCountry country;
 final ValueChanged<WaffraPhoneCountry> onCountryChanged;
 final ValueChanged<String> onChanged;
 final bool english;
 final String? errorText;

 @override State<WaffraGooglePhoneField> createState() =>
   _WaffraGooglePhoneFieldState();
}

class _WaffraGooglePhoneFieldState extends State<WaffraGooglePhoneField> {
 Future<void> _pick() async {
  final query=TextEditingController();
  final selected=await showModalBottomSheet<WaffraPhoneCountry>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(context)=>SafeArea(child:Padding(
    padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
    child:SizedBox(height:MediaQuery.sizeOf(context).height*.65,
     child:StatefulBuilder(builder:(context,update)=>Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(
       controller:query,key:const Key('waffra-google-country-search'),
       onChanged:(_)=>update((){}),
       decoration:InputDecoration(
        prefixIcon:const Icon(Icons.search),
        hintText:widget.english?'Country or dialing code':'ابحث باسم الدولة أو كود الاتصال',
        border:const OutlineInputBorder()))),
      Expanded(child:ListView(children:waffraPhoneCountries.where((item){
       final search=query.text.trim().toLowerCase();
       return search.isEmpty||item.ar.contains(search)||
        item.en.toLowerCase().contains(search)||
        item.dial.contains(search)||item.iso.toLowerCase().contains(search);
      }).map((item)=>ListTile(
       key:Key('waffra-phone-country-'+item.iso),
       leading:Text(item.flag,style:const TextStyle(fontSize:24)),
       title:Text(item.label(widget.english)),
       trailing:Text(item.dial,textDirection:TextDirection.ltr),
       selected:item.iso==widget.country.iso,
       onTap:()=>Navigator.pop(context,item),
      )).toList())),
     ]))))));
  query.dispose();
  if(selected!=null&&mounted)widget.onCountryChanged(selected);
 }
 @override Widget build(BuildContext context)=>TextField(
  key:const Key('waffra-profile-mobile-number'),
  controller:widget.controller,textDirection:TextDirection.ltr,
  keyboardType:TextInputType.phone,
  inputFormatters:[
   FilteringTextInputFormatter.digitsOnly,
   LengthLimitingTextInputFormatter(14),
  ],
  onChanged:widget.onChanged,
  decoration:InputDecoration(
   prefixIconConstraints:const BoxConstraints(minWidth:0,minHeight:44),
   prefixIcon:InkWell(
    key:const Key('waffra-google-phone-country-picker'),
    onTap:_pick,
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:8),
     child:Row(mainAxisSize:MainAxisSize.min,children:[
      Text(widget.country.flag,style:const TextStyle(fontSize:21)),
      const SizedBox(width:4),
      Text(widget.country.dial,textDirection:TextDirection.ltr,
       style:const TextStyle(fontWeight:FontWeight.w700)),
      const Icon(Icons.arrow_drop_down,size:20),
     ]))),
   labelText:widget.english?'Mobile number *':'رقم الجوال *',
   hintText:widget.country.iso=='SA'?'5XXXXXXXX':
    widget.country.iso=='EG'?'1XXXXXXXXX':'Mobile number',
   errorText:widget.errorText,
   errorMaxLines:2,
   border:const OutlineInputBorder(),
  ));
}
