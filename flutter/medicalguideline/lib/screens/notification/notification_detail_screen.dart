import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification.dart' as notification_model;
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/back_button.dart';
import 'dart:ui';

class NotificationDetailScreen extends ConsumerWidget {
  final notification_model.Notification notification;
  final VoidCallback? onNotificationUpdated;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
    this.onNotificationUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          top: true,
          left: true,
          right: true,
          bottom: false,
          child: Column(
            children: [
              // ヘッダー部分
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Row(
                  children: [
                    CustomBackButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // 通知更新のコールバックを呼び出し
                        onNotificationUpdated?.call();
                      },
                    ),
                    const Expanded(
                      child: Text(
                        '通知詳細',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 50), // バランス調整
                  ],
                ),
              ),
              // メインコンテンツ
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 通知カード
                      _buildNotificationCard(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: notification.isRead
              ? [
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.2),
                ]
              : [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notification.isRead
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.blue.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, -8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー部分（アイコン + タイプ）
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: notification.isRead
                              ? [
                                  Colors.grey.withValues(alpha: 0.2),
                                  Colors.grey.withValues(alpha: 0.1),
                                ]
                              : [
                                  _getTypeColor(
                                    notification.type ?? 'system',
                                  ).withValues(alpha: 0.2),
                                  _getTypeColor(
                                    notification.type ?? 'system',
                                  ).withValues(alpha: 0.1),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: notification.isRead
                              ? Colors.grey.withValues(alpha: 0.5)
                              : _getTypeColor(
                                  notification.type ?? 'system',
                                ).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: notification.isRead
                            ? Colors.grey
                            : _getTypeColor(notification.type ?? 'system'),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notification.type != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(
                                  notification.type!,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _getTypeColor(
                                    notification.type!,
                                  ).withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _getTypeLabel(notification.type!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getTypeColor(notification.type!),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // タイトル
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                // 内容
                Text(
                  notification.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                // ステータス表示
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: notification.isRead
                              ? Colors.green.withValues(alpha: 0.5)
                              : Colors.orange.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            notification.isRead
                                ? Icons.check_circle_outline
                                : Icons.circle_outlined,
                            size: 16,
                            color: notification.isRead
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notification.isRead ? '既読' : '未読',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: notification.isRead
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble;
      case 'system':
        return Icons.system_update;
      case 'update':
        return Icons.update;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'chat':
        return Colors.green;
      case 'system':
        return Colors.orange;
      case 'update':
        return Colors.blue;
      case 'security':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'chat':
        return 'チャット';
      case 'system':
        return 'システム';
      case 'update':
        return 'アップデート';
      case 'security':
        return 'セキュリティ';
      default:
        return 'その他';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}
