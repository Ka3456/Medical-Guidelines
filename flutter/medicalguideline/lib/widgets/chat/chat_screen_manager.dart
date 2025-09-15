import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../services/chat_service.dart';
import 'conversation_manager.dart';
import 'message_sender.dart';

class ChatScreenManager {
  final ChatService _chatService = ChatService();
  final MessageSender _messageSender = MessageSender();
  final ConversationManager _conversationManager = ConversationManager();

  MessageSender get messageSender => _messageSender;

  // システム状態確認
  Future<Map<String, dynamic>> checkSystemStatus() async {
    try {
      final status = await _chatService.getStatus();
      return {
        'ready': status['ready'] ?? false,
        'status': status['ready'] ?? false
            ? 'システム準備完了 (文書: ${status['documents_count'] ?? 0}件, OpenAI: ${status['openai_available'] ?? false ? "有効" : "無効"})'
            : 'システム初期化中...',
      };
    } catch (e) {
      return {'ready': false, 'status': 'サーバー接続エラー: $e'};
    }
  }

  // 会話履歴を読み込み
  Future<List<Conversation>> loadConversations() async {
    return await _conversationManager.loadConversations();
  }

  // 会話のメッセージを読み込み
  Future<List<ChatMessage>> loadConversationMessages(
    String conversationId,
  ) async {
    return await _conversationManager.loadConversationMessages(conversationId);
  }

  // 新しい会話を作成
  Conversation createNewConversation(List<ChatMessage> messages) {
    return _conversationManager.createNewConversation(messages);
  }

  // Firestoreに新しい会話を作成
  Future<String?> createNewConversationInFirestore() async {
    return await _conversationManager.createNewConversationInFirestore();
  }

  // 会話削除
  Future<void> deleteConversation(String conversationId) async {
    return await _conversationManager.deleteConversation(conversationId);
  }

  // メッセージ送信
  Future<void> sendMessage(
    String text,
    List<ChatMessage> messages,
    String? currentConversationId,
    Function(List<ChatMessage>) updateMessages,
    Function(bool) updateLoading,
    Function(String?) updateConversationId,
    Function(List<Conversation>) updateConversations,
    VoidCallback onUpdate,
  ) async {
    return await _messageSender.sendMessage(
      text,
      messages,
      currentConversationId,
      updateMessages,
      updateLoading,
      updateConversationId,
      updateConversations,
      onUpdate,
    );
  }

  // 評価処理
  Future<void> handleRatingSubmitted(
    int? rating,
    String? comment,
    List<ChatMessage> messages,
    String? currentConversationId,
    Function(List<ChatMessage>) updateMessages,
  ) async {
    return await _messageSender.handleRatingSubmitted(
      rating,
      comment,
      messages,
      currentConversationId,
      updateMessages,
    );
  }

  // 送信停止
  void stopSending({
    Function(bool)? updateLoading,
    Function(List<ChatMessage>)? updateMessages,
    List<ChatMessage>? messages,
    ChatMessage? userMessage,
    String? currentConversationId,
  }) {
    _messageSender.stopSending(
      updateLoading: updateLoading,
      updateMessages: updateMessages,
      messages: messages,
      userMessage: userMessage,
      currentConversationId: currentConversationId,
    );
  }

  void dispose() {
    _messageSender.dispose();
  }
}
