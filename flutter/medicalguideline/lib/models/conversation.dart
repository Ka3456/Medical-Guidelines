import 'chat_message.dart';

class Conversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  // タイトルを自動生成（最初のユーザーメッセージから）
  String get autoTitle {
    if (messages.isEmpty) return '新しい会話';

    final firstUserMessage = messages.firstWhere(
      (msg) => msg.isUser,
      orElse: () => messages.first,
    );

    final text = firstUserMessage.content;
    if (text.length <= 30) return text;
    return '${text.substring(0, 30)}...';
  }

  // 会話の要約（最後のメッセージ）
  String get lastMessage {
    if (messages.isEmpty) return 'メッセージなし';

    final lastMsg = messages.last;
    if (lastMsg.isUser) {
      return 'あなた: ${lastMsg.content}';
    } else {
      return 'AI: ${lastMsg.content}';
    }
  }

  // JSON変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msg) => ChatMessage.fromJson(msg))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // コピーして更新
  Conversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
