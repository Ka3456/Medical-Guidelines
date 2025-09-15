import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/chat_message.dart';
import '../../utils/colors.dart';
import '../../screens/pdfs/pdf_screen.dart';
import 'message_rating_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onResend; // 引数なしのコールバックに変更
  final Function(int? rating, String? comment)? onRatingSubmitted;

  const ChatBubble({
    super.key,
    required this.message,
    this.onResend,
    this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isTyping) {
      return _buildTypingIndicator();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（アバター + 名前 + 時刻）
          Row(
            children: [
              _buildAvatar(message.isUser),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      message.isUser ? 'あなた' : 'Medical AI',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: const TextStyle(
                        color: AppColors.chatTimestamp,
                        fontSize: 12,
                      ),
                    ),
                    if (message.costInfo != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.chatCostBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.chatCostBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${message.costInfo!.totalCostJpy.toStringAsFixed(1)}円',
                          style: const TextStyle(
                            color: AppColors.chatCostText,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // メッセージ内容
          Padding(
            padding: const EdgeInsets.only(left: 44.0), // アバター分のオフセット
            child: message.isUser
                ? Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textBlack,
                      height: 1.5,
                    ),
                  )
                : SelectionArea(
                    // ← selectable:true の代わりに選択可にする
                    child: MarkdownBody(
                      data: _preprocessMarkdown(
                        message.content,
                      ), // ← ここで note:… を URI 化
                      selectable: false, // ← 既知のタップ不具合回避
                      styleSheet: _getMarkdownStyleSheet(),
                      onTapLink: (text, href, title) =>
                          _handleTapLink(context, text, href, title),
                    ),
                  ),
          ),

          // 再送ボタン（AIの回答の場合のみ表示、ただしウェルカムメッセージは除く）
          if (!message.isUser &&
              onResend != null &&
              !_isWelcomeMessage(message.content))
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => onResend!(),
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.infoBlue,
                    ),
                    label: const Text(
                      '再送',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.infoBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

          // 評価ウィジェットを追加
          if (onRatingSubmitted != null)
            MessageRatingWidget(
              message: message,
              onRatingSubmitted: onRatingSubmitted!,
            ),
        ],
      ),
    );
  }

  /// ( ... ](note:page=63;section=第6章 心不全…;reason=HFrEF) を
  /// ( ... ](note://open?page=63&section=...&reason=HFrEF) に正規化
  String _preprocessMarkdown(String md) {
    final reg = RegExp(r'\]\((note:[^)]+)\)');
    return md.replaceAllMapped(reg, (m) {
      final raw = m.group(1)!; // "note:page=...;section=...;reason=..."
      final body = raw.substring('note:'.length);

      final params = <String, String>{};
      for (final part in body.split(';')) {
        final eq = part.indexOf('=');
        if (eq <= 0) continue;
        final k = part.substring(0, eq).trim();
        final v = part.substring(eq + 1).trim();
        params[k] = Uri.encodeComponent(v); // スペース/日本語を安全に
      }

      final href =
          'note://open?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      return ']($href)';
    });
  }

  /// すべてのリンクタップをここで集約
  void _handleTapLink(
    BuildContext context,
    String text,
    String? href,
    String? title,
  ) {
    if (href == null) return;

    if (href.startsWith('note://')) {
      final uri = Uri.parse(href);
      final page = int.tryParse(uri.queryParameters['page'] ?? '');
      final section = uri.queryParameters['section']; // 自動デコード
      final reason = uri.queryParameters['reason'];

      _openNote(context, page: page, section: section, reason: reason);
      return;
    }

    // 既存の外部リンク処理
    _showLinkPopup(context, text, href, title);
  }

  /// ノート画面（PDF 等）を開く
  void _openNote(
    BuildContext context, {
    int? page,
    String? section,
    String? reason,
  }) {
    // PDF画面への遷移を実装
    // 現在はポップアップで詳細を表示
    _showNoteDialog(
      context,
      '詳細情報',
      'page=${page ?? 'N/A'};section=${section ?? 'N/A'};reason=${reason ?? 'N/A'}',
    );

    // TODO: 実際のPDF画面への遷移を実装する場合
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PdfViewerScreen(
    //       page: page,
    //       section: section,
    //       reason: reason,
    //     ),
    //   ),
    // );
  }

  // ウェルカムメッセージかどうかを判定
  bool _isWelcomeMessage(String content) {
    // 初期挨拶メッセージの特徴的な文字列で判定
    return content.contains('こんにちは！医療ガイドライン AI アシスタントです。') ||
        content.contains('症状、治療法、薬剤、診療ガイドラインについて何でもお聞きください。') ||
        content.contains('このアプリは情報提供のみを目的としており、医師の診断や治療の代替ではありません。');
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? AppColors.chatUserAvatar
          : AppColors.chatAiAvatar,
      child: Icon(
        isUser ? Icons.person : Icons.medical_services,
        color: AppColors.textWhite,
        size: 20,
      ),
    );
  }

  void _showLinkPopup(
    BuildContext context,
    String text,
    String? href,
    String? title,
  ) {
    // note: で始まるリンクの場合、デコードして内容を表示
    if (href != null && href.startsWith('note:')) {
      try {
        // URLデコード
        final decodedText = Uri.decodeComponent(
          href.substring(5),
        ); // 'note:'を除去
        _showNoteDialog(context, text, decodedText);
      } catch (e) {
        _showNoteDialog(context, text, href);
      }
    }
    // 通常のリンクは無視（現在のアプリではnote:リンクのみ使用）
  }

  MarkdownStyleSheet _getMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(fontSize: 16, color: AppColors.textBlack, height: 1.5),
      h1: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textBlack,
        height: 1.3,
      ),
      h2: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textBlack,
        height: 1.3,
      ),
      h3: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textBlack,
        height: 1.3,
      ),
      code: const TextStyle(
        fontSize: 14,
        backgroundColor: AppColors.chatCodeBackground,
        color: AppColors.textBlack,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.chatCodeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.chatCodeBorder),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.chatQuoteBorder, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      listBullet: const TextStyle(color: AppColors.textBlack, fontSize: 16),
      strong: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.textBlack,
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: AppColors.textBlack,
      ),
      a: const TextStyle(
        color: AppColors.primaryRed,
        decoration: TextDecoration.underline,
      ),
    );
  }

  void _showNoteDialog(
    BuildContext context,
    String linkText,
    String noteContent,
  ) {
    // note: の内容をパースして表示
    final parts = noteContent.split(';');
    String page = '';
    String section = '';
    String reason = '';

    for (final part in parts) {
      if (part.startsWith('page=')) {
        page = part.substring(5);
      } else if (part.startsWith('section=')) {
        section = part.substring(8);
      } else if (part.startsWith('reason=')) {
        reason = part.substring(7);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 10,
          ), // 左右の余白を最小限に
          content: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8, // 画面の80%まで
              maxWidth:
                  MediaQuery.of(context).size.width *
                  0.95, // 画面の95%まで（ギリギリまで拡大）
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F9FA), // 薄いグレー
                  Color(0xFFE3F2FD), // 薄いブルー
                  Color(0xFFF3E5F5), // 薄いパープル
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ヘッダー部分
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '心不全ガイドライン',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 理由を大きく表示
                  if (reason.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBlack,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // セクション情報
                  if (section.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        section,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textBlack,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ページ情報を下に配置
                  if (page.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        // ページ番号を抽出
                        final pageNumber = int.tryParse(page);
                        if (pageNumber != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfScreen(
                                pdfPath: '心不全診療ガイドライン',
                                initialPage: pageNumber,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.description,
                              size: 16,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ページ $page',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.touch_app,
                              size: 14,
                              color: AppColors.primaryRed,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 閉じるボタン
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '閉じる',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（アバター + 名前）
          Row(
            children: [
              _buildAvatar(false),
              const SizedBox(width: 12),
              const Text(
                'Medical AI',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // タイピングインジケーター
          Padding(
            padding: const EdgeInsets.only(left: 44.0), // アバター分のオフセット
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: const SizedBox(
                width: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TypingDot(delay: 0),
                    _TypingDot(delay: 200),
                    _TypingDot(delay: 400),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.chatAiAvatar.withValues(
              alpha: 0.4 + (_animation.value * 0.6),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
