import 'package:flutter/material.dart';
import 'dart:ui';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function() onStopSending;
  final bool isLoading;
  final double progressValue;
  final String? initialText;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onStopSending,
    this.isLoading = false,
    this.progressValue = 0.0,
    this.initialText,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 初期テキストが設定されている場合は設定
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
      _isComposing = widget.initialText!.trim().isNotEmpty;
    }
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // initialTextが変更された場合、テキストフィールドを更新
    if (widget.initialText != oldWidget.initialText) {
      if (widget.initialText != null) {
        _controller.text = widget.initialText!;
        setState(() {
          _isComposing = widget.initialText!.trim().isNotEmpty;
        });
      } else {
        _controller.clear();
        setState(() {
          _isComposing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || widget.isLoading) return;

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    widget.onSendMessage(text.trim());
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                onChanged: (text) {
                                  setState(() {
                                    _isComposing = text.trim().isNotEmpty;
                                  });
                                },
                                onSubmitted: _handleSubmitted,
                                enabled: !widget.isLoading,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: '心不全ガイドラインについて質問してください...',
                                  hintStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 12,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: (_isComposing && !widget.isLoading)
                                ? const Color(0xFF007AFF).withOpacity(0.3)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _isComposing && !widget.isLoading
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF007AFF),
                                        Color(0xFF5856D6),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.25),
                                        Colors.white.withOpacity(0.15),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(25),
                                onTap: widget.isLoading
                                    ? () => widget.onStopSending()
                                    : (_isComposing && !widget.isLoading)
                                    ? () => _handleSubmitted(_controller.text)
                                    : null,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  child: widget.isLoading
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // プログレスインジケーター（外側）
                                            SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: CircularProgressIndicator(
                                                value: widget.progressValue,
                                                strokeWidth: 3.0,
                                                backgroundColor: Colors.white
                                                    .withOpacity(0.2),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF007AFF)),
                                              ),
                                            ),
                                            // 停止ボタン（中央）
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    blurRadius: 3,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.stop_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Icon(
                                          Icons.send_rounded,
                                          color:
                                              _isComposing && !widget.isLoading
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.7),
                                          size: 18,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
