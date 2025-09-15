import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE3F2FD).withOpacity(0.8),
            const Color(0xFFBBDEFB).withOpacity(0.6),
            const Color(0xFF90CAF9).withOpacity(0.4),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 装飾的な背景要素（ブラー効果付きの円）
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
