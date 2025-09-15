import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/conversation.dart';

class ConversationItemMenu extends StatefulWidget {
  final Conversation conversation;
  final Function(String)? onDelete;

  const ConversationItemMenu({
    super.key,
    required this.conversation,
    this.onDelete,
  });

  @override
  State<ConversationItemMenu> createState() => _ConversationItemMenuState();
}

class _ConversationItemMenuState extends State<ConversationItemMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onDelete == null) return const SizedBox.shrink();

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _animationController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _animationController.reverse();
        _showDeleteDialog(context);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _isPressed ? 0.25 : 0.18),
                    Colors.white.withValues(alpha: _isPressed ? 0.15 : 0.12),
                    Colors.white.withValues(alpha: _isPressed ? 0.20 : 0.15),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: _isPressed ? 0.35 : 0.25,
                  ),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isPressed ? 0.05 : 0.03,
                    ),
                    blurRadius: _isPressed ? 12 : 16,
                    offset: Offset(0, _isPressed ? 2 : 3),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: _isPressed ? 0.25 : 0.18,
                    ),
                    blurRadius: _isPressed ? 8 : 12,
                    offset: const Offset(-1, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                            alpha: _isPressed ? 0.08 : 0.05,
                          ),
                          Colors.transparent,
                          Colors.white.withValues(
                            alpha: _isPressed ? 0.06 : 0.03,
                          ),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: Colors.red.withValues(
                          alpha: _isPressed ? 0.8 : 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.40),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.45),
                  blurRadius: 35,
                  offset: const Offset(-4, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 32,
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '削除',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '「${widget.conversation.title.isNotEmpty ? widget.conversation.title : widget.conversation.autoTitle}」を削除しますか？',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogButton(
                            'キャンセル',
                            Colors.grey,
                            () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDeleteButton('削除', () {
                            Navigator.of(dialogContext).pop();
                            widget.onDelete?.call(widget.conversation.id);
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              decoration: BoxDecoration(color: Colors.transparent),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color == Colors.grey
                        ? Colors.black.withValues(alpha: 0.7)
                        : color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.withValues(alpha: 0.9),
              Colors.red.withValues(alpha: 0.8),
              Colors.red.withValues(alpha: 0.85),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
