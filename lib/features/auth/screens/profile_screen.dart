import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // 加載用戶數據
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (mounted) {
        setState(() {
          _userModel = userModel;
          if (userModel != null && userModel.nickname != null) {
            _nicknameController.text = userModel.nickname!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加載用戶數據失敗: $e';
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

  // 更新暱稱
  Future<void> _updateNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() {
        _errorMessage = '請輸入暱稱';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.saveNickname(nickname);
      await _loadUserData(); // 重新加載用戶數據
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暱稱更新成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '更新暱稱失敗: $e';
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

  // 登出
  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // 返回上一頁
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '登出失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 用戶頭像
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 用戶信息卡片
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 用戶名稱
                          if (_userModel != null) ...[  
                            const Text(
                              '用戶信息',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Divider(),
                            const SizedBox(height: 10),
                            
                            // 顯示名稱
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 20),
                                const SizedBox(width: 10),
                                const Text('顯示名稱:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                Text(_userModel!.displayName ?? '未設置'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            
                            // 電子郵件
                            if (_userModel!.email != null) ...[  
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 20),
                                  const SizedBox(width: 10),
                                  const Text('電子郵件:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 5),
                                  Text(_userModel!.email!),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            
                            // 用戶角色
                            Row(
                              children: [
                                const Icon(Icons.admin_panel_settings_outlined, size: 20),
                                const SizedBox(width: 10),
                                const Text('用戶角色:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                Text(_getRoleText(_userModel!.role)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            
                            // 帳號類型
                            Row(
                              children: [
                                const Icon(Icons.account_circle_outlined, size: 20),
                                const SizedBox(width: 10),
                                const Text('帳號類型:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                Text(_userModel!.isAnonymous ? '匿名帳號' : '正式帳號'),
                              ],
                            ),
                          ] else ...[  
                            const Text('未登入或使用暱稱模式'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 暱稱設置
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '暱稱設置',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          const Text('設置或更新您的暱稱：'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nicknameController,
                            decoration: const InputDecoration(
                              labelText: '暱稱',
                              hintText: '請輸入您的暱稱',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.edit),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _updateNickname,
                            icon: const Icon(Icons.save),
                            label: const Text('保存暱稱'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 帳號操作
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '帳號操作',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          if (_authService.isUserLoggedIn()) ...[  
                            OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('登出'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ] else ...[  
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              icon: const Icon(Icons.login),
                              label: const Text('前往登入'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

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

  // 獲取角色文字描述
  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '管理員';
      case UserRole.referee:
        return '裁判';
      case UserRole.viewer:
        return '觀眾';
      case UserRole.anonymous:
        return '匿名用戶';
      default:
        return '未知角色';
    }
  }
}