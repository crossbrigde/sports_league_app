import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../../models/match.dart';
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
        'id': 'PLAYER${index + 1}',
        'displayName': 'PLAYER${index + 1}',
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
    
    // 第一步：建立完整的比賽樹結構
    final matchStructure = _buildCompleteMatchTree(totalMatches, adjustedNumPlayers);
    
    // 第二步：安排輪空位置（從兩端開始）
    final byePositions = _calculateByePositions(byeCount, firstRoundMatches);
    
    // 第三步：分配選手到第一輪比賽
    final matchesWithPlayers = _assignPlayersToMatches(
      matchStructure, 
      numPlayers, 
      byePositions, 
      firstRoundMatches
    );
    
    // 第四步：創建所有 Match 物件
    final allMatches = <Match>[];
    for (final entry in matchesWithPlayers.entries) {
      final matchId = entry.key;
      final matchData = entry.value;
      
      final match = Match(
        id: _uuid.v4(),
        name: '${name} - 第${matchData['round']}輪 #${matchData['matchNumber']}',
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
    int firstRoundMatches,
  ) {
    final matches = Map<String, Map<String, dynamic>>.from(matchStructure);
    int playerIndex = 0;
    
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
        // 輪空比賽
        if (playerIndex < numPlayers) {
          matches[matchId]!['redPlayer'] = 'PLAYER${playerIndex + 1}';
          matches[matchId]!['bluePlayer'] = 'BYE';
          matches[matchId]!['status'] = 'completed';
          matches[matchId]!['winner'] = 'red';
          matches[matchId]!['winReason'] = '對手輪空';
          
          debugPrint('輪空比賽: PLAYER${playerIndex + 1} 自動晉級');
          
          // 自動晉級到下一場
          _advanceWinner(matches, matchId, 'PLAYER${playerIndex + 1}');
          
          playerIndex++;
        } else {
          debugPrint('警告: 選手不足，無法分配到輪空比賽 $matchId');
        }
      } else {
        // 正常比賽 - 分配兩名選手
        String? redPlayer;
        String? bluePlayer;
        
        if (playerIndex < numPlayers) {
          redPlayer = 'PLAYER${playerIndex + 1}';
          matches[matchId]!['redPlayer'] = redPlayer;
          debugPrint('分配紅方選手: $redPlayer 到比賽 $matchId');
          playerIndex++;
        }
        
        if (playerIndex < numPlayers) {
          bluePlayer = 'PLAYER${playerIndex + 1}';
          matches[matchId]!['bluePlayer'] = bluePlayer;
          debugPrint('分配藍方選手: $bluePlayer 到比賽 $matchId');
          playerIndex++;
        }
        
        // 檢查是否雙方都有選手，如果有則設為 ongoing
        if (redPlayer != null && bluePlayer != null) {
          matches[matchId]!['status'] = 'ongoing';
          debugPrint('比賽 $matchId 雙方就緒 ($redPlayer vs $bluePlayer)，設為 ongoing');
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

  /// 處理比賽結束後的晉級邏輯
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
        
        if ((match.slotInNext == 'redPlayer' && basicInfo['bluePlayer'] != null && basicInfo['bluePlayer'] != '') ||
            (match.slotInNext == 'bluePlayer' && basicInfo['redPlayer'] != null && basicInfo['redPlayer'] != '')) {
          updates['basic_info.status'] = 'ongoing';
          debugPrint('下一場比賽雙方已就绪，更新狀態為ongoing');
        }
        
        await docSnapshot.reference.update(updates);
        debugPrint('成功更新下一場比賽');
      } else {
        debugPrint('錯誤: 找不到下一場比賽，nextMatchId=${match.nextMatchId}');
      }
    } catch (e) {
      debugPrint('處理晉級邏輯時發生錯誤: $e');
    }
  }
}