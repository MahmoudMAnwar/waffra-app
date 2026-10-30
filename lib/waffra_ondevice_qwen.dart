import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import 'waffra_ai_finance_brain.dart';

/// Opt-in Qwen3-0.6B Q4_K_M, source: smarttasks on Hugging Face, Apache-2.0.
/// The model is NOT shipped inside the APK and is NEVER downloaded at login.
/// Only the verified public GGUF is downloaded. Bank/receipt text is not sent.
abstract final class WaffraAiModelManifest {
  static const filename='Qwen3-0.6B-Q4_K_M.gguf';
  static const url=
    'https://huggingface.co/smarttasks/Qwen3-0.6B-GGUF/'
    'resolve/main/Qwen3-0.6B-Q4_K_M.gguf';
  static const sha256Hex=
    '3479875d3e4c726f7a20b2181f5e1536aefe9925f284f9ae9997a39a7e0d8dc9';
  static const maxBytes=600000000;
}

/// Optional on-device inference; NEVER instantiated by application startup.
/// Native runtime and device memory must pass Android/iOS CI and device QA
/// before any production UI makes this an enabled default.
class WaffraOnDeviceQwen {
  WaffraOnDeviceQwen();
  static final WaffraOnDeviceQwen shared=WaffraOnDeviceQwen();
  LlamaEngine? _engine;
  bool _opening=false;

  bool get isReady=>_engine!=null;

  Future<File> _modelFile()async{
    final folder=await getApplicationSupportDirectory();
    final dir=Directory(folder.path+'/waffra_public_ai_models');
    await dir.create(recursive:true);
    return File(dir.path+'/'+WaffraAiModelManifest.filename);
  }

  Future<bool> installedAndVerified()async{
    try{
      final model=await _modelFile();
      return _verified(model);
    }catch(_){return false;}
  }

  Future<bool> _verified(File file)async{
    if(!await file.exists())return false;
    final size=await file.length();
    if(size<100000000||size>WaffraAiModelManifest.maxBytes)return false;
    final digest=await sha256.bind(file.openRead()).first;
    return digest.toString()==WaffraAiModelManifest.sha256Hex;
  }

  /// Explicitly called after the person opts in to downloading ~484MB.
  /// There is NO background SMS or image processing and NO cloud inference.
  Future<void> open({required bool allowDownload,
      void Function(int downloaded,int? total)? progress})async{
    if(_engine!=null)return;
    if(_opening)throw StateError('model_initialization_in_progress');
    _opening=true;
    try{
      final file=await _modelFile();
      if(!await _verified(file)){
        if(!allowDownload)throw StateError('local_model_not_installed');
        await _downloadVerified(file,progress);
      }
      final instance=LlamaEngine(LlamaBackend());
      try{
        await instance.loadModelSource(ModelSource.path(file.path));
        _engine=instance;
      }catch(_){
        await instance.dispose();
        rethrow;
      }
    }finally{
      _opening=false;
    }
  }

  Future<void> _downloadVerified(File destination,
      void Function(int,int?)? progress)async{
    final part=File(destination.path+'.part');
    final client=http.Client();
    try{
      if(await part.exists())await part.delete();
      final request=http.Request('GET',Uri.parse(WaffraAiModelManifest.url));
      final response=await client.send(request).timeout(const Duration(seconds:60));
      if(response.statusCode!=200 ||
          (response.contentLength??0)>WaffraAiModelManifest.maxBytes){
        throw const FormatException('model_download_rejected');
      }
      final sink=part.openWrite();
      var size=0;
      try{
        await for(final chunk in response.stream){
          size+=chunk.length;
          if(size>WaffraAiModelManifest.maxBytes){
            throw const FormatException('model_too_large');
          }
          sink.add(chunk);
          progress?.call(size,response.contentLength);
        }
      }finally{
        await sink.flush();
        await sink.close();
      }
      if(!await _verified(part)){
        throw const FormatException('model_sha256_mismatch');
      }
      if(await destination.exists())await destination.delete();
      await part.rename(destination.path);
    }finally{
      client.close();
      if(await part.exists())await part.delete();
    }
  }

  /// Same inference entry point for bank SMS, image OCR, Ask Waffra,
  /// financial analysis, and savings suggestions. Only generates text.
  WaffraAiTextInference get textGenerator=>generate;
  Future<String> generate(String prompt)async{
    final engine=_engine;
    if(engine==null)throw StateError('local_model_not_ready');
    if(prompt.length>24000)throw const FormatException('prompt_too_long');
    final output=StringBuffer();
    await for(final chunk in engine.create([
      LlamaChatMessage.fromText(role:LlamaChatRole.user,text:prompt),
    ],params:const GenerationParams(maxTokens:1536))){
      final next=chunk.choices.first.delta.content;
      if(next!=null){
        output.write(next);
        if(output.length>24000)throw const FormatException('model_output_limit');
      }
    }
    return output.toString();
  }

  Future<void> dispose()async{
    final engine=_engine;
    _engine=null;
    if(engine!=null)await engine.dispose();
  }
}
