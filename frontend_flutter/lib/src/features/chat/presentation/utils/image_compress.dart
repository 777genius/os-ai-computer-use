import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:convert';

class ImageCompressOptions {
  final int maxWidth;
  final int jpegQuality; // 1..100
  final bool preferWebp;
  const ImageCompressOptions({this.maxWidth = 2048, this.jpegQuality = 85, this.preferWebp = false});
}

Future<String> makePreviewBase64(Uint8List input, {int maxWidth = 320, int quality = 70}) async {
  try {
    final decoded = img.decodeImage(input);
    if (decoded == null) return base64Encode(input);
    img.Image working = decoded;
    if (working.width > maxWidth) {
      final newHeight = (working.height * (maxWidth / working.width)).round();
      working = img.copyResize(working, width: maxWidth, height: newHeight, interpolation: img.Interpolation.cubic);
    }
    final out = img.encodeJpg(working, quality: quality);
    return base64Encode(out);
  } catch (_) {
    return base64Encode(input);
  }
}

class ImageCompressResult {
  final Uint8List bytes;
  final String mime;
  final String ext;
  const ImageCompressResult(this.bytes, this.mime, this.ext);
}

Future<ImageCompressResult> compressIfNeeded(Uint8List input, {ImageCompressOptions opts = const ImageCompressOptions()}) async {
  try {
    final decoded = img.decodeImage(input);
    if (decoded == null) return ImageCompressResult(input, 'image/jpeg', 'jpg');
    img.Image working = decoded;
    if (working.width > opts.maxWidth) {
      final newHeight = (working.height * (opts.maxWidth / working.width)).round();
      working = img.copyResize(working, width: opts.maxWidth, height: newHeight, interpolation: img.Interpolation.cubic);
    }
    // WebP поддержка в package:image может отсутствовать на некоторых платформах; используем только JPEG для стабильности
    {
      final out = img.encodeJpg(working, quality: opts.jpegQuality);
      return ImageCompressResult(Uint8List.fromList(out), 'image/jpeg', 'jpg');
    }
  } catch (_) {
    return ImageCompressResult(input, 'image/jpeg', 'jpg');
  }
}


