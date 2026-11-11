/// M638 / #559: regulated Saudi institution categories are display choices,
/// NEVER an account or a source of authorization to post financial records.
/// Existing provider IDs are retained so saved SQLCipher account metadata stays
/// valid across upgrades; aliases do not create duplicate banking entities.
class WaffraSaudiProvider {
 const WaffraSaudiProvider(this.id,this.labelAr,this.labelEn,this.category);
 final String id,labelAr,labelEn,category;
 String get groupId =>
  '${category=='wallet'?'wallet':'bank'}:institution:$id';
}

abstract final class WaffraSaudiFinancialProviders {
 static const local='local';
 static const digital='digital';
 static const wallet='wallet';
 static const other='other';

 static const List<WaffraSaudiProvider> localBanks=[
  WaffraSaudiProvider('snb','البنك الأهلي السعودي','Saudi National Bank',local),
  WaffraSaudiProvider('rajhi','مصرف الراجحي','Al Rajhi Bank',local),
  WaffraSaudiProvider('riyad','بنك الرياض','Riyad Bank',local),
  WaffraSaudiProvider('sabb','البنك السعودي الأول','Saudi Awwal Bank',local),
  WaffraSaudiProvider('anb','البنك العربي الوطني','Arab National Bank',local),
  WaffraSaudiProvider('inma','مصرف الإنماء','Alinma Bank',local),
  WaffraSaudiProvider('bsf','البنك السعودي الفرنسي','Banque Saudi Fransi',local),
  WaffraSaudiProvider('saib','البنك السعودي للاستثمار','Saudi Investment Bank',local),
  WaffraSaudiProvider('jazira','بنك الجزيرة','Bank AlJazira',local),
  WaffraSaudiProvider('bilad','بنك البلاد','Bank Albilad',local),
  WaffraSaudiProvider('gib','بنك الخليج الدولي - السعودية','Gulf International Bank - Saudi Arabia',local),
 ];

 static const List<WaffraSaudiProvider> digitalBanks=[
  WaffraSaudiProvider('stc','بنك إس تي سي','STC Bank',digital),
  WaffraSaudiProvider('vision','بنك فيجن','Vision Bank',digital),
  WaffraSaudiProvider('d360','D360','D360',digital),
 ];

 static const List<WaffraSaudiProvider> digitalWallets=[
  WaffraSaudiProvider('barq','برق','Barq',wallet),
  WaffraSaudiProvider('enjazpay','إنجاز باي','Enjaz Pay',wallet),
  WaffraSaudiProvider('alinmapay','الإنماء باي','Alinma Pay',wallet),
 ];

 static const List<WaffraSaudiProvider> all=[
  ...localBanks,...digitalBanks,...digitalWallets,
 ];

 static List<WaffraSaudiProvider> inCategory(String category) =>
  List<WaffraSaudiProvider>.unmodifiable(
   all.where((provider)=>provider.category==category));

 static WaffraSaudiProvider? byId(String? id){
  if(id==null)return null;
  for(final item in all){if(item.id==id)return item;}
  return null;
 }

 static String labelAr(String category){
  switch(category){
   case local:return 'بنوك محلية';
   case digital:return 'بنوك رقمية';
   case wallet:return 'محافظ رقمية';
   default:return 'نقدي / أخرى';
  }
 }
 static String labelEn(String category){
  switch(category){
   case local:return 'Local banks';
   case digital:return 'Digital banks';
   case wallet:return 'Digital wallets';
   default:return 'Cash / other';
  }
 }

 static String categoryForGroup(String groupId){
  if(groupId.startsWith('wallet:'))return wallet;
  if(groupId=='cash'||groupId.startsWith('other:'))return other;
  if(groupId.startsWith('bank:institution:')){
   final id=groupId.substring('bank:institution:'.length);
   return byId(id)?.category??local;
  }
  return local; // Legacy bank account with no trusted provider metadata.
 }
}
