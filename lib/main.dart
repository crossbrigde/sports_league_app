import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/home/home_page.dart';

// 添加 Firebase 配置
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 为 Firebase 提供配置选项
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBdoKP9xvlN3xwl9Wl8rjUvEgzfkrQQwLk",  // 临时使用默认值，请替换为实际值
      projectId: "sports-league-app-d25e2",
      messagingSenderId: "757686243952",
      appId: "1:757686243952:web:123456789abcdef",  // 临时使用默认值，请替换为实际值
      databaseURL: "https://sports-league-app-d25e2-default-rtdb.asia-southeast1.firebasedatabase.app",
      authDomain: "sports-league-app-d25e2.firebaseapp.com",
      storageBucket: "sports-league-app-d25e2.appspot.com",
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '武術競賽記錄',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}