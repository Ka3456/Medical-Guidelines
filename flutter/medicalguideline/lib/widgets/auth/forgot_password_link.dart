import 'package:flutter/material.dart';

class ForgotPasswordLink extends StatelessWidget {
  const ForgotPasswordLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            // パスワードリセット機能（後で実装）
          },
          child: Text(
            'パスワードを忘れた方',
            style: TextStyle(
              color: const Color(0xFF212121).withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
