import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/conversation.dart';
import 'new_conversation_button.dart';
import 'conversation_item.dart';
import 'liquid_glass_refresh_indicator.dart';

class ConversationSidebar extends StatelessWidget {
  final List<Conversation> conversations;
  final String? currentConversationId;
  final Function(String) onConversationSelected;
  final VoidCallback onNewConversation;
  final Function(String, String)? onConversationRenamed;
  final Function(String)? onConversationDeleted;
  final Future<void> Function()? onRefresh;

  const ConversationSidebar({
    super.key,
    required this.conversations,
    this.currentConversationId,
    required this.onConversationSelected,
    required this.onNewConversation,
    this.onConversationRenamed,
    this.onConversationDeleted,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final appBarHeight = safeAreaTop + 56.0; // SafeArea + AppBarの標準高さ

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.01),
            Colors.white.withValues(alpha: 0.015),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 20,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(-1, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.01),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.005),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: appBarHeight),
                _buildConversationList(),
                Center(child: NewConversationButton(onTap: onNewConversation)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Expanded(
      child: LiquidGlassRefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final isSelected = conversation.id == currentConversationId;

            return ConversationItem(
              conversation: conversation,
              isSelected: isSelected,
              onTap: onConversationSelected,
              onDelete: onConversationDeleted,
            );
          },
        ),
      ),
    );
  }
}
