import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/match.dart';
import '../../core/models/tournament.dart';
import 'match_detail_page.dart';
import 'match_statistics_page.dart';

class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Tournament> _tournaments = [];
  Map<String, List<Match>> _matchesByTournament = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取所有賽事
      final tournamentsSnapshot = await _firestore.collection('tournaments').get();
      _tournaments = tournamentsSnapshot.docs
          .map((doc) => Tournament.fromFirestore(doc))
          .toList();

      print('獲取到賽事數量: ${_tournaments.length}');

      // 獲取所有已完成的比賽 - 不使用where條件先獲取所有比賽
      final matchesSnapshot = await _firestore
          .collection('matches')
          .get();
      
      print('總比賽數量: ${matchesSnapshot.docs.length}');

      // 在應用層面過濾已完成的比賽 - 使用多種條件
      final allMatches = matchesSnapshot.docs.map((doc) => Match.fromFirestore(doc)).toList();
      print('轉換後總比賽數量: ${allMatches.length}');
      
      // 檢查特定ID的比賽是否存在
      final specificMatch = allMatches.where((match) => match.id == 'Q2KKVwwZqSmBVKwW06ay').toList();
      if (specificMatch.isNotEmpty) {
        print('找到特定ID的比賽: Q2KKVwwZqSmBVKwW06ay');
        final match = specificMatch.first;
        print('特定比賽詳細信息:');
        print('ID: ${match.id}');
        print('狀態: ${match.status}');
        print('完成時間: ${match.completedAt}');
        print('最後更新時間: ${match.lastUpdated}');
        print('勝者: ${match.winner}');
        print('紅方得分: ${match.redScores['total']}');
        print('藍方得分: ${match.blueScores['total']}');
        print('比賽名稱: ${match.name}');
        print('比賽編號: ${match.matchNumber}');
        print('賽事ID: ${match.tournamentId}');
      } else {
        print('找不到ID為Q2KKVwwZqSmBVKwW06ay的比賽');
      }
      
      // 使用多種條件過濾已完成的比賽
      final matches = allMatches.where((match) => 
        match.status == 'completed' || // 狀態為已完成
        match.completedAt != null || // 有完成時間
        (match.winner != null && match.winner!.isNotEmpty) || // 有指定勝者
        (match.redScores['total']! > 0 || match.blueScores['total']! > 0) // 有得分記錄
      ).toList();
      
      // 檢查特定ID的比賽是否通過過濾條件
      if (specificMatch.isNotEmpty) {
        final match = specificMatch.first;
        final bool passesFilter = 
          match.status == 'completed' || 
          match.completedAt != null || 
          (match.winner != null && match.winner!.isNotEmpty) || 
          (match.redScores['total']! > 0 || match.blueScores['total']! > 0);
        
        print('特定比賽是否通過過濾條件: $passesFilter');
        if (!passesFilter) {
          print('未通過過濾的原因:');
          print('- 狀態是否為completed: ${match.status == "completed"}');
          print('- 是否有完成時間: ${match.completedAt != null}');
          print('- 是否有勝者: ${match.winner != null && match.winner!.isNotEmpty}');
          print('- 是否有得分記錄: ${match.redScores["total"]! > 0 || match.blueScores["total"]! > 0}');
        }
      }
      
      // 輸出診斷信息
      print('過濾條件：status=completed, completedAt!=null, winner!=null, 或有得分記錄');
      print('過濾後找到 ${matches.length} 場已完成比賽');
      
      // 如果找到的比賽與用戶期望不符，輸出更多診斷信息
      if (matches.isEmpty && allMatches.isNotEmpty) {
        print('警告：找不到已完成的比賽，顯示第一場比賽的詳細信息進行診斷：');
        final firstMatch = allMatches.first;
        print('ID: ${firstMatch.id}');
        print('狀態: ${firstMatch.status}');
        print('完成時間: ${firstMatch.completedAt}');
        print('最後更新時間: ${firstMatch.lastUpdated}');
        print('勝者: ${firstMatch.winner}');
        print('紅方得分: ${firstMatch.redScores['total']}');
        print('藍方得分: ${firstMatch.blueScores['total']}');
        print('比賽名稱: ${firstMatch.name}');
        print('比賽編號: ${firstMatch.matchNumber}');
        print('賽事ID: ${firstMatch.tournamentId}');
      } else {
        // 輸出找到的比賽基本信息
        for (var i = 0; i < matches.length && i < 3; i++) {
          final match = matches[i];
          print('找到的比賽 #${i+1} - ID: ${match.id}, 名稱: ${match.name}, 狀態: ${match.status}, 勝者: ${match.winner}');
        }
      }
          
      print('過濾後已完成比賽數量: ${matches.length}');
      
      // 按完成時間排序，最新的排在前面
      matches.sort((a, b) {
        // 如果兩者都有完成時間，按完成時間排序
        if (a.completedAt != null && b.completedAt != null) {
          return b.completedAt!.compareTo(a.completedAt!);
        }
        // 如果只有一個有完成時間，有完成時間的排前面
        if (a.completedAt != null) return -1;
        if (b.completedAt != null) return 1;
        
        // 如果都沒有完成時間，則檢查最後更新時間
        if (a.lastUpdated != null && b.lastUpdated != null) {
          return b.lastUpdated!.compareTo(a.lastUpdated!);
        }
        if (a.lastUpdated != null) return -1;
        if (b.lastUpdated != null) return 1;
        
        // 如果都沒有時間信息，則按創建時間排序
        return b.createdAt.compareTo(a.createdAt);
      });
      
      print('排序後比賽數量: ${matches.length}');

      // 按賽事分組比賽
      _matchesByTournament = {};
      
      // 檢查是否有特定ID的比賽
      if (specificMatch.isNotEmpty) {
        final match = specificMatch.first;
        print('檢查特定比賽的賽事ID: ${match.tournamentId}');
        print('該賽事ID是否存在於tournaments列表中: ${_tournaments.any((t) => t.id == match.tournamentId)}');
      }
      
      // 確保所有賽事ID都有對應的列表
      for (var tournament in _tournaments) {
        if (!_matchesByTournament.containsKey(tournament.id)) {
          _matchesByTournament[tournament.id] = [];
        }
      }
      
      // 將比賽添加到對應賽事的列表中
      for (var match in matches) {
        // 檢查比賽的tournamentId是否存在於_tournaments列表中
        final tournamentExists = _tournaments.any((t) => t.id == match.tournamentId);
        
        if (match.id == 'Q2KKVwwZqSmBVKwW06ay') {
          print('處理特定比賽時的賽事ID: ${match.tournamentId}');
          print('該賽事是否存在於tournaments列表中: $tournamentExists');
        }
        
        // 如果tournamentId不存在於_tournaments列表中，則創建一個「其他比賽」分類
        if (!tournamentExists) {
          if (!_matchesByTournament.containsKey('other')) {
            _matchesByTournament['other'] = [];
          }
          _matchesByTournament['other']!.add(match);
        } else {
          // 正常添加到對應賽事的列表中
          if (!_matchesByTournament.containsKey(match.tournamentId)) {
            _matchesByTournament[match.tournamentId] = [];
          }
          _matchesByTournament[match.tournamentId]!.add(match);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加載比賽記錄失敗: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加載比賽記錄失敗: $e')),
        );
      }
    }
  }

  List<Match> _getFilteredMatches(List<Match> matches) {
    if (_searchQuery.isEmpty) {
      return matches;
    }
    
    return matches.where((match) {
      final searchLower = _searchQuery.toLowerCase();
      return match.name.toLowerCase().contains(searchLower) ||
          match.redPlayer.toLowerCase().contains(searchLower) ||
          match.bluePlayer.toLowerCase().contains(searchLower) ||
          match.refereeNumber.toLowerCase().contains(searchLower) ||
          match.matchNumber.toLowerCase().contains(searchLower) ||
          match.tournamentName.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽紀錄'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTournaments,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜尋比賽',
                hintText: '輸入選手名稱、場次、裁判等',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tournaments.isEmpty
                    ? const Center(child: Text('沒有賽事記錄'))
                    : _buildTournamentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    // 檢查是否有符合搜尋條件的比賽
    bool hasMatchesAfterFilter = false;
    
    // 檢查常規賽事
    for (var tournament in _tournaments) {
      final matches = _matchesByTournament[tournament.id] ?? [];
      if (_getFilteredMatches(matches).isNotEmpty) {
        hasMatchesAfterFilter = true;
        break;
      }
    }
    
    // 檢查「其他比賽」分類
    if (!hasMatchesAfterFilter && _matchesByTournament.containsKey('other')) {
      final otherMatches = _matchesByTournament['other'] ?? [];
      if (_getFilteredMatches(otherMatches).isNotEmpty) {
        hasMatchesAfterFilter = true;
      }
    }

    if (!hasMatchesAfterFilter && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('找不到符合 "$_searchQuery" 的比賽記錄'),
          ],
        ),
      );
    }

    // 創建一個包含所有賽事的列表，包括常規賽事和「其他比賽」分類
    List<Widget> tournamentTiles = [];
    
    // 添加常規賽事
    for (var tournament in _tournaments) {
      final matches = _matchesByTournament[tournament.id] ?? [];
      final filteredMatches = _getFilteredMatches(matches);
      
      // 如果該賽事沒有已完成的比賽或沒有符合搜尋條件的比賽，則不顯示
      if (filteredMatches.isEmpty) {
        continue;
      }
      
      // 檢查賽程狀態，如果是已結束的賽程，在名稱後添加標記
      final isCompleted = tournament.status == 'ended' || tournament.status == 'completed';
      final tournamentTitle = isCompleted
          ? '${tournament.name} (已結束)'
          : tournament.name;
          
      tournamentTiles.add(
        ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(tournamentTitle),
              ),
              // 只有已結束的賽程才顯示統計按鈕
              if (isCompleted)
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: '查看統計',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchStatisticsPage(
                          matches: filteredMatches,
                          tournamentName: tournament.name,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          subtitle: Text('${filteredMatches.length} 場比賽'),
          initiallyExpanded: _searchQuery.isNotEmpty,
          children: filteredMatches.map((match) => _buildMatchItem(match)).toList(),
        )
      );
    }
    
    // 添加「其他比賽」分類
    if (_matchesByTournament.containsKey('other')) {
      final otherMatches = _matchesByTournament['other'] ?? [];
      final filteredOtherMatches = _getFilteredMatches(otherMatches);
      
      if (filteredOtherMatches.isNotEmpty) {
        tournamentTiles.add(
          ExpansionTile(
            title: Row(
              children: [
                const Expanded(
                  child: Text('其他比賽'),
                ),
                // 其他比賽也提供統計功能
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: '查看統計',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchStatisticsPage(
                          matches: filteredOtherMatches,
                          tournamentName: '其他比賽',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            subtitle: Text('${filteredOtherMatches.length} 場比賽'),
            initiallyExpanded: _searchQuery.isNotEmpty,
            children: filteredOtherMatches.map((match) => _buildMatchItem(match)).toList(),
          )
        );
      }
    }
    
    return ListView(
      children: tournamentTiles,
    );
  }

  Widget _buildMatchItem(Match match) {
    // 確定勝者
    String winnerName = '';
    Color winnerColor = Colors.black;
    
    // 檢查比賽是否已完成 - 使用多種條件
    bool isCompleted = match.status == 'completed' || 
                      match.completedAt != null || 
                      (match.winner != null && match.winner!.isNotEmpty);
    
    if (isCompleted) {
      // 先檢查是否有指定勝者
      if (match.winner == 'red') {
        winnerName = match.redPlayer;
        winnerColor = Colors.red;
      } else if (match.winner == 'blue') {
        winnerName = match.bluePlayer;
        winnerColor = Colors.blue;
      } else if (match.redScores['total']! > match.blueScores['total']!) {
        // 如果沒有指定勝者，根據分數判斷
        winnerName = match.redPlayer;
        winnerColor = Colors.red;
      } else if (match.blueScores['total']! > match.redScores['total']!) {
        winnerName = match.bluePlayer;
        winnerColor = Colors.blue;
      } else {
        winnerName = '平局';
      }
    } else {
      winnerName = '進行中';
    }

    return ListTile(
      title: Text('場次 ${match.matchNumber}: ${match.redPlayer} vs ${match.bluePlayer}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match.redScores['total']} : ${match.blueScores['total']} | 勝者: $winnerName',
            style: TextStyle(color: winnerColor),
          ),
          // 顯示完成時間 - 優先使用completedAt，如果沒有則嘗試使用endTime
          // 顯示完成時間 - 優先使用completedAt，如果沒有則嘗試使用lastUpdated
          if (match.completedAt != null)
            Text(
              '完成時間: ${_formatDate(match.completedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          else if (match.lastUpdated != null && (match.winner != null || match.status == 'completed'))
            Text(
              '完成時間: ${_formatDate(match.lastUpdated!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailPage(match: match),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}