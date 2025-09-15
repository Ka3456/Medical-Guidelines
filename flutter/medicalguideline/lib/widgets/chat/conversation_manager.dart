import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/chat_room.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class ConversationManager {
  final FirestoreService _firestoreService = FirestoreService();

  // 会話履歴を読み込み
  Future<List<Conversation>> loadConversations() async {
    final user = AuthService().currentUser;
    if (user == null) return [];

    try {
      final chatRooms = await _firestoreService.getUserChatRoomsOnce(user.uid);
      return chatRooms
          .map(
            (chatRoom) => Conversation(
              id: chatRoom.id,
              title: chatRoom.summary,
              messages: [],
              createdAt: chatRoom.createdAt,
              updatedAt: chatRoom.createdAt,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('会話履歴の読み込みに失敗: $e');
      return [];
    }
  }

  // 会話のメッセージを読み込み
  Future<List<ChatMessage>> loadConversationMessages(
    String conversationId,
  ) async {
    final user = AuthService().currentUser;
    if (user == null) return [];

    try {
      return await _firestoreService.getChatMessagesOnce(
        user.uid,
        conversationId,
        ascending: true,
      );
    } catch (e) {
      debugPrint('メッセージの読み込みに失敗: $e');
      return [];
    }
  }

  // 新しい会話を作成
  Conversation createNewConversation(List<ChatMessage> messages) {
    final now = DateTime.now();
    final messagesWithoutTyping = messages
        .where((msg) => !msg.isTyping)
        .toList();
    return Conversation(
      id: now.millisecondsSinceEpoch.toString(),
      title: '',
      messages: List.from(messagesWithoutTyping),
      createdAt: now,
      updatedAt: now,
    );
  }

  // Firestoreに新しい会話を作成
  Future<String?> createNewConversationInFirestore() async {
    final user = AuthService().currentUser;
    if (user == null) return null;

    try {
      final now = DateTime.now();
      final chatRoom = ChatRoom(id: '', summary: '新しい会話', createdAt: now);
      return await _firestoreService.createChatRoom(user.uid, chatRoom);
    } catch (e) {
      debugPrint('新しい会話の作成に失敗: $e');
      return null;
    }
  }

  // 現在の会話を更新
  Future<void> updateCurrentConversation(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final user = AuthService().currentUser;
    if (user == null || conversationId.isEmpty) return;

    try {
      final existingRoom = await _firestoreService.getChatRoom(
        user.uid,
        conversationId,
      );
      if (existingRoom == null) {
        final now = DateTime.now();
        final chatRoom = ChatRoom(
          id: conversationId,
          summary: '新しい会話',
          createdAt: now,
        );
        await _firestoreService.createChatRoomWithId(
          user.uid,
          conversationId,
          chatRoom,
        );
      }

      final messagesToSave = messages.where((msg) => !msg.isTyping).toList();
      await _firestoreService.saveChatRoomMessages(
        user.uid,
        conversationId,
        messagesToSave,
      );

      // サマリーを更新
      ChatMessage? firstUserMessage;
      try {
        firstUserMessage = messagesToSave.firstWhere((msg) => msg.isUser);
      } catch (e) {
        if (messagesToSave.isNotEmpty) {
          firstUserMessage = messagesToSave.first;
        }
      }

      if (firstUserMessage != null) {
        await _firestoreService.updateChatRoomSummary(
          user.uid,
          conversationId,
          firstUserMessage.content.length > 50
              ? '${firstUserMessage.content.substring(0, 50)}...'
              : firstUserMessage.content,
        );
      }
    } catch (e) {
      debugPrint('会話の保存に失敗しました: $e');
    }
  }

  // 会話削除
  Future<void> deleteConversation(String conversationId) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final existingRoom = await _firestoreService.getChatRoom(
        user.uid,
        conversationId,
      );
      if (existingRoom != null) {
        await _firestoreService.softDeleteChatRoom(user.uid, conversationId);
      }
    } catch (e) {
      debugPrint('会話削除に失敗: $e');
    }
  }
}
