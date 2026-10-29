import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:http/http.dart' as http;

import 'waffra_receipt_ocr_parser.dart';

/// Uses Tesseract entirely on-device after the two language models have been
/// downloaded and checked once. Receipt pictures and OCR text are NEVER
/// uploaded to the model download endpoint or persisted by this feature.
abstract final class WaffraReceiptOcr {
  static const _sourceCommit =
      '87416418657359cb625c412a48b6e1d6d41c29bd';

  static const _models = <_OcrModel>[
    _OcrModel(
      'ara', 1432056, 'c8d129c67821c1592cac46836686b057ecc203dc'),
    _OcrModel(
      'eng', 4113088, 'bbef4675053b5b468cdb477053e28b1c698ba08e'),
  ];

  static Future<WaffraReceiptOcrFields> scan(String imagePath) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const WaffraReceiptOcrException('unsupported_platform');
    }
    final image = File(imagePath);
    if (!await image.exists()) {
      throw const WaffraReceiptOcrException('image_missing');
    }
    await _installVerifiedModels();
    try {
      final recognized = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'ara+eng',
        args: <String, String>{
          'psm': '3',
          'preserve_interword_spaces': '1',
        },
      );
      return WaffraReceiptOcrParser.parse(recognized);
    } catch (_) {
      throw const WaffraReceiptOcrException('recognition_failed');
    }
  }

  static Future<bool> modelsInstalled() async {
    final path = await FlutterTesseractOcr.getTessdataPath();
    for (final model in _models) {
      if (!await _validModel(File(path + '/' + model.language + '.traineddata'),
          model)) {
        return false;
      }
    }
    return true;
  }

  static Future<void> _installVerifiedModels() async {
    final path = await FlutterTesseractOcr.getTessdataPath();
    await Directory(path).create(recursive: true);
    // Serial downloads bound memory use and do not leak any receipt content.
    for (final model in _models) {
      final destination = File(path + '/' + model.language + '.traineddata');
      if (await _validModel(destination, model)) continue;
      final temporary = File(destination.path + '.part');
      try {
        final uri = Uri.https(
          'raw.githubusercontent.com',
          '/tesseract-ocr/tessdata_fast/' +
              _sourceCommit + '/' + model.language + '.traineddata',
        );
        final response = await http.get(uri).timeout(
          const Duration(seconds: 60),
        );
        if (response.statusCode != 200) {
          throw const WaffraReceiptOcrException('model_download_failed');
        }
        final bytes = response.bodyBytes;
        if (!_matchesModel(bytes, model)) {
          throw const WaffraReceiptOcrException('model_integrity_failed');
        }
        await temporary.writeAsBytes(bytes, flush: true);
        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
      } on WaffraReceiptOcrException {
        rethrow;
      } catch (_) {
        throw const WaffraReceiptOcrException('model_download_failed');
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  static Future<bool> _validModel(File file, _OcrModel model) async {
    if (!await file.exists()) return false;
    if (await file.length() != model.bytes) return false;
    return _matchesModel(await file.readAsBytes(), model);
  }

  static bool _matchesModel(Uint8List bytes, _OcrModel model) {
    if (bytes.length != model.bytes) return false;
    // GitHub's pinned git-blob SHA verifies both bytes and exact file length.
    final prefix = ascii.encode('blob ' + bytes.length.toString() + '\x00');
    return sha1.convert(<int>[...prefix, ...bytes]).toString() == model.gitSha;
  }
}

class WaffraReceiptOcrException implements Exception {
  const WaffraReceiptOcrException(this.code);
  final String code;

  @override
  String toString() => 'WaffraReceiptOcrException(' + code + ')';
}

class _OcrModel {
  const _OcrModel(this.language, this.bytes, this.gitSha);
  final String language;
  final int bytes;
  final String gitSha;
}
