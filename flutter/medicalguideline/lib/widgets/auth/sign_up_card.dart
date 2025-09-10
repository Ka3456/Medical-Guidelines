import 'package:flutter/material.dart';
import 'glass_input_field.dart';
import 'sign_up_header.dart';
import 'sign_up_button.dart';

class SignUpCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onConfirmPasswordVisibilityToggle;
  final VoidCallback onSignUp;
  final VoidCallback onBackToLogin;

  const SignUpCard({
    super.key,
    required this.formKey,
    required this.displayNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.onPasswordVisibilityToggle,
    required this.onConfirmPasswordVisibilityToggle,
    required this.onSignUp,
    required this.onBackToLogin,
  });

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
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SignUpHeader(),
            const SizedBox(height: 40),
            _buildDisplayNameField(),
            const SizedBox(height: 20),
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 20),
            _buildConfirmPasswordField(),
            const SizedBox(height: 32),
            SignUpButton(onPressed: onSignUp),
            const SizedBox(height: 24),
            _buildBackToLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return GlassInputField(
      controller: displayNameController,
      label: '表示名（任意）',
      icon: Icons.person_outline,
      validator: (value) {
        // Display name is optional
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return GlassInputField(
      controller: emailController,
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
      controller: passwordController,
      label: 'パスワード',
      icon: Icons.lock_outline,
      obscureText: !isPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey.withOpacity(0.7),
        ),
        onPressed: onPasswordVisibilityToggle,
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

  Widget _buildConfirmPasswordField() {
    return GlassInputField(
      controller: confirmPasswordController,
      label: 'パスワード確認',
      icon: Icons.lock_outline,
      obscureText: !isConfirmPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey.withOpacity(0.7),
        ),
        onPressed: onConfirmPasswordVisibilityToggle,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'パスワード確認を入力してください';
        }
        if (value != passwordController.text) {
          return 'パスワードが一致しません';
        }
        return null;
      },
    );
  }

  Widget _buildBackToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '既にアカウントをお持ちの方は ',
          style: TextStyle(
            color: const Color(0xFF212121).withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        GestureDetector(
          onTap: onBackToLogin,
          child: Text(
            'ログイン',
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
