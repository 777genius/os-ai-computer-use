import 'dart:convert';
import 'dart:io';

import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';
import 'package:path_provider/path_provider.dart';

extension ChatMessageMapper on ChatMessage {
  /// Serialize to a Map suitable for Hive storage.
  ///
  /// If [imageBase64] is present it is saved as a file under [screenshotDir]
  /// and only the relative path is stored in the map (`imagePath` key).
  Map<String, dynamic> toMap({String? screenshotDir}) {
    String? imagePath;
    if (imageBase64 != null && imageBase64!.isNotEmpty && screenshotDir != null) {
      try {
        final file = File('$screenshotDir/$id.jpg');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(base64Decode(imageBase64!));
        imagePath = file.path;
      } catch (_) {}
    }

    return {
      'id': id,
      'role': role,
      'chatId': chatId,
      'kind': kind,
      'text': text,
      if (imagePath != null) 'imagePath': imagePath,
      if (meta != null) 'meta': meta,
      'ts': ts.toIso8601String(),
    };
  }

  /// Deserialize from a Hive Map.
  ///
  /// If the map contains `imagePath`, the file is read and its bytes are
  /// placed into [imageBase64].  Missing / unreadable files result in a
  /// null [imageBase64] (the UI shows a placeholder).
  static ChatMessage fromMap(Map map) {
    String? imageBase64;
    final imagePath = map['imagePath'] as String?;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          imageBase64 = base64Encode(file.readAsBytesSync());
        }
      } catch (_) {}
    }

    return ChatMessage(
      id: (map['id'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'assistant',
      chatId: map['chatId'] as String?,
      kind: map['kind'] as String?,
      text: map['text'] as String?,
      imageBase64: imageBase64,
      meta: (map['meta'] as Map?)?.cast<String, dynamic>(),
      ts: DateTime.tryParse((map['ts'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  /// Delete the screenshot file associated with this message (if any).
  static void deleteScreenshot(Map map) {
    final imagePath = map['imagePath'] as String?;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }
}

/// Returns the screenshots directory inside app support.
Future<String> getScreenshotDir() async {
  final dir = await getApplicationSupportDirectory();
  return '${dir.path}/screenshots';
}
