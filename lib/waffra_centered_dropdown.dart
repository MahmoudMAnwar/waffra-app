import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'waffra_search.dart';
import 'waffra_i18n.dart' show waffraTr;

/// Centered dropdown used in Waffra forms. Unlike Material's anchored popup,
/// this keeps actions legible above IME and Android navigation in RTL and LTR.
/// Only a deliberate item tap updates FormFieldState; dismiss/back never edits.
class WaffraCenteredDropdownFormField<T> extends FormField<T> {
  WaffraCenteredDropdownFormField({
    super.key,
    T? initialValue,
    T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    InputDecoration decoration=const InputDecoration(),
    bool isExpanded=true,
    double? menuMaxHeight,
    FormFieldValidator<T>? validator,
    FormFieldSetter<T>? onSaved,
    bool autovalidateModeAlways=false,
  }) : super(
    initialValue:value??initialValue,
    validator:validator,
    onSaved:onSaved,
    autovalidateMode:autovalidateModeAlways
      ?AutovalidateMode.always:AutovalidateMode.disabled,
    builder:(field) {
      // M529: find the current value without allocating a temporary list.
      final selectedIndex=items.indexWhere((item)=>item.value==field.value);
      final child=selectedIndex>=0?items[selectedIndex].child:
        Text(decoration.hintText??'',maxLines:1,
          overflow:TextOverflow.ellipsis);
      final enabled=onChanged!=null;
      final tone=Theme.of(field.context).brightness==Brightness.dark?
        const Color(0xFF74D8A9):const Color(0xFF0C7957);
      final border=OutlineInputBorder(
        borderRadius:BorderRadius.circular(13),
        borderSide:BorderSide(color:tone,width:1.2));
      final decorated=decoration.copyWith(
        enabledBorder:border,
        focusedBorder:border.copyWith(
          borderSide:BorderSide(color:tone,width:1.6)),
        errorText:field.errorText??decoration.errorText,
      );
      return Semantics(
        button:true,enabled:enabled,
        label:decoration.labelText,
        child:InkWell(
          borderRadius:BorderRadius.circular(13),
          onTap:!enabled?null:()async {
            FocusScope.of(field.context).unfocus();
            var searchQuery='';
            final choice=await showDialog<_WaffraChoice<T>>(
              context:field.context,
              barrierDismissible:true,
              barrierColor:Colors.black.withValues(alpha:.28),
              builder:(dialogContext)=>StatefulBuilder(
               builder:(dialogContext,redraw){
                // Empty search has zero additional list allocations; filled
                // search matches only, never normalizes persisted values.
                final matched=searchQuery.isEmpty?null:<int>[
                 for(var i=0;i<items.length;i++)
                  if(waffraSearchAny([
                   _waffraChoiceSearchText(items[i].child),
                   waffraTr(_waffraChoiceSearchText(items[i].child)),
                   items[i].value?.toString()??'',
                  ],searchQuery))i,
                ];
                return BackdropFilter(
                // Keep a subtle blur; respect system reduced-animations mode
                // without a costly sigma-6 full-screen raster pass.
                filter:ui.ImageFilter.blur(
                  sigmaX:MediaQuery.disableAnimationsOf(dialogContext)?0:3,
                  sigmaY:MediaQuery.disableAnimationsOf(dialogContext)?0:3),
                child:Center(child:Dialog(
                  insetPadding:const EdgeInsets.symmetric(
                    horizontal:18,vertical:24),
                  backgroundColor:Theme.of(dialogContext).cardColor,
                  shape:RoundedRectangleBorder(
                    borderRadius:BorderRadius.circular(19),
                    side:BorderSide(color:tone,width:1.3)),
                  clipBehavior:Clip.antiAlias,
                  child:ConstrainedBox(
                    constraints:BoxConstraints(
                      maxWidth:420,
                      maxHeight:menuMaxHeight==null?480.0:
                        menuMaxHeight.clamp(120.0,560.0).toDouble()),
                    child:Column(mainAxisSize:MainAxisSize.min,children:[
                      Padding(
                        padding:const EdgeInsets.fromLTRB(16,16,16,8),
                        child:Row(children:[
                          Expanded(child:Text(
                            decoration.labelText??'Select',
                            style:Theme.of(dialogContext)
                              .textTheme.titleMedium?.copyWith(
                                fontWeight:FontWeight.bold))),
                          IconButton(
                            tooltip:MaterialLocalizations.of(dialogContext)
                              .closeButtonTooltip,
                            icon:const Icon(Icons.close_rounded),
                            onPressed:()=>Navigator.pop(dialogContext)),
                        ]),
                      ),
                      Padding(
                       padding:const EdgeInsets.fromLTRB(12,0,12,8),
                       child:TextField(
                        key:const Key('waffra-centered-dropdown-search'),
                        onChanged:(text)=>redraw(()=>searchQuery=text),
                        decoration:InputDecoration(
                         isDense:true,
                         prefixIcon:const Icon(Icons.search_rounded),
                         hintText:Directionality.of(dialogContext)==
                           TextDirection.rtl?'ابحث في القائمة':'Search options',
                         border:const OutlineInputBorder()),
                       ),
                      ),
                      Flexible(child:matched!=null&&matched.isEmpty?
                       Center(child:Padding(
                        padding:const EdgeInsets.all(14),
                        child:Text(
                         key:const Key('waffra-centered-dropdown-no-results'),
                         Directionality.of(dialogContext)==TextDirection.rtl?
                          'لا توجد نتائج مطابقة':'No matching results',
                         textAlign:TextAlign.center))):
                       ListView.builder(
                        shrinkWrap:true,
                        itemCount:matched?.length??items.length,
                        itemBuilder:(ctx,index) {
                          final actualIndex=matched==null?index:matched[index];
                          final item=items[actualIndex];
                          final chosen=item.value==field.value;
                          return Padding(
                           padding:const EdgeInsets.symmetric(
                            horizontal:12,vertical:5),
                           child:Material(
                            color:chosen?tone.withValues(alpha:.08):
                             Theme.of(dialogContext).cardColor,
                            shape:RoundedRectangleBorder(
                             borderRadius:BorderRadius.circular(13),
                             side:BorderSide(color:chosen?tone:
                              tone.withValues(alpha:.26),
                              width:chosen?1.5:1)),
                            clipBehavior:Clip.antiAlias,
                            child:ListTile(
                             enabled:item.enabled,
                             key:Key('waffra-modal-choice-$actualIndex'),
                             minVerticalPadding:12,
                             contentPadding:const EdgeInsets.symmetric(
                              horizontal:15,vertical:2),
                             title:item.child,
                             trailing:chosen?
                              Icon(Icons.check_circle,color:tone):null,
                             onTap:item.enabled?(){
                              item.onTap?.call();
                              Navigator.pop(dialogContext,
                                _WaffraChoice<T>(item.value));
                             }:null,
                            ),
                           ),
                          );
                        },
                      )),
                      const SizedBox(height:9),
                    ]),
                  ),
                )),
              );
               }),
            );
            if(choice==null||!field.mounted)return;
            field.didChange(choice.value);
            onChanged?.call(choice.value);
          },
          child:InputDecorator(
            isEmpty:field.value==null,
            isFocused:false,
            decoration:decorated,
            child:Row(mainAxisSize:MainAxisSize.max,children:[
              Expanded(child:DefaultTextStyle.merge(
                maxLines:1,overflow:TextOverflow.ellipsis,child:child)),
              const SizedBox(width:5),
              Icon(Icons.keyboard_arrow_down_rounded,
                color:enabled?tone:Colors.grey),
            ]),
          ),
        ),
      );
    },
  );
}

class _WaffraChoice<T> {
  const _WaffraChoice(this.value);
  final T? value;
}

String _waffraChoiceSearchText(Widget widget){
 if(widget is Text)return widget.data??widget.textSpan?.toPlainText()??'';
 if(widget is RichText)return widget.text.toPlainText();
 if(widget is Row)return widget.children.map(_waffraChoiceSearchText).join(' ');
 if(widget is Column)return widget.children.map(_waffraChoiceSearchText).join(' ');
 if(widget is Padding)return _waffraChoiceSearchText(widget.child);
 if(widget is Align&&widget.child!=null)return _waffraChoiceSearchText(widget.child!);
 if(widget is Expanded)return _waffraChoiceSearchText(widget.child);
 if(widget is Flexible)return _waffraChoiceSearchText(widget.child);
 if(widget is ListTile){
  return [if(widget.title!=null)_waffraChoiceSearchText(widget.title!),
   if(widget.subtitle!=null)_waffraChoiceSearchText(widget.subtitle!)]
   .join(' ');
 }
 return '';
}
