import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_header.dart';
import 'glass_input_field.dart';
import 'login_button.dart';
import 'forgot_password_link.dart';
import 'divider_with_text.dart';
import 'social_login_buttons.dart';
import 'sign_up_link.dart';

class LoginCard extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final VoidCallback onPasswordToggle;
  final VoidCallback onLogin;

  const LoginCard({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.onPasswordToggle,
    required this.onLogin,
  });

  @override
  ConsumerState<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<LoginCard> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width > 400 ? 400 : size.width - 48,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.15),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        boxShadow: [
          // 外側の影（立体感）
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: 0,
          ),
          // 内側の影（凹み感）
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: -5,
          ),
          // ハイライト（光沢感）
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(-5, -5),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoginHeader(),
            const SizedBox(height: 40),
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 16),
            const ForgotPasswordLink(),
            const SizedBox(height: 32),
            LoginButton(onPressed: widget.onLogin),
            const SizedBox(height: 24),
            const DividerWithText(text: 'または'),
            const SizedBox(height: 24),
            const SocialLoginButtons(),
            const SizedBox(height: 24),
            const SignUpLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return GlassInputField(
      controller: widget.emailController,
      label: 'メールアドレス',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'メールアドレスを入力してください';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return '有効なメールアドレスを入力してください';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return GlassInputField(
      controller: widget.passwordController,
      label: 'パスワード',
      icon: Icons.lock_outline,
      obscureText: !widget.isPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          widget.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey.withOpacity(0.7),
        ),
        onPressed: widget.onPasswordToggle,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'パスワードを入力してください';
        }
        if (value.length < 6) {
          return 'パスワードは6文字以上で入力してください';
        }
        return null;
      },
    );
  }
}
