import 'package:firebase_auth/firebase_auth.dart';

/// User model representing the authenticated user
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final List<String>? specialties;
  final bool? trackingEnabled;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.isEmailVerified,
    this.createdAt,
    this.lastSignInAt,
    this.specialties,
    this.trackingEnabled,
  });

  /// Create UserModel from Firebase User
  factory UserModel.fromFirebaseUser(
    User user, {
    List<String>? specialties,
    bool? trackingEnabled,
  }) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
      lastSignInAt: user.metadata.lastSignInTime,
      specialties: specialties,
      trackingEnabled: trackingEnabled,
    );
  }

  /// Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastSignInAt,
    List<String>? specialties,
    bool? trackingEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      specialties: specialties ?? this.specialties,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, isEmailVerified: $isEmailVerified, specialties: $specialties, trackingEnabled: $trackingEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoURL == photoURL &&
        other.isEmailVerified == isEmailVerified &&
        other.trackingEnabled == trackingEnabled &&
        _listEquals(other.specialties, specialties);
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        photoURL.hashCode ^
        isEmailVerified.hashCode ^
        trackingEnabled.hashCode ^
        specialties.hashCode;
  }

  /// Create UserModel from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : null,
      lastSignInAt: data['lastSignInAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSignInAt'] as int)
          : null,
      specialties: data['specialties'] != null
          ? List<String>.from(data['specialties'] as List)
          : null,
      trackingEnabled: data['trackingEnabled'] as bool?,
    );
  }

  /// Convert UserModel to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastSignInAt': lastSignInAt?.millisecondsSinceEpoch,
      'specialties': specialties,
      'trackingEnabled': trackingEnabled,
    };
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
