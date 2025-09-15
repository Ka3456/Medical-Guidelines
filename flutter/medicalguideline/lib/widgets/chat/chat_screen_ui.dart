import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'chat_message_list.dart';
import 'chat_input.dart';
import 'chat_app_bar.dart';
import 'system_status_bar.dart';
import 'conversation_sidebar.dart';
import 'suggested_questions.dart';
import '../common/liquid_background.dart';

class ChatScreenUI extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool isLoading;
  final bool systemReady;
  final String systemStatus;
  final List<Conversation> conversations;
  final String? currentConversationId;
  final double progressValue;
  final Function(String) onSendMessage;
  final Function() onStopSending;
  final Function(int) onResend;
  final Function(int?, String?) onRatingSubmitted;
  final Function(String) onQuestionTap;
  final Function(String) onConversationSelected;
  final Function() onNewConversation;
  final Function(String) onConversationDeleted;
  final Future<void> Function() onRefresh;
  final Function() onSystemRefresh;
  final String? initialText;

  const ChatScreenUI({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.isLoading,
    required this.systemReady,
    required this.systemStatus,
    required this.conversations,
    required this.currentConversationId,
    required this.progressValue,
    required this.onSendMessage,
    required this.onStopSending,
    required this.onResend,
    required this.onRatingSubmitted,
    required this.onQuestionTap,
    required this.onConversationSelected,
    required this.onNewConversation,
    required this.onConversationDeleted,
    required this.onRefresh,
    required this.onSystemRefresh,
    this.initialText,
  });

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final appBarHeight = safeAreaTop + 56.0;

    return Scaffold(
      appBar: const ChatAppBar(),
      extendBodyBehindAppBar: true,
      drawer: ConversationSidebar(
        conversations: conversations,
        currentConversationId: currentConversationId,
        onConversationSelected: onConversationSelected,
        onNewConversation: onNewConversation,
        onConversationDeleted: onConversationDeleted,
        onRefresh: onRefresh,
      ),
      body: LiquidBackground(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: appBarHeight),
            SystemStatusBar(
              systemReady: systemReady,
              systemStatus: systemStatus,
              onRefresh: onSystemRefresh,
            ),
            Expanded(
              child: ChatMessageList(
                messages: messages,
                scrollController: scrollController,
                onResend: onResend,
                onRatingSubmitted: onRatingSubmitted,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SuggestedQuestions(onQuestionTap: onQuestionTap),
            ),
            Container(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: ChatInput(
                onSendMessage: onSendMessage,
                onStopSending: onStopSending,
                isLoading: isLoading,
                progressValue: progressValue,
                initialText: initialText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
