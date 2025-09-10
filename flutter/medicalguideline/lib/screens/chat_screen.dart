import 'package:flutter/material.dart';
import 'dart:ui';
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
      '', // 第2引数（使用されていないパラメータ）
      // 第2引数（使用されていないパラメータ）
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

      // デバッグ用：エラー詳細を出力
      debugPrint('=== 通信エラー詳細 ===');
      debugPrint('エラータイプ: ${e.runtimeType}');
      debugPrint('エラーメッセージ: $e');
      if (e is ChatServiceException) {
        debugPrint('元のエラー: ${e.originalError}');
      }
      debugPrint('==================');

      // エラーメッセージを決定
      String errorText;
      if (e.toString().contains('ChatServiceException')) {
        // 通信エラーの場合
        errorText = '⚠️ 通信に失敗しました\n\nネットワーク接続を確認して、もう一度お試しください。';
      } else {
        // その他のエラーの場合
        errorText = '⚠️ 一時的にサービスを利用できません\n\nしばらく待ってからもう一度お試しください。';
      }

      final errorMessage = ChatMessage.assistant(
        errorText,
        '', // 第2引数（使用されていないパラメータ）
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.5),
              ],
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                title: const SizedBox.shrink(),
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                scrolledUnderElevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // ハンバーガーメニューの処理
                            Scaffold.of(context).openDrawer();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.notes,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Info アイコン
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _showInfoDialog();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Settings アイコン
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // システム状態表示（準備できていない時のみ表示）
          if (!_systemReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningYellow.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.warningYellow.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning,
                    color: AppColors.warningYellow,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _systemStatus,
                      style: const TextStyle(
                        color: AppColors.warningYellow,
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
              color: Colors.transparent,
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
          Container(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: ChatInput(
              onSendMessage: _handleSendMessage,
              isLoading: _isLoading,
            ),
          ),
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
