import 'package:flutter/material.dart';

class SuggestedQuestions extends StatelessWidget {
  final Function(String) onQuestionTap;

  const SuggestedQuestions({super.key, required this.onQuestionTap});

  @override
  Widget build(BuildContext context) {
    final List<String> questions = [
      "慢性心不全の治療方針は？",
      "心不全の症状とは？",
      "心不全の原因は？",
      "心不全の予防法は？",
      "心不全の検査方法は？",
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            child: ElevatedButton(
              onPressed: () => onQuestionTap(questions[index]),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Text(
                questions[index],
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        },
      ),
    );
  }
}
