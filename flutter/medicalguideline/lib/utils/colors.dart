import 'package:flutter/material.dart';

class AppColors {
  // プライマリカラー（赤系）
  static const Color primaryRed = Color(0xFFD32F2F); // メインの赤
  static const Color primaryRedLight = Color(0xFFFF6659); // 明るい赤
  static const Color primaryRedDark = Color(0xFF9A0007); // 暗い赤

  // セカンダリカラー（オレンジ系）
  static const Color secondaryOrange = Color(0xFFFF7043); // メインのオレンジ
  static const Color secondaryOrangeLight = Color(0xFFFFAB91); // 明るいオレンジ
  static const Color secondaryOrangeDark = Color(0xFFC63F17); // 暗いオレンジ

  // ベースカラー（白系）
  static const Color backgroundWhite = Color(0xFFFFFFFF); // 純白
  static const Color surfaceWhite = Color(0xFFFAFAFA); // 少しグレーがかった白
  static const Color cardWhite = Color(0xFFF5F5F5); // カード用の白

  // テキストカラー
  static const Color textBlack = Color(0xFF212121); // 基本の黒
  static const Color textBlackSecondary = Color(0xFF757575); // セカンダリテキスト用のグレー
  static const Color textWhite = Color(0xFFFFFFFF); // 白背景用の白テキスト
  static const Color textWhiteSecondary = Color(0xFFE0E0E0); // セカンダリ白テキスト

  // アクセントカラー
  static const Color accentRed = Color(0xFFE53935); // アクセント用の赤
  static const Color accentOrange = Color(0xFFFF5722); // アクセント用のオレンジ

  // ステータスカラー
  static const Color successGreen = Color(0xFF4CAF50); // 成功
  static const Color warningYellow = Color(0xFFFFC107); // 警告
  static const Color errorRed = Color(0xFFF44336); // エラー
  static const Color infoBlue = Color(0xFF2196F3); // 情報

  // グラデーション
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, secondaryOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundWhite, surfaceWhite],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // シャドウカラー
  static const Color shadowColor = Color(0x1A000000); // 薄い黒のシャドウ
  static const Color shadowColorLight = Color(0x0D000000); // より薄いシャドウ
}
