import 'dart:async';

import 'package:flutter/material.dart';
import 'waffra_ondevice_qwen.dart';

/// Shared first-use consent and progress dialog for all Waffra AI entry points.
/// Cancel keeps the existing deterministic bank/OCR workflow available.
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
    if(!context.mounted)return false;
    if(ready&&WaffraOnDeviceQwen.shared.isReady)return true;
    await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
      key:const Key('waffra-ai-required-feature-notice'),
      title:Text(english?'AI model required':'يلزم تنزيل نموذج الذكاء الاصطناعي'),
      content:Text(english?
        'You must download and activate the Waffra AI model to use '
        +featureEn+'. Without the model this feature cannot be used. '
        'You can still add transactions manually.':
        'لازم تنزّل وتفعّل نموذج الذكاء الاصطناعي لاستخدام '
        +featureAr+'. من غير النموذج مش هتقدر تستخدم الميزة دي. '
        'تقدر تواصل إضافة المعاملات يدويًا.'),
      actions:[FilledButton(
        onPressed:()=>Navigator.pop(dialog),
        child:Text(english?'OK':'فهمت'))],
    ));
    return false;
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
    final featureRequired=requiredFeature!=null;
    final agreed=await showDialog<bool>(context:context,builder:(dialog)=>
      AlertDialog(
        title:Text(english?'Waffra private AI model':
          'نموذج الذكاء الاصطناعي في وفرة'),
        content:Text(featureRequired?
          (english?
            'The Waffra AI model is required for '+requiredFeature+
            '. Download and activate it before using this feature. '
            'Declining keeps this feature locked, but manual transactions '
            'remain available. You can delete the model later from My Account.':
            'نموذج الذكاء الاصطناعي مطلوب لتشغيل '+requiredFeature+
            '. لازم تنزّله وتفعّله قبل استخدام الميزة. '
            'لو اخترت مش دلوقتي هتفضل الميزة مقفولة، '
            'لكن إضافة المعاملات يدويًا هتفضل متاحة. '
            'تقدر تحذف النموذج لاحقًا من حسابي.') :
          installed?
          (english?
            'The AI model is already downloaded and will load on this '
            'device. You can delete it later from My Account. Deleting '
            'it disables AI analysis until you download it again.':
            'نموذج الذكاء الاصطناعي موجود على جهازك وسيتم تحميله الآن. '
            'تقدر تحذفه في أي وقت من حسابي، لكن وقتها هتتوقف '
            'ميزات التحليل بالذكاء الاصطناعي لحد ما تنزّله تاني.'):
          (english?
            'To use private AI analysis, Waffra needs to download a model '
            '(about 484 MB) to your phone once. Analysis stays on '
            'your device. You may delete the model anytime in My Account; '
            'AI analysis will then stop until you download it again. '
            'The regular Waffra features will keep working.':
            'علشان تستخدم تحليل الذكاء الاصطناعي، وفرة هينزّل نموذج '
            'بحجم تقريبي 484 ميجابايت مرة واحدة على جهازك. '
            'التحليل هيتم محليًا بدون رفع الرسائل أو الصور. '
            'تقدر تحذف النموذج في أي وقت من حسابي، '
            'لكن وقتها هتفقد التحليل بالذكاء الاصطناعي '
            'لحد ما تنزّله تاني. خصائص وفرة العادية هتفضل شغالة.')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:Text(english?'Not now':'مش دلوقتي')),
          FilledButton(
            key:const Key('waffra-ai-first-use-consent'),
            onPressed:()=>Navigator.pop(dialog,true),
            child:Text(installed?
              (english?'Load model':'تحميل النموذج'):
              (english?'Download model':'تنزيل النموذج'))),
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
              title:Text(english?
                'Preparing Waffra AI':'تجهيز ذكاء وفرة الاصطناعي'),
              content:Column(
                mainAxisSize:MainAxisSize.min,
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  Text(failed?
                    (english?'Model download or loading failed. '
                      'Your financial data has not changed.':
                      'تعذر تنزيل النموذج أو تحميله. '
                      'بياناتك المالية لم تتغير.'):
                    loadingNative?
                    (english?'Loading the AI model on this device…':
                      'جاري تحميل نموذج الذكاء الاصطناعي على الجهاز…'):
                    (english?'Downloading the AI model to your device…':
                      'جاري تنزيل نموذج الذكاء الاصطناعي على جهازك…')),
                  const SizedBox(height:16),
                  if(!failed)...[
                    LinearProgressIndicator(
                      key:const Key('waffra-ai-model-download-progress'),
                      value:loadingNative?null:progress),
                    const SizedBox(height:8),
                    Text(loadingNative?
                      (english?'Preparing model…':'جاري تجهيز النموذج…'):
                      progress!=null?
                        (progress*100).toStringAsFixed(0)+'% • '+
                        (received/1048576).toStringAsFixed(1)+' / '+
                        (total!/1048576).toStringAsFixed(1)+' MB':
                        (english?'Downloading…':'جارٍ التنزيل…')),
                  ],
                  const SizedBox(height:10),
                  Text(english?
                    'You can delete the model later from My Account. '
                    'Deleting it disables AI analysis only; your '
                    'regular tools and saved transactions stay available.':
                    'تقدر تحذف النموذج لاحقًا من حسابي؛ '
                    'ساعتها هتفقد تحليل الذكاء الاصطناعي فقط، '
                    'لكن الأدوات العادية ومعاملاتك المحفوظة هتفضل موجودة.'),
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
