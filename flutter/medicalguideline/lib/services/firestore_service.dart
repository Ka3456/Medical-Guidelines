import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:medicalguideline/models/chat_message.dart';
import 'package:medicalguideline/models/chat_room.dart';
import 'package:medicalguideline/models/user_model.dart';
import 'package:medicalguideline/models/notification.dart';

/// ======= ここから本体：固定パスに統一した FirestoreService =======
/// 構造:
/// chat_rooms/{uid}/rooms/{roomId}
/// chat_rooms/{uid}/rooms/{roomId}/messages/{messageId}
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // ---------------- ユーザー ----------------
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('ユーザー作成失敗: $e');
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('ユーザー取得失敗: $e');
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('ユーザー更新失敗: $e');
    }
  }

  Future<void> updateUserTrackingPermission(String uid, bool enabled) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'trackingEnabled': enabled,
        'trackingPermissionUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('トラッキング設定更新失敗: $e');
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      // ユーザーの基本情報を削除
      await _firestore.collection('users').doc(uid).delete();

      // ユーザーのチャットルームとメッセージを一括削除
      final userDoc = _firestore.collection('chat_rooms').doc(uid);
      final rooms = await userDoc.collection('rooms').get();

      final batch = _firestore.batch();
      for (final room in rooms.docs) {
        // 各ルームのメッセージを削除
        final messages = await room.reference.collection('messages').get();
        for (final message in messages.docs) {
          batch.delete(message.reference);
        }
        // ルーム自体を削除
        batch.delete(room.reference);
      }

      // ユーザーのチャットルームドキュメント自体も削除
      batch.delete(userDoc);

      await batch.commit();
    } catch (e) {
      throw Exception('ユーザー削除失敗: $e');
    }
  }

  // ---------------- チャットルーム ----------------

  /// ルーム作成（戻り値: roomId）
  Future<String> createChatRoom(String uid, ChatRoom roomDraft) async {
    try {
      final col = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms');
      final docRef = await col.add(roomDraft.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('チャットルーム作成失敗: $e');
    }
  }

  /// ルーム作成（IDを指定）
  Future<void> createChatRoomWithId(
    String uid,
    String roomId,
    ChatRoom roomDraft,
  ) async {
    try {
      final docRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId);
      await docRef.set(roomDraft.toFirestore());
    } catch (e) {
      throw Exception('チャットルーム作成失敗: $e');
    }
  }

  /// ルーム単体取得（存在しなければ null）
  Future<ChatRoom?> getChatRoom(String uid, String roomId) async {
    try {
      final doc = await _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!doc.exists || doc.data() == null) return null;

      // あなたの ChatRoom モデルにある fromFirestore を使う
      return ChatRoom.fromFirestore(
        doc, // DocumentSnapshot<Map<String, dynamic>>
        null,
      );
    } catch (e) {
      throw Exception('チャットルーム取得失敗: $e');
    }
  }

  /// ルーム一覧を一度だけ取得（新しい順、削除されていないもののみ）
  Future<List<ChatRoom>> getUserChatRoomsOnce(String uid, {int? limit}) async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        q = q.limit(limit);
      }

      final snap = await q.get();

      // クライアント側でフィルタリング
      final filteredDocs = snap.docs.where((doc) {
        final data = doc.data();
        return data['isDelete'] != true; // isDeleteがtrueでないもの（falseまたはnull）
      }).toList();

      return filteredDocs.map((d) {
        return ChatRoom.fromFirestore(d, null);
      }).toList();
    } catch (e) {
      throw Exception('チャットルーム一覧取得失敗: $e');
    }
  }

  /// サマリー更新 & 更新時刻
  Future<void> updateChatRoomSummary(
    String uid,
    String roomId,
    String summary,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .update({
            'summary': summary,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('サマリー更新失敗: $e');
    }
  }

  /// ルーム論理削除（isDelete=trueにする）
  Future<void> softDeleteChatRoom(String uid, String roomId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .update({
            'isDelete': true,
            'deletedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('チャットルーム論理削除失敗: $e');
    }
  }

  /// ルーム物理削除（メッセージ込みで一括削除）
  Future<void> deleteChatRoom(String uid, String roomId) async {
    try {
      final roomRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId);

      // メッセージ削除（バッチ）
      final msgs = await roomRef.collection('messages').get();
      final batch = _firestore.batch();
      for (final m in msgs.docs) {
        batch.delete(m.reference);
      }
      batch.delete(roomRef);
      await batch.commit();
    } catch (e) {
      throw Exception('チャットルーム削除失敗: $e');
    }
  }

  // ---------------- メッセージ ----------------

  /// 1件保存（追記）
  Future<void> saveChatMessage(
    String uid,
    String roomId,
    ChatMessage message,
  ) async {
    try {
      final msgRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(message.id);

      final batch = _firestore.batch();
      batch.set(msgRef, message.toJson());
      // ルームの lastMessageAt / updatedAt を更新
      final roomRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId);
      batch.update(roomRef, {
        'lastMessageAt': Timestamp.fromDate(message.timestamp),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      throw Exception('メッセージ保存失敗: $e');
    }
  }

  /// 複数一括保存
  Future<void> saveChatRoomMessages(
    String uid,
    String roomId,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return;
    try {
      final batch = _firestore.batch();
      DateTime? lastTs;

      for (final m in messages) {
        final ref = _firestore
            .collection('chat_rooms')
            .doc(uid)
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc(m.id);
        batch.set(ref, m.toJson());
        if (lastTs == null || m.timestamp.isAfter(lastTs)) {
          lastTs = m.timestamp;
        }
      }

      // ルーム更新
      final roomRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId);
      batch.update(roomRef, {
        if (lastTs != null) 'lastMessageAt': Timestamp.fromDate(lastTs),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('メッセージ一括保存失敗: $e');
    }
  }

  /// メッセージ一覧（1回だけ取得）
  Future<List<ChatMessage>> getChatMessagesOnce(
    String uid,
    String roomId, {
    int? limit,
    bool ascending = true,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: !ascending);
      if (limit != null) q = q.limit(limit);

      final snap = await q.get();
      return snap.docs.map((d) => ChatMessage.fromJson(d.data())).toList();
    } catch (e) {
      throw Exception('メッセージ取得失敗: $e');
    }
  }

  /// メッセージ削除（任意）
  Future<void> deleteMessage(
    String uid,
    String roomId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('メッセージ削除失敗: $e');
    }
  }

  // ---------------- 旧データの簡易移行（任意） ----------------
  /// 旧: chat_rooms/{uid}/{isoTimestamp}/{roomId} を
  /// 新: chat_rooms/{uid}/rooms/{roomId} へコピーするワンショット。
  /// クライアントSDKはサブコレ列挙が弱いので「直近数日 × 24h」を総当たりで拾う簡易版。
  Future<void> migrateOldRooms(String uid, {int lookbackDays = 7}) async {
    final userDoc = _firestore.collection('chat_rooms').doc(uid);

    final now = DateTime.now();
    for (int d = 0; d < lookbackDays; d++) {
      for (int h = 0; h < 24; h++) {
        final ts = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: d)).add(Duration(hours: h)).toIso8601String();

        try {
          final oldRooms = await userDoc.collection(ts).get();
          if (oldRooms.docs.isEmpty) continue;

          final batch = _firestore.batch();
          for (final old in oldRooms.docs) {
            final newRoomRef = userDoc.collection('rooms').doc(old.id);
            batch.set(newRoomRef, old.data(), SetOptions(merge: true));

            final oldMsgs = await old.reference.collection('messages').get();
            for (final m in oldMsgs.docs) {
              batch.set(
                newRoomRef.collection('messages').doc(m.id),
                m.data(),
                SetOptions(merge: true),
              );
            }
          }
          await batch.commit();
        } catch (_) {
          // 無い時間帯は無視
        }
      }
    }
  }

  // ---------------- 通知 ----------------

  /// 全ユーザー向け通知とユーザー個別通知を合算して取得
  /// notification_all と notification/{uid} の両方から取得
  Future<List<Notification>> getUserNotifications(
    String uid, {
    int? limit,
    bool ascending = false, // 新しい順（デフォルト）
  }) async {
    try {
      final List<Notification> allNotifications = [];

      // 1. 全ユーザー向け通知を取得 (notification_all)
      final globalQuery = _firestore
          .collection('notification_all')
          .orderBy('timestamp', descending: !ascending);

      final globalSnapshot = limit != null
          ? await globalQuery.limit(limit).get()
          : await globalQuery.get();

      for (final doc in globalSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // ドキュメントIDを追加
        allNotifications.add(Notification.fromJson(data));
      }

      // 2. ユーザー個別通知を取得 (notification/{uid})
      final userQuery = _firestore
          .collection('notification')
          .doc(uid)
          .collection('notifications')
          .orderBy('timestamp', descending: !ascending);

      final userSnapshot = limit != null
          ? await userQuery.limit(limit).get()
          : await userQuery.get();

      for (final doc in userSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // ドキュメントIDを追加
        allNotifications.add(Notification.fromJson(data));
      }

      // 3. タイムスタンプでソートして重複を除去
      allNotifications.sort((a, b) {
        if (ascending) {
          return a.timestamp.compareTo(b.timestamp);
        } else {
          return b.timestamp.compareTo(a.timestamp);
        }
      });

      // 4. IDで重複除去（同じ通知が両方にある場合）
      final uniqueNotifications = <String, Notification>{};
      for (final notification in allNotifications) {
        uniqueNotifications[notification.id] = notification;
      }

      final result = uniqueNotifications.values.toList();

      // 5. 再度ソート（重複除去後）
      result.sort((a, b) {
        if (ascending) {
          return a.timestamp.compareTo(b.timestamp);
        } else {
          return b.timestamp.compareTo(a.timestamp);
        }
      });

      // 6. リミット適用（合算後の結果に対して）
      if (limit != null && result.length > limit) {
        return result.take(limit).toList();
      }

      return result;
    } catch (e) {
      throw Exception('通知取得失敗: $e');
    }
  }

  /// 通知を既読にする
  Future<void> markNotificationAsRead(String uid, String notificationId) async {
    try {
      // ユーザー個別通知の場合
      final userNotificationRef = _firestore
          .collection('notification')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId);

      final userDoc = await userNotificationRef.get();
      if (userDoc.exists) {
        await userNotificationRef.update({'isRead': true});
        return;
      }

      // 全ユーザー向け通知の場合、ユーザーの既読状態を別途管理
      final userReadStatusRef = _firestore
          .collection('notification_all')
          .doc(notificationId)
          .collection('read_by')
          .doc(uid);

      await userReadStatusRef.set({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('通知既読更新失敗: $e');
    }
  }

  /// 複数通知を一括既読にする
  Future<void> markNotificationsAsRead(
    String uid,
    List<String> notificationIds,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final notificationId in notificationIds) {
        // ユーザー個別通知の場合
        final userNotificationRef = _firestore
            .collection('notification')
            .doc(uid)
            .collection('notifications')
            .doc(notificationId);

        final userDoc = await userNotificationRef.get();
        if (userDoc.exists) {
          batch.update(userNotificationRef, {'isRead': true});
        } else {
          // 全ユーザー向け通知の場合
          final userReadStatusRef = _firestore
              .collection('notification_all')
              .doc(notificationId)
              .collection('read_by')
              .doc(uid);

          batch.set(userReadStatusRef, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('通知一括既読更新失敗: $e');
    }
  }

  /// 全ユーザー向け通知の既読状態を取得
  Future<bool> isGlobalNotificationRead(
    String uid,
    String notificationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('notification_all')
          .doc(notificationId)
          .collection('read_by')
          .doc(uid)
          .get();

      return doc.exists && (doc.data()?['isRead'] ?? false);
    } catch (e) {
      return false; // エラーの場合は未読として扱う
    }
  }

  /// 未読通知数を取得
  Future<int> getUnreadNotificationCount(String uid) async {
    try {
      final notifications = await getUserNotifications(uid);
      int unreadCount = 0;

      for (final notification in notifications) {
        if (notification.isRead) {
          continue;
        }

        // 全ユーザー向け通知の場合は別途確認
        if (notification.userId == null) {
          final isRead = await isGlobalNotificationRead(uid, notification.id);
          if (!isRead) {
            unreadCount++;
          }
        } else {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      throw Exception('未読通知数取得失敗: $e');
    }
  }

  /// 通知のリアルタイムリスナー（Stream）
  Stream<List<Notification>> getUserNotificationsStream(
    String uid, {
    int? limit,
    bool ascending = false,
  }) {
    final globalStream = _firestore
        .collection('notification_all')
        .orderBy('timestamp', descending: !ascending)
        .snapshots();

    final userStream = _firestore
        .collection('notification')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: !ascending)
        .snapshots();

    // StreamControllerを使用して複数のStreamを結合
    final controller = StreamController<List<Notification>>();
    QuerySnapshot<Map<String, dynamic>>? globalSnapshot;
    QuerySnapshot<Map<String, dynamic>>? userSnapshot;

    void _emitCombinedNotifications() {
      if (globalSnapshot != null && userSnapshot != null) {
        final allNotifications = <Notification>[];

        // 全ユーザー向け通知
        for (final doc in globalSnapshot!.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          allNotifications.add(Notification.fromJson(data));
        }

        // ユーザー個別通知
        for (final doc in userSnapshot!.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          allNotifications.add(Notification.fromJson(data));
        }

        // ソートとリミット適用
        allNotifications.sort((a, b) {
          if (ascending) {
            return a.timestamp.compareTo(b.timestamp);
          } else {
            return b.timestamp.compareTo(a.timestamp);
          }
        });

        final result = limit != null && allNotifications.length > limit
            ? allNotifications.take(limit).toList()
            : allNotifications;

        controller.add(result);
      }
    }

    // 各Streamの変更を監視
    final globalSubscription = globalStream.listen((snapshot) {
      globalSnapshot = snapshot;
      _emitCombinedNotifications();
    });

    final userSubscription = userStream.listen((snapshot) {
      userSnapshot = snapshot;
      _emitCombinedNotifications();
    });

    // StreamControllerのクリーンアップ
    controller.onCancel = () {
      globalSubscription.cancel();
      userSubscription.cancel();
    };

    return controller.stream;
  }

  /// 通知を作成する（全ユーザー向け）
  Future<void> createGlobalNotification({
    required String title,
    required String content,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationData = {
        'title': title,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'userId': null, // 全ユーザー向けの場合はnull
        'type': type,
        'data': data,
      };

      await _firestore.collection('notification_all').add(notificationData);
      debugPrint('全ユーザー向け通知を作成しました: $title');
    } catch (e) {
      debugPrint('通知の作成に失敗しました: $e');
      rethrow;
    }
  }

  /// 通知を作成する（特定ユーザー向け）
  Future<void> createUserNotification({
    required String userId,
    required String title,
    required String content,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationData = {
        'title': title,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'userId': userId,
        'type': type,
        'data': data,
      };

      await _firestore
          .collection('notification')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
      debugPrint('ユーザー向け通知を作成しました: $title (ユーザー: $userId)');
    } catch (e) {
      debugPrint('通知の作成に失敗しました: $e');
      rethrow;
    }
  }

  /// 技術的問題を報告する
  Future<void> submitTechnicalIssue({
    required List<String> categories,
    required String title,
    required String description,
    String? stepsToReproduce,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ユーザーがログインしていません');
      }

      // タイムスタンプベースのドキュメントIDを作成（スラッシュをアンダースコアに変換）
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '_')
          .replaceAll('.', '_');

      final issueData = {
        'userId': user.uid,
        'userEmail': user.email,
        'categories': categories,
        'primaryCategory': categories.isNotEmpty ? categories.first : 'その他',
        'title': title,
        'description': description,
        'stepsToReproduce': stepsToReproduce ?? '',
        'status': 'open', // open, in_progress, resolved, closed
        'priority': 'medium', // low, medium, high, critical
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
        'appVersion': '1.0.0', // TODO: 実際のアプリバージョンを取得
      };

      // err_report コレクションにタイムスタンプをドキュメントIDとして保存
      await _firestore.collection('err_report').doc(timestamp).set(issueData);

      debugPrint('技術的問題を報告しました: $title (ドキュメントID: $timestamp)');
    } catch (e) {
      debugPrint('技術的問題の報告に失敗しました: $e');
      rethrow;
    }
  }

  // ---------------- メッセージ評価 ----------------
  /// メッセージの評価を更新
  Future<void> updateMessageRating(
    String uid,
    String roomId,
    String messageId,
    int? rating,
    String? comment,
  ) async {
    try {
      final messageRef = _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId);

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rating != null) {
        updateData['rating'] = rating;
      } else {
        updateData['rating'] = FieldValue.delete();
      }

      if (comment != null && comment.isNotEmpty) {
        updateData['comment'] = comment;
      } else {
        updateData['comment'] = FieldValue.delete();
      }

      await messageRef.update(updateData);
      debugPrint('メッセージの評価を更新しました: rating=$rating, comment=${comment ?? 'なし'}');
    } catch (e) {
      debugPrint('メッセージ評価の更新に失敗しました: $e');
      rethrow;
    }
  }

  /// メッセージの評価を取得
  Future<Map<String, dynamic>?> getMessageRating(
    String uid,
    String roomId,
    String messageId,
  ) async {
    try {
      final messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(uid)
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (messageDoc.exists && messageDoc.data() != null) {
        final data = messageDoc.data()!;
        return {'rating': data['rating'], 'comment': data['comment']};
      }
      return null;
    } catch (e) {
      debugPrint('メッセージ評価の取得に失敗しました: $e');
      return null;
    }
  }
}
