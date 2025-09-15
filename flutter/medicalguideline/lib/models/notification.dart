import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? userId; // 通知の送信先ユーザーID
  final String? type; // 通知の種類（例：chat, system, update等）
  final Map<String, dynamic>? data; // 追加のデータ

  Notification({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.userId,
    this.type,
    this.data,
  });

  // 新しい通知を作成するファクトリコンストラクタ
  factory Notification.create({
    required String title,
    required String content,
    String? userId,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      timestamp: DateTime.now(),
      userId: userId,
      type: type,
      data: data,
    );
  }

  // Firestoreから読み込むためのファクトリコンストラクタ
  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      timestamp: (json['timestamp'] is Timestamp)
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
                DateTime(1970),
      isRead: json['isRead'] ?? false,
      userId: json['userId'] as String?,
      type: json['type'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  // Firestoreに保存するためのメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'userId': userId,
      'type': type,
      'data': data,
    };
  }

  // 既読状態を変更するメソッド
  Notification copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? userId,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }

  // 通知を既読にする
  Notification markAsRead() {
    return copyWith(isRead: true);
  }

  // 通知を未読にする
  Notification markAsUnread() {
    return copyWith(isRead: false);
  }

  @override
  String toString() {
    return 'Notification{id: $id, title: $title, isRead: $isRead, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
