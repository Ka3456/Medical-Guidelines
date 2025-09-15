import 'package:flutter/material.dart';

class UsernameInput extends StatelessWidget {
  final TextEditingController controller;

  const UsernameInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'ユーザー名',
            labelStyle: TextStyle(color: Colors.black87.withOpacity(0.7)),
            hintText: 'ユーザー名を入力',
            hintStyle: TextStyle(color: Colors.black54.withOpacity(0.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.3),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
          ),
          style: const TextStyle(color: Colors.black87),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'ユーザー名を入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'チャット等のやり取りに使用します。一般には公開されません。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
