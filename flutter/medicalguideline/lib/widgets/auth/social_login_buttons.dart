import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.apple,
            label: 'Apple',
            onTap: () {
              // Apple ID ログイン（後で実装）
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google',
            onTap: () {
              // Google ログイン（後で実装）
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        boxShadow: [
          // 外側の影（立体感）
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          // 内側の影（凹み感）
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: -2,
          ),
          // ハイライト（光沢感）
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(-2, -2),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFF212121).withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF212121).withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
