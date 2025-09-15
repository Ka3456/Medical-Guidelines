import 'package:flutter/material.dart';

class TechnicalIssueCategoryChips extends StatelessWidget {
  final Set<String> selectedCategories;
  final Function(String) onCategoryToggle;

  const TechnicalIssueCategoryChips({
    super.key,
    required this.selectedCategories,
    required this.onCategoryToggle,
  });

  static const List<String> _categories = [
    'バグ',
    'パフォーマンス',
    'UI/UX',
    '機能要望',
    'その他',
  ];

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'バグ':
        return Icons.bug_report;
      case 'パフォーマンス':
        return Icons.speed;
      case 'UI/UX':
        return Icons.design_services;
      case '機能要望':
        return Icons.lightbulb_outline;
      case 'その他':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _categories.map((category) {
        final isSelected = selectedCategories.contains(category);
        return GestureDetector(
          onTap: () => onCategoryToggle(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.8),
                        Colors.orange.withOpacity(0.6),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, color: Colors.white, size: 16),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}


