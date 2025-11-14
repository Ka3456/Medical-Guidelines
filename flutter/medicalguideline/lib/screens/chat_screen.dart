import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart' as models;
import '../models/conversation.dart';
import '../models/auth_result.dart';
import '../widgets/chat/chat_screen_ui.dart';
import '../widgets/chat/chat_screen_manager.dart';
import '../provider/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../widgets/common/tracking_permission_dialog.dart';
// AppBarの高さはSafeAreaから動的に計算

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatScreenManager _manager = ChatScreenManager();
  final ScrollController _scrollController = ScrollController();

  List<models.ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _systemReady = false;
  String _systemStatus = 'システム状態を確認中...';
  List<Conversation> _conversations = [];
  String? _currentConversationId;
  String? _initialText;

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
    _addWelcomeMessage();
    _loadConversations();

    // 認証状態の変更を監視してトラッキング許可を確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTrackingPermissionAfterAuth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _manager.dispose();
    super.dispose();
  }

  // 認証完了後のトラッキング許可確認
  void _checkTrackingPermissionAfterAuth() {
    // 認証状態の変更を監視
    ref.listen(authStatusProvider, (previous, next) {
      next.when(
        data: (status) async {
          if (status.state == AuthState.authenticated && status.user != null) {
            final currentUser = status.user!;

            // trackingEnabledがnullの場合のみダイアログを表示
            if (currentUser.trackingEnabled == null) {
              // 少し遅延を入れて、UIが安定してからダイアログを表示
              await Future.delayed(const Duration(milliseconds: 500));

              if (!mounted) return;

              final result = await TrackingPermissionDialog.show(context);
              if (result != null && mounted) {
                await ref
                    .read(authNotifierProvider.notifier)
                    .updateTrackingPermission(result);
              }
            }
          }
        },
        loading: () {
          // 認証状態が読み込み中の場合は何もしない
        },
        error: (error, stack) {
          // エラーの場合は何もしない
        },
      );
    });
  }

  // システム状態確認
  Future<void> _checkSystemStatus() async {
    final result = await _manager.checkSystemStatus();
    setState(() {
      _systemReady = result['ready'];
      _systemStatus = result['status'];
    });
  }

  void _addWelcomeMessage() {
    final welcomeMessage = models.ChatMessage.assistant(
      'こんにちは！心不全ガイドライン AI アシスタントです。\n\n'
          '症状、治療法、薬剤、心不全ガイドラインについて何でもお聞きください。\n\n'
          '⚠️ 注意: このアプリは情報提供のみを目的としており、医師の診断や治療の代替ではありません。重要な医療決定については必ず医師にご相談ください。',
      '',
    );
    setState(() => _messages.add(welcomeMessage));
  }

  Future<void> _loadConversations() async {
    final conversations = await _manager.loadConversations();
    setState(() {
      _conversations = conversations;
      if (_conversations.isEmpty) {
        _createNewConversation();
      } else {
        _currentConversationId = _conversations.first.id;
        _loadConversationMessages(_currentConversationId!);
      }
    });
  }

  void _createNewConversation() {
    final conversation = _manager.createNewConversation(_messages);
    setState(() {
      _conversations.add(conversation);
      _currentConversationId = conversation.id;
    });
  }

  void _loadConversationMessages(String conversationId) async {
    final messages = await _manager.loadConversationMessages(conversationId);
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _selectConversation(String conversationId) {
    setState(() {
      _currentConversationId = conversationId;
      _messages.clear();
    });
    _loadConversationMessages(conversationId);
    Navigator.of(context).pop();
  }

  void _startNewConversation() async {
    setState(() => _messages.clear());
    _addWelcomeMessage();
    await _createNewConversationInFirestore();
    Navigator.of(context).pop();
  }

  Future<void> _createNewConversationInFirestore() async {
    final chatRoomId = await _manager.createNewConversationInFirestore();
    if (chatRoomId != null) {
      final conversation = _manager.createNewConversation(_messages);
      setState(() {
        _conversations.insert(0, conversation);
        _currentConversationId = conversation.id;
      });
    } else {
      _createNewConversation();
    }
  }

  void _handleQuestionTap(String question) {
    setState(() {
      _initialText = question;
    });
  }

  void _handleResend(int messageIndex) {
    // 指定されたインデックスの一つ前のユーザーメッセージを探す
    String? userMessage;
    for (int i = messageIndex - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        userMessage = _messages[i].content;
        break;
      }
    }

    if (userMessage != null) {
      setState(() {
        _initialText = userMessage;
      });
    }
  }

  void _handleRatingSubmitted(int? rating, String? comment) {
    _manager.handleRatingSubmitted(
      rating,
      comment,
      _messages,
      _currentConversationId,
      (messages) => setState(() => _messages = messages),
    );
  }

  void _handleSendMessage(String text) async {
    // メッセージ送信後は初期テキストをクリア
    setState(() {
      _initialText = null;
    });

    await _manager.sendMessage(
      text,
      _messages,
      _currentConversationId,
      (messages) => setState(() => _messages = messages),
      (loading) => setState(() => _isLoading = loading),
      (conversationId) =>
          setState(() => _currentConversationId = conversationId),
      (conversations) => setState(() => _conversations = conversations),
      () => setState(() {}),
    );
    _scrollToBottom();
  }

  void _handleStopSending() {
    // 現在のメッセージから最新のユーザーメッセージを取得
    models.ChatMessage? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserMessage = _messages[i];
        break;
      }
    }

    _manager.stopSending(
      updateLoading: (loading) => setState(() => _isLoading = loading),
      updateMessages: (messages) => setState(() => _messages = messages),
      messages: _messages,
      userMessage: lastUserMessage,
      currentConversationId: _currentConversationId,
    );
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

  void _deleteConversation(String conversationId) async {
    await _manager.deleteConversation(conversationId);
    setState(() {
      _conversations.removeWhere((conv) => conv.id == conversationId);
      if (_currentConversationId == conversationId) {
        _messages.clear();
        _addWelcomeMessage();
        _createNewConversation();
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会話を削除しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 認証状態を監視
    final authStatus = ref.watch(authStatusProvider);

    // 認証されていない場合はログイン画面にリダイレクト
    return authStatus.when(
      data: (status) {
        if (status.state != AuthState.authenticated) {
          // 認証されていない場合はログイン画面を表示
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 認証されている場合は通常のチャット画面を表示
        return ChatScreenUI(
          messages: _messages,
          scrollController: _scrollController,
          isLoading: _isLoading,
          systemReady: _systemReady,
          systemStatus: _systemStatus,
          conversations: _conversations,
          currentConversationId: _currentConversationId,
          progressValue: _manager.messageSender.progressManager.progressValue,
          onSendMessage: _handleSendMessage,
          onStopSending: _handleStopSending,
          onResend: _handleResend,
          onRatingSubmitted: _handleRatingSubmitted,
          onQuestionTap: _handleQuestionTap,
          onConversationSelected: _selectConversation,
          onNewConversation: _startNewConversation,
          onConversationDeleted: _deleteConversation,
          onRefresh: _loadConversations,
          onSystemRefresh: _checkSystemStatus,
          initialText: _initialText,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        // エラーの場合はログイン画面にリダイレクト
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
