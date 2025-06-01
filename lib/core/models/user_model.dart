import 'package:firebase_auth/firebase_auth.dart';

// 用戶角色枚舉
enum UserRole {
  admin,    // 管理員
  referee,  // 裁判
  viewer,   // 觀眾
  anonymous // 匿名用戶
}

class UserModel {
  final String uid;
  String? email;
  String? displayName;
  String? nickname;
  String? photoURL;
  bool isAnonymous;
  DateTime? createdAt;
  DateTime? lastLoginAt;
  UserRole role;
  Map<String, dynamic>? additionalData;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.nickname,
    this.photoURL,
    this.isAnonymous = false,
    this.createdAt,
    this.lastLoginAt,
    this.role = UserRole.viewer,
    this.additionalData,
  });

  // 從 Firebase User 創建 UserModel
  factory UserModel.fromFirebaseUser(User user, {String? nickname, UserRole? role}) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      nickname: nickname,
      photoURL: user.photoURL,
      isAnonymous: user.isAnonymous,
      role: role ?? UserRole.viewer,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }
  
  // 匿名用戶創建方法已移除，只保留Google登入

  // 從 Map 創建 UserModel
  factory UserModel.fromMap(Map<String, dynamic> json) {
    // 處理角色字段
    UserRole userRole = UserRole.viewer;
    if (json['role'] != null) {
      String roleStr = json['role'].toString();
      switch (roleStr) {
        case 'admin':
          userRole = UserRole.admin;
          break;
        case 'referee':
          userRole = UserRole.referee;
          break;
        case 'anonymous':
          userRole = UserRole.anonymous;
          break;
        default:
          userRole = UserRole.viewer;
      }
    }
    
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      nickname: json['nickname'] as String?,
      photoURL: json['photoURL'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      role: userRole,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  // 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'nickname': nickname,
      'photoURL': photoURL,
      'isAnonymous': isAnonymous,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'additionalData': additionalData,
      'role': role.toString().split('.').last,
    };
  }
  
  // 轉換為 JSON (兼容性方法)
  Map<String, dynamic> toJson() {
    return toMap();
  }

  // 獲取顯示名稱
  String getDisplayName() {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    } else if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    } else if (email != null) {
      return email!.split('@').first;
    } else {
      return '用戶 $uid';
    }
  }

  // 創建副本並更新字段
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? nickname,
    String? photoURL,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    UserRole? role,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      photoURL: photoURL ?? this.photoURL,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      role: role ?? this.role,
      additionalData: additionalData ?? this.additionalData,
    );
  }
  
  // 更新最後登入時間
  UserModel updateLastLogin() {
    return copyWith(lastLoginAt: DateTime.now());
  }
  
  // 更新用戶角色
  UserModel updateRole(UserRole newRole) {
    return copyWith(role: newRole);
  }
}