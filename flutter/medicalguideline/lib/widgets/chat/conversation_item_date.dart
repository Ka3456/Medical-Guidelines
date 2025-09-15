import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/conversation.dart';
import '../../utils/colors.dart';

class ConversationItemDate extends StatelessWidget {
  final Conversation conversation;

  const ConversationItemDate({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDate(conversation.updatedAt),
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textBlack,
        letterSpacing: 0.1,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: 0.3),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
