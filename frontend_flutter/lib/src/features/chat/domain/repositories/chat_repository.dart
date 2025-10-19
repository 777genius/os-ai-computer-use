import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/cost_usage.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';

abstract class ChatRepository {
  Stream<ChatMessage> messages();
  Stream<CostUsage> usage();
  Stream<bool> running();
  Stream<ConnectionStatus> connectionStatus();

  Future<String> createSession({String? provider});
  Future<String> runTask({required String task});
  Future<void> cancelJob(String jobId);
  Future<void> cancelCurrentJob();
  void setActiveChat(String chatId);
  Future<String> uploadFile(
    String name,
    List<int> bytes, {
    String? mime,
    void Function(int sent, int total)? onProgress,
    void Function(void Function())? onCreateCancel,
    String? previewBase64,
    String? batchId,
    int? batchSize,
    int? batchIndex,
  });
  Future<List<int>> downloadFile(String id);
}


