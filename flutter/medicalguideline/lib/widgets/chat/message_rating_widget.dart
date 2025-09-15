import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../utils/colors.dart';

class MessageRatingWidget extends StatefulWidget {
  final ChatMessage message;
  final Function(int? rating, String? comment) onRatingSubmitted;

  const MessageRatingWidget({
    super.key,
    required this.message,
    required this.onRatingSubmitted,
  });

  @override
  State<MessageRatingWidget> createState() => _MessageRatingWidgetState();
}

class _MessageRatingWidgetState extends State<MessageRatingWidget> {
  int? _selectedRating;
  String _comment = '';
  final TextEditingController _commentController = TextEditingController();
  bool _isExpanded = false;
  bool _isSubmitting = false; // 送信中の状態を管理

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.message.rating;
    _comment = widget.message.comment ?? '';
    _commentController.text = _comment;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    if (_selectedRating != null && !_isSubmitting) {
      setState(() {
        _isSubmitting = true;
      });

      widget.onRatingSubmitted(
        _selectedRating!,
        _comment.isNotEmpty ? _comment : null,
      );

      setState(() {
        _isExpanded = false;
        _isSubmitting = false;
      });

      // 成功メッセージを上部に表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '評価を送信しました。ありがとうございます！',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            top: 80,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // デフォルトオプションを選択
  void _selectDefaultOption(int rating) {
    // 同じ評価を再度選択した場合は評価を削除
    if (_selectedRating == rating) {
      setState(() {
        _selectedRating = null;
      });
      _removeRating();
    } else {
      setState(() {
        _selectedRating = rating;
        // デフォルトコメントを設定
        _comment = _getDefaultComment(rating);
        _commentController.text = _comment;
      });
      _submitRating();
    }
  }

  // 評価に応じたデフォルトコメントを取得
  String _getDefaultComment(int rating) {
    switch (rating) {
      case 1:
        return '間違った情報が含まれていました';
      case 5:
        return 'とても役に立つ回答でした';
      default:
        return '';
    }
  }

  // 評価機能を非表示にするメッセージかどうかを判定
  bool _isWelcomeMessage(String content) {
    // 初期挨拶メッセージの特徴的な文字列で判定
    final isWelcomeMessage =
        content.contains('こんにちは！医療ガイドライン AI アシスタントです。') ||
        content.contains('症状、治療法、薬剤、診療ガイドラインについて何でもお聞きください。') ||
        content.contains('このアプリは情報提供のみを目的としており、医師の診断や治療の代替ではありません。');

    // エラーメッセージの特徴的な文字列で判定
    final isErrorMessage =
        content.contains('⚠️ 通信に失敗しました') ||
        content.contains('⚠️ 一時的にサービスを利用できません') ||
        content.contains('ネットワーク接続を確認して、もう一度お試しください') ||
        content.contains('しばらく待ってからもう一度お試しください');

    // 送信停止メッセージの判定
    final isStopMessage = content.contains('送信が停止されました。');

    return isWelcomeMessage || isErrorMessage || isStopMessage;
  }

  // 評価を削除
  void _removeRating() async {
    if (!_isSubmitting) {
      setState(() {
        _isSubmitting = true;
      });

      // 評価を削除（rating: null, comment: null）
      widget.onRatingSubmitted(null, null);

      setState(() {
        _isSubmitting = false;
      });

      // 削除完了メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '評価を削除しました',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textBlackSecondary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            top: 80,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // AIのメッセージのみに評価機能を表示
    if (widget.message.isUser || widget.message.isTyping) {
      return const SizedBox.shrink();
    }

    // 初期挨拶メッセージやエラーメッセージの場合は評価機能を非表示にする
    if (_isWelcomeMessage(widget.message.content)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 44, top: 8, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // デフォルト評価オプション（折りたたまれた状態）
          if (!_isExpanded && widget.message.rating == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                const Text(
                  'この回答はいかがでしたか？',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 8),

                // デフォルト評価ボタン
                Row(
                  children: [
                    // 間違った情報（星1）
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => _selectDefaultOption(1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedRating == 1
                              ? AppColors.errorRed.withOpacity(0.2)
                              : AppColors.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedRating == 1
                                ? AppColors.errorRed
                                : AppColors.errorRed.withOpacity(0.3),
                            width: _selectedRating == 1 ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedRating == 1
                                  ? Icons.error
                                  : Icons.error_outline,
                              size: 14,
                              color: AppColors.errorRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isSubmitting && _selectedRating == 1
                                  ? '送信中...'
                                  : '間違った情報',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 役に立った（星5）
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => _selectDefaultOption(5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedRating == 5
                              ? AppColors.successGreen.withOpacity(0.2)
                              : AppColors.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedRating == 5
                                ? AppColors.successGreen
                                : AppColors.successGreen.withOpacity(0.3),
                            width: _selectedRating == 5 ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedRating == 5
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 14,
                              color: AppColors.successGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isSubmitting && _selectedRating == 5
                                  ? '送信中...'
                                  : '役に立った',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // コメント付きで評価ボタン
                GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isExpanded
                          ? AppColors.primaryRed.withOpacity(0.1)
                          : AppColors.chatCostBackground.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isExpanded
                            ? AppColors.primaryRed.withOpacity(0.3)
                            : AppColors.chatCostBorder.withOpacity(0.3),
                        width: _isExpanded ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isExpanded ? Icons.edit : Icons.edit_outlined,
                          size: 12,
                          color: _isExpanded
                              ? AppColors.primaryRed
                              : AppColors.textBlackSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'コメント付きで評価',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isExpanded
                                ? AppColors.primaryRed
                                : AppColors.textBlackSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // 評価済み表示（再評価可能）
          if (widget.message.rating != null && !_isExpanded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chatCostBackground.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.chatCostBorder.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (index) {
                        final isFilled = index < widget.message.rating!;
                        return Icon(
                          isFilled ? Icons.star : Icons.star_border,
                          size: 16,
                          color: isFilled
                              ? Colors.amber
                              : AppColors.textBlackSecondary,
                        );
                      }),
                      if (widget.message.comment != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'コメントあり',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 再評価ボタン
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = true;
                      _selectedRating = widget.message.rating;
                      _comment = widget.message.comment ?? '';
                      _commentController.text = _comment;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 12, color: AppColors.primaryRed),
                        SizedBox(width: 4),
                        Text(
                          '評価を変更',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // 展開された評価フォーム
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.chatCostBorder.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル
                  const Text(
                    'この回答を評価してください',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 星評価
                  Row(
                    children: [
                      const Text(
                        '評価: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        final isSelected =
                            _selectedRating != null && index < _selectedRating!;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRating = index + 1;
                            });
                          },
                          child: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            size: 24,
                            color: isSelected
                                ? Colors.amber
                                : AppColors.textBlackSecondary,
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      if (_selectedRating != null)
                        Text(
                          '${_selectedRating}/5',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textBlack,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // コメント入力欄
                  const Text(
                    'コメント（任意）',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textBlack,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'この回答についてのご意見をお聞かせください...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textBlackSecondary.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.chatCostBorder.withOpacity(0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.chatCostBorder.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primaryRed,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textBlack,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _comment = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isExpanded = false;
                            _selectedRating = widget.message.rating;
                            _comment = widget.message.comment ?? '';
                            _commentController.text = _comment;
                          });
                        },
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textBlackSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _selectedRating != null
                            ? _submitRating
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '送信',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
