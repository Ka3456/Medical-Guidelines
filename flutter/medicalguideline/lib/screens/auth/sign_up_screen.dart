import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalguideline/screens/chat_screen.dart';
import '../../provider/auth_provider.dart';
import '../../widgets/auth/sign_up_card.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/auth/sign_up_listeners.dart';
import '../../widgets/auth/sign_up_animations.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref
            .read(authNotifierProvider.notifier)
            .createUserWithEmailAndPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const ChatScreen()));
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void _togglePasswordVisibility() =>
      setState(() => _isPasswordVisible = !_isPasswordVisible);
  void _toggleConfirmPasswordVisibility() =>
      setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
  void _backToLogin() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Stack(
          children: [
            const SignUpListeners(),
            // メインコンテンツ
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SignUpAnimations(
                    child: SignUpCard(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      isPasswordVisible: _isPasswordVisible,
                      isConfirmPasswordVisible: _isConfirmPasswordVisible,
                      onPasswordVisibilityToggle: _togglePasswordVisibility,
                      onConfirmPasswordVisibilityToggle:
                          _toggleConfirmPasswordVisibility,
                      onSignUp: _handleSignUp,
                      onBackToLogin: _backToLogin,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
