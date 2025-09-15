import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification.dart' as notification_model;
import '../../services/firestore_service.dart';
import '../../provider/auth_provider.dart';
import '../../provider/notification_provider.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/back_button.dart';
import '../../widgets/setting/section_card.dart';
import 'notification_detail_screen.dart';
import 'dart:ui';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<notification_model.Notification> _notifications = [];
  Map<String, bool> _globalNotificationReadStatus = {}; // 全ユーザー向け通知の既読状態
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authState = ref.read(authStatusProvider);
      authState.whenData((authResult) {
        if (authResult.user != null) {
          _firestoreService
              .getUserNotificationsStream(authResult.user!.uid)
              .listen(
                (notifications) async {
                  if (mounted) {
                    // 全ユーザー向け通知の既読状態をチェック
                    final readStatusMap = <String, bool>{};
                    for (final notification in notifications) {
                      if (notification.userId == null) {
                        // 全ユーザー向け通知の場合
                        final isRead = await _firestoreService
                            .isGlobalNotificationRead(
                              authResult.user!.uid,
                              notification.id,
                            );
                        readStatusMap[notification.id] = isRead;
                      }
                    }

                    setState(() {
                      _notifications = notifications;
                      _globalNotificationReadStatus = readStatusMap;
                      _isLoading = false;
                    });
                  }
                },
                onError: (error) {
                  if (mounted) {
                    setState(() {
                      _error = error.toString();
                      _isLoading = false;
                    });
                  }
                },
              );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final authState = ref.read(authStatusProvider);
      authState.whenData((authResult) async {
        if (authResult.user != null) {
          await _firestoreService.markNotificationAsRead(
            authResult.user!.uid,
            notificationId,
          );

          // ローカルの既読状態も更新
          if (mounted) {
            setState(() {
              _globalNotificationReadStatus[notificationId] = true;
            });
          }

          // 通知の既読状態をProviderで更新
          ref
              .read(notificationReadStateProvider.notifier)
              .markAsRead(notificationId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('既読にできませんでした: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final authState = ref.read(authStatusProvider);
      authState.whenData((authResult) async {
        if (authResult.user != null) {
          // 未読の通知IDを取得（read_byサブコレクション対応）
          final unreadIds = <String>[];
          for (final notification in _notifications) {
            if (!_isNotificationRead(notification)) {
              unreadIds.add(notification.id);
            }
          }

          if (unreadIds.isNotEmpty) {
            await _firestoreService.markNotificationsAsRead(
              authResult.user!.uid,
              unreadIds,
            );

            // ローカルの既読状態も更新
            if (mounted) {
              setState(() {
                for (final id in unreadIds) {
                  _globalNotificationReadStatus[id] = true;
                }
              });
            }

            // すべての通知の既読状態をProviderで更新
            final readStateNotifier = ref.read(
              notificationReadStateProvider.notifier,
            );
            for (final id in unreadIds) {
              readStateNotifier.markAsRead(id);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('すべての通知を既読にしました'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('既読にできませんでした: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const CustomBackButton(),
                    const Expanded(
                      child: Text(
                        '通知',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // すべて既読ボタン
                    Consumer(
                      builder: (context, ref, child) {
                        final unreadCount = _notifications
                            .where((n) => !_isNotificationRead(n))
                            .length;

                        if (unreadCount == 0) {
                          return const SizedBox(width: 50);
                        }

                        return TextButton(
                          onPressed: _markAllAsRead,
                          child: Text(
                            'すべて既読',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // メインコンテンツ
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _showCreateNotificationDialog,
      //   backgroundColor: Theme.of(context).primaryColor,
      //   foregroundColor: Colors.white,
      //   icon: const Icon(Icons.add),
      //   label: const Text('通知作成'),
      // ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('エラーが発生しました', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '通知はありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SectionCard(
        title: '通知一覧',
        children: [
          const SizedBox(height: 10),
          ..._notifications.map(
            (notification) => _buildNotificationItem(notification),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(notification_model.Notification notification) {
    final isRead = _isNotificationRead(notification);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRead
              ? [
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.2),
                ]
              : [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 15,
            offset: const Offset(0, -6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                // 通知を既読にする（Firestore更新）
                await _markAsRead(notification.id);

                // 既読状態に更新された通知オブジェクトを作成
                final readNotification = notification.markAsRead();

                // 通知一覧をリフレッシュ
                if (mounted) {
                  await _loadNotifications();
                }

                // 詳細画面に遷移
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationDetailScreen(
                        notification: readNotification,
                        onNotificationUpdated: () {
                          // 詳細画面から戻った時に通知一覧をリフレッシュ
                          _loadNotifications();
                        },
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // 通知アイコン
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isRead
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead
                              ? Colors.grey.withValues(alpha: 0.5)
                              : _getTypeColor(
                                  notification.type ?? 'system',
                                ).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: isRead
                            ? Colors.grey
                            : _getTypeColor(notification.type ?? 'system'),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // タイトルと情報
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // タイトル
                          Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // タイムスタンプとタイプ
                          Row(
                            children: [
                              Text(
                                _formatTimestamp(notification.timestamp),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.black38,
                                      fontSize: 12,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              if (notification.type != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(
                                      notification.type!,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getTypeColor(
                                        notification.type!,
                                      ).withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _getTypeLabel(notification.type!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _getTypeColor(notification.type!),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 未読バッジ
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // 矢印アイコン
                    Icon(Icons.chevron_right, color: Colors.black38, size: 20),
                  ],
                ),
              ),
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

  /// 通知の既読状態を判定する（read_byサブコレクション対応）
  bool _isNotificationRead(notification_model.Notification notification) {
    if (notification.userId != null) {
      // ユーザー個別通知の場合は直接isReadをチェック
      return notification.isRead;
    } else {
      // 全ユーザー向け通知の場合はread_byサブコレクションの状態をチェック
      return _globalNotificationReadStatus[notification.id] ?? false;
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

class _CreateNotificationDialog extends ConsumerStatefulWidget {
  final VoidCallback onNotificationCreated;

  const _CreateNotificationDialog({required this.onNotificationCreated});

  @override
  ConsumerState<_CreateNotificationDialog> createState() =>
      _CreateNotificationDialogState();
}

class _CreateNotificationDialogState
    extends ConsumerState<_CreateNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'system';
  bool _isGlobalNotification = true;
  bool _isLoading = false;

  final List<Map<String, String>> _notificationTypes = [
    {'value': 'system', 'label': 'システム'},
    {'value': 'chat', 'label': 'チャット'},
    {'value': 'update', 'label': 'アップデート'},
    {'value': 'security', 'label': 'セキュリティ'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = FirestoreService();

      if (_isGlobalNotification) {
        // 全ユーザー向け通知
        await firestoreService.createGlobalNotification(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: _selectedType,
        );
      } else {
        // 現在のユーザー向け通知
        final authState = ref.read(authStatusProvider);
        await authState.whenData((authResult) async {
          if (authResult.user != null) {
            await firestoreService.createUserNotification(
              userId: authResult.user!.uid,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              type: _selectedType,
            );
          }
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通知を作成しました'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onNotificationCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通知の作成に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新しい通知を作成'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 通知タイプ選択
              Text('通知タイプ', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _notificationTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 通知範囲選択
              Text('通知範囲', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('全ユーザー'),
                      value: true,
                      groupValue: _isGlobalNotification,
                      onChanged: (value) {
                        setState(() {
                          _isGlobalNotification = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('自分だけ'),
                      value: false,
                      groupValue: _isGlobalNotification,
                      onChanged: (value) {
                        setState(() {
                          _isGlobalNotification = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // タイトル入力
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                  hintText: '通知のタイトルを入力してください',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 内容入力
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                  hintText: '通知の内容を入力してください',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '内容を入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createNotification,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('作成'),
        ),
      ],
    );
  }
}
