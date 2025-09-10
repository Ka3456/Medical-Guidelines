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
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isTyping;
  final CostInfo? costInfo;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.costInfo,
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
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      costInfo: costInfo,
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
}
