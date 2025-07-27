import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/match.dart';
import 'models/tournament.dart';
import 'services/tournament_service.dart';
import '../tournament/services/double_elimination.dart';
import '../tournament/services/tournament_bracket_service.dart';

class CallMatchPage extends StatefulWidget {
  const CallMatchPage({super.key});

  @override
  State<CallMatchPage> createState() => _CallMatchPageState();
}

class _CallMatchPageState extends State<CallMatchPage> {
  final _tournamentService = TournamentService();
  final _doubleEliminationService = DoubleEliminationService();
  final _bracketService = TournamentBracketService();
  final _firestore = FirebaseFirestore.instance;
  
  List<Tournament> _tournaments = [];
  Map<String, List<Match>> _tournamentMatches = {};
  bool _isLoading = true;
  String? _selectedTournamentId;

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
      final tournaments = await _tournamentService.getAllTournaments();
      final activeTournaments = tournaments.where((t) => 
        t.status == 'ongoing' || t.status == 'setup'
      ).toList();
      
      setState(() {
        _tournaments = activeTournaments;
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

  Future<void> _loadTournamentMatches(String tournamentId) async {
    try {
      // 獲取該賽程的所有比賽
      final snapshot = await _firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: tournamentId)
          .get();

      final matches = snapshot.docs
          .map((doc) => Match.fromFirestore(doc))
          .where((match) => match.status == 'pending' || match.status == 'ongoing')
          .toList();

      // 按比賽編號排序
      matches.sort((a, b) {
        final aNum = _extractMatchNumber(a.matchNumber ?? '');
        final bNum = _extractMatchNumber(b.matchNumber ?? '');
        return aNum.compareTo(bNum);
      });

      setState(() {
        _tournamentMatches[tournamentId] = matches;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入比賽失敗: $e')),
        );
      }
    }
  }

  int _extractMatchNumber(String matchNumber) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(matchNumber);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Future<void> _callMatch(Match match) async {
    try {
      // 顯示載入指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final tournament = _tournaments.firstWhere((t) => t.id == match.tournamentId);
      
      // 根據賽事類型處理
      if (tournament.type == 'double_elimination') {
        await _callDoubleEliminationMatch(match, tournament);
      } else {
        await _callSingleEliminationMatch(match, tournament);
      }

      // 關閉載入指示器
      if (mounted) Navigator.pop(context);

      // 重新載入比賽列表
      await _loadTournamentMatches(match.tournamentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功呼叫比賽 ${match.matchNumber}')),
        );
      }
    } catch (e) {
      // 關閉載入指示器
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('呼叫比賽失敗: $e')),
        );
      }
    }
  }

  Future<void> _callDoubleEliminationMatch(Match match, Tournament tournament) async {
    final matchNumber = match.matchNumber ?? '';
    String? redPlayer;
    String? bluePlayer;
    List<String> missingMatches = [];

    // 根據比賽編號確定選手來源
    if (matchNumber.startsWith('W')) {
      // 勝組比賽
      final matchNum = int.tryParse(matchNumber.substring(1)) ?? 0;
      
      if (matchNum <= 8) {
        // 第一輪比賽（W1-W8），從初始選手中分配
        final playerIndex = (matchNum - 1) * 2;
        redPlayer = 'PLAYER${playerIndex + 1}';
        bluePlayer = 'PLAYER${playerIndex + 2}';
      } else if (matchNum == 9) {
        // W9: W1勝者 vs W2勝者
        final result = await _getWinnersFromMatches(['W1', 'W2']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 10) {
        // W10: W3勝者 vs W4勝者
        final result = await _getWinnersFromMatches(['W3', 'W4']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 11) {
        // W11: W5勝者 vs W6勝者
        final result = await _getWinnersFromMatches(['W5', 'W6']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 12) {
        // W12: W7勝者 vs W8勝者
        final result = await _getWinnersFromMatches(['W7', 'W8']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 13) {
        // W13: W9勝者 vs W10勝者
        final result = await _getWinnersFromMatches(['W9', 'W10']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 14) {
        // W14: W11勝者 vs W12勝者
        final result = await _getWinnersFromMatches(['W11', 'W12']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 15) {
        // W15: W13勝者 vs W14勝者 (Winners' Final)
        final result = await _getWinnersFromMatches(['W13', 'W14']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      }
      // 8人雙淘汰賽的舊邏輯（向下兼容）
      else if (matchNum == 5 && tournament.numPlayers == 8) {
        // W5: W1勝者 vs W2勝者
        final result = await _getWinnersFromMatches(['W1', 'W2']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 6 && tournament.numPlayers == 8) {
        // W6: W3勝者 vs W4勝者
        final result = await _getWinnersFromMatches(['W3', 'W4']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 7 && tournament.numPlayers == 8) {
        // W7: W5勝者 vs W6勝者
        final result = await _getWinnersFromMatches(['W5', 'W6']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      }
    } else if (matchNumber.startsWith('L')) {
      // 敗組比賽
      final matchNum = int.tryParse(matchNumber.substring(1)) ?? 0;
      
      // 16人雙淘汰賽敗組邏輯
      if (matchNum == 1) {
        // L1: W1敗者 vs W2敗者
        final result = await _getLosersFromMatches(['W1', 'W2']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 2) {
        // L2: W3敗者 vs W4敗者
        final result = await _getLosersFromMatches(['W3', 'W4']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 3) {
        // L3: W5敗者 vs W6敗者
        final result = await _getLosersFromMatches(['W5', 'W6']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 4) {
        // L4: W7敗者 vs W8敗者
        final result = await _getLosersFromMatches(['W7', 'W8']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 5) {
        // L5: L1勝者 vs W9敗者
        final l1Winner = await _getWinnerFromMatch('L1');
        final w9Loser = await _getLoserFromMatch('W9');
        
        if (l1Winner == null) missingMatches.add('L1');
        if (w9Loser == null) missingMatches.add('W9');
        
        redPlayer = l1Winner;
        bluePlayer = w9Loser;
      } else if (matchNum == 6) {
        // L6: L2勝者 vs W10敗者
        final l2Winner = await _getWinnerFromMatch('L2');
        final w10Loser = await _getLoserFromMatch('W10');
        
        if (l2Winner == null) missingMatches.add('L2');
        if (w10Loser == null) missingMatches.add('W10');
        
        redPlayer = l2Winner;
        bluePlayer = w10Loser;
      } else if (matchNum == 7) {
        // L7: L3勝者 vs W11敗者
        final l3Winner = await _getWinnerFromMatch('L3');
        final w11Loser = await _getLoserFromMatch('W11');
        
        if (l3Winner == null) missingMatches.add('L3');
        if (w11Loser == null) missingMatches.add('W11');
        
        redPlayer = l3Winner;
        bluePlayer = w11Loser;
      } else if (matchNum == 8) {
        // L8: L4勝者 vs W12敗者
        final l4Winner = await _getWinnerFromMatch('L4');
        final w12Loser = await _getLoserFromMatch('W12');
        
        if (l4Winner == null) missingMatches.add('L4');
        if (w12Loser == null) missingMatches.add('W12');
        
        redPlayer = l4Winner;
        bluePlayer = w12Loser;
      } else if (matchNum == 9) {
        // L9: L5勝者 vs L6勝者
        final result = await _getWinnersFromMatches(['L5', 'L6']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 10) {
        // L10: L7勝者 vs L8勝者
        final result = await _getWinnersFromMatches(['L7', 'L8']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 11) {
        // L11: L9勝者 vs W14敗者
        final l9Winner = await _getWinnerFromMatch('L9');
        final w14Loser = await _getLoserFromMatch('W14');
        
        if (l9Winner == null) missingMatches.add('L9');
        if (w14Loser == null) missingMatches.add('W14');
        
        redPlayer = l9Winner;
        bluePlayer = w14Loser;
      } else if (matchNum == 12) {
        // L12: L10勝者 vs W13敗者
        final l10Winner = await _getWinnerFromMatch('L10');
        final w13Loser = await _getLoserFromMatch('W13');
        
        if (l10Winner == null) missingMatches.add('L10');
        if (w13Loser == null) missingMatches.add('W13');
        
        redPlayer = l10Winner;
        bluePlayer = w13Loser;
      } else if (matchNum == 13) {
        // L13: L11勝者 vs L12勝者
        final result = await _getWinnersFromMatches(['L11', 'L12']);
        redPlayer = result['players'][0];
        bluePlayer = result['players'][1];
        missingMatches = result['missing'];
      } else if (matchNum == 14) {
        // L14: L13勝者 vs W15敗者 (Losers' Final)
        final l13Winner = await _getWinnerFromMatch('L13');
        final w15Loser = await _getLoserFromMatch('W15');
        
        if (l13Winner == null) missingMatches.add('L13');
        if (w15Loser == null) missingMatches.add('W15');
        
        redPlayer = l13Winner;
        bluePlayer = w15Loser;
      }
    } else if (matchNumber == 'G1' || matchNumber == 'GF') {
      // 總決賽
      if (tournament.numPlayers == 16) {
        // 16人雙淘汰賽: W15勝者 vs L14勝者
        final w15Winner = await _getWinnerFromMatch('W15');
        final l14Winner = await _getWinnerFromMatch('L14');
        
        if (w15Winner == null) missingMatches.add('W15');
        if (l14Winner == null) missingMatches.add('L14');
        
        redPlayer = w15Winner;
        bluePlayer = l14Winner;
      } else {
        // 8人雙淘汰賽: W7勝者 vs L6勝者
        final w7Winner = await _getWinnerFromMatch('W7');
        final l6Winner = await _getWinnerFromMatch('L6');
        
        if (w7Winner == null) missingMatches.add('W7');
        if (l6Winner == null) missingMatches.add('L6');
        
        redPlayer = w7Winner;
        bluePlayer = l6Winner;
      }
    }

    if (missingMatches.isNotEmpty) {
      throw Exception('無法呼叫比賽，以下比賽尚未完成：${missingMatches.join(', ')}');
    }

    if (redPlayer == null || bluePlayer == null) {
      throw Exception('無法確定比賽選手');
    }

    // 更新比賽
    await _updateMatch(match, redPlayer, bluePlayer);
  }

  Future<void> _callSingleEliminationMatch(Match match, Tournament tournament) async {
    // 單淘汰賽的邏輯相對簡單，通常從初始選手開始
    final matchNumber = match.matchNumber ?? '';
    String? redPlayer;
    String? bluePlayer;
    
    // 對於單淘汰賽，如果是第一輪，直接分配選手
    // 如果是後續輪次，需要從前面比賽的勝者中獲取
    final matchNum = int.tryParse(matchNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    
    if (matchNum <= 4) {
      // 第一輪比賽，從初始選手中分配
      final playerIndex = (matchNum - 1) * 2;
      redPlayer = 'PLAYER${playerIndex + 1}';
      bluePlayer = 'PLAYER${playerIndex + 2}';
    } else {
      throw Exception('單淘汰賽後續輪次需要手動處理，或者實現更複雜的邏輯');
    }

    await _updateMatch(match, redPlayer, bluePlayer);
  }

  Future<Map<String, dynamic>> _getWinnersFromMatches(List<String> matchNumbers) async {
    List<String?> players = [];
    List<String> missingMatches = [];

    for (final matchNumber in matchNumbers) {
      final winner = await _getWinnerFromMatch(matchNumber);
      if (winner != null) {
        players.add(winner);
      } else {
        missingMatches.add(matchNumber);
        players.add(null);
      }
    }

    return {
      'players': players,
      'missing': missingMatches,
    };
  }

  Future<Map<String, dynamic>> _getLosersFromMatches(List<String> matchNumbers) async {
    List<String?> players = [];
    List<String> missingMatches = [];

    for (final matchNumber in matchNumbers) {
      final loser = await _getLoserFromMatch(matchNumber);
      if (loser != null) {
        players.add(loser);
      } else {
        missingMatches.add(matchNumber);
        players.add(null);
      }
    }

    return {
      'players': players,
      'missing': missingMatches,
    };
  }

  Future<String?> _getWinnerFromMatch(String matchNumber) async {
    final match = await _getMatchByNumber(matchNumber);
    if (match?.winner != null && match?.status == 'completed') {
      return match!.winner == 'red' ? match.redPlayer : match.bluePlayer;
    }
    return null;
  }

  Future<String?> _getLoserFromMatch(String matchNumber) async {
    final match = await _getMatchByNumber(matchNumber);
    if (match?.winner != null && match?.status == 'completed') {
      return match!.winner == 'red' ? match.bluePlayer : match.redPlayer;
    }
    return null;
   }

  Future<Match?> _getMatchByNumber(String matchNumber) async {
    if (_selectedTournamentId == null) return null;
    
    final snapshot = await _firestore
        .collection('matches')
        .where('basic_info.tournamentId', isEqualTo: _selectedTournamentId)
        .where('basic_info.matchNumber', isEqualTo: matchNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Match.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<void> _updateMatch(Match match, String redPlayer, String bluePlayer) async {
    await _firestore.collection('matches').doc(match.id).update({
      'basic_info.redPlayer': redPlayer,
      'basic_info.bluePlayer': bluePlayer,
      'basic_info.status': 'ongoing',
      'scores.redScores': [0, 0, 0],
      'scores.blueScores': [0, 0, 0],
      'scores.currentSet': 1,
      'scores.redSetsWon': 0,
      'scores.blueSetsWon': 0,
      'scores.setResults': [],
      'timestamps.startedAt': FieldValue.serverTimestamp(),
      'timestamps.lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('呼叫比賽'),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_tournaments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_score, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '沒有進行中的賽程',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 賽程選擇器
        Container(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedTournamentId,
            decoration: const InputDecoration(
              labelText: '選擇賽程',
              border: OutlineInputBorder(),
            ),
            items: _tournaments.map((tournament) {
              return DropdownMenuItem(
                value: tournament.id,
                child: Text(tournament.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTournamentId = value;
              });
              if (value != null) {
                _loadTournamentMatches(value);
              }
            },
          ),
        ),
        // 比賽列表
        Expanded(
          child: _selectedTournamentId == null
              ? const Center(
                  child: Text(
                    '請選擇一個賽程',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : _buildMatchList(),
        ),
      ],
    );
  }

  Widget _buildMatchList() {
    final matches = _tournamentMatches[_selectedTournamentId] ?? [];
    
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          '沒有待定或進行中的比賽',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return _buildMatchCard(match);
      },
    );
  }

  Widget _buildMatchCard(Match match) {
    final isPending = match.status == 'pending';
    final hasPlayers = match.redPlayer != null && match.bluePlayer != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange : Colors.green,
          child: Icon(
            isPending ? Icons.pending : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
        title: Text(
          match.matchNumber ?? '未知比賽',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('狀態: ${isPending ? "待定" : "進行中"}'),
            if (hasPlayers)
              Text('選手: ${match.redPlayer} vs ${match.bluePlayer}')
            else
              const Text('選手: 待分配'),
            if (match.bracket != null)
              Text('組別: ${match.bracket}'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: isPending ? () => _callMatch(match) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isPending ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(isPending ? '呼叫' : '已開始'),
        ),
      ),
    );
  }
}