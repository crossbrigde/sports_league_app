import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // Google 登入
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.of(context).pop(true); // 登入成功，返回上一頁
      } else if (mounted) {
        setState(() {
          _errorMessage = '登入失敗，請重試';
        });
      }
    } catch (e) {
      print('Google 登入詳細錯誤: $e');
      if (mounted) {
        String errorMsg = '登入過程中發生錯誤';
        
        // 處理常見的Firebase錯誤
        if (e.toString().contains('api-key-not-valid')) {
          errorMsg = 'API密鑰無效，請聯繫開發人員';
        } else if (e.toString().contains('network-request-failed')) {
          errorMsg = '網絡連接失敗，請檢查您的網絡連接';
        } else if (e.toString().contains('popup-closed-by-user')) {
          errorMsg = '登入視窗被關閉，請重試';
        }
        
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 匿名登入和暱稱登入功能已移除，只保留Google登入

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登入'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // 應用程序標誌或圖像
                  Icon(
                    Icons.sports,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '歡迎使用體育聯盟應用',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '請使用Google帳號登入',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  // Google 登入按鈕
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('使用 Google 帳號登入'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 錯誤訊息
                  if (_errorMessage != null) ...[  
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.red.shade100,
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}