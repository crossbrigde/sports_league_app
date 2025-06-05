import 'package:flutter/material.dart';
import '../../core/services/match_service.dart';
import '../../core/services/tournament_service.dart';
import 'match_scoring_page.dart';
import '../../core/models/tournament.dart';
import '../../core/models/match.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OngoingMatchesPage extends StatefulWidget {
  final String tournamentId;

  const OngoingMatchesPage({
    super.key,
    required this.tournamentId,
  });

  @override
  State<OngoingMatchesPage> createState() => _OngoingMatchesPageState();
}

class _OngoingMatchesPageState extends State<OngoingMatchesPage> {
  final _matchService = MatchService();
  final _tournamentService = TournamentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Tournament? _tournament;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  Future<void> _loadTournament() async {
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
            name: '未知賽程',
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
      return const Center(child: CircularProgressIndicator());
    }

    final tournament = _tournament!;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '進行中的比賽',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (tournament.type == 'single_elimination')
                ElevatedButton.icon(
                  onPressed: _showAllPlayersDialog,
                  icon: const Icon(Icons.people, size: 16),
                  label: const Text('選手管理'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: tournament.type == 'single_elimination'
              ? _buildSingleEliminationView()
              : _buildRegularTournamentView(),
        ),
      ],
    );
  }

  // 構建單淘汰賽視圖
  Widget _buildSingleEliminationView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('錯誤: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final matches = <String, dynamic>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
          
          // 統一使用 basic_info 中的數據
          final matchNumber = basicInfo['matchNumber'] ?? data['matchNumber'] ?? '0';
          // 確保 matchNumber 是字符串類型
          final matchNumberStr = matchNumber.toString();
          // 嘗試將 matchNumber 轉換為整數用於排序
          int matchNumberInt = 0;
          try {
            matchNumberInt = int.parse(matchNumberStr);
          } catch (e) {
            print('無法將 matchNumber 轉換為整數: $matchNumberStr');
          }
          
          matches[doc.id] = {
            ...data,
            'status': basicInfo['status'] ?? 'pending',
            'redPlayer': basicInfo['redPlayer'] ?? '待定',
            'bluePlayer': basicInfo['bluePlayer'] ?? '待定',
            'matchNumber': matchNumberStr,
            'matchNumberInt': matchNumberInt,
            'round': basicInfo['round'] ?? data['round'] ?? 0,
            'name': basicInfo['name'] ?? data['name'] ?? '',
            'refereeNumber': basicInfo['refereeNumber'] ?? data['refereeNumber'] ?? '1',
            // 添加單淘汰賽相關字段
            'nextMatchId': basicInfo['nextMatchId'],
            'slotInNext': basicInfo['slotInNext'],
          };
          
          print('載入比賽: ${doc.id}, 狀態: ${basicInfo['status']}, 紅方: ${basicInfo['redPlayer']}, 藍方: ${basicInfo['bluePlayer']}, 比賽號: $matchNumberStr, 輪次: ${basicInfo['round']}');
        }

        if (matches.isEmpty) {
          return const Center(child: Text('尚未生成比賽'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoundStatus(matches),
              const SizedBox(height: 16),
              _buildOngoingMatchesList(matches),
            ],
          ),
        );
      },
    );
  }

  // 構建常規賽程視圖
  Widget _buildRegularTournamentView() {
    return StreamBuilder<List<Match>>(
      stream: _matchService.getOngoingMatches(widget.tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('錯誤：${snapshot.error}'));
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return const Center(child: Text('目前沒有進行中的比賽'));
        }

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text('${match.name} - 場次 ${match.matchNumber}'),
                subtitle: Text('${match.redPlayer} vs ${match.bluePlayer}'),
                trailing: const Icon(Icons.sports_kabaddi),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatchScoringPage(
                        match: match,
                        tournament: _tournament!,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // 構建輪次狀態顯示
  Widget _buildRoundStatus(Map<String, dynamic> matches) {
    final matchesByRound = <int, List<Map<String, dynamic>>>{};
    
    matches.forEach((id, data) {
      final round = data['round'] as int? ?? 0;
      if (!matchesByRound.containsKey(round)) {
        matchesByRound[round] = [];
      }
      matchesByRound[round]!.add({...data, 'id': id});
    });

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('賽程狀態', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...matchesByRound.entries.map((entry) {
              final round = entry.key;
              final roundMatches = entry.value;
              
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
          ],
        ),
      ),
    );
  }

  // 構建進行中比賽列表
  Widget _buildOngoingMatchesList(Map<String, dynamic> matches) {
    final ongoingMatches = matches.entries
        .where((entry) => entry.value['status'] == 'ongoing')
        .toList();

    if (ongoingMatches.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('目前沒有進行中的比賽')),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('進行中比賽', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...ongoingMatches.map((entry) {
            final matchId = entry.key;
            final match = entry.value;
            final redPlayer = match['redPlayer'] ?? '待定';
            final bluePlayer = match['bluePlayer'] ?? '待定';
            final matchNumber = match['matchNumber'] ?? 0;
            final round = match['round'] ?? 0;

            return ListTile(
              title: Text('第$round輪 M$matchNumber: $redPlayer vs $bluePlayer'),
              subtitle: Text('狀態: 進行中'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editPlayerNames(matchId, redPlayer, bluePlayer),
                    tooltip: '編輯選手名稱',
                  ),
                  const Icon(Icons.play_circle, color: Colors.green),
                ],
              ),
              onTap: () {
                // 確保 matchNumber 是字符串
                final matchNumberStr = match['matchNumber'].toString();
                print('點擊比賽: $matchId, 比賽號: $matchNumberStr, 狀態: ${match['status']}');
                
                final matchObj = Match(
                   id: matchId,
                   name: match['name'] ?? '',
                   tournamentId: widget.tournamentId,
                   tournamentName: _tournament?.name ?? '',
                   redPlayer: redPlayer,
                   bluePlayer: bluePlayer,
                   refereeNumber: match['refereeNumber'] ?? '1',
                   status: 'ongoing',
                   matchNumber: matchNumberStr,
                   redScores: {
                     "leftHand": 0,
                     "rightHand": 0,
                     "leftLeg": 0,
                     "rightLeg": 0,
                     "body": 0,
                   },
                   blueScores: {
                     "leftHand": 0,
                     "rightHand": 0,
                     "leftLeg": 0,
                     "rightLeg": 0,
                     "body": 0,
                   },
                   currentSet: 1,
                   redSetsWon: 0,
                   blueSetsWon: 0,
                   setResults: {},
                   createdAt: DateTime.now(),
                   round: round,
                   // 添加單淘汰賽相關字段
                   nextMatchId: match['nextMatchId'],
                   slotInNext: match['slotInNext'],
                 );
                
                print('創建Match對象 - nextMatchId: ${match['nextMatchId']}, slotInNext: ${match['slotInNext']}');
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchScoringPage(
                      match: matchObj,
                      tournament: _tournament!,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  // 顯示所有選手對話框
  void _showAllPlayersDialog() async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: widget.tournamentId)
          .get();

      final allPlayers = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
        final redPlayer = basicInfo['redPlayer'] ?? '';
        final bluePlayer = basicInfo['bluePlayer'] ?? '';
        
        if (redPlayer.isNotEmpty && redPlayer != '待定') {
          allPlayers.add(redPlayer);
        }
        if (bluePlayer.isNotEmpty && bluePlayer != '待定') {
          allPlayers.add(bluePlayer);
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('所有參賽選手'),
          content: SizedBox(
            width: double.maxFinite,
            child: allPlayers.isEmpty
                ? const Text('尚未設定選手名稱')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allPlayers.length,
                    itemBuilder: (context, index) {
                      final player = allPlayers.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(player),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editPlayerNameGlobally(player),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入選手列表失敗: $e')),
        );
      }
    }
  }

  // 全域編輯選手名稱
  Future<void> _editPlayerNameGlobally(String oldName) async {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改選手名稱'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新的選手名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('選手名稱不能為空')),
                );
                return;
              }
              
              Navigator.pop(context);
              Navigator.pop(context); // 關閉選手列表對話框
              
              await _updatePlayerNameGlobally(oldName, newName);
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  // 更新所有比賽中的選手名稱
  Future<void> _updatePlayerNameGlobally(String oldName, String newName) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: widget.tournamentId)
          .get();

      final batch = _firestore.batch();
      int updateCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
        final redPlayer = basicInfo['redPlayer'] ?? '';
        final bluePlayer = basicInfo['bluePlayer'] ?? '';
        
        bool needUpdate = false;
        final updates = <String, dynamic>{};
        
        if (redPlayer == oldName) {
          updates['basic_info.redPlayer'] = newName;
          needUpdate = true;
        }
        if (bluePlayer == oldName) {
          updates['basic_info.bluePlayer'] = newName;
          needUpdate = true;
        }
        
        if (needUpdate) {
          batch.update(doc.reference, updates);
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已更新 $updateCount 場比賽中的選手名稱')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('沒有找到需要更新的比賽')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新選手名稱失敗: $e')),
        );
      }
    }
  }

  // 編輯單場比賽的選手名稱
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
              final redPlayer = redController.text.trim();
              final bluePlayer = blueController.text.trim();
              
              if (redPlayer.isEmpty || bluePlayer.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('選手名稱不能為空')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await _firestore.collection('matches').doc(matchId).update({
                  'basic_info.redPlayer': redPlayer,
                  'basic_info.bluePlayer': bluePlayer,
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('選手名稱更新成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新失敗: $e')),
                  );
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }
}
