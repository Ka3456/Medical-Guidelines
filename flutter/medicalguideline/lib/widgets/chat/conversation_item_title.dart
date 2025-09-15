import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/conversation.dart';
import '../../utils/colors.dart';

class ConversationItemTitle extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;

  const ConversationItemTitle({
    super.key,
    required this.conversation,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      conversation.title.isNotEmpty
          ? conversation.title
          : conversation.autoTitle,
      style: TextStyle(
        fontSize: 16,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.textBlack : AppColors.textBlack,
        letterSpacing: 0.2,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: isSelected ? 0.7 : 0.2),
            offset: const Offset(0, 1),
            blurRadius: isSelected ? 4 : 2,
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
