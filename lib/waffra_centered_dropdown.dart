import 'dart:ui' as ui;
import 'package:flutter/material.dart';

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
      final selected=items.where((item)=>item.value==field.value).toList();
      final child=selected.isNotEmpty?selected.first.child:
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
            final choice=await showDialog<_WaffraChoice<T>>(
              context:field.context,
              barrierDismissible:true,
              barrierColor:Colors.black.withValues(alpha:.28),
              builder:(dialogContext)=>BackdropFilter(
                filter:ui.ImageFilter.blur(sigmaX:6,sigmaY:6),
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
                      maxHeight:menuMaxHeight==null?480:
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
                      Flexible(child:ListView.builder(
                        shrinkWrap:true,
                        itemCount:items.length,
                        itemBuilder:(ctx,index) {
                          final item=items[index];
                          return ListTile(
                            enabled:item.enabled,
                            key:Key('waffra-modal-choice-$index'),
                            contentPadding:const EdgeInsets.symmetric(
                              horizontal:18,vertical:3),
                            title:item.child,
                            trailing:item.value==field.value?
                              Icon(Icons.check_circle,color:tone):null,
                            onTap:item.enabled?(){
                              item.onTap?.call();
                              Navigator.pop(dialogContext,
                                _WaffraChoice<T>(item.value));
                            }:null,
                          );
                        },
                      )),
                      const SizedBox(height:9),
                    ]),
                  ),
                )),
              ),
            );
            if(choice==null||!field.mounted)return;
            field.didChange(choice.value);
            onChanged(choice.value);
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
