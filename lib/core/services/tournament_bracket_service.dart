import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/tournament.dart';
import 'tournament_service.dart';

class TournamentBracketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _tournamentService = TournamentService();

  /// 計算大於等於n的最小2的冪
  int nextPowerOfTwo(int n) {
    return math.pow(2, (math.log(n) / math.ln2).ceil()).toInt();
  }

  /// 創建單淘汰賽（修復版）
  Future<Tournament> createSingleEliminationTournament({
    required String name,
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
    List<String>? playerNames,
    bool randomPairing = false,
  }) async {
    // 創建賽程ID
    final tournamentId = _uuid.v4();
    
    // 創建參賽者列表，使用自定義名稱或預設名稱
    final actualPlayerNames = playerNames ?? List.generate(numPlayers, (index) => 'PLAYER${index + 1}');
    final participants = List.generate(numPlayers, (index) {
      final playerName = actualPlayerNames[index];
      return {
        'id': playerName,
        'displayName': playerName,
        'userId': null,
      };
    });
    
    // 計算最接近的2的冪
    final adjustedNumPlayers = nextPowerOfTwo(numPlayers);
    
    // 計算總比賽場數 = 調整後參賽人數 - 1
    final totalMatches = adjustedNumPlayers - 1;
    
    // 計算輪空數量
    final byeCount = adjustedNumPlayers - numPlayers;
    
    // 計算第一輪比賽數量
    final firstRoundMatches = adjustedNumPlayers ~/ 2;
    
    debugPrint('創建單淘汰賽，參賽人數：$numPlayers，輪空數量：$byeCount');
    debugPrint('調整後的參賽人數：$adjustedNumPlayers，第一輪比賽數量：$firstRoundMatches');
    debugPrint('隨機配對：$randomPairing');
    
    // 第一步：建立完整的比賽樹結構
    final matchStructure = _buildCompleteMatchTree(totalMatches, adjustedNumPlayers);
    
    // 第二步：安排輪空位置（從兩端開始）
    final byePositions = _calculateByePositions(byeCount, firstRoundMatches);
    
    // 第三步：分配選手到第一輪比賽（支持隨機配對）
    final matchesWithPlayers = _assignPlayersToMatches(
      matchStructure, 
      numPlayers, 
      byePositions, 
      firstRoundMatches,
      playerNames: actualPlayerNames, // 傳遞實際的選手名稱
      randomPairing: randomPairing,
    );
    
    // 第四步：創建所有 Match 物件
    final allMatches = <Match>[];
    for (final entry in matchesWithPlayers.entries) {
      final matchData = entry.value;
      
      final match = Match(
        id: _uuid.v4(),
        name: '$name - 第${matchData['round']}輪 #${matchData['matchNumber']}',
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
      );
      
      allMatches.add(match);
      
      // 更新 matchStructure 中的實際 Match ID
      matchData['actualMatchId'] = match.id;
    }
    
    // 第五步：更新 nextMatchId 為實際的 Match ID
    _updateNextMatchIds(allMatches, matchesWithPlayers);
    
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
      matches: matchesWithPlayers,
    );
    
    // 第六步：使用 WriteBatch 一次性寫入所有數據
    await _batchWriteAllData(tournament, allMatches);
    
    return tournament;
  }
  
  /// 建立完整的比賽樹結構
  Map<String, Map<String, dynamic>> _buildCompleteMatchTree(int totalMatches, int adjustedNumPlayers) {
    final matches = <String, Map<String, dynamic>>{};
    final rounds = (math.log(adjustedNumPlayers) / math.ln2).toInt();
    
    debugPrint('建立比賽樹，總輪數：$rounds，總比賽數：$totalMatches');
    
    // 生成決賽（最後一場比賽）
    final finalMatchId = 'm$totalMatches';
    matches[finalMatchId] = {
      'round': rounds,
      'matchNumber': totalMatches.toString(),
      'redPlayer': null,
      'bluePlayer': null,
      'status': 'pending',
      'winner': null,
      'nextMatchId': null,
      'slotInNext': null,
    };
    
    // 從決賽開始，逆向生成比賽樹
    // 使用正確的比賽編號分配邏輯
    final matchesByRound = <int, List<int>>{};
    
    // 先計算每輪的比賽編號
    int matchCounter = 1;
    for (int round = 1; round <= rounds; round++) {
      final matchesInRound = adjustedNumPlayers ~/ math.pow(2, round).toInt();
      matchesByRound[round] = [];
      
      for (int i = 0; i < matchesInRound; i++) {
        if (round < rounds) { // 不是決賽
          matchesByRound[round]!.add(matchCounter);
          matchCounter++;
        } else { // 決賽
          matchesByRound[round]!.add(totalMatches);
        }
      }
    }
    
    debugPrint('每輪比賽編號分配: $matchesByRound');
    
    // 生成所有比賽（除了決賽，已經生成）
    for (int round = 1; round < rounds; round++) {
      final matchesInRound = matchesByRound[round]!;
      final nextRoundMatches = matchesByRound[round + 1]!;
      
      debugPrint('生成第 $round 輪比賽，本輪比賽編號: $matchesInRound');
      
      for (int i = 0; i < matchesInRound.length; i++) {
        final matchNumber = matchesInRound[i];
        final matchId = 'm$matchNumber';
        
        // 計算下一場比賽的編號
        final nextMatchIndex = i ~/ 2;
        final nextMatchNumber = nextRoundMatches[nextMatchIndex];
        final nextMatchId = 'm$nextMatchNumber';
        
        // 決定在下一場比賽中的位置
        final slotInNext = i % 2 == 0 ? 'redPlayer' : 'bluePlayer';
        
        debugPrint('創建比賽: matchId=$matchId (編號$matchNumber), nextMatchId=$nextMatchId (編號$nextMatchNumber), slotInNext=$slotInNext');
        
        matches[matchId] = {
          'round': round,
          'matchNumber': matchNumber.toString(),
          'redPlayer': null,
          'bluePlayer': null,
          'status': 'pending',
          'winner': null,
          'nextMatchId': nextMatchId,
          'slotInNext': slotInNext,
        };
      }
    }
    
    // 驗證所有 nextMatchId 都存在
    for (final entry in matches.entries) {
      final matchId = entry.key;
      final matchData = entry.value;
      final nextMatchId = matchData['nextMatchId'] as String?;
      
      if (nextMatchId != null && !matches.containsKey(nextMatchId)) {
        debugPrint('錯誤: 比賽 $matchId 的 nextMatchId $nextMatchId 不存在');
        throw Exception('比賽樹生成錯誤: nextMatchId $nextMatchId 不存在');
      }
    }
    
    debugPrint('比賽樹生成完成，共 ${matches.length} 場比賽');
    return matches;
  }
  
  /// 計算輪空位置（從兩端開始安排）
  List<int> _calculateByePositions(int byeCount, int firstRoundMatches) {
    final byePositions = <int>[];
    
    if (byeCount <= 0) return byePositions;
    
    debugPrint('開始計算輪空位置，輪空數量: $byeCount，第一輪比賽數量: $firstRoundMatches');
    
    // 從兩端開始安排輪空
    int leftIndex = 0;
    int rightIndex = firstRoundMatches - 1;
    bool useLeft = true;
    
    for (int i = 0; i < byeCount; i++) {
      if (useLeft) {
        byePositions.add(leftIndex);
        debugPrint('添加輪空位置 ${i + 1}: $leftIndex (左側)');
        leftIndex++;
      } else {
        byePositions.add(rightIndex);
        debugPrint('添加輪空位置 ${i + 1}: $rightIndex (右側)');
        rightIndex--;
      }
      useLeft = !useLeft;
    }
    
    byePositions.sort();
    debugPrint('最終輪空位置分配: $byePositions');
    
    return byePositions;
  }
  
  /// 分配選手到比賽中
  Map<String, Map<String, dynamic>> _assignPlayersToMatches(
    Map<String, Map<String, dynamic>> matchStructure,
    int numPlayers,
    List<int> byePositions,
    int firstRoundMatches, {
    List<String>? playerNames,
    bool randomPairing = false,
  }) {
    final matches = Map<String, Map<String, dynamic>>.from(matchStructure);
    int playerIndex = 0;
    
    // 獲取實際的選手名稱列表
    final actualPlayerNames = playerNames ?? List.generate(numPlayers, (index) => 'PLAYER${index + 1}');
    
    // 如果啟用隨機配對，則打亂選手名單
    if (randomPairing) {
      final random = math.Random();
      actualPlayerNames.shuffle(random);
      debugPrint('已啟用隨機配對，打亂後的選手名單: $actualPlayerNames');
    }
    
    // 獲取第一輪的所有比賽ID（按順序排列）
    final firstRoundMatchIds = matches.entries
        .where((entry) => entry.value['round'] == 1)
        .map((entry) => entry.key)
        .toList();
    
    // 按比賽編號排序
    firstRoundMatchIds.sort((a, b) {
      final aNum = int.parse(a.substring(1));
      final bNum = int.parse(b.substring(1));
      return aNum.compareTo(bNum);
    });
    
    debugPrint('第一輪比賽ID列表: $firstRoundMatchIds');
    debugPrint('輪空位置: $byePositions');
    debugPrint('總參賽人數: $numPlayers，第一輪比賽數: $firstRoundMatches');
    
    // 處理第一輪比賽
    for (int i = 0; i < firstRoundMatches && i < firstRoundMatchIds.length; i++) {
      final matchId = firstRoundMatchIds[i];
      
      debugPrint('處理比賽 $i: matchId=$matchId, 是否輪空=${byePositions.contains(i)}');
      
      if (byePositions.contains(i)) {
        // 輪空比賽 - 使用實際選手名稱
        if (playerIndex < numPlayers) {
          final playerName = actualPlayerNames[playerIndex];
          matches[matchId]!['redPlayer'] = playerName;
          matches[matchId]!['bluePlayer'] = 'BYE';
          matches[matchId]!['status'] = 'completed';
          matches[matchId]!['winner'] = 'red';
          matches[matchId]!['winReason'] = '對手輪空';
          
          debugPrint('輪空比賽: $playerName 自動晉級');
          
          // 自動晉級到下一場
          _advanceWinner(matches, matchId, playerName);
          
          playerIndex++;
        }
      } else {
        // 正常比賽 - 分配兩名選手，使用實際選手名稱
        String? redPlayer;
        String? bluePlayer;
        
        if (playerIndex < numPlayers) {
          redPlayer = actualPlayerNames[playerIndex];
          matches[matchId]!['redPlayer'] = redPlayer;
          debugPrint('分配紅方選手: $redPlayer 到比賽 $matchId');
          playerIndex++;
        }
        
        if (playerIndex < numPlayers) {
          bluePlayer = actualPlayerNames[playerIndex];
          matches[matchId]!['bluePlayer'] = bluePlayer;
          debugPrint('分配藍方選手: $bluePlayer 到比賽 $matchId');
          playerIndex++;
        }
        
        // 檢查是否雙方都有選手，如果有則設為 ongoing
        if (redPlayer != null && bluePlayer != null) {
          matches[matchId]!['status'] = 'ongoing';
          debugPrint('比賽 $matchId 雙方就绪 ($redPlayer vs $bluePlayer)，設為 ongoing');
        } else {
          debugPrint('比賽 $matchId 選手不足 (red: $redPlayer, blue: $bluePlayer)，保持 pending 狀態');
        }
      }
    }
    
    debugPrint('選手分配完成，共分配 $playerIndex 名選手');
    
    // 統計各狀態的比賽數量
    final ongoingCount = matches.values.where((m) => m['status'] == 'ongoing').length;
    final completedCount = matches.values.where((m) => m['status'] == 'completed').length;
    final pendingCount = matches.values.where((m) => m['status'] == 'pending').length;
    
    debugPrint('比賽狀態統計: ongoing=$ongoingCount, completed=$completedCount, pending=$pendingCount');
    
    return matches;
  }
  
  /// 處理選手晉級
  void _advanceWinner(Map<String, Map<String, dynamic>> matches, String matchId, String winnerId) {
    final match = matches[matchId]!;
    final nextMatchId = match['nextMatchId'] as String?;
    final slotInNext = match['slotInNext'] as String?;
    
    if (nextMatchId != null && slotInNext != null && matches.containsKey(nextMatchId)) {
      matches[nextMatchId]![slotInNext] = winnerId;
      
      // 檢查下一場比賽是否雙方都已就绪
      final nextMatch = matches[nextMatchId]!;
      if (nextMatch['redPlayer'] != null && 
          nextMatch['bluePlayer'] != null &&
          nextMatch['redPlayer'] != '' &&
          nextMatch['bluePlayer'] != '') {
        nextMatch['status'] = 'ongoing';
        debugPrint('下一場比賽 $nextMatchId 雙方已就绪，更新狀態為 ongoing');
      }
    }
  }
  
  /// 更新 nextMatchId 為實際的 Match ID
  void _updateNextMatchIds(List<Match> allMatches, Map<String, Map<String, dynamic>> matchStructure) {
    final matchIdMapping = <String, String>{};
    
    // 建立映射表：matchNumber -> actualMatchId
    for (final entry in matchStructure.entries) {
      final matchNumber = entry.key;
      final actualMatchId = entry.value['actualMatchId'] as String?;
      if (actualMatchId != null) {
        matchIdMapping[matchNumber] = actualMatchId;
      }
    }
    
    // 更新所有 Match 的 nextMatchId
    for (int i = 0; i < allMatches.length; i++) {
      final match = allMatches[i];
      if (match.nextMatchId != null && matchIdMapping.containsKey(match.nextMatchId)) {
        allMatches[i] = match.copyWith(
          nextMatchId: matchIdMapping[match.nextMatchId],
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
    debugPrint('成功批次寫入賽程和 ${allMatches.length} 場比賽');
  }

  /// 處理比賽結束後的晉級邏輯（增強版）
  Future<void> handleMatchCompletion(Match match) async {
    debugPrint('處理比賽完成後的晉級邏輯: matchId=${match.id}, nextMatchId=${match.nextMatchId}, slotInNext=${match.slotInNext}, winner=${match.winner}');
    
    // 如果比賽沒有下一場或沒有勝者，則不處理
    if (match.nextMatchId == null || match.slotInNext == null || match.winner == null) {
      debugPrint('無法處理晉級: nextMatchId、slotInNext或winner為null');
      return;
    }
    
    try {
      // 獲取勝者ID
      String winnerId = match.winner == 'red' ? match.redPlayer : match.bluePlayer;
      debugPrint('勝者ID: $winnerId');
      
      // 直接使用 nextMatchId 查詢下一場比賽
      final docSnapshot = await _firestore.collection('matches').doc(match.nextMatchId).get();
      
      if (docSnapshot.exists) {
        debugPrint('找到下一場比賽: ${docSnapshot.id}');
        
        // 更新下一場比賽的選手
        final updates = {
          'basic_info.${match.slotInNext}': winnerId,
        };
        
        // 檢查下一場比賽是否雙方都已就绪
        final nextMatchData = docSnapshot.data();
        final basicInfo = nextMatchData?['basic_info'] as Map<String, dynamic>? ?? {};
        
        // 獲取當前的紅藍方選手信息
        String currentRedPlayer = basicInfo['redPlayer'] ?? '';
        String currentBluePlayer = basicInfo['bluePlayer'] ?? '';
        
        // 模擬更新後的狀態
        if (match.slotInNext == 'redPlayer') {
          currentRedPlayer = winnerId;
        } else if (match.slotInNext == 'bluePlayer') {
          currentBluePlayer = winnerId;
        }
        
        debugPrint('下一場比賽選手狀態: red=$currentRedPlayer, blue=$currentBluePlayer');
        
        // 檢查雙方是否都已就绪（都不為空且不為"待定"）
        if (currentRedPlayer.isNotEmpty && currentRedPlayer != '待定' && 
            currentBluePlayer.isNotEmpty && currentBluePlayer != '待定') {
          updates['basic_info.status'] = 'ongoing';
          debugPrint('下一場比賽雙方已就绪，更新狀態為ongoing');
        } else {
          debugPrint('下一場比賽尚未就绪: red=$currentRedPlayer, blue=$currentBluePlayer');
        }
        
        await docSnapshot.reference.update(updates);
        debugPrint('成功更新下一場比賽');
        
        // 同步晉級信息到賽程集合
        if (match.tournamentId.isNotEmpty) {
          final tournamentService = TournamentService();
          final nextMatchNumber = basicInfo['matchNumber'] ?? '';
          if (nextMatchNumber.isNotEmpty) {
            await tournamentService.syncAdvancementToTournament(
              match.tournamentId,
              nextMatchNumber,
              match.slotInNext!,
              winnerId,
            );
          }
        }
        
      } else {
        debugPrint('錯誤: 找不到下一場比賽，nextMatchId=${match.nextMatchId}');
      }
    } catch (e) {
      debugPrint('處理晉級邏輯時發生錯誤: $e');
    }
  }

  // --- 雙淘汰賽相關代碼開始 ---

  // 雙淘汰賽模板 (示例，需要根據實際情況調整)
  static const Map<int, Map<String, List<Map<String, dynamic>>>> _doubleEliminationTemplates = {
    4: {
      'winnerBracket': [
        {'round': 1, 'matchNumber': 'W1', 'nextMatch': 'W3', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W2', 'nextMatch': 'W3', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'bluePlayer'},
        {'round': 2, 'matchNumber': 'W3', 'nextMatch': 'F1', 'nextSlot': 'redPlayer', 'isWinnerBracketFinal': true, 'loserNextMatch': 'L2', 'loserNextSlot': 'bluePlayer'},
      ],
      'loserBracket': [
        {'round': 1, 'matchNumber': 'L1', 'nextMatch': 'L2', 'nextSlot': 'redPlayer'},
        {'round': 2, 'matchNumber': 'L2', 'nextMatch': 'F1', 'nextSlot': 'bluePlayer', 'isLoserBracketFinal': true},
      ],
      'finalBracket': [
        {'round': 1, 'matchNumber': 'F1', 'isGrandFinal': true, 'canRematch': true}, // 假設總決賽可以重賽
      ]
    },
    8: {
      'winnerBracket': [
        // Round 1 (4場比賽)
        {'round': 1, 'matchNumber': 'W1', 'nextMatch': 'W5', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W2', 'nextMatch': 'W5', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'bluePlayer'},
        {'round': 1, 'matchNumber': 'W3', 'nextMatch': 'W6', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L2', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W4', 'nextMatch': 'W6', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L2', 'loserNextSlot': 'bluePlayer'},
        // Round 2 (2場比賽)
        {'round': 2, 'matchNumber': 'W5', 'nextMatch': 'W7', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L3', 'loserNextSlot': 'bluePlayer'},
        {'round': 2, 'matchNumber': 'W6', 'nextMatch': 'W7', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L4', 'loserNextSlot': 'bluePlayer'},
        // Round 3 (勝組決賽)
        {'round': 3, 'matchNumber': 'W7', 'nextMatch': 'F1', 'nextSlot': 'redPlayer', 'isWinnerBracketFinal': true, 'loserNextMatch': 'L6', 'loserNextSlot': 'bluePlayer'},
      ],
      'loserBracket': [
        // Round 1: W1~W4 敗者對戰 (2場)
        {'round': 1, 'matchNumber': 'L1', 'nextMatch': 'L3', 'nextSlot': 'redPlayer'}, // W1 loser vs W2 loser
        {'round': 1, 'matchNumber': 'L2', 'nextMatch': 'L4', 'nextSlot': 'redPlayer'}, // W3 loser vs W4 loser
        
        // Round 2: L1~L2勝者 vs W5~W6敗者 (2場)
        {'round': 2, 'matchNumber': 'L3', 'nextMatch': 'L5', 'nextSlot': 'redPlayer'}, // L1 winner vs W5 loser
        {'round': 2, 'matchNumber': 'L4', 'nextMatch': 'L5', 'nextSlot': 'bluePlayer'}, // L2 winner vs W6 loser
      
        // Round 3: 敗部準決賽 (1場)
        {'round': 3, 'matchNumber': 'L5', 'nextMatch': 'L6', 'nextSlot': 'redPlayer'}, // L3 winner vs L4 winner
      
        // Round 4: 敗部決賽 (1場)
        {'round': 4, 'matchNumber': 'L6', 'nextMatch': 'F1', 'nextSlot': 'bluePlayer', 'isLoserBracketFinal': true}, // L5 winner vs W7 loser
      ],
      'finalBracket': [
        {'round': 1, 'matchNumber': 'F1', 'isGrandFinal': true, 'canRematch': true, 'nextMatch': 'F2', 'nextSlot': 'redPlayer'},
        {'round': 2, 'matchNumber': 'F2', 'isGrandFinalRematch': true, 'canRematch': false}, // 重賽場次
      ]
    },
    16: {
      'winnerBracket': [
        // Round 1 (8場比賽)
        {'round': 1, 'matchNumber': 'W1', 'nextMatch': 'W9', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W2', 'nextMatch': 'W9', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L1', 'loserNextSlot': 'bluePlayer'},
        {'round': 1, 'matchNumber': 'W3', 'nextMatch': 'W10', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L2', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W4', 'nextMatch': 'W10', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L2', 'loserNextSlot': 'bluePlayer'},
        {'round': 1, 'matchNumber': 'W5', 'nextMatch': 'W11', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L3', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W6', 'nextMatch': 'W11', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L3', 'loserNextSlot': 'bluePlayer'},
        {'round': 1, 'matchNumber': 'W7', 'nextMatch': 'W12', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L4', 'loserNextSlot': 'redPlayer'},
        {'round': 1, 'matchNumber': 'W8', 'nextMatch': 'W12', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L4', 'loserNextSlot': 'bluePlayer'},
        // Round 2 (4場比賽)
        {'round': 2, 'matchNumber': 'W9', 'nextMatch': 'W13', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L5', 'loserNextSlot': 'bluePlayer'},
        {'round': 2, 'matchNumber': 'W10', 'nextMatch': 'W13', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L6', 'loserNextSlot': 'bluePlayer'},
        {'round': 2, 'matchNumber': 'W11', 'nextMatch': 'W14', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L7', 'loserNextSlot': 'bluePlayer'},
        {'round': 2, 'matchNumber': 'W12', 'nextMatch': 'W14', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L8', 'loserNextSlot': 'bluePlayer'},
        // Round 3 (2場比賽)
        {'round': 3, 'matchNumber': 'W13', 'nextMatch': 'W15', 'nextSlot': 'redPlayer', 'loserNextMatch': 'L11', 'loserNextSlot': 'bluePlayer'},
        {'round': 3, 'matchNumber': 'W14', 'nextMatch': 'W15', 'nextSlot': 'bluePlayer', 'loserNextMatch': 'L12', 'loserNextSlot': 'bluePlayer'},
        // Round 4 (勝組決賽)
        {'round': 4, 'matchNumber': 'W15', 'nextMatch': 'F1', 'nextSlot': 'redPlayer', 'isWinnerBracketFinal': true, 'loserNextMatch': 'L14', 'loserNextSlot': 'bluePlayer'},
      ],
      'loserBracket': [
        // Round 1: W1~W8 敗者對戰 (4場)
        {'round': 1, 'matchNumber': 'L1', 'nextMatch': 'L5', 'nextSlot': 'redPlayer'}, // W1 loser vs W2 loser
        {'round': 1, 'matchNumber': 'L2', 'nextMatch': 'L6', 'nextSlot': 'redPlayer'}, // W3 loser vs W4 loser
        {'round': 1, 'matchNumber': 'L3', 'nextMatch': 'L7', 'nextSlot': 'redPlayer'}, // W5 loser vs W6 loser
        {'round': 1, 'matchNumber': 'L4', 'nextMatch': 'L8', 'nextSlot': 'redPlayer'}, // W7 loser vs W8 loser
        
        // Round 2: L1~L4勝者 vs W9~W12敗者 (4場)
        {'round': 2, 'matchNumber': 'L5', 'nextMatch': 'L9', 'nextSlot': 'redPlayer'},  // L1 winner vs W9 loser
        {'round': 2, 'matchNumber': 'L6', 'nextMatch': 'L9', 'nextSlot': 'bluePlayer'}, // L2 winner vs W10 loser
        {'round': 2, 'matchNumber': 'L7', 'nextMatch': 'L10', 'nextSlot': 'redPlayer'}, // L3 winner vs W11 loser
        {'round': 2, 'matchNumber': 'L8', 'nextMatch': 'L10', 'nextSlot': 'bluePlayer'}, // L4 winner vs W12 loser
        
        // Round 3: L5~L8勝者互打 (2場)
        {'round': 3, 'matchNumber': 'L9', 'nextMatch': 'L11', 'nextSlot': 'redPlayer'},  // L5 winner vs L6 winner
        {'round': 3, 'matchNumber': 'L10', 'nextMatch': 'L12', 'nextSlot': 'redPlayer'}, // L7 winner vs L8 winner
        
        // Round 4: L9~L10勝者 vs W13~W14敗者 (2場)
        {'round': 4, 'matchNumber': 'L11', 'nextMatch': 'L13', 'nextSlot': 'redPlayer'}, // L9 winner vs W13 loser
        {'round': 4, 'matchNumber': 'L12', 'nextMatch': 'L13', 'nextSlot': 'bluePlayer'}, // L10 winner vs W14 loser
        
        // Round 5: 敗部準決賽 (1場)
        {'round': 5, 'matchNumber': 'L13', 'nextMatch': 'L14', 'nextSlot': 'redPlayer'}, // L11 winner vs L12 winner
        
        // Round 6: 敗部決賽 (1場)
        {'round': 6, 'matchNumber': 'L14', 'nextMatch': 'F1', 'nextSlot': 'bluePlayer', 'isLoserBracketFinal': true}, // L13 winner vs W15 loser
      ],
      'finalBracket': [
        {'round': 1, 'matchNumber': 'F1', 'isGrandFinal': true, 'canRematch': true, 'nextMatch': 'F2', 'nextSlot': 'redPlayer'},
        {'round': 2, 'matchNumber': 'F2', 'isGrandFinalRematch': true, 'canRematch': false}, // 重賽場次
      ]
    },
  };

  Future<Tournament> createDoubleEliminationTournament({
    required String name,
    required int numPlayers,
    int? targetPoints,
    int? matchMinutes,
    List<String>? playerNames,
    bool randomPairing = false,
  }) async {
    if (numPlayers < 3) {
      throw ArgumentError('雙淘汰賽參賽人數至少需要3人');
    }
    
    // 檢查是否有預定義模板，如果沒有則動態生成
    Map<String, List<Map<String, dynamic>>> template;
    if (_doubleEliminationTemplates.containsKey(numPlayers)) {
      template = _doubleEliminationTemplates[numPlayers]!;
      debugPrint('使用預定義的 $numPlayers 人雙淘汰賽模板');
    } else {
      template = _generateDoubleEliminationTemplate(numPlayers);
      debugPrint('動態生成 $numPlayers 人雙淘汰賽模板');
    }

    final tournamentId = _uuid.v4();
    final actualPlayerNames = playerNames ?? List.generate(numPlayers, (index) => 'PLAYER${index + 1}');
    final participants = List.generate(numPlayers, (index) {
      final playerName = actualPlayerNames[index];
      return {
        'id': playerName,
        'displayName': playerName,
        'userId': null,
      };
    });

    final allMatches = <Match>[];
    final matchStructure = <String, Map<String, dynamic>>{};
    
    // 計算輪空數量和位置
    final adjustedNumPlayers = nextPowerOfTwo(numPlayers);
    final byeCount = adjustedNumPlayers - numPlayers;
    debugPrint('雙淘汰賽參數: 實際人數=$numPlayers, 調整後人數=$adjustedNumPlayers, 輪空數量=$byeCount');

    // 創建勝者組比賽
    for (final matchData in template['winnerBracket']!) {
      final match = _createDoubleEliminationMatch(
        tournamentId: tournamentId,
        tournamentName: name,
        matchData: matchData,
        bracket: 'winner',
        // targetPoints: targetPoints, // Removed
        // matchMinutes: matchMinutes, // Removed
      );
      allMatches.add(match);
      matchStructure[match.matchNumber] = {
        ...matchData, 
        'actualMatchId': match.id, 
        'status': 'pending',
        'redPlayer': null,
        'bluePlayer': null,
      };
    }

    // 創建敗者組比賽
    for (final matchData in template['loserBracket']!) {
      final match = _createDoubleEliminationMatch(
        tournamentId: tournamentId,
        tournamentName: name,
        matchData: matchData,
        bracket: 'loser',
        // targetPoints: targetPoints, // Removed
        // matchMinutes: matchMinutes, // Removed
      );
      allMatches.add(match);
      matchStructure[match.matchNumber] = {
        ...matchData, 
        'actualMatchId': match.id, 
        'status': 'pending',
        'redPlayer': null,
        'bluePlayer': null,
      };
    }

    // 創建決賽
    for (final matchData in template['finalBracket']!) {
      final isGrandFinal = matchData['isGrandFinal'] ?? false;
      final isGrandFinalRematch = matchData['isGrandFinalRematch'] ?? false;
      
      final match = _createDoubleEliminationMatch(
        tournamentId: tournamentId,
        tournamentName: name,
        matchData: matchData,
        bracket: 'final',
        isGrandFinal: isGrandFinal,
        isGrandFinalRematch: isGrandFinalRematch,
      );
      allMatches.add(match);
      matchStructure[match.matchNumber] = {
        ...matchData, 
        'actualMatchId': match.id, 
        'status': 'pending',
        'redPlayer': null,
        'bluePlayer': null,
      };
    }
    
    // 更新 nextMatchId 和 loserNextMatchId（在分配選手之前）
    _updateDoubleEliminationNextMatchIds(allMatches, matchStructure);
    
    // 創建batch用於處理輪空晉級的數據庫更新
    final batch = _firestore.batch();
    
    // 分配選手到第一輪勝者組比賽（支持輪空）
    await _assignPlayersToDoubleEliminationWithByes(
      matchStructure,
      allMatches,
      actualPlayerNames,
      byeCount,
      adjustedNumPlayers,
      randomPairing,
      batch,
    );

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
      matches: matchStructure, // 這裡的 matches 結構可能需要調整以適應雙淘汰賽
    );

    // 先寫入賽程和比賽基本數據
    await _batchWriteAllData(tournament, allMatches);
    
    // 然後提交輪空晉級的更新
    await batch.commit();
    return tournament;
  }

  Match _createDoubleEliminationMatch({
    required String tournamentId,
    required String tournamentName,
    required Map<String, dynamic> matchData,
    required String bracket, // 'winner', 'loser', 'final'
    bool isGrandFinal = false,
    bool isGrandFinalRematch = false,
  }) {
    final matchId = _uuid.v4();
    return Match(
      id: matchId,
      name: '$tournamentName - ${bracket == 'winner' ? '勝者組' : bracket == 'loser' ? '敗者組' : '決賽'} - #${matchData['matchNumber']}',
      matchNumber: matchData['matchNumber'] as String,
      redPlayer: '',
      bluePlayer: '',
      refereeNumber: '裁判',
      status: 'pending',
      redScores: <String, int>{'total': 0, 'leftHand': 0, 'rightHand': 0, 'leftLeg': 0, 'rightLeg': 0, 'body': 0},
      blueScores: <String, int>{'total': 0, 'leftHand': 0, 'rightHand': 0, 'leftLeg': 0, 'rightLeg': 0, 'body': 0},
      currentSet: 1,
      redSetsWon: 0,
      blueSetsWon: 0,
      setResults: <String, String>{},
      createdAt: DateTime.now(),
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      round: matchData['round'] as int?,
      nextMatchId: matchData['nextMatch'] as String?,
      slotInNext: matchData['nextSlot'] as String?,
      loserNextMatchId: matchData['loserNextMatch'] as String?, // 敗者組的下一場比賽
      loserSlotInNext: matchData['loserNextSlot'] as String?, // 敗者在下一場敗者組比賽的位置
      bracket: bracket,
      isGrandFinal: isGrandFinal,
      isGrandFinalRematch: isGrandFinalRematch,
    );
  }



  void _updateDoubleEliminationNextMatchIds(List<Match> allMatches, Map<String, Map<String, dynamic>> matchStructure) {
    final matchIdMapping = <String, String>{};
    for (final entry in matchStructure.entries) {
      matchIdMapping[entry.key] = entry.value['actualMatchId'] as String;
    }

    for (int i = 0; i < allMatches.length; i++) {
      final match = allMatches[i];
      String? nextMatchActualId;
      String? loserNextMatchActualId;

      if (match.nextMatchId != null && matchIdMapping.containsKey(match.nextMatchId)) {
        nextMatchActualId = matchIdMapping[match.nextMatchId];
      }
      if (match.loserNextMatchId != null && matchIdMapping.containsKey(match.loserNextMatchId)) {
        loserNextMatchActualId = matchIdMapping[match.loserNextMatchId];
      }
      allMatches[i] = match.copyWith(
        nextMatchId: nextMatchActualId,
        loserNextMatchId: loserNextMatchActualId,
      );
    }
  }

  /// 判斷選手是否為輪空
  bool isBye(String? playerId) => playerId == null || playerId.trim().isEmpty || playerId == '輪空';

  Future<void> handleDoubleEliminationMatchCompletion(Match completedMatch) async {
    // 1. 獲取勝者和敗者
    // 2. 勝者晉級到下一輪勝者組比賽 (如果有的話)
    // 3. 敗者掉入敗者組的相應比賽 (如果有的話)
    // 4. 更新相關比賽的狀態和選手
    // 5. 如果是決賽，可能需要處理重賽邏輯 (如果敗者組冠軍擊敗勝者組冠軍)
    // 6. 更新賽程狀態
    debugPrint('處理雙淘汰賽比賽完成: ${completedMatch.id}');

    if (completedMatch.winner == null) {
        debugPrint('比賽 ${completedMatch.id} 沒有勝者，無法處理晉級。');
        return;
    }

    final winnerId = completedMatch.winner == 'red' ? completedMatch.redPlayer : completedMatch.bluePlayer;
    final loserId = completedMatch.winner == 'red' ? completedMatch.bluePlayer : completedMatch.redPlayer;

    // 確保 winnerId 和 loserId 不是空字符串
    if (isBye(winnerId) && !isBye(loserId)) {
      // 如果 winnerId 無效但 loserId 有效，這不符合正常比賽結束的邏輯，記錄錯誤
      debugPrint('錯誤：比賽 ${completedMatch.id} 結果異常，勝者ID無效但敗者ID有效。');
      return;
    }
    // 如果 loserId 是輪空但 winnerId 有效，這是正常的輪空晉級情況
    if (isBye(loserId) && !isBye(winnerId)) {
      debugPrint('比賽 ${completedMatch.id}：對手輪空，勝者 $winnerId 自動晉級。');
    }

    final batch = _firestore.batch();
    bool tournamentEnded = false;
    String? loserBracketWinnerIdForRematch; // 用於記錄敗者組決賽勝者，以判斷總決賽是否需要重賽

    // 更新當前完成的比賽狀態
    final completedMatchRef = _firestore.collection('matches').doc(completedMatch.id);
    final completedMatchUpdate = <String, dynamic>{
        'basic_info.status': 'completed',
        'basic_info.winner': winnerId,
        // 'basic_info.winReason': completedMatch.winReason, // 假設 winReason 已經在 Match 對象中
        'timestamps.completedAt': FieldValue.serverTimestamp(),
    };
    // 如果是總決賽的第一場，且勝者組冠軍獲勝，則 isGrandFinal 保持 true
    // 如果是總決賽的第一場，且敗者組冠軍獲勝，且允許重賽，則 isGrandFinal 變為 false，準備重賽
    if (completedMatch.isGrandFinal && completedMatch.bracket == 'final') {
        final tournamentDoc = await _firestore.collection('tournaments').doc(completedMatch.tournamentId).get();
        final tournamentData = tournamentDoc.data();
        final numPlayers = tournamentData?['numPlayers'] as int? ?? 0;

        final winnerBracketFinalMatchSnapshot = await _firestore.collection('matches')
            .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
            .where('basic_info.isWinnerBracketFinal', isEqualTo: true)
            .limit(1)
            .get();
        
        if (winnerBracketFinalMatchSnapshot.docs.isNotEmpty) {
            final winnerBracketFinalWinner = winnerBracketFinalMatchSnapshot.docs.first.data()['basic_info']['winner'] == 'red' 
                                            ? winnerBracketFinalMatchSnapshot.docs.first.data()['basic_info']['redPlayer'] 
                                            : winnerBracketFinalMatchSnapshot.docs.first.data()['basic_info']['bluePlayer'];
            
            final loserBracketFinalMatchSnapshot = await _firestore.collection('matches')
                .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
                .where('basic_info.isLoserBracketFinal', isEqualTo: true)
                .limit(1)
                .get();
            if (loserBracketFinalMatchSnapshot.docs.isNotEmpty) {
                 loserBracketWinnerIdForRematch = loserBracketFinalMatchSnapshot.docs.first.data()['basic_info']['winner'] == 'red'
                                                ? loserBracketFinalMatchSnapshot.docs.first.data()['basic_info']['redPlayer']
                                                : loserBracketFinalMatchSnapshot.docs.first.data()['basic_info']['bluePlayer'];
            }

            // 判斷F1中誰是勝者組冠軍，誰是敗者組冠軍
            // 通常F1的redPlayer是勝者組冠軍，bluePlayer是敗者組冠軍
            String? winnerBracketChampionInF1;
            String? loserBracketChampionInF1;
            
            if (completedMatch.redPlayer == winnerBracketFinalWinner) {
                winnerBracketChampionInF1 = completedMatch.redPlayer;
                loserBracketChampionInF1 = completedMatch.bluePlayer;
            } else if (completedMatch.bluePlayer == winnerBracketFinalWinner) {
                winnerBracketChampionInF1 = completedMatch.bluePlayer;
                loserBracketChampionInF1 = completedMatch.redPlayer;
            } else {
                // 如果都不匹配，按照預設邏輯
                winnerBracketChampionInF1 = completedMatch.redPlayer;
                loserBracketChampionInF1 = completedMatch.bluePlayer;
            }
            
            bool currentGrandFinalCanRematch = _doubleEliminationTemplates[numPlayers]!['finalBracket']![0]['canRematch'] ?? false;
            
            debugPrint('F1決賽分析: 勝者組冠軍=$winnerBracketChampionInF1, 敗者組冠軍=$loserBracketChampionInF1, 比賽勝者=$winnerId, 可重賽=$currentGrandFinalCanRematch');

            if (winnerId == loserBracketChampionInF1 && currentGrandFinalCanRematch) { // 敗者組冠軍贏了第一場總決賽
                completedMatchUpdate['basic_info.isGrandFinal'] = false; // 標記第一場結束，準備 F2
                
                // 啟動F2比賽
                await _activateRematchIfExists(completedMatch.tournamentId, winnerBracketChampionInF1!, winnerId, batch);
                
                debugPrint('總決賽第一場由敗者組冠軍 $winnerId 獲勝，已啟動重賽F2。');
            } else {
                tournamentEnded = true; // 勝者組冠軍獲勝，或不允許重賽，或敗者組冠軍輸了
                debugPrint('總決賽結束: 勝者組冠軍獲勝或不允許重賽，賽程結束。');
            }
        } else {
            tournamentEnded = true; // 找不到勝者組決賽信息，直接結束
        }
    } else if (completedMatch.bracket == 'final' && (completedMatch.isGrandFinalRematch || !completedMatch.isGrandFinal)) {
        // 這是總決賽的第二場 (rematch)，無論誰贏都結束
        tournamentEnded = true;
    }

    batch.update(completedMatchRef, completedMatchUpdate);
    await TournamentService().syncMatchToTournament(completedMatch.tournamentId, completedMatch.matchNumber, {
        'status': 'completed',
        'winner': winnerId,
        // 'winReason': completedMatch.winReason,
        'redPlayer': completedMatch.redPlayer,
        'bluePlayer': completedMatch.bluePlayer,
    });


    // --- 勝者晉級 ---
    // 額外檢查：確保使用模板中定義的正確勝者下一場比賽
    String? nextMatchId = completedMatch.nextMatchId;
    String? slotInNext = completedMatch.slotInNext;
    
    // 如果勝者下一場比賽信息缺失或可能不正確，嘗試從預定義模板中查找
    // 對於敗者組比賽，或者當 nextMatchId 與模板中定義的不一致時，都需要從模板中查找
    debugPrint('檢查比賽 ${completedMatch.id} (${completedMatch.matchNumber}) 的勝者晉級路徑，當前設置：nextMatchId=$nextMatchId, slotInNext=$slotInNext');
    if (completedMatch.bracket == 'loser' || completedMatch.matchNumber.startsWith('L')) {
        // 獲取賽程信息
        final tournamentDoc = await _firestore.collection('tournaments').doc(completedMatch.tournamentId).get();
        final numPlayers = tournamentDoc.data()?['numPlayers'] as int? ?? 0;
        
        if (_doubleEliminationTemplates.containsKey(numPlayers)) {
            final template = _doubleEliminationTemplates[numPlayers]!;
            // 在敗者組模板中查找當前比賽
            List<Map<String, dynamic>> bracketToSearch = [];
            if (completedMatch.matchNumber.startsWith('L')) {
                bracketToSearch = template['loserBracket']!;
            } else if (completedMatch.matchNumber.startsWith('W')) {
                bracketToSearch = template['winnerBracket']!;
            }
            
            for (final matchData in bracketToSearch) {
                if (matchData['matchNumber'] == completedMatch.matchNumber) {
                    // 找到對應的下一場比賽信息
                    final nextMatch = matchData['nextMatch'] as String?;
                    final nextSlot = matchData['nextSlot'] as String?;
                    
                    if (nextMatch != null && nextSlot != null) {
                        debugPrint('從模板中找到勝者下一場比賽: $nextMatch, 槽位: $nextSlot');
                        
                        // 查找下一場比賽的actualMatchId
                        String? templateNextMatchId;
                        
                        // 先在敗者組查找
                        for (final nextMatchData in template['loserBracket']!) {
                            if (nextMatchData['matchNumber'] == nextMatch) {
                                // 獲取所有比賽
                                final allMatchesSnapshot = await _firestore
                                    .collection('matches')
                                    .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
                                    .where('basic_info.matchNumber', isEqualTo: nextMatch)
                                    .get();
                                
                                if (allMatchesSnapshot.docs.isNotEmpty) {
                                    templateNextMatchId = allMatchesSnapshot.docs.first.id;
                                    debugPrint('從敗者組模板找到下一場比賽的actualMatchId: $templateNextMatchId');
                                }
                                break;
                            }
                        }
                        
                        // 如果在敗者組沒找到，嘗試在決賽組查找
                        if (templateNextMatchId == null) {
                            for (final finalMatchData in template['finalBracket']!) {
                                if (finalMatchData['matchNumber'] == nextMatch) {
                                    // 獲取所有比賽
                                    final allMatchesSnapshot = await _firestore
                                        .collection('matches')
                                        .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
                                        .where('basic_info.matchNumber', isEqualTo: nextMatch)
                                        .get();
                                    
                                    if (allMatchesSnapshot.docs.isNotEmpty) {
                                        templateNextMatchId = allMatchesSnapshot.docs.first.id;
                                        debugPrint('從決賽組模板找到下一場比賽的actualMatchId: $templateNextMatchId');
                                    }
                                    break;
                                }
                            }
                        }
                        
                        if (templateNextMatchId != null) {
                            debugPrint('從模板更新晉級路徑：原路徑 nextMatchId=$nextMatchId, slotInNext=$slotInNext');
                            nextMatchId = templateNextMatchId;
                            slotInNext = nextSlot;
                            debugPrint('新路徑 nextMatchId=$nextMatchId, slotInNext=$slotInNext');
                        } else {
                            debugPrint('警告：無法從模板中找到比賽 ${completedMatch.matchNumber} 的下一場比賽 $nextMatch 的實際 ID');
                        }
                        
                        break;
                    }
                }
            }
        }
    }
    
    if (!isBye(winnerId) && nextMatchId != null && slotInNext != null) {
      debugPrint('準備同步勝者 $winnerId 到下一場比賽：nextMatchId=$nextMatchId, slotInNext=$slotInNext');
      final nextMatchRef = _firestore.collection('matches').doc(nextMatchId);
      final updates = <String, dynamic>{'basic_info.$slotInNext': winnerId};

      final nextMatchDoc = await nextMatchRef.get();
      if (nextMatchDoc.exists) {
        final nextMatchData = nextMatchDoc.data()?['basic_info'] as Map<String, dynamic>?;
        if (nextMatchData != null) {
          final otherSlot = slotInNext == 'redPlayer' ? 'bluePlayer' : 'redPlayer';
          final otherPlayer = nextMatchData[otherSlot];
          if (!isBye(otherPlayer)) {
            updates['basic_info.status'] = 'ongoing';
            debugPrint('勝者晉級：下一場比賽 $nextMatchId 對方選手 $otherPlayer 已就緒，更新狀態為 ongoing');
          } else {
            debugPrint('勝者晉級：下一場比賽 $nextMatchId 等待對方選手。');
          }
        }
      }
      batch.update(nextMatchRef, updates);

      final nextMatchNumber = nextMatchDoc.data()?['basic_info']?['matchNumber'] as String?;
      if (nextMatchNumber != null) {
        await TournamentService().syncAdvancementToTournament(
          completedMatch.tournamentId,
          nextMatchNumber,
          slotInNext,
          winnerId,
          newStatus: updates['basic_info.status'] as String?,
        );
      }

    } else if (completedMatch.bracket == 'winner' || (completedMatch.bracket == 'final' && !tournamentEnded)) {
        // 如果是勝者組的最後一場，或者總決賽還沒結束（意味著勝者是勝者組冠軍，且敗者組冠軍贏了第一場總決賽，需要重賽）
        // 這種情況下，勝者已經是冠軍或進入總決賽重賽，不需要再晉級
        debugPrint('勝者 $winnerId 已是冠軍或進入總決賽重賽，無需晉級。');
    } else {
        // 如果沒有下一場比賽，且不是總決賽的結束，那麼這位勝者就是賽程的總冠軍
        tournamentEnded = true;
    }

    // --- 敗者處理 ---
    debugPrint('敗者處理開始: loserId=$loserId, loserNextMatchId=${completedMatch.loserNextMatchId}, loserSlotInNext=${completedMatch.loserSlotInNext}, bracket=${completedMatch.bracket}');
    
    // 額外檢查：確保使用模板中定義的正確敗者下一場比賽
    String? loserNextMatchId = completedMatch.loserNextMatchId;
    String? loserSlotInNext = completedMatch.loserSlotInNext;
    
    // 如果敗者下一場比賽信息缺失，嘗試從預定義模板中查找
    if ((loserNextMatchId == null || loserSlotInNext == null) && completedMatch.bracket == 'winner') {
        // 獲取賽程信息
        final tournamentDoc = await _firestore.collection('tournaments').doc(completedMatch.tournamentId).get();
        final numPlayers = tournamentDoc.data()?['numPlayers'] as int? ?? 0;
        
        if (_doubleEliminationTemplates.containsKey(numPlayers)) {
            final template = _doubleEliminationTemplates[numPlayers]!;
            // 在勝者組模板中查找當前比賽
            for (final matchData in template['winnerBracket']!) {
                if (matchData['matchNumber'] == completedMatch.matchNumber) {
                    // 找到對應的敗者下一場比賽信息
                    final loserNextMatch = matchData['loserNextMatch'] as String?;
                    final loserNextSlot = matchData['loserNextSlot'] as String?;
                    
                    if (loserNextMatch != null && loserNextSlot != null) {
                        // 查找敗者下一場比賽的actualMatchId
                        for (final loserMatchData in template['loserBracket']!) {
                            if (loserMatchData['matchNumber'] == loserNextMatch) {
                                // 獲取所有比賽
                                final allMatchesSnapshot = await _firestore
                                    .collection('matches')
                                    .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
                                    .where('basic_info.matchNumber', isEqualTo: loserNextMatch)
                                    .get();
                                
                                if (allMatchesSnapshot.docs.isNotEmpty) {
                                    loserNextMatchId = allMatchesSnapshot.docs.first.id;
                                    loserSlotInNext = loserNextSlot;
                                    debugPrint('從預定義模板找到敗者下一場比賽: matchNumber=$loserNextMatch, actualMatchId=$loserNextMatchId, slot=$loserSlotInNext');
                                }
                                break;
                            }
                        }
                    }
                    break;
                }
            }
        }
    }
    
    if (!isBye(loserId) && loserNextMatchId != null && loserSlotInNext != null) {
        final loserNextMatchRef = _firestore.collection('matches').doc(loserNextMatchId);
        final loserUpdates = <String, dynamic>{};
        loserUpdates['basic_info.$loserSlotInNext'] = loserId; // loserId 在這裡保證非空

        // 檢查敗者組下一場比賽是否雙方選手都已確定，如果是，則更新狀態為 ongoing
        final loserNextMatchDoc = await loserNextMatchRef.get();
        if (loserNextMatchDoc.exists) {
            final loserNextMatchData = loserNextMatchDoc.data()?['basic_info'] as Map<String, dynamic>?;
            final otherSlot = loserSlotInNext == 'redPlayer' ? 'bluePlayer' : 'redPlayer';
            final otherPlayer = loserNextMatchData?[otherSlot];

            if (!isBye(otherPlayer)) {
                loserUpdates['basic_info.status'] = 'ongoing';
                debugPrint('敗者組下一場比賽：對方選手 $otherPlayer 已就緒，更新狀態為 ongoing');
            } else {
                loserUpdates['basic_info.status'] = 'ongoing';
                debugPrint('敗者組下一場比賽：對方選手為輪空或尚未確定，比賽狀態更新為 ongoing，準備自動晉級');
            }
        } else {
            debugPrint('錯誤：敗者下一場比賽的文檔 $loserNextMatchId 不存在！');
        }
        batch.update(loserNextMatchRef, loserUpdates);
        
        // 獲取敗者組下一場比賽的matchNumber
        final loserNextMatchNumber = loserNextMatchDoc.data()?['basic_info']?['matchNumber'] as String?;
        if (loserNextMatchNumber != null) {
            await TournamentService().syncAdvancementToTournament(
                completedMatch.tournamentId,
                loserNextMatchNumber,
                loserSlotInNext, // 使用可能從模板中找到的正確槽位
                loserId, // loserId 在這裡保證非空
                newStatus: loserUpdates['basic_info.status'] as String?,
            );
        } else {
            // 如果無法從文檔獲取matchNumber，嘗試從模板中獲取
            final tournamentDoc = await _firestore.collection('tournaments').doc(completedMatch.tournamentId).get();
            final numPlayers = tournamentDoc.data()?['numPlayers'] as int? ?? 0;
            
            if (_doubleEliminationTemplates.containsKey(numPlayers)) {
                final template = _doubleEliminationTemplates[numPlayers]!;
                for (final loserMatchData in template['loserBracket']!) {
                    // 通過比較actualMatchId找到對應的matchNumber
                    if (loserMatchData['actualMatchId'] == loserNextMatchId) {
                        final templateMatchNumber = loserMatchData['matchNumber'] as String?;
                        if (templateMatchNumber != null) {
                            await TournamentService().syncAdvancementToTournament(
                                completedMatch.tournamentId,
                                templateMatchNumber,
                                loserSlotInNext,
                                loserId,
                                newStatus: loserUpdates['basic_info.status'] as String?,
                            );
                            debugPrint('使用模板中的matchNumber $templateMatchNumber 進行敗者晉級同步');
                        }
                        break;
                    }
                }
            }
            
            if (loserNextMatchNumber == null) {
                debugPrint('警告：無法獲取敗者組下一場比賽的matchNumber，跳過賽程同步');
            }
        }
        debugPrint('敗者 $loserId 成功進入敗者組比賽 $loserNextMatchId 的 $loserSlotInNext 位置');
    } else if (loserId.isNotEmpty && completedMatch.bracket == 'winner') {
        // 如果是勝者組比賽的敗者，但沒有 loserNextMatchId 或 loserSlotInNext，嘗試從模板中查找
        debugPrint('勝者組比賽 ${completedMatch.id} 的敗者 $loserId 未找到有效的敗者組下一場比賽路徑，嘗試從模板中查找。');
        
        // 獲取賽程信息
        final tournamentDoc = await _firestore.collection('tournaments').doc(completedMatch.tournamentId).get();
        final numPlayers = tournamentDoc.data()?['numPlayers'] as int? ?? 0;
        
        if (_doubleEliminationTemplates.containsKey(numPlayers)) {
            final template = _doubleEliminationTemplates[numPlayers]!;
            // 在勝者組模板中查找當前比賽
            for (final matchData in template['winnerBracket']!) {
                if (matchData['matchNumber'] == completedMatch.matchNumber) {
                    // 找到對應的敗者下一場比賽信息
                    final loserNextMatch = matchData['loserNextMatch'] as String?;
                    final loserNextSlot = matchData['loserNextSlot'] as String?;
                    
                    if (loserNextMatch != null && loserNextSlot != null) {
                        debugPrint('從模板中找到敗者下一場比賽: $loserNextMatch, 槽位: $loserNextSlot');
                        
                        // 查找敗者下一場比賽的actualMatchId
                        String? loserNextMatchId;
                        for (final loserMatchData in template['loserBracket']!) {
                            if (loserMatchData['matchNumber'] == loserNextMatch) {
                                // 獲取所有比賽
                                final allMatchesSnapshot = await _firestore
                                    .collection('matches')
                                    .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
                                    .where('basic_info.matchNumber', isEqualTo: loserNextMatch)
                                    .get();
                                
                                if (allMatchesSnapshot.docs.isNotEmpty) {
                                    loserNextMatchId = allMatchesSnapshot.docs.first.id;
                                    debugPrint('找到敗者下一場比賽的actualMatchId: $loserNextMatchId');
                                    
                                    // 更新敗者下一場比賽
                                    final loserNextMatchRef = _firestore.collection('matches').doc(loserNextMatchId);
                                    final loserUpdates = <String, dynamic>{};
                                    loserUpdates['basic_info.$loserNextSlot'] = loserId;
                                    
                                    // 檢查敗者組下一場比賽是否雙方選手都已確定
                                    final loserNextMatchDoc = await loserNextMatchRef.get();
                                    if (loserNextMatchDoc.exists) {
                                        final loserNextMatchData = loserNextMatchDoc.data()?['basic_info'] as Map<String, dynamic>?;
                                        final otherSlot = loserNextSlot == 'redPlayer' ? 'bluePlayer' : 'redPlayer';
                                        final otherPlayer = loserNextMatchData?[otherSlot];
                                        
                                        if (!isBye(otherPlayer)) {
                                            loserUpdates['basic_info.status'] = 'ongoing';
                                            debugPrint('敗者組下一場比賽：對方選手 $otherPlayer 已就緒，更新狀態為 ongoing');
                                        } else {
                                            loserUpdates['basic_info.status'] = 'ongoing';
                                            debugPrint('敗者組下一場比賽：對方選手為輪空或尚未確定，比賽狀態更新為 ongoing，準備自動晉級');
                                        }
                                        
                                        batch.update(loserNextMatchRef, loserUpdates);
                                        
                                        // 同步到賽程
                                        await TournamentService().syncAdvancementToTournament(
                                            completedMatch.tournamentId,
                                            loserNextMatch,
                                            loserNextSlot,
                                            loserId,
                                            newStatus: loserUpdates['basic_info.status'] as String?,
                                        );
                                        
                                        debugPrint('敗者 $loserId 成功進入敗者組比賽 $loserNextMatchId 的 $loserNextSlot 位置');
                                    } else {
                                        debugPrint('錯誤：敗者下一場比賽的文檔 $loserNextMatchId 不存在！');
                                    }
                                }
                                break;
                            }
                        }
                        
                        if (loserNextMatchId == null) {
                            debugPrint('警告：無法找到敗者下一場比賽的actualMatchId，跳過敗者晉級');
                        }
                        
                        break;
                    }
                }
            }
        } else {
            debugPrint('警告：找不到對應的雙淘汰賽模板，無法處理敗者晉級');
        }
    } else if (loserId.isNotEmpty && completedMatch.bracket == 'loser') {
        // 如果是敗者組比賽的敗者，他被淘汰了
        debugPrint('敗者組比賽 ${completedMatch.id} 的敗者 $loserId 被淘汰。 loserNextMatchId=${completedMatch.loserNextMatchId}, loserSlotInNext=${completedMatch.loserSlotInNext}');
    } else if (loserId.isEmpty) {
        debugPrint('敗者ID無效 ($loserId)，跳過敗者處理。 Match ID: ${completedMatch.id}');
    } else {
        debugPrint('未知的敗者處理情況: loserId=$loserId, loserNextMatchId=${completedMatch.loserNextMatchId}, loserSlotInNext=${completedMatch.loserSlotInNext}, bracket=${completedMatch.bracket}');
    }

    // 如果是總決賽且已結束，或者其他情況導致賽程結束
    if (tournamentEnded) {
        final allMatchesSnapshot = await _firestore
            .collection('matches')
            .where('basic_info.tournamentId', isEqualTo: completedMatch.tournamentId)
            .get();

        bool allNonFinalMatchesCompleted = true;
        for (var doc in allMatchesSnapshot.docs) {
            final matchData = doc.data()['basic_info'];
            // 如果 F1 導致了 F2 (isGrandFinal 變為 false)，則 F1 完成不算賽事結束
            if (matchData['matchNumber'] == completedMatch.matchNumber && completedMatch.isGrandFinal && !(completedMatchUpdate['basic_info.isGrandFinal'] ?? true) ) {
                 allNonFinalMatchesCompleted = false; // F1 導致 F2，賽事未結束
                 tournamentEnded = false; // 重置 tournamentEnded 狀態
                 break;
            }
            if (matchData['status'] != 'completed' && !(matchData['isGrandFinal'] == false && matchData['bracket'] == 'final')) { // 排除未開始的F2
                allNonFinalMatchesCompleted = false;
                break;
            }
        }
        if (allNonFinalMatchesCompleted && tournamentEnded) { // 再次確認 tournamentEnded
             batch.update(_firestore.collection('tournaments').doc(completedMatch.tournamentId), {'status': 'completed'});
             debugPrint('賽程 ${completedMatch.tournamentId} 所有比賽已完成，狀態更新為 completed');
        } else if (!tournamentEnded) {
            debugPrint('賽程 ${completedMatch.tournamentId} 尚未完全結束 (可能有總決賽重賽)。');
        }
    }

    await batch.commit();
    debugPrint('雙淘汰賽比賽 ${completedMatch.id} 晉級處理完成。');
  }

  /// 啟動重賽比賽（F2）
  Future<void> _activateRematchIfExists(String tournamentId, String winnerBracketChampion, String loserBracketChampion, WriteBatch batch) async {
    try {
      // 查找F2比賽
      final f2MatchSnapshot = await _firestore.collection('matches')
          .where('basic_info.tournamentId', isEqualTo: tournamentId)
          .where('basic_info.matchNumber', isEqualTo: 'F2')
          .limit(1)
          .get();
      
      if (f2MatchSnapshot.docs.isNotEmpty) {
        final f2MatchRef = f2MatchSnapshot.docs.first.reference;
        
        // 設置F2比賽的選手和狀態
        final f2Updates = <String, dynamic>{
          'basic_info.redPlayer': winnerBracketChampion, // 勝者組冠軍
          'basic_info.bluePlayer': loserBracketChampion, // 敗者組冠軍
          'basic_info.status': 'ongoing',
        };
        
        batch.update(f2MatchRef, f2Updates);
        
        // 同步到賽程
        await TournamentService().syncAdvancementToTournament(
          tournamentId,
          'F2',
          'redPlayer',
          winnerBracketChampion,
          newStatus: 'ongoing',
        );
        
        await TournamentService().syncAdvancementToTournament(
          tournamentId,
          'F2',
          'bluePlayer',
          loserBracketChampion,
        );
        
        debugPrint('F2重賽已啟動: $winnerBracketChampion vs $loserBracketChampion');
      } else {
        debugPrint('警告：找不到F2比賽，無法啟動重賽');
      }
    } catch (e) {
      debugPrint('啟動F2重賽時發生錯誤: $e');
    }
  }

  /// 動態生成雙淘汰賽模板
  Map<String, List<Map<String, dynamic>>> _generateDoubleEliminationTemplate(int numPlayers) {
    final adjustedNumPlayers = nextPowerOfTwo(numPlayers);
    final winnerBracketRounds = (math.log(adjustedNumPlayers) / math.ln2).toInt();
    
    debugPrint('生成雙淘汰賽模板: 實際人數=$numPlayers, 調整後人數=$adjustedNumPlayers, 勝者組輪數=$winnerBracketRounds');
    
    final winnerBracket = <Map<String, dynamic>>[];
    final loserBracket = <Map<String, dynamic>>[];
    final finalBracket = <Map<String, dynamic>>[];
    
    // 生成勝者組
    _generateWinnerBracket(winnerBracket, adjustedNumPlayers, winnerBracketRounds);
    
    // 生成敗者組
    _generateLoserBracket(loserBracket, adjustedNumPlayers, winnerBracketRounds);
    
    // 生成總決賽
    finalBracket.add({
      'round': 1,
      'matchNumber': 'F1',
      'isGrandFinal': true,
      'canRematch': true,
      'nextMatch': 'F2',
      'nextSlot': 'redPlayer',
    });
    
    // 生成重賽場次
    finalBracket.add({
      'round': 2,
      'matchNumber': 'F2',
      'isGrandFinalRematch': true,
      'canRematch': false,
    });
    
    return {
      'winnerBracket': winnerBracket,
      'loserBracket': loserBracket,
      'finalBracket': finalBracket,
    };
  }
  
  /// 生成勝者組比賽
  void _generateWinnerBracket(List<Map<String, dynamic>> winnerBracket, int adjustedNumPlayers, int rounds) {
    int matchCounter = 1;
    
    for (int round = 1; round <= rounds; round++) {
      final matchesInRound = adjustedNumPlayers ~/ math.pow(2, round).toInt();
      
      for (int i = 0; i < matchesInRound; i++) {
        final matchNumber = 'W$matchCounter';
        final match = <String, dynamic>{
          'round': round,
          'matchNumber': matchNumber,
        };
        
        // 設置下一場比賽
        if (round < rounds) {
          // 修正nextMatch計算公式
          int previousRoundMatches = 0;
          for (int r = 1; r < round + 1; r++) {
            previousRoundMatches += adjustedNumPlayers ~/ math.pow(2, r).toInt();
          }
          final nextMatchNumber = 'W${previousRoundMatches + (i ~/ 2) + 1}';
          match['nextMatch'] = nextMatchNumber;
          match['nextSlot'] = (i % 2 == 0) ? 'redPlayer' : 'bluePlayer';
        } else {
          // 勝者組決賽
          match['nextMatch'] = 'F1';
          match['nextSlot'] = 'redPlayer';
          match['isWinnerBracketFinal'] = true;
        }
        
        // 設置敗者晉級路徑
        _setLoserPath(match, round, i, adjustedNumPlayers);
        
        winnerBracket.add(match);
        matchCounter++;
      }
    }
  }
  
  /// 設置敗者晉級路徑
  void _setLoserPath(Map<String, dynamic> match, int round, int matchIndex, int adjustedNumPlayers) {
    if (round == 1) {
      // 第一輪的敗者直接進入敗者組第一輪
      final loserMatchNumber = 'L${(matchIndex ~/ 2) + 1}';
      match['loserNextMatch'] = loserMatchNumber;
      match['loserNextSlot'] = (matchIndex % 2 == 0) ? 'redPlayer' : 'bluePlayer';
    } else {
       // 後續輪次的敗者進入敗者組相應位置
       final loserMatchNumber = _calculateLoserMatchNumber(round, matchIndex, adjustedNumPlayers);
       match['loserNextMatch'] = 'L$loserMatchNumber';
       match['loserNextSlot'] = 'bluePlayer';
     }
  }
  
  /// 計算敗者組比賽編號
  int _calculateLoserMatchNumber(int winnerRound, int matchIndex, int adjustedNumPlayers) {
    // 第一輪敗者組比賽數量
    final firstRoundLoserMatches = adjustedNumPlayers ~/ 4;
    
    if (winnerRound == 2) {
      return firstRoundLoserMatches + matchIndex + 1;
    }
    
    // 計算前面輪次的比賽數量
    int totalPreviousMatches = firstRoundLoserMatches;
    for (int r = 2; r < winnerRound; r++) {
      totalPreviousMatches += adjustedNumPlayers ~/ math.pow(2, r + 1).toInt();
    }
    
    return totalPreviousMatches + matchIndex + 1;
  }
  
  /// 生成敗者組比賽
  void _generateLoserBracket(List<Map<String, dynamic>> loserBracket, int adjustedNumPlayers, int winnerRounds) {
    int matchCounter = 1;
    final totalLoserRounds = (winnerRounds - 1) * 2;
    
    for (int round = 1; round <= totalLoserRounds; round++) {
      int matchesInRound;
      
      if (round % 2 == 1) {
        // 奇數輪：第一輪敗者相互比賽
        matchesInRound = adjustedNumPlayers ~/ math.pow(2, (round + 3) ~/ 2).toInt();
      } else {
        // 偶數輪：與勝者組敗者比賽
        matchesInRound = adjustedNumPlayers ~/ math.pow(2, (round + 4) ~/ 2).toInt();
      }
      
      for (int i = 0; i < matchesInRound; i++) {
        final matchNumber = 'L$matchCounter';
        final match = <String, dynamic>{
          'round': round,
          'matchNumber': matchNumber,
        };
        
        // 設置下一場比賽
        if (round < totalLoserRounds) {
          if (round % 2 == 1) {
            // 奇數輪的下一場是偶數輪
            final nextMatchNumber = 'L${matchCounter + matchesInRound}';
            match['nextMatch'] = nextMatchNumber;
            match['nextSlot'] = 'redPlayer';
          } else {
            // 偶數輪的下一場是下一個奇數輪
            final nextMatchNumber = 'L${matchCounter + matchesInRound}';
            match['nextMatch'] = nextMatchNumber;
            match['nextSlot'] = (i % 2 == 0) ? 'redPlayer' : 'bluePlayer';
          }
        } else {
          // 敗者組決賽
          match['nextMatch'] = 'F1';
          match['nextSlot'] = 'bluePlayer';
          match['isLoserBracketFinal'] = true;
        }
        
        loserBracket.add(match);
        matchCounter++;
      }
    }
  }
  
  /// 支持輪空的選手分配方法
  Future<void> _assignPlayersToDoubleEliminationWithByes(
    Map<String, Map<String, dynamic>> matchStructure,
    List<Match> allMatches,
    List<String> playerNames,
    int byeCount,
    int adjustedNumPlayers,
    bool randomPairing,
    WriteBatch batch,
  ) async {
    final actualPlayerNames = List<String>.from(playerNames);
    if (randomPairing) {
      actualPlayerNames.shuffle(math.Random());
      debugPrint('已啟用隨機配對，打亂後的選手名單: $actualPlayerNames');
    }
    
    // 計算輪空位置（從兩端開始）
    final firstRoundMatches = adjustedNumPlayers ~/ 2;
    final byePositions = _calculateByePositions(byeCount, firstRoundMatches);
    
    debugPrint('第一輪比賽數: $firstRoundMatches, 輪空位置: $byePositions');
    
    // 獲取第一輪勝者組比賽
    final firstRoundWinnerBracketMatches = allMatches
        .where((m) => m.bracket == 'winner' && m.round == 1)
        .toList();
    firstRoundWinnerBracketMatches.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    
    int playerIndex = 0;
    
    // 分配選手到第一輪比賽
    for (int i = 0; i < firstRoundWinnerBracketMatches.length; i++) {
      final match = firstRoundWinnerBracketMatches[i];
      
      if (byePositions.contains(i)) {
        // 這個位置有輪空
        debugPrint('比賽 ${match.matchNumber} (位置 $i) 有輪空');
        
        // 只分配一個選手，另一個位置留空表示輪空
        if (playerIndex < actualPlayerNames.length) {
          final player = actualPlayerNames[playerIndex++];
          final matchIndex = allMatches.indexWhere((m) => m.id == match.id);
          
          // 輪空的選手直接晉級，比賽狀態設為completed
          allMatches[matchIndex] = allMatches[matchIndex].copyWith(
            redPlayer: player,
            bluePlayer: '輪空',
            status: 'completed',
            winner: 'red',
            winReason: '輪空晉級',
          );
          
          matchStructure[match.matchNumber]!['redPlayer'] = player;
          matchStructure[match.matchNumber]!['bluePlayer'] = '輪空';
          matchStructure[match.matchNumber]!['status'] = 'completed';
          matchStructure[match.matchNumber]!['winner'] = player;
          
          debugPrint('選手 $player 在比賽 ${match.matchNumber} 中輪空晉級');
          
          // 處理輪空選手的自動晉級
          _handleByeAdvancement(allMatches[matchIndex], player, matchStructure, allMatches);
          
          // 處理輪空選手進入敗者組
          await _handleByeLoserAdvancement(allMatches[matchIndex], '輪空', matchStructure, allMatches, batch);
        }
      } else {
        // 正常比賽，分配兩個選手
        if (playerIndex < actualPlayerNames.length) {
          final redPlayer = actualPlayerNames[playerIndex++];
          final matchIndex = allMatches.indexWhere((m) => m.id == match.id);
          allMatches[matchIndex] = allMatches[matchIndex].copyWith(redPlayer: redPlayer);
          matchStructure[match.matchNumber]!['redPlayer'] = redPlayer;
        }
        
        if (playerIndex < actualPlayerNames.length) {
          final bluePlayer = actualPlayerNames[playerIndex++];
          final matchIndex = allMatches.indexWhere((m) => m.id == match.id);
          allMatches[matchIndex] = allMatches[matchIndex].copyWith(bluePlayer: bluePlayer);
          matchStructure[match.matchNumber]!['bluePlayer'] = bluePlayer;
        }
        
        // 如果雙方都有選手，則設為ongoing
        if (matchStructure[match.matchNumber]!['redPlayer'] != null && 
            matchStructure[match.matchNumber]!['bluePlayer'] != null) {
          final matchIndex = allMatches.indexWhere((m) => m.id == match.id);
          allMatches[matchIndex] = allMatches[matchIndex].copyWith(status: 'ongoing');
          matchStructure[match.matchNumber]!['status'] = 'ongoing';
        }
      }
    }
    
    debugPrint('選手分配完成，共分配 $playerIndex 名選手');
  }
  
  /// 處理輪空選手的自動晉級
  void _handleByeAdvancement(Match byeMatch, String winnerId, Map<String, Map<String, dynamic>> matchStructure, List<Match> allMatches) {
    if (byeMatch.nextMatchId == null || byeMatch.slotInNext == null) {
      debugPrint('輪空比賽 ${byeMatch.matchNumber} 沒有下一場比賽，無需晉級');
      return;
    }
    
    // 查找下一場比賽的matchNumber
    String? nextMatchNumber;
    for (final entry in matchStructure.entries) {
      if (entry.value['actualMatchId'] == byeMatch.nextMatchId) {
        nextMatchNumber = entry.key;
        break;
      }
    }
    
    // 如果通過actualMatchId找不到，嘗試通過nextMatch字段查找
    if (nextMatchNumber == null) {
      for (final entry in matchStructure.entries) {
        if (entry.key == byeMatch.matchNumber) {
          final nextMatch = entry.value['nextMatch'];
          if (nextMatch != null && matchStructure.containsKey(nextMatch)) {
            nextMatchNumber = nextMatch;
            break;
          }
        }
      }
    }
    
    if (nextMatchNumber != null && matchStructure.containsKey(nextMatchNumber)) {
      // 將輪空獲勝者晉級到下一場比賽
      matchStructure[nextMatchNumber]![byeMatch.slotInNext!] = winnerId;
      
      // 同時更新allMatches中對應的Match對象
      final nextMatchIndex = allMatches.indexWhere((m) => m.id == byeMatch.nextMatchId);
      if (nextMatchIndex != -1) {
        final currentMatch = allMatches[nextMatchIndex];
        if (byeMatch.slotInNext == 'redPlayer') {
          allMatches[nextMatchIndex] = currentMatch.copyWith(redPlayer: winnerId);
        } else if (byeMatch.slotInNext == 'bluePlayer') {
          allMatches[nextMatchIndex] = currentMatch.copyWith(bluePlayer: winnerId);
        }
      }
      
      // 檢查下一場比賽是否雙方都已就緒
      final nextMatch = matchStructure[nextMatchNumber]!;
      if (nextMatch['redPlayer'] != null && 
          nextMatch['bluePlayer'] != null &&
          nextMatch['redPlayer'] != '' &&
          nextMatch['bluePlayer'] != '') {
        nextMatch['status'] = 'ongoing';
        
        // 同時更新allMatches中的狀態
        if (nextMatchIndex != -1) {
          allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(status: 'ongoing');
        }
        
        debugPrint('下一場比賽 $nextMatchNumber 雙方已就緒，更新狀態為 ongoing');
      }
      
      debugPrint('輪空獲勝者 $winnerId 已晉級到比賽 $nextMatchNumber 的 ${byeMatch.slotInNext} 位置');
    } else {
      debugPrint('警告：無法找到下一場比賽 ${byeMatch.nextMatchId} 對應的matchNumber');
    }
  }
  
  /// 處理輪空選手進入敗者組
  Future<void> _handleByeLoserAdvancement(Match byeMatch, String loserId, Map<String, Map<String, dynamic>> matchStructure, List<Match> allMatches, WriteBatch batch) async {
    // 如果是正常選手（非輪空），也需要檢查是否有下一場比賽需要晉級
    if (loserId != '輪空' && byeMatch.nextMatchId != null && byeMatch.slotInNext != null) {
      // 查找下一場比賽的matchNumber
      String? nextMatchNumber;
      for (final entry in matchStructure.entries) {
        if (entry.value['actualMatchId'] == byeMatch.nextMatchId) {
          nextMatchNumber = entry.key;
          break;
        }
      }
      
      // 如果通過actualMatchId找不到，嘗試通過nextMatch字段查找
      if (nextMatchNumber == null) {
        for (final entry in matchStructure.entries) {
          if (entry.key == byeMatch.matchNumber) {
            final nextMatch = entry.value['nextMatch'];
            if (nextMatch != null && matchStructure.containsKey(nextMatch)) {
              nextMatchNumber = nextMatch;
              break;
            }
          }
        }
      }
      
      // 額外檢查：確保使用模板中定義的正確下一場比賽
      if (nextMatchNumber == null) {
        // 嘗試從預定義模板中查找
        final tournamentDoc = await _firestore.collection('tournaments').doc(byeMatch.tournamentId).get();
        final numPlayers = tournamentDoc.data()?['numPlayers'] as int? ?? 0;
        
        if (_doubleEliminationTemplates.containsKey(numPlayers)) {
          final template = _doubleEliminationTemplates[numPlayers]!;
          for (final bracket in ['winnerBracket', 'loserBracket', 'finalBracket']) {
            for (final matchData in template[bracket]!) {
              if (matchData['matchNumber'] == byeMatch.matchNumber) {
                nextMatchNumber = matchData['nextMatch'] as String?;
                debugPrint('從預定義模板找到下一場比賽: $nextMatchNumber');
                break;
              }
            }
            if (nextMatchNumber != null) break;
          }
        }
      }
      
      if (nextMatchNumber != null && matchStructure.containsKey(nextMatchNumber)) {
        // 將正常選手晉級到下一場比賽
        matchStructure[nextMatchNumber]![byeMatch.slotInNext!] = loserId;
        
        // 同時更新allMatches中對應的Match對象
        final nextMatchIndex = allMatches.indexWhere((m) => m.id == byeMatch.nextMatchId);
        if (nextMatchIndex != -1) {
          final currentMatch = allMatches[nextMatchIndex];
          if (byeMatch.slotInNext == 'redPlayer') {
            allMatches[nextMatchIndex] = currentMatch.copyWith(redPlayer: loserId);
          } else if (byeMatch.slotInNext == 'bluePlayer') {
            allMatches[nextMatchIndex] = currentMatch.copyWith(bluePlayer: loserId);
          }
          
          // 更新數據庫中的選手信息
          final nextMatchRef = _firestore.collection('matches').doc(byeMatch.nextMatchId);
          final playerUpdate = <String, dynamic>{
            'basic_info.${byeMatch.slotInNext}': loserId,
          };
          
          // 檢查下一場比賽是否雙方都已就緒
          final nextMatch = matchStructure[nextMatchNumber]!;
          if (nextMatch['redPlayer'] != null && 
              nextMatch['bluePlayer'] != null &&
              nextMatch['redPlayer'] != '' &&
              nextMatch['bluePlayer'] != '') {
            
            // 檢查是否有輪空對手，如果有則自動晉級
            if (nextMatch['redPlayer'] == '輪空' || nextMatch['bluePlayer'] == '輪空') {
              final normalPlayer = nextMatch['redPlayer'] == '輪空' ? nextMatch['bluePlayer'] : nextMatch['redPlayer'];
              final winnerSide = nextMatch['redPlayer'] == '輪空' ? 'blue' : 'red';
              
              nextMatch['status'] = 'completed';
              nextMatch['winner'] = normalPlayer;
              
              allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(
                status: 'completed',
                winner: winnerSide,
                winReason: '對手輪空自動晉級',
              );
              
              // 更新數據庫中的比賽狀態
              playerUpdate['basic_info.status'] = 'completed';
              playerUpdate['basic_info.winner'] = winnerSide;
              playerUpdate['basic_info.winReason'] = '對手輪空自動晉級';
              playerUpdate['timestamps.completedAt'] = FieldValue.serverTimestamp();
              
              debugPrint('比賽 $nextMatchNumber 選手 $normalPlayer 對手輪空，自動晉級');
              
              // 先提交當前更新
              batch.update(nextMatchRef, playerUpdate);
              
              // 遞歸處理自動晉級
              await _handleByeLoserAdvancement(allMatches[nextMatchIndex], normalPlayer, matchStructure, allMatches, batch);
            } else {
              // 正常情況，設為ongoing
              nextMatch['status'] = 'ongoing';
              allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(status: 'ongoing');
              playerUpdate['basic_info.status'] = 'ongoing';
              debugPrint('比賽 $nextMatchNumber 雙方已就緒，更新狀態為 ongoing');
            }
          }
          
          // 提交選手和狀態更新
          batch.update(nextMatchRef, playerUpdate);
        }
        
        debugPrint('選手 $loserId 已晉級到比賽 $nextMatchNumber 的 ${byeMatch.slotInNext} 位置');
      }
    }
    // 只有輪空選手才需要進入敗者組
    if (loserId != '輪空') {
      return;
    }
    
    if (byeMatch.loserNextMatchId == null || byeMatch.loserSlotInNext == null) {
      debugPrint('輪空比賽 ${byeMatch.matchNumber} 沒有敗者組下一場比賽，無需進入敗者組');
      return;
    }
    
    // 查找敗者組下一場比賽的matchNumber
    String? loserNextMatchNumber;
    for (final entry in matchStructure.entries) {
      if (entry.value['actualMatchId'] == byeMatch.loserNextMatchId) {
        loserNextMatchNumber = entry.key;
        break;
      }
    }
    
    // 如果通過actualMatchId找不到，嘗試通過loserNextMatch字段查找
    if (loserNextMatchNumber == null) {
      for (final entry in matchStructure.entries) {
        if (entry.key == byeMatch.matchNumber) {
          final loserNextMatch = entry.value['loserNextMatch'];
          if (loserNextMatch != null && matchStructure.containsKey(loserNextMatch)) {
            loserNextMatchNumber = loserNextMatch;
            break;
          }
        }
      }
    }
    
    if (loserNextMatchNumber != null && matchStructure.containsKey(loserNextMatchNumber)) {
      // 將輪空敗者進入敗者組比賽
      matchStructure[loserNextMatchNumber]![byeMatch.loserSlotInNext!] = loserId;
      
      // 同時更新allMatches中對應的Match對象
      final loserNextMatchIndex = allMatches.indexWhere((m) => m.id == byeMatch.loserNextMatchId);
      if (loserNextMatchIndex != -1) {
        final currentMatch = allMatches[loserNextMatchIndex];
        if (byeMatch.loserSlotInNext == 'redPlayer') {
          allMatches[loserNextMatchIndex] = currentMatch.copyWith(redPlayer: loserId);
        } else if (byeMatch.loserSlotInNext == 'bluePlayer') {
          allMatches[loserNextMatchIndex] = currentMatch.copyWith(bluePlayer: loserId);
        }
      }
      
      // 更新數據庫中的敗者組選手信息
      final loserNextMatchRef = _firestore.collection('matches').doc(byeMatch.loserNextMatchId);
      final loserPlayerUpdate = <String, dynamic>{
        'basic_info.${byeMatch.loserSlotInNext}': loserId,
      };
      
      // 檢查敗者組比賽是否雙方都已就緒
      final loserNextMatch = matchStructure[loserNextMatchNumber]!;
      if (loserNextMatch['redPlayer'] != null && 
          loserNextMatch['bluePlayer'] != null &&
          loserNextMatch['redPlayer'] != '' &&
          loserNextMatch['bluePlayer'] != '') {
        
        // 檢查是否雙方都是輪空
        if (loserNextMatch['redPlayer'] == '輪空' && loserNextMatch['bluePlayer'] == '輪空') {
          // 雙輪空情況，直接在下一場比賽中填入輪空
          loserNextMatch['status'] = 'completed';
          loserNextMatch['winner'] = '輪空';
          
          // 更新allMatches中的狀態
          if (loserNextMatchIndex != -1) {
            allMatches[loserNextMatchIndex] = allMatches[loserNextMatchIndex].copyWith(
              status: 'completed',
              winner: 'red',
              winReason: '雙輪空自動晉級',
            );
          }
          
          // 更新數據庫中的比賽狀態
          loserPlayerUpdate['basic_info.status'] = 'completed';
          loserPlayerUpdate['basic_info.winner'] = 'red';
          loserPlayerUpdate['basic_info.winReason'] = '雙輪空自動晉級';
          loserPlayerUpdate['timestamps.completedAt'] = FieldValue.serverTimestamp();
          
          debugPrint('敗者組比賽 $loserNextMatchNumber 雙方都是輪空，直接在下一場比賽中填入輪空');
          
          // 先提交當前更新
          batch.update(loserNextMatchRef, loserPlayerUpdate);
          
          // 處理雙輪空比賽的晉級 - 直接在下一場比賽中填入輪空
          if (loserNextMatchIndex != -1) {
            final currentMatch = allMatches[loserNextMatchIndex];
            if (currentMatch.nextMatchId != null && currentMatch.slotInNext != null) {
              // 查找下一場比賽
              String? nextMatchNumber;
              for (final entry in matchStructure.entries) {
                if (entry.value['actualMatchId'] == currentMatch.nextMatchId) {
                  nextMatchNumber = entry.key;
                  break;
                }
              }
              
              if (nextMatchNumber != null && matchStructure.containsKey(nextMatchNumber)) {
                // 直接在下一場比賽中填入輪空
                matchStructure[nextMatchNumber]![currentMatch.slotInNext!] = '輪空';
                
                // 更新數據庫
                final nextMatchRef = _firestore.collection('matches').doc(currentMatch.nextMatchId);
                batch.update(nextMatchRef, {
                  'basic_info.${currentMatch.slotInNext}': '輪空',
                  'basic_info.status': 'ongoing',
                });
                
                debugPrint('雙輪空比賽 ${currentMatch.matchNumber} 直接在下一場比賽 $nextMatchNumber 的 ${currentMatch.slotInNext} 位置填入輪空');
                
                // 更新allMatches中對應的Match對象
                final nextMatchIndex = allMatches.indexWhere((m) => m.id == currentMatch.nextMatchId);
                if (nextMatchIndex != -1) {
                  if (currentMatch.slotInNext == 'redPlayer') {
                    allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(redPlayer: '輪空');
                  } else if (currentMatch.slotInNext == 'bluePlayer') {
                    allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(bluePlayer: '輪空');
                  }
                  allMatches[nextMatchIndex] = allMatches[nextMatchIndex].copyWith(status: 'ongoing');
                }
              }
            }
            // 不再遞歸調用，避免自動讓紅方輪空晉級
          }
        } else if (loserNextMatch['redPlayer'] == '輪空' || loserNextMatch['bluePlayer'] == '輪空') {
          // 一方是輪空，另一方是正常選手，自動讓正常選手晉級
          final normalPlayer = loserNextMatch['redPlayer'] == '輪空' ? loserNextMatch['bluePlayer'] : loserNextMatch['redPlayer'];
          final winnerSide = loserNextMatch['redPlayer'] == '輪空' ? 'blue' : 'red';
          
          loserNextMatch['status'] = 'completed';
          loserNextMatch['winner'] = normalPlayer;
          
          // 更新allMatches中的狀態
          if (loserNextMatchIndex != -1) {
            allMatches[loserNextMatchIndex] = allMatches[loserNextMatchIndex].copyWith(
              status: 'completed',
              winner: winnerSide,
              winReason: '對手輪空自動晉級',
            );
          }
          
          // 更新數據庫中的比賽狀態
          loserPlayerUpdate['basic_info.status'] = 'completed';
          loserPlayerUpdate['basic_info.winner'] = winnerSide;
          loserPlayerUpdate['basic_info.winReason'] = '對手輪空自動晉級';
          loserPlayerUpdate['timestamps.completedAt'] = FieldValue.serverTimestamp();
          
          debugPrint('敗者組比賽 $loserNextMatchNumber 選手 $normalPlayer 對手輪空，自動晉級');
          
          // 先提交當前更新
          batch.update(loserNextMatchRef, loserPlayerUpdate);
          
          // 遞歸處理選手對輪空的晉級
          if (loserNextMatchIndex != -1) {
            await _handleByeLoserAdvancement(allMatches[loserNextMatchIndex], normalPlayer, matchStructure, allMatches, batch);
          }
        } else {
          // 正常情況，設為ongoing
          loserNextMatch['status'] = 'ongoing';
          
          // 同時更新allMatches中的狀態
          if (loserNextMatchIndex != -1) {
            allMatches[loserNextMatchIndex] = allMatches[loserNextMatchIndex].copyWith(status: 'ongoing');
          }
          
          loserPlayerUpdate['basic_info.status'] = 'ongoing';
          debugPrint('敗者組比賽 $loserNextMatchNumber 雙方已就緒，更新狀態為 ongoing');
        }
      }
      
      // 提交敗者組選手和狀態更新
      batch.update(loserNextMatchRef, loserPlayerUpdate);
      
      debugPrint('輪空敗者 $loserId 已進入敗者組比賽 $loserNextMatchNumber 的 ${byeMatch.loserSlotInNext} 位置');
    } else {
      debugPrint('警告：無法找到敗者組下一場比賽 ${byeMatch.loserNextMatchId} 對應的matchNumber');
    }
  }
  
  // --- 雙淘汰賽相關代碼結束 ---

  /// 檢查並處理比賽中的輪空晉級
  /// 當比賽狀態從 PENDING 變為 ONGOING 時調用
  Future<void> checkAndHandleByeAdvancement(String matchId) async {
    try {
      // 獲取比賽信息
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) {
        debugPrint('比賽 $matchId 不存在');
        return;
      }
      
      final matchData = matchDoc.data()!;
      final basicInfo = matchData['basic_info'] as Map<String, dynamic>? ?? {};
      final redPlayer = basicInfo['redPlayer'] as String? ?? '';
      final bluePlayer = basicInfo['bluePlayer'] as String? ?? '';
      final status = basicInfo['status'] as String? ?? 'pending';
      
      // 只處理剛變為 ongoing 的比賽
      if (status != 'ongoing') {
        return;
      }
      
      // 檢查是否有輪空選手
      if (redPlayer == '輪空' || bluePlayer == '輪空') {
        final batch = _firestore.batch();
        final winner = redPlayer == '輪空' ? bluePlayer : redPlayer;
        final winnerSide = redPlayer == '輪空' ? 'blue' : 'red';
        
        // 更新比賽狀態為已完成
        batch.update(_firestore.collection('matches').doc(matchId), {
          'basic_info.status': 'completed',
          'basic_info.winner': winnerSide,
          'basic_info.winReason': '對手輪空自動晉級',
          'timestamps.completedAt': FieldValue.serverTimestamp(),
        });
        
        // 獲取比賽的完整信息以處理晉級
        final match = Match.fromFirestore(matchDoc);
        
        // 獲取賽程信息
        final tournamentDoc = await _firestore.collection('tournaments').doc(match.tournamentId).get();
        if (!tournamentDoc.exists) {
          debugPrint('賽程 ${match.tournamentId} 不存在');
          await batch.commit();
          return;
        }
        
        final tournamentData = tournamentDoc.data()!;
        final matchStructure = Map<String, Map<String, dynamic>>.from(tournamentData['matches'] as Map? ?? {});
        
        // 獲取所有比賽
        final allMatchesSnapshot = await _firestore.collection('matches')
            .where('basic_info.tournamentId', isEqualTo: match.tournamentId)
            .get();
        
        final allMatches = allMatchesSnapshot.docs.map((doc) => Match.fromFirestore(doc)).toList();
        
        // 處理勝者晉級
        if (match.nextMatchId != null && match.slotInNext != null) {
          final nextMatchRef = _firestore.collection('matches').doc(match.nextMatchId!);
          batch.update(nextMatchRef, {
            'basic_info.${match.slotInNext}': winner,
          });
          
          // 檢查下一場比賽是否雙方都已就緒
          final nextMatchDoc = await nextMatchRef.get();
          if (nextMatchDoc.exists) {
            final nextMatchBasicInfo = nextMatchDoc.data()?['basic_info'] as Map<String, dynamic>? ?? {};
            final otherSlot = match.slotInNext == 'redPlayer' ? 'bluePlayer' : 'redPlayer';
            final otherPlayer = nextMatchBasicInfo[otherSlot] as String? ?? '';
            
            if (otherPlayer != '' && otherPlayer != null) {
              batch.update(nextMatchRef, {
                'basic_info.status': 'ongoing',
              });
            }
          }
        }
        
        // 處理敗者進入敗者組
        if (match.bracket == 'winner' && match.loserNextMatchId != null && match.loserSlotInNext != null) {
          final loser = redPlayer == '輪空' ? '輪空' : bluePlayer == '輪空' ? '輪空' : '';
          if (loser == '輪空') {
            final loserNextMatchRef = _firestore.collection('matches').doc(match.loserNextMatchId!);
            batch.update(loserNextMatchRef, {
              'basic_info.${match.loserSlotInNext}': loser,
            });
            
            // 檢查敗者組比賽是否雙方都已就緒
            final loserNextMatchDoc = await loserNextMatchRef.get();
            if (loserNextMatchDoc.exists) {
              final loserNextMatchBasicInfo = loserNextMatchDoc.data()?['basic_info'] as Map<String, dynamic>? ?? {};
              final otherSlot = match.loserSlotInNext == 'redPlayer' ? 'bluePlayer' : 'redPlayer';
              final otherPlayer = loserNextMatchBasicInfo[otherSlot] as String? ?? '';
              
              if (otherPlayer != '' && otherPlayer != null) {
                // 檢查是否雙方都是輪空
                if (loser == '輪空' && otherPlayer == '輪空') {
                  // 雙輪空情況，直接在下一場比賽中填入輪空
                  batch.update(loserNextMatchRef, {
                    'basic_info.status': 'completed',
                    'basic_info.winner': 'red',
                    'basic_info.winReason': '雙輪空自動晉級',
                    'timestamps.completedAt': FieldValue.serverTimestamp(),
                  });
                  
                  // 處理雙輪空比賽的晉級
                  final loserNextMatch = Match.fromFirestore(loserNextMatchDoc);
                  if (loserNextMatch.nextMatchId != null && loserNextMatch.slotInNext != null) {
                    // 直接在下一場比賽中填入輪空
                    batch.update(_firestore.collection('matches').doc(loserNextMatch.nextMatchId!), {
                      'basic_info.${loserNextMatch.slotInNext}': '輪空',
                      // 設置下一場比賽狀態為 ongoing，確保它能被正確處理
                      'basic_info.status': 'ongoing',
                    });
                    
                    debugPrint('雙輪空比賽 ${loserNextMatch.matchNumber} 直接在下一場比賽中填入輪空');
                  }
                } else if (loser == '輪空' || otherPlayer == '輪空') {
                  // 一方是輪空，另一方是正常選手，自動讓正常選手晉級
                  final normalPlayer = loser == '輪空' ? otherPlayer : loser;
                  final winnerSide = loser == '輪空' ? (match.loserSlotInNext == 'redPlayer' ? 'blue' : 'red') : (match.loserSlotInNext == 'redPlayer' ? 'red' : 'blue');
                  
                  batch.update(loserNextMatchRef, {
                    'basic_info.status': 'completed',
                    'basic_info.winner': winnerSide,
                    'basic_info.winReason': '對手輪空自動晉級',
                    'timestamps.completedAt': FieldValue.serverTimestamp(),
                  });
                  
                  // 處理正常選手晉級
                  final loserNextMatch = Match.fromFirestore(loserNextMatchDoc);
                  if (loserNextMatch.nextMatchId != null && loserNextMatch.slotInNext != null) {
                    batch.update(_firestore.collection('matches').doc(loserNextMatch.nextMatchId!), {
                      'basic_info.${loserNextMatch.slotInNext}': normalPlayer,
                    });
                  }
                } else {
                  // 正常情況，設為ongoing
                  batch.update(loserNextMatchRef, {
                    'basic_info.status': 'ongoing',
                  });
                }
              }
            }
          }
        }
        
        // 提交所有更新
        await batch.commit();
        
        // 同步更新到賽程
        await _tournamentService.syncMatchDataToTournament(matchId);
      }
    } catch (e) {
      debugPrint('檢查並處理輪空晉級時發生錯誤: $e');
    }
  }
}