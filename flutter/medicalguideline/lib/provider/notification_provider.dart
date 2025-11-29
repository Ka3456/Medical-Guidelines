import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// 未読通知数を取得するProvider
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  debugPrint('🔍 [Provider] unreadNotificationCountProvider: 開始');
  final authState = ref.watch(authStatusProvider);

  return authState.when(
    data: (authResult) {
      debugPrint('🔍 [Provider] unreadNotificationCountProvider: 認証状態確認 - user=${authResult.user?.uid}');
      if (authResult.user != null) {
        final firestoreService = FirestoreService();

        debugPrint('🔍 [Provider] unreadNotificationCountProvider: Stream作成開始 - uid=${authResult.user!.uid}');
        // 通知一覧のStreamから未読数を計算
        return firestoreService
            .getUserNotificationsStream(authResult.user!.uid)
            .asyncMap((notifications) async {
              debugPrint('🔍 [Provider] unreadNotificationCountProvider: 通知受信 - ${notifications.length}件');
              int unreadCount = 0;

              for (final notification in notifications) {
                // ユーザー個別通知の場合は直接isReadをチェック
                if (notification.userId != null) {
                  if (!notification.isRead) {
                    unreadCount++;
                  }
                } else {
                  // 全ユーザー向け通知の場合はread_byサブコレクションをチェック
                  final isRead = await firestoreService
                      .isGlobalNotificationRead(
                        authResult.user!.uid,
                        notification.id,
                      );
                  if (!isRead) {
                    unreadCount++;
                  }
                }
              }

              debugPrint('🔍 [Provider] unreadNotificationCountProvider: 未読数計算完了 - $unreadCount件');
              return unreadCount;
            });
      }
      debugPrint('🔍 [Provider] unreadNotificationCountProvider: ユーザー未認証のため0を返す');
      return Stream.value(0);
    },
    loading: () {
      debugPrint('🔍 [Provider] unreadNotificationCountProvider: 認証状態loading');
      return Stream.value(0);
    },
    error: (e, st) {
      debugPrint('❌ [Provider] unreadNotificationCountProvider: 認証状態エラー - $e');
      return Stream.value(0);
    },
  );
});

/// 通知の一覧を取得するProvider
final notificationsProvider = StreamProvider.family<List, String>((
  ref,
  userId,
) {
  final firestoreService = FirestoreService();
  return firestoreService.getUserNotificationsStream(userId);
});

/// 通知の未読状態を管理するProvider
final notificationReadStateProvider =
    StateNotifierProvider<NotificationReadStateNotifier, Map<String, bool>>((
      ref,
    ) {
      return NotificationReadStateNotifier();
    });

class NotificationReadStateNotifier extends StateNotifier<Map<String, bool>> {
  NotificationReadStateNotifier() : super({});

  void markAsRead(String notificationId) {
    state = {...state, notificationId: true};
  }

  void markAsUnread(String notificationId) {
    state = {...state, notificationId: false};
  }

  bool isRead(String notificationId) {
    return state[notificationId] ?? false;
  }

  void clear() {
    state = {};
  }
}
