import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ondevice_qwen.dart';

void main() {
  test('M321 deleting AI model removes only GGUF/part, keeps finance and unrelated files',()async{
    final root=await Directory.systemTemp.createTemp('waffra-ai-removal-');
    try{
      final modelDir=Directory(root.path+'/waffra_public_ai_models');
      await modelDir.create(recursive:true);
      final model=File(modelDir.path+'/'+WaffraAiModelManifest.filename);
      final part=File(model.path+'.part');
      final unrelated=File(modelDir.path+'/other-asset.txt');
      final finance=File(root.path+'/finances-sqlcipher.db');
      await model.writeAsString('synthetic MODEL bytes');
      await part.writeAsString('synthetic interrupted download');
      await unrelated.writeAsString('unrelated data');
      await finance.writeAsString('financial data remains unchanged');
      final engine=WaffraOnDeviceQwen(modelRootProvider:()async=>root);
      expect(await engine.downloadedOnDisk(),isTrue);
      await engine.deleteDownloadedModel();
      expect(await model.exists(),isFalse);
      expect(await part.exists(),isFalse);
      expect(await unrelated.exists(),isTrue);
      expect(await finance.readAsString(),'financial data remains unchanged');
      expect(await engine.downloadedOnDisk(),isFalse);
    }finally{
      await root.delete(recursive:true);
    }
  });

  test('M321 first-use UI states deletion warning and actual byte progress',(){
    final dialog=File('lib/waffra_ai_model_gate.dart').readAsStringSync();
    final home=File('lib/main.dart').readAsStringSync();
    final smart=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(dialog,contains('waffra-ai-first-use-consent'));
    expect(dialog,contains('waffra-ai-model-download-progress'));
    expect(dialog,contains('waffra-ai-download-cancel'));
    expect(dialog,contains('received/total'));
    expect(dialog,contains('model.cancelPendingLoad()'));
    expect(dialog,contains('You may delete the model anytime in My Account'));
    expect(dialog,contains('الذكاء الاصطناعي'));
    expect(home,contains('WaffraAiModelGate.ensureReady(context,english:waffraIsEnglish)'));
    expect(smart,contains('WaffraAiModelGate.ensureReady(context,english:widget.english)'));
    // Opening verified analysis never forces an AI download; the user's
    // explicit opt-in button still invokes the same consent/progress gate.
    // Only the AI-first Ask Waffra and savings panels prompt on entry.
    expect(smart,contains('if(next==4||next==7)'));
    expect(smart,isNot(contains('if(next==-2||next==4||next==7)')));
    expect(smart,contains("key:const Key('waffra-local-ai-opt-in')"));
    expect(smart,contains('onPressed:aiBusy?null:()=>unawaited(_enableLocalAi())'));
    expect(home,contains('Future<void> bulkSmsSheet('));
    expect(home,contains('Future<void> scanAndAddReceipt()'));
  });

  test('M321 My Account deletion is blocked on biometric-only OS confirmation',(){
    final home=File('lib/main.dart').readAsStringSync();
    final auth=File('lib/waffra_biometrics.dart').readAsStringSync();
    final start=home.indexOf('Future<void> deleteAiModel()async');
    final end=home.indexOf('Future<void> eraseFinancialData()',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final source=home.substring(start,end);
    final consent=source.indexOf('final approved=await confirmDeletion(');
    final biometric=source.indexOf('WaffraBiometrics.confirmAiModelRemoval(');
    final delete=source.indexOf('await model.deleteDownloadedModel();');
    expect(consent,greaterThan(0));
    expect(biometric,greaterThan(consent));
    expect(delete,greaterThan(biometric));
    expect(source,contains('if(!biometric){'));
    expect(source,contains('return;'));
    expect(source,contains('معاملاتك وفواتيرك ونسخك الاحتياطية'));
    expect(home,contains("'Delete AI model'"));
    expect(home,contains("'حذف نموذج الذكاء الاصطناعي'"));
    expect(auth,contains('confirmAiModelRemoval('));
    expect(auth,contains('biometricOnly: true'));
    expect(auth,isNot(contains('fallbackToPinForAiRemoval')));
  });

  test('M321 delete and logout invalidate any pending model download',(){
    final runner=File('lib/waffra_ondevice_qwen.dart').readAsStringSync();
    expect(runner,contains('Future<void> deleteDownloadedModel()async'));
    expect(runner,contains('cancelPendingLoad();'));
    expect(runner,contains('final pending=_openingTask;'));
    expect(runner,contains('if(await file.exists())await file.delete();'));
    expect(runner,contains("File(file.path+'.part')"));
    expect(runner,contains("throw StateError('model_removal_not_verified')"));
    expect(runner,contains('revision.value++'));
    expect(runner,isNot(contains("Directory(folder.path).delete(recursive:true)")));
  });
}
