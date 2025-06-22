import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 更新賽程狀態
  Future<void> updateTournamentStatus(String tournamentId, String status) async {
    try {
      print('正在更新賽程狀態：$tournamentId 到 $status');
      
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': status,
      });
      
      print('賽程狀態更新成功！');
    } catch (e) {
      print('更新賽程狀態時發生錯誤：$e');
      throw '更新賽程狀態失敗：$e';
    }
  }

  // 檢查賽程名稱是否已存在
  Future<bool> isTournamentNameExists(String name) async {
    try {
      print('正在檢查賽程名稱是否重複：$name');
      
      final snapshot = await _firestore
          .collection('tournaments')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      
      final exists = snapshot.docs.isNotEmpty;
      print('賽程名稱「$name」${exists ? '已存在' : '不存在'}');
      return exists;
    } catch (e) {
      print('檢查賽程名稱時發生錯誤：$e');
      throw '檢查賽程名稱失敗：$e';
    }
  }

  Future<void> saveTournament(Tournament tournament) async {
    try {
      print('正在保存賽程到 Firestore：${tournament.id}');
      
      final name = tournament.name.trim();

      // 驗證名稱為非空
      if (name.isEmpty) {
        print('賽程名稱為空');
        throw '賽程名稱不能為空';
      }

      // 驗證名稱長度
      if (name.length > 25) {
        print('賽程名稱超過25個字元上限：$name');
        throw '賽程名稱不能超過25個字元';
      }

      // 可選：驗證是否包含非法符號（只允許中英數、空格與部分標點）
      final nameRegex = RegExp(r"^[\u4e00-\u9fa5_a-zA-Z0-9\s\-]+$");
      if (!nameRegex.hasMatch(name)) {
        print('賽程名稱包含非法字元：$name');
        throw '賽程名稱只能包含中英文、數字與「-」等基本符號';
      }
      
      // 檢查賽程名稱是否重複
      final nameExists = await isTournamentNameExists(name);
      if (nameExists) {
        print('賽程名稱重複：$name');
        throw '賽程名稱「$name」已存在，請使用其他名稱';
      }

      await _firestore.collection('tournaments').doc(tournament.id).set({
        'id': tournament.id,
        'name': name,
        'type': tournament.type,
        'targetPoints': tournament.targetPoints,
        'matchMinutes': tournament.matchMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'ongoing',
      });
      
      print('賽程保存成功！');
    } catch (e) {
      print('保存賽程時發生錯誤：$e');
      throw '保存賽程失敗：$e';
    }
  }

  Future<List<Tournament>> getAllTournaments() async {
    try {
      print('正在獲取所有賽程...');
      
      final snapshot = await _firestore
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        return Tournament.fromFirestore(doc);
      }).toList();

      print('成功獲取 ${tournaments.length} 個賽程');
      return tournaments;
    } catch (e) {
      print('獲取賽程列表時發生錯誤：$e');
      throw '獲取賽程列表失敗：$e';
    }
  }

  Future<List<Tournament>> getActiveTournaments() async {
    try {
      print('正在獲取進行中的賽程...');
      
      final snapshot = await _firestore
          .collection('tournaments')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        return Tournament.fromFirestore(doc);
      }).toList();

      print('成功獲取 ${tournaments.length} 個進行中的賽程');
      return tournaments;
    } catch (e) {
      print('獲取進行中賽程列表時發生錯誤：$e');
      throw '獲取進行中賽程列表失敗：$e';
    }
  }
  
  // 同步比賽數據到賽程集合（增強版）
  Future<void> syncMatchToTournament(String tournamentId, String matchNumber, Map<String, dynamic> matchData) async {
    try {
      print('正在同步比賽數據到賽程：tournamentId=$tournamentId, matchNumber=$matchNumber');
      
      // 獲取賽程文檔
      final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
      
      if (!tournamentDoc.exists) {
        print('找不到賽程文檔：$tournamentId');
        return;
      }
      
      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final matches = Map<String, dynamic>.from(tournamentData['matches'] ?? {});
      
      // 找到對應的比賽並更新
      String? targetMatchId;
      matches.forEach((matchId, match) {
        if (match['matchNumber'] == matchNumber) {
          targetMatchId = matchId;
        }
      });
      
      if (targetMatchId != null) {
        // 更新比賽數據，保持與您提供的數據結構一致
        matches[targetMatchId!] = {
          ...matches[targetMatchId!],
          'bluePlayer': matchData['bluePlayer'],
          'redPlayer': matchData['redPlayer'],
          'status': matchData['status'],
          'winner': matchData['winner'],
          'winReason': matchData['winReason'],
        };
        
        // 檢查是否需要更新整體賽程狀態
        String tournamentStatus = 'ongoing';
        final allMatches = matches.values.toList();
        final completedMatches = allMatches.where((m) => m['status'] == 'completed').length;
        final ongoingMatches = allMatches.where((m) => m['status'] == 'ongoing').length;
        
        if (completedMatches == allMatches.length) {
          tournamentStatus = 'completed';
        } else if (ongoingMatches == 0 && completedMatches == 0) {
          tournamentStatus = 'pending';
        }
        
        // 更新賽程文檔
        await _firestore.collection('tournaments').doc(tournamentId).update({
          'matches': matches,
          'status': tournamentStatus,
        });
        
        print('成功同步比賽數據到賽程，賽程狀態：$tournamentStatus');
      } else {
        print('在賽程中找不到對應的比賽：matchNumber=$matchNumber');
      }
    } catch (e) {
      print('同步比賽數據時發生錯誤：$e');
      throw '同步比賽數據失敗：$e';
    }
  }
  
  // 新增：同步晉級選手到賽程
  Future<void> syncAdvancementToTournament(String tournamentId, String nextMatchNumber, String slotInNext, String winnerId, {String? newStatus}) async {
    try {
      print('正在同步晉級數據到賽程：tournamentId=$tournamentId, nextMatchNumber=$nextMatchNumber, slot=$slotInNext, winner=$winnerId, newStatus=$newStatus');
      
      final tournamentDocRef = _firestore.collection('tournaments').doc(tournamentId);
      final tournamentDoc = await tournamentDocRef.get();
      
      if (!tournamentDoc.exists) {
        print('找不到賽程文檔：$tournamentId');
        return;
      }
      
      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final matches = Map<String, dynamic>.from(tournamentData['matches'] ?? {});
      
      String? targetMatchId;
      matches.forEach((matchId, match) {
        if (match['matchNumber'] == nextMatchNumber) {
          targetMatchId = matchId;
        }
      });
      
      if (targetMatchId != null) {
        final matchToUpdate = Map<String, dynamic>.from(matches[targetMatchId!] ?? {});
        matchToUpdate[slotInNext] = winnerId;
        
        // 如果提供了 newStatus，則更新比賽狀態
        if (newStatus != null) {
          matchToUpdate['status'] = newStatus;
        }
        
        matches[targetMatchId!] = matchToUpdate;
        
        await tournamentDocRef.update({'matches': matches});
        print('成功同步晉級數據到賽程');
      } else {
        print('在賽程中找不到對應的下一場比賽：matchNumber=$nextMatchNumber');
      }
    } catch (e) {
      print('同步晉級數據時發生錯誤：$e');
      throw '同步晉級數據失敗：$e';
    }
  }
  
  // 刪除賽程及其相關比賽
  
  // 根據比賽ID同步比賽數據到賽程
  Future<void> syncMatchDataToTournament(String matchId) async {
    try {
      print('正在根據比賽ID同步數據到賽程：matchId=$matchId');
      
      // 獲取比賽文檔
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      
      if (!matchDoc.exists) {
        print('找不到比賽文檔：$matchId');
        return;
      }
      
      final matchData = matchDoc.data() as Map<String, dynamic>;
      final tournamentId = matchData['tournamentId'];
      final matchNumber = matchData['matchNumber'];
      
      if (tournamentId == null || matchNumber == null) {
        print('比賽缺少必要的賽程ID或比賽編號：$matchId');
        return;
      }
      
      // 提取需要同步的比賽數據
      final syncData = {
        'bluePlayer': matchData['bluePlayer'],
        'redPlayer': matchData['redPlayer'],
        'status': matchData['status'],
        'winner': matchData['winner'],
        'winReason': matchData['winReason'],
      };
      
      // 調用現有方法同步到賽程
      await syncMatchToTournament(tournamentId, matchNumber, syncData);
      
      print('成功根據比賽ID同步數據到賽程');
    } catch (e) {
      print('根據比賽ID同步數據時發生錯誤：$e');
      throw '根據比賽ID同步數據失敗：$e';
    }
  }
}