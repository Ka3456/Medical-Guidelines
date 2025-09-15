import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String summary;
  final bool showSummary;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final bool isDelete;

  ChatRoom({
    required this.id,
    required this.summary,
    this.showSummary = true,
    required this.createdAt,
    this.metadata,
    this.isDelete = false,
  });

  factory ChatRoom.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return ChatRoom(
      id: snapshot.id,
      summary: data?['summary'] ?? '',
      showSummary: data?['showSummary'] ?? true,
      createdAt: (data?['createdAt'] as Timestamp).toDate(),
      metadata: data?['metadata'],
      isDelete: data?['isDelete'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'summary': summary,
      'showSummary': showSummary,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDelete': isDelete,
      if (metadata != null) 'metadata': metadata,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? summary,
    bool? showSummary,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    bool? isDelete,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      summary: summary ?? this.summary,
      showSummary: showSummary ?? this.showSummary,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      isDelete: isDelete ?? this.isDelete,
    );
  }
}
