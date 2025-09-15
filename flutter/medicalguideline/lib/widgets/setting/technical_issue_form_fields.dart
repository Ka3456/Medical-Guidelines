import 'package:flutter/material.dart';

class TechnicalIssueFormFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController stepsController;

  const TechnicalIssueFormFields({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.stepsController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title field
        const Text(
          'タイトル',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: titleController,
          decoration: InputDecoration(
            hintText: '問題を簡潔に説明してください',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'タイトルを入力してください';
            }
            if (value.trim().length < 5) {
              return 'タイトルは5文字以上で入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Description field
        const Text(
          '問題の詳細',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: descriptionController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '問題の詳細を説明してください',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '詳細を入力してください';
            }
            if (value.trim().length < 10) {
              return '詳細は10文字以上で入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Steps field
        const Text(
          '再現手順（任意）',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: stepsController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '問題を再現する手順を教えてください',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}


