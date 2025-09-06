import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../utils/colors.dart';
import 'setting/setting_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _systemReady = false;
  String _systemStatus = 'システム状態を確認中...';

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // システム状態確認
  Future<void> _checkSystemStatus() async {
    try {
      final status = await _chatService.getStatus();
      setState(() {
        _systemReady = status['ready'] ?? false;
        if (_systemReady) {
          final docCount = status['documents_count'] ?? 0;
          final openaiAvailable = status['openai_available'] ?? false;
          _systemStatus =
              'システム準備完了 (文書: $docCount件, OpenAI: ${openaiAvailable ? "有効" : "無効"})';
        } else {
          _systemStatus = 'システム初期化中...';
        }
      });
    } catch (e) {
      setState(() {
        _systemReady = false;
        _systemStatus = 'サーバー接続エラー: $e';
      });
    }
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage.assistant(
      'こんにちは！医療ガイドライン AI アシスタントです。\n\n'
      '症状、治療法、薬剤、診療ガイドラインについて何でもお聞きください。\n\n'
      '⚠️ 注意: このアプリは情報提供のみを目的としており、医師の診断や治療の代替ではありません。重要な医療決定については必ず医師にご相談ください。',
    );
    setState(() {
      _messages.add(welcomeMessage);
    });
  }

  void _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // ユーザーメッセージを追加
    final userMessage = ChatMessage.user(text);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    // タイピングインジケーターを追加
    final typingMessage = ChatMessage.typing();
    setState(() {
      _messages.add(typingMessage);
    });

    _scrollToBottom();

    try {
      // AIレスポンスを取得
      final response = await _chatService.sendMessage(text);

      // タイピングインジケーターを削除
      setState(() {
        _messages.removeWhere((msg) => msg.isTyping);
      });

      // AIレスポンスを追加（料金情報付き）
      setState(() {
        _messages.add(response);
        _isLoading = false;
      });
    } catch (e) {
      // エラーハンドリング
      setState(() {
        _messages.removeWhere((msg) => msg.isTyping);
      });

      final errorMessage = ChatMessage.assistant(
        'すみません、一時的にサービスを利用できません。しばらく待ってからもう一度お試しください。',
      );
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medical_services, color: AppColors.textWhite),
            SizedBox(width: 8),
            Text(
              'Medical Guideline AI',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textWhite,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryRed,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.textWhite),
            onPressed: () {
              _showInfoDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textWhite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // システム状態表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _systemReady
                  ? AppColors.successGreen.withOpacity(0.1)
                  : AppColors.warningYellow.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: _systemReady
                      ? AppColors.successGreen.withOpacity(0.3)
                      : AppColors.warningYellow.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _systemReady ? Icons.check_circle : Icons.warning,
                  color: _systemReady
                      ? AppColors.successGreen
                      : AppColors.warningYellow,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _systemStatus,
                    style: TextStyle(
                      color: _systemReady
                          ? AppColors.successGreen
                          : AppColors.warningYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _checkSystemStatus,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.surfaceWhite,
              child: _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return ChatBubble(message: _messages[index]);
                      },
                    ),
            ),
          ),
          ChatInput(onSendMessage: _handleSendMessage, isLoading: _isLoading),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.medical_services, color: AppColors.primaryRed),
              SizedBox(width: 8),
              Text('Medical Guideline AI について'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'このアプリは医療ガイドラインに基づいた情報提供を目的としています。',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  '⚠️ 重要な注意事項:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorRed,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• このアプリは医師の診断や治療の代替ではありません\n'
                  '• 緊急時は直ちに医療機関にご連絡ください\n'
                  '• 重要な医療決定については必ず医師にご相談ください\n'
                  '• 症状が悪化した場合は速やかに受診してください',
                ),
                SizedBox(height: 16),
                Text('機能:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  '• 症状に関する一般的な情報提供\n'
                  '• 治療ガイドラインの検索\n'
                  '• 薬剤情報の提供\n'
                  '• 医療専門用語の説明',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
