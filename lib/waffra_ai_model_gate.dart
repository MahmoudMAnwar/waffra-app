import 'dart:async';

import 'package:flutter/material.dart';
import 'waffra_ondevice_qwen.dart';

/// Shared first-use consent and progress dialog for all Waffra AI entry points.
/// Optional Tools AI retains a non-AI fallback; bank SMS and OCR are gated.
abstract final class WaffraAiModelGate {
  /// A feature that explicitly requires local AI must never silently fall
  /// back to bank-SMS parsing or image OCR when the model is unavailable.
  /// The mandatory notice is shown even after a user declines installation.
  static Future<bool> requireForFeature(BuildContext context,{
    required bool english,
    required String featureAr,
    required String featureEn,
  }) async {
    if(WaffraOnDeviceQwen.shared.isReady)return true;
    final ready=await ensureReady(context,english:english,
      requiredFeature:english?featureEn:featureAr);
    // The consent screen already explains the requirement. Closing it must
    // NOT open a second warning dialog.
    return context.mounted&&ready&&WaffraOnDeviceQwen.shared.isReady;
  }

  static Future<bool> ensureReady(BuildContext context,{
    required bool english,
    String? requiredFeature,
  }) async {
    final model=WaffraOnDeviceQwen.shared;
    if(model.isReady)return true;
    if(model.isBusy)return false;
    final installed=await model.installedAndVerified();
    if(!context.mounted)return false;
    // An installed GGUF is verified and reused without another download prompt.
    final agreed=installed?true:await showDialog<bool>(
      context:context,builder:(dialog)=>AlertDialog(
        key:const Key('waffra-ai-first-use-dialog'),
        title:Text(english?'Download AI model':'تنزيل نموذج الذكاء'),
        content:Text(english?
          (requiredFeature!=null?
           'To use '+requiredFeature+', download the model once (~484 MB). ':
           'Download the private model once (~484 MB). ')+
          'Runs on your device. You can delete it in My Account.':
          (requiredFeature!=null?
           'لتشغيل '+requiredFeature+'، نزّل النموذج مرة واحدة (~484 MB). ':
           'نزّل نموذج الذكاء مرة واحدة (~484 MB). ')+
          'يعمل على جهازك ويمكن حذفه من حسابي.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:Text(english?'Later':'لاحقًا')),
          FilledButton(
            key:const Key('waffra-ai-first-use-consent'),
            onPressed:()=>Navigator.pop(dialog,true),
            child:Text(english?'Download now':'تنزيل الآن')),
        ],
      ));
    if(agreed!=true||!context.mounted)return false;

    final state=ValueNotifier<_ModelLoadingState>(
      const _ModelLoadingState(phase:'starting'));
    var started=false,cancelled=false;
    Future<void>? operation;
    final result=await showDialog<bool>(
      context:context,barrierDismissible:false,
      builder:(dialog){
        Future<void> load()async{
          try{
            state.value=_ModelLoadingState(phase:installed?'loading':'downloading');
            await model.open(allowDownload:!installed,
              progress:(received,total){
                if(cancelled)return;
                final old=state.value;
                final percentage=total==null||total<=0?
                   -1:(received*100~/total).clamp(0,100);
                final previous=old.total==null||old.total! <= 0?
                   -1:(old.received*100~/old.total!).clamp(0,100);
                // Update on each percent or meaningful byte movement.
                if(percentage==previous&&received-old.received<512*1024)return;
                state.value=_ModelLoadingState(
                  phase:'downloading',received:received,total:total);
              });
            if(!cancelled&&dialog.mounted)Navigator.of(dialog).pop(true);
          }catch(_){
            if(!cancelled&&dialog.mounted){
              state.value=const _ModelLoadingState(phase:'failed');
            }
          }
        }
        if(!started){
          started=true;
          WidgetsBinding.instance.addPostFrameCallback((_){
            if(dialog.mounted&&!cancelled)operation=load();
          });
        }
        return ValueListenableBuilder<_ModelLoadingState>(
          valueListenable:state,builder:(context,loading,_){
            final total=loading.total;
            final received=loading.received;
            final progress=total!=null&&total>0?
              (received/total).clamp(0.0,1.0):null;
            final failed=loading.phase=='failed';
            final loadingNative=loading.phase=='loading';
            return AlertDialog(
              title:Text(failed?
                (english?'Could not load model':'تعذر تحميل النموذج'):
                loadingNative?
                (english?'Loading model':'تشغيل النموذج'):
                (english?'Downloading model':'تنزيل النموذج')),
              content:Column(
                mainAxisSize:MainAxisSize.min,
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  if(!failed&&loadingNative)
                    Text(english?'Preparing the AI model…':'جاري تجهيز النموذج…'),
                  if(failed)
                    Text(english?
                      'Could not prepare the model. Try again.':
                      'تعذر تجهيز النموذج. حاول مرة أخرى.'),
                  const SizedBox(height:12),
                  if(!failed)...[
                    LinearProgressIndicator(
                      key:const Key('waffra-ai-model-download-progress'),
                      value:loadingNative?null:progress),
                    const SizedBox(height:8),
                    if(!loadingNative)
                      Directionality(textDirection:TextDirection.ltr,
                        child:Text(progress!=null?
                          (progress*100).toStringAsFixed(0)+'% • '+
                          (received/1048576).toStringAsFixed(1)+' / '+
                          (total!/1048576).toStringAsFixed(1)+' MB':
                          (english?'Downloading…':'جارٍ التنزيل…'),
                          textAlign:TextAlign.center)),

                  ],

                ]),
              actions:[
                TextButton(
                  key:const Key('waffra-ai-download-cancel'),
                  onPressed:(){
                    cancelled=true;
                    model.cancelPendingLoad();
                    Navigator.of(dialog).pop(false);
                  },
                  child:Text(failed?
                    (english?'Close':'إغلاق'):
                    (english?'Cancel':'إلغاء'))),
              ],
            );
          });
      });
    // Ensure no cancelled callback can write to a disposed notifier.
    if(operation!=null){try{await operation;}catch(_){}}
    state.dispose();
    return result==true&&model.isReady;
  }
}

class _ModelLoadingState {
  const _ModelLoadingState({
    required this.phase,this.received=0,this.total,
  });
  final String phase;
  final int received;
  final int? total;
}
