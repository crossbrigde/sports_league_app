import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../../core/models/match.dart';
import '../../match/models/tournament.dart';

class TournamentBracketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// 計算大於等於n的最小2的冪
  int nextPowerOfTwo(int n) {
    return math.pow(2, (math.log(n) / math.ln2).ceil()).toInt();
  }

  /// 創建單淘汰賽
  Future<Tournament> createSingleEliminationTournament({
    required String name,
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
  }) async {
    // 創建賽程ID
    final tournamentId = _uuid.v4();
    
    // 創建參賽者列表
    final participants = List.generate(numPlayers, (index) {
      return {
        'id': 'player${index + 1}',
        'displayName': 'PLAYER${index + 1}',
        'userId': null,
      };
    });

    // 計算總比賽場數 = 參賽人數 - 1
    final totalMatches = numPlayers - 1;
    
    // 計算最接近的2的冪
    final adjustedNumPlayers = nextPowerOfTwo(numPlayers);
    
    // 計算輪空數量
    final byeCount = adjustedNumPlayers - numPlayers;
    
    // 計算第一輪比賽數量
    final firstRoundMatches = adjustedNumPlayers ~/ 2;
    
    // 創建比賽樹
    final matches = <String, Map<String, dynamic>>{};
    
    // 使用BFS生成比賽樹
    final rounds = math.log(adjustedNumPlayers) / math.ln2;
    
    // 生成決賽（最後一場比賽）
    final finalMatchId = 'm$totalMatches';
    matches[finalMatchId] = {
      'round': rounds.toInt(),
      'matchNumber': totalMatches.toString(),
      'redPlayer': null,
      'bluePlayer': null,
      'status': 'pending',
      'winner': null,
      'nextMatchId': null,
      'slotInNext': null,
    };
    
    // 從決賽開始，逆向生成比賽樹
    for (int round = rounds.toInt() - 1; round >= 1; round--) {
      final matchesInRound = math.pow(2, round - 1).toInt();
      
      for (int i = 0; i < matchesInRound; i++) {
        final matchIndex = totalMatches - matchesInRound + i - matchesInRound;
        final matchId = 'm${matchIndex + 1}';
        
        // 計算下一場比賽的ID
        final nextMatchIndex = (matchIndex / 2).floor() + matchesInRound;
        final nextMatchId = 'm${nextMatchIndex + 1}';
        
        // 決定在下一場比賽中的位置
        final slotInNext = matchIndex % 2 == 0 ? 'redPlayer' : 'bluePlayer';
        
        matches[matchId] = {
          'round': round,
          'matchNumber': (matchIndex + 1).toString(),
          'redPlayer': null,
          'bluePlayer': null,
          'status': 'pending',
          'winner': null,
          'nextMatchId': nextMatchId,
          'slotInNext': slotInNext,
        };
      }
    }
    
    // 填入第一輪參賽者
    int playerIndex = 0;
    int byePlayerIndex = numPlayers;
    
    for (int i = 0; i < firstRoundMatches; i++) {
      final matchId = 'm${i + 1}';
      
      // 如果這場比賽需要輪空
      if (i < byeCount) {
        // 一位真實選手對陣一位輪空選手
        matches[matchId]!['redPlayer'] = 'player${playerIndex + 1}';
        matches[matchId]!['bluePlayer'] = 'BYE';
        matches[matchId]!['status'] = 'completed';
        matches[matchId]!['winner'] = 'red';
        matches[matchId]!['winReason'] = '對手輪空';
        
        // 自動將勝者填入下一場比賽
        final nextMatchId = matches[matchId]!['nextMatchId'];
        final slotInNext = matches[matchId]!['slotInNext'];
        
        if (nextMatchId != null && slotInNext != null) {
          matches[nextMatchId]![slotInNext] = 'player${playerIndex + 1}';
          
          // 檢查下一場比賽是否雙方都已就緒
          if (matches[nextMatchId]!['redPlayer'] != null && 
              matches[nextMatchId]!['bluePlayer'] != null) {
            matches[nextMatchId]!['status'] = 'ongoing';
          }
        }
        
        playerIndex++;
      } else {
        // 兩位真實選手對陣
        if (playerIndex < numPlayers) {
          matches[matchId]!['redPlayer'] = 'player${playerIndex + 1}';
          playerIndex++;
        }
        
        if (playerIndex < numPlayers) {
          matches[matchId]!['bluePlayer'] = 'player${playerIndex + 1}';
          playerIndex++;
        }
        
        // 設置第一輪實際比賽為ongoing
        matches[matchId]!['status'] = 'ongoing';
      }
    }
    
    // 創建賽程對象
    final tournament = Tournament(
      id: tournamentId,
      name: name,
      type: 'single_elimination',
      createdAt: DateTime.now(),
      targetPoints: targetPoints,
      matchMinutes: matchMinutes,
      status: 'ongoing',
      numPlayers: numPlayers,
      participants: participants,
      matches: matches,
    );
    
    // 保存賽程到Firestore
    await _firestore.collection('tournaments').doc(tournamentId).set(tournament.toFirestore());
    
    // 創建比賽記錄
    for (final entry in matches.entries) {
      final matchId = entry.key;
      final matchData = entry.value;
      
      // 只為狀態為ongoing的比賽創建記錄
      if (matchData['status'] == 'ongoing') {
        final match = Match(
          id: _uuid.v4(),
          name: '${name} - 第${matchData['round']}輪 #${matchData['matchNumber']}',
          matchNumber: matchData['matchNumber'],
          redPlayer: matchData['redPlayer'] ?? '',
          bluePlayer: matchData['bluePlayer'] ?? '',
          refereeNumber: '',
          status: 'ongoing',
          createdAt: DateTime.now(),
          tournamentId: tournamentId,
          tournamentName: name,
          round: matchData['round'],
          nextMatchId: matchData['nextMatchId'],
          slotInNext: matchData['slotInNext'],
          winner: matchData['winner'],
          winReason: matchData['winReason'],
        );
        
        await _firestore.collection('matches').doc(match.id).set(match.toJson());
      }
    }
    
    return tournament;
  }

  /// 處理比賽結束後的晉級邏輯
  Future<void> handleMatchCompletion(Match match) async {
    // 如果比賽沒有下一場或沒有勝者，則不處理
    if (match.nextMatchId == null || match.slotInNext == null || match.winner == null) {
      return;
    }
    
    // 獲取勝者ID
    String winnerId = match.winner == 'red' ? match.redPlayer : match.bluePlayer;
    
    // 更新下一場比賽
    await _firestore.collection('matches').where('matchNumber', isEqualTo: match.nextMatchId)
        .where('tournamentId', isEqualTo: match.tournamentId)
        .get()
        .then((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final nextMatch = snapshot.docs.first;
        final nextMatchData = nextMatch.data();
        
        // 更新下一場比賽的選手
        final updates = {
          match.slotInNext!: winnerId,
        };
        
        // 檢查下一場比賽是否雙方都已就緒
        if ((match.slotInNext == 'redPlayer' && nextMatchData['bluePlayer'] != null) ||
            (match.slotInNext == 'bluePlayer' && nextMatchData['redPlayer'] != null)) {
          updates['status'] = 'ongoing';
        }
        
        await nextMatch.reference.update(updates);
      }
    });
  }
}