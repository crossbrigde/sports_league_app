import 'package:flutter/material.dart';
import 'package:sports_league_app/core/models/tournament.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/tournament_service.dart';
import '../../core/services/tournament_bracket_service.dart';
import '../../features/tournament/tournament_detail_page.dart';

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({super.key});

  @override
  State<CreateMatchPage> createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  final _tournamentService = TournamentService();
  final _bracketService = TournamentBracketService();
  final _formKey = GlobalKey<FormState>();
  String tournamentName = '';
  bool isPointTimeSystem = false;
  bool isTimeSystem = false;
  int targetPoints = 0;
  int matchMinutes = 0;
  bool isSingleElimination = false;
  int numPlayers = 8; // 預設參賽人數

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立賽程'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '大賽名稱',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入大賽名稱';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        tournamentName = value ?? '';
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    const SizedBox(height: 20),
                    const Text('賽制選擇', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('單淘汰賽'),
                      value: isSingleElimination,
                      onChanged: (bool? value) {
                        setState(() {
                          isSingleElimination = value ?? false;
                        });
                      },
                    ),
                    if (isSingleElimination) ...[  
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('參賽人數 (4-16人)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '請輸入4-16之間的數字',
                              ),
                              initialValue: numPlayers.toString(),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '請輸入參賽人數';
                                }
                                final number = int.tryParse(value);
                                if (number == null) {
                                  return '請輸入有效的數字';
                                }
                                if (number < 4 || number > 16) {
                                  return '參賽人數必須在4到16人之間';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                numPlayers = int.tryParse(value ?? '') ?? 8;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            
                            try {
                              if (isSingleElimination) {
                                // 顯示詳細的單淘汰賽設定對話框
                                _showSingleEliminationDialog();
                              } else {
                                // 創建常規賽程
                                final tournament = Tournament(
                                  id: const Uuid().v4(),
                                  name: tournamentName,
                                  type: 'regular',
                                  createdAt: DateTime.now(),
                                  targetPoints: isPointTimeSystem ? targetPoints : null,
                                  matchMinutes: (isPointTimeSystem || isTimeSystem) ? matchMinutes : null,
                                  status: 'ongoing',
                                );
                                
                                await _tournamentService.saveTournament(tournament);
                                
                                if (!mounted) return;
                                
                                // 顯示成功消息並提供選項
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('常規賽程創建成功！'),
                                    content: Text('賽程「$tournamentName」已成功創建'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pop(context); // 返回上一頁
                                        },
                                        child: const Text('返回'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TournamentDetailPage(
                                                tournamentId: tournament.id,
                                                tournamentName: tournament.name,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('進入賽程'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              // 顯示錯誤消息
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('創建賽程失敗: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('創建賽程'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSingleEliminationDialog() {
    int dialogNumPlayers = numPlayers; // 直接使用 numPlayers 變量
    List<String> playerNames = [];
    bool randomPairing = false;
    int? targetPoints;
    int? matchMinutes;

    void initializePlayerNames() {
      playerNames = List.generate(dialogNumPlayers, (index) => 'PLAYER${index + 1}');
    }
    initializePlayerNames();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('單淘汰賽詳細設定'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('請設定參賽人數和比賽規則'),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '參賽人數',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: dialogNumPlayers.toString(),
                    onChanged: (value) {
                      final newNumPlayers = int.tryParse(value) ?? 8;
                      if (newNumPlayers != dialogNumPlayers && newNumPlayers >= 4 && newNumPlayers <= 16) {
                        setState(() {
                          dialogNumPlayers = newNumPlayers;
                          initializePlayerNames();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 選手名稱輸入區域
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '選手名稱設定',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: dialogNumPlayers,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: '選手 ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  initialValue: playerNames[index],
                                  onChanged: (value) {
                                    playerNames[index] = value.trim().isEmpty 
                                        ? 'PLAYER${index + 1}' 
                                        : value.trim();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 隨機配對選項
                  Row(
                    children: [
                      Checkbox(
                        value: randomPairing,
                        onChanged: (value) {
                          setState(() {
                            randomPairing = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('隨機配對（在不違反輪空原則下隨機分配比賽場次）'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '目標分數 (可選)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      targetPoints = int.tryParse(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '比賽時間 (分鐘, 可選)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      matchMinutes = int.tryParse(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _createSingleEliminationTournament(
                  numPlayers: dialogNumPlayers,
                  targetPoints: targetPoints,
                  matchMinutes: matchMinutes,
                  playerNames: playerNames,
                  randomPairing: randomPairing,
                );
              },
              child: const Text('創建'),
            ),
          ],
        ),
      ),
    );
  }

  // 創建單淘汰賽
  Future<void> _createSingleEliminationTournament({
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
    List<String>? playerNames,
    bool randomPairing = false,
  }) async {
    try {
      print('_createSingleEliminationTournament - 檢查參數:');
      print('- numPlayers: $numPlayers');
      print('- targetPoints: $targetPoints');
      print('- matchMinutes: $matchMinutes');
      print('- playerNames: $playerNames');
      print('- randomPairing: $randomPairing');
      print('- tournamentName: $tournamentName');

      // 調用服務創建單淘汰賽（包含所有參數）
      final tournament = await _bracketService.createSingleEliminationTournament(
        name: tournamentName,
        numPlayers: numPlayers,
        targetPoints: targetPoints,
        matchMinutes: matchMinutes,
        playerNames: playerNames,
        randomPairing: randomPairing,
      );

      if (mounted) {
        // 顯示成功消息並提供選項
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('單淘汰賽創建成功！'),
            content: Text('賽程「$tournamentName」已成功創建'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 關閉對話框
                  Navigator.pop(context); // 返回上一頁
                },
                child: const Text('返回'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 關閉對話框
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TournamentDetailPage(
                        tournamentId: tournament.id,
                        tournamentName: tournament.name,
                      ),
                    ),
                  );
                },
                child: const Text('進入賽程'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('創建單淘汰賽時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('創建單淘汰賽失敗: $e')),
        );
      }
    }
  }
}