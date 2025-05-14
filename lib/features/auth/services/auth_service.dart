import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '757686243952-13if2k8aijod81i835b9ivk7ka3elnm5.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  final UserService _userService = UserService();

  // 獲取當前用戶
  User? get currentUser => _auth.currentUser;

  // 監聽用戶狀態變化
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google 登入
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 確保登出任何可能的先前登入，避免快取問題
      await _googleSignIn.signOut();
      
      // 觸發 Google 登入流程
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 獲取 Google 登入憑證
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 使用 Google 憑證登入 Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      
      // 創建或更新用戶資料
      if (userCredential.user != null) {
        await _userService.createUserModelFromFirebaseUser(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      print('Google 登入失敗: $e');
      return null;
    }
  }

  // 其他登入方法已移除，只保留 Google 登入

  // 登出
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 檢查用戶是否已登入
  bool isUserLoggedIn() {
    return currentUser != null;
  }

  // 檢查用戶是否為匿名用戶 (保留方法但永遠返回false，因為已移除匿名登入功能)
  bool isAnonymousUser() {
    return false;
  }

  // 獲取用戶顯示名稱
  String? getUserDisplayName() {
    return currentUser?.displayName;
  }

  // 獲取用戶電子郵件
  String? getUserEmail() {
    return currentUser?.email;
  }

  // 獲取用戶 UID
  String? getUserUid() {
    return currentUser?.uid;
  }
  
  // 獲取當前用戶的 UserModel
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;
    return await _userService.getUserByUid(currentUser!.uid);
  }
  
  // 更新用戶角色
  Future<UserModel?> updateUserRole(String uid, UserRole role) async {
    return await _userService.updateUserRole(uid, role);
  }
  
  // 保存用戶的暱稱
  Future<void> saveNickname(String nickname) async {

    if (currentUser != null) {
      await _userService.saveUserNickname(currentUser!.uid, nickname);
    }
  }
}