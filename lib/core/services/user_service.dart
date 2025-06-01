import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // 創建或更新用戶資料
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('創建或更新用戶失敗: $e');
      rethrow;
    }
  }

  // 根據 UID 獲取用戶資料
  Future<UserModel?> getUserByUid(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('獲取用戶資料失敗: $e');
      return null;
    }
  }

  // 從 Firebase User 創建或獲取用戶模型
  Future<UserModel> createUserModelFromFirebaseUser(firebase_auth.User firebaseUser, {String? nickname}) async {
    // 先嘗試從 Firestore 獲取現有用戶資料
    UserModel? existingUser = await getUserByUid(firebaseUser.uid);
    
    if (existingUser != null) {
      // 更新最後登入時間
      UserModel updatedUser = existingUser.updateLastLogin();
      await createOrUpdateUser(updatedUser);
      return updatedUser;
    } else {
      // 創建新用戶
      UserModel newUser = UserModel.fromFirebaseUser(
        firebaseUser,
        role: UserRole.viewer,
        nickname: nickname,
      );
      await createOrUpdateUser(newUser);
      return newUser;
    }
  }

  // 更新用戶角色
  Future<UserModel?> updateUserRole(String uid, UserRole newRole) async {
    try {
      UserModel? user = await getUserByUid(uid);
      if (user != null) {
        UserModel updatedUser = user.updateRole(newRole);
        await createOrUpdateUser(updatedUser);
        return updatedUser;
      }
      return null;
    } catch (e) {
      print('更新用戶角色失敗: $e');
      return null;
    }
  }

  // 獲取所有裁判用戶
  Future<List<UserModel>> getAllReferees() async {
    try {
      final querySnapshot = await _usersCollection
          .where('role', whereIn: ['referee', 'admin'])
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('獲取裁判列表失敗: $e');
      return [];
    }
  }

  // 保存用戶的暱稱
  Future<void> saveUserNickname(String uid, String nickname) async {
    try {
      await _usersCollection.doc(uid).update({'nickname': nickname});
    } catch (e) {
      print('保存暱稱失敗: $e');
      rethrow;
    }
  }

  // 將匿名帳號升級為正式帳號後更新用戶資料
  Future<void> updateUserAfterAnonymousUpgrade(String uid, firebase_auth.User firebaseUser) async {
    try {
      UserModel? existingUser = await getUserByUid(uid);
      if (existingUser != null) {
        // 保留原有暱稱，但更新其他資訊
        UserModel updatedUser = UserModel(
          uid: firebaseUser.uid,
          displayName: firebaseUser.displayName,
          email: firebaseUser.email,
          isAnonymous: false,
          role: UserRole.viewer, // 升級為正式觀眾角色
          nickname: existingUser.nickname,
          createdAt: existingUser.createdAt,
          lastLoginAt: DateTime.now(),
        );
        await createOrUpdateUser(updatedUser);
      }
    } catch (e) {
      print('更新匿名用戶資料失敗: $e');
      rethrow;
    }
  }
}