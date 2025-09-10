import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/auth_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/auth/login_background.dart';
import '../../widgets/auth/animated_login_content.dart';
import '../../widgets/auth/login_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authNotifierProvider.notifier)
          .signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

      if (mounted) {
        ref.listen(authNotifierProvider, (previous, next) {
          next.when(
            data: (result) {
              if (result != null) {
                if (result.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ログインしました'),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'ログインに失敗しました'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            loading: () {},
            error: (error, stack) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('エラーが発生しました: $error'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoginBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedLoginContent(
                child: LoginCard(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isPasswordVisible: _isPasswordVisible,
                  onPasswordToggle: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  onLogin: _handleLogin,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
