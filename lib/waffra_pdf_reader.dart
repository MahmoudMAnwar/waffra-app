import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Display reports as vertically scrollable pages, with one-tap full-screen
/// reading and horizontal page navigation. Raster images are generated locally;
/// no report content is uploaded to a server.
class WaffraPdfPage {
 final Uint8List png;
 final double aspectRatio;
 const WaffraPdfPage(this.png,this.aspectRatio);
}

class WaffraPdfReader extends StatefulWidget {
 final Uint8List bytes;
 final String fileName;
 final bool english;
 final Future<List<WaffraPdfPage>>? previewPages;
 const WaffraPdfReader({super.key,required this.bytes,required this.fileName,
  required this.english,this.previewPages});
 @override State<WaffraPdfReader> createState()=>_WaffraPdfReaderState();
}

class _WaffraPdfReaderState extends State<WaffraPdfReader> {
 late final Future<List<WaffraPdfPage>> _rasterized;
 int _current=0;
 @override void initState(){
  super.initState();
  _rasterized=widget.previewPages??_renderPages();
 }
 Future<List<WaffraPdfPage>> _renderPages()async{
  final result=<WaffraPdfPage>[];
  await for(final page in Printing.raster(widget.bytes,dpi:125)){
   final png=await page.toPng();
   result.add(WaffraPdfPage(png,page.width/page.height));
  }
  return result;
 }
 void _openFullScreen(List<WaffraPdfPage> pages,int selected){
  Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>_WaffraPdfFullScreen(
    pages:pages,initialIndex:selected,english:widget.english)));
 }
 @override Widget build(BuildContext context){
  const darkGreen=Color(0xFF073F31);
  return Scaffold(
   appBar:AppBar(backgroundColor:darkGreen,foregroundColor:Colors.white,
    title:Text(widget.english?'Report preview':'معاينة التقرير'),
    actions:[
     IconButton(
      tooltip:widget.english?'Share PDF':'مشاركة PDF',
      onPressed:()=>Printing.sharePdf(bytes:widget.bytes,filename:widget.fileName),
      icon:const Icon(Icons.share_outlined)),
    ]),
   body:FutureBuilder<List<WaffraPdfPage>>(
    future:_rasterized,
    builder:(context,snapshot){
     if(snapshot.hasError)return Center(child:Text(widget.english
      ?'Could not display this report.':'تعذر عرض التقرير.'));
     if(!snapshot.hasData)return Center(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
       const CircularProgressIndicator(),
       const SizedBox(height:14),
       Text(widget.english?'Preparing report pages…':'جاري تجهيز صفحات التقرير…'),
      ]));
     final pages=snapshot.data!;
     if(pages.isEmpty)return Center(child:Text(widget.english
      ?'There are no report pages.':'لا توجد صفحات في التقرير.'));
     return Column(children:[
      Expanded(child:ListView.separated(
       padding:const EdgeInsets.fromLTRB(14,18,14,18),
       itemCount:pages.length,
       separatorBuilder:(_,__)=>const SizedBox(height:15),
       itemBuilder:(ctx,index)=>Column(children:[
        Semantics(button:true,label:widget.english
         ?'Open page ${index+1} full-screen'
         :'عرض الصفحة ${index+1} بملء الشاشة',
         child:InkWell(
          key:Key('waffra-pdf-page-$index'),
          onTap:()=>_openFullScreen(pages,index),
          borderRadius:BorderRadius.circular(12),
          child:Card(margin:EdgeInsets.zero,elevation:4,
           clipBehavior:Clip.antiAlias,
           child:AspectRatio(aspectRatio:pages[index].aspectRatio,
            child:Image.memory(pages[index].png,fit:BoxFit.contain,gaplessPlayback:true))),
         )),
        const SizedBox(height:6),
        Text(widget.english?'Page ${index+1} of ${pages.length}'
         :'الصفحة ${index+1} من ${pages.length}',
         style:Theme.of(ctx).textTheme.bodySmall),
       ]))),
      SafeArea(top:false,child:Container(
       padding:const EdgeInsets.symmetric(vertical:11,horizontal:16),
       decoration:BoxDecoration(
        color:Theme.of(context).colorScheme.surface,
        border:Border(top:BorderSide(color:Theme.of(context).dividerColor))),
       child:Text(widget.english
        ?'Scroll vertically; tap a page to expand'
        :'اسحب لأعلى وأسفل، واضغط على الصفحة لتكبيرها',
        maxLines:2,softWrap:true,textAlign:TextAlign.center,
        style:Theme.of(context).textTheme.bodySmall),
      )),
     ]);
    }),
  );
 }
}

class _WaffraPdfFullScreen extends StatefulWidget{
 final List<WaffraPdfPage> pages;
 final int initialIndex;
 final bool english;
 const _WaffraPdfFullScreen({
  required this.pages,required this.initialIndex,required this.english});
 @override State<_WaffraPdfFullScreen> createState()=>_WaffraPdfFullScreenState();
}

class _WaffraPdfFullScreenState extends State<_WaffraPdfFullScreen>{
 late final PageController controller;
 late int current;
 @override void initState(){
  super.initState();
  current=widget.initialIndex;
  controller=PageController(initialPage:current);
 }
 @override void dispose(){controller.dispose();super.dispose();}
 void goTo(int page){
  if(page<0||page>=widget.pages.length)return;
  controller.animateToPage(page,
   duration:const Duration(milliseconds:220),curve:Curves.easeInOut);
 }
 @override Widget build(BuildContext context){
  return Scaffold(
   backgroundColor:const Color(0xFF111715),
   appBar:AppBar(
    backgroundColor:const Color(0xFF073F31),foregroundColor:Colors.white,
    leading:IconButton(icon:const Icon(Icons.arrow_back_rounded),
     tooltip:widget.english?'Back to report':'العودة للتقرير',
     onPressed:()=>Navigator.pop(context)),
    title:Text(widget.english?'Back to report':'العودة للتقرير')),
   body:SafeArea(child:Column(children:[
    Expanded(child:PageView.builder(
     controller:controller,
     itemCount:widget.pages.length,
     onPageChanged:(index)=>setState(()=>current=index),
     itemBuilder:(ctx,index)=>InteractiveViewer(
      key:Key('waffra-pdf-full-page-$index'),
      panEnabled:true,minScale:1,maxScale:5,
      child:Center(child:Image.memory(widget.pages[index].png,
       fit:BoxFit.contain,gaplessPlayback:true))))),
    Container(
     padding:const EdgeInsets.symmetric(vertical:9),
     color:const Color(0xFF073F31),
     child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton(
       tooltip:widget.english?'Previous page':'الصفحة السابقة',
       onPressed:current>0?()=>goTo(current-1):null,
       icon:Icon(Icons.chevron_left_rounded,color:current>0?Colors.white:Colors.white38)),
      const SizedBox(width:24),
      Text('${current+1} / ${widget.pages.length}',
       textDirection:TextDirection.ltr,
       style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:17)),
      const SizedBox(width:24),
      IconButton(
       tooltip:widget.english?'Next page':'الصفحة التالية',
       onPressed:current<widget.pages.length-1?()=>goTo(current+1):null,
       icon:Icon(Icons.chevron_right_rounded,
        color:current<widget.pages.length-1?Colors.white:Colors.white38)),
     ])),
   ])),
  );
 }
}
