import 'package:flutter/material.dart';

/// M435: known merchant catalogue. Lookup never sends bank SMS or amounts to
/// a branding service, and unknown names must not receive guessed logos.
class WaffraMerchantBrand {
 final String name,domain;
 final List<String> aliases;
 const WaffraMerchantBrand(this.name,this.domain,this.aliases);
}

abstract final class WaffraMerchantBrands {
 // Brandfetch free Logo API client ID is public. Leave empty until Android
 // client origin/Referer usage and provider terms are confirmed on hardware.
 static const clientId=String.fromEnvironment(
  'WAFFRA_BRANDFETCH_CLIENT_ID',defaultValue:'1id765UE_np6HSZtwVK');
 static const androidLogoProviderApproved=bool.fromEnvironment(
  'WAFFRA_BRANDFETCH_ANDROID_APPROVED',defaultValue:false);
 static const known=<WaffraMerchantBrand>[
  WaffraMerchantBrand('Spotify','spotify.com',['سبوتيفاي','spotify']),
  WaffraMerchantBrand('Rumble','rumble.com',['رامبل','rumble']),
  WaffraMerchantBrand('STARZPLAY','starzplay.com',['ستارزبلاي','starzplay']),
  WaffraMerchantBrand('Tazkarti','tazkarti.com',['تذكرتي','tazkarti']),
  WaffraMerchantBrand('WATCH IT','watchit.com',['واتش ات','watch it','watchit']),
  WaffraMerchantBrand('Tinder','tinder.com',['تيندر','tinder']),
  WaffraMerchantBrand('Truecaller','truecaller.com',['ترو كولر','truecaller']),
  WaffraMerchantBrand('Steam','steampowered.com',['ستيم','steam']),
  WaffraMerchantBrand('Netflix','netflix.com',['نتفلكس','netflix']),
  WaffraMerchantBrand('YouTube','youtube.com',['يوتيوب','youtube']),
  WaffraMerchantBrand('Google','google.com',['جوجل','google']),
  WaffraMerchantBrand('Apple','apple.com',['ابل','آبل','apple']),
  WaffraMerchantBrand('Amazon','amazon.com',['امازون','أمازون','amazon']),
  WaffraMerchantBrand('noon','noon.com',['نون','noon']),
  WaffraMerchantBrand('Jarir','jarir.com',['جرير','jarir']),
  WaffraMerchantBrand('IKEA','ikea.com',['ايكيا','إيكيا','ikea']),
  WaffraMerchantBrand('Careem','careem.com',['كريم','careem']),
  WaffraMerchantBrand('Uber','uber.com',['اوبر','أوبر','uber']),
  WaffraMerchantBrand('Starbucks','starbucks.com',['ستاربكس','starbucks']),
  WaffraMerchantBrand("McDonald's",'mcdonalds.com',
   ['ماكدونالدز','mcdonalds',"mcdonald's"]),
  WaffraMerchantBrand('Albaik','albaik.com',['البيك','albaik']),
  WaffraMerchantBrand('STC','stc.com.sa',['الاتصالات السعودية','stc']),
  WaffraMerchantBrand('Al Rajhi Bank','alrajhibank.com.sa',
   ['الراجحي','مصرف الراجحي','alrajhi','al rajhi bank']),
  WaffraMerchantBrand('Alinma Bank','alinma.com',
   ['الإنماء','الانماء','alinma','alinma bank']),
  WaffraMerchantBrand('HungerStation','hungerstation.com',
   ['هنقرستيشن','هنقر ستيشن','hungerstation']),
  WaffraMerchantBrand('Talabat','talabat.com',['طلبات','talabat']),
 ];
 static String normalize(String text)=>text.toLowerCase()
  .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'),'')
  .replaceAll('أ','ا').replaceAll('إ','ا').replaceAll('آ','ا')
  .replaceAll('ى','ي').replaceAll('ة','ه')
  .replaceAll(RegExp(r'[^a-z0-9ء-ي]+'),' ')
  .trim().replaceAll(RegExp(r'\s+'),' ');

 /// Exact name/alias only: no fuzzy guesses or SMS sender impersonation.
 static WaffraMerchantBrand? match(String? raw){
  final key=normalize(raw??'');
  if(key.isEmpty)return null;
  for(final item in known){
   if(normalize(item.name)==key||normalize(item.domain)==key||
    item.aliases.any((alias)=>normalize(alias)==key))return item;
  }
  return null;
 }
 static List<WaffraMerchantBrand> search(String query){
  final key=normalize(query);
  if(key.isEmpty)return known;
  return known.where((item)=>normalize(item.name).contains(key)||
   item.aliases.any((alias)=>normalize(alias).contains(key))).toList();
 }
 /// Direct CDN URL, never an image scraper. No network request if unconfigured.
 static Uri? logoUri(WaffraMerchantBrand? brand){
  if(!androidLogoProviderApproved||brand==null||
     !RegExp(r'^[A-Za-z0-9_-]{8,128}$')
     .hasMatch(clientId))return null;
  if(!RegExp(r'^[a-z0-9.-]+$').hasMatch(brand.domain))return null;
  return Uri.https('cdn.brandfetch.io','/'+brand.domain,{'c':clientId});
 }
}

/// Safe branded avatar. On offline/error/missing client ID show a monogram.
class WaffraMerchantLogo extends StatelessWidget {
 final WaffraMerchantBrand? brand;
 final String fallbackName;
 final double size;
 const WaffraMerchantLogo({super.key,this.brand,this.fallbackName='',this.size=40});
 @override Widget build(BuildContext context){
  final name=brand?.name??fallbackName.trim();
  final initial=name.isEmpty?'•':String.fromCharCode(name.runes.first).toUpperCase();
  final colors=Theme.of(context).colorScheme;
  final fallback=Container(
   width:size,height:size,
   decoration:BoxDecoration(color:colors.primaryContainer,
    borderRadius:BorderRadius.circular(12)),
   alignment:Alignment.center,
   child:Text(initial,maxLines:1,
    style:TextStyle(fontSize:size*.44,fontWeight:FontWeight.bold,
     color:colors.onPrimaryContainer)));
  final uri=WaffraMerchantBrands.logoUri(brand);
  if(uri==null)return fallback;
  return SizedBox(width:size,height:size,child:ClipRRect(
   borderRadius:BorderRadius.circular(12),
   child:Image.network(uri.toString(),fit:BoxFit.contain,
    headers:const {'Referer':'android-app://com.waffra.app/'},
    errorBuilder:(_,__,___)=>fallback,
    loadingBuilder:(_,child,progress)=>progress==null?child:fallback)));
 }
}

/// Local searchable list. Selecting a brand only changes an editor field;
/// it cannot post a transaction until the user confirms the existing form.
Future<WaffraMerchantBrand?> waffraChooseMerchantBrand(
 BuildContext context,{required bool english})async {
 String query='';
 return showModalBottomSheet<WaffraMerchantBrand>(
  context:context,isScrollControlled:true,showDragHandle:true,
  useSafeArea:true,
  builder:(sheet)=>StatefulBuilder(builder:(ctx,update){
   final matches=WaffraMerchantBrands.search(query);
   return Padding(
    padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),
    child:SizedBox(height:MediaQuery.sizeOf(ctx).height*.7,
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.all(16),
       child:Text(english?'Choose merchant':'اختيار التاجر',
        style:Theme.of(ctx).textTheme.titleLarge)),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),
       child:TextField(
        key:const Key('waffra-merchant-brand-search'),
        onChanged:(value)=>update(()=>query=value),
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
         hintText:english?'Search merchants':'بحث عن تاجر',
         border:const OutlineInputBorder()))),
      const SizedBox(height:8),
      Expanded(child:matches.isEmpty?
       Center(child:Text(english?
        'Not listed: enter the merchant name manually in the form.':
        'التاجر مش موجود في الدليل. تقدر تكتب اسمه يدويًا.')):
       ListView.builder(
        key:const Key('waffra-merchant-brand-directory'),
        itemCount:matches.length,
        itemBuilder:(ctx,i){
         final brand=matches[i];
         return ListTile(
          key:Key('waffra-merchant-brand-'+brand.domain),
          leading:WaffraMerchantLogo(brand:brand,size:43),
          title:Text(brand.name,maxLines:2),
          trailing:const Icon(Icons.chevron_left_rounded),
          onTap:()=>Navigator.pop(ctx,brand));
        })),
     ]),
    ),
   );
  }),
 );
}
