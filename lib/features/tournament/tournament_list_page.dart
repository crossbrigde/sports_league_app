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

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTournaments = await _tournamentService.getAllTournaments();
      // 只顯示單淘汰賽且未完成的賽程
      final filteredTournaments = allTournaments
          .where((tournament) => 
              tournament.type == 'single_elimination' && 
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
            icon: const Icon(Icons.stop_circle),
            onPressed: _showEndTournamentDialog,
            tooltip: '結束賽程',
          ),
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
      case 'regular':
        return '常規賽程';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 顯示結束賽程對話框
  Future<void> _showEndTournamentDialog() async {
    try {
      // 搜尋ongoing或active狀態的賽程
      final ongoingTournaments = await _getOngoingTournaments();
      
      if (ongoingTournaments.isEmpty) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('目前沒有進行中的單淘汰賽賽程')),
           );
         }
         return;
       }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('選擇要結束的單淘汰賽賽程'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ongoingTournaments.length,
                itemBuilder: (context, index) {
                  final tournament = ongoingTournaments[index];
                  return ListTile(
                    title: Text(tournament.name),
                    subtitle: Text('狀態: ${_getStatusText(tournament.status)}'),
                    onTap: () {
                      Navigator.pop(context);
                      _showTournamentStatsDialog(tournament);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入賽程失敗: $e')),
        );
      }
    }
  }

  // 獲取進行中的單淘汰賽賽程
  Future<List<Tournament>> _getOngoingTournaments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .where('status', whereIn: ['ongoing', 'active'])
        .where('type', isEqualTo: 'single_elimination')
        .get();
    
    return snapshot.docs
        .map((doc) => Tournament.fromFirestore(doc))
        .toList();
  }

  // 顯示賽程統計對話框
  Future<void> _showTournamentStatsDialog(Tournament tournament) async {
    try {
      // 獲取該賽程的比賽統計
      final stats = await _getTournamentStats(tournament.id);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('結束賽程：${tournament.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('賽程名稱：${tournament.name}'),
                const SizedBox(height: 8),
                Text('總比賽數量：${stats['totalMatches']}'),
                Text('已完成比賽：${stats['completedMatches']}'),
                Text('進行中比賽：${stats['ongoingMatches']}'),
                Text('未開始比賽：${stats['pendingMatches']}'),
                const SizedBox(height: 16),
                const Text(
                  '確定要結束此賽程嗎？結束後狀態將變更為「已完成」。',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _endTournament(tournament);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('確定結束'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入賽程統計失敗: $e')),
        );
      }
    }
  }

  // 獲取賽程統計數據
  Future<Map<String, int>> _getTournamentStats(String tournamentId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('basic_info.tournamentId', isEqualTo: tournamentId)
        .get();
    
    int totalMatches = snapshot.docs.length;
    int completedMatches = 0;
    int ongoingMatches = 0;
    int pendingMatches = 0;
    
    for (final doc in snapshot.docs) {
      final status = doc.data()['basic_info']['status'] as String? ?? 'pending';
      switch (status) {
        case 'completed':
          completedMatches++;
          break;
        case 'ongoing':
          ongoingMatches++;
          break;
        default:
          pendingMatches++;
          break;
      }
    }
    
    return {
      'totalMatches': totalMatches,
      'completedMatches': completedMatches,
      'ongoingMatches': ongoingMatches,
      'pendingMatches': pendingMatches,
    };
  }

  // 結束賽程
  Future<void> _endTournament(Tournament tournament) async {
    try {
      await _tournamentService.updateTournamentStatus(tournament.id, 'completed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('賽程「${tournament.name}」已成功結束')),
        );
        
        // 重新載入賽程列表
        _loadTournaments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('結束賽程失敗: $e')),
        );
      }
    }
  }
}