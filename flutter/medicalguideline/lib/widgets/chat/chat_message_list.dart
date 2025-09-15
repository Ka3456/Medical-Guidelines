import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import 'chat_bubble.dart';

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final Function(int) onResend; // メッセージのインデックスを渡すように変更
  final Function(int?, String?) onRatingSubmitted;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.onResend,
    required this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return ChatBubble(
            message: messages[index],
            onResend: () => onResend(index),
            onRatingSubmitted: onRatingSubmitted,
          );
        },
      ),
    );
  }
}
