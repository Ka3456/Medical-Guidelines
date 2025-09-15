import 'package:flutter/material.dart';
import 'dart:ui';
import '../../utils/colors.dart';

class LiquidGlassRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const LiquidGlassRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<LiquidGlassRefreshIndicator> createState() =>
      _LiquidGlassRefreshIndicatorState();
}

class _LiquidGlassRefreshIndicatorState
    extends State<LiquidGlassRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _scaleController.forward();
    _rotationController.repeat();

    try {
      await widget.onRefresh();
      // 少し待ってからアニメーションを終了
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      _rotationController.stop();
      _rotationController.reset();
      _scaleController.reverse();

      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo is ScrollUpdateNotification) {
              // リストが一番上にいて、下方向にスクロールしようとした時
              if (scrollInfo.metrics.pixels <= 0 &&
                  scrollInfo.scrollDelta! > 0) {
                if (!_isRefreshing) {
                  _handleRefresh();
                }
              }
            }
            return false;
          },
          child: widget.child,
        ),
        if (_isRefreshing)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _rotationAnimation,
                  _scaleAnimation,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.25),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(-2, -2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Center(
                            child: Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.textBlack.withValues(
                                    alpha: 0.8,
                                  ),
                                  size: 24,
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
            ),
          ),
      ],
    );
  }
}
