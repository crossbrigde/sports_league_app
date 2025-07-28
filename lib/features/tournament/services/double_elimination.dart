import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/tournament.dart';
import '../../../core/models/match.dart';

class DoubleEliminationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// 計算大於等於n的最小2的冪
  int nextPowerOfTwo(int n) {
    return math.pow(2, (math.log(n) / math.ln2).ceil()).toInt();
  }

  /// 創建雙淘汰賽
  Future<Tournament> createDoubleEliminationTournament({
    required String name,
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
    List<String>? playerNames,
    bool randomPairing = false,
  }) async {
    // 創建賽程ID
    final tournamentId = _uuid.v4();
    
    // 創建參賽者列表
    final participants = List.generate(numPlayers, (index) {
      String playerName;
      if (playerNames != null && index < playerNames.length && playerNames[index].isNotEmpty) {
        playerName = playerNames[index];
      } else {
        playerName = 'PLAYER${index + 1}';
      }
      
      return {
        'id': playerName,
        'displayName': playerName,
        'userId': null,
      };
    });
    
    debugPrint('創建雙淘汰賽，參賽人數：$numPlayers');
    
    // 根據參賽人數選擇合適的模板
    Map<String, dynamic> bracketTemplate;
    if (numPlayers <= 8) {
      bracketTemplate = await _load8PlayerTemplate();
    } else if (numPlayers <= 16) {
      bracketTemplate = await _load16PlayerTemplate();
    } else {
      // 對於更多人數，使用動態生成
      bracketTemplate = _generateDynamicBracket(numPlayers);
    }
    
    // 創建比賽結構
    final matchStructure = _buildDoubleEliminationMatches(
      bracketTemplate, 
      numPlayers, 
      name, 
      tournamentId
    );
    
    // 分配選手到第一輪比賽
    _assignPlayersToFirstRound(matchStructure, numPlayers);
    
    // 創建所有 Match 物件
    final allMatches = <Match>[];
    for (final entry in matchStructure.entries) {
      final matchId = entry.key;
      final matchData = entry.value;
      
      final match = Match(
        id: _uuid.v4(),
        name: '${name} - ${matchData['bracket']} ${matchData['displayName']}',
        matchNumber: matchData['matchNumber'] as String,
        redPlayer: matchData['redPlayer'] as String? ?? '',
        bluePlayer: matchData['bluePlayer'] as String? ?? '',
        refereeNumber: '裁判',
        status: matchData['status'] as String,
        redScores: <String, int>{'total': 0, 'leftHand': 0, 'rightHand': 0, 'leftLeg': 0, 'rightLeg': 0, 'body': 0},
        blueScores: <String, int>{'total': 0, 'leftHand': 0, 'rightHand': 0, 'leftLeg': 0, 'rightLeg': 0, 'body': 0},
        currentSet: 1,
        redSetsWon: 0,
        blueSetsWon: 0,
        setResults: <String, String>{},
        createdAt: DateTime.now(),
        tournamentId: tournamentId,
        tournamentName: name,
        round: matchData['round'] as int?,
        nextMatchId: matchData['nextMatchId'] as String?,
        slotInNext: matchData['slotInNext'] as String?,
        winner: matchData['winner'] as String?,
        winReason: matchData['winReason'] as String?,
        bracket: matchData['bracket'] as String?, // 新增：標記是勝組還是敗組
        losersDestination: matchData['losersDestination'] as String?, // 新增：敗者目標位置
      );
      
      allMatches.add(match);
      
      // 更新 matchStructure 中的實際 Match ID
      matchData['actualMatchId'] = match.id;
    }
    
    // 更新 nextMatchId 為實際的 Match ID
    _updateNextMatchIds(allMatches, matchStructure);
    
    // 創建賽程對象
    final tournament = Tournament(
      id: tournamentId,
      name: name,
      type: 'double_elimination',
      createdAt: DateTime.now(),
      targetPoints: targetPoints,
      matchMinutes: matchMinutes,
      status: 'ongoing',
      numPlayers: numPlayers,
      participants: participants,
      matches: matchStructure,
    );
    
    // 使用 WriteBatch 一次性寫入所有數據
    await _batchWriteAllData(tournament, allMatches);
    
    return tournament;
  }

  /// 載入8人雙淘汰賽模板
  Future<Map<String, dynamic>> _load8PlayerTemplate() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'lib/features/tournament/services/double_elimination_8_template.json'
      );
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('載入8人模板失敗，使用動態生成: $e');
      return _generateDynamicBracket(8);
    }
  }

  /// 載入16人雙淘汰賽模板
  Future<Map<String, dynamic>> _load16PlayerTemplate() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'lib/features/tournament/services/double_elimination_16_template.json'
      );
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('載入16人模板失敗，使用動態生成: $e');
      return _generateDynamicBracket(16);
    }
  }

  /// 動態生成雙淘汰賽結構（適用於非16人的情況）
  Map<String, dynamic> _generateDynamicBracket(int numPlayers) {
    final adjustedNumPlayers = nextPowerOfTwo(numPlayers);
    
    return {
      "tournament_type": "double_elimination",
      "num_players": numPlayers,
      "adjusted_players": adjustedNumPlayers,
      "winners_bracket": _generateWinnersBracket(adjustedNumPlayers),
      "losers_bracket": _generateLosersBracket(adjustedNumPlayers),
    };
  }

  /// 生成勝組結構
  Map<String, dynamic> _generateWinnersBracket(int adjustedNumPlayers) {
    final rounds = <Map<String, dynamic>>[];
    int currentPlayers = adjustedNumPlayers;
    int round = 1;
    int globalMatchCounter = 1;
    
    while (currentPlayers > 1) {
      final matches = currentPlayers ~/ 2;
      final matchDetails = <Map<String, dynamic>>[];
      
      // 為每場比賽生成詳細配置
      for (int i = 0; i < matches; i++) {
        final losersDestination = _generateLosersDestination(round, i, adjustedNumPlayers);
        matchDetails.add({
          "id": "W$globalMatchCounter",
          "losers_to": losersDestination,
          "slot_in_losers": i % 2 == 0 ? "red" : "blue"
        });
        globalMatchCounter++;
      }
      
      rounds.add({
        "round": round == (math.log(adjustedNumPlayers) / math.ln2).toInt() ? "final" : round,
        "matches": matches,
        "match_details": matchDetails
      });
      
      currentPlayers ~/= 2;
      round++;
    }
    
    return {"rounds": rounds};
  }
  
  /// 生成敗者目標位置
  String _generateLosersDestination(int round, int matchIndex, int adjustedNumPlayers) {
    if (round == 1) {
      // 第一輪：每兩場比賽的敗者進入同一個敗組比賽
      final losersMatchIndex = (matchIndex ~/ 2) + 1;
      return "L$losersMatchIndex";
    } else if (round == 2) {
      // 第二輪：根據比賽索引分配到不同的敗組比賽
      final baseIndex = adjustedNumPlayers ~/ 4; // 第一輪敗組比賽數量
      final losersMatchIndex = baseIndex + matchIndex + 1;
      return "L$losersMatchIndex";
    } else {
      // 後續輪次：簡化邏輯
      final losersMatchIndex = round * 2 + matchIndex;
      return "L$losersMatchIndex";
    }
  }

  /// 生成敗組結構
  Map<String, dynamic> _generateLosersBracket(int adjustedNumPlayers) {
    final rounds = <Map<String, dynamic>>[];
    // 簡化的敗組生成邏輯
    int losersRound = 1;
    int remainingMatches = adjustedNumPlayers ~/ 4;
    
    while (remainingMatches > 0) {
      final matches = <String>[];
      for (int i = 0; i < remainingMatches; i++) {
        matches.add("L$losersRound");
        losersRound++;
      }
      
      rounds.add({
        "round": rounds.length + 1,
        "matches": matches,
        "winners_to": remainingMatches > 1 ? "L${losersRound}" : "Final"
      });
      
      remainingMatches ~/= 2;
    }
    
    return {"rounds": rounds};
  }

  /// 計算敗組輪次
  int _calculateLosersRound(int winnersRound, int adjustedNumPlayers) {
    // 簡化的計算邏輯
    return winnersRound * 2;
  }

  /// 建立雙淘汰賽比賽結構
  Map<String, Map<String, dynamic>> _buildDoubleEliminationMatches(
    Map<String, dynamic> bracketTemplate,
    int numPlayers,
    String tournamentName,
    String tournamentId,
  ) {
    final matches = <String, Map<String, dynamic>>{};
    int winnersMatchCounter = 1;
    
    // 處理勝組
    final winnersBracket = bracketTemplate['winners_bracket'] as Map<String, dynamic>;
    final winnersRounds = winnersBracket['rounds'] as List<dynamic>;
    
    for (int i = 0; i < winnersRounds.length; i++) {
      final roundData = winnersRounds[i] as Map<String, dynamic>;
      final roundNumber = roundData['round'];
      final matchCount = roundData['matches'] as int;
      
      for (int j = 0; j < matchCount; j++) {
        String matchId;
        String matchNumber;
        
        // 檢查是否有 match_details（新格式）
        if (roundData.containsKey('match_details')) {
          final matchDetails = roundData['match_details'] as List<dynamic>;
          if (j < matchDetails.length) {
            final matchDetail = matchDetails[j] as Map<String, dynamic>;
            matchId = matchDetail['id'] as String;
            matchNumber = matchId;
          } else {
            matchId = 'W$winnersMatchCounter';
            matchNumber = 'W$winnersMatchCounter';
          }
        } else {
          // 舊格式
          matchId = 'W$winnersMatchCounter';
          matchNumber = 'W$winnersMatchCounter';
        }
        
        // 特殊處理勝組決賽的slotInNext
        String slotInNext;
        final nextMatchId = _calculateNextWinnersMatch(i, j, winnersRounds.length);
        if (nextMatchId == 'G1') {
          // 勝組決賽的勝者固定進入G1的紅方
          slotInNext = 'redPlayer';
        } else {
          slotInNext = j % 2 == 0 ? 'redPlayer' : 'bluePlayer';
        }
        
        matches[matchId] = {
          'matchNumber': matchNumber,
          'bracket': 'Winners',
          'round': i + 1,
          'displayName': '勝組第${i + 1}輪 #${j + 1}',
          'redPlayer': null,
          'bluePlayer': null,
          'status': 'pending',
          'winner': null,
          'nextMatchId': nextMatchId,
          'slotInNext': slotInNext,
          'losersDestination': _calculateLosersDestination(i, j, bracketTemplate),
        };
        winnersMatchCounter++;
      }
    }
    
    // 處理敗組
    final losersBracket = bracketTemplate['losers_bracket'] as Map<String, dynamic>;
    final losersRounds = losersBracket['rounds'] as List<dynamic>;
    
    for (int i = 0; i < losersRounds.length; i++) {
      final roundData = losersRounds[i] as Map<String, dynamic>;
      final matches_list = roundData['matches'] as List<dynamic>;
      
      for (int j = 0; j < matches_list.length; j++) {
        String matchName;
        String matchId;
        
        // 檢查matches是字符串格式還是對象格式
        if (matches_list[j] is String) {
          // 8人模板格式：["L1", "L2"]
          matchName = matches_list[j] as String;
          matchId = matchName;
        } else {
          // 16人模板格式：[{"id": "L1", "red": "...", "blue": "..."}]
          final matchDetail = matches_list[j] as Map<String, dynamic>;
          matchName = matchDetail['id'] as String;
          matchId = matchName;
        }
        
        // 特殊處理敗組比賽的slotInNext邏輯
        String slotInNext;
        final nextMatchId = _calculateNextLosersMatch(i, j, losersRounds);
        if (matchName == 'L3') {
          // L3勝者 → L5（紅方）
          slotInNext = 'redPlayer';
        } else if (matchName == 'L4') {
          // L4勝者 → L5（藍方）
          slotInNext = 'bluePlayer';
        } else if (matchName == 'L5') {
          // L5比賽的slotInNext不重要，因為它是接收方
          slotInNext = 'redPlayer';
        } else if (nextMatchId == 'G1') {
          // 敗組決賽的勝者固定進入G1的藍方
          slotInNext = 'bluePlayer';
        } else {
          slotInNext = j % 2 == 0 ? 'redPlayer' : 'bluePlayer';
        }
        
        matches[matchId] = {
          'matchNumber': matchName,
          'bracket': 'Losers',
          'round': i + 1,
          'displayName': '敗組 $matchName',
          'redPlayer': null,
          'bluePlayer': null,
          'status': 'pending',
          'winner': null,
          'nextMatchId': nextMatchId,
          'slotInNext': slotInNext,
        };
      }
    }
    
    // 添加總決賽
    matches['G1'] = {
      'matchNumber': 'G1',
      'bracket': 'Grand Final',
      'round': winnersRounds.length + losersRounds.length + 1,
      'displayName': '總決賽',
      'redPlayer': null, // 勝組冠軍
      'bluePlayer': null, // 敗組冠軍
      'status': 'pending',
      'winner': null,
      'nextMatchId': null,
      'slotInNext': null,
    };
    
    return matches;
  }

  /// 計算勝組下一場比賽
  String? _calculateNextWinnersMatch(int roundIndex, int matchIndex, int totalRounds) {
    if (roundIndex >= totalRounds - 1) {
      return 'G1'; // 勝組決賽的勝者直接進入總決賽
    }
    
    // 8人雙淘汰賽的正確晉級規則：
    // 第1輪：W1,W2 → W5; W3,W4 → W6
    // 第2輪：W5,W6 → W7
    // 第3輪：W7 → G1
    
    if (roundIndex == 0) {
      // 第一輪：W1,W2 → W5; W3,W4 → W6
      if (matchIndex < 2) {
        return 'W5';
      } else {
        return 'W6';
      }
    } else if (roundIndex == 1) {
      // 第二輪：W5,W6 → W7
      return 'W7';
    }
    
    return 'G1';
  }
  
  /// 獲取指定輪次的比賽數量
  int _getMatchesInRound(int roundIndex) {
    // 8人雙淘汰賽的比賽數量
    switch (roundIndex) {
      case 0: return 4; // 第一輪：4場 (W1,W2,W3,W4)
      case 1: return 2; // 第二輪：2場 (W5,W6)
      case 2: return 1; // 第三輪：1場 (W7)
      default: return 1;
    }
  }

  /// 計算敗組下一場比賽
  String? _calculateNextLosersMatch(int roundIndex, int matchIndex, List<dynamic> losersRounds) {
    if (roundIndex >= losersRounds.length - 1) {
      return 'G1'; // 敗組決賽的勝者進入總決賽
    }
    
    // 根據敗組的 winners_to 配置計算下一場比賽
    final currentRound = losersRounds[roundIndex] as Map<String, dynamic>;
    final winnersTo = currentRound['winners_to'] as List<dynamic>?;
    
    if (winnersTo != null && matchIndex < winnersTo.length) {
      return winnersTo[matchIndex] as String;
    }
    
    // 如果沒有明確的 winners_to 配置，使用簡化邏輯
    return 'L${roundIndex + 2}';
  }

  /// 計算敗組目標位置
  String? _calculateLosersDestination(int roundIndex, int matchIndex, Map<String, dynamic> bracketTemplate) {
    try {
      final winnersBracket = bracketTemplate['winners_bracket'] as Map<String, dynamic>;
      final winnersRounds = winnersBracket['rounds'] as List<dynamic>;
      
      if (roundIndex < winnersRounds.length) {
        final roundData = winnersRounds[roundIndex] as Map<String, dynamic>;
        
        // 檢查是否有 match_details（新格式）
        if (roundData.containsKey('match_details')) {
          final matchDetails = roundData['match_details'] as List<dynamic>;
          if (matchIndex < matchDetails.length) {
            final matchDetail = matchDetails[matchIndex] as Map<String, dynamic>;
            return matchDetail['losers_to'] as String?;
          }
        } else {
          // 舊格式處理
          final losersTo = roundData['losers_to'];
          
          if (losersTo != null) {
            if (losersTo is List) {
              // 如果是陣列格式
              if (matchIndex < losersTo.length) {
                return losersTo[matchIndex] as String;
              }
            } else if (losersTo is String) {
              // 如果是字符串格式（如 "L1-L4"）
              final losersDestinations = _parseLosersToString(losersTo);
              if (matchIndex < losersDestinations.length) {
                return losersDestinations[matchIndex];
              }
            }
          }
        }
      }
      
      debugPrint('警告：無法為勝組第${roundIndex + 1}輪第${matchIndex + 1}場比賽找到敗組目標');
      return null;
    } catch (e) {
      debugPrint('計算敗組目標時發生錯誤: $e');
      return null;
    }
  }

  /// 解析 losers_to 字符串格式（如 "L1-L4" -> ["L1", "L2", "L3", "L4"]）
  List<String> _parseLosersToString(String losersTo) {
    final parts = losersTo.split('-');
    if (parts.length == 2) {
      final start = parts[0].trim();
      final end = parts[1].trim();
      
      // 提取數字部分
      final startMatch = RegExp(r'L(\d+)').firstMatch(start);
      final endMatch = RegExp(r'L(\d+)').firstMatch(end);
      
      if (startMatch != null && endMatch != null) {
        final startNum = int.parse(startMatch.group(1)!);
        final endNum = int.parse(endMatch.group(1)!);
        
        final result = <String>[];
        for (int i = startNum; i <= endNum; i++) {
          result.add('L$i');
        }
        return result;
      }
    }
    
    // 如果解析失敗，返回原字符串作為單一元素
    return [losersTo];
  }

  /// 分配選手到第一輪比賽
  void _assignPlayersToFirstRound(Map<String, Map<String, dynamic>> matchStructure, int numPlayers) {
    // 獲取勝組第一輪比賽
    final firstRoundMatches = matchStructure.entries
        .where((entry) => entry.value['bracket'] == 'Winners' && entry.value['round'] == 1)
        .toList();
    
    firstRoundMatches.sort((a, b) => a.key.compareTo(b.key));
    
    int playerIndex = 0;
    for (final entry in firstRoundMatches) {
      final matchData = entry.value;
      
      if (playerIndex < numPlayers) {
        matchData['redPlayer'] = 'PLAYER${playerIndex + 1}';
        playerIndex++;
      }
      
      if (playerIndex < numPlayers) {
        matchData['bluePlayer'] = 'PLAYER${playerIndex + 1}';
        playerIndex++;
      }
      
      // 如果雙方都有選手，設為 ongoing
      if (matchData['redPlayer'] != null && matchData['bluePlayer'] != null) {
        matchData['status'] = 'ongoing';
      }
    }
    
    debugPrint('雙淘汰賽選手分配完成，共分配 $playerIndex 名選手');
  }

  /// 更新 nextMatchId 和 losersDestination 為實際的 Match ID
  void _updateNextMatchIds(List<Match> allMatches, Map<String, Map<String, dynamic>> matchStructure) {
    final matchIdMapping = <String, String>{};
    
    // 建立映射表：matchNumber -> actualMatchId
    for (final entry in matchStructure.entries) {
      final matchKey = entry.key;
      final actualMatchId = entry.value['actualMatchId'] as String?;
      if (actualMatchId != null) {
        matchIdMapping[matchKey] = actualMatchId;
      }
    }
    
    // 更新所有 Match 的 nextMatchId 和 losersDestination
    for (int i = 0; i < allMatches.length; i++) {
      final match = allMatches[i];
      String? updatedNextMatchId = match.nextMatchId;
      String? updatedLosersDestination = match.losersDestination;
      
      // 更新 nextMatchId
      if (match.nextMatchId != null && matchIdMapping.containsKey(match.nextMatchId)) {
        updatedNextMatchId = matchIdMapping[match.nextMatchId];
      }
      
      // 更新 losersDestination（查找對應的敗組比賽ID）
      if (match.losersDestination != null) {
        // 查找具有相同 matchNumber 的比賽
        for (final entry in matchStructure.entries) {
          final matchData = entry.value;
          if (matchData['matchNumber'] == match.losersDestination) {
            updatedLosersDestination = matchData['actualMatchId'] as String?;
            break;
          }
        }
      }
      
      // 如果有更新，創建新的 Match 對象
      if (updatedNextMatchId != match.nextMatchId || updatedLosersDestination != match.losersDestination) {
        allMatches[i] = match.copyWith(
          nextMatchId: updatedNextMatchId,
          losersDestination: updatedLosersDestination,
        );
      }
    }
  }

  /// 使用 WriteBatch 一次性寫入所有數據
  Future<void> _batchWriteAllData(Tournament tournament, List<Match> allMatches) async {
    final batch = _firestore.batch();
    
    // 寫入賽程
    final tournamentRef = _firestore.collection('tournaments').doc(tournament.id);
    batch.set(tournamentRef, tournament.toFirestore());
    
    // 寫入所有比賽
    for (final match in allMatches) {
      final matchRef = _firestore.collection('matches').doc(match.id);
      batch.set(matchRef, match.toJson());
    }
    
    // 執行批次寫入
    await batch.commit();
    debugPrint('成功批次寫入雙淘汰賽程和 ${allMatches.length} 場比賽');
  }

  /// 處理雙淘汰賽比賽結束後的晉級邏輯
  Future<void> handleMatchCompletion(Match match) async {
    debugPrint('處理雙淘汰賽比賽完成: matchId=${match.id}, bracket=${match.bracket}, matchNumber=${match.matchNumber}, winner=${match.winner}');
    
    if (match.winner == null) {
      debugPrint('無法處理晉級: winner為null');
      return;
    }
    
    try {
      // 特殊處理決賽G1
      if (match.matchNumber == 'G1' && match.bracket == 'Grand Final') {
        await _handleGrandFinalCompletion(match);
        return;
      }
      
      String winnerId = match.winner == 'red' ? match.redPlayer : match.bluePlayer;
      String loserId = match.winner == 'red' ? match.bluePlayer : match.redPlayer;
      
      // 處理勝者晉級
      if (match.nextMatchId != null && match.slotInNext != null) {
        await _advanceWinner(match.nextMatchId!, match.slotInNext!, winnerId);
      }
      
      // 如果是勝組比賽，處理敗者落入敗組
      if (match.bracket == 'Winners') {
        await _handleLoserToLosersBracket(match, loserId);
      }
      
    } catch (e) {
      debugPrint('處理雙淘汰賽晉級邏輯時發生錯誤: $e');
    }
  }

  /// 處理決賽G1完成後的邏輯
  Future<void> _handleGrandFinalCompletion(Match g1Match) async {
    debugPrint('處理決賽G1完成: winner=${g1Match.winner}, redPlayer=${g1Match.redPlayer}, bluePlayer=${g1Match.bluePlayer}');
    
    if (g1Match.winner == 'red') {
      // 勝組冠軍獲勝，賽事結束
      debugPrint('勝組冠軍 ${g1Match.redPlayer} 獲勝，賽事結束');
      // 這裡可以添加賽事結束的處理邏輯，比如更新賽程狀態等
    } else if (g1Match.winner == 'blue') {
      // 敗組冠軍獲勝，需要創建決賽加賽G2
      debugPrint('敗組冠軍 ${g1Match.bluePlayer} 獲勝，創建決賽加賽G2');
      await _createGrandFinalGame2(g1Match);
    }
  }

  /// 創建決賽加賽G2
  Future<void> _createGrandFinalGame2(Match g1Match) async {
    try {
      // 默認分數結構
      final defaultScores = {
        "leftHand": 0,
        "rightHand": 0,
        "leftLeg": 0,
        "rightLeg": 0,
        "body": 0,
      };
      
      // 創建G2比賽
      final g2Match = Match(
        id: '', // 將由 Firestore 自動生成
        tournamentId: g1Match.tournamentId,
        tournamentName: g1Match.tournamentName,
        name: '${g1Match.tournamentName} - Grand Final 決賽加賽',
        matchNumber: 'G2',
        round: (g1Match.round ?? 9) + 1,
        redPlayer: g1Match.redPlayer, // 勝組冠軍
        bluePlayer: g1Match.bluePlayer, // 敗組冠軍
        status: 'ongoing', // 立即開始
        refereeNumber: g1Match.refereeNumber,
        nextMatchId: null, // 這是最終比賽
        slotInNext: null,
        winner: null,
        winReason: null,
        bracket: 'Grand Final',
        losersDestination: null,
        redScores: Map<String, int>.from(defaultScores),
        blueScores: Map<String, int>.from(defaultScores),
        currentSet: 1,
        redSetsWon: 0,
        blueSetsWon: 0,
        setResults: {},
        createdAt: DateTime.now(),
      );

      // 寫入到 Firestore
      final docRef = await _firestore.collection('matches').add(g2Match.toJson());
      debugPrint('成功創建決賽加賽G2: ${docRef.id}');
      
      // 可以選擇性地更新G1比賽的nextMatchId指向G2
      await _firestore.collection('matches').doc(g1Match.id).update({
        'basic_info.nextMatchId': docRef.id,
      });
      
      debugPrint('決賽加賽G2已創建並開始，參賽者：${g1Match.redPlayer} vs ${g1Match.bluePlayer}');
      
    } catch (e) {
      debugPrint('創建決賽加賽G2時發生錯誤: $e');
    }
  }

  /// 處理勝者晉級
  Future<void> _advanceWinner(String nextMatchId, String slotInNext, String winnerId) async {
    final docSnapshot = await _firestore.collection('matches').doc(nextMatchId).get();
    
    if (docSnapshot.exists) {
      final updates = {
        'basic_info.$slotInNext': winnerId,
      };
      
      // 檢查下一場比賽是否雙方都已就緒
      final nextMatchData = docSnapshot.data();
      final basicInfo = nextMatchData?['basic_info'] as Map<String, dynamic>? ?? {};
      
      if ((slotInNext == 'redPlayer' && basicInfo['bluePlayer'] != null && basicInfo['bluePlayer'] != '') ||
          (slotInNext == 'bluePlayer' && basicInfo['redPlayer'] != null && basicInfo['redPlayer'] != '')) {
        updates['basic_info.status'] = 'ongoing';
      }
      
      await docSnapshot.reference.update(updates);
      debugPrint('成功更新下一場比賽: $nextMatchId');
    }
  }

  /// 處理敗者落入敗組
  Future<void> _handleLoserToLosersBracket(Match match, String loserId) async {
    debugPrint('處理敗者 $loserId 落入敗組，來源比賽: ${match.id}, losersDestination: ${match.losersDestination}');
    
    if (match.losersDestination == null) {
      debugPrint('警告：比賽 ${match.id} 沒有設定 losersDestination');
      return;
    }
    
    try {
      // 直接使用 losersDestination 作為比賽 ID 查找
      final losersMatchDoc = await _firestore
          .collection('matches')
          .doc(match.losersDestination!)
          .get();
      
      if (!losersMatchDoc.exists) {
        debugPrint('錯誤：找不到敗組比賽 ${match.losersDestination}');
        return;
      }
      
      final losersMatchData = losersMatchDoc.data()!;
      final basicInfo = losersMatchData['basic_info'] as Map<String, dynamic>? ?? {};
      
      debugPrint('找到敗組比賽: ${match.losersDestination}, 當前狀態: ${basicInfo['status']}, 紅方: ${basicInfo['redPlayer']}, 藍方: ${basicInfo['bluePlayer']}');
      
      // 決定敗者應該進入的位置（紅方或藍方）
      String targetSlot;
      if (basicInfo['redPlayer'] == null || basicInfo['redPlayer'] == '') {
        targetSlot = 'redPlayer';
      } else if (basicInfo['bluePlayer'] == null || basicInfo['bluePlayer'] == '') {
        targetSlot = 'bluePlayer';
      } else {
        debugPrint('警告：敗組比賽 ${match.losersDestination} 已滿員');
        return;
      }
      
      // 更新敗組比賽
      final updates = <String, dynamic>{
        'basic_info.$targetSlot': loserId,
      };
      
      // 檢查敗組比賽是否雙方都已就緒
      if ((targetSlot == 'redPlayer' && basicInfo['bluePlayer'] != null && basicInfo['bluePlayer'] != '') ||
          (targetSlot == 'bluePlayer' && basicInfo['redPlayer'] != null && basicInfo['redPlayer'] != '')) {
        updates['basic_info.status'] = 'ongoing';
        debugPrint('敗組比賽 ${match.losersDestination} 雙方就緒，狀態更新為 ongoing');
      }
      
      await losersMatchDoc.reference.update(updates);
      debugPrint('成功將敗者 $loserId 分配到敗組比賽 ${match.losersDestination} 的 $targetSlot 位置');
      
    } catch (e) {
      debugPrint('處理敗者落入敗組時發生錯誤: $e');
    }
  }
}