import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../../screens/auth/sign_up_screen.dart';

class SignUpLink extends StatelessWidget {
  const SignUpLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'アカウントをお持ちでない方は ',
          style: TextStyle(
            color: const Color(0xFF212121).withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(
              context,
            ).push(SlideUpScalePageRoute(child: const SignUpScreen()));
          },
          child: Text(
            '新規登録',
            style: TextStyle(
              color: const Color(0xFF212121),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
