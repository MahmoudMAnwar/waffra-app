import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  WaffraOnDeviceQwen({Future<Directory> Function()? modelRootProvider})
    : _modelRootProvider=modelRootProvider;
  final Future<Directory> Function()? _modelRootProvider;
  static final WaffraOnDeviceQwen shared=WaffraOnDeviceQwen();
  LlamaEngine? _engine;
  bool _opening=false;
  Future<void>? _openingTask;
  bool _deleting=false;
  int _session=0;
  final ValueNotifier<int> revision=ValueNotifier<int>(0);
  static const _everEnabledKey='waffra_ai_model_ever_enabled_v1';
  bool _everEnabled=false;
  bool _historyLoaded=false;
  bool get hasEverEnabled=>_everEnabled;

  /// This records only the installation history, not prompts or finance data.
  /// Deleting the model intentionally does NOT clear it: previously unlocked
  /// AI tools remain visible but disabled after deletion or app restart.
  Future<void> loadToolVisibilityHistory()async{
    if(_historyLoaded)return;
    final prefs=await SharedPreferences.getInstance();
    if(_historyLoaded)return;
    _everEnabled=prefs.getBool(_everEnabledKey)??false;
    _historyLoaded=true;
    revision.value++;
  }

  Future<void> _recordFirstActivation()async{
    try{
      final prefs=await SharedPreferences.getInstance();
      await prefs.setBool(_everEnabledKey,true);
      _everEnabled=true;
      _historyLoaded=true;
      revision.value++;
    }catch(_){
      // A loaded model is immediately usable, even if preference storage
      // fails; do not claim this unlock will survive an app restart.
    }
  }
  http.Client? _activeDownload;

  bool get isReady=>_engine!=null;
  bool get isBusy=>_opening||_deleting;

  Future<bool> downloadedOnDisk()async {
    try {return await (await _modelFile()).exists();}
    catch (_) {return false;}
  }

  /// Closing the account or cancelling a dialog invalidates an in-flight
  /// download and prevents a stale model load from opening in another session.
  void cancelPendingLoad(){
    _session++;
    _activeDownload?.close();
  }

  Future<File> _modelFile()async{
    final folder=await (_modelRootProvider?.call()??getApplicationSupportDirectory());
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
    if(_deleting)throw StateError('model_removal_in_progress');
    if(_engine!=null)return;
    if(_openingTask!=null)throw StateError('model_initialization_in_progress');
    final task=_openVerified(allowDownload:allowDownload,progress:progress);
    _openingTask=task;
    try{await task;}finally{_openingTask=null;}
  }

  Future<void> _openVerified({required bool allowDownload,
      void Function(int downloaded,int? total)? progress})async{
    _opening=true;
    final session=_session;
    try{
      final file=await _modelFile();
      if(!await _verified(file)){
        if(!allowDownload)throw StateError('local_model_not_installed');
        await _downloadVerified(file,progress);
      }
      if(session!=_session)throw StateError('account_session_changed');
      final instance=LlamaEngine(LlamaBackend());
      try{
        await instance.loadModelSource(ModelSource.path(file.path));
        if(session!=_session)throw StateError('account_session_changed');
        _engine=instance;
        revision.value++;
        await _recordFirstActivation();
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
    _activeDownload=client;
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
      if(identical(_activeDownload,client))_activeDownload=null;
      if(await part.exists())await part.delete();
    }
  }

  /// Native llama.cpp runs in a worker isolate, but long Qwen3 thinking
  /// output can make low-powered phones appear stuck. One bounded generation
  /// at a time; cancellation never deletes the verified local GGUF.
  bool _generationActive=false;
  bool _generationCancelled=false;
  static const generationTimeLimit=Duration(seconds:45);

  void cancelCurrentGeneration(){
    if(!_generationActive)return;
    _generationCancelled=true;
    _engine?.cancelGeneration();
  }

  /// Same inference entry point for SMS, OCR, Ask Waffra and finance tools.
  /// No finance write occurs here. The model stays installed after timeout.
  WaffraAiTextInference get textGenerator=>generate;
  Future<String> generate(String prompt)async{
    final engine=_engine;
    if(engine==null)throw StateError('local_model_not_ready');
    if(_generationActive)throw StateError('ai_generation_already_running');
    if(prompt.length>24000)throw const FormatException('prompt_too_long');
    _generationActive=true;
    _generationCancelled=false;
    final output=StringBuffer();
    Future<String> readTokens()async{
      try{
        // Qwen3 defaults to thinking output. A final /no_think instruction
        // requests short task JSON instead of thousands of reasoning tokens.
        await for(final chunk in engine.create([
          LlamaChatMessage.fromText(role:LlamaChatRole.user,
            text:prompt+'\\n/no_think'),
        ],params:const GenerationParams(maxTokens:768))){
          if(_generationCancelled)throw StateError('ai_generation_cancelled');
          final next=chunk.choices.first.delta.content;
          if(next!=null){
            output.write(next);
            if(output.length>24000){
              cancelCurrentGeneration();
              throw const FormatException('model_output_limit');
            }
          }
        }
        if(_generationCancelled)throw StateError('ai_generation_cancelled');
        return output.toString();
      }finally{
        // Keep busy until the native generation stream really stops, even
        // if the user-facing timeout returned early.
        _generationActive=false;
      }
    }
    return readTokens().timeout(generationTimeLimit,onTimeout:(){
      cancelCurrentGeneration();
      throw TimeoutException('ai_generation_timed_out',generationTimeLimit);
    });
  }

  Future<void> dispose()async{
    cancelCurrentGeneration();
    // Logout revokes any in-flight model download/load from the old session.
    _session++;
    _activeDownload?.close();
    _activeDownload=null;
    final pending=_openingTask;
    if(pending!=null){try{await pending;}catch(_){}}
    final engine=_engine;
    _engine=null;
    if(engine!=null)await engine.dispose();
    revision.value++;
  }

  /// Removes ONLY the public GGUF and its temporary partial download.
  /// Financial records, receipts, SQLCipher, and backup directories are
  /// never opened or modified. Caller must enforce biometric confirmation.
  Future<void> deleteDownloadedModel()async{
    if(_deleting)throw StateError('model_removal_in_progress');
    _deleting=true;
    try{
      cancelPendingLoad();
      final pending=_openingTask;
      if(pending!=null){try{await pending;}catch(_){}}
      await dispose();
      final file=await _modelFile();
      final partial=File(file.path+'.part');
      if(await partial.exists())await partial.delete();
      if(await file.exists())await file.delete();
      if(await file.exists()||await partial.exists()){
        throw StateError('model_removal_not_verified');
      }
      revision.value++;
    }finally{
      _deleting=false;
    }
  }
}
