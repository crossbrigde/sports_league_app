import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/match.dart';
import 'models/tournament.dart';
import 'match_detail_page.dart';

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

      // 獲取所有已完成的比賽
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('basic_info.status', isEqualTo: 'completed')
          .orderBy('timestamps.completedAt', descending: true)
          .get();

      final matches = matchesSnapshot.docs
          .map((doc) => Match.fromFirestore(doc))
          .toList();

      // 按賽事分組比賽
      _matchesByTournament = {};
      for (var match in matches) {
        if (!_matchesByTournament.containsKey(match.tournamentId)) {
          _matchesByTournament[match.tournamentId] = [];
        }
        _matchesByTournament[match.tournamentId]!.add(match);
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
    for (var tournament in _tournaments) {
      final matches = _matchesByTournament[tournament.id] ?? [];
      if (_getFilteredMatches(matches).isNotEmpty) {
        hasMatchesAfterFilter = true;
        break;
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

    return ListView.builder(
      itemCount: _tournaments.length,
      itemBuilder: (context, index) {
        final tournament = _tournaments[index];
        final matches = _matchesByTournament[tournament.id] ?? [];
        final filteredMatches = _getFilteredMatches(matches);
        
        // 如果該賽事沒有已完成的比賽或沒有符合搜尋條件的比賽，則不顯示
        if (filteredMatches.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return ExpansionTile(
          title: Text(tournament.name),
          subtitle: Text('${filteredMatches.length} 場比賽'),
          initiallyExpanded: _searchQuery.isNotEmpty,
          children: filteredMatches.map((match) => _buildMatchItem(match)).toList(),
        );
      },
    );
  }

  Widget _buildMatchItem(Match match) {
    // 確定勝者
    String winnerName = '';
    Color winnerColor = Colors.black;
    
    if (match.status == 'completed') {
      if (match.redScores['total']! > match.blueScores['total']!) {
        winnerName = match.redPlayer;
        winnerColor = Colors.red;
      } else if (match.blueScores['total']! > match.redScores['total']!) {
        winnerName = match.bluePlayer;
        winnerColor = Colors.blue;
      } else {
        // 如果分數相同，檢查是否有指定勝者
        if (match.winner == 'red') {
          winnerName = match.redPlayer;
          winnerColor = Colors.red;
        } else if (match.winner == 'blue') {
          winnerName = match.bluePlayer;
          winnerColor = Colors.blue;
        } else {
          winnerName = '平局';
        }
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
          if (match.completedAt != null)
            Text(
              '完成時間: ${_formatDate(match.completedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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