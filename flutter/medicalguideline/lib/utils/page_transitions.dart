import 'package:flutter/material.dart';

/// 下から上に浮かび上がるページトランジション
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  SlideUpPageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // 下から上へのスライドアニメーション
           const begin = Offset(0.0, 1.0);
           const end = Offset.zero;
           const curve = Curves.easeOutCubic;

           var tween = Tween(
             begin: begin,
             end: end,
           ).chain(CurveTween(curve: curve));

           // フェードアニメーションも追加
           var fadeTween = Tween<double>(
             begin: 0.0,
             end: 1.0,
           ).chain(CurveTween(curve: curve));

           return SlideTransition(
             position: animation.drive(tween),
             child: FadeTransition(
               opacity: animation.drive(fadeTween),
               child: child,
             ),
           );
         },
       );
}

/// 上から下に沈むページトランジション（戻る時用）
class SlideDownPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  SlideDownPageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // 上から下へのスライドアニメーション
           const begin = Offset(0.0, -1.0);
           const end = Offset.zero;
           const curve = Curves.easeOutCubic;

           var tween = Tween(
             begin: begin,
             end: end,
           ).chain(CurveTween(curve: curve));

           // フェードアニメーションも追加
           var fadeTween = Tween<double>(
             begin: 0.0,
             end: 1.0,
           ).chain(CurveTween(curve: curve));

           return SlideTransition(
             position: animation.drive(tween),
             child: FadeTransition(
               opacity: animation.drive(fadeTween),
               child: child,
             ),
           );
         },
       );
}

/// より滑らかな下から上へのトランジション（スケール効果付き）
class SlideUpScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  SlideUpScalePageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // 下から上へのスライドアニメーション
           const slideBegin = Offset(0.0, 1.0);
           const slideEnd = Offset.zero;
           const curve = Curves.easeOutCubic;

           var slideTween = Tween(
             begin: slideBegin,
             end: slideEnd,
           ).chain(CurveTween(curve: curve));

           // スケールアニメーション
           var scaleTween = Tween<double>(
             begin: 0.8,
             end: 1.0,
           ).chain(CurveTween(curve: Curves.easeOutBack));

           // フェードアニメーション
           var fadeTween = Tween<double>(
             begin: 0.0,
             end: 1.0,
           ).chain(CurveTween(curve: curve));

           return SlideTransition(
             position: animation.drive(slideTween),
             child: ScaleTransition(
               scale: animation.drive(scaleTween),
               child: FadeTransition(
                 opacity: animation.drive(fadeTween),
                 child: child,
               ),
             ),
           );
         },
       );
}
