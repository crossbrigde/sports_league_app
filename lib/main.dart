import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/home/home_page.dart';
import 'core/services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'core/models/user_model.dart';

// 添加 Firebase 配置
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 为 Firebase 提供配置选项
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDlphPjw9Ivsl6Uo9h33Y10T-2LwoIRxpQ",  // 使用google-services.json中的API密鑰
      projectId: "sports-league-app-d25e2",
      messagingSenderId: "757686243952",
      appId: "1:757686243952:web:fe291194a5e7b463a3dab5",  // 使用firebase-config.js中的appId
      databaseURL: "https://sports-league-app-d25e2-default-rtdb.asia-southeast1.firebasedatabase.app",
      authDomain: "sports-league-app-d25e2.firebaseapp.com",
      storageBucket: "sports-league-app-d25e2.appspot.com",
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    // 監聽身份驗證狀態變化
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        // 獲取用戶模型
        final userModel = await _authService.getCurrentUserModel();
        setState(() {
          _userModel = userModel;
        });
      } else {
        setState(() {
          _userModel = null;
        });
      }
    });
  }

  // 顯示登入頁面
  Future<void> _showLoginScreen(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    // 處理登入結果
    if (result != null && result is Map) {
      setState(() {
        if (result.containsKey('userModel')) {
          _userModel = result['userModel'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '武術競賽記錄',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('武術競賽記錄'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              // 顯示登入狀態和操作按鈕
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: '個人資料',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              if (_authService.isUserLoggedIn())
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: '登出',
                  onPressed: () async {
                    await _authService.signOut();
                    setState(() {
                      // 用戶登出時重置用戶模型
                      _userModel = null;
                    });
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.login),
                  tooltip: '登入',
                  onPressed: () => _showLoginScreen(context),
                )
            ],
          ),
          body: Column(
            children: [
              // 顯示用戶信息
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text(
                      _authService.isUserLoggedIn()
                          ? '${_authService.getUserDisplayName() ?? '用戶'} (${_authService.getUserEmail()})'
                          : '未登入',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    if (!_authService.isUserLoggedIn())
                      TextButton(
                        onPressed: () => _showLoginScreen(context),
                        child: const Text('點擊登入'),
                      ),
                  ],
                ),
              ),
              // 主頁內容
              const Expanded(child: HomePage()),
            ],
          ),
        ),
      ),
    );
  }
}