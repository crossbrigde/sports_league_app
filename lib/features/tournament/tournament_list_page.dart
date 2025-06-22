import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/tournament.dart';
import '../../core/services/tournament_service.dart';
import 'tournament_detail_page.dart';

class TournamentListPage extends StatefulWidget {
  const TournamentListPage({super.key});

  @override
  State<TournamentListPage> createState() => _TournamentListPageState();
}

class _TournamentListPageState extends State<TournamentListPage> {
  final _tournamentService = TournamentService();
  List<Tournament> _tournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  // 檢查並更新ongoing賽程中的pending比賽狀態
  Future<void> _checkAndUpdatePendingMatches(List<Tournament> tournaments) async {
    final firestore = FirebaseFirestore.instance;
    
    for (final tournament in tournaments) {
      if (tournament.status != 'ongoing') continue;
      
      try {
        // 獲取賽程文檔
        final tournamentDoc = await firestore.collection('tournaments').doc(tournament.id).get();
        if (!tournamentDoc.exists) continue;
        
        final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
        final matches = Map<String, dynamic>.from(tournamentData['matches'] ?? {});
        
        bool hasUpdates = false;
        final batch = firestore.batch();
        
        // 檢查每場比賽
        for (final entry in matches.entries) {
          final matchId = entry.key;
          final matchData = Map<String, dynamic>.from(entry.value);
          
          if (matchData['status'] != 'pending') continue;
          
          final redPlayer = matchData['redPlayer'] as String?;
          final bluePlayer = matchData['bluePlayer'] as String?;
          
          // 檢查是否雙方選手都已就緒（包含輪空）
          if (redPlayer != null && bluePlayer != null && 
              redPlayer.isNotEmpty && bluePlayer.isNotEmpty &&
              redPlayer != '待定' && bluePlayer != '待定') {
            
            // 檢查是否有輪空
             if (redPlayer == '輪空' || bluePlayer == '輪空') {
               // 輪空情況，直接判定勝利
               final winner = redPlayer == '輪空' ? 'blue' : 'red';
               final winnerId = redPlayer == '輪空' ? bluePlayer : redPlayer;
               
               matchData['status'] = 'completed';
               matchData['winner'] = winner;
               matchData['winReason'] = '輪空晉級';
               
               // 更新賽程中的比賽數據
               matches[matchId] = matchData;
               
               // 同時更新matches集合中的比賽
               final matchRef = firestore.collection('matches').doc(matchId);
               batch.update(matchRef, {
                 'basic_info.status': 'completed',
                 'basic_info.winner': winner,
                 'basic_info.winReason': '輪空晉級',
                 'status': 'completed',
                 'winner': winner,
                 'winReason': '輪空晉級',
               });
               
               // 處理輪空晉級到下一場比賽
               await _handleByeAdvancement(tournament.id, matchData, winnerId, matches, batch);
               
               hasUpdates = true;
               print('自動判定輪空勝利：比賽 ${matchData['matchNumber']}，獲勝者：$winnerId');
            } else {
              // 雙方選手都就緒，更新狀態為ongoing
              matchData['status'] = 'ongoing';
              matches[matchId] = matchData;
              
              // 同時更新matches集合中的比賽
              final matchRef = firestore.collection('matches').doc(matchId);
              batch.update(matchRef, {
                'basic_info.status': 'ongoing',
                'status': 'ongoing',
              });
              
              hasUpdates = true;
              print('自動更新比賽狀態為ongoing：比賽 ${matchData['matchNumber']}');
            }
          }
        }
        
        // 如果有更新，提交批次操作並更新賽程文檔
        if (hasUpdates) {
          await batch.commit();
          
          // 更新賽程文檔中的matches
          await firestore.collection('tournaments').doc(tournament.id).update({
            'matches': matches,
          });
          
          print('已更新賽程 ${tournament.name} 中的比賽狀態');
        }
      } catch (e) {
        print('檢查賽程 ${tournament.name} 時發生錯誤：$e');
      }
     }
   }

  // 處理輪空晉級到下一場比賽
  Future<void> _handleByeAdvancement(String tournamentId, Map<String, dynamic> byeMatchData, String winnerId, Map<String, dynamic> matches, WriteBatch batch) async {
    try {
      final currentMatchNumber = byeMatchData['matchNumber'] as String?;
      if (currentMatchNumber == null) return;
      
      // 根據比賽編號確定下一場比賽和槽位
      String? nextMatchNumber;
      String? slotInNext;
      
      // 解析當前比賽編號以確定下一場比賽
      if (currentMatchNumber.startsWith('W')) {
        // 勝者組比賽
        final matchNum = int.tryParse(currentMatchNumber.substring(1));
        if (matchNum != null) {
          if (matchNum <= 4) {
            // 第一輪勝者組 -> 第二輪勝者組
            nextMatchNumber = 'W${5 + (matchNum - 1) ~/ 2}';
            slotInNext = (matchNum % 2 == 1) ? 'bluePlayer' : 'redPlayer';
          } else if (matchNum <= 6) {
            // 第二輪勝者組 -> 第三輪勝者組
            nextMatchNumber = 'W${7 + (matchNum - 5) ~/ 2}';
            slotInNext = (matchNum % 2 == 1) ? 'bluePlayer' : 'redPlayer';
          } else if (matchNum == 7) {
            // 勝者組決賽 -> 總決賽
            nextMatchNumber = 'W9';
            slotInNext = 'bluePlayer';
          }
        }
      } else if (currentMatchNumber.startsWith('L')) {
        // 敗者組比賽
        final matchNum = int.tryParse(currentMatchNumber.substring(1));
        if (matchNum != null) {
          if (matchNum <= 2) {
            // 敗者組第一輪 -> 敗者組第二輪
            nextMatchNumber = 'L${3 + (matchNum - 1) ~/ 2}';
            slotInNext = (matchNum % 2 == 1) ? 'bluePlayer' : 'redPlayer';
          } else if (matchNum <= 4) {
            // 敗者組第二輪 -> 敗者組第三輪
            nextMatchNumber = 'L${5 + (matchNum - 3) ~/ 2}';
            slotInNext = (matchNum % 2 == 1) ? 'bluePlayer' : 'redPlayer';
          } else if (matchNum <= 6) {
            // 敗者組第三輪 -> 敗者組第四輪
            nextMatchNumber = 'L${7 + (matchNum - 5) ~/ 2}';
            slotInNext = (matchNum % 2 == 1) ? 'bluePlayer' : 'redPlayer';
          } else if (matchNum == 7) {
            // 敗者組決賽 -> 總決賽
            nextMatchNumber = 'W9';
            slotInNext = 'redPlayer';
          }
        }
      }
      
      if (nextMatchNumber != null && slotInNext != null) {
        // 查找下一場比賽
        String? nextMatchId;
        for (final entry in matches.entries) {
          if (entry.value['matchNumber'] == nextMatchNumber) {
            nextMatchId = entry.key;
            break;
          }
        }
        
        if (nextMatchId != null) {
          final nextMatchData = Map<String, dynamic>.from(matches[nextMatchId] ?? {});
          nextMatchData[slotInNext] = winnerId;
          
          // 檢查下一場比賽是否雙方選手都就緒
          final nextRedPlayer = nextMatchData['redPlayer'] as String?;
          final nextBluePlayer = nextMatchData['bluePlayer'] as String?;
          
          if (nextRedPlayer != null && nextBluePlayer != null &&
              nextRedPlayer.isNotEmpty && nextBluePlayer.isNotEmpty &&
              nextRedPlayer != '待定' && nextBluePlayer != '待定') {
            // 雙方選手都就緒，更新狀態為ongoing
            nextMatchData['status'] = 'ongoing';
            print('下一場比賽 $nextMatchNumber 雙方選手就緒，狀態更新為ongoing');
          }
          
          matches[nextMatchId] = nextMatchData;
          
          // 同時更新matches集合中的下一場比賽
          final nextMatchRef = FirebaseFirestore.instance.collection('matches').doc(nextMatchId);
          final updateData = {
            'basic_info.$slotInNext': winnerId,
            slotInNext: winnerId,
          };
          
          if (nextMatchData['status'] == 'ongoing') {
            updateData['basic_info.status'] = 'ongoing';
            updateData['status'] = 'ongoing';
          }
          
          batch.update(nextMatchRef, updateData);
          
          print('輪空晉級：$winnerId 晉級到比賽 $nextMatchNumber ($slotInNext)');
        } else {
          print('警告：無法找到下一場比賽 $nextMatchNumber 對應的matchId');
        }
      } else {
        print('警告：無法確定比賽 $currentMatchNumber 的下一場比賽');
      }
    } catch (e) {
      print('處理輪空晉級時發生錯誤：$e');
    }
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTournaments = await _tournamentService.getAllTournaments();
      
      // 檢查並更新ongoing賽程中的pending比賽狀態
      await _checkAndUpdatePendingMatches(allTournaments);
      
      // 重新獲取更新後的賽程
      final updatedTournaments = await _tournamentService.getAllTournaments();
      
      // 顯示單淘汰賽或雙淘汰賽且未完成的賽程
      final filteredTournaments = updatedTournaments
          .where((tournament) => 
              (tournament.type == 'single_elimination' || tournament.type == 'double_elimination') && 
              tournament.status != 'completed')
          .toList();
      setState(() {
        _tournaments = filteredTournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入賽程失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('賽程管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTournaments,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tournaments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_score, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '尚未創建任何賽程',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '請先建立賽程',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTournaments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tournaments.length,
        itemBuilder: (context, index) {
          final tournament = _tournaments[index];
          return _buildTournamentCard(tournament);
        },
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(tournament.status),
          child: Icon(
            _getStatusIcon(tournament.status),
            color: Colors.white,
          ),
        ),
        title: Text(
          tournament.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('類型: ${_getTournamentTypeText(tournament.type)}'),
            Text('狀態: ${_getStatusText(tournament.status)}'),
            Text('創建時間: ${_formatDateTime(tournament.createdAt)}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TournamentDetailPage(
                tournamentId: tournament.id,
                tournamentName: tournament.name,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'setup':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'ongoing':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check;
      case 'setup':
        return Icons.settings;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ongoing':
        return '進行中';
      case 'completed':
        return '已完成';
      case 'setup':
        return '設置中';
      default:
        return '未知';
    }
  }

  String _getTournamentTypeText(String type) {
    switch (type) {
      case 'single_elimination':
        return '單淘汰賽';
      case 'double_elimination': // Added case for double elimination
        return '雙淘汰賽';
      case 'regular':
        return '常規賽程';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }


}