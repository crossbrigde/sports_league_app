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
}