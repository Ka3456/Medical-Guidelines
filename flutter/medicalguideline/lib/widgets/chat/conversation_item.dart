import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import 'conversation_item_decoration.dart';
import 'conversation_item_title.dart';
import 'conversation_item_menu.dart';
import 'conversation_item_date.dart';

class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final Function(String) onTap;
  final Function(String)? onDelete;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap(conversation.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(18),
            decoration: ConversationItemDecoration(isSelected: isSelected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ConversationItemTitle(
                        conversation: conversation,
                        isSelected: isSelected,
                      ),
                    ),
                    ConversationItemMenu(
                      conversation: conversation,
                      onDelete: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ConversationItemDate(conversation: conversation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
