import 'package:cloud_firestore/cloud_firestore.dart';

class CostInfo {
  final int inputTokens;
  final int outputTokens;
  final double inputCostUsd;
  final double outputCostUsd;
  final double totalCostUsd;
  final double totalCostJpy;

  CostInfo({
    required this.inputTokens,
    required this.outputTokens,
    required this.inputCostUsd,
    required this.outputCostUsd,
    required this.totalCostUsd,
    required this.totalCostJpy,
  });

  factory CostInfo.fromJson(Map<String, dynamic> json) {
    return CostInfo(
      inputTokens: json['input_tokens'] ?? 0,
      outputTokens: json['output_tokens'] ?? 0,
      inputCostUsd: (json['input_cost_usd'] ?? 0.0).toDouble(),
      outputCostUsd: (json['output_cost_usd'] ?? 0.0).toDouble(),
      totalCostUsd: (json['total_cost_usd'] ?? 0.0).toDouble(),
      totalCostJpy: (json['total_cost_jpy'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'input_cost_usd': inputCostUsd,
      'output_cost_usd': outputCostUsd,
      'total_cost_usd': totalCostUsd,
      'total_cost_jpy': totalCostJpy,
    };
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isTyping;
  final CostInfo? costInfo;
  final int? rating;
  final String? comment;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.costInfo,
    this.rating,
    this.comment,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(
    String content,
    String s, {
    CostInfo? costInfo,
    int? rating,
    String? comment,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      costInfo: costInfo,
      rating: rating,
      comment: comment,
    );
  }

  factory ChatMessage.typing() {
    return ChatMessage(
      id: 'typing',
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isTyping: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'isTyping': isTyping,
      'costInfo': costInfo?.toJson(),
      'rating': rating,
      'comment': comment,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      isUser: (json['isUser'] as bool?) ?? false,
      timestamp: (json['timestamp'] is Timestamp)
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
                DateTime(1970),
      isTyping: json['isTyping'] ?? false,
      costInfo: json['costInfo'] != null
          ? CostInfo.fromJson(json['costInfo'] as Map<String, dynamic>)
          : null,
      rating: json['rating'],
      comment: json['comment'],
    );
  }
}
