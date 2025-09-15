import 'package:flutter/material.dart';
import 'package:medicalguideline/models/conversation.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'conversation_manager.dart';
import 'progress_manager.dart';

class MessageSender {
  final ChatService _chatService = ChatService();
  final ConversationManager _conversationManager = ConversationManager();
  final ProgressManager _progressManager = ProgressManager();

  // 送信停止用のフラグ
  bool _isStopped = false;

  ProgressManager get progressManager => _progressManager;

  // メッセージ送信処理
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
    if (text.trim().isEmpty) return;

    // 停止フラグをリセット
    _isStopped = false;

    // ユーザーメッセージを追加
    final userMessage = ChatMessage.user(text);
    final typingMessage = ChatMessage.typing();

    updateMessages([...messages, userMessage, typingMessage]);
    updateLoading(true);
    _progressManager.startProgressTimer(onUpdate);

    // 会話を更新
    if (currentConversationId != null) {
      await _conversationManager.updateCurrentConversation(
        currentConversationId,
        [...messages, userMessage],
      );
    }

    try {
      // AIレスポンスを取得
      final response = await _chatService.sendMessage(text);

      // 停止された場合は処理を中断
      if (_isStopped) {
        _handleStop(
          updateMessages,
          updateLoading,
          messages,
          userMessage,
          currentConversationId,
        );
        return;
      }

      // タイピングインジケーターを削除
      final messagesWithoutTyping = messages
          .where((msg) => !msg.isTyping)
          .toList();
      updateMessages([...messagesWithoutTyping, userMessage, response]);
      updateLoading(false);
      _progressManager.stopProgressTimer();

      // 会話を更新
      if (currentConversationId != null) {
        await _conversationManager.updateCurrentConversation(
          currentConversationId,
          [...messagesWithoutTyping, userMessage, response],
        );
      }
    } catch (e) {
      // 停止された場合は処理を中断
      if (_isStopped) {
        _handleStop(
          updateMessages,
          updateLoading,
          messages,
          userMessage,
          currentConversationId,
        );
        return;
      }

      // エラーハンドリング
      final messagesWithoutTyping = messages
          .where((msg) => !msg.isTyping)
          .toList();
      _progressManager.stopProgressTimer();

      String errorText;
      if (e.toString().contains('ChatServiceException')) {
        errorText =
            '⚠️ 通信に失敗しました\n\nネットワーク接続を確認して、もう一度お試しください。\n\n多くの場合、再送すると通信に成功します。';
      } else {
        errorText = '⚠️ 一時的にサービスを利用できません\n\nしばらく待ってからもう一度お試しください。';
      }

      final errorMessage = ChatMessage.assistant(errorText, '');
      updateMessages([...messagesWithoutTyping, userMessage, errorMessage]);
      updateLoading(false);

      // 会話を更新
      if (currentConversationId != null) {
        await _conversationManager.updateCurrentConversation(
          currentConversationId,
          [...messagesWithoutTyping, userMessage, errorMessage],
        );
      }
    }
  }

  // 送信停止処理
  void _handleStop(
    Function(List<ChatMessage>) updateMessages,
    Function(bool) updateLoading,
    List<ChatMessage> messages,
    ChatMessage userMessage,
    String? currentConversationId,
  ) {
    final messagesWithoutTyping = messages
        .where((msg) => !msg.isTyping)
        .toList();

    final stopMessage = ChatMessage.assistant('送信が停止されました。', '');
    updateMessages([...messagesWithoutTyping, userMessage, stopMessage]);
    updateLoading(false);
    _progressManager.stopProgressTimer();

    // 会話を更新
    if (currentConversationId != null) {
      _conversationManager.updateCurrentConversation(currentConversationId, [
        ...messagesWithoutTyping,
        userMessage,
        stopMessage,
      ]);
    }
  }

  // 送信を停止するメソッド
  void stopSending({
    Function(bool)? updateLoading,
    Function(List<ChatMessage>)? updateMessages,
    List<ChatMessage>? messages,
    ChatMessage? userMessage,
    String? currentConversationId,
  }) {
    _isStopped = true;

    // UIを即座に更新
    if (updateLoading != null) {
      updateLoading(false);
    }

    // メッセージとコールバックが提供されている場合は停止メッセージを追加
    if (updateMessages != null && messages != null && userMessage != null) {
      _handleStop(
        updateMessages,
        (loading) {}, // 既にfalseに設定済み
        messages,
        userMessage,
        currentConversationId,
      );
    }

    _progressManager.stopProgressTimer();
  }

  // 評価処理
  Future<void> handleRatingSubmitted(
    int? rating,
    String? comment,
    List<ChatMessage> messages,
    String? currentConversationId,
    Function(List<ChatMessage>) updateMessages,
  ) async {
    final user = AuthService().currentUser;
    if (user == null || currentConversationId == null) return;

    try {
      // 最新のAIメッセージを見つける
      int lastAiMessageIndex = -1;
      for (int i = messages.length - 1; i >= 0; i--) {
        if (!messages[i].isUser && !messages[i].isTyping) {
          lastAiMessageIndex = i;
          break;
        }
      }

      if (lastAiMessageIndex == -1) return;

      // メッセージを更新
      final originalMessage = messages[lastAiMessageIndex];
      final updatedMessage = ChatMessage(
        id: originalMessage.id,
        content: originalMessage.content,
        isUser: originalMessage.isUser,
        timestamp: originalMessage.timestamp,
        isTyping: originalMessage.isTyping,
        costInfo: originalMessage.costInfo,
        rating: rating,
        comment: comment,
      );

      final updatedMessages = List<ChatMessage>.from(messages);
      updatedMessages[lastAiMessageIndex] = updatedMessage;
      updateMessages(updatedMessages);

      // Firestoreに保存
      final firestoreService = FirestoreService();
      await firestoreService.updateMessageRating(
        user.uid,
        currentConversationId,
        originalMessage.id,
        rating,
        comment,
      );
    } catch (e) {
      debugPrint('評価の保存に失敗: $e');
    }
  }

  void dispose() {
    _progressManager.dispose();
  }
}
