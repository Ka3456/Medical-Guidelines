import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class SignUpHeader extends StatelessWidget {
  const SignUpHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primaryRed, AppColors.secondaryOrange],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.person_add, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'アカウント作成',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '新しいアカウントを作成してください',
          style: TextStyle(
            fontSize: 16,
            color: const Color(0xFF212121).withOpacity(0.8),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

