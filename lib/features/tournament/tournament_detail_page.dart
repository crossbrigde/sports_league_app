import 'package:flutter/material.dart';
import '../match/match_setup_page.dart';
import '../match/ongoing_matches_page.dart';
import '../match/models/tournament.dart';
import 'services/tournament_bracket_service.dart';
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            onPressed: _showCreateTournamentDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('創建單淘汰賽'),
                          ),
                        ],
                      ),
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
  void _showCreateTournamentDialog() {
    int numPlayers = 8;
    int? targetPoints;
    int? matchMinutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  numPlayers = int.tryParse(value) ?? 8;
                },
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
              );
            },
            child: const Text('創建'),
          ),
        ],
      ),
    );
  }

  // 創建單淘汰賽
  Future<void> _createSingleEliminationTournament({
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
  }) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _bracketService.createSingleEliminationTournament(
        name: widget.tournamentName,
        numPlayers: numPlayers,
        targetPoints: targetPoints,
        matchMinutes: matchMinutes,
      );

      // 重新載入賽程
      await _loadTournament();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('單淘汰賽創建成功！')),
        );
      }
    } catch (e) {
      print('創建單淘汰賽時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('創建失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 構建賽程結構信息顯示
  Widget _buildTournamentBracketInfo(Tournament tournament) {
    final matches = tournament.matches;
    final numPlayers = tournament.numPlayers ?? 0;
    
    if (matches == null || matches.isEmpty) {
      return const Text('無賽程數據');
    }

    // 計算輪次數量
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
}