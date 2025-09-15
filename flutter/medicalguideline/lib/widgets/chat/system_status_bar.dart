import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class SystemStatusBar extends StatelessWidget {
  final bool systemReady;
  final String systemStatus;
  final VoidCallback onRefresh;

  const SystemStatusBar({
    super.key,
    required this.systemReady,
    required this.systemStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (systemReady) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppColors.warningYellow.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppColors.warningYellow, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              systemStatus,
              style: const TextStyle(
                color: AppColors.warningYellow,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
