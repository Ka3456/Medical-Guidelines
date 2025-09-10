import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const GlassInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          // 外側の影（立体感）
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // 内側の影（凹み感）
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, -3),
            spreadRadius: -3,
          ),
          // ハイライト（光沢感）
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 15,
            offset: const Offset(-3, -3),
            spreadRadius: -8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF212121).withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF212121).withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        inputFormatters: [
          if (keyboardType == TextInputType.emailAddress)
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
      ),
    );
  }
}
