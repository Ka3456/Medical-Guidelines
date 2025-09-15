import 'dart:ui';
import 'package:flutter/material.dart';

class SignUpBackground extends StatelessWidget {
  final Widget child;

  const SignUpBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          // 背景の装飾的な円（薄いグレーで控えめに）
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.grey.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.grey.withOpacity(0.03), Colors.transparent],
                ),
              ),
            ),
          ),
          // ブラー効果を追加
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),
          child,
        ],
      ),
    );
  }
}

