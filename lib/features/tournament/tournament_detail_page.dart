import 'package:flutter/material.dart';
import '../match/match_setup_page.dart';
import '../match/ongoing_matches_page.dart';
import '../../core/models/tournament.dart';
import '../../core/services/tournament_bracket_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentDetailPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentDetailPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  final TournamentBracketService _bracketService = TournamentBracketService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Tournament? _tournament;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  Future<void> _loadTournament() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await _firestore.collection('tournaments').doc(widget.tournamentId).get();
      if (doc.exists) {
        setState(() {
          _tournament = Tournament.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        setState(() {
          _tournament = Tournament(
            id: widget.tournamentId,
            name: widget.tournamentName,
            type: 'regular',
            createdAt: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('載入賽程時發生錯誤: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.tournamentName),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tournament = _tournament!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournamentName),
      ),
      body: Column(
        children: [
          // 上半部：進行中賽程
          Expanded(
            flex: 1,
            child: OngoingMatchesPage(tournamentId: widget.tournamentId),  // 添加 tournamentId 參數
          ),
          // 下半部：比賽設置
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '賽程管理',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (tournament.type == 'single_elimination') 
                      _buildTournamentBracketInfo(tournament)
                    else
                      _buildRegularTournamentInfo(tournament),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 顯示創建單淘汰賽對話框
  void _showCreateSingleEliminationDialog() {
    int numPlayers = 8;
    int? targetPoints;
    int? matchMinutes;
    List<String> playerNames = [];
    bool randomPairing = false;

    // 初始化選手名稱列表
    void _initializePlayerNames() {
      playerNames = List.generate(numPlayers, (index) => 'PLAYER${index + 1}');
    }
    _initializePlayerNames();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('創建單淘汰賽'),
          content: SingleChildScrollView(
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
                  initialValue: numPlayers.toString(),
                  onChanged: (value) {
                    final newNumPlayers = int.tryParse(value) ?? 8;
                    if (newNumPlayers != numPlayers) {
                      setState(() {
                        numPlayers = newNumPlayers;
                        _initializePlayerNames();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // 動態選手名稱輸入區域
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
                        height: 200, // 限制高度，避免對話框過大
                        child: ListView.builder(
                          itemCount: numPlayers,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: '選手 ${index + 1}',
                                  border: const OutlineInputBorder(),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _createSingleEliminationTournament(
                  numPlayers: numPlayers,
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
      setState(() {
        _isLoading = true;
      });

      print('_createSingleEliminationTournament - 檢查參數:');
      print('- numPlayers: $numPlayers');
      print('- targetPoints: $targetPoints');
      print('- matchMinutes: $matchMinutes');
      print('- playerNames: $playerNames');
      print('- randomPairing: $randomPairing');
      print('- tournamentName: ${_tournament?.name ?? widget.tournamentName}');

      // 調用服務創建單淘汰賽（包含所有參數）
      await _bracketService.createSingleEliminationTournament(
        name: _tournament?.name ?? widget.tournamentName,
        numPlayers: numPlayers,
        targetPoints: targetPoints,
        matchMinutes: matchMinutes,
        playerNames: playerNames,
        randomPairing: randomPairing,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('單淘汰賽創建成功！')),
        );
        _loadTournament();
      }
    } catch (e) {
      print('創建單淘汰賽時發生錯誤: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('創建失敗：$e')),
        );
      }
    }
  }

  // 構建常規賽程信息顯示
  Widget _buildRegularTournamentInfo(Tournament tournament) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('matches')
          .where('tournamentId', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('錯誤: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final matches = snapshot.data!.docs;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('常規賽程', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('賽程狀態: ${_getStatusText(tournament.status)}'),
            const SizedBox(height: 16),
            if (matches.isNotEmpty) ...[
               Text('比賽列表 (${matches.length} 場比賽):', style: const TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               ...matches.map((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
                 final status = basicInfo['status'] ?? data['status'] ?? 'pending';
                 final redPlayer = basicInfo['redPlayer'] ?? data['redPlayer'] ?? '待定';
                 final bluePlayer = basicInfo['bluePlayer'] ?? data['bluePlayer'] ?? '待定';
                 
                 return Card(
                   margin: const EdgeInsets.only(bottom: 8),
                   child: ListTile(
                     title: Text('$redPlayer vs $bluePlayer'),
                     subtitle: Text('狀態: ${_getStatusText(status)}'),
                     trailing: Icon(
                       _getStatusIcon(status),
                       color: _getStatusColor(status),
                     ),
                   ),
                 );
               }).toList(),
               const SizedBox(height: 16),
             ] else ...[
               const Text('尚未創建比賽'),
               const SizedBox(height: 16),
             ],
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchSetupPage(
                      tournament: tournament,
                    ),
                  ),
                );
              },
              child: const Text('設置新比賽'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showCreateSingleEliminationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('創建單淘汰賽'),
            ),
          ],
        );
      },
    );
  }

  // 構建賽程結構信息顯示
  Widget _buildTournamentBracketInfo(Tournament tournament) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('matches')
          .where('tournamentId', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('錯誤: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final matches = <String, dynamic>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // 從 basic_info 中提取狀態和選手信息
          final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
          matches[doc.id] = {
            ...data,
            'status': basicInfo['status'] ?? data['status'] ?? 'pending',
            'redPlayer': basicInfo['redPlayer'] ?? data['redPlayer'] ?? '待定',
            'bluePlayer': basicInfo['bluePlayer'] ?? data['bluePlayer'] ?? '待定',
          };
        }

        if (matches.isEmpty) {
          return const Text('尚未生成比賽');
        }

        final numPlayers = matches.values
            .map((m) => [m['redPlayer'], m['bluePlayer']])
            .expand((players) => players)
            .where((player) => player != null && player != '' && player != '待定')
            .toSet()
            .length;

        final rounds = matches.values
            .map((m) => m['round'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('單淘汰賽 - $numPlayers 人參賽', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('共 ${numPlayers - 1} 場比賽，${rounds} 輪賽程'),
            const SizedBox(height: 16),
            const Text('賽程狀態：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildRoundStatus(matches),
            const SizedBox(height: 16),
            _buildMatchesList(matches),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchSetupPage(
                      tournament: tournament,
                    ),
                  ),
                );
              },
              child: const Text('查看比賽詳情'),
            ),
          ],
        );
      },
    );
  }

  // 構建輪次狀態顯示
  Widget _buildRoundStatus(Map<String, dynamic> matches) {
    // 按輪次分組
    final matchesByRound = <int, List<Map<String, dynamic>>>{};
    
    matches.forEach((id, data) {
      final round = data['round'] as int? ?? 0;
      if (!matchesByRound.containsKey(round)) {
        matchesByRound[round] = [];
      }
      matchesByRound[round]!.add({...data, 'id': id});
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: matchesByRound.entries.map((entry) {
        final round = entry.key;
        final roundMatches = entry.value;
        
        // 計算該輪次的進行中和已完成比賽數量
        final ongoingCount = roundMatches.where((m) => m['status'] == 'ongoing').length;
        final completedCount = roundMatches.where((m) => m['status'] == 'completed').length;
        final totalCount = roundMatches.length;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Text('第 $round 輪：', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('$completedCount/$totalCount 已完成', 
                style: TextStyle(
                  color: completedCount == totalCount ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ongoingCount > 0) ...[  
                const SizedBox(width: 8),
                Text('$ongoingCount 場進行中', 
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // 構建比賽列表
  Widget _buildMatchesList(Map<String, dynamic> matches) {
    // 按輪次分組
    final matchesByRound = <int, List<Map<String, dynamic>>>{};
    
    matches.forEach((id, data) {
      final round = data['round'] as int? ?? 0;
      if (!matchesByRound.containsKey(round)) {
        matchesByRound[round] = [];
      }
      matchesByRound[round]!.add({...data, 'id': id});
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('比賽詳情：', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...matchesByRound.entries.map((entry) {
          final round = entry.key;
          final roundMatches = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('第 $round 輪', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...roundMatches.map((match) {
                final matchId = match['id'];
                final status = match['status'] ?? 'pending';
                final redPlayer = match['redPlayer'] ?? '待定';
                final bluePlayer = match['bluePlayer'] ?? '待定';
                final matchNumber = match['matchNumber'] ?? 0;
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text('M$matchNumber: $redPlayer vs $bluePlayer'),
                    subtitle: Text('狀態: ${_getStatusText(status)}'),
                    trailing: status == 'pending' && redPlayer != '待定' && bluePlayer != '待定'
                        ? ElevatedButton(
                            onPressed: () => _startMatch(matchId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('開始比賽'),
                          )
                        : status == 'ongoing'
                            ? const Icon(Icons.play_circle, color: Colors.blue)
                            : status == 'completed'
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                    onTap: round == 1 ? () => _editPlayerNames(matchId, redPlayer, bluePlayer) : null,
                  ),
                );
              }).toList(),
            ],
          );
        }).toList(),
      ],
    );
  }

  // 獲取狀態文字
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '等待中';
      case 'ongoing':
        return '進行中';
      case 'completed':
        return '已完成';
      case 'setup':
        return '設置中';
      case 'active':
        return '進行中';
      case 'finished':
        return '已結束';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'ongoing':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'setup':
        return Icons.settings;
      case 'active':
        return Icons.play_arrow;
      case 'finished':
        return Icons.flag;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'setup':
        return Colors.grey;
      case 'active':
        return Colors.green;
      case 'finished':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // 手動開始比賽
  Future<void> _startMatch(String matchId) async {
    try {
      // 直接更新比賽狀態為ongoing
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .update({
        'basic_info.status': 'ongoing',
      });

      // 重新載入賽程
      await _loadTournament();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('比賽已開始！')),
        );
      }
    } catch (e) {
      print('開始比賽時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('開始比賽失敗: $e')),
        );
      }
    }
  }

  // 編輯選手名稱
  Future<void> _editPlayerNames(String matchId, String currentRedPlayer, String currentBluePlayer) async {
    final redController = TextEditingController(text: currentRedPlayer == '待定' ? '' : currentRedPlayer);
    final blueController = TextEditingController(text: currentBluePlayer == '待定' ? '' : currentBluePlayer);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編輯選手名稱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: redController,
              decoration: const InputDecoration(
                labelText: '紅方選手',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: blueController,
              decoration: const InputDecoration(
                labelText: '藍方選手',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRedPlayer = redController.text.trim().isEmpty ? '待定' : redController.text.trim();
              final newBluePlayer = blueController.text.trim().isEmpty ? '待定' : blueController.text.trim();
              
              try {
                // 更新比賽中的選手名稱
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(matchId)
                    .update({
                  'basic_info.redPlayer': newRedPlayer,
                  'basic_info.bluePlayer': newBluePlayer,
                  'redPlayer': newRedPlayer,
                  'bluePlayer': newBluePlayer,
                });

                // 更新所有後續比賽中的選手名稱
                await _updatePlayerNamesInTournament(currentRedPlayer, newRedPlayer);
                await _updatePlayerNamesInTournament(currentBluePlayer, newBluePlayer);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('選手名稱已更新！')),
                  );
                }
              } catch (e) {
                print('更新選手名稱時發生錯誤: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新失敗: $e')),
                  );
                }
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 更新整個賽程中的選手名稱
  Future<void> _updatePlayerNamesInTournament(String oldName, String newName) async {
    if (oldName == newName || oldName == '待定') return;

    try {
      // 查詢所有包含該選手的比賽
      final redPlayerMatches = await FirebaseFirestore.instance
          .collection('matches')
          .where('tournamentId', isEqualTo: widget.tournamentId)
          .where('basic_info.redPlayer', isEqualTo: oldName)
          .get();

      final bluePlayerMatches = await FirebaseFirestore.instance
          .collection('matches')
          .where('tournamentId', isEqualTo: widget.tournamentId)
          .where('basic_info.bluePlayer', isEqualTo: oldName)
          .get();

      // 批次更新
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in redPlayerMatches.docs) {
        batch.update(doc.reference, {
          'basic_info.redPlayer': newName,
          'redPlayer': newName,
        });
      }

      for (var doc in bluePlayerMatches.docs) {
        batch.update(doc.reference, {
          'basic_info.bluePlayer': newName,
          'bluePlayer': newName,
        });
      }

      await batch.commit();
    } catch (e) {
      print('更新賽程中選手名稱時發生錯誤: $e');
    }
  }
}